/// Chrome that sits on a live 3D world rather than on a themed surface.
///
/// Hand-authored, like `photo_chrome_tokens.dart`, `motion_tokens.dart` and
/// `sizing_tokens.dart`: these values are brightness-invariant on purpose.
/// The backdrop is a rendered street — a night facade one second and a noon
/// sky the next — so the theme's own surfaces cannot serve. Those greys were
/// picked to sit *under* content; a flat one laid over the world reads as a
/// hole cut in it. Nothing here lerps between light and dark, and none of it
/// is a Figma variable in this repo's export.
///
/// Sibling to `PhotoNeutralGlass`, and the same bargain: a photograph is an
/// arbitrary picture, a world is an arbitrary view of one. The difference is
/// strength. Black at 45% works over a still photo because nothing behind it
/// moves; over a walking camera it strobes as the street slides past, so this
/// glass is near-opaque and tinted rather than neutral — a cool navy that
/// stays a panel while the world moves underneath it.
///
/// Used by the plaza's HUD. Keep it that way: chrome over a themed surface
/// has the theme's own tokens.
library;

import 'package:material_ui/material_ui.dart';

/// `glass.world` — the fill, blur and drop of a panel or button floating over
/// a rendered world.
abstract final class WorldGlass {
  /// The glass itself. Dark enough to carry white type against a noon sky,
  /// translucent enough that the street still moves behind it.
  static const Color fill = Color(0xEB263148);

  /// The same glass under a pointer: lighter, no hue shift.
  static const Color fillHover = Color(0xF23A4864);

  /// Standard deviation, in logical pixels, of the blur applied to whatever
  /// is behind the glass. Sized to smear building windows and billboard type
  /// into a wash without turning the whole street to fog.
  static const double blurSigma = 8;

  /// The drop the glass casts onto the world. Deeper and softer than
  /// `DsShadows.floatingSurface`, which is tuned for a card over a page:
  /// here the backdrop is an arbitrary view of a city, and a 4px grey blur
  /// disappears into it.
  static const List<BoxShadow> drop = [
    BoxShadow(
      color: Color(0x59000000),
      offset: Offset(0, 8),
      blurRadius: 24,
    ),
  ];
}
