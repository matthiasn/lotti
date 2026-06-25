import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/character/engine/autonomic.dart';
import 'package:lotti/features/character/model/affine2d.dart';
import 'package:lotti/features/character/model/clip.dart';
import 'package:lotti/features/character/model/face.dart';
import 'package:lotti/features/character/runtime/character_painter.dart';
import 'package:lotti/features/character/runtime/character_renderer.dart';
import 'package:lotti/features/character/runtime/character_scene.dart';
import 'package:lotti/features/character/samples/cat_in_suit.dart';

/// Controllable per-frame **contact-sheet** capture for motion review.
///
/// Where `film_strip_test.dart` lays one cycle in a single wide row, this tool
/// renders *every* sampled frame of a motion into a labelled grid (so timing,
/// spacing and pose-to-pose readability can be eyeballed at detail), plus an
/// **onion-skin** overlay per clip (all frames superimposed) that reveals the
/// arcs of the hands / feet / tail — the single most useful motion-debug view.
///
/// Everything is env-controllable so a reviewer can zoom into one motion:
///
/// | Env var              | Meaning                                  | Default |
/// | -------------------- | ---------------------------------------- | ------- |
/// | `CHARACTER_STRIP_DIR`| output directory                         | `build/character_film_strips` |
/// | `GRID_CLIPS`         | comma list: walk,run,sit,jump,idle       | all     |
/// | `GRID_FRAMES`        | frames per clip (override)               | 24 loop / 32 one-shot |
/// | `GRID_COLS`          | columns in the contact sheet             | 6       |
/// | `GRID_SCALE`         | character scale                          | 0.62    |
/// | `GRID_EXPRESSION`    | neutral/content/happy/surprised/sad/angry| content |
/// | `GRID_ONION`         | also write `<clip>_onion.png` (1/0)      | 1       |
///
/// Run a single motion densely, for example:
/// ```sh
/// GRID_CLIPS=walk GRID_FRAMES=36 GRID_COLS=6 \
///   fvm flutter test test/features/character/frame_grid_test.dart
/// ```
void main() {
  // Cell geometry. Large enough to read a single pose; the body is ~310 units
  // tall at scale 1, so scale 0.62 → ~190px and fits with headroom + ground.
  const cellW = 240.0;
  const cellH = 320.0;
  const bg = Color(0xFFF4F1EA);
  const ground = Color(0xFFD9D2C4);
  const cellLine = Color(0x14000000);
  const labelColor = Color(0xFF555049);

  // Character placement within a cell. Hips sit high enough that the feet land
  // near the ground line; centred slightly left so the tail has room at right.
  const hipsY = cellH * 0.66;
  const groundY = cellH * 0.9;
  const centreX = cellW * 0.46;

  final env = Platform.environment;
  final outputDir = Directory(
    env['CHARACTER_STRIP_DIR'] ?? 'build/character_film_strips',
  );
  final cols = int.tryParse(env['GRID_COLS'] ?? '') ?? 6;
  final scale = double.tryParse(env['GRID_SCALE'] ?? '') ?? 0.62;
  final onion = (env['GRID_ONION'] ?? '1') != '0';
  // When set, also write a numbered full-frame PNG sequence per clip into
  // `seq_<clip>/` so ffmpeg can stitch a watchable GIF/APNG of the motion.
  final frameSeq = (env['GRID_FRAMESEQ'] ?? '0') == '1';
  // Also write `<clip>_live.png`: a representative frame through the real
  // CharacterPainter (floor band + contact shadow + grounded framing) so the
  // offline review matches the live demo exactly.
  final live = (env['GRID_LIVE'] ?? '1') == '1';
  final expression = _expressionByName(env['GRID_EXPRESSION'] ?? 'content');

  final clipsByName = <String, Clip>{
    for (final c in CatClips.all) c.name: c,
  };
  final selected = (env['GRID_CLIPS'] ?? clipsByName.keys.join(','))
      .split(',')
      .map((s) => s.trim())
      .where(clipsByName.containsKey)
      .toList();

  setUpAll(() => outputDir.createSync(recursive: true));

  // The phase-sample time for frame [i] of [n], matching the film-strip
  // convention: loops sample [0, span) (the wrap frame == frame 0, omitted),
  // one-shots sample [0, span] inclusive so the terminal pose is shown.
  double sampleTime(Clip clip, int i, int n, double span) {
    if (n <= 1) return 0;
    return clip.loop ? span * i / n : span * i / (n - 1);
  }

  // Places frame [i]'s character at the centre of its grid cell.
  Affine2D cellBase(int i) {
    final col = i % cols;
    final row = i ~/ cols;
    return Affine2D.translation(
      col * cellW + centreX,
      row * cellH + hipsY,
    ).multiply(Affine2D.scale(scale, scale));
  }

  void drawLabel(Canvas canvas, String text, double x, double y) {
    TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(
            color: labelColor,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )
      ..layout()
      ..paint(canvas, Offset(x, y));
  }

  // Renders the full contact sheet for [clip]: one labelled cell per frame.
  Future<Uint8List> renderGrid(
    CharacterScene scene,
    Clip clip,
    int frames,
  ) async {
    final rows = (frames / cols).ceil();
    final width = cellW * cols;
    final height = cellH * rows;
    final span = clip.duration;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final renderer = CharacterRenderer();

    canvas.drawRect(
      Rect.fromLTWH(0, 0, width, height),
      Paint()..color = bg,
    );

    for (var i = 0; i < frames; i++) {
      final col = i % cols;
      final row = i ~/ cols;
      final cx = col * cellW;
      final cy = row * cellH;
      // Per-cell ground strip + separators so each pose reads on its own.
      canvas
        ..drawRect(
          Rect.fromLTWH(cx, cy + groundY, cellW, cellH - groundY),
          Paint()..color = ground,
        )
        ..drawRect(
          Rect.fromLTWH(cx, cy, cellW, 1),
          Paint()..color = cellLine,
        )
        ..drawRect(
          Rect.fromLTWH(cx, cy, 1, cellH),
          Paint()..color = cellLine,
        );

      final t = sampleTime(clip, i, frames, span);
      final p = clip.duration <= 0 ? 0.0 : (t / clip.duration);
      final frame = scene.frameAt(
        clip: clip,
        timeSeconds: t,
        expression: expression,
        base: cellBase(i),
      );
      renderer.paint(canvas, scene.rig, frame.world, frame.face);

      drawLabel(
        canvas,
        '#$i  p=${p.toStringAsFixed(2)}',
        cx + 6,
        cy + 5,
      );
    }

    return _pngOf(recorder.endRecording(), width.round(), height.round());
  }

  // Onion-skin overlay: every frame superimposed at low opacity so the motion
  // arcs (hand / foot / tail paths) and any foot-skate are visible at a glance.
  // Frames fade from old (faint) to current (stronger); the final pose is solid.
  Future<Uint8List> renderOnion(
    CharacterScene scene,
    Clip clip,
    int frames,
  ) async {
    final span = clip.duration;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final renderer = CharacterRenderer();

    canvas
      ..drawRect(
        const Rect.fromLTWH(0, 0, cellW, cellH),
        Paint()..color = bg,
      )
      ..drawRect(
        const Rect.fromLTWH(0, groundY, cellW, cellH - groundY),
        Paint()..color = ground,
      );

    final base = Affine2D.translation(
      centreX,
      hipsY,
    ).multiply(Affine2D.scale(scale, scale));

    for (var i = 0; i < frames; i++) {
      final t = sampleTime(clip, i, frames, span);
      final frame = scene.frameAt(
        clip: clip,
        timeSeconds: t,
        expression: expression,
        base: base,
      );
      final last = i == frames - 1;
      // Fade ramp: oldest ~10%, newest ~45%, final pose fully solid.
      final alpha = last ? 1.0 : 0.10 + 0.35 * (i / (frames - 1));
      canvas.saveLayer(
        const Rect.fromLTWH(0, 0, cellW, cellH),
        Paint()..color = Color.fromRGBO(0, 0, 0, alpha),
      );
      renderer.paint(canvas, scene.rig, frame.world, frame.face);
      canvas.restore();
    }

    drawLabel(canvas, 'onion: ${clip.name} ($frames)', 6, 5);
    return _pngOf(recorder.endRecording(), cellW.round(), cellH.round());
  }

  // A single full-cell frame (no labels/separators) for assembling a GIF/APNG.
  Future<Uint8List> renderFrame(
    CharacterScene scene,
    Clip clip,
    int i,
    int frames,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final renderer = CharacterRenderer();
    canvas
      ..drawRect(const Rect.fromLTWH(0, 0, cellW, cellH), Paint()..color = bg)
      ..drawRect(
        const Rect.fromLTWH(0, groundY, cellW, cellH - groundY),
        Paint()..color = ground,
      );
    final base = Affine2D.translation(
      centreX,
      hipsY,
    ).multiply(Affine2D.scale(scale, scale));
    final frame = scene.frameAt(
      clip: clip,
      timeSeconds: sampleTime(clip, i, frames, clip.duration),
      expression: expression,
      base: base,
    );
    renderer.paint(canvas, scene.rig, frame.world, frame.face);
    return _pngOf(recorder.endRecording(), cellW.round(), cellH.round());
  }

  // Renders one frame through the real CharacterPainter at a demo-like stage
  // size, so the floor + contact shadow + auto-fit framing match the live view.
  Future<Uint8List> renderLive(CharacterScene scene, Clip clip) async {
    const w = 360.0;
    const h = 520.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..drawRect(
        const Rect.fromLTWH(0, 0, w, h),
        Paint()..color = const Color(0xFF26303A),
      );
    CharacterPainter(
      scene: scene,
      clip: clip,
      timeSeconds: clip.duration * 0.5,
      expression: expression,
      scale: h * 0.78 / 300.0,
      groundColor: const Color(0xFF374551),
    ).paint(canvas, const Size(w, h));
    return _pngOf(recorder.endRecording(), w.round(), h.round());
  }

  // Travel onion: overlays the cat at successive times with locomotion ON, so a
  // PLANTED foot appears as a crisp footprint (it holds world-x through stance)
  // while the body blurs forward. A smeared foot band = residual foot-skate.
  Future<Uint8List> renderTravel(CharacterScene scene, Clip clip) async {
    const w = 360.0;
    const h = 240.0;
    const margin = 64.0;
    const sc = h * 0.62 / 300.0;
    const floorY = h * 0.9;
    const band = w - 2 * margin;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..drawRect(const Rect.fromLTWH(0, 0, w, h), Paint()..color = bg)
      ..drawRect(
        const Rect.fromLTWH(0, floorY, w, h - floorY),
        Paint()..color = ground,
      );
    final renderer = CharacterRenderer();
    const frames = 36;
    final total = clip.duration * 2.4; // a couple of strides
    for (var i = 0; i < frames; i++) {
      final t = total * i / frames;
      final travelPx = scene.locomotionOffset(clip, t).abs() * sc;
      final cyc = travelPx % (2 * band);
      final movingRight = cyc <= band;
      final pos = movingRight ? cyc : 2 * band - cyc;
      // Mirror while moving +x, mirroring the painter's facing so the onion
      // reflects the real runtime (foot should hold still).
      final base = Affine2D.translation(
        margin + pos,
        floorY - scene.restFeetOffset * sc,
      ).multiply(Affine2D.scale(movingRight ? -sc : sc, sc));
      final frame = scene.frameAt(
        clip: clip,
        timeSeconds: t,
        expression: expression,
        base: base,
      );
      final alpha = 0.1 + 0.5 * (i / (frames - 1));
      canvas.saveLayer(
        const Rect.fromLTWH(0, 0, w, h),
        Paint()..color = Color.fromRGBO(0, 0, 0, alpha),
      );
      renderer.paint(canvas, scene.rig, frame.world, frame.face);
      canvas.restore();
    }
    drawLabel(canvas, 'travel: ${clip.name}', 6, 5);
    return _pngOf(recorder.endRecording(), w.round(), h.round());
  }

  testWidgets('renders per-frame contact-sheet grids', (tester) async {
    await tester.runAsync(() async {
      for (final name in selected) {
        final clip = clipsByName[name]!;
        final scene = CharacterScene(
          buildCatInSuitRig(),
          autonomic: AutonomicLayer(),
        );
        final frames =
            int.tryParse(env['GRID_FRAMES'] ?? '') ?? (clip.loop ? 24 : 32);

        final grid = await renderGrid(scene, clip, frames);
        File('${outputDir.path}/${name}_grid.png').writeAsBytesSync(grid);
        expect(
          await _nonBlankPixels(grid),
          greaterThan(2000),
          reason: '$name grid should paint the character',
        );
        // ignore: avoid_print
        print('wrote ${outputDir.path}/${name}_grid.png ($frames frames)');

        if (onion) {
          final onionPng = await renderOnion(scene, clip, frames);
          File(
            '${outputDir.path}/${name}_onion.png',
          ).writeAsBytesSync(onionPng);
          // ignore: avoid_print
          print('wrote ${outputDir.path}/${name}_onion.png');
        }

        if (frameSeq) {
          final seqDir = Directory('${outputDir.path}/seq_$name')
            ..createSync(recursive: true);
          for (var i = 0; i < frames; i++) {
            final png = await renderFrame(scene, clip, i, frames);
            File(
              '${seqDir.path}/f${i.toString().padLeft(3, '0')}.png',
            ).writeAsBytesSync(png);
          }
          // ignore: avoid_print
          print('wrote ${seqDir.path}/ ($frames frames)');
        }

        if (live) {
          final livePng = await renderLive(scene, clip);
          File('${outputDir.path}/${name}_live.png').writeAsBytesSync(livePng);
          // ignore: avoid_print
          print('wrote ${outputDir.path}/${name}_live.png');
        }

        if (live && clip.locomotionSpeed != 0) {
          final travelPng = await renderTravel(scene, clip);
          File(
            '${outputDir.path}/${name}_travel.png',
          ).writeAsBytesSync(travelPng);
          // ignore: avoid_print
          print('wrote ${outputDir.path}/${name}_travel.png');
        }
      }
    });
  });
}

