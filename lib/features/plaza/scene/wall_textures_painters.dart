part of 'wall_textures.dart';

// The procedural painters behind [WallTextures]: each draws one wall material.

Future<Texture2D> _upload(ui.Image image) async {
  try {
    return await Texture2D.fromImage(image);
  } finally {
    image.dispose();
  }
}

double _m(double meters) => meters * WallTextures._px;

/// Text on a sign or a notice: capitals, letter-spaced, centred in
/// [box], shrunk to fit.
void _paintWord(
  ui.Canvas canvas,
  String word,
  ui.Rect box,
  ui.Color ink, {
  required double sizePx,
  ui.Color? glow,
}) {
  var size = sizePx;
  ui.Paragraph paragraph;
  while (true) {
    final builder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(
              textAlign: ui.TextAlign.center,
              maxLines: 1,
              fontFamily: 'sans-serif',
            ),
          )
          ..pushStyle(
            ui.TextStyle(
              color: ink,
              fontSize: size,
              fontWeight: ui.FontWeight.w700,
              letterSpacing: size * 0.12,
              shadows: glow == null
                  ? null
                  : [ui.Shadow(color: glow, blurRadius: size * 0.6)],
            ),
          )
          ..addText(word);
    paragraph = builder.build()
      ..layout(ui.ParagraphConstraints(width: box.width));
    // The intrinsic width, not the laid-out line: a single clipped line
    // always fits its box.
    if (paragraph.maxIntrinsicWidth <= box.width * 0.96 || size < 6) break;
    size *= 0.9;
  }
  canvas.drawParagraph(
    paragraph,
    ui.Offset(box.left, box.center.dy - paragraph.height / 2),
  );
}

