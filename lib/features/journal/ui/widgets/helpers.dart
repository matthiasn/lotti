import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// The shared value-line renderer for entry summaries (health, workout,
/// measurement, habit). Each line is split on its first `": "` into a quiet
/// label and a dominant value, so the number the user came for is the boldest
/// thing on the line — e.g. `Weight: 94.49 kg` renders "Weight" in a quiet
/// secondary caption and "94.49 kg" in a high-emphasis subtitle with tabular
/// figures. Lines without a colon render entirely in the value style. Always
/// left-aligned so values line up under the card's content gutter.
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
    final tokens = context.designTokens;
    final labelStyle = tokens.typography.styles.body.bodySmall.copyWith(
      color: tokens.colors.text.mediumEmphasis,
    );
    final valueStyle = tokens.typography.styles.subtitle.subtitle2.copyWith(
      color: tokens.colors.text.highEmphasis,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    final lines = text.split('\n');
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final line in lines)
            _ValueLine(
              line: line,
              labelStyle: labelStyle,
              valueStyle: valueStyle,
              maxLines: maxLines,
            ),
        ],
      ),
    );
  }
}

class _ValueLine extends StatelessWidget {
  const _ValueLine({
    required this.line,
    required this.labelStyle,
    required this.valueStyle,
    required this.maxLines,
  });

  final String line;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final idx = line.indexOf(': ');
    if (idx < 0) {
      return Text(line, maxLines: maxLines, softWrap: true, style: valueStyle);
    }
    final label = line.substring(0, idx + 1); // keep the colon
    final value = line.substring(idx + 2);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '$label ', style: labelStyle),
          TextSpan(text: value, style: valueStyle),
        ],
      ),
      maxLines: maxLines,
      softWrap: true,
    );
  }
}
