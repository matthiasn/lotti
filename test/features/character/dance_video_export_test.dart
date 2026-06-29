import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/character/demo/dance_camera_director.dart';
import 'package:lotti/features/character/demo/dance_camera_rig.dart';
import 'package:lotti/features/character/demo/dance_lip_sync.dart';
import 'package:lotti/features/character/engine/autonomic.dart';
import 'package:lotti/features/character/model/beat_map.dart';
import 'package:lotti/features/character/model/clip.dart';
import 'package:lotti/features/character/model/face.dart';
import 'package:lotti/features/character/runtime/character_painter.dart';
import 'package:lotti/features/character/runtime/character_renderer.dart';
import 'package:lotti/features/character/runtime/character_scene.dart';
import 'package:lotti/features/character/samples/cat_in_suit.dart';
import 'package:lotti/features/scenery/layers/backdrop_layer.dart';
import 'package:lotti/features/scenery/model/backdrop_palette.dart';
import 'package:lotti/features/scenery/model/backdrop_scene.dart';
import 'package:lotti/features/scenery/runtime/scenery_shaders.dart';
import 'package:lotti/features/scenery/runtime/stage_lights.dart';
import 'package:lotti/features/scenery/scene_texture_overlay.dart';
import 'package:lotti/features/scenery/stage_lights_overlay.dart';
import 'package:path/path.dart' as p;

/// Dev-only MP4 exporter for the beat-synced character showcase.
///
/// This is intentionally a Flutter test harness rather than app UI: `dart:ui`
/// rendering needs Flutter engine bindings, while the export should stay out of
/// product code for now. Invoke through:
///
/// ```sh
/// tools/character_video_export/export_dance_video.sh --preset 1080p
/// ```
///
/// The wrapper sets `DANCE_EXPORT=1`; without that env flag this test is skipped
/// and has no effect in ordinary targeted/full test runs.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final enabled = Platform.environment['DANCE_EXPORT'] == '1';
  test(
    'exports beat-synced dance video',
    () async {
      final config = _ExportConfig.fromEnv(Platform.environment);
      await _DanceVideoExporter(config).export();
    },
    skip: enabled
        ? false
        : 'Set DANCE_EXPORT=1 or use '
              'tools/character_video_export/export_dance_video.sh',
    timeout: const Timeout(Duration(hours: 12)),
  );
}

const String _defaultAudioPath =
    '/home/parallels/Downloads/Omah_Lay-Moving.mp3';
const String _defaultBeatMapPath =
    '/home/parallels/github/lotti/tools/dance_audio/out/moving.json';
const String _defaultWordsPath =
    '/home/parallels/github/lotti/tools/dance_audio/out/moving.words.json';
const String _defaultCuesPath =
    '/home/parallels/github/lotti/tools/dance_audio/out/moving.cues.json';
const int _phraseBars = 3;
const double _sectionEnergyThreshold = 0.5;
const double _minCalmSeconds = 4;
const double _mouthAttackSeconds = 0.045;
const double _mouthReleaseSeconds = 0.12;
const double _voiceSlack = 0.3;
const Set<String> _groupSections = {'chorus', 'post-chorus', 'outro'};

typedef _Section = ({
  double start,
  double end,
  String label,
  bool energetic,
  double level,
});
typedef _Word = ({
  double start,
  double end,
  String word,
  String voice,
  String section,
});
typedef _SectionSpan = ({double start, double end, String section});
typedef _Stage = ({
  Clip lead,
  List<Clip> ensemble,
  double seconds,
  _Section? section,
  bool energetic,
  bool synchronous,
});

final class _ExportConfig {
  const _ExportConfig({
    required this.audioPath,
    required this.beatMapPath,
    required this.wordsPath,
    required this.cuesPath,
    required this.outputPath,
    required this.width,
    required this.height,
    required this.fps,
    required this.startSec,
    required this.durationSec,
    required this.keepFrames,
    required this.captions,
    required this.crf,
    required this.audioBitrateKbps,
    required this.x264Preset,
  });

