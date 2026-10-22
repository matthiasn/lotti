import 'package:lotti/features/companion/animation/mouth_track.dart';
import 'package:lotti/features/companion/animation/tone_reader.dart';
import 'package:lotti/features/companion/model/companion_reaction.dart';

/// One stretch of the words, by when the voice reaches it: how it reads and
/// the beat it turns on, as its [ToneCue] has them.
typedef ToneTrackCue = ({Duration start, int? approval, SassBeat? beat});

/// How what she says lands, timed by the same playhead as her mouth: the
/// approval of the sentence the voice is in, so her face can change as the
/// words turn from praise to what needs work, and the beats — a question, a
/// "but", a "finally" — she pulls a face on as the voice reaches them.
class ToneTrack {
  ToneTrack(List<ToneTrackCue> cues, {this.end})
    : cues = List.unmodifiable(cues);

  /// The tones of [text] ([readTones]) at the times [mouth] speaks them.
  /// A mouth with no words to place (a voice alone) gives no cues.
  factory ToneTrack.read(String text, MouthTrack mouth) => ToneTrack(
    [
      for (final cue in readTones(text))
        if (mouth.timeOf(cue.offset) case final start?)
          (start: start, approval: cue.approval, beat: cue.beat),
    ],
    end: mouth.timeOf(text.length),
  );

  /// When each stretch starts, in order.
  final List<ToneTrackCue> cues;

  /// When the last word has been spoken, or null where that is not known:
  /// then the end of the clip stands in for it.
  final Duration? end;

  /// The index in [cues] of the latest cue at or before [position], or -1
  /// before the first. A change of index is the voice reaching a new cue.
  int indexAt(Duration position) {
    var index = -1;
    for (var i = 0; i < cues.length; i++) {
      if (cues[i].start > position) break;
      index = i;
    }
    return index;
  }

  /// The approval at [position], or null before the first cue and where the
  /// words read neither way.
  int? approvalAt(Duration position) {
    final index = indexAt(position);
    return index < 0 ? null : cues[index].approval;
  }
}
