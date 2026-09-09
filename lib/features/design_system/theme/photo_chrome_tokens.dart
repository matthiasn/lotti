/// Chrome that sits on a photograph rather than on a themed surface.
///
/// Hand-authored, like `motion_tokens.dart`, `sizing_tokens.dart` and
/// `alpha_tokens.dart`: these values are brightness-invariant on purpose. A
/// banner is an arbitrary user picture — light, dark or busy — and the only
/// chrome that reads over *any* picture, in either theme, is black at reduced
/// strength with white glyphs. Nothing here lerps between light and dark, and
/// none of it is a Figma variable in this repo's export.
///
/// Two tokens, both named by the 2026-09-08 People design (direction 2b) and
/// each used in exactly one place: the person hero's banner strip. Keep it
/// that way — chrome over a themed surface has the theme's own tokens.
library;

import 'dart:ui';

/// `scrim.photoTop` — the darkening over the top of a photo strip, so the
/// glass actions and a swapped-in title stay legible over whatever picture
/// the user chose.
abstract final class PhotoScrim {
  /// The scrim's colour. Black, not a themed surface: the picture beneath it
  /// is the same picture in both themes.
  static const Color color = Color(0xFF000000);

  /// Alpha at the strip's top edge …
  static const double topAlpha = 0.42;

  /// … fading to nothing this far down the strip, as a fraction of the
  /// strip's height *at rest*. Seventy percent puts the toolbar inside the
  /// strong part, and the extent is fixed in pixels once laid out so a
  /// folding strip keeps the toolbar covered rather than fading under it.
  static const double fadeExtent = 0.7;
}

/// `glass.photoNeutral` — a glass button's fill and glyph while it sits on a
/// photograph. The theme's glass is a translucent surface colour: right over
/// the wash, but it disappears over a light picture and muddies over a dark
/// one. Black at 45 % with a white glyph reads over both.
abstract final class PhotoNeutralGlass {
  /// Black at 45 %.
  static const Color fill = Color(0x73000000);

  /// The glyph on that fill.
  static const Color glyph = Color(0xFFFFFFFF);
}