  factory _ExportConfig.fromEnv(Map<String, String> env) {
    final width = _intEnv(env, 'DANCE_EXPORT_WIDTH', 1920);
    final height = _intEnv(env, 'DANCE_EXPORT_HEIGHT', 1080);
    if (width.isOdd || height.isOdd) {
      throw StateError('width and height must be even for yuv420p H.264');
    }
    final fps = _intEnv(env, 'DANCE_EXPORT_FPS', 60);
    if (fps <= 0) throw StateError('DANCE_EXPORT_FPS must be positive');
    final outputPath =
        env['DANCE_EXPORT_OUT'] ??
        'build/character_video_exports/dance_${width}x${height}_${fps}fps.mp4';
    return _ExportConfig(
      audioPath: env['DANCE_AUDIO'] ?? _defaultAudioPath,
      beatMapPath: env['DANCE_BEATMAP'] ?? _defaultBeatMapPath,
      wordsPath: env['DANCE_WORDS'] ?? _defaultWordsPath,
      cuesPath: env['DANCE_CUES'] ?? _defaultCuesPath,
      outputPath: outputPath,
      width: width,
      height: height,
      fps: fps,
      startSec: _doubleEnv(env, 'DANCE_EXPORT_START', 0),
      // <= 0 means "to the end of the track".
      durationSec: _doubleEnv(env, 'DANCE_EXPORT_DURATION', 0),
      keepFrames: _boolEnv(env, 'DANCE_EXPORT_KEEP_FRAMES'),
      captions: _boolEnv(env, 'DANCE_EXPORT_CAPTIONS'),
      crf: _intEnv(env, 'DANCE_EXPORT_CRF', 18),
      audioBitrateKbps: _intEnv(env, 'DANCE_EXPORT_AUDIO_KBPS', 320),
      x264Preset: env['DANCE_EXPORT_X264_PRESET'] ?? 'slow',
    );
  }

  final String audioPath;
  final String beatMapPath;
  final String wordsPath;
  final String cuesPath;
  final String outputPath;
  final int width;
  final int height;
  final int fps;
  final double startSec;
  final double durationSec;
  final bool keepFrames;
  final bool captions;
  final int crf;
  final int audioBitrateKbps;
  final String x264Preset;

  Size get size => Size(width.toDouble(), height.toDouble());
}

final class _DanceVideoExporter {
  _DanceVideoExporter(this.config);

  final _ExportConfig config;

  Future<void> export() async {
    final audioFile = File(config.audioPath);
    final mapFile = File(config.beatMapPath);
    if (!audioFile.existsSync()) {
      throw StateError('audio file not found: ${config.audioPath}');
    }
    if (!mapFile.existsSync()) {
      throw StateError('beat map not found: ${config.beatMapPath}');
    }

    final json =
        jsonDecode(await mapFile.readAsString()) as Map<String, Object?>;
    final beatMap = BeatMap.fromJson(json);
    final trackDuration = _trackDuration(json, beatMap);
    final start = config.startSec.clamp(0.0, trackDuration);
    final duration = config.durationSec > 0
        ? math.min(config.durationSec, trackDuration - start)
        : trackDuration - start;
    if (duration <= 0) throw StateError('export duration is empty');

    final outputFile = File(config.outputPath);
    outputFile.parent.createSync(recursive: true);
    Directory? framesDir;
    if (config.keepFrames) {
      framesDir = Directory(
        p.join(
          outputFile.parent.path,
          '${p.basenameWithoutExtension(outputFile.path)}_frames',
        ),
      );
      if (framesDir.existsSync()) framesDir.deleteSync(recursive: true);
      framesDir.createSync(recursive: true);
    }

    final composer = await _DanceFrameComposer.load(
      json: json,
      beatMap: beatMap,
      trackDurationSec: trackDuration,
      wordsPath: config.wordsPath,
      cuesPath: config.cuesPath,
      size: config.size,
      captions: config.captions,
    );

    final frameCount = math.max(1, (duration * config.fps).ceil());
    final dt = 1 / config.fps;
    final progressEvery = math.max(1, config.fps);
    final prerollStart = start <= 2 ? 0.0 : start - 2.0;
    for (var t = prerollStart; t < start; t += dt) {
      composer.advance(t, dt);
    }

    final encoder = await _RawVideoEncoder.start(
      config: config,
      outputFile: outputFile,
      startSec: start,
      durationSec: duration,
    );
    var encoderFinished = false;
    try {
      for (var frame = 0; frame < frameCount; frame++) {
        final t = start + frame * dt;
        final rendered = await composer.renderFrame(
          t,
          dt,
          includePng: config.keepFrames,
        );
        await encoder.writeFrame(rendered.rgba);
        final png = rendered.png;
        if (framesDir != null && png != null) {
          final file = File(p.join(framesDir.path, _frameName(frame)));
          await file.writeAsBytes(png);
        }
        if (frame % progressEvery == 0 || frame == frameCount - 1) {
          // ignore: avoid_print
          print('rendered ${frame + 1}/$frameCount frames');
        }
      }
      await encoder.finish();
      encoderFinished = true;
    } finally {
      if (!encoderFinished) encoder.kill();
      composer.dispose();
      if (!config.keepFrames && framesDir != null && framesDir.existsSync()) {
        framesDir.deleteSync(recursive: true);
      }
    }

    // ignore: avoid_print
    print('wrote ${outputFile.path}');
  }
}

