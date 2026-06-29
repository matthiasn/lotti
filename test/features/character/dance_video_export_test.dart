import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/character/model/beat_map.dart';
import 'package:path/path.dart' as p;

import 'dance_frame_composer.dart';

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

    final composer = await DanceFrameComposer.load(
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
