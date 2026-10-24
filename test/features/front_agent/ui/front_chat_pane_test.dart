import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/state/agent_chat_projection.dart';
import 'package:lotti/features/agents/ui/chat/agent_chat_view.dart';
import 'package:lotti/features/ai_consumption/model/consumption_aggregation_models.dart';
import 'package:lotti/features/ai_consumption/state/consumption_providers.dart';
import 'package:lotti/features/design_system/components/dividers/design_system_divider.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/front_agent/model/front_agent_identity.dart';
import 'package:lotti/features/front_agent/model/front_chat_thread.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_door.dart';
import 'package:lotti/features/front_agent/service/front_chat_service.dart';
import 'package:lotti/features/front_agent/state/front_agent_providers.dart';
import 'package:lotti/features/front_agent/state/front_chat_thread_provider.dart';
import 'package:lotti/features/front_agent/ui/front_ask_options_row.dart';
import 'package:lotti/features/front_agent/ui/front_chat_header.dart';
import 'package:lotti/features/front_agent/ui/front_chat_pane.dart';
import 'package:lotti/features/front_agent/ui/front_door_card.dart';
import 'package:lotti/features/front_agent/ui/front_turn_cost_line.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../../agents/test_data/entity_factories.dart';
import '../../ai_consumption/test_utils.dart';

void main() {
  final now = DateTime(2026, 10, 24, 10);
  late MockFrontChatService chatService;
  late MockFrontAgentService agentService;

  setUp(() {
    chatService = MockFrontChatService();
    agentService = MockFrontAgentService();
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
  }) async {
    await setUpTestGetIt();
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
            frontChatServiceProvider.overrideWithValue(chatService),
            frontAgentServiceProvider.overrideWithValue(agentService),
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
        'Ask about a task, a goal, a project or a person. She finds who '
        'knows and brings back the answer.',
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
          'u1': [FrontDoorEntry(record: doorRecord)],
        },
      ),
    );

    // Three days, three dividers: the date, yesterday, today.
    final dividers = tester
        .widgetList<DesignSystemDivider>(find.byType(DesignSystemDivider))
        .map((d) => d.label)
        .toList();
    expect(dividers, ['Tuesday, October 20, 2026', 'Yesterday', 'Today']);
    expect(find.byKey(const ValueKey('goal-chat-divider-u0')), findsOneWidget);
    expect(find.byKey(const ValueKey('goal-chat-divider-ask0')), findsNothing);

    expect(find.byKey(const ValueKey('front-doors-u1')), findsOneWidget);
    expect(find.byType(FrontDoorCard), findsOneWidget);
    expect(find.text('The seam walk is next.'), findsOneWidget);

    expect(find.byKey(const ValueKey('front-options-ask2')), findsOneWidget);
    expect(find.byKey(const ValueKey('front-options-ask0')), findsNothing);
    expect(find.byType(FrontAskOptionsRow), findsOneWidget);

    // Her turns carry what they cost, under the chips when there are any;
    // a wake that recorded no call shows nothing.
    expect(find.byType(FrontTurnCostLine), findsNWidgets(2));
    expect(find.byKey(const ValueKey('front-turn-cost-run-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('front-turn-cost-run-1')), findsNothing);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('front-turn-cost-run-2'))).dy,
      greaterThan(
        tester
            .getBottomLeft(find.byKey(const ValueKey('front-options-ask2')))
            .dy,
      ),
    );
  });

  testWidgets('a chip answers in its own words through the composer', (
    tester,
  ) async {
    when(
      () => chatService.sendMessage(text: 'Swim 2 km'),
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
      () => chatService.sendMessage(text: 'Swim 2 km'),
    ]);
  });

  testWidgets('typing and sending goes through the chat service; a failed '
      'turn offers a retry that re-wakes the same turn', (tester) async {
    when(() => chatService.sendMessage(text: 'Hello')).thenThrow(
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

    verify(() => chatService.sendMessage(text: 'Hello')).called(1);
    expect(find.text("That didn't send."), findsOneWidget);

    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();

    verify(() => chatService.retryMessage(messageId: 'm-1')).called(1);
    expect(find.text("That didn't send."), findsNothing);
  });

  testWidgets('the header close hands back to the host', (tester) async {
    var closed = 0;
    await pumpPane(tester, onClose: () => closed++);
    await tester.tap(find.byKey(FrontChatHeaderKeys.close));
    expect(closed, 1);
    expect(find.byType(AgentChatView), findsOneWidget);
  });
}
