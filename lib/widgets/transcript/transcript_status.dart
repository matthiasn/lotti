import 'dart:async';

import 'package:clock/clock.dart';
import 'package:material_ui/material_ui.dart';

/// Where a recording's words are — the one vocabulary every check-in surface
/// speaks, Goals and People alike, drawn by `RecordingTranscript`.
///
/// A recording is the user's own and is never lost if transcription fails,
/// so every surface has to be able to show a recording whose words do not
/// exist yet; this is how it says why.
enum TranscriptStatus {
  /// The words are here.
  heard,

  /// Asked for and on their way — or recorded so recently that they may
  /// still be.
  transcribing,

  /// No words, nothing running, no failure on record: nothing picked the
  /// recording up. Distinct from [failed] because nothing ran, so saying
  /// "transcription failed" would be a lie; the same Retry applies.
  notTranscribed,

  /// A transcription ran and failed.
  failed,
}

/// How long a recording with no words and nothing working on it still counts
/// as [TranscriptStatus.transcribing] before it is [TranscriptStatus.notTranscribed].
///
/// Long enough to cover a queued transcription on a slow provider, short
/// enough that a recording nothing will ever pick up stops promising words
/// while the user is still looking at it.
const Duration kTranscriptGrace = Duration(minutes: 10);

/// What a recording shows where its words would be.
///
/// Words win. Without them a [running] transcription is
/// [TranscriptStatus.transcribing]; a [failed] one (a live error or a
/// durable failure on record) is [TranscriptStatus.failed]; and an idle
/// recording is transcribing until [graceExpiry], then
/// [TranscriptStatus.notTranscribed].
///
/// Hosts that cannot see a transcription's progress — a list of rows read
/// from the journal — pass `running: false, failed: false` and get the grace
/// rule alone, which is still honest: a recording from last week is not
/// being transcribed.
TranscriptStatus transcriptStatusOf({
  required bool hasTranscript,
  required DateTime graceExpiry,
  required DateTime now,
  bool running = false,
  bool failed = false,
}) {
  if (hasTranscript) return TranscriptStatus.heard;
  if (running) return TranscriptStatus.transcribing;
  if (failed) return TranscriptStatus.failed;
  return graceExpiry.isAfter(now)
      ? TranscriptStatus.transcribing
      : TranscriptStatus.notTranscribed;
}

/// Rebuilds a surface showing recordings the moment the soonest grace window
/// closes ([transcriptStatusOf]).
///
/// Without it the status is only recomputed when something else rebuilds —
/// a transcript arriving, an inference status changing, a database
/// notification. A user who records and stays on the page gets none of those
/// when the recording is exactly the one nothing picked up, so it would sit
/// on "Transcribing…" for as long as the page stayed open: the one case the
/// not-transcribed state exists to catch is the one case nothing would have
/// refreshed.
mixin TranscriptGraceRebuild<T extends StatefulWidget> on State<T> {
  Timer? _graceTimer;
  DateTime? _armedFor;

  @override
  void dispose() {
    _graceTimer?.cancel();
    super.dispose();
  }

  /// Arms (or re-arms, or cancels) the rebuild for [deadline].
  ///
  /// Idempotent on the deadline, because this is called from `build` and must
  /// not restart the timer on every unrelated rebuild — that would push the
  /// wake-up further out each time and never fire.
  void armGraceRebuild(DateTime? deadline) {
    if (deadline == _armedFor) return;
    _graceTimer?.cancel();
    _armedFor = deadline;
    if (deadline == null) return;
    final remaining = deadline.difference(clock.now());
    _graceTimer = Timer(
      remaining.isNegative ? Duration.zero : remaining,
      () {
        if (!mounted) return;
        // Cleared so the next build's deadline is never mistaken for the one
        // just served, which would leave the following recording unarmed.
        setState(() => _armedFor = null);
      },
    );
  }
}
