import 'package:lotti/features/companion/animation/mouth_track.dart';
import 'package:lotti/features/companion/animation/tone_reader.dart';

/// How what she says lands, timed by the same playhead as her mouth: the
/// approval of the sentence the voice is in, so her face can change as the
/// words turn from praise to what needs work.
class ToneTrack {
  ToneTrack(List<({Duration start, int? approval})> cues)
    : cues = List.unmodifiable(cues);

  /// The tones of [text] ([readTones]) at the times [mouth] speaks them.
  /// A mouth with no words to place (a voice alone) gives no cues.
  factory ToneTrack.read(String text, MouthTrack mouth) => ToneTrack([
    for (final cue in readTones(text))
      if (mouth.timeOf(cue.offset) case final start?)
        (start: start, approval: cue.approval),
  ]);

  /// When each tone starts, in order.
  final List<({Duration start, int? approval})> cues;

  /// The approval at [position], or null before the first cue and where the
  /// words read neither way.
  int? approvalAt(Duration position) {
    int? approval;
    for (final cue in cues) {
      if (cue.start > position) break;
      approval = cue.approval;
    }
    return approval;
  }
}
