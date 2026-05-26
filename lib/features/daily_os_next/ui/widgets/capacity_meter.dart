import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Linear capacity meter for the day's planned load.
///
/// Color flips with pressure:
/// - `< 90%` -> teal (comfortable)
/// - `90-100%` -> warning amber (near full)
/// - `> 100%` -> error red, clamped to a full bar.
class CapacityMeter extends StatelessWidget {
  const CapacityMeter({
    required this.scheduledMinutes,
    required this.capacityMinutes,
    super.key,
  });

  final int scheduledMinutes;
  final int capacityMinutes;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ratio = capacityMinutes <= 0
        ? 0.0
        : scheduledMinutes / capacityMinutes;
    final progress = ratio.clamp(0.0, 1.0);
    final color = ratio < 0.9
        ? tokens.colors.interactive.enabled
        : ratio <= 1.0
        ? tokens.colors.alert.warning.defaultColor
        : tokens.colors.alert.error.defaultColor;

    return Semantics(
      label: context.messages.dailyOsNextAgendaSummary(
        _formatHours(scheduledMinutes),
        _formatHours(capacityMinutes),
      ),
      value: '${(progress * 100).round()}%',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(tokens.radii.xs),
        child: SizedBox(
          height: tokens.spacing.step2,
          child: LinearProgressIndicator(
            value: progress,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            backgroundColor: tokens.colors.background.level03,
          ),
        ),
      ),
    );
  }

  String _formatHours(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }
}
