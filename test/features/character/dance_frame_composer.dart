import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lotti/features/character/demo/dance_camera_director.dart';
import 'package:lotti/features/character/demo/dance_lip_sync.dart';
import 'package:lotti/features/character/demo/dance_loaders.dart';
import 'package:lotti/features/character/demo/dance_performance.dart';
import 'package:lotti/features/character/demo/dance_playback_stepper.dart';
import 'package:lotti/features/character/demo/dance_stage_view.dart';
import 'package:lotti/features/character/model/beat_map.dart';
import 'package:lotti/features/character/model/face.dart';
import 'package:lotti/features/character/runtime/character_painter.dart';
import 'package:lotti/features/character/runtime/character_renderer.dart';
import 'package:lotti/features/scenery/layers/backdrop_layer.dart';
import 'package:lotti/features/scenery/model/backdrop_palette.dart';
import 'package:lotti/features/scenery/model/backdrop_scene.dart';
import 'package:lotti/features/scenery/runtime/scenery_shaders.dart';
import 'package:lotti/features/scenery/runtime/stage_lights.dart';
import 'package:lotti/features/scenery/scene_texture_overlay.dart';
import 'package:lotti/features/scenery/stage_lights_overlay.dart';

/// Renders the beat-synced dance showcase to an offscreen canvas, frame by
/// frame, from an **audio position in seconds** — exactly as the live player
/// composes it, but without a widget tree.
///
/// This is the faithful offline render path shared by:
///  * the MP4 exporter (`dance_video_export_test.dart`), and
///  * the position-window debug harness (`dance_player_window_test.dart`).
///
/// Faithfulness comes from [DancePerformance]: the composer derives *what* to
/// show (which move, the warped pose clock, the beat, the camera context) from
/// the very same object the live player builds, so a render at position `p`
/// matches the running app at `p`. The only stateful, history-dependent inputs
/// are the camera rig's smoothing and the singing mouths; [advance] integrates
/// them per frame, so callers must **preroll** ([advance] without rendering)
/// from a lead-in up to the first frame they care about to settle the camera.
class DanceFrameComposer {
  DanceFrameComposer._({
    required this.perf,
    required this.cues,
    required this.bpm,
    required this.images,
    required this.skyProgram,
    required this.oceanProgram,
    required this.cityLightsProgram,
    required this.size,
    required this.captions,
  });

  /// Builds a composer for a loaded track. [json] is the beat-map document (for
  /// the embedded waveform + structural sections); [beatMap] its parsed map.
  static Future<DanceFrameComposer> load({
    required Map<String, Object?> json,
    required BeatMap beatMap,
    required double trackDurationSec,
    required String wordsPath,
    required String cuesPath,
    required Size size,
    required bool captions,
  }) async {
    final words = await loadDanceWords(wordsPath);
    final cues = await loadDanceCues(cuesPath);
    final perf = DancePerformance.fromBeatMapJson(
      json: json,
      map: beatMap,
      trackDurationSec: trackDurationSec,
      words: words,
    );
    final tempo = json['tempo'] as Map<String, Object?>?;
    final scene = BackdropScene.blueHourWaterfront();
    return DanceFrameComposer._(
      perf: perf,
      cues: cues,
      bpm: (tempo?['global_bpm'] as num?)?.toDouble() ?? 0,
      images: await _loadImages(scene.imageAssets),
      skyProgram: await SceneryShaderProgramCache.loadSky(),
      oceanProgram: await SceneryShaderProgramCache.loadOcean(),
      cityLightsProgram: await SceneryShaderProgramCache.loadCityLights(),
      size: size,
      captions: captions,
    );
  }

  /// The shared per-frame derivation — the single source of truth this composer
  /// renders, identical to the live player's.
  final DancePerformance perf;

  /// Rhubarb lip-sync cues driving the singing mouths (empty → mouths rest).
  final List<DanceCue> cues;

  /// Track tempo, which sets the gel-cycle period via [danceStageRig].
  final double bpm;
  final Map<String, ui.Image> images;
  final ui.FragmentProgram skyProgram;
  final ui.FragmentProgram oceanProgram;
  final ui.FragmentProgram cityLightsProgram;
  final Size size;
  final bool captions;

  // Cast, gel rig and paint constants are single-sourced from the generalized
  // live path ([DanceStageView]), so this offline canvas render references the
  // exact same values the running app paints with (it cannot drift on them).
  final DanceCast _cast = DanceCast.build();
  final CharacterRenderer _renderer = CharacterRenderer();
  late final StageLightRig _stageRig = danceStageRig(bpm);
  // The per-frame orchestration (eased mouths + smoothed camera) is the SAME
  // stepper the live player drives, so the two cannot diverge.
  final DancePlaybackStepper _stepper = DancePlaybackStepper();
  List<Offset> _dancerAnchors = const [];

  /// The framing the last [advance] settled on (after preroll). Lets debug tools
  /// label a frame with its camera zoom/pan.
  Shot get shot => _stepper.shot;

  /// Advances the stateful per-frame state (camera smoothing, singing mouths) by
  /// [dt] seconds at audio position [pos]. Call this WITHOUT rendering to preroll
  /// the camera before the first frame of interest.
  void advance(double pos, double dt) => _stepper.advance(perf, cues, pos, dt);

