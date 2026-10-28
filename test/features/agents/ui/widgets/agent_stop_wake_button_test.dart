import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/ui/widgets/agent_stop_wake_button.dart';
import 'package:lotti/features/agents/wake/wake_runner.dart';
import 'package:lotti/features/design_system/components/buttons/ds_ai_disc_button.dart';
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

  Future<void> pump(
    WidgetTester tester, {
    MediaQueryData? mediaQueryData,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const AgentStopWakeButton(agentId: kTestAgentId),
        mediaQueryData: mediaQueryData,
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

  DsAiDiscButton disc(WidgetTester tester) =>
      tester.widget<DsAiDiscButton>(find.byType(DsAiDiscButton));

  CircularProgressIndicator ring(WidgetTester tester) =>
      disc(tester).ring! as CircularProgressIndicator;

  testWidgets('renders nothing while the agent is idle', (tester) async {
    await pump(tester);

    expect(find.byType(DsAiDiscButton), findsNothing);
  });

  testWidgets(
    'is the active disc with the stop glyph inside a spinning ring while the '
    "agent runs — the read-aloud control's busy-and-stoppable grammar",
    (tester) async {
      await setRunning(tester, running: true);
      await pump(tester);

      expect(disc(tester).active, isTrue);
      expect(disc(tester).icon, LottiIcons.stop);
      expect(disc(tester).label, 'Stop the running inference');
      expect(ring(tester).value, isNull);
    },
  );

  testWidgets(
    'stops the running wake, turns to Stopping… and ignores further taps until '
    'the agent is idle, then offers the stop again for the next wake',
    (tester) async {
      when(() => agentService.abortRunningWake(any())).thenReturn(true);
      await setRunning(tester, running: true);
      await pump(tester);

      await tester.tap(find.byType(DsAiDiscButton));
      await tester.pump();

      verify(() => agentService.abortRunningWake(kTestAgentId)).called(1);
      expect(disc(tester).icon, LottiIcons.pending);
      expect(disc(tester).label, 'Stopping…');

      await tester.tap(find.byType(DsAiDiscButton));
      await tester.pump();
      verifyNever(() => agentService.abortRunningWake(any()));

      await setRunning(tester, running: false);
      expect(find.byType(DsAiDiscButton), findsNothing);

      await setRunning(tester, running: true);
      expect(disc(tester).icon, LottiIcons.stop);
      expect(disc(tester).label, 'Stop the running inference');
    },
  );

  testWidgets(
    'keeps offering the stop when the wake had already ended before the tap '
    'landed',
    (tester) async {
      when(() => agentService.abortRunningWake(any())).thenReturn(false);
      await setRunning(tester, running: true);
      await pump(tester);

      await tester.tap(find.byType(DsAiDiscButton));
      await tester.pump();

      verify(() => agentService.abortRunningWake(kTestAgentId)).called(1);
      expect(disc(tester).icon, LottiIcons.stop);
    },
  );

  testWidgets('holds the ring still under reduced motion', (tester) async {
    await setRunning(tester, running: true);
    await pump(
      tester,
      mediaQueryData: const MediaQueryData(disableAnimations: true),
    );

    expect(ring(tester).value, 1.0);
  });
}
