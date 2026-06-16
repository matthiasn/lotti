import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';

/// Plain-text label with the app's tabular-figure style, clamped to `maxLines`.
/// Used by the health/workout/measurement summaries to render their formatted
/// value lines.
class EntryTextWidget extends StatelessWidget {
  const EntryTextWidget(
    this.text, {
    super.key,
    this.maxLines = 5,
    this.padding = const EdgeInsets.symmetric(vertical: 8),
  });

  final String text;
  final int maxLines;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(
        text,
        maxLines: maxLines,
        softWrap: true,
        style: tabularFigureStyle(
          fontSize: fontSizeMedium,
          fontWeight: FontWeight.w300,
        ),
      ),
    );
  }
}