  /// Advances by [dt] then paints the frame at [pos] to a [ui.Image] (caller
  /// owns it and must `dispose()`). The raw image is what debug tools tile into
  /// a contact sheet; [renderFrame] wraps this for the encoded-bytes path.
  Future<ui.Image> renderImage(double pos, double dt) async {
    advance(pos, dt);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    _paintFrame(canvas, pos);
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      size.width.round(),
      size.height.round(),
    );
    picture.dispose();
    return image;
  }

  /// Advances by [dt] then renders the frame at [pos]. Returns raw RGBA always
  /// (for ffmpeg) and a PNG when [includePng] is set (for stills / debug grids).
  Future<({Uint8List rgba, Uint8List? png})> renderFrame(
    double pos,
    double dt, {
    required bool includePng,
  }) async {
    final image = await renderImage(pos, dt);
    final rgbaData = await image.toByteData();
    final pngData = includePng
        ? await image.toByteData(format: ui.ImageByteFormat.png)
        : null;
    image.dispose();
    if (rgbaData == null) throw StateError('failed to encode raw RGBA frame');
    return (
      rgba: rgbaData.buffer.asUint8List(
        rgbaData.offsetInBytes,
        rgbaData.lengthInBytes,
      ),
      png: pngData?.buffer.asUint8List(
        pngData.offsetInBytes,
        pngData.lengthInBytes,
      ),
    );
  }

  void dispose() {
    for (final image in images.values) {
      image.dispose();
    }
  }

  void _paintFrame(Canvas canvas, double pos) {
    final stage = _stepper.stage ?? perf.stageAt(pos);
    final beat = perf.beatPulse(pos);
    final parallax = CharacterPainter.danceParallaxTransformForShot(
      shot: _stepper.shot,
      size: size,
    );

    canvas
      ..drawRect(Offset.zero & size, Paint()..color = Colors.black)
      ..save()
      ..clipRect(Offset.zero & size)
      ..transform(parallax.storage);
    _paintBackdropLayers(
      canvas,
      BackdropScene.blueHourWaterfront().layers,
      pos,
      beat,
    );
    _paintBackdropLayers(
      canvas,
      BackdropScene.blueHourWaterfront().foregroundLayers,
      pos,
      beat,
    );
    canvas.restore();

    _paintHaze(canvas);
    StageLightsPainter(
      time: pos,
      beat: beat,
      rig: _stageRig,
      aimX: _dancerAnchors.length == _stageRig.count
          ? [for (final a in _dancerAnchors) a.dx]
          : null,
      footY: _dancerAnchors.length == _stageRig.count
          ? [for (final a in _dancerAnchors) a.dy]
          : null,
    ).paint(canvas, size);
    const SceneTexturePainter().paint(canvas, size);

    final samples = _stageRig.sample(time: pos, beat: beat);
    final catBacklights = danceMemberBacklights(samples);

    CharacterPainter(
      scene: _cast.lead,
      partnerScene: _cast.left,
      ensembleScenes: [_cast.left, _cast.right],
      ensembleExpressions: [
        danceSingExpression(
          _stepper.leadMouth,
          Expression.neutral,
          _stepper.leadShape,
        ),
        danceSingExpression(
          _stepper.bgMouth,
          Expression.content,
          _stepper.bgShape,
        ),
        danceSingExpression(
          _stepper.bgMouth,
          Expression.happy,
          _stepper.bgShape,
        ),
      ],
      ensembleClips: stage.ensemble,
      synchronousEnsemble: stage.synchronous,
      singingHeadMotion: true,
      walkingPair: true,
      clip: stage.lead,
      timeSeconds: stage.seconds,
      cameraOverride: _stepper.shot,
      onDancerAnchors: (anchors) => _dancerAnchors = anchors,
      scale: danceCastScale(size.height),
      memberBacklights: catBacklights,
      bodyGrade: kDanceBodyGrade,
      heroStaging: true,
      renderer: _renderer,
    ).paint(canvas, size);

    if (captions && perf.words.isNotEmpty) _paintCaption(canvas, pos);
  }

  void _paintBackdropLayers(
    Canvas canvas,
    List<BackdropLayer> layers,
    double pos,
    double beat,
  ) {
    final ctx = BackdropContext(
      size: size,
      timeSeconds: pos,
      palette: kBlueHourPalette,
      beatPulse: beat,
      skyProgram: skyProgram,
      oceanProgram: oceanProgram,
      cityLightsProgram: cityLightsProgram,
      images: images,
    );
    for (final layer in layers) {
      layer.paint(canvas, ctx);
    }
  }

  void _paintHaze(Canvas canvas) {
    // Same waterline haze the live DanceStageView paints as a DecoratedBox.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(size.width / 2, 0),
          Offset(size.width / 2, size.height),
          kDanceHazeGradient.colors,
          kDanceHazeGradient.stops,
        ),
    );
  }

  void _paintCaption(Canvas canvas, double pos) {
    final i = _captionWordIndex(pos);
    if (i == null) return;
    final words = perf.words;
    final from = math.max(0, i - 3);
    final to = math.min(words.length, i + 4);
    final painter = TextPainter(
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
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 96);
    final left = (size.width - painter.width) / 2;
    const top = 20.0;
    final bg = RRect.fromRectAndRadius(
      Rect.fromLTWH(left - 16, top, painter.width + 32, painter.height + 16),
      const Radius.circular(10),
    );
    canvas.drawRRect(
      bg,
      Paint()..color = Colors.black.withValues(alpha: 0.45),
    );
    painter.paint(canvas, Offset(left, top + 8));
  }

  int? _captionWordIndex(double pos) {
    final words = perf.words;
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
}

Future<Map<String, ui.Image>> _loadImages(List<String> assets) async {
  final images = <String, ui.Image>{};
  for (final asset in assets.toSet()) {
    images[asset] = await _loadUiImage(asset);
  }
  return images;
}

Future<ui.Image> _loadUiImage(String asset) async {
  final data = await rootBundle.load(asset);
  final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}
