part of 'wall_textures.dart';

/// The inks a painted wall is made of, per hour.
///
/// The window and shopfront tiles are opaque: the texture *is* the wall, so
/// unlike the paving and grain overlays they cannot be reused across skies.
/// Everything the two painters draw the building itself with lives here;
/// what they draw *inside* a lit shop does not, because a shop lights its
/// interior at noon as well.
@immutable
class WallInk {
  const WallInk({
    required this.mode,
    required this.wall,
    required this.officeWall,
    required this.frame,
    required this.reveal,
    required this.mullion,
    required this.board,
    required this.riser,
    required this.leaf,
    required this.signOff,
    required this.shutter,
    required this.blind,
    required this.slabEdge,
    required this.skyHigh,
    required this.skyLow,
    required this.interior,
  });

  final PlazaSkyMode mode;

  /// The wall between the windows, and a shopfront parade's surround.
  final ui.Color wall;

  /// The curtain-wall family's spandrel, which is glass rather than render.
  final ui.Color officeWall;

  /// Around glass and doors.
  final ui.Color frame;

  /// The window reveal: the wall's own thickness around a pane.
  final ui.Color reveal;
  final ui.Color mullion;

  /// Fascia board, stair riser, door leaf, an unlit sign, a closed shutter.
  final ui.Color board;
  final ui.Color riser;
  final ui.Color leaf;
  final ui.Color signOff;
  final ui.Color shutter;

  /// A blind pulled part-way down.
  final ui.Color blind;

  /// The lit top edge of a floor slab, the relief that makes a storey read
  /// as a storey: catching the city at night, catching the sun by day.
  final ui.Color slabEdge;

  /// Daylight only: what a pane reflects, top and bottom, and the interior
  /// that shows through the reflection where someone is in.
  final ui.Color skyHigh;
  final ui.Color skyLow;
  final ui.Color interior;

  /// Whether panes mirror the sky rather than glowing.
  bool get reflectsSky => mode == PlazaSkyMode.day;

  /// The two gradient stops of one pane.
  ///
  /// At night a pane is a light source: [tint] at an alpha that says whether
  /// anyone is in. By day it is a mirror — the sky, top to bottom — and
  /// occupancy shows as an interior behind the reflection instead. Either
  /// way an [on] pane is the one with somebody in it, so the same lit ratio
  /// drives both.
  (ui.Color, ui.Color) pane({
    required ui.Color tint,
    required bool on,
    required double roll,
  }) {
    if (reflectsSky) {
      if (!on) return (skyHigh, skyLow);
      // The reflection survives at the top of the glass, where the sky is
      // steepest in it; the room shows through lower down.
      return (
        ui.Color.lerp(skyHigh, interior, 0.35 + roll * 0.2)!,
        ui.Color.lerp(skyLow, interior, 0.6 + roll * 0.25)!,
      );
    }
    final glow = on ? 0.4 + roll * 0.4 : 0.14 + roll * 0.1;
    return (
      tint.withValues(alpha: glow),
      tint.withValues(alpha: glow * 0.55),
    );
  }

  static WallInk of(PlazaSkyMode mode) =>
      mode == PlazaSkyMode.day ? day : night;

  /// The register the district was painted in: a dark city carrying its own
  /// light.
  static const night = WallInk(
    mode: PlazaSkyMode.night,
    wall: ui.Color(0xFF0B0A14),
    officeWall: ui.Color(0xFF121722),
    frame: ui.Color(0xFF07060D),
    reveal: ui.Color(0xFF050409),
    mullion: ui.Color(0xFF07060D),
    board: ui.Color(0xFF15131F),
    riser: ui.Color(0xFF0A0910),
    leaf: ui.Color(0xFF15131F),
    signOff: ui.Color(0xFF2B2836),
    shutter: ui.Color(0xFF232230),
    blind: ui.Color(0xB30B0A14),
    slabEdge: ui.Color(0xFF1C1A2A),
    // Unused at night: nothing reflects a sky this dark.
    skyHigh: ui.Color(0xFF0B0A14),
    skyLow: ui.Color(0xFF0B0A14),
    interior: ui.Color(0xFF0B0A14),
  );

