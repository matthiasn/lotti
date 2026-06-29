import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:lotti/features/character/demo/dance_camera_director.dart';
import 'package:lotti/features/character/demo/dance_lip_sync.dart';
import 'package:lotti/features/character/demo/dance_performance.dart';
import 'package:lotti/features/character/engine/autonomic.dart';
import 'package:lotti/features/character/model/face.dart';
import 'package:lotti/features/character/runtime/character_painter.dart';
import 'package:lotti/features/character/runtime/character_renderer.dart';
import 'package:lotti/features/character/runtime/character_scene.dart';
import 'package:lotti/features/character/samples/cat_in_suit.dart';
import 'package:lotti/features/scenery/layered_backdrop.dart';
import 'package:lotti/features/scenery/model/backdrop_scene.dart';
import 'package:lotti/features/scenery/runtime/stage_lights.dart';
import 'package:lotti/features/scenery/scene_texture_overlay.dart';
import 'package:lotti/features/scenery/stage_lights_overlay.dart';

/// The generalized **live paint path** for the beat-synced dance showcase.
///
/// The whole point of this widget is that there is exactly ONE composite. The
/// live player (`DanceToTrackPage`) renders it, and every offline renderer — the
/// MP4 exporter, the position-window debug harness, the cinematography render
/// skill — pumps the *same* `DanceStageView` and captures its [RepaintBoundary].
/// So an offline frame is the live frame, not a hand-reconstruction that drifts.
///
/// It owns the paint constants and the stage-light rig that previously had to be
/// hand-synced across the two paint paths (gel cadence, backlight weights, body
/// grade, haze band, cast scale), so they cannot diverge. The per-frame
/// *derivation* (which move, warped clock, beat, camera) is supplied by the
/// caller from a [DancePerformance]; the stateful camera/mouth integration by a
/// `DancePlaybackStepper`.
class DanceStageView extends StatelessWidget {
  const DanceStageView({
    required this.cast,
    required this.renderer,
    required this.stage,
    required this.shot,
    required this.beat,
    required this.backdropTimeSeconds,
    required this.lightsTimeSeconds,
    required this.bpm,
    required this.leadMouth,
    required this.bgMouth,
    required this.leadShape,
    required this.bgShape,
    required this.dancerAnchors,
    this.onDancerAnchors,
    this.useNewBackdrop = true,
    this.showCaptions = false,
    this.words = const [],
    this.onBackdropReady,
    this.backdropImage,
    this.cloudsImage,
    this.wavesImage,
    this.boundaryKey,
    super.key,
  });

  /// The three dancers (lead, left, right).
  final DanceCast cast;
  final CharacterRenderer renderer;

  /// The frame's derived stage: lead clip, ensemble clips, warped clock, canon.
  final DanceStage stage;

  /// The virtual director's framing (applied verbatim by the painter).
  final Shot shot;

  /// 0..1 beat pulse (lights/foam brightness; never the cat bodies).
  final double beat;

  /// Audio position seconds — drives the scenery (it pauses/seeks with the
  /// track).
  final double backdropTimeSeconds;

  /// Clock for the ambient stage-light gel sweep. The live app passes a
  /// free-running wall clock (decoupled from the looping dance); offline
  /// renderers pass the audio position so a render is deterministic at a
  /// position.
  final double lightsTimeSeconds;

  /// Track tempo, which sets the gel-cycle period (`60 / bpm`).
  final double bpm;

  final double leadMouth;
  final double bgMouth;
  final MouthShape leadShape;
  final MouthShape bgShape;

  /// Last frame's published foot anchors (the lights track them, one frame
  /// lagged).
  final List<Offset> dancerAnchors;
  final ValueChanged<List<Offset>>? onDancerAnchors;

  /// The layered blue-hour scene (true) vs. the old single waterfront plate.
  final bool useNewBackdrop;

  final bool showCaptions;
  final List<DanceWord> words;
  final VoidCallback? onBackdropReady;

  /// Old-plate images (only used when [useNewBackdrop] is false).
  final ui.Image? backdropImage;
  final ui.Image? cloudsImage;
  final ui.Image? wavesImage;

  /// Key on the captured [RepaintBoundary] (offline renderers read its image).
  final Key? boundaryKey;

