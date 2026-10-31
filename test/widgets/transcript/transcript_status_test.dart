import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/transcript/transcript_status.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  final now = DateTime(2026, 8, 11, 12);
  final graceOpen = now.add(const Duration(minutes: 5));
  final graceClosed = now.subtract(const Duration(minutes: 1));

  TranscriptStatus status({
    bool hasTranscript = false,
    bool running = false,
    bool failed = false,
    DateTime? graceExpiry,
  }) => transcriptStatusOf(
    hasTranscript: hasTranscript,
    running: running,
    failed: failed,
    graceExpiry: graceExpiry ?? graceOpen,
    now: now,
  );

  test('words win over every other signal', () {
    expect(
      status(
        hasTranscript: true,
        running: true,
        failed: true,
        graceExpiry: graceClosed,
      ),
      TranscriptStatus.heard,
    );
  });

  test('a running transcription is transcribing, even past the grace '
      'window', () {
    expect(
      status(running: true, graceExpiry: graceClosed),
      TranscriptStatus.transcribing,
    );
  });

  test('a failure on record is a failure, inside the window or not', () {
    expect(status(failed: true), TranscriptStatus.failed);
    expect(
      status(failed: true, graceExpiry: graceClosed),
      TranscriptStatus.failed,
    );
  });

  test('an idle recording waits out the grace window, then is not '
      'transcribed', () {
    expect(status(), TranscriptStatus.transcribing);
    expect(status(graceExpiry: graceClosed), TranscriptStatus.notTranscribed);
  });

  test('the window closes at its deadline, not a moment later', () {
    expect(status(graceExpiry: now), TranscriptStatus.notTranscribed);
  });

  test('a host that cannot see a transcription gets the grace rule alone', () {
    final recorded = now.subtract(const Duration(days: 3));
    expect(
      transcriptStatusOf(
        hasTranscript: false,
        graceExpiry: recorded.add(kTranscriptGrace),
        now: now,
      ),
      TranscriptStatus.notTranscribed,
      reason: 'a recording from last week is not being transcribed',
    );
  });

  group('TranscriptGraceRebuild', () {
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

class _GraceHostState extends State<_GraceHost> with TranscriptGraceRebuild {
  @override
  Widget build(BuildContext context) {
    widget.onBuild();
    armGraceRebuild(widget.deadline);
    return const SizedBox.shrink();
  }
}