  /// Mid-morning: render and concrete in the sun, glass that mirrors the
  /// sky, and reveals that read as shade rather than as holes.
  static const day = WallInk(
    mode: PlazaSkyMode.day,
    wall: ui.Color(0xFFB3ADA3),
    officeWall: ui.Color(0xFF9FA8B4),
    frame: ui.Color(0xFF6B665E),
    reveal: ui.Color(0xFF8A857C),
    mullion: ui.Color(0xFF7C776E),
    board: ui.Color(0xFFC7C1B5),
    riser: ui.Color(0xFF9A948A),
    leaf: ui.Color(0xFF8E8577),
    signOff: ui.Color(0xFFA8A296),
    shutter: ui.Color(0xFF9EA2A8),
    blind: ui.Color(0xCCE9E3D6),
    slabEdge: ui.Color(0xFFD6D0C4),
    skyHigh: ui.Color(0xFFBBD3EA),
    skyLow: ui.Color(0xFF8098AE),
    interior: ui.Color(0xFF4A4740),
  );
}

/// The trades in the parade, left to right, plus a vacant unit.
enum _Trade { cafe, records, bar, noodles, arcade, florist, vacant }

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

/// The shops, in a warm register (amber, coral, salmon, orange, gold)
/// with the arcade's teal as the one cool accent, so the attention
/// colours stay the loudest thing at street level.
const _cafe = _Shop(
  5,
  _Trade.cafe,
  ui.Color(0xFFFFC46B),
  doorLeft: false,
  awning: true,
);
const _records = _Shop(
  6,
  _Trade.records,
  ui.Color(0xFFE8705F),
  doorLeft: true,
  awning: false,
);
const _bar = _Shop(
  4,
  _Trade.bar,
  ui.Color(0xFFFF8A6B),
  doorLeft: false,
  awning: false,
);
const _noodles = _Shop(
  6,
  _Trade.noodles,
  ui.Color(0xFFFF7A4A),
  doorLeft: true,
  awning: true,
);
const _arcade = _Shop(
  5,
  _Trade.arcade,
  ui.Color(0xFF5CE0FF),
  doorLeft: false,
  awning: false,
);
const _florist = _Shop(
  4,
  _Trade.florist,
  ui.Color(0xFFD9C36B),
  doorLeft: true,
  awning: true,
);

/// The unit nobody has taken: papered, TO LET, whatever the neighbours
/// are doing. One per run breaks the parade's perfect rhythm.
const _vacant = _Shop(
  3,
  _Trade.vacant,
  ui.Color(0xFF8A8598),
  doorLeft: true,
  awning: false,
);

/// Three orders of the same seven units, 33 m each; a wall picks one by
/// hash, so neighbours never show the same run in the same order.
const _parades = <List<_Shop>>[
  [_cafe, _records, _bar, _vacant, _noodles, _arcade, _florist],
  [_florist, _noodles, _vacant, _cafe, _arcade, _records, _bar],
  [_bar, _arcade, _cafe, _florist, _vacant, _records, _noodles],
];

/// How the parade is dressed for a lantern state.
enum _Dressing {
  /// Open for business: lit signs, glass and people inside.
  trading(LanternState.inProgress, lit: true),

  /// Trading, flooded amber, with amber signs.
  late(LanternState.overdue, lit: true),

  /// Papered glass, blank fascia and a notice on the door.
  fittingOut(LanternState.open),

  /// Shutters behind alarm tape, with a red lamp over the door.
  shuttered(LanternState.blocked),

  /// Shutters down, signs off and a security light over the door.
  closed(LanternState.off);

  const _Dressing(this.state, {this.lit = false});
  final LanternState state;
  final bool lit;

  static _Dressing forState(LanternState state) =>
      values.firstWhere((d) => d.state == state);
}