final class _RawVideoEncoder {
  _RawVideoEncoder._(
    this._process,
    this._stdoutDone,
    this._stderrDone,
    this._stderrBuffer,
  );

  static Future<_RawVideoEncoder> start({
    required _ExportConfig config,
    required File outputFile,
    required double startSec,
    required double durationSec,
  }) async {
    final args = [
      '-y',
      '-f',
      'rawvideo',
      '-pix_fmt',
      'rgba',
      '-s:v',
      '${config.width}x${config.height}',
      '-framerate',
      '${config.fps}',
      '-i',
      'pipe:0',
      '-ss',
      startSec.toStringAsFixed(6),
      '-t',
      durationSec.toStringAsFixed(6),
      '-i',
      config.audioPath,
      '-map',
      '0:v:0',
      '-map',
      '1:a:0',
      '-c:v',
      'libx264',
      '-preset',
      config.x264Preset,
      '-crf',
      '${config.crf}',
      '-pix_fmt',
      'yuv420p',
      '-profile:v',
      'high',
      '-level',
      '4.2',
      '-r',
      '${config.fps}',
      '-g',
      '${math.max(1, (config.fps / 2).round())}',
      '-bf',
      '2',
      '-colorspace',
      'bt709',
      '-color_primaries',
      'bt709',
      '-color_trc',
      'bt709',
      '-c:a',
      'aac',
      '-b:a',
      '${config.audioBitrateKbps}k',
      '-ar',
      '48000',
      '-movflags',
      '+faststart',
      '-shortest',
      outputFile.path,
    ];
    final process = await Process.start('ffmpeg', args);
    final stderrBuffer = StringBuffer();
    final stdoutDone = process.stdout.drain<void>();
    final stderrDone = process.stderr
        .transform(utf8.decoder)
        .forEach(stderrBuffer.write);
    return _RawVideoEncoder._(
      process,
      stdoutDone,
      stderrDone,
      stderrBuffer,
    );
  }

  final Process _process;
  final Future<void> _stdoutDone;
  final Future<void> _stderrDone;
  final StringBuffer _stderrBuffer;
  bool _killed = false;

  Future<void> writeFrame(Uint8List rgba) async {
    _process.stdin.add(rgba);
    await _process.stdin.flush();
  }

  Future<void> finish() async {
    await _process.stdin.close();
    final exitCode = await _process.exitCode;
    await _stdoutDone;
    await _stderrDone;
    if (exitCode != 0) {
      throw StateError(
        'ffmpeg failed with exit $exitCode\n'
        '$_stderrBuffer',
      );
    }
  }

  void kill() {
    if (_killed) return;
    _killed = true;
    _process.kill();
  }
}

final class _DanceFrameComposer {
  _DanceFrameComposer._({
    required this.beatMap,
    required this.binding,
    required this.trackDurationSec,
    required this.sections,
    required this.words,
    required this.sectionSpans,
    required this.cues,
    required this.images,
    required this.skyProgram,
    required this.oceanProgram,
    required this.cityLightsProgram,
    required this.size,
    required this.captions,
  });

