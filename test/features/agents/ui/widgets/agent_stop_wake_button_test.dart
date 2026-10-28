import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/ui/widgets/agent_stop_wake_button.dart';
import 'package:lotti/features/agents/wake/wake_runner.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import '../../test_utils.dart';

void main() {
  late WakeRunner runner;
  late MockAgentService agentService;

  setUp(() {
    runner = WakeRunner();
    agentService = MockAgentService();
  });

  tearDown(() => runner.dispose());

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        child,
        overrides: [
          wakeRunnerProvider.overrideWithValue(runner),
          agentServiceProvider.overrideWithValue(agentService),
        ],
      ),
    );
    await tester.pump();
  }

  /// Starts or ends a run the way the drain does, then lets the running
  /// stream reach the widget.
  Future<void> setRunning(WidgetTester tester, {required bool running}) async {
    if (running) {
      await runner.tryAcquire(kTestAgentId, runKey: 'run-1');
    } else {
      runner.release(kTestAgentId);
    }
    await tester.pump();
  }

  DesignSystemButton stopButton(WidgetTester tester) =>
      tester.widget<DesignSystemButton>(find.byType(DesignSystemButton));

  group('AgentStopWakeButton', () {
    testWidgets('renders nothing while the agent is idle', (tester) async {
      await pump(tester, const AgentStopWakeButton(agentId: kTestAgentId));

      expect(find.byType(DesignSystemButton), findsNothing);
    });

    testWidgets(
      'stops the running wake, shows Stopping… and ignores further taps until '
      'the agent is idle, then reads Stop again for the next wake',
      (tester) async {
        when(() => agentService.abortRunningWake(any())).thenReturn(true);
        await setRunning(tester, running: true);
        await pump(tester, const AgentStopWakeButton(agentId: kTestAgentId));

        expect(find.text('Stop'), findsOneWidget);
        expect(stopButton(tester).isLoading, isFalse);
        expect(stopButton(tester).leadingIcon, LottiIcons.stop);

        await tester.tap(find.text('Stop'));
        await tester.pump();

        verify(() => agentService.abortRunningWake(kTestAgentId)).called(1);
        expect(find.text('Stopping…'), findsOneWidget);
        expect(stopButton(tester).isLoading, isTrue);

        await tester.tap(find.text('Stopping…'), warnIfMissed: false);
        await tester.pump();
        verifyNever(() => agentService.abortRunningWake(any()));

        await setRunning(tester, running: false);
        expect(find.byType(DesignSystemButton), findsNothing);

        await setRunning(tester, running: true);
        expect(find.text('Stop'), findsOneWidget);
        expect(stopButton(tester).isLoading, isFalse);
      },
    );

    testWidgets(
      'stays on Stop when the wake had already ended before the tap landed',
      (tester) async {
        when(() => agentService.abortRunningWake(any())).thenReturn(false);
        await setRunning(tester, running: true);
        await pump(tester, const AgentStopWakeButton(agentId: kTestAgentId));

        await tester.tap(find.text('Stop'));
        await tester.pump();

        verify(() => agentService.abortRunningWake(kTestAgentId)).called(1);
        expect(find.text('Stop'), findsOneWidget);
        expect(stopButton(tester).isLoading, isFalse);
      },
    );

    testWidgets('publishes what it does as its accessible label', (
      tester,
    ) async {
      await setRunning(tester, running: true);
      await pump(
        tester,
        const AgentStopWakeButton(
          agentId: kTestAgentId,
          size: DesignSystemButtonSize.dense,
        ),
      );

      expect(stopButton(tester).semanticsLabel, 'Stop the running inference');
      expect(stopButton(tester).size, DesignSystemButtonSize.dense);
    });
  });

  group('AgentRunningControls', () {
    testWidgets('pairs the running spinner with the stop button while the '
        'agent runs, and shows neither once it is idle', (tester) async {
      await pump(tester, const AgentRunningControls(agentId: kTestAgentId));
      expect(find.byType(DesignSystemSpinner), findsNothing);
      expect(find.byType(DesignSystemButton), findsNothing);

      await setRunning(tester, running: true);
      expect(
        find.bySemanticsLabel('Running'),
        findsOneWidget,
      );
      expect(find.byType(DesignSystemSpinner), findsOneWidget);
      expect(find.text('Stop'), findsOneWidget);

      await setRunning(tester, running: false);
      expect(find.byType(DesignSystemSpinner), findsNothing);
      expect(find.text('Stop'), findsNothing);
    });
  });
}
