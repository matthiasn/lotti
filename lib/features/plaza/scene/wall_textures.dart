import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_scene/scene.dart';
import 'package:lotti/features/plaza/domain/attention.dart';

/// Window-grid textures for the side and back walls, one per lantern
/// state, tiled across every wall: the cheapest way to turn a cuboid into
/// a building at night. Painted once with the Flutter canvas and uploaded
/// as repeating textures; walls pick a tile offset from the task id so no
/// two facades share the same lit windows.
class WallTextures {
  WallTextures._(this._byState);

  final Map<LanternState, Texture2D> _byState;

  /// One tile is [floors] storeys tall and [bays] windows wide, in world
  /// metres [tileHeight] × [tileWidth].
  static const floors = 4;
  static const bays = 10;
  static const tileWidth = 12.0;
  static const tileHeight = 12.0;
  static const _px = 96;

  /// One paving tile covers this many metres of plaza: a 2 × 2 grid of
  /// slabs with a joint between.
  static const pavingMeters = 4.0;

  /// The shopfront strip: six trades in one [shopfrontWidth] ×
  /// [shopfrontHeight] metre parade, painted once per lantern state so a
  /// building's ground floor says what its task is doing (see
  /// [shopfront]).
  static const shopfrontWidth = 30.0;
  static const shopfrontHeight = 4.0;

  /// Lit-window ratio per state: busy buildings glow, finished ones sleep.
  static double litRatio(LanternState state) => switch (state) {
    LanternState.inProgress => 0.62,
    LanternState.blocked => 0.5,
    LanternState.overdue => 0.5,
    LanternState.open => 0.36,
    LanternState.off => 0.2,
  };

  static const _coolTint = ui.Color(0xFF8FB8FF);

  static const _tints = <LanternState, ui.Color>{
    LanternState.inProgress: ui.Color(0xFF9BD8FF),
    LanternState.blocked: ui.Color(0xFFFFB0A0),
    LanternState.overdue: ui.Color(0xFFFFD08A),
    LanternState.open: ui.Color(0xFFFFE2B0),
    LanternState.off: ui.Color(0xFF6E7080),
  };

  /// Paints and uploads the five window tiles, the five shopfront strips,
  /// the light-pool falloff, the asphalt grain and the plaza paving.
  static Future<WallTextures> load() async {
    final map = <LanternState, Texture2D>{};
    final shops = <LanternState, Texture2D>{};
    for (final state in LanternState.values) {
      map[state] = await Texture2D.fromImage(_paint(state));
      shops[state] = await Texture2D.fromImage(paintShopfront(state));
    }
    final textures = WallTextures._(map)
      ..pool = await Texture2D.fromImage(_paintPool())
      ..grain = await Texture2D.fromImage(_paintGrain())
      ..paving = await Texture2D.fromImage(_paintPaving())
      .._shopfronts = shops;
    return textures;
  }

  Texture2D operator [](LanternState state) => _byState[state]!;

  /// A radial falloff: hot core, long feathered skirt. White; the material
  /// colour tints it.
  late final Texture2D pool;

  /// Asphalt grain: a near-black noise tile with faint lighter grit.
  late final Texture2D grain;

  /// Plaza paving: slab joints and a little wear, blended over the slab.
  late final Texture2D paving;

  late Map<LanternState, Texture2D> _shopfronts;

  /// The ground floor for [state]: the parade dressed for what the task is
  /// doing. In progress trades (lit signs, lit glass, people inside);
  /// overdue trades late, flooded amber; open (not started) is papered
  /// over and fitting out, with no sign yet; blocked is shuttered behind
  /// alarm tape; off is shuttered for the night with a security light
  /// over each door.
  Texture2D shopfront(LanternState state) => _shopfronts[state]!;

  static double _m(double meters) => meters * _px;

  static const _night = ui.Color(0xFF0B0A14);
  static const _frame = ui.Color(0xFF07060D);
  static const _board = ui.Color(0xFF15131F);
  static const _riser = ui.Color(0xFF0A0910);
  static const _leaf = ui.Color(0xFF15131F);
  static const _signOff = ui.Color(0xFF2B2836);
  static const _shutter = ui.Color(0xFF232230);
  static const _warmLight = ui.Color(0xFFFFE2B8);

  /// The alarm colours match the lanterns.
  static const _alarm = ui.Color(0xFFE4655F);
  static const _amber = ui.Color(0xFFFBA336);

  static const _fasciaM = 0.75;
  static const _glassTopM = 0.85;
  static const _baseM = 0.4;
  static const _pilasterM = 0.25;
  static const _jambM = 0.12;
  static const _doorM = 1.0;

