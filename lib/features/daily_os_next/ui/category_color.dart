export 'package:lotti/utils/category_color.dart';

/// Category-tint alpha for a timeline block fill, encoding the
/// paint-by-numbers contract: planned blocks are a faint sketch waiting
/// to be filled in; recorded ("tracked") blocks are the filled-in paint.
/// Recorded needs more chroma in light mode to keep the filled-in/sketch
/// contrast legible on a white canvas. Composite the result over the
/// canvas color — fills must stay opaque so gridlines never bleed
/// through the cards.
double timelineBlockTintAlpha({required bool tracked, required bool isLight}) {
  if (!tracked) return 0.05;
  return isLight ? 0.30 : 0.18;
}

/// Alpha for a planned block's category-colored accents (left stripe,
/// dashed outline): strong enough to key the category, faint enough to
/// keep the sketch reading provisional. Recorded blocks use the full
/// category color instead.
const double kTimelinePlannedAccentAlpha = 0.45;
