import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
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
import 'package:lotti/features/companion/state/companion_card_controller.dart';
import 'package:lotti/features/companion/ui/companion_floating_card.dart';
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
import 'package:lotti/features/front_agent/model/front_due_section.dart';
import 'package:lotti/features/front_agent/model/front_entity_preview.dart';
import 'package:lotti/features/front_agent/model/front_logged_time_chart.dart';
import 'package:lotti/features/front_agent/model/front_pull_requests.dart';
import 'package:lotti/features/front_agent/model/front_reply_layout.dart';
import 'package:lotti/features/front_agent/model/front_routing_index.dart';
import 'package:lotti/features/front_agent/model/front_turn_failure.dart';
import 'package:lotti/features/front_agent/service/front_chat_service.dart';
import 'package:lotti/features/front_agent/state/front_agent_providers.dart';
import 'package:lotti/features/front_agent/state/front_chat_thread_provider.dart';
import 'package:lotti/features/front_agent/state/front_conversation_providers.dart';
import 'package:lotti/features/front_agent/state/front_entity_preview_provider.dart';
import 'package:lotti/features/front_agent/state/front_inbox_filter.dart';
import 'package:lotti/features/front_agent/state/front_journal_access_provider.dart';
import 'package:lotti/features/front_agent/state/front_mention_categories.dart';
import 'package:lotti/features/front_agent/ui/front_ask_options_row.dart';
import 'package:lotti/features/front_agent/ui/front_category_chip.dart';
import 'package:lotti/features/front_agent/ui/front_chat_drawer.dart';
import 'package:lotti/features/front_agent/ui/front_chat_header.dart';
import 'package:lotti/features/front_agent/ui/front_chat_hero.dart';
import 'package:lotti/features/front_agent/ui/front_chat_pane.dart';
import 'package:lotti/features/front_agent/ui/front_conversation_list.dart';
import 'package:lotti/features/front_agent/ui/front_door_card.dart';
import 'package:lotti/features/front_agent/ui/front_door_wizards.dart';
import 'package:lotti/features/front_agent/ui/front_entity_preview_card.dart';
import 'package:lotti/features/front_agent/ui/front_logged_time_chart_card.dart';
import 'package:lotti/features/front_agent/ui/front_pull_request_chart_card.dart';
import 'package:lotti/features/front_agent/ui/front_task_list.dart';
import 'package:lotti/features/insights/model/insights_models.dart';
import 'package:lotti/features/projects/ui/widgets/project_create_modal.dart';
import 'package:lotti/features/tasks/state/task_preview_provider.dart';
import 'package:lotti/features/tasks/ui/pages/task_details_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/consts.dart';
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

  /// Every list of cards her reply draws, in any reply.
  final herLists = find.byWidgetPredicate(
    (widget) => switch (widget.key) {
      ValueKey<String>(:final value) =>
        value.startsWith('front-reply-') && value.contains('-cards-'),
      _ => false,
    },
  );

  /// The ids of the cards the list her reply draws at [part] of reply
  /// [replyId] shows, in order.
  List<String> listedIds(WidgetTester tester, String replyId, {int part = 1}) =>
      tester
          .widget<FrontEntityPreviewList>(
            find.descendant(
              of: find.byKey(ValueKey('front-reply-$replyId-cards-$part')),
              matching: find.byType(FrontEntityPreviewList),
            ),
          )
          .references
          .map((reference) => reference.id)
          .toList();

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
    Set<String> Function()? storedScope,
    ChatRecorderController Function()? recorder,
    FrontDayPlanner? planDay,
    FrontNewProject? newProject,
    Future<ResolvedInferenceProvider> Function()? dictationTarget,
    bool pushed = false,
    List<NavigatorObserver> navigatorObservers = const [],
    List<CategoryDefinition>? mentionCategories,
    bool companion = false,
    Set<String> flagsOn = const {},
    Future<FrontEntityPreview?> Function(FrontEntityKey key)? previews,
    bool reducedMotion = false,
    ValueListenable<double?>? listWidth,
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
    VoidCallback close() =>
        onClose ??
        () {
          if (pushed) navigator.currentState!.pop();
        };
    final pane = Scaffold(
      body: listWidth == null
          ? FrontChatPane(onClose: close())
          // The window crossing the desktop width: the drawer beside the
          // conversation, then over it again.
          : ValueListenableBuilder<double?>(
              valueListenable: listWidth,
              builder: (context, width, _) =>
                  FrontChatPane(onClose: close(), listWidth: width),
            ),
    );
    await withClock(Clock.fixed(now), () async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          pushed ? const SizedBox.shrink() : pane,
          navigatorKey: navigator,
          navigatorObservers: navigatorObservers,
          mediaQueryData: MediaQueryData(
            size: window,
            disableAnimations: reducedMotion,
          ),
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
                        // As the index reads `c-1`'s newest turn now.
                        categoryIds: storedScope?.call() ?? const {},
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
            configFlagProvider.overrideWith(
              (ref, flag) => Stream.value(
                (companion && flag == enableCompanionFlag) ||
                    flagsOn.contains(flag),
              ),
            ),
            if (mentionCategories != null)
              frontMentionCategoriesProvider.overrideWithValue(
                mentionCategories,
              ),
            // The tasks her lists name: none loads, so each row keeps the
            // title she gave it.
            taskPreviewProvider.overrideWith((ref, id) async => null),
            if (previews != null)
              frontEntityPreviewProvider.overrideWith(
                (ref, key) => previews(key),
              ),
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

  /// Lets the drawer slide all the way in or out: its ticker starts on the
  /// frame after the change and settles a frame after its last value.
  Future<void> settleDrawer(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(MotionDurations.medium2);
    await tester.pump(MotionDurations.short2);
  }

  /// Opens the drawer from the header and lets it slide all the way in.
  Future<void> openDrawer(WidgetTester tester) async {
    await tester.tap(find.byKey(FrontChatHeaderKeys.drawer));
    await settleDrawer(tester);
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

  group('another conversation picked', () {
    late Future<FrontChatThread> Function() load;

    /// The pane on `c-1`'s thread; each later load is [load]'s, which a
    /// test points at the conversation picked next or at `c-1` reloading.
    Future<ProviderContainer> pumpOn(WidgetTester tester) async {
      load = () async => FrontChatThread(
        messages: [message('m0', AgentChatRole.user, 'Count c-1', now)],
      );
      await pumpPane(tester, thread: () => load());
      expect(find.text('Count c-1'), findsOne);
      return ProviderScope.containerOf(
        tester.element(find.byType(FrontChatHeader)),
      );
    }

    Future<void> pick(
      WidgetTester tester,
      ProviderContainer container,
      String id,
    ) => withClock(Clock.fixed(now), () async {
      container.read(frontPickedConversationProvider.notifier).picked = id;
      container.invalidate(frontChatThreadProvider);
      await tester.pump();
      await tester.pump();
    });

    testWidgets("never shows the last one's words while its own load: the "
        'composer already sends to the one picked', (tester) async {
      final container = await pumpOn(tester);
      final loading = Completer<FrontChatThread>();
      load = () => loading.future;

      await pick(tester, container, 'c-2');

      expect(find.text('Count c-1'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOne);

      loading.complete(
        FrontChatThread(
          messages: [message('m1', AgentChatRole.user, 'Count c-2', now)],
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Count c-2'), findsOne);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('says its own load failed rather than showing the last '
        "one's words", (tester) async {
      final container = await pumpOn(tester);
      load = () => Future.error(StateError('db'));

      await pick(tester, container, 'c-2');

      expect(find.text('Count c-1'), findsNothing);
      expect(
        find.text("Couldn't load this conversation right now."),
        findsOne,
      );
    });

    testWidgets('a reload of the same conversation keeps its words on '
        'screen (stay while reload)', (tester) async {
      final container = await pumpOn(tester);
      load = () => Completer<FrontChatThread>().future;

      container.invalidate(frontChatThreadProvider);
      await tester.pump();
      await tester.pump();

      expect(find.text('Count c-1'), findsOne);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
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

    // A conversation, not a log: no name-and-time line on each message,
    // and no cost line under her words — what the conversation cost is
    // the drawer's to say.
    expect(find.textContaining('Companion · '), findsNothing);
    expect(find.textContaining('tokens'), findsNothing);
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

  group('the drawer', () {
    testWidgets('slides over the thread, which stays mounted under it: the '
        'same thread, never rebuilt', (tester) async {
      await pumpPane(tester);
      final thread = tester.state(find.byType(AgentChatView));
      expect(find.byType(FrontChatDrawer), findsNothing);

      await openDrawer(tester);

      expect(find.byType(FrontChatDrawer), findsOneWidget);
      expect(find.byType(FrontConversationList), findsOneWidget);
      expect(tester.state(find.byType(AgentChatView)), same(thread));
      // From the leading edge, a tap target short of the far one.
      final drawer = tester.getRect(find.byType(FrontChatDrawer));
      final pane = tester.getRect(find.byType(FrontChatPane));
      expect(drawer.left, pane.left);
      expect(drawer.width, lessThanOrEqualTo(pane.width - TapTargets.minimum));

      // Picking a conversation opens it and closes the drawer.
      await tester.tap(find.text('Two things.'));
      await settleDrawer(tester);
      expect(find.byType(FrontChatDrawer), findsNothing);
      expect(tester.state(find.byType(AgentChatView)), same(thread));
    });

    testWidgets('a tap on the scrim closes it, and the scrim is a labelled '
        'button', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpPane(tester);
      await openDrawer(tester);

      expect(
        tester.getSemantics(find.byKey(FrontChatPaneKeys.scrim)),
        isSemantics(label: 'Close chats', isButton: true, hasTapAction: true),
      );
      // Beside the drawer, where only the scrim is.
      final pane = tester.getRect(find.byType(FrontChatPane));
      await tester.tapAt(Offset(pane.right - 4, pane.center.dy));
      await settleDrawer(tester);
      expect(find.byType(FrontChatDrawer), findsNothing);
      semantics.dispose();
    });

    testWidgets('its own close glyph closes it', (tester) async {
      await pumpPane(tester);
      await openDrawer(tester);

      await tester.tap(find.byKey(FrontChatDrawerKeys.close));
      await settleDrawer(tester);
      expect(find.byType(FrontChatDrawer), findsNothing);
    });

    testWidgets('a new chat from it starts one and closes it', (tester) async {
      await pumpPane(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(FrontChatPane)),
      );
      await openDrawer(tester);

      await tester.tap(find.byKey(FrontChatDrawerKeys.newChat));
      await settleDrawer(tester);

      expect(find.byType(FrontChatDrawer), findsNothing);
      expect(
        container.read(frontPickedConversationProvider),
        isNot(anyOf(isNull, 'c-1')),
      );
    });

    testWidgets('is a named region, and the thread under it is out of reach '
        'of focus while it is open', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpPane(tester);
      await openDrawer(tester);

      // The drawer's own region, not the toggle's tooltip of the same name.
      final region = tester.widget<Semantics>(
        find
            .ancestor(
              of: find.byType(FrontChatDrawer),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Semantics &&
                    (widget.properties.scopesRoute ?? false),
              ),
            )
            .first,
      );
      expect(region.properties.label, 'Chats');
      expect(region.properties.namesRoute, isTrue);
      expect(
        tester
            .widget<ExcludeFocus>(
              find
                  .ancestor(
                    of: find.byType(AgentChatView),
                    matching: find.byType(ExcludeFocus),
                  )
                  .first,
            )
            .excluding,
        isTrue,
      );
      semantics.dispose();
    });

    testWidgets('takes focus as it opens and gives it back to its toggle as '
        'it closes', (tester) async {
      await pumpPane(tester);
      await openDrawer(tester);
      final drawerScope = FocusScope.of(
        tester.element(find.byType(FrontConversationList)),
      );
      expect(drawerScope.hasFocus, isTrue);

      await tester.tap(find.byKey(FrontChatDrawerKeys.close));
      await settleDrawer(tester);
      final toggle = Focus.of(
        tester.element(
          find.descendant(
            of: find.byKey(FrontChatHeaderKeys.drawer),
            matching: find.byType(Icon),
          ),
        ),
      );
      expect(toggle.hasPrimaryFocus, isTrue);
    });

    testWidgets('a window that widens and narrows again finds the drawer '
        'where its state says: closed beside the thread, closed over it', (
      tester,
    ) async {
      final width = ValueNotifier<double?>(null);
      addTearDown(width.dispose);
      await pumpPane(tester, listWidth: width);
      await openDrawer(tester);

      width.value = 300;
      await settleDrawer(tester);
      // Beside the thread, picking a conversation closes the drawer.
      await tester.tap(find.text('Two things.'));
      await settleDrawer(tester);

      width.value = null;
      await settleDrawer(tester);
      expect(find.byType(FrontChatDrawer), findsNothing);
    });

    testWidgets('with reduced motion focus still goes back to the toggle, '
        'though the drawer is gone at once', (tester) async {
      await pumpPane(tester, reducedMotion: true);
      await tester.tap(find.byKey(FrontChatHeaderKeys.drawer));
      await tester.pump();
      await tester.pump();
      expect(
        FocusScope.of(
          tester.element(find.byType(FrontConversationList)),
        ).hasFocus,
        isTrue,
      );

      await tester.tap(find.byKey(FrontChatDrawerKeys.close));
      await tester.pump();
      await tester.pump();

      expect(find.byType(FrontChatDrawer), findsNothing);
      final toggle = Focus.of(
        tester.element(
          find.descendant(
            of: find.byKey(FrontChatHeaderKeys.drawer),
            matching: find.byType(Icon),
          ),
        ),
      );
      expect(toggle.hasPrimaryFocus, isTrue);
    });

    testWidgets('with reduced motion it is there at once', (tester) async {
      await pumpPane(tester, reducedMotion: true);

      await tester.tap(find.byKey(FrontChatHeaderKeys.drawer));
      await tester.pump();

      expect(
        tester.getRect(find.byType(FrontChatDrawer)).left,
        tester.getRect(find.byType(FrontChatPane)).left,
      );
    });
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

  testWidgets('opening the drawer is not leaving: the recording goes on '
      'under it (decision 5)', (tester) async {
    final recording = _Recording();
    await pumpPane(tester, recorder: () => recording);

    await openDrawer(tester);
    await tester.tap(find.byKey(FrontChatDrawerKeys.close));
    await settleDrawer(tester);

    expect(recording.cancels, 0);
  });

  testWidgets('a new chat from the drawer leaves the conversation, and lets '
      'the recording go', (tester) async {
    final recording = _Recording();
    await pumpPane(tester, recorder: () => recording);

    await openDrawer(tester);
    await withClock(Clock.fixed(now), () async {
      await tester.tap(find.byKey(FrontChatDrawerKeys.newChat));
      await settleDrawer(tester);
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

    /// Opens the drawer from the header and the inbox from the drawer.
    Future<void> openInbox(WidgetTester tester) async {
      await openDrawer(tester);
      await tester.tap(find.byKey(FrontConversationListKeys.inbox));
      await settleDrawer(tester);
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

    testWidgets("the drawer's inbox filters the thread to the turns that "
        'wait', (tester) async {
      await pumpPane(tester, thread: () async => waiting());
      expect(find.text('Fine.'), findsOneWidget);
      // A count on the drawer's toggle says something waits.
      expect(find.byKey(FrontChatHeaderKeys.inbox), findsOneWidget);

      await openInbox(tester);

      expect(find.text('The hinge arrived.'), findsWidgets);
      expect(find.text('Fine.'), findsNothing);
      // Her reply carries the doors, so it stays with the words.
      expect(find.text('Filed? Your call.'), findsOneWidget);

      // Opening a conversation from the drawer leaves the inbox.
      await openDrawer(tester);
      await tester.tap(find.text('Two things.'));
      await settleDrawer(tester);
      expect(find.text('Fine.'), findsOneWidget);
    });

    testWidgets('back closes the drawer, then leaves the inbox, before the '
        'sheet', (
      tester,
    ) async {
      var closed = 0;
      await pumpPane(
        tester,
        thread: () async => waiting(),
        onClose: () => closed++,
      );
      await openInbox(tester);
      await openDrawer(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(FrontChatHeader)),
      );

      await tester.binding.handlePopRoute();
      await settleDrawer(tester);
      expect(find.byType(FrontChatDrawer), findsNothing);
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
              FrontDoorEntry(
                doorId: 'd:door:4',
                record: settled(
                  4,
                  const FrontDoorEventCreated(eventId: 'ev-1'),
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
      await tester.tap(find.byKey(const ValueKey('front-door-open-4')));
      await tester.pump();

      // The day it planned is the Daily OS day surface, showing that day.
      expect(paths, [
        '/journal/e-1',
        '/tasks/t-1',
        '/projects/p-1',
        '/calendar',
        '/events/ev-1',
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

  FrontEntityReference taskRef(String id, String title) =>
      FrontEntityReference(kind: FrontEntityKind.task, id: id, title: title);

  testWidgets('her cards sit between her words where she placed them, and a '
      'card opens its task on top of her', (tester) async {
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
          message('a1', AgentChatRole.agent, 'Two things:\n\nEggs first.', now),
        ],
        partsByMessageId: {
          'a1': [
            const FrontReplyText('Two things:'),
            FrontReplyCards([
              taskRef('t-9', 'Feed the penguins'),
              taskRef('t-8', 'Count the eggs'),
            ]),
            const FrontReplyText('Eggs first.'),
          ],
        },
      ),
    );

    expect(listedIds(tester, 'a1'), ['t-9', 't-8']);
    final words = tester.getTopLeft(
      find.textContaining('Two things:', findRichText: true),
    );
    final card = tester.getRect(
      find.byKey(const ValueKey('front-reply-a1-cards-1')),
    );
    final after = tester.getTopLeft(
      find.textContaining('Eggs first.', findRichText: true),
    );
    expect(words.dy, lessThan(card.top));
    expect(after.dy, greaterThan(card.bottom));

    await expectTaskOpensOverPane(
      tester,
      observer,
      find.byKey(FrontEntityPreviewKeys.card('t-8')),
      't-8',
      paths,
    );
  });

  testWidgets('a Markdown list of task links in her words stays her words: a '
      'reply is never parsed into cards', (tester) async {
    await pumpPane(
      tester,
      thread: () async => FrontChatThread(
        messages: [
          message('u1', AgentChatRole.user, 'Anything overdue?', now),
          message(
            'a1',
            AgentChatRole.agent,
            'Overdue:\n'
                '- [Feed the penguins](lotti://task/t-9)\n'
                '- [Count the eggs](lotti://task/t-8)',
            now,
          ),
        ],
      ),
    );

    expect(herLists, findsNothing);
    expect(find.byType(FrontEntityPreviewList), findsNothing);
    expect(
      find.textContaining('Count the eggs', findRichText: true),
      findsOneWidget,
    );
  });

  group('her lists', () {
    FrontChatThread answer(
      List<FrontReplyPart> parts, {
      FrontDueSection? due,
    }) => FrontChatThread(
      messages: [
        message('u1', AgentChatRole.user, 'What is on my plate?', now),
        message('a1', AgentChatRole.agent, 'Her words.', now),
      ],
      partsByMessageId: {'a1': parts},
      dueSectionsByMessageId: {'a1': ?due},
    );

    final dueToday = FrontDueSection(
      window: FrontDueWindow.today,
      today: DateTime(2026, 10, 24),
      through: DateTime(2026, 10, 24),
    );

    testWidgets('an answer about what is due says which window, quietly, '
        'over its list', (tester) async {
      await pumpPane(
        tester,
        thread: () async => answer([
          const FrontReplyText('Two things:'),
          FrontReplyCards([
            taskRef('t-9', 'Feed the penguins'),
            taskRef('t-8', 'Count the eggs'),
          ]),
        ], due: dueToday),
      );

      final list = find.byKey(const ValueKey('front-reply-a1-cards-1'));
      final label = find.descendant(
        of: list,
        matching: find.byType(FrontDueSectionLabel),
      );
      expect(tester.widget<FrontDueSectionLabel>(label).section, dueToday);
      expect(find.text('Due today'), findsOneWidget);
      expect(
        tester.getRect(label).bottom,
        lessThanOrEqualTo(
          tester.getRect(find.byKey(FrontEntityPreviewKeys.card('t-9'))).top,
        ),
      );
    });

    testWidgets('overdue and due as two lists are named by her words, with '
        'no window label; one list of no due answer has none either', (
      tester,
    ) async {
      await pumpPane(
        tester,
        thread: () async => answer([
          const FrontReplyText('One is overdue:'),
          FrontReplyCards([taskRef('t-9', 'Feed the penguins')]),
          const FrontReplyText('And one is due today:'),
          FrontReplyCards([taskRef('t-8', 'Count the eggs')]),
        ], due: dueToday),
      );

      expect(listedIds(tester, 'a1'), ['t-9']);
      expect(listedIds(tester, 'a1', part: 3), ['t-8']);
      expect(find.byType(FrontDueSectionLabel), findsNothing);
      expect(
        tester
            .getRect(find.byKey(const ValueKey('front-reply-a1-cards-1')))
            .bottom,
        lessThan(
          tester
              .getTopLeft(
                find.textContaining('And one is due', findRichText: true),
              )
              .dy,
        ),
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await pumpPane(
        tester,
        thread: () async => answer([
          const FrontReplyText('Two things:'),
          FrontReplyCards([
            taskRef('t-9', 'Feed the penguins'),
            taskRef('t-8', 'Count the eggs'),
          ]),
        ]),
      );
      expect(herLists, findsOneWidget);
      expect(find.byType(FrontDueSectionLabel), findsNothing);
    });

    testWidgets('a due answer with nothing listed draws no label', (
      tester,
    ) async {
      await pumpPane(
        tester,
        thread: () async => answer([
          const FrontReplyText('Nothing is due today.'),
        ], due: dueToday),
      );

      expect(find.byType(FrontDueSectionLabel), findsNothing);
    });

    testWidgets('a project in her list is a card of its title that closes '
        'her and opens the project', (tester) async {
      final paths = <String>[];
      beamToNamedOverride = paths.add;
      addTearDown(() => beamToNamedOverride = null);
      var closed = 0;
      await pumpPane(
        tester,
        onClose: () => closed++,
        thread: () async => answer([
          const FrontReplyText('Found these:'),
          FrontReplyCards([
            const FrontEntityReference(
              kind: FrontEntityKind.project,
              id: 'p-1',
              title: 'Colony census',
            ),
            taskRef('t-8', 'Count the eggs'),
          ]),
        ]),
      );

      final card = find.byKey(FrontEntityPreviewKeys.card('p-1'));
      expect(
        find.descendant(of: card, matching: find.byIcon(LottiIcons.folder)),
        findsOneWidget,
      );
      await tester.tap(card);
      await tester.pump();

      expect(closed, 1);
      expect(paths, ['/projects/p-1']);
    });
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
    // The two her words listed are not drawn again as cards.
    expect(herLists, findsNothing);
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

  group('entity previews', () {
    const iceRef = FrontEntityReference(
      kind: FrontEntityKind.task,
      id: 't-9',
      title: 'Check the ice-pad weather window',
    );
    const coldRef = FrontEntityReference(
      kind: FrontEntityKind.task,
      id: 't-8',
      title: 'Audit the cold-chain freezer logs',
    );

    FrontDoorEntry madeTask(int index, String taskId, String words) =>
        FrontDoorEntry(
          doorId: 'd:door:$index',
          record: FrontDoorRecord(
            segmentIndex: index,
            text: words,
            kind: FrontDestinationKind.newThing,
            status: FrontDoorStatus.done,
            claimedAt: now.toUtc(),
            outcome: FrontDoorTaskCreated(taskId: taskId),
          ),
        );

    testWidgets('a reply whose turn made tasks draws each as a preview card '
        'under her words, above her doors, and a card opens its task on top '
        'of her', (tester) async {
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
            message('u1', AgentChatRole.user, 'Ice pad, freezers.', now),
            message('a1', AgentChatRole.agent, 'Made them tasks.', now),
          ],
          doorsByMessageId: {
            'u1': [
              madeTask(0, 't-9', iceRef.title),
              madeTask(1, 't-8', coldRef.title),
            ],
          },
          entityPreviewsByMessageId: const {
            'a1': [iceRef, coldRef],
          },
        ),
      );

      final list = tester.widget<FrontEntityPreviewList>(
        find.byKey(const ValueKey('front-entity-previews-a1')),
      );
      expect(list.references, [iceRef, coldRef]);
      final words = tester.getTopLeft(
        find.textContaining('Made them tasks.', findRichText: true),
      );
      final cards = tester.getRect(
        find.byKey(const ValueKey('front-entity-previews-a1')),
      );
      final doors = tester.getRect(
        find.byKey(const ValueKey('front-doors-a1')),
      );
      expect(words.dy, lessThan(cards.top));
      expect(cards.bottom, lessThanOrEqualTo(doors.top));

      await expectTaskOpensOverPane(
        tester,
        observer,
        find.byKey(FrontEntityPreviewKeys.card('t-8')),
        't-8',
        paths,
      );
    });

    testWidgets('a task the door cards show is not drawn again in her list; '
        'the rest of the list stays', (tester) async {
      await pumpPane(
        tester,
        thread: () async => FrontChatThread(
          messages: [
            message('u1', AgentChatRole.user, 'Ice pad.', now),
            message('a1', AgentChatRole.agent, 'Made it a task.', now),
          ],
          partsByMessageId: {
            'a1': [
              const FrontReplyText('Made it a task. Also due:'),
              FrontReplyCards([iceRef, taskRef('t-7', 'Feed the penguins')]),
            ],
          },
          entityPreviewsByMessageId: const {
            'a1': [iceRef],
          },
        ),
      );

      expect(listedIds(tester, 'a1'), ['t-7']);
      expect(find.byKey(FrontEntityPreviewKeys.card('t-9')), findsOneWidget);
    });

    testWidgets('a list the door cards cover entirely is not drawn at all', (
      tester,
    ) async {
      await pumpPane(
        tester,
        thread: () async => FrontChatThread(
          messages: [
            message('u1', AgentChatRole.user, 'Ice pad.', now),
            message('a1', AgentChatRole.agent, 'Made them tasks:', now),
          ],
          partsByMessageId: const {
            'a1': [
              FrontReplyText('Made them tasks:'),
              FrontReplyCards([iceRef, coldRef]),
            ],
          },
          entityPreviewsByMessageId: const {
            'a1': [iceRef, coldRef],
          },
        ),
      );

      expect(herLists, findsNothing);
      expect(find.byKey(FrontEntityPreviewKeys.card('t-9')), findsOneWidget);
      expect(find.byKey(FrontEntityPreviewKeys.card('t-8')), findsOneWidget);
      expect(
        find.textContaining('Made them tasks:', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('an event her turn made opens its page: she closes first, '
        'then it goes there', (tester) async {
      final order = <String>[];
      beamToNamedOverride = order.add;
      addTearDown(() => beamToNamedOverride = null);
      const rehearsal = FrontEntityReference(
        kind: FrontEntityKind.event,
        id: 'ev-1',
        title: 'Launch-day rehearsal',
      );
      await pumpPane(
        tester,
        onClose: () => order.add('closed'),
        previews: (_) async => null,
        thread: () async => FrontChatThread(
          messages: [
            message('u1', AgentChatRole.user, 'Rehearsal Friday.', now),
            message('a1', AgentChatRole.agent, 'Made it an event.', now),
          ],
          entityPreviewsByMessageId: const {
            'a1': [rehearsal],
          },
        ),
      );

      await tester.tap(find.byKey(FrontEntityPreviewKeys.card('ev-1')));
      await tester.pump();

      expect(order, ['closed', '/events/ev-1']);
    });

    testWidgets('a day her turn planned opens that day: she closes first, '
        'then the day surface shows it', (tester) async {
      final order = <String>[];
      beamToNamedOverride = order.add;
      addTearDown(() => beamToNamedOverride = null);
      final planned = DateTime(2026, 10, 30);
      final day = FrontEntityReference(
        kind: FrontEntityKind.dayPlan,
        id: frontDayPlanId(planned),
        title: 'Move the audit to the afternoon',
      );
      await pumpPane(
        tester,
        onClose: () => order.add('closed'),
        previews: (_) async => null,
        thread: () async => FrontChatThread(
          messages: [
            message('u1', AgentChatRole.user, 'Move the audit.', now),
            message('a1', AgentChatRole.agent, 'Moved it.', now),
          ],
          entityPreviewsByMessageId: {
            'a1': [day],
          },
        ),
      );

      await tester.tap(find.byKey(FrontEntityPreviewKeys.card(day.id)));
      await tester.pump();

      expect(order, ['closed', '/calendar']);
      expect(
        ProviderScope.containerOf(
          tester.element(find.byType(FrontChatPane)),
        ).read(dailyOsNextSelectedDateProvider),
        planned,
      );
    });

    testWidgets('a person her turn was handed to opens their page: she '
        'closes first, then it goes there', (tester) async {
      final order = <String>[];
      beamToNamedOverride = order.add;
      addTearDown(() => beamToNamedOverride = null);
      const anna = FrontEntityReference(
        kind: FrontEntityKind.person,
        id: 'anna',
        title: 'Anna',
      );
      await pumpPane(
        tester,
        onClose: () => order.add('closed'),
        previews: (_) async => null,
        thread: () async => FrontChatThread(
          messages: [
            message('u1', AgentChatRole.user, 'Anna won a ribbon.', now),
            message('a1', AgentChatRole.agent, 'Passed it on to Anna.', now),
          ],
          entityPreviewsByMessageId: const {
            'a1': [anna],
          },
        ),
      );

      await tester.tap(find.byKey(FrontEntityPreviewKeys.card('anna')));
      await tester.pump();

      expect(order, ['closed', '/people/anna']);
    });

    testWidgets('only the reply the cards belong to draws them', (
      tester,
    ) async {
      await pumpPane(
        tester,
        thread: () async => FrontChatThread(
          messages: [
            message('u1', AgentChatRole.user, 'Ice pad.', now),
            message('a1', AgentChatRole.agent, 'Made it a task.', now),
            message('u2', AgentChatRole.user, 'Thanks.', now),
            message('a2', AgentChatRole.agent, 'Any time.', now),
          ],
          entityPreviewsByMessageId: const {
            'a1': [iceRef],
          },
        ),
      );

      expect(
        find.byKey(const ValueKey('front-entity-previews-a1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('front-entity-previews-a2')),
        findsNothing,
      );
      expect(find.byType(FrontEntityPreviewList), findsOneWidget);
    });
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

  testWidgets('a chart she placed between her words is drawn there, and what '
      'she did not place follows her words', (tester) async {
    const chart = FrontLoggedTimeChart(
      range: InsightsRange(startDay: 20396, endDayExclusive: 20403),
      categoryIds: {},
    );
    const pullRequests = FrontPullRequestChart(
      range: InsightsRange(startDay: 20396, endDayExclusive: 20403),
      categoryIds: {},
    );
    await pumpPane(
      tester,
      thread: () async => FrontChatThread(
        messages: [
          message('u1', AgentChatRole.user, 'Time and PRs?', now),
          message('a1', AgentChatRole.agent, '12h logged.', now),
        ],
        loggedTimeByMessageId: const {'a1': chart},
        pullRequestsByMessageId: const {'a1': pullRequests},
        partsByMessageId: const {
          'a1': [
            FrontReplyText('12h logged.'),
            FrontReplyShow(FrontReplyAttachment.loggedTimeChart),
            FrontReplyText('And 12 PRs.'),
            FrontReplyShow(FrontReplyAttachment.pullRequestChart),
          ],
        },
      ),
    );

    double top(Finder finder) => tester.getTopLeft(finder).dy;
    final time = top(find.byType(FrontLoggedTimeChartCard));
    final words = top(find.textContaining('And 12 PRs.', findRichText: true));
    expect(
      top(find.textContaining('12h logged.', findRichText: true)),
      lessThan(time),
    );
    expect(time, lessThan(words));
    expect(words, lessThan(top(find.byType(FrontPullRequestChartCard))));
  });

  testWidgets('a part whose data the reply does not carry draws nothing', (
    tester,
  ) async {
    await pumpPane(
      tester,
      thread: () async => FrontChatThread(
        messages: [
          message('u1', AgentChatRole.user, 'Time?', now),
          message('a1', AgentChatRole.agent, 'Nothing logged.', now),
        ],
        partsByMessageId: const {
          'a1': [
            FrontReplyText('Nothing logged.'),
            FrontReplyShow(FrontReplyAttachment.loggedTimeChart),
          ],
        },
      ),
    );

    expect(find.byType(FrontLoggedTimeChartCard), findsNothing);
    expect(
      find.textContaining('Nothing logged.', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('@ offers the categories she may see, and the field leads '
      "with the conversation's category; with none, neither", (tester) async {
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
    expect(input.leading, isA<FrontCategoryChip>());
    expect(input.helperText, isNull);

    await pumpPane(tester, mentionCategories: const <CategoryDefinition>[]);
    input = tester.widget<DesignSystemChatInput>(
      find.byType(DesignSystemChatInput),
    );
    expect(input.mentionOptions, isEmpty);
    expect(input.leading, isNull);
  });

  testWidgets('a category picked in the composer goes out with the next '
      'turn, and stays for the one after', (tester) async {
    // What the turns sent leave as `c-1`'s scope, once the pick has gone.
    var stored = const <String>{};
    when(
      () => chatService.sendMessage(
        text: any(named: 'text'),
        conversationId: 'c-1',
        categoryIds: {'colony'},
      ),
    ).thenAnswer((_) async => stored = {'colony'});
    await pumpPane(
      tester,
      storedScope: () => stored,
      mentionCategories: [
        CategoryTestUtils.createTestCategory(
          id: 'colony',
          name: 'Colony',
          color: '#4CAF93',
        ),
      ],
    );
    expect(find.text('Everything'), findsOneWidget);

    await tester.tap(find.byKey(FrontCategoryChipKeys.chip));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(FrontCategoryChipKeys.option('colony')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(FrontCategoryChipKeys.chip),
        matching: find.text('Colony'),
      ),
      findsOneWidget,
    );

    for (final words in ['How many chicks?', 'And eggs?']) {
      await tester.enterText(find.byType(TextField), words);
      await tester.pump();
      await tester.tap(find.byIcon(LottiIcons.arrowUp));
      await tester.pump();
      await tester.pump();
    }

    verify(
      () => chatService.sendMessage(
        text: 'How many chicks?',
        conversationId: 'c-1',
        categoryIds: {'colony'},
      ),
    ).called(1);
    verify(
      () => chatService.sendMessage(
        text: 'And eggs?',
        conversationId: 'c-1',
        categoryIds: {'colony'},
      ),
    ).called(1);
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

    expect(herLists, findsNothing);
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

  group('her card', () {
    final card = find.byKey(CompanionFloatingCardKeys.card);
    final toggle = find.byKey(FrontChatHeaderKeys.companion);
    // She animates, so no settle: frames past the card's fade.
    Future<void> frames(WidgetTester tester) async {
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    double inset(WidgetTester tester) => tester
        .widget<AgentChatView>(find.byType(AgentChatView))
        .threadBottomInset;

    testWidgets('a tap on her face fades her card in over the thread, in '
        'place — no page is pushed — between the header and the field, the '
        'thread keeping her height free after its end; a tap on the card '
        'fades her out and gives the header her face back', (tester) async {
      final observer = _PushObserver();
      await pumpPane(tester, companion: true, navigatorObservers: [observer]);
      final pushes = observer.pushed.length;
      expect(card, findsNothing);
      expect(inset(tester), 0);

      await tester.tap(toggle);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // Halfway through its fade.
      final fade = tester.widget<FadeTransition>(
        find
            .ancestor(
              of: find.byType(FrontCompanionCard),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      expect(fade.opacity.value, inExclusiveRange(0, 1));
      await frames(tester);

      expect(observer.pushed, hasLength(pushes));
      final rect = tester.getRect(card);
      expect(
        rect.top,
        greaterThanOrEqualTo(
          tester.getRect(find.byType(FrontChatHeader)).bottom,
        ),
      );
      expect(
        rect.bottom,
        lessThanOrEqualTo(tester.getRect(find.byType(TextField)).top),
      );
      // An 800-wide window is no desktop: the phone placement.
      expect(rect.height, CompanionCardForm.phone.smallHeight);
      expect(inset(tester), CompanionCardForm.phone.smallHeight + 16);
      expect(
        tester
            .widget<FrontCompanionCard>(find.byType(FrontCompanionCard))
            .conversationId,
        'c-1',
      );

      // The face is gone while she is out: the card puts itself away.
      expect(toggle, findsNothing);
      await tester.tap(card);
      await tester.pump(kDoubleTapTimeout);
      await frames(tester);
      expect(card, findsNothing);
      expect(inset(tester), 0);
      expect(toggle, findsOne);
    });

    for (final (why, companion, inbox) in [
      ('in the inbox', true, true),
      ('with the character off', false, false),
    ]) {
      testWidgets('$why she stays away, though her card was shown', (
        tester,
      ) async {
        await pumpPane(tester, companion: companion);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(FrontChatPane)),
        );
        container.read(frontCompanionCardShownProvider.notifier).toggle();
        if (inbox) container.read(frontInboxFilterProvider.notifier).toggle();
        await frames(tester);

        expect(container.read(frontCompanionCardShownProvider), isTrue);
        expect(card, findsNothing);
        expect(inset(tester), 0);
      });
    }
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

    testWidgets('make it an event makes the event through the filing '
        'service, and leaves the sheet where it is', (tester) async {
      final paths = <String>[];
      beamToNamedOverride = paths.add;
      addTearDown(() => beamToNamedOverride = null);
      var closed = 0;
      when(() => filing.makeEvent('d:door:0')).thenAnswer((_) async {});
      await pumpPane(
        tester,
        thread: () async => inbox(FrontNewKind.task),
        onClose: () => closed++,
        flagsOn: {enableEventsFlag},
      );

      await tester.tap(find.byKey(const ValueKey('front-door-menu-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('front-door-event-0')));
      await tester.pump();
      await tester.pump();

      verify(() => filing.makeEvent('d:door:0')).called(1);
      expect(closed, 0);
      expect(paths, isEmpty);
    });

    testWidgets('where events are off, an item offers no event to make', (
      tester,
    ) async {
      await pumpPane(tester, thread: () async => inbox(FrontNewKind.task));

      await tester.tap(find.byKey(const ValueKey('front-door-menu-0')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('front-door-note-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('front-door-event-0')), findsNothing);
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
