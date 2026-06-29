import 'package:lotti/features/character/model/face.dart';

/// Pure lip-sync mapping for the dance-to-track demo, extracted from the widget
/// so it is unit-testable. The demo feeds a Rhubarb cue track (mouth-shape
/// letters over time, from `tools/dance_audio/lipsync.py`) through these.

/// A Rhubarb mouth-shape cue: a shape letter active over a half-open span.
typedef DanceCue = ({double start, double end, String shape});

/// Maps a Rhubarb cue letter to a singing viseme + how far the mouth opens
/// (0 = shut). Vowels grow/round; `G` is the tight F/V consonant; `A`/`X` (and
/// anything unrecognised) rest closed. Openings are kept tasteful — a sung
/// syllable, not a gape.
({MouthShape shape, double open}) mouthForCue(String letter) {
  switch (letter) {
    case 'B': // slightly open, teeth near-closed
      return (shape: MouthShape.singEe, open: 0.3);
    case 'C': // open (EH, AE)
      return (shape: MouthShape.singAh, open: 0.46);
    case 'D': // wide open (AA) — the biggest, still tasteful
      return (shape: MouthShape.singAh, open: 0.6);
    case 'E': // slightly rounded (AO, ER)
      return (shape: MouthShape.singOh, open: 0.4);
    case 'F': // puckered (UW, OW, W)
      return (shape: MouthShape.singOh, open: 0.26);
    case 'G': // F, V — tight near-closed consonant
      return (shape: MouthShape.teethOnLip, open: 0.1);
    case 'H': // "L" — tongue up
      return (shape: MouthShape.singAh, open: 0.4);
    default: // 'A' closed, 'X' idle, or unknown
      return (shape: MouthShape.singAh, open: 0);
  }
}

/// A face whose mouth is driven open by [mouth] (lyric-synced) on the [shape]
/// viseme, falling back to [base] when essentially closed. The upper face sings
/// too: brows lift and the eyes squint a touch as the mouth opens, so the
/// performance isn't a dead-eyed mask over a moving mouth. Shared by the live
/// player and the offline composer.
Expression danceSingExpression(
  double mouth,
  Expression base,
  MouthShape shape,
) {
  if (mouth < 0.04) return base;
  final brow = 0.18 + mouth * 0.4; // gentle engagement, not a hard arch
  final eye = 1 - mouth * 0.18; // a whisper of a squint, not a grimace
  return Expression(
    'sing',
    FaceState(
      mouthShape: shape,
      mouthOpen: mouth,
      browRaiseLeft: brow,
      browRaiseRight: brow,
      eyeOpenLeft: eye,
      eyeOpenRight: eye,
    ),
  );
}

/// The cue shape active at [pos] in a time-ordered [cues] list; `'X'` (rest) when
/// none. Stops early once a cue starts after [pos].
String cueShapeAt(List<DanceCue> cues, double pos) {
  for (final c in cues) {
    if (pos >= c.start && pos < c.end) return c.shape;
    if (c.start > pos) break;
  }
  return 'X';
}

/// Whether the half-open window `[start, end)` — dilated by [slack] on each side
/// — contains [pos]. The dilation bridges the short gaps between a phrase's words
/// so a singer's mouth doesn't flicker shut mid-phrase; it only rests between
/// phrases (gaps wider than `2 * slack`).
bool windowActiveAt(double start, double end, double pos, double slack) =>
    pos >= start - slack && pos < end + slack;