void _paintShop(
  ui.Canvas canvas,
  math.Random rng,
  _Shop shop,
  double left,
  double width,
  _Dressing dressing,
  PlazaCopy copy,
  WallInk ink,
) {
  const h = WallTextures.shopfrontHeight * WallTextures._px;
  final lit = dressing.lit;
  final accent = dressing == _Dressing.late ? WallTextures._amber : shop.colour;

  // Fascia board with a little of the shop's hue in it, then the sign:
  // lit in the shop's colour, dark when the shop is shut, absent while
  // it is still fitting out.
  canvas.drawRect(
    ui.Rect.fromLTWH(left, 0, width, _m(WallTextures._fasciaM)),
    ui.Paint()..color = ui.Color.lerp(ink.board, shop.colour, 0.12)!,
  );
  if (dressing != _Dressing.fittingOut) {
    final signW = width * (0.5 + rng.nextDouble() * 0.15);
    final signX = left + (width - signW) * (0.3 + rng.nextDouble() * 0.4);
    final sign = ui.Rect.fromLTWH(
      signX,
      _m(0.14),
      signW,
      _m(WallTextures._fasciaM - 0.3),
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
      if (dressing == _Dressing.late) {
        // Trading late says so on every sign.
        _paintWord(
          canvas,
          copy.messages.plazaOpenLate.toUpperCase(),
          sign.deflate(_m(0.05)),
          const ui.Color(0xE607060D),
          sizePx: sign.height * 0.5,
        );
      } else if (shop.trade == _Trade.vacant) {
        _paintWord(
          canvas,
          copy.messages.plazaToLet.toUpperCase(),
          sign.deflate(_m(0.05)),
          const ui.Color(0xB3EDE6D6),
          sizePx: sign.height * 0.45,
        );
      } else {
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
      }
    } else {
      // A dark sign box that says why the shop is shut: the state word
      // is on the wall where the walker reads it.
      final alarm = dressing == _Dressing.shuttered;
      canvas
        ..drawRect(sign, ui.Paint()..color = ink.signOff)
        ..drawRect(
          sign.deflate(2),
          ui.Paint()
            ..color = alarm
                ? WallTextures._alarm.withValues(alpha: 0.7)
                : const ui.Color(0xFF474356)
            ..style = ui.PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      _paintWord(
        canvas,
        shop.trade == _Trade.vacant
            ? copy.messages.plazaToLet.toUpperCase()
            : alarm
            ? copy.messages.taskStatusBlocked.toUpperCase()
            : copy.messages.plazaClosedForNight.toUpperCase(),
        sign.deflate(_m(0.05)),
        alarm ? WallTextures._alarm : const ui.Color(0xFF6E6A80),
        sizePx: sign.height * 0.5,
        glow: alarm ? WallTextures._alarm.withValues(alpha: 0.6) : null,
      );
    }
  } else {
    // Fitting out: a builder's board where the sign will go, sign-sized
    // so the words read from the road.
    final board = ui.Rect.fromLTWH(
      left + width * 0.15,
      _m(0.14),
      width * 0.7,
      _m(WallTextures._fasciaM - 0.3),
    );
    canvas.drawRect(board, ui.Paint()..color = const ui.Color(0xFF2A2734));
    _paintWord(
      canvas,
      shop.trade == _Trade.vacant
          ? copy.messages.plazaToLet.toUpperCase()
          : copy.messages.plazaOpeningSoon.toUpperCase(),
      board.deflate(_m(0.05)),
      const ui.Color(0xFF9A94A8),
      sizePx: board.height * 0.5,
    );
  }
  if (lit) {
    canvas.drawRect(
      ui.Rect.fromLTWH(left, _m(WallTextures._fasciaM) - 4, width, 4),
      ui.Paint()..color = accent.withValues(alpha: 0.9),
    );
  }

  // The frontage: a door to the ground on one side, glazing beside it.
  final doorX = shop.doorLeft
      ? left + _m(WallTextures._pilasterM + WallTextures._jambM)
      : left +
            width -
            _m(
              WallTextures._pilasterM +
                  WallTextures._jambM +
                  WallTextures._doorM,
            );
  final door = ui.Rect.fromLTWH(
    doorX,
    _m(WallTextures._glassTopM),
    _m(WallTextures._doorM),
    h - _m(WallTextures._glassTopM),
  );
  final glass = ui.Rect.fromLTRB(
    shop.doorLeft
        ? door.right + _m(WallTextures._jambM)
        : left + _m(WallTextures._pilasterM + WallTextures._jambM),
    _m(WallTextures._glassTopM),
    shop.doorLeft
        ? left + width - _m(WallTextures._pilasterM + WallTextures._jambM)
        : door.left - _m(WallTextures._jambM),
    h - _m(WallTextures._baseM),
  );
  final riser = ui.Rect.fromLTRB(glass.left, glass.bottom, glass.right, h);
  final vacant = shop.trade == _Trade.vacant;
  switch (dressing) {
    case _Dressing.trading when vacant:
    case _Dressing.late when vacant:
    case _Dressing.fittingOut:
      _paintPapered(canvas, rng, glass, ink);
      _paintDoor(
        canvas,
        door,
        accent,
        lit: false,
        dressing: dressing,
        copy: copy,
        ink: ink,
      );
      canvas.drawRect(riser, ui.Paint()..color = ink.riser);
    case _Dressing.trading:
    case _Dressing.late:
      _paintInterior(
        canvas,
        rng,
        glass,
        shop,
        late: dressing == _Dressing.late,
        ink: ink,
      );
      _paintDoor(
        canvas,
        door,
        accent,
        lit: true,
        dressing: dressing,
        copy: copy,
        ink: ink,
      );
      canvas.drawRect(riser, ui.Paint()..color = ink.riser);
      if (shop.awning) _paintAwning(canvas, glass, accent);
    case _Dressing.shuttered:
    case _Dressing.closed:
      _paintShutters(
        canvas,
        glass,
        door,
        alarm: dressing == _Dressing.shuttered,
        copy: copy,
        ink: ink,
      );
  }
  // Pilaster: the column between one shop and the next.
  canvas.drawRect(
    ui.Rect.fromLTWH(
      left,
      _m(WallTextures._fasciaM),
      _m(WallTextures._pilasterM),
      h - _m(WallTextures._fasciaM),
    ),
    ui.Paint()..color = ink.frame,
  );
}

void _paintInterior(
  ui.Canvas canvas,
  math.Random rng,
  ui.Rect glass,
  _Shop shop, {
  required bool late,
  required WallInk ink,
}) {
  final (interior, glow) = switch (shop.trade) {
    _Trade.cafe => (const ui.Color(0xFFFFD08A), 0.6),
    _Trade.records => (const ui.Color(0xFF9BD8FF), 0.5),
    _Trade.bar => (const ui.Color(0xFFFF6A7A), 0.3),
    _Trade.noodles => (const ui.Color(0xFFFFB070), 0.55),
    _Trade.arcade => (const ui.Color(0xFF6A7AFF), 0.28),
    _Trade.florist => (const ui.Color(0xFFBDE8A0), 0.5),
    // Never trades; painted papered before this is reached.
    _Trade.vacant => (const ui.Color(0xFF8A8598), 0.2),
  };
  canvas
    ..drawRect(glass.inflate(_m(0.05)), ui.Paint()..color = ink.frame)
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
    case _Trade.vacant:
      break;
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
    canvas.drawRect(
      glass,
      ui.Paint()..color = WallTextures._amber.withValues(alpha: 0.3),
    );
  }
  _paintMullions(canvas, glass, ink);
}