  static Future<_DanceFrameComposer> load({
    required Map<String, Object?> json,
    required BeatMap beatMap,
    required double trackDurationSec,
    required String wordsPath,
    required String cuesPath,
    required Size size,
    required bool captions,
  }) async {
    final amplitudes =
        (json['waveform'] as List?)
            ?.map((e) => (e as num).toDouble())
            .toList() ??
        const <double>[];
    final rawSections = ((json['sections'] as List?) ?? const [])
        .cast<Map<String, Object?>>()
        .map(
          (s) => (
            start: (s['start_sec']! as num).toDouble(),
            end: (s['end_sec']! as num).toDouble(),
            label: (s['label'] as String?) ?? '',
          ),
        )
        .toList();
    final words = await _loadWords(wordsPath);
    final cues = await _loadCues(cuesPath);
    final scene = BackdropScene.blueHourWaterfront();
    return _DanceFrameComposer._(
      beatMap: beatMap,
      binding: BeatLoopBinding.barAligned(beatMap, bars: _phraseBars),
      trackDurationSec: trackDurationSec,
      sections: _classifySections(rawSections, amplitudes, trackDurationSec),
      words: words,
      sectionSpans: _buildSectionSpans(words, trackDurationSec),
      cues: cues,
      images: await _loadImages(scene.imageAssets),
      skyProgram: await SceneryShaderProgramCache.loadSky(),
      oceanProgram: await SceneryShaderProgramCache.loadOcean(),
      cityLightsProgram: await SceneryShaderProgramCache.loadCityLights(),
      size: size,
      captions: captions,
    );
  }

  final BeatMap beatMap;
  final BeatLoopBinding binding;
  final double trackDurationSec;
  final List<_Section> sections;
  final List<_Word> words;
  final List<_SectionSpan> sectionSpans;
  final List<DanceCue> cues;
  final Map<String, ui.Image> images;
  final ui.FragmentProgram skyProgram;
  final ui.FragmentProgram oceanProgram;
  final ui.FragmentProgram cityLightsProgram;
  final Size size;
  final bool captions;

  final CharacterScene _lead = CharacterScene(
    buildCatInSuitRig(
      legWidthScale: kDanceLeadLegWidthScale,
      armWidthScale: kDanceLeadArmWidthScale,
    ),
    autonomic: _danceAutonomic(11),
  );
  final CharacterScene _left = CharacterScene(
    buildCatInSuitRig(palette: CatInSuitPalette.silverTabby),
    autonomic: _danceAutonomic(29),
  );
  final CharacterScene _right = CharacterScene(
    buildCatInSuitRig(palette: CatInSuitPalette.darkBrown),
    autonomic: _danceAutonomic(47),
  );
  final CharacterRenderer _renderer = CharacterRenderer();
  final StageLightRig _stageRig = const StageLightRig(leadGoldIndex: 1);
  final DanceCameraRig _cameraRig = DanceCameraRig();

  late final Clip _shaku = CatClips.shaku;
  late final Clip _zanku = CatClips.zanku;
  late final Clip _azonto = CatClips.azonto;
  late final Clip _buga = CatClips.buga;
  late final Clip _pounce = CatClips.pouncingCat;
  late final Clip _sekem = CatClips.sekem;
  late final Clip _idle = CatClips.idle;

  double _leadMouth = 0;
  double _bgMouth = 0;
  MouthShape _leadShape = MouthShape.singAh;
  MouthShape _bgShape = MouthShape.singAh;
  Shot _shot = (zoom: 1, dx: 0, dy: 0);
  List<Offset> _dancerAnchors = const [];
  _Stage? _stage;

  void advance(double pos, double dt) {
    final cue = mouthForCue(cueShapeAt(cues, pos));
    final leadOn = words.isEmpty || _voiceActive(pos, (w) => w.voice == 'lead');
    final bgOn = _voiceActive(
      pos,
      (w) =>
          w.voice == 'background' ||
          (w.voice == 'lead' && _groupSections.contains(w.section)),
    );
    if (leadOn) _leadShape = cue.shape;
    if (bgOn) _bgShape = cue.shape;
    _leadMouth = _easeMouth(_leadMouth, leadOn ? cue.open : 0.0, dt);
    _bgMouth = _easeMouth(_bgMouth, bgOn ? cue.open : 0.0, dt);

    final stage = _stageAt(pos);
    final ctx = _directorContext(pos, energetic: stage.energetic);
    final target = cameraShot(ctx);
    _shot = _cameraRig.update(
      target: target,
      cut: isHardCut(ctx) || isChorusDrop(ctx) || isBridgeCut(ctx),
      dt: dt,
    );
    _stage = stage;
  }