  /// Paints the shopfront strip for [state]; public so the dressing can be
  /// checked pixel by pixel without a GPU.
  @visibleForTesting
  static ui.Image paintShopfront(LanternState state) {
    const w = shopfrontWidth * _px;
    const h = shopfrontHeight * _px;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)
      ..drawRect(
        const ui.Rect.fromLTWH(0, 0, w, h),
        ui.Paint()..color = _night,
      );
    final rng = math.Random(31337 + state.index);
    final dressing = _dressingFor(state);
    var left = 0.0;
    for (final shop in _parade) {
      _paintShop(canvas, rng, shop, left, _m(shop.width), dressing);
      left += _m(shop.width);
    }
    return recorder.endRecording().toImageSync(w.toInt(), h.toInt());
  }

  static void _paintShop(
    ui.Canvas canvas,
    math.Random rng,
    _Shop shop,
    double left,
    double width,
    _Dressing dressing,
  ) {
    const h = shopfrontHeight * _px;
    final lit = dressing == _Dressing.trading || dressing == _Dressing.late;
    final accent = dressing == _Dressing.late ? _amber : shop.colour;

    // Fascia board with a little of the shop's hue in it, then the sign:
    // lit in the shop's colour, dark when the shop is shut, absent while
    // it is still fitting out.
    canvas.drawRect(
      ui.Rect.fromLTWH(left, 0, width, _m(_fasciaM)),
      ui.Paint()..color = ui.Color.lerp(_board, shop.colour, 0.12)!,
    );
    if (dressing != _Dressing.fittingOut) {
      final signW = width * (0.5 + rng.nextDouble() * 0.15);
      final signX = left + (width - signW) * (0.3 + rng.nextDouble() * 0.4);
      final sign = ui.Rect.fromLTWH(
        signX,
        _m(0.14),
        signW,
        _m(_fasciaM - 0.3),
      );
      if (lit) {
        canvas
          ..drawRect(
            sign.inflate(_m(0.1)),
            ui.Paint()
              ..color = accent.withValues(alpha: 0.5)
              ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, _m(0.12)),
          )
          ..drawRect(sign, ui.Paint()..color = accent);
        // Lettering, abstracted: a few dark blocks in a row.
        final letters = 3 + rng.nextInt(3);
        final slot = sign.width / letters;
        for (var i = 0; i < letters; i++) {
          canvas.drawRRect(
            ui.RRect.fromRectAndRadius(
              ui.Rect.fromLTWH(
                sign.left + slot * i + slot * 0.18,
                sign.top + sign.height * 0.28,
                slot * 0.64,
                sign.height * 0.44,
              ),
              ui.Radius.circular(_m(0.03)),
            ),
            ui.Paint()..color = const ui.Color(0x9E07060D),
          );
        }
      } else {
        canvas
          ..drawRect(sign, ui.Paint()..color = _signOff)
          ..drawRect(
            sign.deflate(2),
            ui.Paint()
              ..color = const ui.Color(0xFF474356)
              ..style = ui.PaintingStyle.stroke
              ..strokeWidth = 2,
          );
      }
    }
    if (lit) {
      canvas.drawRect(
        ui.Rect.fromLTWH(left, _m(_fasciaM) - 4, width, 4),
        ui.Paint()..color = accent.withValues(alpha: 0.9),
      );
    }

    // The frontage: a door to the ground on one side, glazing beside it.
    final doorX = shop.doorLeft
        ? left + _m(_pilasterM + _jambM)
        : left + width - _m(_pilasterM + _jambM + _doorM);
    final door = ui.Rect.fromLTWH(
      doorX,
      _m(_glassTopM),
      _m(_doorM),
      h - _m(_glassTopM),
    );
    final glass = ui.Rect.fromLTRB(
      shop.doorLeft ? door.right + _m(_jambM) : left + _m(_pilasterM + _jambM),
      _m(_glassTopM),
      shop.doorLeft
          ? left + width - _m(_pilasterM + _jambM)
          : door.left - _m(_jambM),
      h - _m(_baseM),
    );
    final riser = ui.Rect.fromLTRB(glass.left, glass.bottom, glass.right, h);
    switch (dressing) {
      case _Dressing.trading:
      case _Dressing.late:
        _paintInterior(
          canvas,
          rng,
          glass,
          shop,
          late: dressing == _Dressing.late,
        );
        _paintDoor(canvas, door, accent, lit: true);
        canvas.drawRect(riser, ui.Paint()..color = _riser);
        if (shop.awning) _paintAwning(canvas, glass, accent);
      case _Dressing.fittingOut:
        _paintPapered(canvas, rng, glass);
        _paintDoor(canvas, door, accent, lit: false);
        canvas.drawRect(riser, ui.Paint()..color = _riser);
      case _Dressing.shuttered:
      case _Dressing.closed:
        _paintShutters(
          canvas,
          glass,
          door,
          alarm: dressing == _Dressing.shuttered,
        );
    }
    // Pilaster: the dark column between one shop and the next.
    canvas.drawRect(
      ui.Rect.fromLTWH(left, _m(_fasciaM), _m(_pilasterM), h - _m(_fasciaM)),
      ui.Paint()..color = _frame,
    );
  }

  static void _paintInterior(
    ui.Canvas canvas,
    math.Random rng,
    ui.Rect glass,
    _Shop shop, {
    required bool late,
  }) {
    final (interior, glow) = switch (shop.trade) {
      _Trade.cafe => (const ui.Color(0xFFFFD08A), 0.6),
      _Trade.records => (const ui.Color(0xFF9BD8FF), 0.5),
      _Trade.bar => (const ui.Color(0xFFFF6A7A), 0.3),
      _Trade.noodles => (const ui.Color(0xFFFFB070), 0.55),
      _Trade.arcade => (const ui.Color(0xFF6A7AFF), 0.28),
      _Trade.florist => (const ui.Color(0xFFBDE8A0), 0.5),
    };
    canvas
      ..drawRect(glass.inflate(_m(0.05)), ui.Paint()..color = _frame)
      ..drawRect(
        glass,
        ui.Paint()
          ..shader = ui.Gradient.linear(glass.topCenter, glass.bottomCenter, [
            interior.withValues(alpha: glow),
            interior.withValues(alpha: glow * 0.45),
          ]),
      );
    switch (shop.trade) {
      case _Trade.cafe:
        _paintCafe(canvas, rng, glass);
      case _Trade.records:
        _paintRecords(canvas, rng, glass);
      case _Trade.bar:
        _paintBar(canvas, rng, glass);
      case _Trade.noodles:
        _paintNoodles(canvas, rng, glass);
      case _Trade.arcade:
        _paintArcade(canvas, rng, glass);
      case _Trade.florist:
        _paintFlorist(canvas, rng, glass);
    }
    // People inside.
    final figures = 1 + rng.nextInt(2);
    for (var i = 0; i < figures; i++) {
      final x =
          glass.left + _m(0.35) + rng.nextDouble() * (glass.width - _m(0.7));
      _paintFigure(canvas, x, glass.bottom, _m(1.6 + rng.nextDouble() * 0.25));
    }
    if (late) {
      // Trading late: the whole interior flooded in the alarm amber.
      canvas.drawRect(glass, ui.Paint()..color = _amber.withValues(alpha: 0.3));
    }
    _paintMullions(canvas, glass);
  }

  /// Vertical mullions about every 1.4 m and a transom under the fanlight.
  static void _paintMullions(ui.Canvas canvas, ui.Rect glass) {
    final panes = math.max(1, (glass.width / _m(1.4)).round());
    final paint = ui.Paint()..color = _frame;
    for (var i = 1; i < panes; i++) {
      final x = glass.left + glass.width * i / panes;
      canvas.drawRect(
        ui.Rect.fromLTWH(x - 2, glass.top, 4, glass.height),
        paint,
      );
    }
    canvas.drawRect(
      ui.Rect.fromLTWH(glass.left, glass.top + _m(0.45), glass.width, 3),
      paint,
    );
  }

  static void _paintFigure(
    ui.Canvas canvas,
    double x,
    double baseY,
    double height,
  ) {
    final paint = ui.Paint()..color = const ui.Color(0xC20B0A14);
    canvas
      ..drawCircle(ui.Offset(x, baseY - height + _m(0.1)), _m(0.1), paint)
      ..drawRRect(
        ui.RRect.fromRectAndRadius(
          ui.Rect.fromLTWH(
            x - _m(0.17),
            baseY - height + _m(0.24),
            _m(0.34),
            height - _m(0.24),
          ),
          ui.Radius.circular(_m(0.1)),
        ),
        paint,
      );
  }

  static void _paintDoor(
    ui.Canvas canvas,
    ui.Rect door,
    ui.Color accent, {
    required bool lit,
  }) {
    canvas.drawRect(door.inflate(_m(0.06)), ui.Paint()..color = _frame);
    if (lit) {
      canvas
        ..drawRect(
          door,
          ui.Paint()
            ..shader = ui.Gradient.linear(door.topCenter, door.bottomCenter, [
              accent.withValues(alpha: 0.35),
              accent.withValues(alpha: 0.12),
            ]),
        )
        // A lit transom over the door.
        ..drawRect(
          ui.Rect.fromLTWH(door.left, door.top, door.width, _m(0.38)),
          ui.Paint()..color = accent.withValues(alpha: 0.85),
        )
        ..drawRect(
          ui.Rect.fromLTWH(door.left, door.top + _m(0.38), door.width, 3),
          ui.Paint()..color = _frame,
        );
    } else {
      canvas
        ..drawRect(door, ui.Paint()..color = _leaf)
        // A notice taped to the door at eye height.
        ..drawRect(
          ui.Rect.fromLTWH(
            door.center.dx - _m(0.12),
            _m(1.45),
            _m(0.24),
            _m(0.3),
          ),
          ui.Paint()..color = const ui.Color(0xFFEDE6D6),
        );
    }
    canvas.drawCircle(
      ui.Offset(door.left + door.width * 0.82, _m(2.05)),
      _m(0.025),
      ui.Paint()..color = const ui.Color(0xFF8A8A96),
    );
  }

  /// Not open yet: sheets of paper taped inside the glass, seams between.
  static void _paintPapered(ui.Canvas canvas, math.Random rng, ui.Rect glass) {
    canvas.drawRect(glass.inflate(_m(0.05)), ui.Paint()..color = _frame);
    var x = glass.left;
    while (x < glass.right) {
      final sheet = math.min(_m(0.6 + rng.nextDouble() * 0.5), glass.right - x);
      canvas
        ..drawRect(
          ui.Rect.fromLTWH(x, glass.top, sheet, glass.height),
          ui.Paint()
            ..color = ui.Color.lerp(
              const ui.Color(0xFFD8CBB2),
              const ui.Color(0xFFC3B69B),
              rng.nextDouble(),
            )!.withValues(alpha: 0.94),
        )
        ..drawRect(
          ui.Rect.fromLTWH(x, glass.top, 2, glass.height),
          ui.Paint()..color = const ui.Color(0xFFB3A48A),
        );
      x += sheet;
    }
    // A work light left on behind the paper, some nights.
    if (rng.nextDouble() < 0.4) {
      canvas.drawCircle(
        ui.Offset(
          glass.left + glass.width * (0.3 + rng.nextDouble() * 0.4),
          glass.center.dy,
        ),
        glass.height * 0.5,
        ui.Paint()
          ..color = _warmLight.withValues(alpha: 0.35)
          ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, _m(0.3)),
      );
    }
    _paintMullions(canvas, glass);
  }

  /// Shutters down over the glass and the door; alarm tape across them
  /// and a red lamp over the door when the task is blocked, a dim warm
  /// security light when it is simply finished.
  static void _paintShutters(
    ui.Canvas canvas,
    ui.Rect glass,
    ui.Rect door, {
    required bool alarm,
  }) {
    const h = shopfrontHeight * _px;
    final span = ui.Rect.fromLTRB(
      math.min(glass.left, door.left) - _m(0.06),
      _m(_glassTopM) - _m(0.06),
      math.max(glass.right, door.right) + _m(0.06),
      h,
    );
    canvas.drawRect(span, ui.Paint()..color = _shutter);
    final light = ui.Paint()..color = const ui.Color(0xFF3B3A4A);
    final dark = ui.Paint()..color = const ui.Color(0xFF14131C);
    for (var y = span.top + _m(0.18); y < span.bottom; y += _m(0.18)) {
      canvas
        ..drawRect(ui.Rect.fromLTWH(span.left, y, span.width, 3), light)
        ..drawRect(ui.Rect.fromLTWH(span.left, y + 3, span.width, 2), dark);
    }
    if (alarm) {
      final band = ui.Rect.fromLTRB(span.left, _m(1.3), span.right, _m(1.6));
      canvas
        ..save()
        ..clipRect(band)
        ..drawRect(band, ui.Paint()..color = const ui.Color(0xFF14121F));
      final stripe = ui.Paint()..color = _alarm;
      for (var x = band.left - band.height; x < band.right; x += _m(0.5)) {
        canvas.drawPath(
          ui.Path()
            ..moveTo(x, band.bottom)
            ..lineTo(x + _m(0.25), band.bottom)
            ..lineTo(x + _m(0.25) + band.height, band.top)
            ..lineTo(x + band.height, band.top)
            ..close(),
          stripe,
        );
      }
      canvas.restore();
    }
    final lamp = ui.Offset(door.center.dx, _m(_glassTopM) + _m(0.14));
    if (alarm) {
      canvas.drawCircle(
        lamp,
        _m(0.14),
        ui.Paint()
          ..color = _alarm.withValues(alpha: 0.6)
          ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, _m(0.1)),
      );
    }
    canvas.drawCircle(
      lamp,
      _m(0.05),
      ui.Paint()..color = alarm ? _alarm : _warmLight.withValues(alpha: 0.7),
    );
  }

  /// A striped canopy over the glass in the shop's colour.
  static void _paintAwning(ui.Canvas canvas, ui.Rect glass, ui.Color accent) {
    final band = ui.Rect.fromLTWH(
      glass.left - _m(0.1),
      glass.top - _m(0.02),
      glass.width + _m(0.2),
      _m(0.32),
    );
    canvas.drawRect(band, ui.Paint()..color = accent);
    final stripe = ui.Paint()..color = _night.withValues(alpha: 0.7);
    for (var x = band.left + _m(0.15); x < band.right; x += _m(0.3)) {
      canvas.drawRect(
        ui.Rect.fromLTWH(
          x,
          band.top,
          math.min(_m(0.15), band.right - x),
          band.height,
        ),
        stripe,
      );
    }
    canvas.drawRect(
      ui.Rect.fromLTWH(band.left, band.bottom - 3, band.width, 3),
      ui.Paint()..color = ui.Color.lerp(accent, _night, 0.5)!,
    );
  }

  static const _spines = [
    ui.Color(0xFFE84C6A),
    ui.Color(0xFF4CC2E8),
    ui.Color(0xFFF2C94C),
    ui.Color(0xFF7ED957),
    ui.Color(0xFFF08A3C),
    ui.Color(0xFFB884F2),
  ];

  static void _paintCafe(ui.Canvas canvas, math.Random rng, ui.Rect g) {
    const loaves = [
      ui.Color(0xFFB07A3A),
      ui.Color(0xFFC99555),
      ui.Color(0xFF8E5A2B),
    ];
    for (final f in [0.3, 0.5]) {
      final y = g.top + g.height * f;
      canvas.drawRect(
        ui.Rect.fromLTWH(g.left + _m(0.2), y, g.width - _m(0.4), 4),
        ui.Paint()..color = const ui.Color(0xFF3A2A1E),
      );
      for (
        var x = g.left + _m(0.25);
        x + _m(0.22) < g.right - _m(0.2);
        x += _m(0.28)
      ) {
        canvas.drawRRect(
          ui.RRect.fromRectAndRadius(
            ui.Rect.fromLTWH(x, y - _m(0.14), _m(0.22), _m(0.14)),
            ui.Radius.circular(_m(0.06)),
          ),
          ui.Paint()..color = loaves[rng.nextInt(loaves.length)],
        );
      }
    }
    final counterTop = g.bottom - g.height * 0.32;
    canvas
      ..drawRect(
        ui.Rect.fromLTRB(
          g.left + _m(0.15),
          counterTop,
          g.right - _m(0.15),
          g.bottom,
        ),
        ui.Paint()..color = const ui.Color(0xFF2A1F19),
      )
      ..drawRect(
        ui.Rect.fromLTWH(
          g.left + _m(0.2),
          counterTop - _m(0.3),
          (g.width - _m(0.4)) * 0.6,
          _m(0.3),
        ),
        ui.Paint()..color = const ui.Color(0x66FFE2B8),
      );
    for (final f in [0.3, 0.7]) {
      final x = g.left + g.width * f;
      canvas
        ..drawRect(
          ui.Rect.fromLTWH(x - 1, g.top, 2, _m(0.35)),
          ui.Paint()..color = const ui.Color(0xFF221D33),
        )
        ..drawCircle(
          ui.Offset(x, g.top + _m(0.4)),
          _m(0.2),
          ui.Paint()..color = const ui.Color(0x4DFFD9A0),
        )
        ..drawRRect(
          ui.RRect.fromRectAndRadius(
            ui.Rect.fromLTWH(
              x - _m(0.12),
              g.top + _m(0.35),
              _m(0.24),
              _m(0.08),
            ),
            ui.Radius.circular(_m(0.03)),
          ),
          ui.Paint()..color = const ui.Color(0xFFFFD9A0),
        );
    }
  }

  static void _paintRecords(ui.Canvas canvas, math.Random rng, ui.Rect g) {
    canvas.drawLine(
      ui.Offset(g.left + _m(0.3), g.top + _m(0.25)),
      ui.Offset(g.left + g.width * 0.5, g.top + _m(0.25)),
      ui.Paint()
        ..color = const ui.Color(0xFFE84C6A)
        ..strokeWidth = 5
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.solid, _m(0.06)),
    );
    for (final dy in [0.35, 0.85]) {
      final top = g.bottom - _m(dy) - _m(0.35);
      for (
        var x = g.left + _m(0.15);
        x + _m(0.5) < g.right - _m(0.1);
        x += _m(0.55)
      ) {
        canvas.drawRect(
          ui.Rect.fromLTWH(x, top, _m(0.5), _m(0.35)),
          ui.Paint()..color = const ui.Color(0xFF1E1A2A),
        );
        for (var i = 0; i < 7; i++) {
          canvas.drawRect(
            ui.Rect.fromLTWH(
              x + _m(0.03) + i * _m(0.065),
              top + _m(0.05),
              _m(0.05),
              _m(0.28),
            ),
            ui.Paint()..color = _spines[rng.nextInt(_spines.length)],
          );
        }
      }
    }
  }

  static void _paintBar(ui.Canvas canvas, math.Random rng, ui.Rect g) {
    canvas.drawLine(
      ui.Offset(g.left + _m(0.25), g.top + _m(0.3)),
      ui.Offset(g.right - _m(0.25), g.top + _m(0.3)),
      ui.Paint()
        ..color = const ui.Color(0xFFFF4A6A)
        ..strokeWidth = 4
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.solid, _m(0.08)),
    );
    final shelf = g.top + g.height * 0.42;
    canvas.drawRect(
      ui.Rect.fromLTWH(g.left + _m(0.15), shelf, g.width - _m(0.3), 3),
      ui.Paint()..color = const ui.Color(0xFF2A1F2A),
    );
    const bottles = [
      ui.Color(0xFF9BD8FF),
      ui.Color(0xFFFFD08A),
      ui.Color(0xFF7ED957),
      ui.Color(0xFFFF6A7A),
    ];
    for (
      var x = g.left + _m(0.2);
      x + _m(0.05) < g.right - _m(0.2);
      x += _m(0.09)
    ) {
      canvas.drawRect(
        ui.Rect.fromLTWH(x, shelf - _m(0.2), _m(0.05), _m(0.2)),
        ui.Paint()
          ..color = bottles[rng.nextInt(bottles.length)].withValues(alpha: 0.8),
      );
    }
    final counter = g.bottom - g.height * 0.28;
    canvas
      ..drawRect(
        ui.Rect.fromLTRB(
          g.left + _m(0.1),
          counter,
          g.right - _m(0.1),
          g.bottom,
        ),
        ui.Paint()..color = const ui.Color(0xFF241A1A),
      )
      ..drawRect(
        ui.Rect.fromLTRB(
          g.left + _m(0.1),
          counter,
          g.right - _m(0.1),
          counter + _m(0.08),
        ),
        ui.Paint()..color = const ui.Color(0xFF3A2A2A),
      );
    for (final f in [0.25, 0.5, 0.75]) {
      final x = g.left + g.width * f;
      canvas
        ..drawRect(
          ui.Rect.fromLTWH(
            x - 2,
            counter + _m(0.25),
            4,
            g.bottom - counter - _m(0.25),
          ),
          ui.Paint()..color = const ui.Color(0xFF2A2230),
        )
        ..drawCircle(
          ui.Offset(x, counter + _m(0.25)),
          _m(0.08),
          ui.Paint()..color = const ui.Color(0xFF2A2230),
        );
    }
  }

  static void _paintNoodles(ui.Canvas canvas, math.Random rng, ui.Rect g) {
    for (final f in [0.2, 0.5, 0.8]) {
      final x = g.left + g.width * f;
      canvas
        ..drawRect(
          ui.Rect.fromLTWH(x - 1, g.top, 2, _m(0.15)),
          ui.Paint()..color = const ui.Color(0xFF221D33),
        )
        ..drawCircle(
          ui.Offset(x, g.top + _m(0.36)),
          _m(0.3),
          ui.Paint()..color = const ui.Color(0x40FF8A5B),
        )
        ..drawRRect(
          ui.RRect.fromRectAndRadius(
            ui.Rect.fromLTWH(
              x - _m(0.16),
              g.top + _m(0.15),
              _m(0.32),
              _m(0.42),
            ),
            ui.Radius.circular(_m(0.14)),
          ),
          ui.Paint()..color = const ui.Color(0xFFFF6A4A),
        )
        ..drawRect(
          ui.Rect.fromLTWH(x - _m(0.16), g.top + _m(0.15), _m(0.32), 3),
          ui.Paint()..color = const ui.Color(0xFFFFC46B),
        )
        ..drawRect(
          ui.Rect.fromLTWH(x - _m(0.16), g.top + _m(0.57) - 3, _m(0.32), 3),
          ui.Paint()..color = const ui.Color(0xFFFFC46B),
        );
    }
    for (
      var x = g.left + _m(0.2);
      x + _m(0.16) < g.right - _m(0.2);
      x += _m(0.22)
    ) {
      canvas.drawRect(
        ui.Rect.fromLTWH(x, g.top + _m(0.75), _m(0.16), _m(0.16)),
        ui.Paint()..color = const ui.Color(0xB3FFE9B8),
      );
    }
    final counter = g.bottom - g.height * 0.3;
    canvas.drawRect(
      ui.Rect.fromLTRB(g.left + _m(0.1), counter, g.right - _m(0.1), g.bottom),
      ui.Paint()..color = const ui.Color(0xFF2A1C16),
    );
    for (
      var x = g.left + _m(0.35);
      x + _m(0.22) < g.right - _m(0.3);
      x += _m(0.4)
    ) {
      canvas
        ..drawOval(
          ui.Rect.fromLTWH(x, counter - _m(0.1), _m(0.22), _m(0.1)),
          ui.Paint()..color = const ui.Color(0xFFF2E6D0),
        )
        ..drawCircle(
          ui.Offset(x + _m(0.11), counter - _m(0.3)),
          _m(0.1 + rng.nextDouble() * 0.06),
          ui.Paint()..color = const ui.Color(0x1FFFFFFF),
        );
    }
  }

  static void _paintArcade(ui.Canvas canvas, math.Random rng, ui.Rect g) {
    const screens = [
      ui.Color(0xFF5CE0FF),
      ui.Color(0xFFFF5AE0),
      ui.Color(0xFF6A7AFF),
      ui.Color(0xFFB884F2),
    ];
    for (
      var x = g.left + _m(0.15);
      x + _m(0.05) < g.right - _m(0.15);
      x += _m(0.14)
    ) {
      canvas.drawCircle(
        ui.Offset(x, g.top + _m(0.12)),
        _m(0.03),
        ui.Paint()..color = screens[rng.nextInt(screens.length)],
      );
    }
    for (final row in [0, 1]) {
      final y = g.top + _m(0.65) + row * _m(0.55);
      var i = 0;
      for (
        var x = g.left + _m(0.2);
        x + _m(0.5) < g.right - _m(0.15);
        x += _m(0.62)
      ) {
        final colour = screens[(i + row) % screens.length];
        final screen = ui.Rect.fromLTWH(x, y, _m(0.5), _m(0.34));
        canvas
          ..drawRect(
            screen.inflate(_m(0.06)),
            ui.Paint()
              ..color = colour.withValues(alpha: 0.5)
              ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, _m(0.08)),
          )
          ..drawRect(screen, ui.Paint()..color = colour)
          ..drawRect(
            screen.deflate(_m(0.05)),
            ui.Paint()..color = _night.withValues(alpha: 0.45),
          );
        i++;
      }
    }
  }

  static void _paintFlorist(ui.Canvas canvas, math.Random rng, ui.Rect g) {
    const blooms = [
      ui.Color(0xFFE8506A),
      ui.Color(0xFFF2C94C),
      ui.Color(0xFFF08A3C),
      ui.Color(0xFFB884F2),
      ui.Color(0xFFFFFFFF),
    ];
    for (final f in [0.3, 0.7]) {
      final x = g.left + g.width * f;
      canvas.drawRRect(
        ui.RRect.fromRectAndRadius(
          ui.Rect.fromLTWH(x - _m(0.1), g.top + _m(0.05), _m(0.2), _m(0.14)),
          ui.Radius.circular(_m(0.03)),
        ),
        ui.Paint()..color = const ui.Color(0xFF3E2E22),
      );
      for (final dx in [-0.1, 0.0, 0.1]) {
        canvas.drawCircle(
          ui.Offset(x + _m(dx), g.top + _m(0.22)),
          _m(0.1),
          ui.Paint()..color = const ui.Color(0xFF4E9A5A),
        );
      }
      canvas.drawRect(
        ui.Rect.fromLTWH(x - 1, g.top + _m(0.28), 2, _m(0.3)),
        ui.Paint()..color = const ui.Color(0xFF3E8A4E),
      );
    }
    for (var tier = 0; tier < 3; tier++) {
      final inset = _m(0.15) + tier * _m(0.15);
      final top = g.bottom - _m(0.25) * (tier + 1);
      canvas.drawRect(
        ui.Rect.fromLTRB(g.left + inset, top, g.right - inset, top + _m(0.22)),
        ui.Paint()..color = const ui.Color(0xFF2A3A28),
      );
      for (
        var x = g.left + inset + _m(0.1);
        x < g.right - inset - _m(0.1);
        x += _m(0.18)
      ) {
        canvas.drawCircle(
          ui.Offset(x, top - _m(0.05)),
          _m(0.07 + rng.nextDouble() * 0.05),
          ui.Paint()
            ..color = blooms[rng.nextInt(blooms.length)].withValues(
              alpha: 0.95,
            ),
        );
      }
    }
  }

  static ui.Image _paintPaving() {
    const size = 256;
    const half = size / 2;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)
      ..drawRect(
        ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
        ui.Paint()..color = const ui.Color(0x00000000),
      );
    final rng = math.Random(9001);
    // Four slabs, each a faintly different shade, so the grid is not flat.
    for (final (x, y) in [(0.0, 0.0), (half, 0.0), (0.0, half), (half, half)]) {
      canvas.drawRect(
        ui.Rect.fromLTWH(x, y, half, half),
        ui.Paint()
          ..color = ui.Color.fromARGB(10 + rng.nextInt(16), 255, 255, 255),
      );
    }
    // Joints: a dark line with a lit edge, the way wet paving catches light.
    final joint = ui.Paint()..color = const ui.Color(0x66000000);
    final edge = ui.Paint()..color = const ui.Color(0x14FFFFFF);
    for (final at in [0.0, half]) {
      canvas
        ..drawRect(ui.Rect.fromLTWH(at, 0, 3, size.toDouble()), joint)
        ..drawRect(ui.Rect.fromLTWH(at + 3, 0, 1.5, size.toDouble()), edge)
        ..drawRect(ui.Rect.fromLTWH(0, at, size.toDouble(), 3), joint)
        ..drawRect(ui.Rect.fromLTWH(0, at + 3, size.toDouble(), 1.5), edge);
    }
    for (var i = 0; i < 300; i++) {
      canvas.drawRect(
        ui.Rect.fromLTWH(
          rng.nextDouble() * size,
          rng.nextDouble() * size,
          1.5,
          1,
        ),
        ui.Paint()..color = ui.Color.fromARGB(20 + rng.nextInt(40), 0, 0, 0),
      );
    }
    return recorder.endRecording().toImageSync(size, size);
  }

  static ui.Image _paintPool() {
    const size = 256;
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawCircle(
      const ui.Offset(size / 2, size / 2),
      size / 2,
      ui.Paint()
        ..shader = ui.Gradient.radial(
          const ui.Offset(size / 2, size / 2),
          size / 2,
          const [
            ui.Color(0xFFFFFFFF),
            ui.Color(0xB3FFFFFF),
            ui.Color(0x4DFFFFFF),
            ui.Color(0x14FFFFFF),
            ui.Color(0x00FFFFFF),
          ],
          const [0, 0.18, 0.45, 0.75, 1],
        ),
    );
    return recorder.endRecording().toImageSync(size, size);
  }

  static ui.Image _paintGrain() {
    const size = 128;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)
      ..drawRect(
        ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
        ui.Paint()..color = const ui.Color(0x00000000),
      );
    // Mostly dark grit with the odd faint fleck: asphalt, not snow.
    final rng = math.Random(4242);
    for (var i = 0; i < 2200; i++) {
      final light = rng.nextDouble() < 0.12;
      canvas.drawRect(
        ui.Rect.fromLTWH(
          rng.nextDouble() * size,
          rng.nextDouble() * size,
          1 + rng.nextDouble() * 1.5,
          1,
        ),
        ui.Paint()
          ..color = light
              ? ui.Color.fromARGB(10 + rng.nextInt(14), 255, 240, 220)
              : ui.Color.fromARGB(50 + rng.nextInt(80), 0, 0, 0),
      );
    }
    return recorder.endRecording().toImageSync(size, size);
  }

  static ui.Image _paint(LanternState state) {
    const w = bays * _px;
    const h = floors * _px;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)
      ..drawRect(
        ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
        ui.Paint()..color = const ui.Color(0xFF0B0A14),
      );
    final rng = math.Random(state.index * 7919 + 17);
    final tint = _tints[state]!;
    final lit = litRatio(state);
    for (var floor = 0; floor < floors; floor++) {
      for (var bay = 0; bay < bays; bay++) {
        final x = bay * _px + _px * 0.2;
        final y = floor * _px + _px * 0.24;
        final rect = ui.Rect.fromLTWH(x, y, _px * 0.6, _px * 0.56);
        final on = rng.nextDouble() < lit;
        // Two tints per state: most windows warm, a few the cooler one,
        // and a sill-to-lintel gradient so the pane has depth.
        final cool = rng.nextDouble() < 0.3;
        final base = cool ? _coolTint : tint;
        final glow = on
            ? 0.5 + rng.nextDouble() * 0.5
            : 0.14 + rng.nextDouble() * 0.1;
        // Reveal: a dark frame around the pane; then the pane with a
        // sill-to-lintel gradient; then mullion and transom.
        final mullion = ui.Paint()..color = const ui.Color(0xFF07060D);
        canvas
          ..drawRect(
            rect.inflate(_px * 0.03),
            ui.Paint()..color = const ui.Color(0xFF050409),
          )
          ..drawRect(
            rect,
            ui.Paint()
              ..shader = ui.Gradient.linear(
                rect.topCenter,
                rect.bottomCenter,
                [
                  base.withValues(alpha: glow),
                  base.withValues(alpha: glow * 0.55),
                ],
              ),
          )
          ..drawRect(
            ui.Rect.fromLTWH(rect.center.dx - 1.5, rect.top, 3, rect.height),
            mullion,
          )
          ..drawRect(
            ui.Rect.fromLTWH(
              rect.left,
              rect.top + rect.height * 0.32,
              rect.width,
              2.5,
            ),
            mullion,
          );
        if (on && rng.nextDouble() < 0.4) {
          // A blind pulled part-way: breaks the grid's regularity.
          canvas.drawRect(
            ui.Rect.fromLTWH(
              rect.left,
              rect.top,
              rect.width,
              rect.height * (0.25 + rng.nextDouble() * 0.35),
            ),
            ui.Paint()..color = const ui.Color(0xB30B0A14),
          );
        }
      }
      // Floor slab: a lit edge over a dark band, the relief of a storey.
      canvas
        ..drawRect(
          ui.Rect.fromLTWH(0, floor * _px.toDouble(), w.toDouble(), 6),
          ui.Paint()..color = const ui.Color(0xFF07060D),
        )
        ..drawRect(
          ui.Rect.fromLTWH(0, floor * _px.toDouble() + 6, w.toDouble(), 3),
          ui.Paint()..color = const ui.Color(0xFF1C1A2A),
        );
    }
    return recorder.endRecording().toImageSync(w, h);
  }
}

