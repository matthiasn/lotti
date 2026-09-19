import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/logic/mock_day_agent.dart';
import 'package:lotti/features/daily_os_next/state/capture_controller.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/state/refine_controller.dart';
import 'package:lotti/features/daily_os_next/ui/refine_voice_sync.dart';

/// Records the orb's calls into capture instead of touching the recorder.
class _RecordingCaptureController extends CaptureController {
  int resets = 0;
  final toggles = <({DateTime? forDate, AudioCaptureIntent intent})>[];

  @override
  CaptureState build() => const CaptureState.idle();

  @override
  void reset() => resets++;

  @override
  Future<void> toggle({
    DateTime? forDate,
    AudioCaptureIntent intent = AudioCaptureIntent.dayPlan,
  }) async => toggles.add((forDate: forDate, intent: intent));
}

void main() {
  final planDate = DateTime(2026, 5, 26);
  final draft = DraftPlan.emptyForDay(planDate);

  late ProviderContainer container;
  late _RecordingCaptureController capture;

  setUp(() {
    capture = _RecordingCaptureController();
    container = ProviderContainer(
      overrides: [
        dayAgentProvider.overrideWithValue(
          MockDayAgent(
            parseLatency: Duration.zero,
            pendingLatency: Duration.zero,
            triageLatency: Duration.zero,
            draftLatency: Duration.zero,
            summarizeLatency: Duration.zero,
          ),
        ),
        captureControllerProvider.overrideWith(() => capture),
      ],
    )..listen(refineControllerProvider(draft), (_, _) {});
  });

  tearDown(() => container.dispose());

  RefineState tapIn(RefinePhase phase) {
    final notifier = container.read(refineControllerProvider(draft).notifier);
    final state = container
        .read(refineControllerProvider(draft))
        .copyWith(phase: phase, transcript: 'move the krill count earlier');
    handleRefineVoiceTap(
      refineState: state,
      refineNotifier: notifier,
      captureNotifier: container.read(captureControllerProvider.notifier),
      planDate: planDate,
    );
    return container.read(refineControllerProvider(draft));
  }

  test('an idle orb starts a fresh refine recording', () {
    final after = tapIn(RefinePhase.idle);

    expect(capture.resets, 1);
    expect(after.phase, RefinePhase.listening);
    expect(capture.toggles, [
      (forDate: planDate, intent: AudioCaptureIntent.dayRefine),
    ]);
  });

  test('a listening orb stops the recording it started', () {
    tapIn(RefinePhase.listening);

    expect(capture.resets, 0);
    expect(capture.toggles, [
      (forDate: planDate, intent: AudioCaptureIntent.dayPlan),
    ]);
  });

  for (final phase in [RefinePhase.thinking, RefinePhase.accepted]) {
    test('the orb ignores taps while ${phase.name}', () {
      final before = container.read(refineControllerProvider(draft));

      final after = tapIn(phase);

      expect(capture.resets, 0);
      expect(capture.toggles, isEmpty);
      expect(after, same(before));
    });
  }
}
