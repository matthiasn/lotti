import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/character/model/clip.dart';
import 'package:lotti/features/character/model/face.dart';
import 'package:lotti/features/character/runtime/character_painter.dart';
import 'package:lotti/features/character/runtime/character_renderer.dart';
import 'package:lotti/features/character/runtime/character_scene.dart';
import 'package:lotti/features/character/samples/cat_in_suit.dart';

void main() {
  late CharacterScene scene;
  late CharacterRenderer renderer;
  late ui.Image waterfrontBackdropImage;
  late ui.Image waterfrontCloudsImage;
  late ui.Image waterfrontWavesImage;

  setUpAll(() async {
    waterfrontBackdropImage = await _imageFromFile(
      kCharacterWaterfrontBackdropAsset,
    );
    waterfrontCloudsImage = await _imageFromFile(
      kCharacterWaterfrontCloudsAsset,
    );
    waterfrontWavesImage = await _imageFromFile(
      kCharacterWaterfrontWavesAsset,
    );
  });

  tearDownAll(() {
    waterfrontBackdropImage.dispose();
    waterfrontCloudsImage.dispose();
    waterfrontWavesImage.dispose();
  });

  setUp(() {
    scene = CharacterScene(buildCatInSuitRig());
    renderer = CharacterRenderer();
  });

  CharacterPainter painterAt(double t, {Expression e = Expression.neutral}) =>
      CharacterPainter(
        scene: scene,
        clip: CatClips.walk,
        timeSeconds: t,
        expression: e,
        renderer: renderer,
      );

  group('CharacterPainter.shouldRepaint', () {
    test('repaints when time advances', () {
      expect(painterAt(0.1).shouldRepaint(painterAt(0)), isTrue);
    });

    test('repaints when the expression changes', () {
      expect(
        painterAt(0, e: Expression.happy).shouldRepaint(painterAt(0)),
        isTrue,
      );
    });

    test('repaints when the renderer instance changes', () {
      final other = CharacterPainter(
        scene: scene,
        clip: CatClips.walk,
        timeSeconds: 0.5,
        renderer: CharacterRenderer(antiAlias: false),
      );
      expect(other.shouldRepaint(painterAt(0.5)), isTrue);
    });

    test('repaints when walking pair mode changes', () {
      final pair = CharacterPainter(
        scene: scene,
        clip: CatClips.walk,
        timeSeconds: 0.5,
        walkingPair: true,
        renderer: renderer,
      );
      expect(pair.shouldRepaint(painterAt(0.5)), isTrue);
    });

    test('repaints when ensemble clips change', () {
      final lead = CharacterPainter(
        scene: scene,
        clip: CatClips.dance,
        timeSeconds: 0.5,
        walkingPair: true,
        ensembleClips: [CatClips.dance],
        renderer: renderer,
      );
      final backup = CharacterPainter(
        scene: scene,
        clip: CatClips.dance,
        timeSeconds: 0.5,
        walkingPair: true,
        ensembleClips: [CatClips.danceBackupLeft],
        renderer: renderer,
      );
      expect(backup.shouldRepaint(lead), isTrue);
    });

    test('repaints when the backdrop changes', () {
      final waterfront = CharacterPainter(
        scene: scene,
        clip: CatClips.walk,
        timeSeconds: 0.5,
        backdrop: CharacterBackdrop.waterfront,
        renderer: renderer,
      );
      expect(waterfront.shouldRepaint(painterAt(0.5)), isTrue);
    });

    test('does not repaint for identical inputs', () {
      expect(painterAt(0.5).shouldRepaint(painterAt(0.5)), isFalse);
    });
  });

  testWidgets('locomotion moves the cat off-centre vs in-place', (
    tester,
  ) async {
    await tester.runAsync(() async {
      Future<Uint8List> render({required bool locomote}) async {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        CharacterPainter(
          scene: scene,
          clip: CatClips.walk,
          // A time where the walk has travelled a good fraction of a stride.
          timeSeconds: 0.6,
          locomote: locomote,
          renderer: renderer,
        ).paint(canvas, const Size(360, 280));
        final picture = recorder.endRecording();
        final image = await picture.toImage(360, 280);
        final data = await image.toByteData();
        image.dispose();
        picture.dispose();
        return data!.buffer.asUint8List();
      }

      final travelling = await render(locomote: true);
      final inPlace = await render(locomote: false);
      // A clip with no locomotionSpeed (sit) must be unaffected by the flag.
      expect(
        travelling,
        isNot(equals(inPlace)),
        reason: 'a walk should be placed differently when travelling',
      );
    });
  });

  testWidgets('paint actually draws the character (non-blank output)', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      painterAt(0.3).paint(canvas, const Size(200, 280));
      final picture = recorder.endRecording();
      try {
        final image = await picture.toImage(200, 280);
        try {
          final data = await image.toByteData();
          final pixels = data!.buffer.asUint8List();
          // The painter draws on a transparent canvas, so any non-zero alpha
          // byte means the rig was actually rendered (not an empty frame).
          var opaque = 0;
          for (var i = 3; i < pixels.length; i += 4) {
            if (pixels[i] != 0) opaque++;
          }
          expect(opaque, greaterThan(0), reason: 'expected painted pixels');
        } finally {
          image.dispose();
        }
      } finally {
        picture.dispose();
      }
    });
  });

  testWidgets('dance contact foot is visually pinned to the floor', (
    tester,
  ) async {
    await tester.runAsync(() async {
      const width = 320;
      const height = 360;
      const canvasSize = Size(320, 360);
      const feetFraction = 0.78;
      const expectedFloorY = height * feetFraction;

      for (final t in const [0.0, 0.75, 1.5, 2.25, 3.0, 3.75, 4.5]) {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        CharacterPainter(
          scene: scene,
          clip: CatClips.dance,
          timeSeconds: t,
          feetFraction: feetFraction,
          shadowColor: const Color(0x00000000),
          renderer: renderer,
        ).paint(canvas, canvasSize);
        final picture = recorder.endRecording();
        try {
          final image = await picture.toImage(width, height);
          try {
            final data = await image.toByteData();
            final pixels = data!.buffer.asUint8List();
            final floorPixels = _opaquePixelsInBox(
              pixels,
              width,
              0,
              width - 1,
              (expectedFloorY - 4).floor(),
              (expectedFloorY + 5).ceil(),
            );
            expect(
              floorPixels,
              greaterThan(0),
              reason:
                  'dance lowest declared contact foot should reach the floor '
                  'at t=$t',
            );
          } finally {
            image.dispose();
          }
        } finally {
          picture.dispose();
        }
      }
    });
  });

  testWidgets(
    'dance support handoff does not horizontally re-anchor the body',
    (
      tester,
    ) async {
      await tester.runAsync(() async {
        const width = 760;
        const height = 520;
        const canvasSize = Size(760, 520);

        Future<({double x, double y})> visibleCenter(
          Clip clip,
          double p,
        ) async {
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder);
          CharacterPainter(
            scene: scene,
            clip: clip,
            timeSeconds: clip.duration * p,
            shadowColor: const Color(0x00000000),
            renderer: renderer,
          ).paint(canvas, canvasSize);
          final picture = recorder.endRecording();
          try {
            final image = await picture.toImage(width, height);
            try {
              final data = await image.toByteData();
              return _visibleCenter(data!.buffer.asUint8List(), width, height);
            } finally {
              image.dispose();
            }
          } finally {
            picture.dispose();
          }
        }

        for (final clip in [
          CatClips.dance,
          CatClips.danceBackupLeft,
          CatClips.danceBackupRight,
        ]) {
          for (final frame in [60, 120, 225]) {
            final before = await visibleCenter(clip, (frame - 1) / 240);
            final after = await visibleCenter(clip, frame / 240);

            expect(
              (after.x - before.x).abs(),
              lessThan(18),
              reason:
                  '${clip.name} should not snap sideways at support handoff '
                  '$frame',
            );
            expect(
              (after.y - before.y).abs(),
              lessThan(18),
              reason:
                  '${clip.name} should not snap vertically at support handoff '
                  '$frame',
            );
          }
        }
      });
    },
  );

  testWidgets('waterfront backdrop paints distinct stage bands', (
    tester,
  ) async {
    await tester.runAsync(() async {
      const width = 360;
      const height = 420;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      CharacterPainter(
        scene: scene,
        clip: CatClips.dance,
        timeSeconds: 0.3,
        backdrop: CharacterBackdrop.waterfront,
        backdropImage: waterfrontBackdropImage,
        backdropCloudsImage: waterfrontCloudsImage,
        backdropWavesImage: waterfrontWavesImage,
        shadowColor: const Color(0x00000000),
        renderer: renderer,
      ).paint(canvas, Size(width.toDouble(), height.toDouble()));
      final picture = recorder.endRecording();
      try {
        final image = await picture.toImage(width, height);
        try {
          final data = await image.toByteData();
          final pixels = data!.buffer.asUint8List();
          final sky = _rgbaAt(pixels, width, width ~/ 2, 40);
          final water = _rgbaAt(pixels, width, 60, 230);
          final deck = _rgbaAt(pixels, width, width ~/ 2, 400);

          expect(sky.a, 255);
          expect(sky.b, greaterThan(sky.r), reason: 'sky should read blue');
          expect(
            water.b,
            greaterThan(water.r),
            reason: 'water should read blue',
          );
          expect(
            deck.r,
            greaterThan(water.r),
            reason: 'deck should separate from lagoon water',
          );
          expect(deck.r, greaterThan(deck.b), reason: 'deck should read warm');
        } finally {
          image.dispose();
        }
      } finally {
        picture.dispose();
      }
    });
  });

  testWidgets('walking pair paints two separated characters', (tester) async {
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      CharacterPainter(
        scene: scene,
        clip: CatClips.walk,
        timeSeconds: 0.3,
        walkingPair: true,
        shadowColor: const Color(0x00000000),
        renderer: renderer,
      ).paint(canvas, const Size(520, 320));
      final picture = recorder.endRecording();
      try {
        final image = await picture.toImage(520, 320);
        try {
          final data = await image.toByteData();
          final pixels = data!.buffer.asUint8List();
          var leftOpaque = 0;
          var rightOpaque = 0;
          for (var y = 0; y < 320; y++) {
            for (var x = 0; x < 520; x++) {
              final alpha = pixels[(y * 520 + x) * 4 + 3];
              if (alpha == 0) continue;
              if (x < 220) {
                leftOpaque++;
              } else if (x > 300) {
                rightOpaque++;
              }
            }
          }
          expect(
            leftOpaque,
            greaterThan(1500),
            reason: 'left cat should occupy its own lane',
          );
          expect(
            rightOpaque,
            greaterThan(1500),
            reason: 'right cat should occupy its own lane',
          );
        } finally {
          image.dispose();
        }
      } finally {
        picture.dispose();
      }
    });
  });

  testWidgets('dance trio stages the orange lead in the centre lane', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      CharacterPainter(
        scene: scene,
        partnerScene: CharacterScene(
          buildCatInSuitRig(palette: CatInSuitPalette.silverTabby),
        ),
        ensembleScenes: [
          CharacterScene(
            buildCatInSuitRig(palette: CatInSuitPalette.silverTabby),
          ),
          CharacterScene(
            buildCatInSuitRig(palette: CatInSuitPalette.darkBrown),
          ),
        ],
        ensembleClips: [
          CatClips.dance,
          CatClips.danceBackupLeft,
          CatClips.danceBackupRight,
        ],
        ensembleExpressions: const [
          Expression.neutral,
          Expression.content,
          Expression.happy,
        ],
        synchronousEnsemble: true,
        clip: CatClips.dance,
        timeSeconds: 0.25,
        walkingPair: true,
        shadowColor: const Color(0x00000000),
        renderer: renderer,
      ).paint(canvas, const Size(760, 420));
      final picture = recorder.endRecording();
      try {
        final image = await picture.toImage(760, 420);
        try {
          final data = await image.toByteData();
          final pixels = data!.buffer.asUint8List();
          var leftOrange = 0;
          var centerOrange = 0;
          var rightOrange = 0;
          var leftOpaque = 0;
          var rightOpaque = 0;
          for (var y = 0; y < 420; y++) {
            for (var x = 0; x < 760; x++) {
              final offset = (y * 760 + x) * 4;
              final red = pixels[offset];
              final green = pixels[offset + 1];
              final blue = pixels[offset + 2];
              final alpha = pixels[offset + 3];
              if (alpha == 0) continue;
              if (x < 260) leftOpaque++;
              if (x > 500) rightOpaque++;
              final orangeFur =
                  red > 200 && green > 120 && green < 190 && blue < 120;
              if (!orangeFur) continue;
              if (x < 260) {
                leftOrange++;
              } else if (x > 500) {
                rightOrange++;
              } else {
                centerOrange++;
              }
            }
          }

          expect(leftOpaque, greaterThan(1000));
          expect(rightOpaque, greaterThan(1000));
          expect(
            centerOrange,
            greaterThan(leftOrange * 4),
            reason: 'the orange lead should be staged in the centre lane',
          );
          expect(
            centerOrange,
            greaterThan(rightOrange * 4),
            reason: 'the orange lead should be staged in the centre lane',
          );
        } finally {
          image.dispose();
        }
      } finally {
        picture.dispose();
      }
    });
  });

  testWidgets('dance trio camera pushes from wide into a hook medium shot', (
    tester,
  ) async {
    await tester.runAsync(() async {
      Future<({int width, int height})> orangeBoundsAt(double p) async {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        CharacterPainter(
          scene: scene,
          partnerScene: CharacterScene(
            buildCatInSuitRig(palette: CatInSuitPalette.silverTabby),
          ),
          ensembleScenes: [
            CharacterScene(
              buildCatInSuitRig(palette: CatInSuitPalette.silverTabby),
            ),
            CharacterScene(
              buildCatInSuitRig(palette: CatInSuitPalette.darkBrown),
            ),
          ],
          ensembleClips: [
            CatClips.dance,
            CatClips.danceBackupLeft,
            CatClips.danceBackupRight,
          ],
          synchronousEnsemble: true,
          clip: CatClips.dance,
          timeSeconds: CatClips.dance.duration * p,
          walkingPair: true,
          shadowColor: const Color(0x00000000),
          renderer: renderer,
        ).paint(canvas, const Size(760, 420));
        final picture = recorder.endRecording();
        try {
          final image = await picture.toImage(760, 420);
          try {
            final data = await image.toByteData();
            final pixels = data!.buffer.asUint8List();
            var minX = 760;
            var maxX = -1;
            var minY = 420;
            var maxY = -1;
            for (var y = 0; y < 420; y++) {
              for (var x = 0; x < 760; x++) {
                final offset = (y * 760 + x) * 4;
                final red = pixels[offset];
                final green = pixels[offset + 1];
                final blue = pixels[offset + 2];
                final orangeFur =
                    red > 200 && green > 120 && green < 190 && blue < 120;
                if (!orangeFur) continue;
                minX = math.min(minX, x);
                maxX = math.max(maxX, x);
                minY = math.min(minY, y);
                maxY = math.max(maxY, y);
              }
            }

            return (width: maxX - minX + 1, height: maxY - minY + 1);
          } finally {
            image.dispose();
          }
        } finally {
          picture.dispose();
        }
      }

      final wide = await orangeBoundsAt(0);
      final hook = await orangeBoundsAt(5 / 8);

      expect(
        hook.height,
        greaterThan(wide.height * 1.18),
        reason:
            'the hook should read as a camera push-in, not another locked-off '
            'wide stage frame',
      );
      expect(
        hook.width,
        greaterThan(wide.width * 1.15),
        reason: 'the orange lead should visibly grow in the medium hook shot',
      );
    });
  });
}

int _opaquePixelsInBox(
  Uint8List pixels,
  int width,
  int minX,
  int maxX,
  int minY,
  int maxY,
) {
  final left = minX.clamp(0, width - 1);
  final right = maxX.clamp(0, width - 1);
  var opaque = 0;
  for (var y = minY; y <= maxY; y++) {
    for (var x = left; x <= right; x++) {
      if (pixels[(y * width + x) * 4 + 3] != 0) opaque++;
    }
  }
  return opaque;
}

({double x, double y}) _visibleCenter(Uint8List pixels, int width, int height) {
  var minX = width;
  var maxX = 0;
  var minY = height;
  var maxY = 0;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      if (pixels[(y * width + x) * 4 + 3] == 0) continue;
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
  }
  return (x: (minX + maxX) / 2, y: (minY + maxY) / 2);
}

({int r, int g, int b, int a}) _rgbaAt(
  Uint8List pixels,
  int width,
  int x,
  int y,
) {
  final offset = (y * width + x) * 4;
  return (
    r: pixels[offset],
    g: pixels[offset + 1],
    b: pixels[offset + 2],
    a: pixels[offset + 3],
  );
}

Future<ui.Image> _imageFromFile(String path) async {
  final bytes = await File(path).readAsBytes();
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}