/// The trades in the parade, left to right.
enum _Trade { cafe, records, bar, noodles, arcade, florist }

/// One shop: its frontage in metres, its trade, its sign colour, which
/// side its door is on and whether it has an awning.
class _Shop {
  const _Shop(
    this.width,
    this.trade,
    this.colour, {
    required this.doorLeft,
    required this.awning,
  });

  final double width;
  final _Trade trade;
  final ui.Color colour;
  final bool doorLeft;
  final bool awning;
}

/// Six shops of different widths, 30 m in all, so any stretch of wall
/// shows a different mix and no two walls start at the same shop.
const _parade = [
  _Shop(5, _Trade.cafe, ui.Color(0xFFFFC46B), doorLeft: false, awning: true),
  _Shop(6, _Trade.records, ui.Color(0xFFE84C6A), doorLeft: true, awning: false),
  _Shop(4, _Trade.bar, ui.Color(0xFFFF5A7A), doorLeft: false, awning: false),
  _Shop(6, _Trade.noodles, ui.Color(0xFFFF7A4A), doorLeft: true, awning: true),
  _Shop(5, _Trade.arcade, ui.Color(0xFF5CE0FF), doorLeft: false, awning: false),
  _Shop(4, _Trade.florist, ui.Color(0xFF7ED957), doorLeft: true, awning: true),
];

/// How the parade is dressed for a lantern state.
enum _Dressing {
  /// Open for business: lit signs, lit glass, people inside.
  trading,

  /// Open late: trading, flooded amber, every sign in amber.
  late,

  /// Not open yet: papered glass, a blank fascia, a notice on the door.
  fittingOut,

  /// Shutters down behind alarm tape, a red lamp over each door.
  shuttered,

  /// Shutters down, signs off, a security light over each door.
  closed,
}

_Dressing _dressingFor(LanternState state) => switch (state) {
  LanternState.inProgress => _Dressing.trading,
  LanternState.overdue => _Dressing.late,
  LanternState.open => _Dressing.fittingOut,
  LanternState.blocked => _Dressing.shuttered,
  LanternState.off => _Dressing.closed,
};
