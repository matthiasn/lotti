import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/themes/theme.dart';

/// A compact "this spans a stretch of time" readout: the start and end times
/// flanking a filled track, with the elapsed duration called out at the end.
///
/// Used to make a *time recording* (an entry whose `dateTo` is after its
/// `dateFrom`) read as an interval rather than a point-in-time note — e.g. a
/// 2.5-hour entry on an event shows `13:00 ──── 15:30   2h 30m` instead of just
/// its text. All three labels are pre-formatted by the caller so this stays
/// pure and locale-agnostic.
class TimeSpanBar extends StatelessWidget {
  const TimeSpanBar({
    required this.startLabel,
    required this.endLabel,
    required this.durationLabel,
    super.key,
  });

  /// Pre-formatted start time, e.g. `13:00`.
  final String startLabel;

  /// Pre-formatted end time, e.g. `15:30`.
  final String endLabel;

  /// Pre-formatted elapsed duration, e.g. `2h 30m`.
  final String durationLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final cs = context.colorScheme;
    final styles = tokens.typography.styles;
    final endpointStyle = styles.body.bodySmall.copyWith(
      color: cs.onSurfaceVariant,
    );

    return Row(
      children: [
        Icon(Icons.schedule_rounded, size: 15, color: cs.primary),
        SizedBox(width: tokens.spacing.step2),
        Text(startLabel, style: endpointStyle),
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step2),
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
              ),
            ),
          ),
        ),
        Text(endLabel, style: endpointStyle),
        SizedBox(width: tokens.spacing.step3),
        Text(
          durationLabel,
          style: styles.body.bodySmall.copyWith(
            color: cs.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
