import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/query_chat_models.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/query/query_source_access.dart';
import 'package:lotti/features/agents/state/agent_chat_projection.dart';
import 'package:lotti/features/agents/ui/chat/agent_chat_view.dart';
import 'package:lotti/features/ai_consumption/model/consumption_aggregation_models.dart';
import 'package:lotti/features/ai_consumption/state/consumption_providers.dart';
import 'package:lotti/features/design_system/components/chips/design_system_chip.dart';
import 'package:lotti/features/design_system/components/dividers/design_system_divider.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/front_agent/model/front_agent_identity.dart';
import 'package:lotti/features/front_agent/model/front_chat_thread.dart';
import 'package:lotti/features/front_agent/model/front_conversation.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_door.dart';
import 'package:lotti/features/front_agent/service/front_chat_service.dart';
import 'package:lotti/features/front_agent/state/front_agent_providers.dart';
import 'package:lotti/features/front_agent/state/front_chat_thread_provider.dart';
import 'package:lotti/features/front_agent/state/front_conversation_providers.dart';
import 'package:lotti/features/front_agent/state/front_inbox_filter.dart';
import 'package:lotti/features/front_agent/state/front_journal_access_provider.dart';
import 'package:lotti/features/front_agent/ui/front_ask_options_row.dart';
import 'package:lotti/features/front_agent/ui/front_chat_header.dart';
import 'package:lotti/features/front_agent/ui/front_chat_pane.dart';
import 'package:lotti/features/front_agent/ui/front_conversation_list.dart';
import 'package:lotti/features/front_agent/ui/front_door_card.dart';
import 'package:lotti/features/front_agent/ui/front_turn_cost_line.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/goal_routes.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../../widget_test_utils.dart';
import '../../agents/test_data/entity_factories.dart';
import '../../ai_consumption/test_utils.dart';

