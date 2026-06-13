import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Percent change from [previous] to [current], rounded. Null when there is
/// no previous baseline to divide by (`previous == 0`).
int? insightsDeltaPercent(int current, int previous) {
  if (previous == 0) return null;
  return ((current - previous) / previous * 100).round();
}

/// Calm current-vs-previous change indicator: the percent change in a quiet
/// accent — teal-ish up, clay-ish down (semantic success/warning tokens),
/// never loud red/green. The leading sign conveys direction without an
/// arrow, so it stays compact in a table cell. Renders nothing when both
/// values are zero.
class InsightsDeltaChip extends StatelessWidget {
  const InsightsDeltaChip({
    required this.current,
    required this.previous,
    super.key,
  });

  final int current;
  final int previous;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    if (current == 0 && previous == 0) return const SizedBox.shrink();

    final up = tokens.colors.alert.success.defaultColor;
    final down = tokens.colors.alert.warning.defaultColor;
    final flat = tokens.colors.text.mediumEmphasis;
    final pct = insightsDeltaPercent(current, previous);

    final String text;
    final Color color;
    if (pct == null) {
      // No previous time, but the current period has some → brand new.
      text = messages.insightsDeltaNew;
      color = up;
    } else if (pct > 0) {
      text = '+$pct%';
      color = up;
    } else if (pct < 0) {
      text = '$pct%'; // already carries the minus sign
      color = down;
    } else {
      text = '0%';
      color = flat;
    }

    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: monoMetaStyle(
        tokens,
        tokens.colors,
        base: tokens.typography.styles.others.caption,
        color: color,
      ),
    );
  }
}
