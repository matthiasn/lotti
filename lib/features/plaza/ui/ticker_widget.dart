import 'dart:math' as math;

import 'package:lotti/features/plaza/ui/plaza_style.dart';
import 'package:material_ui/material_ui.dart';

/// One period of an LED ticker band: [text] once, followed by the gap
/// before it comes round again. Captured once; the scene scrolls the
/// texture along the band by its UV offset and repeats it, so the band
/// runs forever without another capture, and the housing's end fade is
/// in the band's own geometry.
///
/// Lay it out at [periodMeters] × [heightMeters] (times the px/m of the
/// capture); the text starts at the left edge and the gap fills the rest.
class TickerWidget extends StatelessWidget {
  const TickerWidget({
    required this.text,
    required this.heightMeters,
    required this.pxPerMeter,
    super.key,
  });

  final String text;
  final double heightMeters;
  final double pxPerMeter;

  /// The type's height as a fraction of the band's.
  static const glyphFraction = 0.62;

  static TextStyle _style(double fontPx) => TextStyle(
    fontFamily: PlazaStyle.fontMono,
    fontSize: fontPx,
    fontWeight: FontWeight.w500,
    color: PlazaStyle.teal,
  );

  /// The width of [text] set for a band [heightMeters] tall, in metres.
  static double textMeters(String text, double heightMeters) {
    // Laid out at a reference size; type scales with its size.
    const referencePx = 100.0;
    final painter = TextPainter(
      text: TextSpan(text: text, style: _style(referencePx)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return painter.width / referencePx * heightMeters * glyphFraction;
  }

  /// One period of the band: the text and a gap of at least four glyph
  /// heights or half of [bandWidthMeters], so a phrase is read whole
  /// before the next one arrives.
  static double periodMeters(
    String text,
    double heightMeters,
    double bandWidthMeters,
  ) {
    final glyph = heightMeters * glyphFraction;
    final gap = math.max(glyph * 4, bandWidthMeters * 0.5);
    return textMeters(text, heightMeters) + gap;
  }

  @override
  Widget build(BuildContext context) {
    final fontPx = heightMeters * pxPerMeter * glyphFraction;
    final border = BorderSide(
      color: PlazaStyle.teal.withValues(alpha: 0.45),
      width: fontPx * 0.08,
    );
    return Material(
      color: const Color(0xFF05070C),
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: border, bottom: border),
        ),
        clipBehavior: Clip.hardEdge,
        alignment: Alignment.centerLeft,
        child: Text(text, maxLines: 1, softWrap: false, style: _style(fontPx)),
      ),
    );
  }
}
