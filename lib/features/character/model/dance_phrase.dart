import 'package:lotti/features/character/model/clip.dart';
import 'package:lotti/features/character/model/easing.dart';

/// Frame-addressed choreography data that compiles into the lower-level clip
/// primitives.
///
/// The regular animation engine samples normalized phases (`0..1`). Dance
/// review, however, happens on counts and frames: "frame 16 is the right-foot
/// plant" is much easier to reason about than `p: 0.5`. This layer keeps the
/// authored intent in those terms, then converts it to [GroundSpan],
/// [KeyframeChannel], and [KeyframeRootChannel] so the runtime stays unchanged.
class DancePhrase {
  const DancePhrase({
    required this.frameCount,
    required this.supports,
  }) : assert(frameCount > 0, 'frameCount must be positive');

  /// Number of authored frames in the looping phrase.
  ///
  /// A 32-frame phrase is two bars of sixteenth-note-addressable motion: frames
  /// `0, 4, 8, ...` are the main counts, while odd frames can hold pickup,
  /// settle, and loop-prep details.
  final int frameCount;

  /// Declared support-foot windows. These are choreography intent, not a
  /// locomotion curve: the scene solver uses them to keep the in-place dance
  /// grounded while the body grooves over the support.
  final List<DanceSupportSpan> supports;

  double phaseOf(int frame) {
    _checkFrame(frame);
    return frame / frameCount;
  }

  List<GroundSpan> contactSpans() => [
    for (final support in supports) support.toGroundSpan(this),
  ];

  Keyframe jointKey(
    int frame, {
    double rotation = 0,
    double scaleX = 1,
    double scaleY = 1,
    Ease ease = Ease.easeInOut,
  }) => Keyframe(
    p: phaseOf(frame),
    rotation: rotation,
    scaleX: scaleX,
    scaleY: scaleY,
    ease: ease,
  );

  KeyframeChannel jointChannel(
    List<DanceJointKey> keys, {
    double phase = 0,
    bool smooth = false,
  }) => KeyframeChannel(
    [for (final key in keys) key.toKeyframe(this)],
    phase: phase,
    smooth: smooth,
  );

  RootKeyframe rootKey(
    int frame, {
    double dx = 0,
    double dy = 0,
    double rotation = 0,
    Ease ease = Ease.easeInOut,
  }) => RootKeyframe(
    p: phaseOf(frame),
    dx: dx,
    dy: dy,
    rotation: rotation,
    ease: ease,
  );

  KeyframeRootChannel rootChannel(
    List<DanceRootKey> keys, {
    bool smooth = false,
  }) => KeyframeRootChannel(
    [for (final key in keys) key.toRootKeyframe(this)],
    smooth: smooth,
  );

  void _checkFrame(int frame) {
    RangeError.checkValueInInterval(frame, 0, frameCount, 'frame');
  }
}

class DanceSupportSpan {
  const DanceSupportSpan({
    required this.footBoneId,
    required this.startFrame,
    required this.endFrame,
    required this.label,
  }) : assert(startFrame < endFrame, 'support span must move forward');

  final String footBoneId;
  final int startFrame;
  final int endFrame;

  /// Human-readable choreographic intent, e.g. "left low pocket".
  ///
  /// The runtime does not use this, but tests and reviewers can point to the
  /// support move by name instead of only by a number.
  final String label;

  GroundSpan toGroundSpan(DancePhrase phrase) => GroundSpan(
    footBoneId,
    phrase.phaseOf(startFrame),
    phrase.phaseOf(endFrame),
  );
}

class DanceJointKey {
  const DanceJointKey(
    this.frame, {
    this.rotation = 0,
    this.scaleX = 1,
    this.scaleY = 1,
    this.ease = Ease.easeInOut,
  });

  final int frame;
  final double rotation;
  final double scaleX;
  final double scaleY;
  final Ease ease;

  Keyframe toKeyframe(DancePhrase phrase) => phrase.jointKey(
    frame,
    rotation: rotation,
    scaleX: scaleX,
    scaleY: scaleY,
    ease: ease,
  );
}

class DanceRootKey {
  const DanceRootKey(
    this.frame, {
    this.dx = 0,
    this.dy = 0,
    this.rotation = 0,
    this.ease = Ease.easeInOut,
  });

  final int frame;
  final double dx;
  final double dy;
  final double rotation;
  final Ease ease;

  RootKeyframe toRootKeyframe(DancePhrase phrase) => phrase.rootKey(
    frame,
    dx: dx,
    dy: dy,
    rotation: rotation,
    ease: ease,
  );
}
