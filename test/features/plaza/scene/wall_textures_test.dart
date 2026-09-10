import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/plaza/domain/attention.dart';
import 'package:lotti/features/plaza/scene/wall_textures.dart';
import 'package:lotti/features/plaza/ui/plaza_palette.dart';

/// The strip as raw RGBA, sampled in world metres from its top-left.
class _Strip {
  _Strip(this.width, this.height, this.bytes);

  final int width;
  final int height;
  final ByteData bytes;

  double get pxPerMeter => width / WallTextures.shopfrontWidth;

  /// The pixel at [x], [y] in texels, for tiles that are not measured in
  /// shopfront metres.
  ui.Color atPixel(int x, int y) {
    final i = (y.clamp(0, height - 1) * width + x.clamp(0, width - 1)) * 4;
    return ui.Color.fromARGB(
      bytes.getUint8(i + 3),
      bytes.getUint8(i),
      bytes.getUint8(i + 1),
      bytes.getUint8(i + 2),
    );
  }

  ui.Color at(double xMeters, double yMeters) {
    final x = (xMeters * pxPerMeter).floor().clamp(0, width - 1);
    final y = (yMeters * pxPerMeter).floor().clamp(0, height - 1);
    final i = (y * width + x) * 4;
    return ui.Color.fromARGB(
      bytes.getUint8(i + 3),
      bytes.getUint8(i),
      bytes.getUint8(i + 1),
      bytes.getUint8(i + 2),
    );
  }

  /// Samples along the whole strip at [yMeters], 300 points.
  Iterable<ui.Color> along(double yMeters) sync* {
    for (var i = 0; i < 300; i++) {
      yield at(WallTextures.shopfrontWidth * (i + 0.5) / 300, yMeters);
    }
  }

  /// Every pixel row at [xMeters] between two heights.
  Iterable<ui.Color> down(
    double xMeters,
    double fromMeters,
    double toMeters,
  ) sync* {
    final rows = ((toMeters - fromMeters) * pxPerMeter).floor();
    for (var i = 0; i < rows; i++) {
      yield at(xMeters, fromMeters + i / pxPerMeter);
    }
  }
}

Future<_Strip> _paint(
  LanternState state, {
  int variant = 0,
  WallInk ink = WallInk.night,
}) async {
  final image = WallTextures.paintShopfront(state, variant: variant, ink: ink);
  final bytes = await image.toByteData();
  return _Strip(image.width, image.height, bytes!);
}

/// A window tile as raw RGBA, addressed in bays and floors.
Future<_Strip> _paintTile(
  LanternState state, {
  int family = 0,
  WallInk ink = WallInk.night,
}) async {
  final image = WallTextures.paintWindows(state, family: family, ink: ink);
  final bytes = await image.toByteData();
  return _Strip(image.width, image.height, bytes!);
}

/// Mean brightness of every pixel in an image, the one number that says
/// whether a wall is painted for the dark or for the sun.
Future<double> _meanBrightness(ui.Image image) async {
  final bytes = (await image.toByteData())!;
  var total = 0.0;
  for (var i = 0; i < bytes.lengthInBytes; i += 4) {
    total +=
        (bytes.getUint8(i) + bytes.getUint8(i + 1) + bytes.getUint8(i + 2)) /
        (3 * 255);
  }
  return total / (bytes.lengthInBytes / 4);
}

int _count(Iterable<ui.Color> colors, bool Function(ui.Color) test) =>
    colors.where(test).length;

double _mean(Iterable<ui.Color> colors, double Function(ui.Color) f) =>
    colors.map(f).reduce((a, b) => a + b) / colors.length;

double _sum(ui.Color c) => c.r + c.g + c.b;
bool _isRed(ui.Color c) => c.r > 0.7 && c.g < 0.5 && c.b < 0.5;
bool _isAmber(ui.Color c) => c.r > 0.7 && c.g > 0.45 && c.g < 0.85 && c.b < 0.4;

/// Papered glass: a muted warm grey in the shutter register, never a
/// lightbox.
bool _isPaper(ui.Color c) =>
    _sum(c) > 0.85 && _sum(c) < 1.4 && c.r > c.b && c.r - c.b < 0.15;

/// A sign lit in a shop colour: bright and saturated. Grey state words
/// on a dark box are not lit signs.
bool _isLitSign(ui.Color c) {
  final hi = math.max(c.r, math.max(c.g, c.b));
  final lo = math.min(c.r, math.min(c.g, c.b));
  return hi > 0.7 && hi - lo > 0.3;
}

