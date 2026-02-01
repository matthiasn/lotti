import 'package:flutter/material.dart';
import 'package:lotti/features/daily_os/state/time_budget_progress_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/themes/theme.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

/// Status indicator showing budget health.
class StatusIndicator extends StatelessWidget {
  const StatusIndicator({
    required this.stats,
    super.key,
  });

  final DayBudgetStats stats;

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = _getStatusDetails(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMedium,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: context.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  (IconData, Color, String) _getStatusDetails(BuildContext context) {
    if (stats.isOverBudget) {
      return (
        MdiIcons.alertCircle,
        context.colorScheme.error,
        context.messages.dailyOsOverBudget,
      );
    }

    final remaining = stats.totalRemaining;
    if (remaining.inMinutes <= 15 && remaining.inMinutes > 0) {
      return (
        MdiIcons.clockAlert,
        syncPendingAccentColor,
        context.messages.dailyOsNearLimit,
      );
    }

    if (stats.progressFraction >= 0.8) {
      return (
        MdiIcons.checkCircle,
        successColor,
        context.messages.dailyOsOnTrack,
      );
    }

    return (
      MdiIcons.clockOutline,
      context.colorScheme.onSurfaceVariant,
      context.messages
          .dailyOsTimeLeft(_formatDuration(context, stats.totalRemaining)),
    );
  }

  String _formatDuration(BuildContext context, Duration duration) {
    if (duration.inHours > 0) {
      final hours = duration.inHours;
      final mins = duration.inMinutes % 60;
      if (mins == 0) return context.messages.dailyOsDurationHours(hours);
      return context.messages.dailyOsDurationHoursMinutes(hours, mins);
    }
    return context.messages.dailyOsDurationMinutes(duration.inMinutes);
  }
}
