import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/query_chat_models.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/query/query_source_access.dart';
import 'package:lotti/features/agents/state/agent_chat_projection.dart';
import 'package:lotti/features/agents/ui/chat/agent_chat_view.dart';
import 'package:lotti/features/agents/ui/chat/chat_recorder_controller.dart';
import 'package:lotti/features/ai/state/subject_dictation_providers.dart';
import 'package:lotti/features/ai/util/inference_provider_resolver.dart';
import 'package:lotti/features/ai_consumption/model/consumption_aggregation_models.dart';
import 'package:lotti/features/ai_consumption/state/consumption_providers.dart';
import 'package:lotti/features/daily_os_next/state/selected_date_provider.dart';
import 'package:lotti/features/design_system/components/chat_input/design_system_chat_input.dart';
import 'package:lotti/features/design_system/components/dividers/design_system_divider.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/front_agent/model/front_agent_identity.dart';
import 'package:lotti/features/front_agent/model/front_chat_thread.dart';
import 'package:lotti/features/front_agent/model/front_closed_task_card.dart';
import 'package:lotti/features/front_agent/model/front_conversation.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_door.dart';
import 'package:lotti/features/front_agent/model/front_logged_time_chart.dart';
import 'package:lotti/features/front_agent/model/front_pull_requests.dart';
import 'package:lotti/features/front_agent/model/front_turn_failure.dart';
import 'package:lotti/features/front_agent/service/front_chat_service.dart';
import 'package:lotti/features/front_agent/state/front_agent_providers.dart';
import 'package:lotti/features/front_agent/state/front_chat_thread_provider.dart';
import 'package:lotti/features/front_agent/state/front_conversation_providers.dart';
import 'package:lotti/features/front_agent/state/front_inbox_filter.dart';
import 'package:lotti/features/front_agent/state/front_journal_access_provider.dart';
import 'package:lotti/features/front_agent/state/front_mention_categories.dart';
import 'package:lotti/features/front_agent/ui/front_ask_options_row.dart';
import 'package:lotti/features/front_agent/ui/front_chat_header.dart';
import 'package:lotti/features/front_agent/ui/front_chat_hero.dart';
import 'package:lotti/features/front_agent/ui/front_chat_pane.dart';
import 'package:lotti/features/front_agent/ui/front_conversation_list.dart';
import 'package:lotti/features/front_agent/ui/front_door_card.dart';
import 'package:lotti/features/front_agent/ui/front_door_wizards.dart';
import 'package:lotti/features/front_agent/ui/front_logged_time_chart_card.dart';
import 'package:lotti/features/front_agent/ui/front_pull_request_chart_card.dart';
import 'package:lotti/features/front_agent/ui/front_task_list.dart';
import 'package:lotti/features/front_agent/ui/front_turn_cost_line.dart';
import 'package:lotti/features/insights/model/insights_models.dart';
import 'package:lotti/features/projects/ui/widgets/project_create_modal.dart';
import 'package:lotti/features/tasks/state/task_preview_provider.dart';
import 'package:lotti/features/tasks/ui/pages/task_details_page.dart';
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
import '../../categories/test_utils.dart';

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

  /// Taps [target] and expects [taskId]'s page pushed on top of her, nothing
  /// beamed, and back — a pop — landing on her conversation again.
  Future<void> expectTaskOpensOverPane(
    WidgetTester tester,
    _PushObserver observer,
    Finder target,
    String taskId,
    List<String> beamed,
  ) async {
    observer.pushed.clear();
    await tester.tap(target);

    final route = observer.pushed.whereType<MaterialPageRoute<void>>().single;
    // The builder, not the built page: TaskDetailsPage needs the whole app.
    expect(
      route.builder(tester.element(find.byType(FrontChatPane))),
      isA<TaskDetailsPage>().having((p) => p.taskId, 'taskId', taskId),
    );
    expect(beamed, isEmpty);
    // She stays under the page, so back has somewhere to land.
    expect(find.byType(FrontChatPane), findsOne);

    // Popped before it ever builds; back is that pop.
    route.navigator!.pop();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(FrontChatPane), findsOne);
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
    Future<ResolvedInferenceProvider> Function()? dictationTarget,
    bool pushed = false,
    List<NavigatorObserver> navigatorObservers = const [],
    List<CategoryDefinition>? mentionCategories,
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
    // Pushed, the pane sits on a route of its own over the app, as her
    // surface does, so leaving it can be seen.
    final navigator = GlobalKey<NavigatorState>();
    // Her surface closes by popping its route, which back's PopScope does
    // not hold.
    final pane = Scaffold(
      body: FrontChatPane(
        onClose:
            onClose ??
            () {
              if (pushed) navigator.currentState!.pop();
            },
      ),
    );
    await withClock(Clock.fixed(now), () async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          pushed ? const SizedBox.shrink() : pane,
          navigatorKey: navigator,
          navigatorObservers: navigatorObservers,
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
            if (mentionCategories != null)
              frontMentionCategoriesProvider.overrideWithValue(
                mentionCategories,
              ),
            // The tasks her lists name: none loads, so each row keeps the
            // title she gave it.
            taskPreviewProvider.overrideWith((ref, id) async => null),
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
            if (dictationTarget != null)
              settingsDefaultDictationTargetProvider.overrideWithValue(
                dictationTarget,
              ),
          ],
        ),
      );
      if (pushed) {
        navigator.currentState!
            .push(MaterialPageRoute<void>(builder: (_) => pane))
            .ignore();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      }
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
    // One field for typing and talking: the mic at its end, no mode to
    // switch first.
    expect(find.text('Ask anything…'), findsOneWidget);
    expect(find.byIcon(LottiIcons.mic), findsOneWidget);
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

    await tester.enterText(find.byType(TextField), 'Hello');
    await tester.pump();
    await tester.tap(find.byIcon(LottiIcons.arrowUp));
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

  for (final (failure, line) in [
    (
      FrontTurnFailure.rateLimit,
      'Your AI provider is limiting requests right now. Wait a moment, '
          'then try again.',
    ),
    (
      FrontTurnFailure.noAnswer,
      "The companion didn't finish an answer. Try again, or put it another "
          'way.',
    ),
    (
      FrontTurnFailure.timeout,
      'Your AI provider took too long to answer. Try again.',
    ),
    (
      FrontTurnFailure.network,
      "Couldn't reach your AI provider. Check your connection, then try "
          'again.',
    ),
    (
      FrontTurnFailure.authentication,
      'Your AI provider refused its API key. Check it in Settings.',
    ),
    (
      FrontTurnFailure.provider,
      'Your AI provider answered with an error. Try again in a moment.',
    ),
    (
      FrontTurnFailure.noModel,
      'No AI model is set up for the companion. Choose one in Settings.',
    ),
    (FrontTurnFailure.unknown, "That didn't send."),
  ]) {
    testWidgets('a turn that failed for $failure says why beside the retry, '
        'instead of a bare "that did not send"', (tester) async {
      when(
        () => chatService.sendMessage(text: 'Hello', conversationId: 'c-1'),
      ).thenThrow(
        FrontChatTurnException('boom', messageId: 'm-1', failure: failure),
      );
      await pumpPane(tester);

      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.pump();
      await tester.tap(find.byIcon(LottiIcons.arrowUp));
      await tester.pumpAndSettle();

      expect(find.text(line), findsOneWidget);
      // Only a cause nobody can act on falls back to the bare line.
      expect(
        find.text("That didn't send."),
        failure == FrontTurnFailure.unknown ? findsOneWidget : findsNothing,
      );
      expect(find.text('Try Again'), findsOneWidget);
    });
  }

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

  testWidgets('a begun conversation leads with its first message — she is '
      'in the header — and one not begun greets with her figure', (
    tester,
  ) async {
    var fresh = false;
    await pumpPane(
      tester,
      thread: () async => FrontChatThread(
        messages: [
          if (!fresh) message('m0', AgentChatRole.user, 'Penguin count 0', now),
        ],
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(FrontChatHeader)),
    );
    expect(find.byKey(FrontChatHeroKeys.hero), findsNothing);
    final header = tester.getRect(find.byType(FrontChatHeader));
    final first = tester.getRect(find.text('Penguin count 0'));
    expect(first.top - header.bottom, lessThan(ControlSizes.avatarHero));

    fresh = true;
    container
      ..invalidate(frontChatThreadProvider)
      ..read(frontPickedConversationProvider.notifier).startNew();
    await tester.pump();
    await tester.pump();

    expect(find.byKey(FrontChatHeroKeys.hero), findsOne);
  });

  testWidgets('the thread and the field under it keep to one reading '
      'column on a wide window, their edges lined up', (tester) async {
    tester.view
      ..physicalSize = const Size(1400, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpPane(
      tester,
      thread: () async => FrontChatThread(
        messages: [message('m0', AgentChatRole.user, 'Penguin count 0', now)],
      ),
    );

    final field = tester.getRect(find.byKey(DesignSystemChatInputKeys.card));
    final view = tester.widget<AgentChatView>(find.byType(AgentChatView));
    expect(view.contentMaxWidth, kProseMeasureWidth);
    expect(field.width, lessThanOrEqualTo(kProseMeasureWidth));
    // Centred in the pane, as the thread's column is.
    final pane = tester.getRect(find.byType(AgentChatView));
    expect(field.center.dx, closeTo(pane.center.dx, 1));
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
    expect(
      find.descendant(
        of: find.byType(AgentChatView),
        matching: find.byIcon(LottiIcons.close),
      ),
      findsOne,
    );
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

    testWidgets('a task linked in an answer opens on top of her from the '
        'inbox too, and back returns to the inbox', (tester) async {
      final paths = <String>[];
      beamToNamedOverride = paths.add;
      addTearDown(() => beamToNamedOverride = null);
      final observer = _PushObserver();
      final base = waiting();
      await pumpPane(
        tester,
        pushed: true,
        navigatorObservers: [observer],
        thread: () async => FrontChatThread(
          messages: base.messages,
          doorsByMessageId: {
            'u1': [
              ...base.doorsByMessageId['u1']!,
              FrontDoorEntry(
                doorId: 'd:door:1',
                record: FrontDoorRecord(
                  segmentIndex: 1,
                  text: 'What is next?',
                  kind: FrontDestinationKind.task,
                  destinationId: 'garden',
                  ownerTitle: 'Garden',
                  status: FrontDoorStatus.done,
                  claimedAt: now.toUtc(),
                  outcome: const FrontDoorAnswer(
                    text: 'Then [Feed the penguins](lotti://task/t-9).',
                    summaryBased: false,
                    incomplete: false,
                  ),
                ),
              ),
            ],
          },
        ),
      );
      await openInbox(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(FrontChatPane)),
      );
      expect(container.read(frontInboxFilterProvider), isTrue);

      await expectTaskOpensOverPane(
        tester,
        observer,
        find
            .descendant(
              of: find.byKey(const ValueKey('front-door-text-1')),
              matching: find.textContaining(
                'Feed the penguins',
                findRichText: true,
              ),
            )
            .last,
        't-9',
        paths,
      );
      expect(container.read(frontInboxFilterProvider), isTrue);
    });

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

      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.pump();
      await tester.tap(find.byIcon(LottiIcons.arrowUp));
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
              FrontDoorEntry(
                doorId: 'd:door:2',
                record: settled(
                  2,
                  const FrontDoorProjectCreated(projectId: 'p-1'),
                ),
              ),
              FrontDoorEntry(
                doorId: 'd:door:3',
                record: settled(
                  3,
                  FrontDoorDayPlanned(day: DateTime(2026, 10, 30)),
                ),
              ),
            ],
          },
        ),
      );

      await tester.tap(find.byKey(const ValueKey('front-door-open-0')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('front-door-open-1')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('front-door-open-2')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('front-door-open-3')));
      await tester.pump();

      // The day it planned is the Daily OS day surface, showing that day.
      expect(paths, [
        '/journal/e-1',
        '/tasks/t-1',
        '/projects/p-1',
        '/calendar',
      ]);
      expect(
        ProviderScope.containerOf(
          tester.element(find.byType(FrontChatPane)),
        ).read(dailyOsNextSelectedDateProvider),
        DateTime(2026, 10, 30),
      );
    });
  });

  testWidgets('a task she names as a link opens on top of her, and back '
      'returns to her', (tester) async {
    final paths = <String>[];
    beamToNamedOverride = paths.add;
    addTearDown(() => beamToNamedOverride = null);
    final observer = _PushObserver();
    await pumpPane(
      tester,
      pushed: true,
      navigatorObservers: [observer],
      thread: () async => FrontChatThread(
        messages: [
          message('u1', AgentChatRole.user, 'What is due today?', now),
          message(
            'a1',
            AgentChatRole.agent,
            'Due today: [Feed the penguins](lotti://task/t-9).',
            now,
          ),
        ],
      ),
    );
    expect(find.byType(FrontChatPane), findsOneWidget);

    await expectTaskOpensOverPane(
      tester,
      observer,
      find.textContaining('Feed the penguins', findRichText: true).last,
      't-9',
      paths,
    );
  });

  testWidgets('a list of tasks in her words is drawn as task rows, her words '
      'around it kept; a row opens its task on top of her', (
    tester,
  ) async {
    final paths = <String>[];
    beamToNamedOverride = paths.add;
    addTearDown(() => beamToNamedOverride = null);
    final observer = _PushObserver();
    await pumpPane(
      tester,
      pushed: true,
      navigatorObservers: [observer],
      thread: () async => FrontChatThread(
        messages: [
          message('u1', AgentChatRole.user, 'What is due today?', now),
          message(
            'a1',
            AgentChatRole.agent,
            'Two things:\n\n'
                '- [Feed the penguins](lotti://task/t-9)\n'
                '- [Count the eggs](lotti://task/t-8)\n\n'
                'Eggs first.',
            now,
          ),
        ],
      ),
    );

    final list = tester.widget<FrontTaskList>(find.byType(FrontTaskList));
    expect(list.tasks.map((t) => t.id), ['t-9', 't-8']);
    final words = tester.getTopLeft(
      find.textContaining('Two things:', findRichText: true),
    );
    final card = tester.getRect(find.byKey(FrontTaskListKeys.card));
    final after = tester.getTopLeft(
      find.textContaining('Eggs first.', findRichText: true),
    );
    expect(words.dy, lessThan(card.top));
    expect(after.dy, greaterThan(card.bottom));

    await expectTaskOpensOverPane(
      tester,
      observer,
      find.byKey(FrontTaskListKeys.row('t-8')),
      't-8',
      paths,
    );
  });

  testWidgets('an overdue list, emphasised and dated, is task rows too, and '
      'a row opens its task on top of her', (tester) async {
    final paths = <String>[];
    beamToNamedOverride = paths.add;
    addTearDown(() => beamToNamedOverride = null);
    final observer = _PushObserver();
    await pumpPane(
      tester,
      pushed: true,
      navigatorObservers: [observer],
      thread: () async => FrontChatThread(
        messages: [
          message('u1', AgentChatRole.user, 'Anything overdue?', now),
          message(
            'a1',
            AgentChatRole.agent,
            'Overdue:\n'
                '- **[Feed the penguins](lotti://task/t-9)**, due 2026-10-20\n'
                '- [Count the eggs](lotti://task/t-8) (overdue)',
            now,
          ),
        ],
      ),
    );

    final list = tester.widget<FrontTaskList>(find.byType(FrontTaskList));
    expect(list.tasks.map((t) => t.id), ['t-9', 't-8']);

    await expectTaskOpensOverPane(
      tester,
      observer,
      find.byKey(FrontTaskListKeys.row('t-9')),
      't-9',
      paths,
    );
  });

  testWidgets('an answer about what was closed draws every task it found as '
      'cards under her words, none twice, and a card opens its task on top '
      'of her', (tester) async {
    final paths = <String>[];
    beamToNamedOverride = paths.add;
    addTearDown(() => beamToNamedOverride = null);
    final observer = _PushObserver();
    final cards = [
      FrontClosedTaskCard(
        id: 't-9',
        title: 'Feed the penguins',
        closedAt: DateTime(2026, 11, 7, 10),
      ),
      FrontClosedTaskCard(
        id: 't-8',
        title: 'Count the eggs',
        closedAt: DateTime(2026, 11, 8, 11),
        rejected: true,
      ),
      FrontClosedTaskCard(
        id: 't-7',
        title: 'Sweep the ice',
        closedAt: DateTime(2026, 11, 8, 12),
      ),
    ];
    await pumpPane(
      tester,
      pushed: true,
      navigatorObservers: [observer],
      thread: () async => FrontChatThread(
        messages: [
          message(
            'u1',
            AgentChatRole.user,
            'What was closed this weekend?',
            now,
          ),
          // Her words still list two of them, as the bug report's reply did.
          message(
            'a1',
            AgentChatRole.agent,
            'Two completed, one rejected:\n\n'
                '- [Feed the penguins](lotti://task/t-9)\n'
                '- [Sweep the ice](lotti://task/t-7)\n\n'
                'Nothing else.',
            now,
          ),
        ],
        closedTasksByMessageId: {'a1': cards},
      ),
    );

    final list = tester.widget<FrontClosedTaskList>(
      find.byType(FrontClosedTaskList),
    );
    expect(list.tasks, cards);
    // The two her words listed are not drawn again as task rows.
    expect(find.byType(FrontTaskList), findsNothing);
    final words = tester.getTopLeft(
      find.textContaining('Two completed', findRichText: true),
    );
    expect(
      words.dy,
      lessThan(tester.getRect(find.byKey(FrontTaskListKeys.closedCard)).top),
    );

    await expectTaskOpensOverPane(
      tester,
      observer,
      find.byKey(FrontTaskListKeys.closedRow('t-8')),
      't-8',
      paths,
    );
  });

  testWidgets('an answer about logged time draws its chart under her words; '
      'a reply without one draws none', (tester) async {
    const chart = FrontLoggedTimeChart(
      range: InsightsRange(startDay: 20396, endDayExclusive: 20403),
      categoryIds: {},
    );
    await pumpPane(
      tester,
      thread: () async => FrontChatThread(
        messages: [
          message('u1', AgentChatRole.user, 'Time this week?', now),
          message('a1', AgentChatRole.agent, '12h this week.', now),
          message('u2', AgentChatRole.user, 'Thanks', now),
          message('a2', AgentChatRole.agent, 'Any time.', now),
        ],
        loggedTimeByMessageId: const {'a1': chart},
      ),
    );

    final card = find.byType(FrontLoggedTimeChartCard);
    expect(tester.widget<FrontLoggedTimeChartCard>(card).chart, chart);
    expect(
      tester.getTopLeft(card).dy,
      greaterThan(
        tester
            .getTopLeft(
              find.textContaining('12h this week.', findRichText: true),
            )
            .dy,
      ),
    );
    expect(
      tester.getTopLeft(card).dy,
      lessThan(
        tester.getTopLeft(find.textContaining('Thanks', findRichText: true)).dy,
      ),
    );
  });

  testWidgets('an answer about pull requests draws its charts under her '
      'words; a reply without one draws none', (tester) async {
    const chart = FrontPullRequestChart(
      range: InsightsRange(startDay: 20396, endDayExclusive: 20410),
      categoryIds: {},
    );
    await pumpPane(
      tester,
      thread: () async => FrontChatThread(
        messages: [
          message('u1', AgentChatRole.user, 'PRs in two weeks?', now),
          message('a1', AgentChatRole.agent, 'You created 12 PRs.', now),
          message('u2', AgentChatRole.user, 'Thanks', now),
          message('a2', AgentChatRole.agent, 'Any time.', now),
        ],
        pullRequestsByMessageId: const {'a1': chart},
      ),
    );

    final card = find.byType(FrontPullRequestChartCard);
    expect(tester.widget<FrontPullRequestChartCard>(card).chart, chart);
    expect(
      tester.getTopLeft(card).dy,
      greaterThan(
        tester
            .getTopLeft(
              find.textContaining('You created 12 PRs.', findRichText: true),
            )
            .dy,
      ),
    );
    expect(
      tester.getTopLeft(card).dy,
      lessThan(
        tester.getTopLeft(find.textContaining('Thanks', findRichText: true)).dy,
      ),
    );
  });

  testWidgets('@ offers the categories she may see, and the field says so; '
      'with none, it says nothing about @', (tester) async {
    await pumpPane(
      tester,
      mentionCategories: [
        CategoryTestUtils.createTestCategory(
          id: 'colony',
          name: 'Colony',
          color: '#4CAF93',
        ),
      ],
    );
    var input = tester.widget<DesignSystemChatInput>(
      find.byType(DesignSystemChatInput),
    );
    expect(input.mentionOptions.single.label, 'Colony');
    expect(input.mentionOptions.single.color, const Color(0xFF4CAF93));
    expect(input.helperText, 'Type @ to name a category');

    await pumpPane(tester, mentionCategories: const <CategoryDefinition>[]);
    input = tester.widget<DesignSystemChatInput>(
      find.byType(DesignSystemChatInput),
    );
    expect(input.mentionOptions, isEmpty);
    expect(input.helperText, isNull);
  });

  testWidgets('a reply with no list of tasks has no task rows', (tester) async {
    await pumpPane(
      tester,
      thread: () async => FrontChatThread(
        messages: [
          message('a1', AgentChatRole.agent, 'Nothing is due today.', now),
        ],
      ),
    );

    expect(find.byType(FrontTaskList), findsNothing);
    expect(
      find.textContaining('Nothing is due today.', findRichText: true),
      findsOne,
    );
  });

  testWidgets('a date she copied from her tools shows as the device writes '
      "it; the user's own words stay as typed", (tester) async {
    await pumpPane(
      tester,
      thread: () async => FrontChatThread(
        messages: [
          message('u1', AgentChatRole.user, 'Since 2026-03-01?', now),
          message(
            'a1',
            AgentChatRole.agent,
            'Fix the fence was due 2026-03-17.',
            now,
          ),
        ],
      ),
    );

    expect(
      find.textContaining('was due 3/17/2026.', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('2026-03-17', findRichText: true), findsNothing);
    expect(find.text('Since 2026-03-01?'), findsOneWidget);
  });

  testWidgets('a link the app does not route keeps her open and goes '
      'nowhere', (tester) async {
    final paths = <String>[];
    beamToNamedOverride = paths.add;
    addTearDown(() => beamToNamedOverride = null);
    await pumpPane(
      tester,
      pushed: true,
      thread: () async => FrontChatThread(
        messages: [
          message('u1', AgentChatRole.user, 'How is swimming going?', now),
          message(
            'a1',
            AgentChatRole.agent,
            'Ask [the swim goal](lotti://goal/g-1).',
            now,
          ),
        ],
      ),
    );

    await tester.tap(
      find.textContaining('the swim goal', findRichText: true).last,
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(paths, isEmpty);
    expect(find.byType(FrontChatPane), findsOneWidget);
  });

  testWidgets("a task named in an owner's answer opens on top of her, and "
      'back returns to her', (tester) async {
    final paths = <String>[];
    beamToNamedOverride = paths.add;
    addTearDown(() => beamToNamedOverride = null);
    final observer = _PushObserver();
    await pumpPane(
      tester,
      pushed: true,
      navigatorObservers: [observer],
      thread: () async => FrontChatThread(
        messages: [
          message('u1', AgentChatRole.user, 'What is left?', now),
        ],
        doorsByMessageId: {
          'u1': [
            FrontDoorEntry(
              doorId: 'd:door:0',
              record: FrontDoorRecord(
                segmentIndex: 0,
                text: 'What is left?',
                kind: FrontDestinationKind.task,
                destinationId: 'census',
                ownerTitle: 'Penguin census',
                status: FrontDoorStatus.done,
                claimedAt: now.toUtc(),
                outcome: const FrontDoorAnswer(
                  text: 'Then [Feed the penguins](lotti://task/t-9).',
                  summaryBased: false,
                  incomplete: false,
                ),
              ),
            ),
          ],
        },
      ),
    );

    await expectTaskOpensOverPane(
      tester,
      observer,
      find
          .descendant(
            of: find.byKey(const ValueKey('front-door-text-0')),
            matching: find.textContaining(
              'Feed the penguins',
              findRichText: true,
            ),
          )
          .last,
      't-9',
      paths,
    );
  });

  testWidgets('dictation goes to the Settings default transcription slot, '
      'the words as heard', (tester) async {
    Future<ResolvedInferenceProvider> target() async =>
        throw UnimplementedError();
    await pumpPane(tester, dictationTarget: target);

    final view = tester.widget<AgentChatView>(find.byType(AgentChatView));
    // An explicit route, so no on-device engine is discovered for her...
    expect(view.resolveTranscriptionTarget, same(target));
    // ...and no correction pass keeps the question waiting.
    expect(view.correctTranscript, isNull);
  });

  testWidgets('a source her journal answer cites opens its own page, a task '
      'on top of her', (tester) async {
    final paths = <String>[];
    beamToNamedOverride = paths.add;
    addTearDown(() => beamToNamedOverride = null);
    final observer = _PushObserver();
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
      navigatorObservers: [observer],
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

    // A task opens on top of her, as every task she names does...
    await expectTaskOpensOverPane(
      tester,
      observer,
      find.byKey(const ValueKey('front-door-source-0-0')),
      't-1',
      paths,
    );
    // ...any other source leaves her for its own page.
    for (var i = 1; i < cited.length; i++) {
      await tester.tap(find.byKey(ValueKey('front-door-source-0-$i')));
      await tester.pump();
    }

    expect(paths, ['/projects/p-1', '/journal/e-1']);
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

    testWidgets('make it a task makes the task through the filing service', (
      tester,
    ) async {
      when(() => filing.makeTask('d:door:0')).thenAnswer((_) async {});
      await pumpPane(tester, thread: () async => inbox(FrontNewKind.task));

      await tester.tap(find.byKey(const ValueKey('front-door-task-0')));
      await tester.pump();
      await tester.pump();

      verify(() => filing.makeTask('d:door:0')).called(1);
    });

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

    testWidgets('takes the words into the planning, and settles on the day '
        'a plan was accepted for', (tester) async {
      final day = DateTime(2026, 10, 31);
      DateTime? accepted = day;
      final asked = <String>[];
      when(
        () => filing.markDayPlanned('d:door:0', day),
      ).thenAnswer((_) async {});
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
      verify(() => filing.markDayPlanned('d:door:0', day)).called(1);

      accepted = null;
      await tester.tap(find.byKey(const ValueKey('front-door-day-0')));
      await tester.pump();
      expect(asked, hasLength(2));
      verifyNever(() => filing.markDayPlanned(any(), any()));
    });

    testWidgets('a second tap while the planning is open opens no second '
        'one', (tester) async {
      final open = Completer<DateTime?>();
      var opened = 0;
      await pumpPane(
        tester,
        thread: () async => today(),
        planDay: (context, words) {
          opened++;
          return open.future;
        },
      );

      await tester.tap(find.byKey(const ValueKey('front-door-day-0')));
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('front-door-day-0')),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(opened, 1);

      open.complete(null);
      await tester.pump();
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

/// Records the routes pushed, so a test can read a page's route without
/// building the page.
class _PushObserver extends NavigatorObserver {
  final List<Route<dynamic>> pushed = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      pushed.add(route);
}