  @override
  Widget build(BuildContext context) {
    // One rig drives BOTH the per-cat rim/halo (memberBacklights) and the floor
    // pools, gel-cycling on the tempo, so a cat's glow always matches its pool.
    final rig = danceStageRig(bpm);
    final samples = useNewBackdrop
        ? rig.sample(time: lightsTimeSeconds, beat: beat)
        : const <StageLightSample>[];
    final backlights = danceMemberBacklights(samples);

    return RepaintBoundary(
      key: boundaryKey,
      child: Center(
        // Lock the stage to 16:9 so the painted 2560x1440 art maps 1:1 and never
        // crops/distorts; the resizable window letterboxes around it.
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              final scale = danceCastScale(constraints.maxHeight);
              // Parallax the scene behind the dancers, lagged, matching the
              // foreground camera the painter applies.
              final backdropTransform =
                  CharacterPainter.danceParallaxTransformForShot(
                    shot: shot,
                    size: size,
                  );
              return Stack(
                fit: StackFit.expand,
                children: [
                  if (useNewBackdrop)
                    Transform(
                      transform: backdropTransform,
                      filterQuality: FilterQuality.low,
                      child: LayeredBackdrop(
                        scene: BackdropScene.blueHourWaterfront(),
                        timeSeconds: backdropTimeSeconds,
                        beatPulse: beat,
                        onReady: onBackdropReady,
                      ),
                    ),
                  // Aerial-perspective haze band at the waterline (frame-fixed,
                  // fades out above the dancers' feet so they stay crisp).
                  if (useNewBackdrop)
                    const DecoratedBox(
                      decoration: BoxDecoration(gradient: kDanceHazeGradient),
                      child: SizedBox.expand(),
                    ),
                  // Floor pools under the feet, grounding each cat in its gel.
                  if (useNewBackdrop)
                    StageLightsOverlay(
                      timeSeconds: lightsTimeSeconds,
                      beat: beat,
                      dancerAnchors: dancerAnchors,
                      rig: rig,
                    ),
                  if (useNewBackdrop) const SceneTextureOverlay(),
                  CustomPaint(
                    painter: CharacterPainter(
                      scene: cast.lead,
                      partnerScene: cast.left,
                      ensembleScenes: [cast.left, cast.right],
                      ensembleExpressions: [
                        danceSingExpression(
                          leadMouth,
                          Expression.neutral,
                          leadShape,
                        ),
                        danceSingExpression(
                          bgMouth,
                          Expression.content,
                          bgShape,
                        ),
                        danceSingExpression(bgMouth, Expression.happy, bgShape),
                      ],
                      ensembleClips: stage.ensemble,
                      synchronousEnsemble: stage.synchronous,
                      singingHeadMotion: true,
                      walkingPair: true,
                      clip: stage.lead,
                      timeSeconds: stage.seconds,
                      cameraOverride: shot,
                      onDancerAnchors: useNewBackdrop ? onDancerAnchors : null,
                      scale: scale,
                      groundColor: useNewBackdrop
                          ? null
                          : const Color(0xFF374551),
                      backdrop: useNewBackdrop
                          ? CharacterBackdrop.none
                          : CharacterBackdrop.waterfront,
                      backdropImage: useNewBackdrop ? null : backdropImage,
                      backdropCloudsImage: useNewBackdrop ? null : cloudsImage,
                      backdropWavesImage: useNewBackdrop ? null : wavesImage,
                      memberBacklights: backlights,
                      bodyGrade: useNewBackdrop ? kDanceBodyGrade : null,
                      heroStaging: useNewBackdrop,
                      renderer: renderer,
                    ),
                    child: const SizedBox.expand(),
                  ),
                  if (showCaptions && words.isNotEmpty)
                    Positioned(
                      left: 24,
                      right: 24,
                      top: 20,
                      child: Center(
                        child: DanceCaption(
                          words: words,
                          positionSeconds: backdropTimeSeconds,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The three dancers, built once. Rebuilding a rig is expensive, so a player or
/// renderer holds one [DanceCast] for its lifetime.
class DanceCast {
  DanceCast({required this.lead, required this.left, required this.right});

  /// The standard trio: a lead with slightly stronger limbs plus two backups.
  factory DanceCast.build() => DanceCast(
    lead: CharacterScene(
      buildCatInSuitRig(
        legWidthScale: kDanceLeadLegWidthScale,
        armWidthScale: kDanceLeadArmWidthScale,
      ),
      autonomic: danceAutonomic(11),
    ),
    left: CharacterScene(
      buildCatInSuitRig(palette: CatInSuitPalette.silverTabby),
      autonomic: danceAutonomic(29),
    ),
    right: CharacterScene(
      buildCatInSuitRig(palette: CatInSuitPalette.darkBrown),
      autonomic: danceAutonomic(47),
    ),
  );

  final CharacterScene lead;
  final CharacterScene left;
  final CharacterScene right;
}

/// The autonomic (blink / eye-dart) layer used for every dancer — same cadence,
/// per-cat [seed].
AutonomicLayer danceAutonomic(int seed) => AutonomicLayer(
  seed: seed,
  blinkIntervalBase: 1.7,
  blinkIntervalJitter: 1.1,
  eyeDartInterval: 1.05,
  eyeDartAmplitude: 0.75,
);

/// The concert gel rig. The cycle period is the tempo (`60 / bpm`), so the gels
/// rotate one colour per beat; the lead lane is locked to the hero gold.
StageLightRig danceStageRig(double bpm) =>
    StageLightRig(colorPeriod: bpm > 0 ? 60 / bpm : 0.5, leadGoldIndex: 1);

/// Per-cat rim/halo colours from the rig [samples]: screen order
/// (left→center→right), the centre (lead) hotter so the hero owns the frame.
List<Color> danceMemberBacklights(List<StageLightSample> samples) => [
  for (final (i, s) in samples.indexed)
    s.color.withValues(
      alpha: (s.intensity * kDanceHeroWeight[i % kDanceHeroWeight.length])
          .clamp(0.0, 1.0),
    ),
];

/// Rim-halo weight per screen lane (centre lead hotter, flankers near full).
const List<double> kDanceHeroWeight = [0.9, 1.1, 0.9];

/// Sizes the cast to the stage height (the painter scales uniformly). At the
/// authored ~300-unit body height, 0.78 lands the feet on the painted deck.
double danceCastScale(double stageHeight) => stageHeight * 0.78 / 300.0;

/// Grades the cats into the twilight plate (static, not beat-driven): a cool sky
/// wrap up top fading to a lighter warm deck bounce down low.
const ({Color skyWrap, Color deckWrap}) kDanceBodyGrade = (
  skyWrap: Color(0x2E1F3354),
  deckWrap: Color(0x1E3A2616),
);

/// The waterline haze gradient (a soft cool veil that separates the foreground
/// cat plane from the distant city/water; fades out above the feet).
const LinearGradient kDanceHazeGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    Color(0x005E7088),
    Color(0x005E7088),
    Color(0x2C5E7088),
    Color(0x185E7088),
    Color(0x005E7088),
  ],
  stops: [0.0, 0.40, 0.52, 0.64, 0.76],
);

/// The karaoke caption: a short window of lyric words centred on the current
/// one (highlighted). Empty when no word is active. Shared by the live player
/// and the offline renderers so the caption can't drift.
class DanceCaption extends StatelessWidget {
  const DanceCaption({
    required this.words,
    required this.positionSeconds,
    super.key,
  });

  final List<DanceWord> words;
  final double positionSeconds;

  /// Index of the lyric word to caption: the most recent word that has started,
  /// hidden during instrumental gaps (>2 s after the last word ended).
  static int? captionWordIndex(List<DanceWord> words, double pos) {
    int? recent;
    for (var i = 0; i < words.length; i++) {
      if (words[i].start <= pos) {
        recent = i;
      } else {
        break;
      }
    }
    if (recent == null) return null;
    if (pos - words[recent].end > 2.0) return null;
    return recent;
  }

  @override
  Widget build(BuildContext context) {
    final i = captionWordIndex(words, positionSeconds);
    if (i == null) return const SizedBox.shrink();
    final from = i - 3 < 0 ? 0 : i - 3;
    final to = i + 4 > words.length ? words.length : i + 4;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: RichText(
          text: TextSpan(
            children: [
              for (var j = from; j < to; j++)
                TextSpan(
                  text: '${words[j].word} ',
                  style: TextStyle(
                    color: j == i ? Colors.white : Colors.white54,
                    fontSize: j == i ? 26 : 21,
                    fontWeight: j == i ? FontWeight.w700 : FontWeight.w400,
                    height: 1.2,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
