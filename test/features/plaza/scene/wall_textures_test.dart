import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/plaza/domain/attention.dart';
import 'package:lotti/features/plaza/scene/wall_textures.dart';

/// The strip as raw RGBA, sampled in world metres from its top-left.
class _Strip {
  _Strip(this.width, this.height, this.bytes);

  final int width;
  final int height;
  final ByteData bytes;

  double get pxPerMeter => width / WallTextures.shopfrontWidth;

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

Future<_Strip> _paint(LanternState state, {int variant = 0}) async {
  final image = WallTextures.paintShopfront(state, variant: variant);
  final bytes = await image.toByteData();
  return _Strip(image.width, image.height, bytes!);
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
}