bool _isLitGlass(ui.Color c) => _sum(c) > 0.75;
bool _isDark(ui.Color c) => _sum(c) < 0.9;

/// Rows of the strip in metres from its top: the fascia signs, the tape
/// band, mid-glass.
const _signRow = 0.4;
const _tapeRow = 1.45;
const _glassRow = 2.4;

/// The first shop's glass, centre column, and its glazed height.
const _glassColumn = 1.9;
const _glassTop = 0.9;
const _glassBottom = 3.5;

void main() {
  test(
    'office glazing fills its bays while residential windows stay inset',
    () async {
      final images = [
        WallTextures.paintWindows(LanternState.open),
        WallTextures.paintWindows(LanternState.open, family: 2),
      ];
      for (final image in images) {
        addTearDown(image.dispose);
      }
      final residential = (await images[0].toByteData())!;
      final office = (await images[1].toByteData())!;
      // At 15% across a bay, the residential tile is still solid wall, while
      // the office's full-height glazing has already begun. Test every floor
      // and bay so one seeded lit pane cannot accidentally satisfy the test.
      var glassSamples = 0;
      for (var floor = 0; floor < WallTextures.floors; floor++) {
        for (var bay = 0; bay < WallTextures.bays; bay++) {
          final x = ((bay + 0.15) * images[0].width / WallTextures.bays)
              .floor();
          final y = ((floor + 0.65) * images[0].height / WallTextures.floors)
              .floor();
          final offset = (y * images[0].width + x) * 4;
          final wallPixel = residential.getUint32(offset);
          expect(wallPixel, 0x0B0A14FF);
          if (office.getUint32(offset) != wallPixel) glassSamples++;
        }
      }
      expect(glassSamples, WallTextures.floors * WallTextures.bays);
      expect(images[1].width, images[0].width);
      expect(images[1].height, images[0].height);
    },
  );

  test(
    'paving preserves unlit slab centres and alternates mortar joints',
    () async {
      final image = WallTextures.paintPaving();
      addTearDown(image.dispose);
      final pixels = (await image.toByteData())!;
      int alphaAt(int x, int y) =>
          pixels.getUint8((y * image.width + x) * 4 + 3);
      expect((image.width, image.height), (256, 256));
      for (final y in [32, 96, 160, 224]) {
        expect(alphaAt(64, y), 0);
        expect(alphaAt(192, y), 0);
      }
      expect(alphaAt(0, 32), greaterThan(0));
      expect(alphaAt(128, 32), 0);
      expect(alphaAt(128, 96), greaterThan(0));
      expect(alphaAt(0, 96), 0);
      expect(alphaAt(64, 64), greaterThan(0));
    },
  );

  test('window and shopfront tiles fit the reduced texture budget', () {
    final window = WallTextures.paintWindows(LanternState.open);
    final shops = WallTextures.paintShopfront(LanternState.open);
    addTearDown(window.dispose);
    addTearDown(shops.dispose);
    expect((window.width, window.height), (480, 192));
    expect((shops.width, shops.height), (1584, 192));
    final texels =
        (window.width * window.height + shops.width * shops.height) * 15;
    expect(texels * 4 * 4 / 3, lessThan(32 * 1024 * 1024));
  });

  test(
    'window floor details scale with the reduced texture resolution',
    () async {
      final image = WallTextures.paintWindows(LanternState.open);
      addTearDown(image.dispose);
      final pixels = (await image.toByteData())!;
      // At the left edge there are no panes: the slab is a three-pixel dark
      // band, then a 1.5-pixel lit edge, then the wall. These were authored as
      // six and three pixels at twice the raster resolution.
      List<int> rgbAt(int y) {
        final offset = y * image.width * 4;
        return [
          for (var channel = 0; channel < 3; channel++)
            pixels.getUint8(offset + channel),
        ];
      }

      expect(rgbAt(2), [7, 6, 13]);
      expect(rgbAt(3), [28, 26, 42]);
      expect(rgbAt(5), [11, 10, 20]);
    },
  );

  late final Map<LanternState, _Strip> strips;
  setUpAll(() async {
    strips = {
      for (final state in LanternState.values) state: await _paint(state),
    };
  });

  test(
    'the three window-tile families differ in occupancy, not in state',
    () async {
      final tiles = <int, _Strip>{};
      for (var f = 0; f < WallTextures.tileFamilies; f++) {
        final image = WallTextures.paintWindows(LanternState.open, family: f);
        final bytes = await image.toByteData();
        tiles[f] = _Strip(image.width, image.height, bytes!);
      }
      // Every family is the same 12 x 12 m tile.
      for (final t in tiles.values) {
        expect(t.width / t.height, 2.5);
      }
      // Lit panes per floor, sampled at each pane's centre. The strip
      // sampler works in shopfront metres, so convert through pixels.
      List<int> litPerFloor(_Strip t) => [
        for (var floor = 0; floor < WallTextures.floors; floor++)
          () {
            var n = 0;
            for (var bay = 0; bay < WallTextures.bays; bay++) {
              // Off the centre mullion, inside the pane.
              final px = (bay + 0.4) * (t.width / WallTextures.bays);
              // Below any part-drawn blind, inside the pane.
              final py = (floor + 0.65) * (t.height / WallTextures.floors);
              final c = t.at(
                px / t.pxPerMeter,
                py / t.pxPerMeter,
              );
              if (_sum(c) > 0.62) n++;
            }
            return n;
          }(),
      ];
      // The residential family has one floor with no lit pane and one lit
      // edge to edge; the mixed family has neither.
      final mixed = litPerFloor(tiles[0]!);
      final stack = litPerFloor(tiles[1]!);
      expect(stack, contains(0));
      expect(
        stack.reduce(math.max),
        greaterThanOrEqualTo(WallTextures.bays - 1),
      );
      expect(
        mixed.where((n) => n == 0 || n >= WallTextures.bays - 1),
        isEmpty,
      );
      // The office family is mostly the cool tint.
      var cool = 0;
      var warm = 0;
      final office = tiles[2]!;
      for (var bay = 0; bay < WallTextures.bays; bay++) {
        for (var floor = 0; floor < WallTextures.floors; floor++) {
          final c = office.at(
            (bay + 0.4) *
                (office.width / WallTextures.bays) /
                office.pxPerMeter,
            (floor + 0.65) *
                (office.height / WallTextures.floors) /
                office.pxPerMeter,
          );
          if (_sum(c) < 0.62) continue;
          if (c.b > c.r) {
            cool++;
          } else {
            warm++;
          }
        }
      }
      expect(cool, greaterThan(warm));
    },
  );

  test('every strip is the parade at 48 px per metre', () {
    for (final strip in strips.values) {
      expect(strip.pxPerMeter, 48);
      expect(strip.height / strip.pxPerMeter, WallTextures.shopfrontHeight);
    }
  });

  test(
    'the second parade order is a different picture with the same dressing',
    () async {
      final a = strips[LanternState.inProgress]!;
      final b = await _paint(LanternState.inProgress, variant: 1);
      expect(b.width, a.width);
      // Same amount of lit shop, different arrangement.
      final litA = _count(a.along(_signRow), _isLitSign);
      final litB = _count(b.along(_signRow), _isLitSign);
      expect((litA - litB).abs(), lessThan(litA ~/ 2));
      var differ = 0;
      for (final (ca, cb) in [
        for (var i = 0; i < 300; i++)
          (
            a.at(WallTextures.shopfrontWidth * (i + 0.5) / 300, _glassRow),
            b.at(WallTextures.shopfrontWidth * (i + 0.5) / 300, _glassRow),
          ),
      ]) {
        if ((_sum(ca) - _sum(cb)).abs() > 0.2) differ++;
      }
      expect(differ, greaterThan(100));
    },
  );

  test('the five dressings are five different pictures', () {
    final signatures = {
      for (final MapEntry(key: state, value: strip) in strips.entries)
        state: [
          _count(strip.along(_signRow), _isLitSign),
          _count(strip.along(_glassRow), _isLitGlass),
          _count(strip.along(_tapeRow), _isRed),
          _count(strip.along(_glassRow), _isPaper),
        ],
    };
    final distinct = signatures.values.map((s) => s.join(',')).toSet();
    expect(
      distinct,
      hasLength(LanternState.values.length),
      reason: '$signatures',
    );
  });

  test('in progress trades: lit signs, lit glass, no tape', () {
    final strip = strips[LanternState.inProgress]!;
    // Lit sign colour on at least an eighth of the fascia (the abstract
    // lettering and the vacant unit's board are dark).
    expect(_count(strip.along(_signRow), _isLitSign), greaterThan(38));
    expect(_count(strip.along(_glassRow), _isLitGlass), greaterThan(60));
    expect(_count(strip.along(_tapeRow), _isRed), lessThan(10));
  });

  test('overdue trades late in amber', () {
    final strip = strips[LanternState.overdue]!;
    final trading = strips[LanternState.inProgress]!;
    // Every sign is amber, and the glass is warmer than when trading.
    expect(_count(strip.along(_signRow), _isAmber), greaterThan(60));
    expect(_count(trading.along(_signRow), _isAmber), lessThan(40));
    final warmth = _mean(strip.along(_glassRow), (c) => c.r - c.b);
    final tradingWarmth = _mean(trading.along(_glassRow), (c) => c.r - c.b);
    expect(warmth, greaterThan(tradingWarmth + 0.08));
    expect(_count(strip.along(_glassRow), _isLitGlass), greaterThan(60));
  });

  test('open is not open yet: papered glass and no lit sign', () {
    final strip = strips[LanternState.open]!;
    // At least a third of the strip is papered glass (the rest is doors,
    // mullions, seams and the work light's wash).
    expect(_count(strip.along(_glassRow), _isPaper), greaterThan(100));
    // In the shutter register: nothing on the papered glass is bright.
    expect(
      _count(strip.along(_glassRow), (c) => _sum(c) > 1.6),
      lessThan(20),
    );
    expect(_count(strip.along(_signRow), _isLitSign), lessThan(5));
    expect(_count(strip.along(_tapeRow), _isRed), lessThan(5));
  });

  test('blocked is shuttered behind alarm tape, BLOCKED on the signs', () {
    final strip = strips[LanternState.blocked]!;
    expect(_count(strip.along(_tapeRow), _isRed), greaterThan(60));
    expect(_count(strip.along(_glassRow), _isDark), greaterThan(250));
    // The only colour on the fascia is the alarm word.
    final signs = strip.along(_signRow).toList();
    expect(_count(signs, _isRed), greaterThan(8));
    expect(_count(signs, (c) => _isLitSign(c) && !_isRed(c)), lessThan(5));
  });

  test('off is shuttered for the night: dark, no tape, no lit sign', () {
    final strip = strips[LanternState.off]!;
    expect(_count(strip.along(_glassRow), _isDark), greaterThan(250));
    expect(_count(strip.along(_tapeRow), _isRed), lessThan(5));
    expect(_count(strip.along(_signRow), _isLitSign), lessThan(5));
    expect(_count(strip.along(_signRow), _isRed), lessThan(5));
    // The shutter slats read as lines down the glass, not a black hole.
    final slats = _count(
      strip.down(_glassColumn, _glassTop, _glassBottom),
      (c) => _sum(c) > 0.6,
    );
    expect(slats, greaterThan(10));
    expect(slats, lessThan(80));
  });

  group('WallInk', () {
    test('the painters default to the sky the district was designed in', () {
      expect(WallInk.of(PlazaSkyMode.night), same(WallInk.night));
      expect(WallInk.of(PlazaSkyMode.day), same(WallInk.day));
      expect(WallInk.night.mode, PlazaSkyMode.night);
      expect(WallInk.day.mode, PlazaSkyMode.day);
      expect(WallInk.night.reflectsSky, isFalse);
      expect(WallInk.day.reflectsSky, isTrue);
    });

    test('a night pane is a light: occupied glows, empty barely shows', () {
      const tint = ui.Color(0xFFFFE2B0);
      final (litTop, litBottom) = WallInk.night.pane(
        tint: tint,
        on: true,
        roll: 0.5,
      );
      final (darkTop, _) = WallInk.night.pane(
        tint: tint,
        on: false,
        roll: 0.5,
      );
      expect(litTop.a, greaterThan(darkTop.a));
      expect(
        litBottom.a,
        lessThan(litTop.a),
        reason: 'a pane is brighter at the lintel than at the sill',
      );
      expect((litTop.r, litTop.g, litTop.b), (tint.r, tint.g, tint.b));
    });

    test('a day pane is a mirror: the empty one is pure sky', () {
      final (top, bottom) = WallInk.day.pane(
        tint: const ui.Color(0xFFFFE2B0),
        on: false,
        roll: 0.5,
      );
      expect(top, WallInk.day.skyHigh);
      expect(bottom, WallInk.day.skyLow);
      expect(
        _sum(top),
        greaterThan(_sum(bottom)),
        reason: 'glass mirrors more sky the higher up the pane you look',
      );
    });

    test('a day pane with someone in shows the room through the sky', () {
      const tint = ui.Color(0xFFFFE2B0);
      final (top, bottom) = WallInk.day.pane(tint: tint, on: true, roll: 0.5);
      final (emptyTop, emptyBottom) = WallInk.day.pane(
        tint: tint,
        on: false,
        roll: 0.5,
      );
      expect(_sum(top), lessThan(_sum(emptyTop)));
      expect(_sum(bottom), lessThan(_sum(emptyBottom)));
      expect(
        _sum(bottom),
        lessThan(_sum(top)),
        reason: 'the reflection survives at the top, the room shows below',
      );
      expect(top.a, 1.0, reason: 'daylight glass is opaque, not a glow');
    });

    test('a day pane never out-brightens the sky it reflects', () {
      for (final on in [true, false]) {
        for (final roll in [0.0, 0.5, 1.0]) {
          final (top, bottom) = WallInk.day.pane(
            tint: const ui.Color(0xFFFFFFFF),
            on: on,
            roll: roll,
          );
          expect(_sum(top), lessThanOrEqualTo(_sum(WallInk.day.skyHigh)));
          expect(_sum(bottom), lessThanOrEqualTo(_sum(WallInk.day.skyLow)));
        }
      }
    });
  });

  group('daylight wall textures', () {
    test('the wall between the windows is painted for the sun', () async {
      final nightImage = WallTextures.paintWindows(LanternState.open);
      final dayImage = WallTextures.paintWindows(
        LanternState.open,
        ink: WallInk.day,
      );
      addTearDown(nightImage.dispose);
      addTearDown(dayImage.dispose);
      expect(
        await _meanBrightness(dayImage),
        greaterThan(await _meanBrightness(nightImage) + 0.25),
        reason: 'a night tile under a blue sky is the bug this prevents',
      );
      expect(
        (dayImage.width, dayImage.height),
        (nightImage.width, nightImage.height),
        reason: 'both sets tile the same walls, so the atlas cannot move',
      );
    });

    test('a day tile is wall where a night tile is wall', () async {
      // 15 % across a bay is solid wall on the residential family: the day
      // set must paint the render there, not glass.
      final day = await _paintTile(LanternState.open, ink: WallInk.day);
      for (var floor = 0; floor < WallTextures.floors; floor++) {
        for (var bay = 0; bay < WallTextures.bays; bay++) {
          final x = (bay + 0.15) * day.width / WallTextures.bays;
          final y = (floor + 0.65) * day.height / WallTextures.floors;
          expect(
            day.atPixel(x.floor(), y.floor()),
            WallInk.day.wall,
            reason: 'floor $floor bay $bay is not the day wall',
          );
        }
      }
    });

    test('the shopfront parade is dressed for the sun too', () async {
      final nightImage = WallTextures.paintShopfront(LanternState.inProgress);
      final dayImage = WallTextures.paintShopfront(
        LanternState.inProgress,
        ink: WallInk.day,
      );
      addTearDown(nightImage.dispose);
      addTearDown(dayImage.dispose);
      expect(
        await _meanBrightness(dayImage),
        greaterThan(await _meanBrightness(nightImage)),
      );
      expect((dayImage.width, dayImage.height), (1584, 192));
    });

    test(
      'daylight keeps the state vocabulary the walker has learned',
      () async {
        // The parade still says what the task is doing: blocked is taped,
        // in progress is lit, not started is papered over.
        final blocked = await _paint(LanternState.blocked, ink: WallInk.day);
        final trading = await _paint(LanternState.inProgress, ink: WallInk.day);
        final open = await _paint(LanternState.open, ink: WallInk.day);
        expect(_count(blocked.along(_tapeRow), _isRed), greaterThan(30));
        expect(_count(trading.along(_tapeRow), _isRed), lessThan(5));
        expect(_count(trading.along(_signRow), _isLitSign), greaterThan(10));
        expect(_count(open.along(_glassRow), _isPaper), greaterThan(20));
      },
    );

    test(
      'busy walls are more occupied than sleeping ones, in both skies',
      () async {
        // The lit ratio still says how busy a task is when the panes are
        // mirrors: a day tile with more rooms showing is a busier building.
        for (final ink in [WallInk.night, WallInk.day]) {
          final byState = <LanternState, double>{};
          for (final state in LanternState.values) {
            for (var family = 0; family < WallTextures.tileFamilies; family++) {
              final image = WallTextures.paintWindows(
                state,
                family: family,
                ink: ink,
              );
              addTearDown(image.dispose);
              byState[state] =
                  (byState[state] ?? 0) + await _meanBrightness(image);
            }
          }
          final busy = byState[LanternState.inProgress]!;
          final asleep = byState[LanternState.off]!;
          expect(
            WallTextures.litRatio(LanternState.inProgress),
            greaterThan(WallTextures.litRatio(LanternState.off)),
          );
          expect(
            ink.reflectsSky ? asleep : busy,
            greaterThan(ink.reflectsSky ? busy : asleep),
            reason: ink.reflectsSky
                // Occupied glass shows a dark room where empty glass mirrors
                // a bright sky, so by day a busy wall is the darker one.
                ? 'a day wall with more rooms showing should darken'
                : 'a night wall with more lights on should brighten',
          );
        }
      },
    );

    test('the five states stay five different pictures by day', () async {
      final signatures = <double>{};
      for (final state in LanternState.values) {
        final image = WallTextures.paintShopfront(state, ink: WallInk.day);
        addTearDown(image.dispose);
        signatures.add(
          double.parse((await _meanBrightness(image)).toStringAsFixed(4)),
        );
      }
      expect(signatures, hasLength(LanternState.values.length));
    });
  });

  group('the ground overlays serve both skies', () {
    test('the falloff is a hot core with a feathered skirt', () async {
      // Every ground light is drawn with this, and so is every daylight
      // contact shadow: a hard-edged quad would read as a painted
      // rectangle rather than as contact with the paving.
      final image = WallTextures.paintPool();
      addTearDown(image.dispose);
      final pixels = (await image.toByteData())!;
      int alphaAt(int x, int y) =>
          pixels.getUint8((y * image.width + x) * 4 + 3);
      final centre = image.width ~/ 2;
      expect(
        alphaAt(centre, centre),
        greaterThan(240),
        reason: 'the core is all but opaque; the gradient samples it at 250',
      );
      final ring = [
        for (final r in [0.1, 0.25, 0.4, 0.49])
          alphaAt(centre + (image.width * r).round(), centre),
      ];
      for (var i = 1; i < ring.length; i++) {
        expect(
          ring[i],
          lessThan(ring[i - 1]),
          reason: 'the skirt has to fall away, not step down',
        );
      }
      expect(alphaAt(0, 0), 0, reason: 'the corners must not clip a square');
    });

    test(
      'the shadow mask is flat in the middle where the pool is not',
      () async {
        // This is the difference the daylight shadows live on. Multiplied
        // into a dark colour, the pool's long thin skirt darkens the paving
        // by a percent or two; shade needs a mask that is opaque across the
        // shape and soft only at its rim. Swapping the two back makes every
        // contact shadow disappear, which is exactly what happened once.
        final shadowImage = WallTextures.paintShadow();
        final poolImage = WallTextures.paintPool();
        addTearDown(shadowImage.dispose);
        addTearDown(poolImage.dispose);
        final shadow = (await shadowImage.toByteData())!;
        final pool = (await poolImage.toByteData())!;
        int alphaAt(ByteData pixels, int width, int x, int y) =>
            pixels.getUint8((y * width + x) * 4 + 3);
        final centre = shadowImage.width ~/ 2;
        // Half way out to the rim the shadow is still solid and the pool has
        // already fallen away to a fraction of itself.
        final half = centre + (shadowImage.width * 0.25).round();
        expect(alphaAt(shadow, shadowImage.width, half, centre), 255);
        expect(
          alphaAt(pool, poolImage.width, half, centre),
          lessThan(120),
          reason: 'if the pool ever flattens, this test is measuring nothing',
        );
        // And it still feathers rather than ending in a hard disc edge.
        final rim = centre + (shadowImage.width * 0.45).round();
        expect(
          alphaAt(shadow, shadowImage.width, rim, centre),
          inExclusiveRange(0, 255),
        );
        expect(alphaAt(shadow, shadowImage.width, 0, 0), 0);
      },
    );

    test('the grain is a transparent overlay, so both roads take it', () async {
      // It is blended over the road colour rather than replacing it, which
      // is why the day road needs no grain tile of its own.
      final image = WallTextures.paintGrain();
      addTearDown(image.dispose);
      final pixels = (await image.toByteData())!;
      var opaque = 0;
      var marked = 0;
      for (var i = 0; i < pixels.lengthInBytes; i += 4) {
        final alpha = pixels.getUint8(i + 3);
        if (alpha == 255) opaque++;
        if (alpha > 0) marked++;
      }
      expect(opaque, 0, reason: 'an opaque grain tile would repaint the road');
      expect(marked, greaterThan(500), reason: 'and it has to be visible');
      expect(
        marked,
        lessThan(image.width * image.height),
        reason: 'grit, not a wash',
      );
    });
  });
}
