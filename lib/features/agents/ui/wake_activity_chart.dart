import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/hourly_wake_activity.dart';
import 'package:lotti/features/agents/state/agent_pending_wake_providers.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

/// Compact 24-hour bar chart showing wake-run activity per hour.
///
/// Helps diagnose unexpected spikes in agent wake activity by displaying
/// a per-hour breakdown with reason tooltips.
class WakeActivityChart extends ConsumerWidget {
  const WakeActivityChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityAsync = ref.watch(hourlyWakeActivityProvider);
    final buckets = activityAsync.value;

    if (buckets == null || buckets.every((b) => b.count == 0)) {
      return const SizedBox.shrink();
    }

    final tokens = context.designTokens;
    final maxCount = buckets.fold<int>(0, (m, b) => math.max(m, b.count));
    final totalWakes = buckets.fold<int>(0, (sum, b) => sum + b.count);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.step4,
            vertical: tokens.spacing.step2,
          ),
          child: Row(
            children: [
              Icon(
                Icons.bar_chart_rounded,
                size: tokens.typography.size.subtitle1,
                color: context.colorScheme.onSurfaceVariant,
              ),
              SizedBox(width: tokens.spacing.step2),
              Text(
                context.messages.agentPendingWakesActivityTitle,
                style: context.textTheme.titleSmall,
              ),
              const Spacer(),
              Text(
                context.messages.agentPendingWakesActivityTotal(totalWakes),
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 64,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final bucket in buckets)
                  Expanded(
                    child: _HourBar(
                      bucket: bucket,
                      maxCount: maxCount,
                    ),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.step4,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatHour(buckets.first.hour),
                style: context.textTheme.labelSmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                _formatHour(buckets.last.hour),
                style: context.textTheme.labelSmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: tokens.spacing.step2),
      ],
    );
  }

  String _formatHour(DateTime hour) {
    return '${hour.hour.toString().padLeft(2, '0')}:00';
  }
}

class _HourBar extends StatelessWidget {
  const _HourBar({
    required this.bucket,
    required this.maxCount,
  });

  final HourlyWakeActivity bucket;
  final int maxCount;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final fraction = maxCount > 0 ? bucket.count / maxCount : 0.0;

    final tooltipLines = <String>[
      '${_formatHour(bucket.hour)} — ${bucket.count} wakes',
      ...bucket.reasons.entries.map((e) => '  ${e.key}: ${e.value}'),
    ];

    return Tooltip(
      message: tooltipLines.join('\n'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 0.5),
        child: FractionallySizedBox(
          heightFactor: fraction > 0 ? math.max(0.05, fraction) : 0,
          alignment: Alignment.bottomCenter,
          child: Container(
            decoration: BoxDecoration(
              color: _barColor(context, bucket.count),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(tokens.radii.xs),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _barColor(BuildContext context, int count) {
    if (count == 0) return Colors.transparent;
    if (count >= 10) return context.colorScheme.error;
    if (count >= 5) return context.colorScheme.tertiary;
    return context.colorScheme.primary;
  }

  String _formatHour(DateTime hour) {
    return '${hour.hour.toString().padLeft(2, '0')}:00';
  }
}