Expression _expressionByName(String name) => Expression.presets.firstWhere(
  (e) => e.name == name,
  orElse: () => Expression.content,
);

Future<Uint8List> _pngOf(ui.Picture picture, int w, int h) async {
  try {
    final image = await picture.toImage(w, h);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return bytes!.buffer.asUint8List();
  } finally {
    picture.dispose();
  }
}

// Counts pixels that are neither background nor ground (within tolerance) —
// i.e. pixels the character actually painted. Mirrors the film-strip check.
Future<int> _nonBlankPixels(Uint8List png) async {
  const tol = 24;
  const bgRgb = [0xF4, 0xF1, 0xEA];
  const groundRgb = [0xD9, 0xD2, 0xC4];
  bool near(int r, int g, int b, List<int> c) =>
      (r - c[0]).abs() <= tol &&
      (g - c[1]).abs() <= tol &&
      (b - c[2]).abs() <= tol;

  final codec = await ui.instantiateImageCodec(png);
  final frame = await codec.getNextFrame();
  final data = await frame.image.toByteData();
  frame.image.dispose();
  codec.dispose();
  final bytes = data!.buffer.asUint8List();

  var count = 0;
  for (var i = 0; i + 3 < bytes.length; i += 4) {
    if (near(bytes[i], bytes[i + 1], bytes[i + 2], bgRgb) ||
        near(bytes[i], bytes[i + 1], bytes[i + 2], groundRgb)) {
      continue;
    }
    count++;
  }
  return count;
}
