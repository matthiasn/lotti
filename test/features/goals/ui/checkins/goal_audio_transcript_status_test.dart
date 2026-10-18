import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/goals/ui/checkins/goal_audio_transcript_status.dart';
import 'package:lotti/widgets/timeline/timeline_models.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  final now = DateTime(2026, 8, 11, 12);
  final graceOpen = now.add(const Duration(minutes: 5));
  final graceClosed = now.subtract(const Duration(minutes: 1));

  TimelineTranscriptStatus status({
    bool hasTranscript = false,
    InferenceStatus inference = InferenceStatus.idle,
    bool durableFailure = false,
    DateTime? graceExpiry,
  }) => goalAudioTranscriptStatus(
    hasTranscript: hasTranscript,
    inference: inference,
    durableFailure: durableFailure,
    graceExpiry: graceExpiry ?? graceOpen,
    now: now,
  );

  test('words win over every other signal', () {
    expect(
      status(
        hasTranscript: true,
        inference: InferenceStatus.error,
        durableFailure: true,
        graceExpiry: graceClosed,
      ),
      TimelineTranscriptStatus.none,
    );
  });

  test('a running transcription is pending, even past the grace window', () {
    expect(
      status(inference: InferenceStatus.running, graceExpiry: graceClosed),
      TimelineTranscriptStatus.pending,
    );
  });

  test('a live or a durable failure is a failure', () {
    expect(
      status(inference: InferenceStatus.error),
      TimelineTranscriptStatus.failed,
    );
    expect(status(durableFailure: true), TimelineTranscriptStatus.failed);
  });

  test('an idle recording waits out the grace window, then has stalled', () {
    expect(status(), TimelineTranscriptStatus.pending);
    expect(
      status(graceExpiry: graceClosed),
      TimelineTranscriptStatus.stalled,
    );
  });

  group('GoalTranscriptGraceRebuild', () {
    testWidgets('rebuilds once the deadline passes, and only then', (
      tester,
    ) async {
      var builds = 0;
      await withClock(Clock.fixed(now), () async {
        await tester.pumpWidget(
          _GraceHost(deadline: graceOpen, onBuild: () => builds++),
        );
        expect(builds, 1);

        await tester.pump(const Duration(minutes: 4));
        expect(builds, 1, reason: 'still inside the window');

        await tester.pump(const Duration(minutes: 1));
        expect(builds, 2, reason: 'the window closed');
      });
    });

    testWidgets('an unrelated rebuild does not push the wake-up out', (
      tester,
    ) async {
      var builds = 0;
      await withClock(Clock.fixed(now), () async {
        Widget host() =>
            _GraceHost(deadline: graceOpen, onBuild: () => builds++);
        await tester.pumpWidget(host());
        await tester.pump(const Duration(minutes: 3));
        // Same deadline, rebuilt for some other reason.
        await tester.pumpWidget(host());
        expect(builds, 2);

        await tester.pump(const Duration(minutes: 2));
        expect(builds, 3, reason: 'fired at the original deadline');
      });
    });

    testWidgets('takes its timer with it when it goes', (tester) async {
      await withClock(Clock.fixed(now), () async {
        await tester.pumpWidget(
          _GraceHost(deadline: graceOpen, onBuild: () {}),
        );
        await tester.pumpWidget(const SizedBox.shrink());
        // Short of the deadline: a live timer would fail the binding's
        // pending-timer check at teardown.
        await tester.pump(const Duration(minutes: 1));
      });
      expect(tester.takeException(), isNull);
    });
  });
}

/// A minimal host for the mixin: counts its builds and arms what it is told.
class _GraceHost extends StatefulWidget {
  const _GraceHost({required this.deadline, required this.onBuild});

  final DateTime? deadline;
  final VoidCallback onBuild;

  @override
  State<_GraceHost> createState() => _GraceHostState();
}

class _GraceHostState extends State<_GraceHost>
    with GoalTranscriptGraceRebuild {
  @override
  Widget build(BuildContext context) {
    widget.onBuild();
    armGraceRebuild(widget.deadline);
    return const SizedBox.shrink();
  }
}