/// Vertical mullions about every 1.4 m and a transom under the fanlight.
void _paintMullions(ui.Canvas canvas, ui.Rect glass, WallInk ink) {
  final panes = math.max(1, (glass.width / _m(1.4)).round());
  final paint = ui.Paint()..color = ink.mullion;
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

void _paintFigure(
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

void _paintDoor(
  ui.Canvas canvas,
  ui.Rect door,
  ui.Color accent, {
  required bool lit,
  required _Dressing dressing,
  required PlazaCopy copy,
  required WallInk ink,
}) {
  canvas.drawRect(door.inflate(_m(0.06)), ui.Paint()..color = ink.frame);
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
        ui.Paint()..color = ink.frame,
      );
  } else {
    // A notice taped to the door at eye height, with the words on it.
    final notice = ui.Rect.fromLTWH(
      door.center.dx - _m(0.3),
      _m(1.35),
      _m(0.6),
      _m(0.42),
    );
    canvas
      ..drawRect(door, ui.Paint()..color = ink.leaf)
      ..drawRect(notice, ui.Paint()..color = const ui.Color(0xFFEDE6D6));
    _paintWord(
      canvas,
      dressing == _Dressing.fittingOut
          ? copy.messages.plazaOpeningSoon.toUpperCase()
          : copy.messages.plazaToLet.toUpperCase(),
      notice.deflate(_m(0.03)),
      const ui.Color(0xFF2A2734),
      sizePx: notice.height * 0.4,
    );
  }
  canvas.drawCircle(
    ui.Offset(door.left + door.width * 0.82, _m(2.05)),
    _m(0.025),
    ui.Paint()..color = const ui.Color(0xFF8A8A96),
  );
}

/// Not open yet: sheets of paper taped inside the glass, seams between.
void _paintPapered(
  ui.Canvas canvas,
  math.Random rng,
  ui.Rect glass,
  WallInk ink,
) {
  canvas.drawRect(glass.inflate(_m(0.05)), ui.Paint()..color = ink.frame);
  var x = glass.left;
  while (x < glass.right) {
    final sheet = math.min(_m(0.6 + rng.nextDouble() * 0.5), glass.right - x);
    canvas
      ..drawRect(
        ui.Rect.fromLTWH(x, glass.top, sheet, glass.height),
        ui.Paint()
          // Paper in the shutter register, not a lightbox: a dead unit
          // is never the brightest thing in the parade.
          ..color = ui.Color.lerp(
            const ui.Color(0xFF6E6658),
            const ui.Color(0xFF5E5749),
            rng.nextDouble(),
          )!.withValues(alpha: 0.94),
      )
      ..drawRect(
        ui.Rect.fromLTWH(x, glass.top, 2, glass.height),
        ui.Paint()..color = const ui.Color(0xFF4A443A),
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
        ..color = WallTextures._warmLight.withValues(alpha: 0.35)
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, _m(0.3)),
    );
  }
  _paintMullions(canvas, glass, ink);
}