  Future<({Uint8List rgba, Uint8List? png})> renderFrame(
    double pos,
    double dt, {
    required bool includePng,
  }) async {
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
    final stage = _stage ?? _stageAt(pos);
    final beat = _beatPulse(pos);
    final parallax = CharacterPainter.danceParallaxTransformForShot(
      shot: _shot,
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
    const heroWeight = [0.9, 1.1, 0.9];
    final catBacklights = [
      for (final (i, s) in samples.indexed)
        s.color.withValues(
          alpha: (s.intensity * heroWeight[i % heroWeight.length]).clamp(
            0.0,
            1.0,
          ),
        ),
    ];

    CharacterPainter(
      scene: _lead,
      partnerScene: _left,
      ensembleScenes: [_left, _right],
      ensembleExpressions: [
        _singExpression(_leadMouth, Expression.neutral, _leadShape),
        _singExpression(_bgMouth, Expression.content, _bgShape),
        _singExpression(_bgMouth, Expression.happy, _bgShape),
      ],
      ensembleClips: stage.ensemble,
      synchronousEnsemble: stage.synchronous,
      singingHeadMotion: true,
      walkingPair: true,
      clip: stage.lead,
      timeSeconds: stage.seconds,
      cameraOverride: _shot,
      onDancerAnchors: (anchors) => _dancerAnchors = anchors,
      scale: size.height * 0.78 / 300,
      memberBacklights: catBacklights,
      bodyGrade: const (
        skyWrap: Color(0x2E1F3354),
        deckWrap: Color(0x2E3A2616),
      ),
      heroStaging: true,
      renderer: _renderer,
    ).paint(canvas, size);

    if (captions && words.isNotEmpty) _paintCaption(canvas, pos);
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
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(size.width / 2, 0),
          Offset(size.width / 2, size.height),
          const [
            Color(0x005E7088),
            Color(0x005E7088),
            Color(0x2C5E7088),
            Color(0x185E7088),
            Color(0x005E7088),
          ],
          const [0.0, 0.40, 0.52, 0.64, 0.76],
        ),
    );
  }

  void _paintCaption(Canvas canvas, double pos) {
    final i = _captionWordIndex(pos);
    if (i == null) return;
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

  _Stage _stageAt(double pos) {
    final section = _sectionAt(pos);
    final level = section?.level ?? 1.0;
    final resting = section != null && !section.energetic && level < 0.15;
    if (!resting) {
      final lyric = _sectionInfoAt(pos);
      final occurrence = _sectionOccurrenceAt(pos, lyric.section);
      final trio = _choreoTrioForSection(
        lyric.section,
        lyric.phase,
        level,
        occurrence,
      );
      return (
        lead: trio.lead,
        ensemble: trio.ensemble,
        seconds: beatMap.clipSecondsAt(
          pos,
          clipDuration: trio.lead.duration,
          binding: binding,
        ),
        section: section,
        energetic: section?.energetic ?? true,
        synchronous: trio.lead != _pounce,
      );
    }
    return (
      lead: _idle,
      ensemble: [_idle, _idle, _idle],
      seconds: pos,
      section: section,
      energetic: false,
      synchronous: true,
    );
  }

  ({Clip lead, List<Clip> ensemble}) _choreoTrioForSection(
    String section,
    double phase,
    double level,
    int variant,
  ) {
    switch (section) {
      case 'chorus':
      case 'post-chorus':
        if (phase >= 0.55) {
          return (lead: _buga, ensemble: [_buga, _buga, _buga]);
        }
        final fronts = [
          [_zanku, _sekem, _buga],
          [_sekem, _zanku, _buga],
          [_zanku, _buga, _sekem],
        ];
        final front = fronts[variant % fronts.length];
        return (lead: front[0], ensemble: front);
      case 'pre-chorus':
        return (lead: _shaku, ensemble: [_shaku, _zanku, _sekem]);
      case 'verse':
        return variant.isEven
            ? (lead: _azonto, ensemble: [_azonto, _shaku, _zanku])
            : (lead: _shaku, ensemble: [_shaku, _azonto, _zanku]);
      case 'bridge':
        return (lead: _pounce, ensemble: [_pounce, _pounce, _pounce]);
      case 'outro':
        return (lead: _pounce, ensemble: [_pounce, _pounce, _shaku]);
      default:
        return _choreoTrioByLevel(level);
    }
  }

  ({Clip lead, List<Clip> ensemble}) _choreoTrioByLevel(double level) {
    if (level >= 0.90) return (lead: _buga, ensemble: [_buga, _buga, _buga]);
    if (level >= 0.78) {
      return (lead: _zanku, ensemble: [_zanku, _sekem, _buga]);
    }
    if (level >= 0.62) {
      return (lead: _shaku, ensemble: [_shaku, _zanku, _sekem]);
    }
    if (level >= 0.45) {
      return (lead: _shaku, ensemble: [_shaku, _azonto, _zanku]);
    }
    if (level >= 0.28) {
      return (lead: _azonto, ensemble: [_azonto, _shaku, _pounce]);
    }
    return (lead: _pounce, ensemble: [_pounce, _pounce, _pounce]);
  }

  DanceCameraContext _directorContext(double pos, {required bool energetic}) {
    final info = _sectionInfoAt(pos);
    return cameraContext(
      beat: beatMap.beatAt(pos),
      anchorBeat: binding.anchorBeatIndex.toDouble(),
      loopLengthBeats: binding.loopLengthBeats.toDouble(),
      section: info.section,
      energetic: energetic,
      build: trackDurationSec > 0 ? pos / trackDurationSec : 0,
      sectionPhase: info.phase,
    );
  }

  _Section? _sectionAt(double pos) {
    for (final section in sections) {
      if (pos >= section.start && pos < section.end) return section;
    }
    return sections.isEmpty ? null : sections.last;
  }

  ({String section, double phase}) _sectionInfoAt(double pos) {
    for (final span in sectionSpans) {
      if (pos >= span.start && pos < span.end) {
        final length = span.end - span.start <= 0 ? 1.0 : span.end - span.start;
        return (
          section: span.section,
          phase: ((pos - span.start) / length).clamp(0.0, 1.0),
        );
      }
    }
    return (section: '', phase: 0);
  }

  int _sectionOccurrenceAt(double pos, String section) {
    var occurrence = 0;
    for (final span in sectionSpans) {
      if (pos >= span.start && pos < span.end) break;
      if (span.section == section) occurrence++;
    }
    return occurrence;
  }

  bool _voiceActive(double pos, bool Function(_Word w) test) {
    for (final word in words) {
      if (test(word) &&
          windowActiveAt(word.start, word.end, pos, _voiceSlack)) {
        return true;
      }
      if (word.start - _voiceSlack > pos) break;
    }
    return false;
  }

  int? _captionWordIndex(double pos) {
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

  double _beatPulse(double pos) {
    final beats = beatMap.beatTimesSec;
    var lo = 0;
    var hi = beats.length - 1;
    var idx = 0;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (beats[mid] <= pos) {
        idx = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    final since = pos - beats[idx];
    if (since < 0) return 0;
    final value = 1 - since / 0.18;
    return value <= 0 ? 0 : value * value;
  }

  double _easeMouth(double current, double target, double dt) {
    final tc = target > current ? _mouthAttackSeconds : _mouthReleaseSeconds;
    return current + (target - current) * math.min(1.0, dt / tc);
  }

  Expression _singExpression(double mouth, Expression base, MouthShape shape) {
    if (mouth < 0.04) return base;
    final brow = 0.18 + mouth * 0.4;
    final eye = 1 - mouth * 0.18;
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
}

AutonomicLayer _danceAutonomic(int seed) => AutonomicLayer(
  seed: seed,
  blinkIntervalBase: 1.7,
  blinkIntervalJitter: 1.1,
  eyeDartInterval: 1.05,
  eyeDartAmplitude: 0.75,
);

List<_Section> _classifySections(
  List<({double start, double end, String label})> raw,
  List<double> amplitudes,
  double duration,
) {
  if (raw.isEmpty || amplitudes.isEmpty || duration <= 0) {
    return [
      for (final section in raw)
        (
          start: section.start,
          end: section.end,
          label: section.label,
          energetic: true,
          level: 1.0,
        ),
    ];
  }

  final n = amplitudes.length;
  double energyOf(double start, double end) {
    final i0 = (start / duration * n).floor().clamp(0, n - 1);
    var i1 = (end / duration * n).ceil().clamp(0, n);
    if (i1 <= i0) i1 = i0 + 1;
    var sum = 0.0;
    for (var i = i0; i < i1; i++) {
      sum += amplitudes[i];
    }
    return sum / (i1 - i0);
  }

  final energies = [
    for (final section in raw) energyOf(section.start, section.end),
  ];
  final minEnergy = energies.reduce(math.min);
  final maxEnergy = energies.reduce(math.max);
  final threshold =
      minEnergy + _sectionEnergyThreshold * (maxEnergy - minEnergy);
  final range = maxEnergy - minEnergy;
  return [
    for (var i = 0; i < raw.length; i++)
      (
        start: raw[i].start,
        end: raw[i].end,
        label: raw[i].label,
        energetic:
            !(energies[i] < threshold &&
                (raw[i].end - raw[i].start) >= _minCalmSeconds),
        level: range > 0 ? (energies[i] - minEnergy) / range : 1.0,
      ),
  ];
}

List<_SectionSpan> _buildSectionSpans(List<_Word> words, double duration) {
  final spans = <_SectionSpan>[];
  for (final word in words) {
    final section = word.section.toLowerCase();
    if (spans.isEmpty || spans.last.section != section) {
      spans.add((start: word.start, end: duration, section: section));
    }
  }
  for (var i = 0; i < spans.length - 1; i++) {
    spans[i] = (
      start: spans[i].start,
      end: spans[i + 1].start,
      section: spans[i].section,
    );
  }
  return spans;
}

Future<List<_Word>> _loadWords(String path) async {
  final file = File(path);
  if (!file.existsSync()) return const [];
  final json = jsonDecode(await file.readAsString()) as Map<String, Object?>;
  return ((json['words'] as List?) ?? const [])
      .cast<Map<String, Object?>>()
      .where((word) => word['start_sec'] != null && word['end_sec'] != null)
      .map(
        (word) => (
          start: (word['start_sec']! as num).toDouble(),
          end: (word['end_sec']! as num).toDouble(),
          word: (word['word'] as String?) ?? '',
          voice: (word['voice'] as String?) ?? 'lead',
          section: (word['section'] as String?) ?? '',
        ),
      )
      .toList();
}

Future<List<DanceCue>> _loadCues(String path) async {
  final file = File(path);
  if (!file.existsSync()) return const [];
  final json = jsonDecode(await file.readAsString()) as Map<String, Object?>;
  return ((json['cues'] as List?) ?? const [])
      .cast<Map<String, Object?>>()
      .map(
        (cue) => (
          start: (cue['start_sec']! as num).toDouble(),
          end: (cue['end_sec']! as num).toDouble(),
          shape: (cue['shape'] as String?) ?? 'X',
        ),
      )
      .toList();
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

double _trackDuration(Map<String, Object?> json, BeatMap map) {
  final audio = json['audio'] as Map<String, Object?>?;
  return (audio?['duration_sec'] as num?)?.toDouble() ?? map.beatTimesSec.last;
}

String _frameName(int frame) => '${frame.toString().padLeft(6, '0')}.png';

int _intEnv(Map<String, String> env, String name, int fallback) =>
    int.tryParse(env[name] ?? '') ?? fallback;

double _doubleEnv(Map<String, String> env, String name, double fallback) =>
    double.tryParse(env[name] ?? '') ?? fallback;

bool _boolEnv(
  Map<String, String> env,
  String name, {
  bool defaultValue = false,
}) {
  final value = env[name]?.toLowerCase();
  if (value == null || value.isEmpty) return defaultValue;
  return value == '1' || value == 'true' || value == 'yes' || value == 'on';
}
