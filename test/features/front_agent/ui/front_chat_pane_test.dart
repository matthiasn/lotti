import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/query_chat_models.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/query/query_source_access.dart';
import 'package:lotti/features/agents/state/agent_chat_projection.dart';
import 'package:lotti/features/agents/ui/chat/agent_chat_view.dart';
import 'package:lotti/features/agents/ui/chat/chat_recorder_controller.dart';
import 'package:lotti/features/ai_consumption/model/consumption_aggregation_models.dart';
import 'package:lotti/features/ai_consumption/state/consumption_providers.dart';
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
import 'package:lotti/features/front_agent/ui/front_chat_hero.dart';
import 'package:lotti/features/front_agent/ui/front_chat_pane.dart';
import 'package:lotti/features/front_agent/ui/front_conversation_list.dart';
import 'package:lotti/features/front_agent/ui/front_door_card.dart';
import 'package:lotti/features/front_agent/ui/front_door_wizards.dart';
import 'package:lotti/features/front_agent/ui/front_turn_cost_line.dart';
import 'package:lotti/features/projects/ui/widgets/project_create_modal.dart';
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

  /// The composer leads with talking; this swaps in the text field.
  Future<void> typeInstead(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('agent-chat-type-instead')));
    await tester.pump();
  }

  Future<void> pumpPane(
    WidgetTester tester, {
    Future<FrontChatThread> Function()? thread,
    VoidCallback? onClose,
    QueryAccessSnapshot? journalAccess,
    FrontConversationIndex? conversations,
    ChatRecorderController Function()? recorder,
    FrontDayPlanner? planDay,
    FrontNewProject? newProject,
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
            if (recorder != null)
              chatRecorderControllerProvider.overrideWith(recorder),
            if (planDay != null)
              frontDayPlannerProvider.overrideWithValue(planDay),
            if (newProject != null)
              frontNewProjectProvider.overrideWithValue(newProject),
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
    // Voice first: one talk control leads, typing a tap away.
    expect(find.byKey(const Key('agent-chat-talk')), findsOneWidget);
    expect(find.text('Ask anything…'), findsNothing);
    await typeInstead(tester);
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

    // A conversation, not a log: no name-and-time line on each message.
    // Her turns keep what they cost, quietly under her words; a wake that
    // recorded no call shows nothing.
    expect(find.textContaining('Companion · '), findsNothing);
    expect(find.byType(FrontTurnCostLine), findsNWidgets(2));
    final cost = find.byKey(const ValueKey('front-turn-cost-run-2'));
    expect(cost, findsOneWidget);
    expect(find.byKey(const ValueKey('front-turn-cost-run-1')), findsNothing);
    expect(tester.widget<Text>(cost).data, isNot(startsWith(' · ')));
    final bubble = find.byKey(const ValueKey('goal-chat-message-ask2'));
    expect(find.descendant(of: bubble, matching: cost), findsOneWidget);
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

    await typeInstead(tester);
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

  testWidgets('scrolling the thread past her bust puts her and the title in '
      "the header's line", (tester) async {
    var fresh = false;
    await pumpPane(
      tester,
      thread: () async => FrontChatThread(
        messages: [
          for (var i = 0; i < (fresh ? 0 : 80); i++)
            message(
              'm$i',
              i.isEven ? AgentChatRole.user : AgentChatRole.agent,
              'Penguin count $i',
              now,
            ),
        ],
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(FrontChatHeader)),
    );
    final scrolled = container.listen(frontHeroScrolledProvider, (_, _) {});
    addTearDown(scrolled.close);
    final list = find.byType(ListView).first;
    await tester.drag(list, const Offset(0, -600));
    await tester.pump();
    expect(scrolled.read(), isTrue);

    // Another conversation opens at its top, her bust in view: the header
    // lets her go.
    await withClock(Clock.fixed(now), () async {
      container.read(frontPickedConversationProvider.notifier).picked = 'c-2';
      await tester.pump();
      await tester.pump();
    });
    expect(scrolled.read(), isFalse);

    await tester.drag(find.byType(ListView).first, const Offset(0, -600));
    await tester.pump();
    expect(scrolled.read(), isTrue);

    // Back to the top, she leaves the header line again.
    await tester.fling(
      find.byType(ListView).first,
      const Offset(0, 3000),
      5000,
    );
    await tester.pumpAndSettle();
    expect(scrolled.read(), isFalse);

    // Back from the list in the same chat, the thread is where it was left
    // — at its latest message, where nothing moves on the way back — and so
    // is she.
    await tester.drag(find.byType(ListView).first, const Offset(0, -100000));
    await tester.pumpAndSettle();
    expect(scrolled.read(), isTrue);
    await tester.tap(find.byKey(FrontChatHeaderKeys.chats));
    await tester.pump();
    container.read(frontConversationListOpenProvider.notifier).close();
    await tester.pump();
    await tester.pump();
    expect(scrolled.read(), isTrue);

    // A new chat started from the list: the thread was not there to see
    // it, and an empty one has nothing to scroll, yet she stands at its
    // top and the header lets her go.
    await tester.drag(find.byType(ListView).first, const Offset(0, -600));
    await tester.pump();
    expect(scrolled.read(), isTrue);
    await tester.tap(find.byKey(FrontChatHeaderKeys.chats));
    await tester.pump();
    fresh = true;
    container
      ..invalidate(frontChatThreadProvider)
      ..read(frontPickedConversationProvider.notifier).startNew();
    // The new chat is resolved while the list is still up.
    await tester.pump();
    await tester.pump();
    container.read(frontConversationListOpenProvider.notifier).close();
    await tester.pump();
    await tester.pump();
    expect(scrolled.read(), isFalse);
  });

  testWidgets('what is being said stays with its conversation: leaving it '
      'for another lets the recording go', (tester) async {
    final recording = _Recording();
    await pumpPane(tester, recorder: () => recording);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(FrontChatHeader)),
    );

    await withClock(Clock.fixed(now), () async {
      container.read(frontPickedConversationProvider.notifier).picked = 'c-2';
      await tester.pump();
      await tester.pump();
    });

    expect(recording.cancels, 1);
  });

  testWidgets('a recording made as the surface opens is kept while its '
      'conversation resolves — only leaving one lets it go', (tester) async {
    final recording = _Recording();
    await pumpPane(tester, recorder: () => recording);

    // The first conversation resolved during the pump: nothing was left.
    expect(recording.cancels, 0);
    expect(find.byKey(const Key('agent-chat-talk-cancel')), findsOne);
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
      when(() => filing.fileUnderOwner('d:door:0')).thenAnswer((_) async {});
      await pumpPane(tester, thread: () async => waiting());

      await tester.tap(find.byKey(const ValueKey('front-door-file-0')));
      await tester.pump();
      await tester.pump();

      verify(() => filing.fileUnderOwner('d:door:0')).called(1);
    });

    /// Opens the list from the header and the inbox from the list.
    Future<void> openInbox(WidgetTester tester) async {
      await tester.tap(find.byKey(FrontChatHeaderKeys.chats));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byKey(FrontConversationListKeys.inbox));
      await tester.pump();
      await tester.pump();
    }

    testWidgets("the list's inbox filters the thread to the turns that wait, "
        'and the header names it', (tester) async {
      await pumpPane(tester, thread: () async => waiting());
      expect(find.text('Fine.'), findsOneWidget);
      // A dot on the way to the list says something waits.
      expect(find.byKey(FrontChatHeaderKeys.inbox), findsOneWidget);

      await openInbox(tester);

      expect(
        tester.widget<Text>(find.byKey(FrontChatHeaderKeys.title)).data,
        'Inbox',
      );
      expect(find.text('The hinge arrived.'), findsWidgets);
      expect(find.text('Fine.'), findsNothing);
      // Her reply carries the doors, so it stays with the words.
      expect(find.text('Filed? Your call.'), findsOneWidget);

      // Opening a conversation from the list leaves the inbox.
      await tester.tap(find.byKey(FrontChatHeaderKeys.chats));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('Two things.'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Fine.'), findsOneWidget);
    });

    testWidgets('back leaves the list, then the inbox, before the sheet', (
      tester,
    ) async {
      var closed = 0;
      await pumpPane(
        tester,
        thread: () async => waiting(),
        onClose: () => closed++,
      );
      await openInbox(tester);
      await tester.tap(find.byKey(FrontChatHeaderKeys.chats));
      await tester.pump();
      await tester.pump();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(FrontChatHeader)),
      );

      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(FrontConversationList), findsNothing);
      expect(container.read(frontInboxFilterProvider), isTrue);

      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(container.read(frontInboxFilterProvider), isFalse);
      expect(find.text('Fine.'), findsOneWidget);
    });

    testWidgets('with nothing waiting there is no inbox dot', (tester) async {
      await pumpPane(tester);
      expect(find.byKey(FrontChatHeaderKeys.inbox), findsNothing);
    });

    testWidgets('a send leaves the inbox filter, so the new turn lands in '
        'its conversation', (tester) async {
      when(
        () => chatService.sendMessage(text: 'Hello', conversationId: 'c-1'),
      ).thenAnswer((_) async {});
      await pumpPane(tester, thread: () async => waiting());
      await openInbox(tester);
      expect(find.text('Fine.'), findsNothing);

      await typeInstead(tester);
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
        tester.element(find.byType(FrontChatHeader)),
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

    testWidgets('start a goal leaves the sheet and goes to the goal wizard, '
        'with the words as its intention', (tester) async {
      final paths = <String>[];
      beamToNamedOverride = paths.add;
      addTearDown(() => beamToNamedOverride = null);
      await pumpPane(tester, thread: () async => inbox(FrontNewKind.goal));

      await tester.tap(find.byKey(const ValueKey('front-door-menu-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('front-door-goal-0')));
      await tester.pump();

      expect(paths, [goalCreatePathWith(intention: 'Relocate the colony.')]);
      // Nothing was written: the door still waits.
      verifyNever(() => filing.saveAsNote(any()));
    });

    testWidgets('new project opens the project creation, titled with the '
        'words', (tester) async {
      await pumpPane(tester, thread: () async => inbox(FrontNewKind.project));

      await tester.tap(find.byKey(const ValueKey('front-door-menu-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('front-door-project-0')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Create Project'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ProjectCreateForm),
          matching: find.text('Relocate the colony.'),
        ),
        findsOne,
      );
      verifyNever(() => filing.markProjectCreated(any(), any()));
    });

    testWidgets('a project the form created settles the item on it; a form '
        'closed settles nothing', (tester) async {
      String? created = 'p-1';
      final asked = <String>[];
      when(
        () => filing.markProjectCreated('d:door:0', 'p-1'),
      ).thenAnswer((_) async {});
      await pumpPane(
        tester,
        thread: () async => inbox(FrontNewKind.project),
        newProject: (context, words) async {
          asked.add(words);
          return created;
        },
      );

      Future<void> choose() async {
        await tester.tap(find.byKey(const ValueKey('front-door-menu-0')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('front-door-project-0')));
        await tester.pumpAndSettle();
      }

      await choose();
      expect(asked, ['Relocate the colony.']);
      verify(() => filing.markProjectCreated('d:door:0', 'p-1')).called(1);

      created = null;
      await choose();
      verifyNever(() => filing.markProjectCreated(any(), any()));
    });
  });

  group('a change to today', () {
    FrontChatThread today() => FrontChatThread(
      messages: [
        message('u1', AgentChatRole.user, 'Move the count.', now),
      ],
      doorsByMessageId: {
        'u1': [
          FrontDoorEntry(
            doorId: 'd:door:0',
            record: FrontDoorRecord(
              segmentIndex: 0,
              text: 'Move the count.',
              kind: FrontDestinationKind.day,
              status: FrontDoorStatus.done,
              claimedAt: now.toUtc(),
              outcome: const FrontDoorDay(),
            ),
          ),
        ],
      },
    );

    testWidgets('takes the words into the planning, and settles once a plan '
        'was accepted there', (tester) async {
      var accepted = true;
      final asked = <String>[];
      when(() => filing.markDayPlanned('d:door:0')).thenAnswer((_) async {});
      await pumpPane(
        tester,
        thread: () async => today(),
        planDay: (context, words) async {
          asked.add(words);
          return accepted;
        },
      );

      await tester.tap(find.byKey(const ValueKey('front-door-day-0')));
      await tester.pump();
      expect(asked, ['Move the count.']);
      verify(() => filing.markDayPlanned('d:door:0')).called(1);

      accepted = false;
      await tester.tap(find.byKey(const ValueKey('front-door-day-0')));
      await tester.pump();
      expect(asked, hasLength(2));
      verifyNever(() => filing.markDayPlanned(any()));
    });
  });
}

/// A recorder in the middle of listening, counting the cancels it gets.
class _Recording extends ChatRecorderController {
  int cancels = 0;

  @override
  ChatRecorderState build() => const ChatRecorderState(
    status: ChatRecorderStatus.recording,
    amplitudeHistory: [],
  );

  @override
  Future<void> cancel() async {
    cancels++;
    state = const ChatRecorderState.initial();
  }
}
