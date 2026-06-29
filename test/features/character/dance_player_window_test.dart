import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/character/model/beat_map.dart';
import 'package:path/path.dart' as p;

import 'dance_frame_composer.dart';

/// Visual debug harness: render the dancing-cats player at an exact audio
/// position — and a window of frames around it — through the REAL production
/// paint path ([DanceFrameComposer]), so a reported misalignment at "player
/// position X" can be inspected frame by frame.
///
/// Because the composer derives its content from the same `DancePerformance` the
/// live app builds, and this harness **prerolls** the stateful camera up to the
/// window, the frames match what the running player shows at those positions.
///
/// Usage (skipped unless `DANCE_POS` is set):
/// ```sh
/// DANCE_POS=73.4 fvm flutter test test/features/character/dance_player_window_test.dart
/// # tune the window:
/// DANCE_POS=73.4 DANCE_WINDOW=12 DANCE_FPS=60 DANCE_WINDOW_OUT=build/dance_window \
///   fvm flutter test test/features/character/dance_player_window_test.dart
/// ```
/// Output: numbered full-res PNGs `frame_NN.png` plus a labelled contact sheet
/// `window.png` in `DANCE_WINDOW_OUT` (default `build/dance_window`). Each frame
/// is annotated with its audio position, the warped clip-seconds the rig samples,
/// the active move, the fractional beat index and the beat pulse.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final env = Platform.environment;
  final posEnv = env['DANCE_POS'];

  test(
    'renders a labelled frame window around DANCE_POS',
    () async {
      // Load a real font so the per-frame labels render as readable glyphs
      // (the test engine otherwise paints text as boxes).
      await (FontLoader('Inter')..addFont(
            rootBundle.load(
              'assets/fonts/Inter/Inter-VariableFont_opsz,wght.ttf',
            ),
          ))
          .load();

      final config = _WindowConfig.fromEnv(env);
      final mapFile = File(config.beatMapPath);
      if (!mapFile.existsSync()) {
        throw StateError('beat map not found: ${config.beatMapPath}');
      }
      final json =
          jsonDecode(await mapFile.readAsString()) as Map<String, Object?>;
      final beatMap = BeatMap.fromJson(json);
      final audio = json['audio'] as Map<String, Object?>?;
      final duration =
          (audio?['duration_sec'] as num?)?.toDouble() ??
          beatMap.beatTimesSec.last;

      final composer = await DanceFrameComposer.load(
        json: json,
        beatMap: beatMap,
        trackDurationSec: duration,
        wordsPath: config.wordsPath,
        cuesPath: config.cuesPath,
        size: config.size,
        captions: false,
      );

      final dt = 1.0 / config.fps;
      final half = config.window ~/ 2;
      final firstPos = config.pos - half * dt;
      // Preroll: settle the stateful camera/mouths from a lead-in up to the
      // first frame, stepping at the true frame cadence so the framing matches
      // the live app (which has been integrating since playback started).
      var prerollStart = firstPos - config.prerollSeconds;
      if (prerollStart < 0) prerollStart = 0;
      for (var t = prerollStart; t < firstPos; t += dt) {
        composer.advance(t, dt);
      }

      final outDir = Directory(config.outDir);
      if (outDir.existsSync()) outDir.deleteSync(recursive: true);
      outDir.createSync(recursive: true);

      final frames = <_WindowFrame>[];
      try {
        for (var k = 0; k < config.window; k++) {
          final pos = firstPos + k * dt;
          final image = await composer.renderImage(pos, dt);
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          File(
            p.join(config.outDir, 'frame_${k.toString().padLeft(2, '0')}.png'),
          ).writeAsBytesSync(png!.buffer.asUint8List());

          final stage = composer.perf.stageAt(pos);
          frames.add(
            _WindowFrame(
              index: k,
              pos: pos,
              image: image,
              clip: stage.lead.name,
              clipSeconds: stage.seconds,
              beatIndex: composer.perf.map.beatAt(pos),
              beatPulse: composer.perf.beatPulse(pos),
              isCenter: k == half,
            ),
          );
        }

        final sheet = await _composeContactSheet(frames, config);
        final sheetPng = await sheet.toByteData(
          format: ui.ImageByteFormat.png,
        );
        sheet.dispose();
        File(
          p.join(config.outDir, 'window.png'),
        ).writeAsBytesSync(sheetPng!.buffer.asUint8List());
      } finally {
        for (final f in frames) {
          f.image.dispose();
        }
        composer.dispose();
      }

      // ignore: avoid_print
      print(
        'Wrote ${config.window} frames + window.png around '
        '${config.pos.toStringAsFixed(3)}s to ${config.outDir}',
      );
      expect(frames.length, config.window);
    },
    skip: posEnv == null || posEnv.isEmpty
        ? 'Set DANCE_POS=<seconds> to render a debug window'
        : false,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

/// Tiles the window frames into a labelled grid (center frame outlined), each
/// cell carrying its position / clip-seconds / move / beat readout.
Future<ui.Image> _composeContactSheet(
  List<_WindowFrame> frames,
  _WindowConfig config,
) async {
  const cols = 4;
  const thumbW = 360.0;
  final thumbH = thumbW * config.size.height / config.size.width;
  const labelH = 64.0;
  const pad = 10.0;
  const cellW = thumbW + pad;
  final cellH = thumbH + labelH + pad;
  final rows = (frames.length / cols).ceil();
  final sheetW = (cols * cellW + pad).round();
  final sheetH = (rows * cellH + pad).round();

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)
    ..drawRect(
      Rect.fromLTWH(0, 0, sheetW.toDouble(), sheetH.toDouble()),
      Paint()..color = const Color(0xFF15171C),
    );

  final imgPaint = Paint()..filterQuality = FilterQuality.medium;
  for (final f in frames) {
    final col = f.index % cols;
    final row = f.index ~/ cols;
    final x = pad + col * cellW;
    final y = pad + row * cellH;
    final dst = Rect.fromLTWH(x, y, thumbW, thumbH);
    canvas
      ..drawImageRect(
        f.image,
        Rect.fromLTWH(
          0,
          0,
          f.image.width.toDouble(),
          f.image.height.toDouble(),
        ),
        dst,
        imgPaint,
      )
      // Outline the center frame (the reported position) in amber; others grey.
      ..drawRect(
        dst.inflate(1.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = f.isCenter ? 3 : 1
          ..color = f.isCenter
              ? const Color(0xFFFFC24B)
              : const Color(0xFF3A3F4A),
      );

    TextPainter(
        text: TextSpan(
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            height: 1.25,
          ),
          children: [
            TextSpan(
              text:
                  '#${f.index}  t=${f.pos.toStringAsFixed(3)}s'
                  '${f.isCenter ? '  ◀ X' : ''}\n',
              style: TextStyle(
                color: f.isCenter
                    ? const Color(0xFFFFC24B)
                    : const Color(0xFFE6E8EC),
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(
              text:
                  'move=${f.clip}   clipSec=${f.clipSeconds.toStringAsFixed(3)}\n'
                  'beat=${f.beatIndex.toStringAsFixed(2)}   '
                  'pulse=${f.beatPulse.toStringAsFixed(2)}',
              style: const TextStyle(color: Color(0xFFAEB4BF)),
            ),
          ],
        ),
        textDirection: TextDirection.ltr,
      )
      ..layout(maxWidth: thumbW - 6)
      ..paint(canvas, Offset(x + 3, y + thumbH + 4));
  }

  final picture = recorder.endRecording();
  final image = await picture.toImage(sheetW, sheetH);
  picture.dispose();
  return image;
}

/// One rendered frame of the window plus its derivation readout.
class _WindowFrame {
  _WindowFrame({
    required this.index,
    required this.pos,
    required this.image,
    required this.clip,
    required this.clipSeconds,
    required this.beatIndex,
    required this.beatPulse,
    required this.isCenter,
  });

  final int index;
  final double pos;
  final ui.Image image;
  final String clip;
  final double clipSeconds;
  final double beatIndex;
  final double beatPulse;
  final bool isCenter;
}

/// Env-driven configuration for the window render.
class _WindowConfig {
  _WindowConfig({
    required this.pos,
    required this.window,
    required this.fps,
    required this.prerollSeconds,
    required this.size,
    required this.outDir,
    required this.beatMapPath,
    required this.wordsPath,
    required this.cuesPath,
  });

  factory _WindowConfig.fromEnv(Map<String, String> env) {
    double d(String name, double fallback) =>
        double.tryParse(env[name] ?? '') ?? fallback;
    int i(String name, int fallback) =>
        int.tryParse(env[name] ?? '') ?? fallback;
    final width = i('DANCE_WINDOW_W', 1280);
    final height = i('DANCE_WINDOW_H', 720);
    return _WindowConfig(
      pos: d('DANCE_POS', 0),
      window: math.max(1, i('DANCE_WINDOW', 12)),
      fps: math.max(1, i('DANCE_FPS', 60)),
      prerollSeconds: d('DANCE_PREROLL', 2),
      size: Size(width.toDouble(), height.toDouble()),
      outDir: env['DANCE_WINDOW_OUT'] ?? 'build/dance_window',
      beatMapPath:
          env['DANCE_BEATMAP'] ??
          '/home/parallels/github/lotti/tools/dance_audio/out/moving.json',
      wordsPath:
          env['DANCE_WORDS'] ??
          '/home/parallels/github/lotti/tools/dance_audio/out/moving.words.json',
      cuesPath:
          env['DANCE_CUES'] ??
          '/home/parallels/github/lotti/tools/dance_audio/out/moving.cues.json',
    );
  }

  final double pos;
  final int window;
  final int fps;
  final double prerollSeconds;
  final Size size;
  final String outDir;
  final String beatMapPath;
  final String wordsPath;
  final String cuesPath;
}
