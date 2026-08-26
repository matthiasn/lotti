/// Filled counterparts for the icons that carry a state.
///
/// Lucide is stroke-only by design and ships no filled set — the whole family
/// is one consistent 2px outline. That is the right default, but it loses
/// something Material gave us for free: a *toggle* whose on-state was the same
/// glyph, filled. Colour alone is a weaker signal, and in one case
/// (`entry_detail_header`'s flag) colour was not applied at all, so a flagged
/// entry looked exactly like an unflagged one.
///
/// So this is a deliberately tiny font, generated from Lucide's own SVG
/// geometry with the silhouette filled — same shapes, same optical weight, no
/// second icon family. Regenerate with `tool/icons/filled_font/build.mjs`; the
/// source SVGs and the reasoning live beside it.
///
/// Most glyphs here are the on-state of a toggle. The timer's two controls
/// are the exception: `square` is its stop mark, which outlined read as an
/// empty checkbox, and `circle` doubles as its continue mark — the full-size
/// record dot, replacing Lucide's `dot`, a ~4px mark inside a 20px glyph.
///
/// Only glyphs whose outline is a single closed silhouette are here. `list`,
/// `chartColumn` and `users` are built from open strokes and have no meaningful
/// filled form; `book` fills to a featureless rounded square because its spine
/// is an inner stroke. Those toggles carry their state in colour, which their
/// components already do.
///
/// `flag` is the one glyph that needed a correction rather than a straight
/// fill: its pole is an open run that the fill swallows, so the source SVG
/// re-adds it as a solid bar. Both states therefore share one silhouette.
library;

import 'package:flutter/widgets.dart';

/// Filled glyphs, keyed to their `LottiIcons` outline counterpart by name.
///
/// Pair them: `starred ? LottiIconsFilled.star : LottiIcons.star`.
abstract final class LottiIconsFilled {
  static const _family = 'LottiFilled';

  /// Filled counterpart of `LottiIcons.bookmark` — saved for later.
  static const IconData bookmark = IconData(0xea01, fontFamily: _family);

  /// Filled counterpart of `LottiIcons.radioUnselected` — a chosen dot, and
  /// the timer's record mark that continues a stopped entry.
  static const IconData circle = IconData(0xea02, fontFamily: _family);

  /// Filled counterpart of `LottiIcons.flag` — flagged for attention.
  static const IconData flag = IconData(0xea03, fontFamily: _family);

  /// Filled counterpart of `LottiIcons.folder`.
  static const IconData folder = IconData(0xea04, fontFamily: _family);

  /// Filled counterpart of `LottiIcons.favorite` — a liked entry.
  static const IconData heart = IconData(0xea05, fontFamily: _family);

  /// Filled counterpart of `LottiIcons.night` — dark theme selected.
  static const IconData moon = IconData(0xea06, fontFamily: _family);

  /// Filled counterpart of `LottiIcons.stop` — stop the running timer.
  static const IconData square = IconData(0xea07, fontFamily: _family);

  /// Filled counterpart of `LottiIcons.star` — starred.
  static const IconData star = IconData(0xea08, fontFamily: _family);
}
