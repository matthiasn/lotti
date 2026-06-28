import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/character/demo/dance_camera_director.dart';
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

  group('CharacterPainter.memberBacklights / bodyGrade', () {
    // Distinct pure-colour gels per lane so rim pixels are unambiguous.
    const gels = [Color(0xFFFF0000), Color(0xFF00FF00), Color(0xFF0000FF)];
    const w = 760;
    const h = 420;
    // Cat lane centres (≈ 0.3/0.5/0.7 of width); assign a pixel to its nearest.
    int laneOf(int x) =>
        (x - 228).abs() <= (x - 380).abs() && x < 304 ? 0 : (x < 456 ? 1 : 2);

    CharacterPainter trio({
      List<Color> backlights = const [],
      ({Color skyWrap, Color deckWrap})? bodyGrade,
      Clip? lead,
    }) => CharacterPainter(
      scene: scene,
      partnerScene: CharacterScene(
        buildCatInSuitRig(palette: CatInSuitPalette.silverTabby),
      ),
      ensembleScenes: [
        CharacterScene(
          buildCatInSuitRig(palette: CatInSuitPalette.silverTabby),
        ),
        CharacterScene(buildCatInSuitRig(palette: CatInSuitPalette.darkBrown)),
      ],
      ensembleClips: [
        lead ?? CatClips.dance,
        CatClips.danceBackupLeft,
        CatClips.danceBackupRight,
      ],
      synchronousEnsemble: true,
      walkingPair: true,
      clip: lead ?? CatClips.dance,
      timeSeconds: 0.25,
      shadowColor: const Color(0x00000000),
      memberBacklights: backlights,
      bodyGrade: bodyGrade,
      renderer: renderer,
    );

    Future<Uint8List> pixels(CharacterPainter p) async {
      final recorder = ui.PictureRecorder();
      p.paint(Canvas(recorder), const Size(760, 420));
      final pic = recorder.endRecording();
      final img = await pic.toImage(w, h);
      final data = (await img.toByteData())!.buffer.asUint8List();
      img.dispose();
      pic.dispose();
      return data;
    }

    testWidgets('rings each member in its own gel beyond the silhouette', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final plain = await pixels(trio());
        final lit = await pixels(trio(backlights: gels));
        var litTotal = 0;
        var plainTotal = 0;
        final hits = [0, 0, 0]; // NEW rim pixels matching this lane's gel
        final wrong = [0, 0, 0];
        for (var y = 0; y < h; y++) {
          for (var x = 0; x < w; x++) {
            final o = (y * w + x) * 4;
            if (plain[o + 3] != 0) plainTotal++;
            if (lit[o + 3] == 0) continue;
            litTotal++;
            if (plain[o + 3] != 0) continue; // only NEW (rim) pixels
            final r = lit[o];
            final g = lit[o + 1];
            final b = lit[o + 2];
            final dom = r > g && r > b ? 0 : (g > r && g > b ? 1 : 2);
            if (dom == laneOf(x)) {
              hits[laneOf(x)]++;
            } else {
              wrong[laneOf(x)]++;
            }
          }
        }
        // The rim adds coloured coverage OUTSIDE the bodies, and each lane's new
        // pixels are dominated by THAT lane's gel.
        expect(
          litTotal,
          greaterThan(plainTotal),
          reason: 'rim adds coverage beyond the bodies',
        );
        for (var i = 0; i < 3; i++) {
          expect(
            hits[i],
            greaterThan(100),
            reason: 'lane $i ringed in its gel',
          );
          expect(
            hits[i],
            greaterThan(wrong[i]),
            reason: 'lane $i rim is mostly its own gel',
          );
        }
      });
    });

    // Regression guard: the concert stage act (rim/halo, grade, formation, foot
    // anchors) must light up for the SHIPPING `shaku` phrase, not only `dance`.
    // The audio player dances `shaku`; gating the whole system on `clip.name ==
    // 'dance'` once left the running player completely dark — invisible to tests
    // because they only ever rendered `dance`. Assert the rim draws for `shaku`.
    testWidgets(
      'rings the trio for the shipping shaku phrase, not just dance',
      (
        tester,
      ) async {
        await tester.runAsync(() async {
          final plain = await pixels(trio(lead: CatClips.shaku));
          final lit = await pixels(
            trio(lead: CatClips.shaku, backlights: gels),
          );
          var newRimPixels = 0;
          for (var y = 0; y < h; y++) {
            for (var x = 0; x < w; x++) {
              final o = (y * w + x) * 4;
              if (lit[o + 3] != 0 && plain[o + 3] == 0) newRimPixels++;
            }
          }
          expect(
            newRimPixels,
            greaterThan(300),
            reason:
                'memberBacklights must ring the cats for the shaku phrase the '
                'audio player actually dances, not only the dance phrase',
          );
        });
      },
    );

    testWidgets('bodyGrade tints the body but leaves the face ungraded', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final plain = await pixels(trio(backlights: gels));
        // Strong, opaque-ish wrap so the body tint is unambiguous in the diff.
        final graded = await pixels(
          trio(
            backlights: gels,
            bodyGrade: const (
              skyWrap: Color(0xAA1F3354),
              deckWrap: Color(0xAA3A2616),
            ),
          ),
        );
        // The figure's vertical extent, from the (ungraded) silhouette.
        var minY = h;
        var maxY = 0;
        for (var y = 0; y < h; y++) {
          for (var x = 0; x < w; x++) {
            if (plain[(y * w + x) * 4 + 3] != 0) {
              if (y < minY) minY = y;
              if (y > maxY) maxY = y;
              break;
            }
          }
        }
        final span = maxY - minY;
        final headCut = minY + (span * 0.32).round(); // head ≈ the top third
        final bodyCut = minY + (span * 0.55).round(); // torso/legs below
        var headChange = 0;
        var bodyChange = 0;
        for (var y = 0; y < h; y++) {
          for (var x = 0; x < w; x++) {
            final o = (y * w + x) * 4;
            if (plain[o + 3] == 0 && graded[o + 3] == 0) continue;
            final d =
                (graded[o] - plain[o]).abs() +
                (graded[o + 1] - plain[o + 1]).abs() +
                (graded[o + 2] - plain[o + 2]).abs();
            if (y < headCut) headChange += d;
            if (y >= bodyCut) bodyChange += d;
          }
        }
        // The grade visibly re-tints the body…
        expect(
          bodyChange,
          greaterThan(5000),
          reason: 'bodyGrade re-tints the torso/legs',
        );
        // …but the head/face is clipped out of the grade, so it barely moves.
        expect(
          headChange,
          lessThan(bodyChange ~/ 8),
          reason: 'the face/head is left at its natural tone',
        );
      });
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

  testWidgets(
    'capped dance-camera strength keeps the left backup off the stage edge '
    'during the push-in (the "left cat cut off" fix)',
    (tester) async {
      await tester.runAsync(() async {
        // At FULL strength the push-in (zoom ~2.08 about centre) shoves the left
        // silver-tabby backup off the 16:9 stage box at the demo's scale — the
        // "left cat cut off well within the window" bug. The demo caps the
        // energetic ramp (kEnergeticCameraStrength) so the whole trio stays on
        // the locked stage. This renders both strengths at the demo's stage and
        // asserts the cap pulls the left backup clear of the edge it hit at full.
        Future<({int count, double centerX, int minX})> silverAt(
          double p,
          double strength,
        ) async {
          const size = Size(1333, 750); // demo-representative locked 16:9 stage
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
            danceCameraStrength: strength,
            scale: size.height * 0.78 / 300.0,
            shadowColor: const Color(0x00000000),
            renderer: renderer,
          ).paint(canvas, size);
          final picture = recorder.endRecording();
          try {
            final image = await picture.toImage(
              size.width.toInt(),
              size.height.toInt(),
            );
            try {
              final data = await image.toByteData();
              final pixels = data!.buffer.asUint8List();
              // Silver-tabby fur: light grey (channels close, mid-bright) — the
              // navy suit is blue-dominant and white eyes are >205, both excluded.
              final silver = _boundsForPixels(
                pixels,
                size.width.toInt(),
                size.height.toInt(),
                (red, green, blue, alpha, x, y) =>
                    alpha > 180 &&
                    red > 120 &&
                    red < 205 &&
                    (red - green).abs() < 24 &&
                    (green - blue).abs() < 24,
              );
              return (
                count: silver.count,
                centerX: silver.centerX,
                minX: silver.minX,
              );
            } finally {
              image.dispose();
            }
          } finally {
            picture.dispose();
          }
        }

        // Worst push-in phase (p=7/16: rising zoom into the right-feature hold).
        const worstPhase = 7 / 16;
        final full = await silverAt(worstPhase, 1);
        final capped = await silverAt(worstPhase, 0.5);

        // Full strength clips the left backup hard against the left edge...
        expect(
          full.minX,
          lessThan(8),
          reason:
              'at full strength the push-in should reach the stage edge (this is '
              'the bug the demo cap exists to prevent)',
        );
        // ...the capped strength pulls it clear, fully on the stage.
        expect(
          capped.minX,
          greaterThan(40),
          reason:
              'the capped energetic strength must hold the left backup clear of '
              'the stage edge so it is not cut off',
        );
        expect(
          capped.centerX,
          lessThan(1333 / 2),
          reason:
              'it must still read as the LEFT dancer (centre left of stage)',
        );
      });
    },
  );

  testWidgets(
    'director close shots keep hero-staged backup cats clear of the side edges',
    (tester) async {
      await tester.runAsync(() async {
        const size = Size(1333, 750); // demo-representative locked 16:9 stage
        const width = 1333;
        const height = 750;
        const edgeMargin = 12;
        const grade = (
          skyWrap: Color(0x2E1F3354),
          deckWrap: Color(0x2E3A2616),
        );

        Future<
          ({
            ({int minX, int maxX, int count}) silver,
            ({int minX, int maxX, int count}) dark,
          })
        >
        backupBounds(Shot shot, double phase) async {
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder);
          CharacterPainter(
            scene: scene,
            ensembleScenes: [
              CharacterScene(
                buildCatInSuitRig(palette: CatInSuitPalette.silverTabby),
              ),
              CharacterScene(
                buildCatInSuitRig(palette: CatInSuitPalette.darkBrown),
              ),
            ],
            ensembleClips: [
              CatClips.shaku,
              CatClips.danceBackupLeft,
              CatClips.danceBackupRight,
            ],
            synchronousEnsemble: true,
            walkingPair: true,
            clip: CatClips.shaku,
            timeSeconds: CatClips.shaku.duration * phase,
            cameraOverride: shot,
            heroStaging: true,
            bodyGrade: grade,
            scale: size.height * 0.78 / 300.0,
            shadowColor: const Color(0x00000000),
            renderer: renderer,
          ).paint(canvas, size);
          final picture = recorder.endRecording();
          try {
            final image = await picture.toImage(width, height);
            try {
              final data = await image.toByteData();
              final pixels = data!.buffer.asUint8List();
              final silver = _boundsForPixels(
                pixels,
                width,
                height,
                (red, green, blue, alpha, x, y) =>
                    x < width ~/ 2 &&
                    alpha > 150 &&
                    red > 110 &&
                    red < 220 &&
                    (red - green).abs() < 30 &&
                    (green - blue).abs() < 30,
              );
              final dark = _boundsForPixels(
                pixels,
                width,
                height,
                (red, green, blue, alpha, x, y) =>
                    x > width ~/ 2 &&
                    alpha > 150 &&
                    red < 95 &&
                    green < 90 &&
                    blue < 90,
              );
              return (
                silver: (
                  minX: silver.minX,
                  maxX: silver.maxX,
                  count: silver.count,
                ),
                dark: (minX: dark.minX, maxX: dark.maxX, count: dark.count),
              );
            } finally {
              image.dispose();
            }
          } finally {
            picture.dispose();
          }
        }

        final cases = [
          (
            label: 'post-chorus sway left',
            shot: cameraShot(
              const DanceCameraContext(
                section: 'post-chorus',
                energetic: true,
                build: 0.9,
                phrasePhase: 0.75,
                sectionPhase: 0.45,
              ),
            ),
          ),
          (
            label: 'post-chorus sway right',
            shot: cameraShot(
              const DanceCameraContext(
                section: 'post-chorus',
                energetic: true,
                build: 0.9,
                phrasePhase: 0.25,
                sectionPhase: 0.45,
              ),
            ),
          ),
          (
            label: 'bridge favours silver',
            shot: cameraShot(
              const DanceCameraContext(
                section: 'bridge',
                energetic: true,
                build: 0.9,
                phrasePhase: 0,
                sectionPhase: 0.25,
              ),
            ),
          ),
          (
            label: 'bridge favours dark',
            shot: cameraShot(
              const DanceCameraContext(
                section: 'bridge',
                energetic: true,
                build: 0.9,
                phrasePhase: 0,
                sectionPhase: 0.75,
              ),
            ),
          ),
        ];

        for (final phase in const [0.0, 0.25, 0.5, 0.75, 31 / 32]) {
          for (final c in cases) {
            final b = await backupBounds(c.shot, phase);
            expect(
              b.silver.count,
              greaterThan(250),
              reason: '${c.label} phase=$phase should find the silver backup',
            );
            expect(
              b.dark.count,
              greaterThan(250),
              reason: '${c.label} phase=$phase should find the dark backup',
            );
            expect(
              b.silver.minX,
              greaterThan(edgeMargin),
              reason:
                  '${c.label} phase=$phase clipped silver at x=${b.silver.minX}',
            );
            expect(
              b.dark.maxX,
              lessThan(width - edgeMargin),
              reason:
                  '${c.label} phase=$phase clipped dark at x=${b.dark.maxX}',
            );
          }
        }
      });
    },
  );

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

  group('danceParallaxTransformForShot', () {
    const size = Size(800, 450);
    // The director plants its pivot at the dancers' feet (0.88 of the height)
    // so a zoom grows the cast upward; the backdrop must scale about the SAME
    // pivot or the scenery would slide off the planted feet.
    const directorPivot = Offset(400, 450 * 0.88); // (400, 396)

    test('is the identity matrix when inactive or the stage is empty', () {
      const shot = (zoom: 2.10, dx: 120.0, dy: 0.0);
      expect(
        CharacterPainter.danceParallaxTransformForShot(
          shot: shot,
          size: size,
          active: false,
        ),
        Matrix4.identity(),
      );
      expect(
        CharacterPainter.danceParallaxTransformForShot(
          shot: shot,
          size: Size.zero,
        ),
        Matrix4.identity(),
      );
    });

    test('a neutral shot leaves the backdrop untouched', () {
      expect(
        CharacterPainter.danceParallaxTransformForShot(
          shot: (zoom: 1.0, dx: 0.0, dy: 0.0),
          size: size,
        ),
        Matrix4.identity(),
      );
    });

    test('parallaxes the backdrop far less than the foreground push-in', () {
      // A strong foreground push to 2.10x only scales the backdrop to
      // 1 + (2.10 - 1) * 0.34 ≈ 1.374 so the scenery reads as deeper than the
      // dancers and the move never feels like a flat crop.
      final m = CharacterPainter.danceParallaxTransformForShot(
        shot: (zoom: 2.10, dx: 0.0, dy: 0.0),
        size: size,
      );
      expect(m.entry(0, 0), moreOrLessEquals(1.374, epsilon: 1e-9));
      expect(m.entry(0, 0), greaterThan(1.0));
      expect(m.entry(0, 0), lessThan(2.10));
    });

    test('scales about the feet-planted director pivot, not the head pivot', () {
      // Under a pure zoom the pivot is the one point that maps to itself.
      // Proving the feet pivot (0.88h) is fixed — while the head pivot (0.56h)
      // is pulled up — is what distinguishes this from the built-in
      // head-height parallax (danceParallaxTransform).
      final m = CharacterPainter.danceParallaxTransformForShot(
        shot: (zoom: 2.10, dx: 0.0, dy: 0.0),
        size: size,
      );
      final fixed = MatrixUtils.transformPoint(m, directorPivot);
      expect(fixed.dx, moreOrLessEquals(directorPivot.dx, epsilon: 1e-6));
      expect(fixed.dy, moreOrLessEquals(directorPivot.dy, epsilon: 1e-6));

      const headPivot = Offset(400, 450 * 0.56); // (400, 252)
      final movedHead = MatrixUtils.transformPoint(m, headPivot);
      expect(
        movedHead.dy,
        lessThan(headPivot.dy - 40),
        reason: 'the head-height point is pulled up, so it is not the pivot',
      );
    });

    test('pans the backdrop by the reduced, 2560-ref-rescaled dx', () {
      // dx is authored in 2560-ref px; the backdrop drifts by dx * 0.28 (lag)
      // rescaled to the stage width. A positive dx slides content right.
      const shot = (zoom: 1.5, dx: 514.0, dy: 0.0);
      final m = CharacterPainter.danceParallaxTransformForShot(
        shot: shot,
        size: size,
      );
      final panned = MatrixUtils.transformPoint(m, directorPivot);
      const expectedDx = 514.0 * 0.28 * 800 / 2560; // ≈ 44.98, within the clamp
      expect(
        panned.dx - directorPivot.dx,
        moreOrLessEquals(expectedDx, epsilon: 1e-6),
      );
      expect(
        panned.dx,
        greaterThan(directorPivot.dx),
        reason: 'a positive dx slides the scenery right',
      );
    });

    test('a flat-zoom vertical nudge is clamped away (dy needs headroom)', () {
      // With no zoom there is no off-screen margin to pan into, so dy clamps to
      // zero and the backdrop stays put — matching _applySceneCamera.
      expect(
        CharacterPainter.danceParallaxTransformForShot(
          shot: (zoom: 1.0, dx: 0.0, dy: 30.0),
          size: size,
        ),
        Matrix4.identity(),
      );
    });

    test('a positive dy lowers the backdrop (more sky on top) once zoomed', () {
      // dy is parallax-reduced (×0.18) then rescaled to the stage height
      // (×height/1440), so the same dy frames the same FRACTION at any size:
      // 40 × 0.18 × 450/1440 = 2.25. Positive pushes content DOWN, opening sky.
      final m = CharacterPainter.danceParallaxTransformForShot(
        shot: (zoom: 2.10, dx: 0.0, dy: 40.0),
        size: size,
      );
      final nudged = MatrixUtils.transformPoint(m, directorPivot);
      expect(
        nudged.dy - directorPivot.dy,
        moreOrLessEquals(2.25, epsilon: 1e-6),
      );
      expect(nudged.dy, greaterThan(directorPivot.dy));
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
