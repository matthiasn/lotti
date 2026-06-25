import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/character/engine/autonomic.dart';
import 'package:lotti/features/character/model/affine2d.dart';
import 'package:lotti/features/character/model/clip.dart';
import 'package:lotti/features/character/model/face.dart';
import 'package:lotti/features/character/runtime/character_renderer.dart';
import 'package:lotti/features/character/runtime/character_scene.dart';
import 'package:lotti/features/character/samples/cat_in_suit.dart';

/// Renders the Phase-1 film strips: tiled frame sequences of the cat-in-a-suit
/// rig in each motion cycle, plus expression and blink strips. Output PNGs land
/// in `build/character_film_strips/` (override with `CHARACTER_STRIP_DIR`).
///
/// This doubles as a regression test: the same `(clip, time)` must paint
/// identical pixels every run (deterministic engine), and every strip must
/// actually paint the character (non-blank).
void main() {
  const cellW = 200.0;
  const cellH = 280.0;
  const bg = Color(0xFFF4F1EA);
  const ground = Color(0xFFD9D2C4);
  const cellLine = Color(0x11000000);

  final outputDir = Directory(
    Platform.environment['CHARACTER_STRIP_DIR'] ??
        'build/character_film_strips',
  );

  late CharacterScene scene;

  setUp(() {
    scene = CharacterScene(
      buildCatInSuitRig(),
      autonomic: AutonomicLayer(),
    );
  });

  setUpAll(() => outputDir.createSync(recursive: true));

  // Paints one strip of [frames] cells sampling [clip] across [span] seconds.
  Future<Uint8List> renderCycleStrip(
    CharacterScene scene, {
    required Clip clip,
    required int frames,
    required double span,
    Expression expression = Expression.neutral,
    double scale = 0.72,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final renderer = CharacterRenderer();
    final width = cellW * frames;
    // Hips sit at 60% height; with scale 0.72 the ~150-unit legs land the feet
    // near the ground line and the ears stay inside the cell.
    const hipsY = cellH * 0.6;
    const groundY = cellH * 0.95;

    canvas
      ..drawRect(
        Rect.fromLTWH(0, 0, width, cellH),
        Paint()..color = bg,
      )
      ..drawRect(
        Rect.fromLTWH(0, groundY, width, cellH - groundY),
        Paint()..color = ground,
      );

    for (var i = 0; i < frames; i++) {
      final x = i * cellW;
      if (i > 0) {
        canvas.drawRect(
          Rect.fromLTWH(x, 0, 1, cellH),
          Paint()..color = cellLine,
        );
      }
      // Looping clips sample [0, span) so the wrap cell isn't duplicated;
      // one-shots sample [0, span] (divisor frames-1) so the terminal p=1 pose
      // is rendered and end-state regressions are caught.
      final t = frames <= 1
          ? 0.0
          : clip.loop
          ? span * i / frames
          : span * i / (frames - 1);
      final base = Affine2D.translation(
        x + cellW / 2,
        hipsY,
      ).multiply(Affine2D.scale(scale, scale));
      final frame = scene.frameAt(
        clip: clip,
        timeSeconds: t,
        expression: expression,
        base: base,
      );
      renderer.paint(canvas, scene.rig, frame.world, frame.face);
    }

    final picture = recorder.endRecording();
    try {
      final image = await picture.toImage(width.round(), cellH.round());
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return bytes!.buffer.asUint8List();
    } finally {
      picture.dispose();
    }
  }

  // Head-zoomed strip showing each [FaceState] in [faces].
  Future<Uint8List> renderFaceStrip(
    CharacterScene scene, {
    required List<({String label, FaceState face})> faces,
    double scale = 1.9,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final renderer = CharacterRenderer();
    final width = cellW * faces.length;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, width, cellH),
      Paint()..color = bg,
    );

    // A static pose (idle at t=0) with the head framed in the cell.
    for (var i = 0; i < faces.length; i++) {
      final x = i * cellW;
      if (i > 0) {
        canvas.drawRect(
          Rect.fromLTWH(x, 0, 1, cellH),
          Paint()..color = cellLine,
        );
      }
      // Map the head (~local y -120) to the cell centre.
      final base = Affine2D.translation(x + cellW / 2, cellH * 0.52)
          .multiply(Affine2D.scale(scale, scale))
          .multiply(Affine2D.translation(0, 118));
      final frameBase = scene.frameAt(
        clip: CatClips.idle,
        timeSeconds: 0,
        base: base,
      );
      renderer.paint(canvas, scene.rig, frameBase.world, faces[i].face);
    }

    final picture = recorder.endRecording();
    try {
      final image = await picture.toImage(width.round(), cellH.round());
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return bytes!.buffer.asUint8List();
    } finally {
      picture.dispose();
    }
  }

  // Decodes [png] and counts pixels that are neither the background nor the
  // ground bar (within tolerance), i.e. pixels the character actually painted.
  // The faint cell-separator lines composite to within tolerance of the
  // background, so they are not counted — a strip that drew only chrome and no
  // character scores ~0.
  Future<int> characterPixelCount(Uint8List png) async {
    const tol = 24; // per-channel; > the ~16 the separator lines shift bg
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
      final r = bytes[i];
      final g = bytes[i + 1];
      final b = bytes[i + 2];
      if (near(r, g, b, bgRgb) || near(r, g, b, groundRgb)) continue;
      count++;
    }
    return count;
  }

  testWidgets('renders cycle film strips (walk/run/kick/dance/sit/jump)', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final strips = <String, Uint8List>{
        'walk': await renderCycleStrip(
          scene,
          clip: CatClips.walk,
          frames: 14,
          span: CatClips.walk.duration,
        ),
        'run': await renderCycleStrip(
          scene,
          clip: CatClips.run,
          frames: 14,
          span: CatClips.run.duration,
        ),
        'kick': await renderCycleStrip(
          scene,
          clip: CatClips.kick,
          frames: 16,
          span: CatClips.kick.duration,
        ),
        'dance': await renderCycleStrip(
          scene,
          clip: CatClips.dance,
          frames: 14,
          span: CatClips.dance.duration,
        ),
        'sit': await renderCycleStrip(
          scene,
          clip: CatClips.sit,
          frames: 16,
          span: CatClips.sit.duration,
        ),
        'jump': await renderCycleStrip(
          scene,
          clip: CatClips.jump,
          frames: 16,
          span: CatClips.jump.duration,
        ),
      };

      for (final entry in strips.entries) {
        final file = File('${outputDir.path}/${entry.key}.png')
          ..writeAsBytesSync(entry.value);
        expect(
          await characterPixelCount(entry.value),
          greaterThan(2000),
          reason: '${entry.key} strip should paint the character, not just bg',
        );
        // ignore: avoid_print
        print('wrote ${file.path} (${entry.value.length} bytes)');
      }
    });
  });

  testWidgets('renders expression and blink strips', (tester) async {
    await tester.runAsync(() async {
      final expressions = <({String label, FaceState face})>[
        for (final e in Expression.presets) (label: e.name, face: e.state),
      ];
      final expressionStrip = await renderFaceStrip(scene, faces: expressions);
      File(
        '${outputDir.path}/expressions.png',
      ).writeAsBytesSync(expressionStrip);
      expect(await characterPixelCount(expressionStrip), greaterThan(2000));

      // A blink: eyelids close fast, open slower (asymmetric), happy underneath.
      final blinkFrames = <({String label, FaceState face})>[
        for (final v in <double>[1, 0.75, 0.35, 0, 0.2, 0.5, 0.8, 1])
          (
            label: 'blink',
            face: Expression.happy.state.copyWith(
              eyeOpenLeft: v,
              eyeOpenRight: v,
            ),
          ),
      ];
      final blinkStrip = await renderFaceStrip(scene, faces: blinkFrames);
      File('${outputDir.path}/blink.png').writeAsBytesSync(blinkStrip);
      expect(await characterPixelCount(blinkStrip), greaterThan(2000));
      // ignore: avoid_print
      print('wrote ${outputDir.path}/expressions.png and blink.png');
    });
  });

  testWidgets('engine is deterministic: identical bytes across renders', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final a = await renderCycleStrip(
        scene,
        clip: CatClips.walk,
        frames: 6,
        span: CatClips.walk.duration,
      );
      final b = await renderCycleStrip(
        CharacterScene(buildCatInSuitRig(), autonomic: AutonomicLayer()),
        clip: CatClips.walk,
        frames: 6,
        span: CatClips.walk.duration,
      );
      expect(a, equals(b), reason: 'same inputs must render identical pixels');
    });
  });
}
