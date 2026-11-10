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

/// Alpha for a planned block's dashed category outline on a dark canvas:
/// strong enough to key the category, faint enough to keep the sketch
/// reading provisional. The left stripe, planned or recorded, is the full
/// category color.
const double kTimelinePlannedAccentAlpha = 0.45;

/// The dashed outline's alpha for [isLight]: a hue at 45% all but vanishes
/// on white, so a light canvas takes it stronger to keep "provisional"
/// visible.
double timelinePlannedOutlineAlpha({required bool isLight}) =>
    isLight ? 0.75 : kTimelinePlannedAccentAlpha;
