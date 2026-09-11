import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/world_chrome_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// WCAG relative contrast between two opaque colours.
double _contrast(Color a, Color b) {
  final lit = math.max(a.computeLuminance(), b.computeLuminance());
  final dark = math.min(a.computeLuminance(), b.computeLuminance());
  return (lit + 0.05) / (dark + 0.05);
}

void main() {
  // The glyph the glass has to carry. Chrome over a world is pinned dark, so
  // this is the ink both themes would put on it.
  final ink = dsTokensDark.colors.text.highEmphasis;

  test('the glass carries its glyphs over any world it floats on', () {
    // The backdrop is not a known surface — it is a night facade one second
    // and a noon sky the next. Compositing the translucent glass over both
    // extremes is the honest test of whether a glyph survives it.
    for (final backdrop in [Colors.black, Colors.white]) {
      for (final glass in [WorldGlass.fill, WorldGlass.fillHover]) {
        expect(
          _contrast(Color.alphaBlend(glass, backdrop), ink),
          greaterThanOrEqualTo(4.5),
          reason: '$glass over $backdrop must still read as a dark button',
        );
      }
    }
  });

  test('the glass is near-opaque, which is what a moving backdrop needs', () {
    // A still photograph can be read through 45% black; a street sliding past
    // at walking pace cannot, and a panel you can see the world move through
    // reads as a smear rather than a surface. `PhotoNeutralGlass` is the
    // sibling token that makes the other trade.
    for (final glass in [WorldGlass.fill, WorldGlass.fillHover]) {
      expect(
        glass.a,
        greaterThan(0.9),
        reason: '$glass would strobe as the camera walks',
      );
    }
    expect(
      WorldGlass.fillHover.computeLuminance(),
      greaterThan(WorldGlass.fill.computeLuminance()),
      reason: 'the pointer lifts the glass; it does not merely tint it',
    );
  });

  test('the drop is deep enough to separate glass from city', () {
    // `DsShadows.floatingSurface` is tuned for a card over a page. Over an
    // arbitrary view of a city a short grey blur simply disappears, taking
    // the panel's edge with it.
    expect(WorldGlass.drop, hasLength(1));
    final drop = WorldGlass.drop.single;
    expect(drop.blurRadius, greaterThanOrEqualTo(16));
    expect(drop.offset.dy, greaterThan(0), reason: 'lit from above');
    expect(drop.color.a, greaterThan(0.3));
  });
}
