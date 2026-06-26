import 'package:lotti/features/character/model/clip.dart';
import 'package:lotti/features/character/model/easing.dart';

/// Frame-addressed choreography data that compiles into the lower-level clip
/// primitives.
///
/// The regular animation engine samples normalized phases (`0..1`). Dance
/// review, however, happens on counts and frames: "frame 16 is the right-foot
/// plant" is much easier to reason about than `p: 0.5`. This layer keeps the
/// authored intent in those terms, then converts it to [GroundSpan],
/// [KeyframeChannel], [KeyframeRootChannel], [KeyframeIkTargetChannel], and
/// synchronized body-groove channels so the runtime stays unchanged.
class DancePhrase {
  const DancePhrase({
    required this.frameCount,
    required this.supports,
    this.sections = const [],
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

  /// Named movement windows in the phrase. These are review/choreography
  /// handles, e.g. "Shaku pocket" or "Gbese toe-flick answer"; lower-level
  /// channels still carry the exact bone values.
  final List<DancePhraseSection> sections;

  double phaseOf(int frame) {
    _checkFrame(frame);
    return frame / frameCount;
  }

  List<GroundSpan> contactSpans() => [
    for (final support in supports) support.toGroundSpan(this),
  ];

  DanceSupportSpan supportAtFrame(int frame) {
    final wrappedFrame = _wrappedFrame(frame);
    for (final support in supports) {
      if (support.containsFrame(wrappedFrame)) return support;
    }
    throw StateError('No dance support covers frame $wrappedFrame.');
  }

  DanceSupportSpan supportAtPhase(double phase) {
    final normalized = phase - phase.floorToDouble();
    final frame = (normalized * frameCount).floor();
    return supportAtFrame(frame);
  }

  DancePhraseSection sectionAtFrame(int frame) {
    final wrappedFrame = _wrappedFrame(frame);
    for (final section in sections) {
      if (section.containsFrame(wrappedFrame)) return section;
    }
    throw StateError('No dance section covers frame $wrappedFrame.');
  }

  DancePhraseSection sectionAtPhase(double phase) {
    final normalized = phase - phase.floorToDouble();
    final frame = (normalized * frameCount).floor();
    return sectionAtFrame(frame);
  }

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

  List<DanceJointKey> jointAccentKeys(List<DanceJointAccent> accents) {
    final keys = <DanceJointKey>[];
    for (final accent in accents) {
      final startFrame = accent.frame - accent.radiusFrames;
      final endFrame = accent.frame + accent.radiusFrames;
      _checkFrame(startFrame);
      _checkFrame(accent.frame);
      _checkFrame(endFrame);
      keys
        ..add(accent.neutralKey(startFrame))
        ..add(accent.peakKey())
        ..add(accent.neutralKey(endFrame));
    }
    keys.sort((a, b) => a.frame.compareTo(b.frame));
    return List<DanceJointKey>.unmodifiable(keys);
  }

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

  KeyframeRootChannel bodyRootChannel(
    List<DanceBodyKey> keys, {
    bool smooth = false,
  }) => KeyframeRootChannel(
    [
      for (final key in keys)
        if (key.hasRoot) key.toRootKeyframe(this),
    ],
    smooth: smooth,
  );

  List<DanceBodyKey> bodyAccentKeys(List<DanceBodyAccent> accents) {
    final keys = <DanceBodyKey>[];
    for (final accent in accents) {
      final startFrame = accent.frame - accent.radiusFrames;
      final endFrame = accent.frame + accent.radiusFrames;
      _checkFrame(startFrame);
      _checkFrame(accent.frame);
      _checkFrame(endFrame);
      keys
        ..add(accent.neutralKey(startFrame))
        ..add(accent.peakKey())
        ..add(accent.neutralKey(endFrame));
    }
    keys.sort((a, b) => a.frame.compareTo(b.frame));
    return List<DanceBodyKey>.unmodifiable(keys);
  }

  KeyframeChannel bodyPelvisChannel(
    List<DanceBodyKey> keys, {
    bool smooth = false,
  }) => KeyframeChannel(
    [
      for (final key in keys)
        if (key.hasPelvis) key.toPelvisKeyframe(this),
    ],
    smooth: smooth,
  );

  KeyframeChannel bodyChestChannel(
    List<DanceBodyKey> keys, {
    bool smooth = false,
  }) => KeyframeChannel(
    [
      for (final key in keys)
        if (key.hasChest) key.toChestKeyframe(this),
    ],
    smooth: smooth,
  );

  IkTargetKeyframe ikTargetKey(
    int frame, {
    required double x,
    required double y,
    double weight = 1,
    Ease ease = Ease.easeInOut,
  }) => IkTargetKeyframe(
    p: phaseOf(frame),
    x: x,
    y: y,
    weight: weight,
    ease: ease,
  );

  KeyframeIkTargetChannel ikTargetChannel(
    List<DanceIkTargetKey> keys, {
    bool smooth = false,
  }) => KeyframeIkTargetChannel(
    [for (final key in keys) key.toIkTargetKeyframe(this)],
    smooth: smooth,
  );

  List<DanceIkTargetKey> ikTargetAccentKeys(
    List<DanceIkTargetAccent> accents,
  ) {
    final keys = <DanceIkTargetKey>[];
    for (final accent in accents) {
      final startFrame = accent.frame - accent.radiusFrames;
      final endFrame = accent.frame + accent.radiusFrames;
      _checkFrame(startFrame);
      _checkFrame(accent.frame);
      _checkFrame(endFrame);
      keys
        ..add(accent.neutralKey(startFrame))
        ..add(accent.peakKey())
        ..add(accent.neutralKey(endFrame));
    }
    keys.sort((a, b) => a.frame.compareTo(b.frame));
    return List<DanceIkTargetKey>.unmodifiable(keys);
  }

  void _checkFrame(int frame) {
    RangeError.checkValueInInterval(frame, 0, frameCount, 'frame');
  }

  int _wrappedFrame(int frame) {
    _checkFrame(frame);
    return frame == frameCount ? 0 : frame;
  }
}

class DanceSupportSpan {
  const DanceSupportSpan({
    required this.footBoneId,
    required this.freeFootBoneId,
    required this.startFrame,
    required this.endFrame,
    required this.loadFrame,
    required this.releaseFrame,
    required this.maxPelvisDistance,
    required this.pocketScaleY,
    required this.label,
  }) : assert(startFrame < endFrame, 'support span must move forward'),
       assert(
         startFrame <= loadFrame && loadFrame < endFrame,
         'load frame must be inside the support span',
       ),
       assert(
         startFrame < releaseFrame && releaseFrame <= endFrame,
         'release frame must finish inside the support span',
       ),
       assert(maxPelvisDistance > 0, 'max pelvis distance must be positive'),
       assert(
         pocketScaleY > 0 && pocketScaleY <= 1,
         'pocket scale must be a positive compression multiplier',
       );

  final String footBoneId;
  final String freeFootBoneId;
  final int startFrame;
  final int endFrame;

  /// Strongest body-load frame inside the support. This is where the hips should
  /// visibly settle over the planted foot and the torso can compress into the
  /// pocket.
  final int loadFrame;

  /// Last frame of the support's release. It must stay inside the span so a
  /// handoff has time to prepare before the next foot takes weight.
  final int releaseFrame;

  /// Maximum intended world-space horizontal distance from pelvis origin to the
  /// support-foot contact point during this support. Tests use this to keep the
  /// pose readable as loaded over one leg instead of drifting away from it.
  final double maxPelvisDistance;

  /// Intended torso `scaleY` at the load frame. Lower values mean a deeper
  /// pocket/squash over the support foot.
  final double pocketScaleY;

  /// Human-readable choreographic intent, e.g. "left low pocket".
  ///
  /// The runtime does not use this, but tests and reviewers can point to the
  /// support move by name instead of only by a number.
  final String label;

  bool containsFrame(int frame) => frame >= startFrame && frame < endFrame;

  GroundSpan toGroundSpan(DancePhrase phrase) => GroundSpan(
    footBoneId,
    phrase.phaseOf(startFrame),
    phrase.phaseOf(endFrame),
  );
}

class DancePhraseSection {
  const DancePhraseSection({
    required this.name,
    required this.startFrame,
    required this.endFrame,
    required this.intent,
  }) : assert(startFrame < endFrame, 'section must move forward');

  final String name;
  final int startFrame;
  final int endFrame;

  /// Short choreographic purpose of the section. Kept data-side so panel
  /// feedback can target a movement idea, not just a numeric frame range.
  final String intent;

  bool containsFrame(int frame) => frame >= startFrame && frame < endFrame;
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

class DanceJointAccent {
  const DanceJointAccent(
    this.frame, {
    required this.radiusFrames,
    this.rotation = 0,
    this.scaleX = 1,
    this.scaleY = 1,
    this.ease = Ease.easeInOut,
  }) : assert(radiusFrames > 0, 'radiusFrames must be positive');

  final int frame;
  final int radiusFrames;
  final double rotation;
  final double scaleX;
  final double scaleY;
  final Ease ease;

  DanceJointKey neutralKey(int frame) => DanceJointKey(
    frame,
    ease: ease,
  );

  DanceJointKey peakKey() => DanceJointKey(
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

class DanceBodyKey {
  const DanceBodyKey(
    this.frame, {
    this.rootDx,
    this.rootDy,
    this.rootRotation,
    this.pelvisRotation,
    this.chestRotation,
    this.chestScaleX,
    this.chestScaleY,
    this.ease = Ease.easeInOut,
  });

  final int frame;
  final double? rootDx;
  final double? rootDy;
  final double? rootRotation;
  final double? pelvisRotation;
  final double? chestRotation;
  final double? chestScaleX;
  final double? chestScaleY;
  final Ease ease;

  bool get hasRoot => rootDx != null || rootDy != null || rootRotation != null;

  bool get hasPelvis => pelvisRotation != null;

  bool get hasChest =>
      chestRotation != null || chestScaleX != null || chestScaleY != null;

  RootKeyframe toRootKeyframe(DancePhrase phrase) => phrase.rootKey(
    frame,
    dx: rootDx ?? 0,
    dy: rootDy ?? 0,
    rotation: rootRotation ?? 0,
    ease: ease,
  );

  Keyframe toPelvisKeyframe(DancePhrase phrase) => phrase.jointKey(
    frame,
    rotation: pelvisRotation ?? 0,
    ease: ease,
  );

  Keyframe toChestKeyframe(DancePhrase phrase) => phrase.jointKey(
    frame,
    rotation: chestRotation ?? 0,
    scaleX: chestScaleX ?? 1,
    scaleY: chestScaleY ?? 1,
    ease: ease,
  );
}

class DanceBodyAccent {
  const DanceBodyAccent(
    this.frame, {
    required this.radiusFrames,
    this.rootDx,
    this.rootDy,
    this.rootRotation,
    this.pelvisRotation,
    this.chestRotation,
    this.chestScaleX,
    this.chestScaleY,
    this.ease = Ease.easeInOut,
  }) : assert(radiusFrames > 0, 'radiusFrames must be positive');

  final int frame;
  final int radiusFrames;
  final double? rootDx;
  final double? rootDy;
  final double? rootRotation;
  final double? pelvisRotation;
  final double? chestRotation;
  final double? chestScaleX;
  final double? chestScaleY;
  final Ease ease;

  bool get _hasRoot => rootDx != null || rootDy != null || rootRotation != null;

  bool get _hasPelvis => pelvisRotation != null;

  bool get _hasChest =>
      chestRotation != null || chestScaleX != null || chestScaleY != null;

  DanceBodyKey neutralKey(int frame) => DanceBodyKey(
    frame,
    rootDx: _hasRoot ? 0 : null,
    rootDy: _hasRoot ? 0 : null,
    rootRotation: _hasRoot ? 0 : null,
    pelvisRotation: _hasPelvis ? 0 : null,
    chestRotation: _hasChest ? 0 : null,
    chestScaleX: _hasChest ? 1 : null,
    chestScaleY: _hasChest ? 1 : null,
    ease: ease,
  );

  DanceBodyKey peakKey() => DanceBodyKey(
    frame,
    rootDx: _hasRoot ? rootDx ?? 0 : null,
    rootDy: _hasRoot ? rootDy ?? 0 : null,
    rootRotation: _hasRoot ? rootRotation ?? 0 : null,
    pelvisRotation: pelvisRotation,
    chestRotation: _hasChest ? chestRotation ?? 0 : null,
    chestScaleX: _hasChest ? chestScaleX ?? 1 : null,
    chestScaleY: _hasChest ? chestScaleY ?? 1 : null,
    ease: ease,
  );
}

class DanceIkTargetKey {
  const DanceIkTargetKey(
    this.frame, {
    required this.x,
    required this.y,
    this.weight = 1,
    this.ease = Ease.easeInOut,
  });

  final int frame;
  final double x;
  final double y;
  final double weight;
  final Ease ease;

  IkTargetKeyframe toIkTargetKeyframe(DancePhrase phrase) => phrase.ikTargetKey(
    frame,
    x: x,
    y: y,
    weight: weight,
    ease: ease,
  );
}

class DanceIkTargetAccent {
  const DanceIkTargetAccent(
    this.frame, {
    required this.radiusFrames,
    required this.x,
    required this.y,
    this.weight = 1,
    this.ease = Ease.easeInOut,
  }) : assert(radiusFrames > 0, 'radiusFrames must be positive');

  final int frame;
  final int radiusFrames;
  final double x;
  final double y;
  final double weight;
  final Ease ease;

  DanceIkTargetKey neutralKey(int frame) => DanceIkTargetKey(
    frame,
    x: 0,
    y: 0,
    weight: 0,
    ease: ease,
  );

  DanceIkTargetKey peakKey() => DanceIkTargetKey(
    frame,
    x: x,
    y: y,
    weight: weight,
    ease: ease,
  );
}

class DanceRoleStyle {
  const DanceRoleStyle({
    this.bodyAccents = const <DanceBodyAccent>[],
    this.ikTargetAccents = const <String, List<DanceIkTargetAccent>>{},
    this.jointAccents = const <String, List<DanceJointAccent>>{},
  });

  /// Body-pocket/style pulses for this dancer role.
  final List<DanceBodyAccent> bodyAccents;

  /// Local IK target pulses, keyed by target/end bone id.
  final Map<String, List<DanceIkTargetAccent>> ikTargetAccents;

  /// Additive FK joint pulses, keyed by bone id.
  final Map<String, List<DanceJointAccent>> jointAccents;

  List<DanceBodyKey> bodyKeys(DancePhrase phrase) =>
      phrase.bodyAccentKeys(bodyAccents);

  List<DanceIkTargetKey> ikTargetKeys(
    DancePhrase phrase,
    String targetBoneId,
  ) => phrase.ikTargetAccentKeys(
    ikTargetAccents[targetBoneId] ?? const <DanceIkTargetAccent>[],
  );

  List<DanceJointKey> jointKeys(
    DancePhrase phrase,
    String boneId,
  ) => phrase.jointAccentKeys(
    jointAccents[boneId] ?? const <DanceJointAccent>[],
  );
}