/// Shutters down over the glass and the door; alarm tape across them
/// and a red lamp over the door when the task is blocked, a dim warm
/// security light when it is simply finished.
void _paintShutters(
  ui.Canvas canvas,
  ui.Rect glass,
  ui.Rect door, {
  required bool alarm,
  required PlazaCopy copy,
  required WallInk ink,
}) {
  const h = WallTextures.shopfrontHeight * WallTextures._px;
  final span = ui.Rect.fromLTRB(
    math.min(glass.left, door.left) - _m(0.06),
    _m(WallTextures._glassTopM) - _m(0.06),
    math.max(glass.right, door.right) + _m(0.06),
    h,
  );
  canvas.drawRect(span, ui.Paint()..color = ink.shutter);
  final light = ui.Paint()..color = const ui.Color(0xFF3B3A4A);
  final dark = ui.Paint()..color = const ui.Color(0xFF14131C);
  for (var y = span.top + _m(0.18); y < span.bottom; y += _m(0.18)) {
    canvas
      ..drawRect(ui.Rect.fromLTWH(span.left, y, span.width, 3), light)
      ..drawRect(ui.Rect.fromLTWH(span.left, y + 3, span.width, 2), dark);
  }
  if (alarm) {
    final band = ui.Rect.fromLTRB(span.left, _m(1.25), span.right, _m(1.65));
    canvas
      ..save()
      ..clipRect(band)
      ..drawRect(band, ui.Paint()..color = const ui.Color(0xFF14121F));
    final stripe = ui.Paint()..color = WallTextures._alarm;
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
    // The words on the tape, where the eye lands.
    final label = ui.Rect.fromLTWH(
      span.center.dx - math.min(span.width * 0.42, _m(1.6)),
      band.top - _m(0.02),
      math.min(span.width * 0.84, _m(3.2)),
      band.height + _m(0.04),
    );
    canvas.drawRect(label, ui.Paint()..color = const ui.Color(0xFF14121F));
    _paintWord(
      canvas,
      copy.messages.plazaDecisionStrip.toUpperCase(),
      label.deflate(_m(0.03)),
      WallTextures._alarm,
      sizePx: label.height * 0.6,
      glow: WallTextures._alarm.withValues(alpha: 0.5),
    );
  }
  final lamp = ui.Offset(
    door.center.dx,
    _m(WallTextures._glassTopM) + _m(0.14),
  );
  if (alarm) {
    canvas
      ..drawCircle(
        lamp,
        _m(0.5),
        ui.Paint()
          ..color = WallTextures._alarm.withValues(alpha: 0.35)
          ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, _m(0.3)),
      )
      ..drawCircle(
        lamp,
        _m(0.16),
        ui.Paint()
          ..color = WallTextures._alarm.withValues(alpha: 0.8)
          ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, _m(0.08)),
      );
  }
  if (!alarm) {
    // A notice on the shutter at eye height: why it is down.
    final notice = ui.Rect.fromLTWH(
      door.center.dx - _m(0.5),
      _m(2),
      _m(1),
      _m(0.36),
    );
    canvas.drawRect(notice, ui.Paint()..color = const ui.Color(0xFFD9D2C2));
    _paintWord(
      canvas,
      copy.messages.plazaClosedForNight.toUpperCase(),
      notice.deflate(_m(0.03)),
      const ui.Color(0xFF2A2734),
      sizePx: notice.height * 0.45,
    );
  }
  canvas.drawCircle(
    lamp,
    _m(0.05),
    ui.Paint()
      ..color = alarm
          ? WallTextures._alarm
          : WallTextures._warmLight.withValues(alpha: 0.7),
  );
}

/// A striped canopy over the glass in the shop's colour.
void _paintAwning(ui.Canvas canvas, ui.Rect glass, ui.Color accent) {
  final band = ui.Rect.fromLTWH(
    glass.left - _m(0.1),
    glass.top - _m(0.02),
    glass.width + _m(0.2),
    _m(0.32),
  );
  canvas.drawRect(band, ui.Paint()..color = accent);
  final stripe = ui.Paint()..color = WallTextures._shade.withValues(alpha: 0.7);
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
    ui.Paint()..color = ui.Color.lerp(accent, WallTextures._shade, 0.5)!,
  );
}

void _paintCafe(ui.Canvas canvas, math.Random rng, ui.Rect g) {
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

void _paintRecords(ui.Canvas canvas, math.Random rng, ui.Rect g) {
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
          ui.Paint()
            ..color =
                WallTextures._spines[rng.nextInt(WallTextures._spines.length)],
        );
      }
    }
  }
}

void _paintBar(ui.Canvas canvas, math.Random rng, ui.Rect g) {
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

void _paintNoodles(ui.Canvas canvas, math.Random rng, ui.Rect g) {
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

void _paintArcade(ui.Canvas canvas, math.Random rng, ui.Rect g) {
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
          ui.Paint()..color = WallTextures._shade.withValues(alpha: 0.45),
        );
      i++;
    }
  }
}

void _paintFlorist(ui.Canvas canvas, math.Random rng, ui.Rect g) {
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
