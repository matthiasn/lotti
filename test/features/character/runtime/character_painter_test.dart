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

    test('repaints when the dance camera review mode changes', () {
      final locked = CharacterPainter(
        scene: scene,
        clip: CatClips.dance,
        timeSeconds: 0.5,
        enableDanceCamera: false,
        renderer: renderer,
      );
      expect(locked.shouldRepaint(painterAt(0.5)), isTrue);
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

  testWidgets('dance trio clears the dark backup during the finish', (
    tester,
  ) async {
    await tester.runAsync(() async {
      Future<({double darkCenterX, double leadCenterX, int darkPixels})>
      boundsAt(double p) async {
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
            final lead = _boundsForPixels(
              pixels,
              760,
              420,
              (red, green, blue, alpha, x, y) =>
                  alpha > 180 &&
                  red > 200 &&
                  green > 120 &&
                  green < 190 &&
                  blue < 120,
            );
            final dark = _boundsForPixels(
              pixels,
              760,
              420,
              (red, green, blue, alpha, x, y) =>
                  x > lead.centerX + 20 &&
                  alpha > 180 &&
                  red >= 28 &&
                  red <= 78 &&
                  green >= 20 &&
                  green <= 64 &&
                  blue <= 52,
            );

            expect(dark.count, greaterThan(250));
            expect(lead.count, greaterThan(250));
            return (
              darkCenterX: dark.centerX,
              leadCenterX: lead.centerX,
              darkPixels: dark.count,
            );
          } finally {
            image.dispose();
          }
        } finally {
          picture.dispose();
        }
      }

      final preFinish = await boundsAt(3 / 4);
      final finish = await boundsAt(29 / 32);

      expect(
        finish.darkCenterX,
        lessThan(preFinish.darkCenterX - 8),
        reason:
            'the final hook-reset triangle should pull the dark backup inward '
            'instead of leaving it parked in the right-side clutter lane',
      );
      expect(
        finish.darkCenterX,
        greaterThan(finish.leadCenterX + 34),
        reason:
            'the dark backup should still read as the right-side dancer, not '
            'cross into the lead lane during the finish',
      );
    });
  });

  test('dance trio keeps backup depth stable while focus moves laterally', () {
    ({double dx, double dy, double scale}) formationAt(int index, double p) =>
        CharacterPainter.debugDanceFormation(
          index,
          3,
          CatClips.dance.duration * p,
          CatClips.dance.duration,
        );

    final silverFrames = [
      for (var frame = 0; frame <= 32; frame++) formationAt(0, frame / 32),
    ];
    final darkFrames = [
      for (var frame = 0; frame <= 32; frame++) formationAt(2, frame / 32),
    ];
    final allFrames = [
      ...silverFrames,
      for (var frame = 0; frame <= 32; frame++) formationAt(1, frame / 32),
      ...darkFrames,
    ];

    double range(Iterable<double> values) {
      final list = values.toList();
      return list.reduce(math.max) - list.reduce(math.min);
    }

    double largestFrameStep(
      List<({double dx, double dy, double scale})> frames,
    ) {
      var largest = 0.0;
      for (var i = 1; i < frames.length; i++) {
        largest = math.max(largest, (frames[i].dy - frames[i - 1].dy).abs());
      }
      return largest;
    }

    expect(
      range(silverFrames.map((frame) => frame.dx)),
      greaterThan(28),
      reason:
          'the silver backup should still trade focus through lateral '
          'formation changes instead of standing in a static chorus lane',
    );
    expect(
      range(darkFrames.map((frame) => frame.dx)),
      greaterThan(34),
      reason:
          'the dark backup should still trade focus through lateral formation '
          'changes instead of standing in a static chorus lane',
    );
    expect(
      range(silverFrames.map((frame) => frame.dy)),
      lessThanOrEqualTo(0.001),
      reason:
          'the silver backup floor row should stay locked when its feet are '
          'dancing in place',
    );
    expect(
      range(darkFrames.map((frame) => frame.dy)),
      lessThanOrEqualTo(0.001),
      reason:
          'the dark backup floor row should stay locked when its feet are '
          'dancing in place',
    );
    expect(
      largestFrameStep(silverFrames),
      lessThanOrEqualTo(0.001),
      reason: 'backup depth should not animate without matching footwork',
    );
    expect(
      largestFrameStep(darkFrames),
      lessThanOrEqualTo(0.001),
      reason: 'backup depth should not animate without matching footwork',
    );
    for (final frame in allFrames) {
      expect(
        frame.scale,
        closeTo(1, 0.001),
        reason:
            'dance focus should not come from perspective scale pulses that '
            'are disconnected from the legwork',
      );
    }
  });

  testWidgets('dance trio camera pushes into torso close-up then pulls out', (
    tester,
  ) async {
    await tester.runAsync(() async {
      Future<
        ({
          int orangeWidth,
          int orangeHeight,
          double orangeCenterX,
          double orangeCenterY,
          int contentMinX,
          int contentMaxX,
          int contentMinY,
          int contentMaxY,
        })
      >
      boundsAt(double p, {bool enableDanceCamera = true}) async {
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
          enableDanceCamera: enableDanceCamera,
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
            var minOpaqueX = 760;
            var maxOpaqueX = -1;
            var minOpaqueY = 420;
            var maxOpaqueY = -1;
            for (var y = 0; y < 420; y++) {
              for (var x = 0; x < 760; x++) {
                final offset = (y * 760 + x) * 4;
                if (pixels[offset + 3] != 0) {
                  minOpaqueX = math.min(minOpaqueX, x);
                  maxOpaqueX = math.max(maxOpaqueX, x);
                  minOpaqueY = math.min(minOpaqueY, y);
                  maxOpaqueY = math.max(maxOpaqueY, y);
                }
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

            expect(maxX, greaterThanOrEqualTo(minX));
            expect(maxY, greaterThanOrEqualTo(minY));
            expect(maxOpaqueX, greaterThanOrEqualTo(minOpaqueX));
            expect(maxOpaqueY, greaterThanOrEqualTo(minOpaqueY));
            return (
              orangeWidth: maxX - minX + 1,
              orangeHeight: maxY - minY + 1,
              orangeCenterX: (minX + maxX) / 2,
              orangeCenterY: (minY + maxY) / 2,
              contentMinX: minOpaqueX,
              contentMaxX: maxOpaqueX,
              contentMinY: minOpaqueY,
              contentMaxY: maxOpaqueY,
            );
          } finally {
            image.dispose();
          }
        } finally {
          picture.dispose();
        }
      }

      final wide = await boundsAt(0);
      final centerPush = await boundsAt(1 / 8);
      final rightPan = await boundsAt(1 / 4);
      final rightClose = await boundsAt(3 / 8);
      final rightHold = await boundsAt(7 / 16);
      final leadLevel = await boundsAt(1 / 2);
      final postRightRecovery = await boundsAt(17 / 32);
      final leftPan = await boundsAt(5 / 8);
      final leftClose = await boundsAt(3 / 4);
      final leftHold = await boundsAt(13 / 16);
      final reset = await boundsAt(1);
      final lockedWide = await boundsAt(0, enableDanceCamera: false);
      final lockedMid = await boundsAt(1 / 2, enableDanceCamera: false);

      expect(
        centerPush.orangeCenterX,
        closeTo(wide.orangeCenterX, 28),
        reason:
            'the first push should stay centred on the trio before travelling',
      );
      expect(
        centerPush.orangeHeight,
        inInclusiveRange(wide.orangeHeight * 0.95, wide.orangeHeight * 1.18),
        reason:
            'the first beat should begin a visible dolly-in without jumping '
            'straight to a close-up',
      );
      expect(
        centerPush.orangeCenterX - rightPan.orangeCenterX,
        inInclusiveRange(24, 96),
        reason:
            'the second beat should truck toward the right-side dancer, moving '
            'the lead left on screen',
      );
      expect(
        rightClose.orangeHeight,
        inInclusiveRange(
          wide.orangeHeight * 1.55,
          wide.orangeHeight * 1.9,
        ),
        reason:
            'the right-side pass should commit to a face/torso close-up, not '
            'another mostly full-body medium-wide shot',
      );
      expect(
        rightClose.orangeCenterY,
        lessThan(wide.orangeCenterY - 38),
        reason:
            'the pushed-in camera should lift the dancers toward a face/torso '
            'composition instead of keeping the enlarged lead low in frame',
      );
      expect(
        rightClose.contentMinY,
        greaterThan(2),
        reason:
            'lifting the close-up should not crop ears or heads through the top '
            'of the desktop viewport',
      );
      expect(
        rightClose.contentMinX,
        greaterThanOrEqualTo(0),
        reason:
            'the close-up may crop feet, but it must stay within the desktop '
            'viewport horizontally',
      );
      expect(
        rightClose.contentMaxX,
        lessThanOrEqualTo(759),
        reason:
            'the close-up must not move the visible trio out of the desktop '
            'viewport horizontally',
      );
      expect(
        rightClose.contentMaxY,
        lessThanOrEqualTo(419),
        reason:
            'the torso close-up can crop feet, but it should not move the shot '
            'outside the desktop canvas',
      );
      expect(
        rightHold.orangeCenterX,
        closeTo(rightClose.orangeCenterX, 24),
        reason:
            'the right feature should settle for a short held shot instead of '
            'drifting immediately back to centre',
      );
      expect(
        rightHold.orangeHeight,
        inInclusiveRange(
          rightClose.orangeHeight * 0.98,
          rightClose.orangeHeight * 1.12,
        ),
        reason:
            'the right feature can begin the center push-in, but it should '
            'still read as a settled held shot rather than a zoom jump',
      );
      expect(
        leadLevel.orangeCenterX,
        closeTo(rightHold.orangeCenterX, 72),
        reason:
            'the right pass should ease through the lunge recovery instead of '
            'snapping straight back to the trio centre',
      );
      expect(
        leadLevel.orangeHeight,
        inInclusiveRange(
          rightClose.orangeHeight * 1.08,
          rightClose.orangeHeight * 1.34,
        ),
        reason:
            'the mid-phrase should punch into the lead face/torso instead of '
            'staying at the same side-pass close-up size',
      );
      expect(
        leadLevel.contentMinY,
        greaterThan(2),
        reason: 'the tighter center close-up should not crop ears or heads',
      );
      expect(
        leadLevel.contentMaxY,
        lessThanOrEqualTo(419),
        reason:
            'the tighter center close-up should stay inside the desktop '
            'viewport',
      );
      expect(
        postRightRecovery.orangeCenterX,
        closeTo(leadLevel.orangeCenterX, 72),
        reason:
            'the truck/arc should glide through the centre instead of resetting '
            'to the original wide composition',
      );
      expect(
        postRightRecovery.orangeHeight,
        greaterThan(wide.orangeHeight * 1.5),
        reason:
            'the camera should still be in face/torso territory at the middle '
            'of the shot phrase',
      );
      expect(
        leftPan.orangeCenterX - postRightRecovery.orangeCenterX,
        inInclusiveRange(24, 116),
        reason:
            'the next beat should truck toward the left-side dancer, moving '
            'the lead right on screen',
      );
      expect(
        leftClose.orangeHeight,
        inInclusiveRange(wide.orangeHeight * 1.34, wide.orangeHeight * 1.72),
        reason:
            'the left-side pass should stay visibly pushed in before the final '
            'pull-out',
      );
      expect(
        leftHold.orangeCenterX,
        closeTo(leftClose.orangeCenterX, 36),
        reason:
            'the left feature should also hold briefly before the wide reset',
      );
      expect(
        leftHold.orangeHeight,
        inInclusiveRange(wide.orangeHeight * 1.06, leftClose.orangeHeight),
        reason:
            'the left-side hold should begin the pull-out without snapping '
            'straight back to the wide frame',
      );
      expect(
        reset.orangeHeight,
        closeTo(wide.orangeHeight, wide.orangeHeight * 0.14),
        reason: 'the final beat should return to the wide stage frame',
      );
      expect(
        lockedMid.orangeHeight,
        closeTo(lockedWide.orangeHeight, lockedWide.orangeHeight * 0.2),
        reason:
            'locked-camera review should preserve the choreo formation without '
            'the music-video zoom changing dancer size',
      );
      expect(
        lockedMid.orangeHeight,
        lessThan(leadLevel.orangeHeight * 0.68),
        reason:
            'turning off the dance camera should disable the close-up push-in',
      );
    });
  });

  group('danceParallaxTransform', () {
    const size = Size(800, 450);

    test('is the identity matrix when the dance camera is inactive', () {
      expect(
        CharacterPainter.danceParallaxTransform(
          timeSeconds: 1.2,
          clipDuration: 6,
          size: size,
          active: false,
        ),
        Matrix4.identity(),
      );
      expect(
        CharacterPainter.danceParallaxTransform(
          timeSeconds: 1.2,
          clipDuration: 6,
          size: size,
          danceCameraStrength: 0,
        ),
        Matrix4.identity(),
      );
    });

    test('parallaxes the backdrop less than the foreground dance camera', () {
      // Mid-phrase the shot pushes in; the backdrop scales up too, but by a
      // gentler factor than the full ~2x camera (zoom reduced to 34%).
      final m = CharacterPainter.danceParallaxTransform(
        timeSeconds: 3, // ~half of a 6s phrase → peak push-in
        clipDuration: 6,
        size: size,
      );
      final scale = m.entry(0, 0);
      expect(
        scale,
        greaterThan(1.0),
        reason: 'backdrop zooms with the push-in',
      );
      expect(scale, lessThan(1.4), reason: 'far less than the ~2x foreground');
      expect(m.entry(0, 3), isNot(0), reason: 'a horizontal drift is applied');
    });

    test('strength eases the parallax toward neutral', () {
      final full = CharacterPainter.danceParallaxTransform(
        timeSeconds: 3,
        clipDuration: 6,
        size: size,
      );
      final half = CharacterPainter.danceParallaxTransform(
        timeSeconds: 3,
        clipDuration: 6,
        size: size,
        danceCameraStrength: 0.5,
      );
      expect(half.entry(0, 0), lessThan(full.entry(0, 0)));
      expect(half.entry(0, 0), greaterThan(1.0));
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

({
  int minX,
  int maxX,
  int minY,
  int maxY,
  int count,
  double centerX,
})
_boundsForPixels(
  Uint8List pixels,
  int width,
  int height,
  bool Function(int red, int green, int blue, int alpha, int x, int y)
  predicate,
) {
  var minX = width;
  var maxX = -1;
  var minY = height;
  var maxY = -1;
  var count = 0;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final offset = (y * width + x) * 4;
      if (!predicate(
        pixels[offset],
        pixels[offset + 1],
        pixels[offset + 2],
        pixels[offset + 3],
        x,
        y,
      )) {
        continue;
      }
      minX = math.min(minX, x);
      maxX = math.max(maxX, x);
      minY = math.min(minY, y);
      maxY = math.max(maxY, y);
      count++;
    }
  }
  expect(maxX, greaterThanOrEqualTo(minX));
  expect(maxY, greaterThanOrEqualTo(minY));
  return (
    minX: minX,
    maxX: maxX,
    minY: minY,
    maxY: maxY,
    count: count,
    centerX: (minX + maxX) / 2,
  );
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
