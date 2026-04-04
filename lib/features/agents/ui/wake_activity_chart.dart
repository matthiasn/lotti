import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/hourly_wake_activity.dart';
import 'package:lotti/features/agents/state/agent_pending_wake_providers.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

class WakeActivityChart extends ConsumerStatefulWidget {
  const WakeActivityChart({super.key});

  @override
  ConsumerState<WakeActivityChart> createState() => _WakeActivityChartState();
}

class _WakeActivityChartState extends ConsumerState<WakeActivityChart> {
  int? _selectedIndex;

  static const _chartHeight = 80.0;
  static const _yAxisWidth = 28.0;
  static const _xAxisHeight = 16.0;

  @override
  Widget build(BuildContext context) {
    final activityAsync = ref.watch(hourlyWakeActivityProvider);
    final buckets = activityAsync.value;

    if (buckets == null || buckets.every((b) => b.count == 0)) {
      return const SizedBox.shrink();
    }

    final tokens = context.designTokens;
    final maxCount = buckets.fold<int>(0, (m, b) => math.max(m, b.count));
    final totalWakes = buckets.fold<int>(0, (sum, b) => sum + b.count);
    final selected = _selectedIndex != null ? buckets[_selectedIndex!] : null;
    final axisColor = context.colorScheme.onSurfaceVariant.withValues(
      alpha: 0.4,
    );
    final labelStyle = context.textTheme.labelSmall?.copyWith(
      color: context.colorScheme.onSurfaceVariant,
      fontSize: 10,
    );

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
        Padding(
          padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step4),
          child: SizedBox(
            height: _chartHeight + _xAxisHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: _yAxisWidth,
                  height: _chartHeight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('$maxCount', style: labelStyle),
                      const Spacer(),
                      if (maxCount > 1)
                        Text('${maxCount ~/ 2}', style: labelStyle),
                      if (maxCount > 1) const Spacer(),
                      Text('0', style: labelStyle),
                    ],
                  ),
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: CustomPaint(
                    painter: _AxisPainter(
                      axisColor: axisColor,
                      chartHeight: _chartHeight,
                      maxCount: maxCount,
                    ),
                    child: Column(
                      children: [
                        SizedBox(
                          height: _chartHeight,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              for (var i = 0; i < buckets.length; i++)
                                Expanded(
                                  child: _HourBar(
                                    bucket: buckets[i],
                                    maxCount: maxCount,
                                    isSelected: _selectedIndex == i,
                                    onTap: () => _onBarTap(i),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: _xAxisHeight,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              for (final i in const [0, 6, 12, 18, 23])
                                if (i < buckets.length)
                                  Text(
                                    _fmtHour(buckets[i].hour),
                                    style: labelStyle,
                                  ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (selected != null && selected.count > 0)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacing.step4,
              vertical: tokens.spacing.step1,
            ),
            child: Text(
              context.messages.agentPendingWakesActivityHourDetail(
                _fmtHour(selected.hour),
                selected.count,
                selected.reasons.entries
                    .map((e) => '${e.key}: ${e.value}')
                    .join(', '),
              ),
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        SizedBox(height: tokens.spacing.step2),
      ],
    );
  }

  void _onBarTap(int index) {
    setState(() {
      _selectedIndex = _selectedIndex == index ? null : index;
    });
  }

  static String _fmtHour(DateTime hour) {
    return '${hour.hour.toString().padLeft(2, '0')}:00';
  }
}

class _AxisPainter extends CustomPainter {
  _AxisPainter({
    required this.axisColor,
    required this.chartHeight,
    required this.maxCount,
  });

  final Color axisColor;
  final double chartHeight;
  final int maxCount;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = axisColor
      ..strokeWidth = 1;

    canvas
      ..drawLine(Offset.zero, Offset(0, chartHeight), paint)
      ..drawLine(
        Offset(0, chartHeight),
        Offset(size.width, chartHeight),
        paint,
      );

    if (maxCount > 1) {
      final dashPaint = Paint()
        ..color = axisColor.withValues(alpha: 0.3)
        ..strokeWidth = 0.5;
      final midY = chartHeight / 2;
      canvas.drawLine(Offset(0, midY), Offset(size.width, midY), dashPaint);
    }
  }

  @override
  bool shouldRepaint(_AxisPainter oldDelegate) =>
      axisColor != oldDelegate.axisColor ||
      chartHeight != oldDelegate.chartHeight ||
      maxCount != oldDelegate.maxCount;
}

class _HourBar extends StatelessWidget {
  const _HourBar({
    required this.bucket,
    required this.maxCount,
    required this.isSelected,
    required this.onTap,
  });

  final HourlyWakeActivity bucket;
  final int maxCount;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final fraction = maxCount > 0 ? bucket.count / maxCount : 0.0;
    final color = _barColor(context, bucket.count);
    final hour = '${bucket.hour.hour.toString().padLeft(2, '0')}:00';

    return Semantics(
      button: true,
      label: '$hour: ${bucket.count}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0.5),
          child: FractionallySizedBox(
            heightFactor: fraction > 0 ? math.max(0.06, fraction) : 0,
            alignment: Alignment.bottomCenter,
            child: Container(
              decoration: BoxDecoration(
                color: isSelected ? color : color.withValues(alpha: 0.7),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(tokens.radii.xs),
                ),
                border: isSelected
                    ? Border.all(
                        color: context.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      )
                    : null,
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
}