void main() {
  final now = DateTime(2026, 10, 24, 10);
  late MockFrontChatService chatService;
  late MockFrontAgentService agentService;
  late MockFrontFilingService filing;

  setUp(() {
    chatService = MockFrontChatService();
    agentService = MockFrontAgentService();
    filing = MockFrontFilingService();
    when(
      () => agentService.getOrCreate(),
    ).thenAnswer((_) async => makeTestIdentity(id: frontAgentId));
  });

  AgentChatMessage message(
    String id,
    AgentChatRole role,
    String text,
    DateTime at, {
    String? runKey,
  }) => AgentChatMessage(
    id: id,
    role: role,
    text: text,
    createdAt: at,
    runKey: runKey,
  );

  Future<void> pumpPane(
    WidgetTester tester, {
    Future<FrontChatThread> Function()? thread,
    VoidCallback? onClose,
    QueryAccessSnapshot? journalAccess,
    FrontConversationIndex? conversations,
  }) async {
    // The project creation resolves categories through the locator.
    final cache = MockEntitiesCacheService();
    when(() => cache.getCategoryById(any())).thenReturn(null);
    await setUpTestGetIt(
      additionalSetup: () =>
          getIt.registerSingleton<EntitiesCacheService>(cache),
    );
    addTearDown(tearDownTestGetIt);
    // Tall enough that every message of the longest thread is built.
    const window = Size(800, 2400);
    setTestSurfaceSize(tester, window);
    await withClock(Clock.fixed(now), () async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Scaffold(body: FrontChatPane(onClose: onClose ?? () {})),
          mediaQueryData: const MediaQueryData(size: window),
          overrides: [
            frontChatThreadProvider.overrideWith(
              (ref) => (thread ?? () async => FrontChatThread.empty)(),
            ),
            frontAllChatsThreadProvider.overrideWith(
              (ref) => (thread ?? () async => FrontChatThread.empty)(),
            ),
            // Where the user left off: the conversation sends land in.
            frontConversationsProvider.overrideWith(
              (ref) async =>
                  conversations ??
                  FrontConversationIndex(
                    conversations: [
                      FrontConversation(
                        id: 'c-1',
                        title: 'Two things.',
                        lastActivity: now,
                        archived: false,
                      ),
                    ],
                  ),
            ),
            frontChatServiceProvider.overrideWithValue(chatService),
            frontAgentServiceProvider.overrideWithValue(agentService),
            frontFilingServiceProvider.overrideWithValue(filing),
            if (journalAccess != null)
              frontJournalAccessProvider.overrideWith(
                (ref) => Stream.value(journalAccess),
              ),
            configFlagProvider.overrideWith((ref, _) => Stream.value(false)),
            agentConsumptionTotalsProvider(
              frontAgentId,
            ).overrideWith((ref) => const Stream<ConsumptionTotals>.empty()),
            // Only her second turn recorded calls.
            agentRunConsumptionTotalsProvider.overrideWith(
              (ref, run) => Stream.value(
                run.runKey == 'run-2'
                    ? makeConsumptionTotals(
                        callCount: 2,
                        totalTokens: 900,
                        credits: 0.01,
                        energyKwh: 0.002,
                        carbonGCo2: 0.5,
                      )
                    : ConsumptionTotals.empty,
              ),
            ),
          ],
        ),
      );
      // The loading shell spins, so no settle: a few frames let the
      // thread and the composer land.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    });
  }

  testWidgets('an empty thread invites the first question under her header', (
    tester,
  ) async {
    await pumpPane(tester);

    expect(find.byType(FrontChatHeader), findsOneWidget);
    expect(
      find.text(
        'Ask about a task, a goal, a project or a person, or tell what '
        'happened. The right agent answers, and nothing is filed until you '
        'tap.',
      ),
      findsOneWidget,
    );
    expect(find.text('Ask anything…'), findsOneWidget);
  });

  testWidgets('a thread still loading shows a shell', (tester) async {
    await pumpPane(tester, thread: () => Completer<FrontChatThread>().future);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('a thread that failed to load says so', (tester) async {
    await pumpPane(tester, thread: () async => throw StateError('db'));
    expect(
      find.text("Couldn't load this conversation right now."),
      findsOneWidget,
    );
  });

  testWidgets('renders the thread with day dividers, the doors under a routed '
      'turn and chips only under her latest question', (tester) async {
    final doorRecord = FrontDoorRecord(
      segmentIndex: 0,
      text: 'How is the garden?',
      kind: FrontDestinationKind.task,
      destinationId: 'garden',
      ownerTitle: 'Garden',
      status: FrontDoorStatus.done,
      claimedAt: now.toUtc(),
      outcome: const FrontDoorAnswer(
        text: 'The seam walk is next.',
        summaryBased: false,
        incomplete: false,
      ),
    );
    const option = FrontAskOption(
      kind: FrontDestinationKind.goal,
      id: 'goal-a',
      label: 'Swim 2 km',
    );
    await pumpPane(
      tester,
      thread: () async => FrontChatThread(
        messages: [
          message(
            'u0',
            AgentChatRole.user,
            'Old question?',
            DateTime(2026, 10, 20, 9),
          ),
          message(
            'ask0',
            AgentChatRole.agent,
            'Which old one?',
            DateTime(2026, 10, 20, 9, 1),
          ),
          message(
            'u1',
            AgentChatRole.user,
            'How is the garden?',
            DateTime(2026, 10, 23, 9),
          ),
          message(
            'reply1',
            AgentChatRole.agent,
            'I asked the garden agent.',
            DateTime(2026, 10, 23, 9, 1),
            runKey: 'run-1',
          ),
          message('u2', AgentChatRole.user, 'Swim?', DateTime(2026, 10, 24, 9)),
          message(
            'ask2',
            AgentChatRole.agent,
            'Which one?',
            DateTime(2026, 10, 24, 9, 1),
            runKey: 'run-2',
          ),
        ],
        optionsByMessageId: const {
          'ask0': [option],
          'ask2': [option],
        },
        doorsByMessageId: {
          'u1': [FrontDoorEntry(doorId: 'd:door:0', record: doorRecord)],
        },
      ),
    );

    // Three days, three dividers: the date, yesterday, today.
    // The day dividers carry a label; the hairlines inside her bubble do not.
    final dividers = tester
        .widgetList<DesignSystemDivider>(find.byType(DesignSystemDivider))
        .map((d) => d.label)
        .nonNulls
        .toList();
    expect(dividers, ['Tuesday, October 20, 2026', 'Yesterday', 'Today']);
    expect(find.byKey(const ValueKey('goal-chat-divider-u0')), findsOneWidget);
    expect(find.byKey(const ValueKey('goal-chat-divider-ask0')), findsNothing);

    expect(find.byKey(const ValueKey('front-doors-reply1')), findsOneWidget);
    expect(find.byType(FrontDoorCard), findsOneWidget);
    expect(find.text('The seam walk is next.'), findsOneWidget);

    expect(find.byKey(const ValueKey('front-options-ask2')), findsOneWidget);
    expect(find.byKey(const ValueKey('front-options-ask0')), findsNothing);
    expect(find.byType(FrontAskOptionsRow), findsOneWidget);

    // Her turns carry what they cost as the tail of the bubble's footer
    // line, after her name and the time; a wake that recorded no call shows
    // nothing.
    expect(find.byType(FrontTurnCostLine), findsNWidgets(2));
    final cost = find.byKey(const ValueKey('front-turn-cost-run-2'));
    expect(cost, findsOneWidget);
    expect(find.byKey(const ValueKey('front-turn-cost-run-1')), findsNothing);
    expect(tester.widget<Text>(cost).data, startsWith(' · '));
    final bubble = find.byKey(const ValueKey('goal-chat-message-ask2'));
    final footer = find.descendant(
      of: bubble,
      matching: find.textContaining('Companion · '),
    );
    expect(footer, findsOneWidget);
    expect(tester.getCenter(cost).dy, tester.getCenter(footer).dy);
    expect(tester.getTopLeft(cost).dx, tester.getTopRight(footer).dx);
  });

  testWidgets('a chip answers in its own words through the composer', (
    tester,
  ) async {
    when(
      () => chatService.sendMessage(text: 'Swim 2 km', conversationId: 'c-1'),
    ).thenAnswer((_) async {});
    await pumpPane(
      tester,
      thread: () async => FrontChatThread(
        messages: [
          message('ask', AgentChatRole.agent, 'Which one?', now),
        ],
        optionsByMessageId: const {
          'ask': [
            FrontAskOption(
              kind: FrontDestinationKind.goal,
              id: 'goal-a',
              label: 'Swim 2 km',
            ),
          ],
        },
      ),
    );

    await tester.tap(find.text('Swim 2 km'));
    await tester.pumpAndSettle();

    verifyInOrder([
      () => agentService.getOrCreate(),
      () => chatService.sendMessage(text: 'Swim 2 km', conversationId: 'c-1'),
    ]);
  });

  testWidgets('typing and sending goes through the chat service; a failed '
      'turn offers a retry that re-wakes the same turn', (tester) async {
    when(
      () => chatService.sendMessage(text: 'Hello', conversationId: 'c-1'),
    ).thenThrow(
      const FrontChatTurnException('boom', messageId: 'm-1'),
    );
    when(
      () => chatService.retryMessage(messageId: 'm-1'),
    ).thenAnswer((_) async {});
    await pumpPane(tester);

    await tester.enterText(find.byType(TextField), 'Hello');
    await tester.pump();
    await tester.tap(find.byIcon(LottiIcons.send));
    await tester.pumpAndSettle();

    verify(
      () => chatService.sendMessage(text: 'Hello', conversationId: 'c-1'),
    ).called(1);
    expect(find.text("That didn't send."), findsOneWidget);

    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();

    verify(() => chatService.retryMessage(messageId: 'm-1')).called(1);
    expect(find.text("That didn't send."), findsNothing);
  });

  testWidgets('the list of conversations takes the thread’s place while it '
      'is open', (tester) async {
    await pumpPane(tester);
    expect(find.byType(AgentChatView), findsOneWidget);

    await tester.tap(find.byKey(FrontChatHeaderKeys.chats));
    await tester.pump();
    await tester.pump();

    expect(find.byType(FrontConversationList), findsOneWidget);
    expect(find.byType(AgentChatView), findsNothing);
    expect(find.text('Two things.'), findsOneWidget);

    await tester.tap(find.text('Two things.'));
    await tester.pump();
    await tester.pump();

    expect(find.byType(FrontConversationList), findsNothing);
    expect(find.byType(AgentChatView), findsOneWidget);
  });

  testWidgets('the header close hands back to the host', (tester) async {
    var closed = 0;
    await pumpPane(tester, onClose: () => closed++);
    await tester.tap(find.byKey(FrontChatHeaderKeys.close));
    expect(closed, 1);
    expect(find.byType(AgentChatView), findsOneWidget);
  });

  group('the doors', () {
    FrontChatThread waiting() => FrontChatThread(
      messages: [
        message('u1', AgentChatRole.user, 'The hinge arrived.', now),
        message(
          'r1',
          AgentChatRole.agent,
          'Filed? Your call.',
          now,
          runKey: 'run-1',
        ),
        message('u2', AgentChatRole.user, 'Fine.', now),
      ],
      doorsByMessageId: {
        'u1': [
          FrontDoorEntry(
            doorId: 'd:door:0',
            record: FrontDoorRecord(
              segmentIndex: 0,
              text: 'The hinge arrived.',
              kind: FrontDestinationKind.task,
              destinationId: 'garden',
              ownerTitle: 'Garden',
              status: FrontDoorStatus.done,
              claimedAt: now.toUtc(),
              outcome: const FrontDoorProposal(ownerId: 'garden'),
            ),
          ),
        ],
      },
    );

    testWidgets('the one tap under a proposal files through the service', (
      tester,
    ) async {
      when(() => filing.fileUnderTask('d:door:0')).thenAnswer((_) async {});
      await pumpPane(tester, thread: () async => waiting());

      await tester.tap(find.byKey(const ValueKey('front-door-file-0')));
      await tester.pump();
      await tester.pump();

      verify(() => filing.fileUnderTask('d:door:0')).called(1);
    });

    testWidgets('the inbox chip filters the thread to the turns that wait', (
      tester,
    ) async {
      await pumpPane(tester, thread: () async => waiting());
      expect(find.text('Fine.'), findsOneWidget);
      expect(
        tester
            .widget<DesignSystemChip>(find.byKey(FrontChatHeaderKeys.inbox))
            .label,
        'Inbox 1',
      );

      await tester.tap(find.byKey(FrontChatHeaderKeys.inbox));
      await tester.pump();
      await tester.pump();

      expect(find.text('The hinge arrived.'), findsWidgets);
      expect(find.text('Fine.'), findsNothing);
      // Her reply carries the doors, so it stays with the words.
      expect(find.text('Filed? Your call.'), findsOneWidget);

      await tester.tap(find.byKey(FrontChatHeaderKeys.inbox));
      await tester.pump();
      expect(find.text('Fine.'), findsOneWidget);
    });

    testWidgets('with nothing waiting there is no inbox chip', (tester) async {
      await pumpPane(tester);
      expect(find.byKey(FrontChatHeaderKeys.inbox), findsNothing);
    });

    testWidgets('a send leaves the inbox filter, so the new turn lands in '
        'the whole thread', (tester) async {
      when(
        () => chatService.sendMessage(text: 'Hello', conversationId: 'c-1'),
      ).thenAnswer((_) async {});
      await pumpPane(tester, thread: () async => waiting());
      await tester.tap(find.byKey(FrontChatHeaderKeys.inbox));
      await tester.pump();
      await tester.pump();
      expect(find.text('Fine.'), findsNothing);

      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.pump();
      await tester.tap(find.byIcon(LottiIcons.send));
      await tester.pump();
      await tester.pump();

      verify(
        () => chatService.sendMessage(text: 'Hello', conversationId: 'c-1'),
      ).called(1);
      expect(find.text('Fine.'), findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(find.byKey(FrontChatHeaderKeys.inbox)),
      );
      expect(container.read(frontInboxFilterProvider), isFalse);
    });

    testWidgets('a question that carries doors shows them under its bubble, '
        'above its chips', (tester) async {
      await pumpPane(
        tester,
        thread: () async => FrontChatThread(
          messages: [
            message('u1', AgentChatRole.user, 'Garden? And swim?', now),
            message(
              'ask1',
              AgentChatRole.agent,
              'Which swim goal?',
              now.add(const Duration(minutes: 1)),
            ),
          ],
          optionsByMessageId: const {
            'ask1': [
              FrontAskOption(
                kind: FrontDestinationKind.goal,
                id: 'goal-a',
                label: 'Swim 2 km',
              ),
            ],
          },
          doorsByMessageId: {
            'u1': [
              FrontDoorEntry(
                doorId: 'd:door:0',
                record: FrontDoorRecord(
                  segmentIndex: 0,
                  text: 'Garden?',
                  kind: FrontDestinationKind.task,
                  destinationId: 'garden',
                  ownerTitle: 'Garden',
                  status: FrontDoorStatus.done,
                  claimedAt: now.toUtc(),
                  outcome: const FrontDoorAnswer(
                    text: 'Weeded.',
                    summaryBased: false,
                    incomplete: false,
                  ),
                ),
              ),
            ],
          },
        ),
      );

      final bubble = find.byKey(const ValueKey('goal-chat-message-ask1'));
      final doors = find.byKey(const ValueKey('front-doors-ask1'));
      final chips = find.byKey(const ValueKey('front-options-ask1'));
      expect(find.descendant(of: bubble, matching: doors), findsNothing);
      expect(
        tester.getTopLeft(doors).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(bubble).dy),
      );
      expect(
        tester.getTopLeft(chips).dy,
        greaterThan(tester.getBottomLeft(doors).dy),
      );
      expect(find.byKey(const ValueKey('front-doors-u1')), findsNothing);
    });

    testWidgets('open on a settled door leaves the sheet and goes to what '
        'it wrote', (tester) async {
      final paths = <String>[];
      beamToNamedOverride = paths.add;
      addTearDown(() => beamToNamedOverride = null);
      FrontDoorRecord settled(int index, FrontDoorOutcome outcome) =>
          FrontDoorRecord(
            segmentIndex: index,
            text: 'segment $index',
            kind: FrontDestinationKind.unrouted,
            status: FrontDoorStatus.done,
            claimedAt: now.toUtc(),
            outcome: outcome,
          );
      await pumpPane(
        tester,
        thread: () async => FrontChatThread(
          messages: [
            message('u1', AgentChatRole.user, 'Two things.', now),
          ],
          doorsByMessageId: {
            'u1': [
              FrontDoorEntry(
                doorId: 'd:door:0',
                record: settled(0, const FrontDoorFiled(entryId: 'e-1')),
              ),
              FrontDoorEntry(
                doorId: 'd:door:1',
                record: settled(1, const FrontDoorTaskCreated(taskId: 't-1')),
              ),
            ],
          },
        ),
      );

      await tester.tap(find.byKey(const ValueKey('front-door-open-0')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('front-door-open-1')));
      await tester.pump();

      expect(paths, ['/journal/e-1', '/tasks/t-1']);
    });
  });

  testWidgets('a source her journal answer cites leaves the sheet and opens '
      'its own page', (tester) async {
    final paths = <String>[];
    beamToNamedOverride = paths.add;
    addTearDown(() => beamToNamedOverride = null);
    final category = categoryMindfulness;
    final cited = [
      for (final (id, kind) in [
        ('t-1', QuerySourceKind.task),
        ('p-1', QuerySourceKind.project),
        ('e-1', QuerySourceKind.text),
      ])
        QueryEvidence(
          source: QuerySourceRef(
            id: id,
            private: false,
            categoryPrivate: false,
            categoryId: category.id,
          ),
          kind: kind,
          label: 'Source $id',
          sourceDate: DateTime(2026, 10, 20),
          textVersion: 'entryText',
          fingerprint: id,
          sourceText: 'The colony counted the fish stores.',
          start: 0,
          end: 10,
          summary: 'Count',
        ),
    ];
    await pumpPane(
      tester,
      journalAccess: QueryAccessSnapshot(
        showPrivate: false,
        categories: {category.id: category},
        entries: {
          for (final e in cited)
            e.source.id: testTextEntry.copyWith(
              meta: testTextEntry.meta.copyWith(
                id: e.source.id,
                categoryId: category.id,
                private: false,
              ),
            ),
        },
      ),
      thread: () async => FrontChatThread(
        messages: [
          message('u1', AgentChatRole.user, 'What about the stores?', now),
        ],
        doorsByMessageId: {
          'u1': [
            FrontDoorEntry(
              doorId: 'd:door:0',
              record: FrontDoorRecord(
                segmentIndex: 0,
                text: 'What about the stores?',
                kind: FrontDestinationKind.journal,
                status: FrontDoorStatus.done,
                claimedAt: now.toUtc(),
                outcome: FrontDoorAnswer(
                  text: 'Counted [1], planned [2], noted [3].',
                  summaryBased: false,
                  incomplete: false,
                  fromJournal: true,
                  evidence: cited,
                  dependencies: [for (final e in cited) e.source],
                ),
              ),
            ),
          ],
        },
      ),
    );

    for (var i = 0; i < cited.length; i++) {
      await tester.tap(find.byKey(ValueKey('front-door-source-0-$i')));
      await tester.pump();
    }

    expect(paths, ['/tasks/t-1', '/projects/p-1', '/journal/e-1']);
  });

  group('the wizard chips', () {
    FrontChatThread inbox(FrontNewKind kind) => FrontChatThread(
      messages: [
        message('u1', AgentChatRole.user, 'Relocate the colony.', now),
      ],
      doorsByMessageId: {
        'u1': [
          FrontDoorEntry(
            doorId: 'd:door:0',
            record: FrontDoorRecord(
              segmentIndex: 0,
              text: 'Relocate the colony.',
              kind: FrontDestinationKind.newThing,
              status: FrontDoorStatus.done,
              claimedAt: now.toUtc(),
              outcome: FrontDoorInbox(newKind: kind),
            ),
          ),
        ],
      },
    );

    testWidgets('start a goal leaves the sheet and goes to the goal wizard', (
      tester,
    ) async {
      final paths = <String>[];
      beamToNamedOverride = paths.add;
      addTearDown(() => beamToNamedOverride = null);
      await pumpPane(tester, thread: () async => inbox(FrontNewKind.goal));

      await tester.tap(find.byKey(const ValueKey('front-door-menu-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('front-door-goal-0')));
      await tester.pump();

      expect(paths, [goalCreatePath]);
      // Nothing was written: the door still waits.
      verifyNever(() => filing.saveAsNote(any()));
    });

    testWidgets('new project opens the project creation', (tester) async {
      await pumpPane(tester, thread: () async => inbox(FrontNewKind.project));

      await tester.tap(find.byKey(const ValueKey('front-door-menu-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('front-door-project-0')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Create Project'), findsOneWidget);
    });
  });
}
