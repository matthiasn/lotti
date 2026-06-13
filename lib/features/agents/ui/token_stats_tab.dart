import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/agents/model/daily_token_usage.dart';
import 'package:lotti/features/agents/state/token_stats_providers.dart';
import 'package:lotti/features/agents/ui/token_stats_tab_daily_section.dart';
import 'package:lotti/features/agents/ui/token_stats_tab_per_model_section.dart';
import 'package:lotti/features/agents/ui/wake_activity_chart.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';

/// Stats tab showing token usage in an iOS battery-usage-inspired layout.
///
/// Sections:
/// 1. Wake activity chart (migrated from pending wakes)
/// 2. Summary comparison card with interactive 7-day chart
/// 3. Per-model charts
/// 4. Per-template source breakdown list
class TokenStatsTab extends ConsumerStatefulWidget {
  const TokenStatsTab({super.key});

  @override
  ConsumerState<TokenStatsTab> createState() => _TokenStatsTabState();
}

class _TokenStatsTabState extends ConsumerState<TokenStatsTab> {
  int _days = 7;

  @override
  Widget build(BuildContext context) {
    final dailyAsync = ref.watch(dailyTokenUsageProvider(_days));
    final comparisonAsync = ref.watch(tokenUsageComparisonProvider(_days));
    final breakdownAsync = ref.watch(tokenSourceBreakdownProvider);
    final byModelAsync = ref.watch(dailyTokenUsageByModelProvider(_days));
    final tokens = context.designTokens;

    return ListView(
      padding: EdgeInsets.only(
        bottom: math.max(
          tokens.spacing.step10,
          DesignSystemBottomNavigationBar.occupiedHeight(context),
        ),
      ),
      children: [
        const WakeActivityChart(),
        SizedBox(height: tokens.spacing.step4),
        DailyUsageSection(
          days: _days,
          dailyAsync: dailyAsync,
          comparisonAsync: comparisonAsync,
          onDaysChanged: (days) => setState(() => _days = days),
        ),
        SizedBox(height: tokens.spacing.step6),
        PerModelChartsSection(byModelAsync: byModelAsync),
        SizedBox(height: tokens.spacing.step6),
        _SourceBreakdownSection(breakdownAsync: breakdownAsync),
      ],
    );
  }
}

// ── Daily Usage Section ─────────────────────────────────────────────────────

class _SourceBreakdownSection extends StatelessWidget {
  const _SourceBreakdownSection({required this.breakdownAsync});

  final AsyncValue<List<TokenSourceBreakdown>> breakdownAsync;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final breakdowns = breakdownAsync.value;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.messages.agentStatsSourceActivityHeading,
            style: context.textTheme.titleSmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: tokens.spacing.step3),
          if (breakdowns == null)
            const SizedBox(height: 40)
          else if (breakdowns.isEmpty)
            Text(
              context.messages.agentStatsNoUsage,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            )
          else
            for (final source in breakdowns) _SourceListTile(source: source),
        ],
      ),
    );
  }
}

class _SourceListTile extends StatelessWidget {
  const _SourceListTile({required this.source});

  final TokenSourceBreakdown source;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final warningColor = tokens.colors.alert.warning.defaultColor;

    return InkWell(
      onTap: () => beamToNamed(
        '/settings/agents/${source.isTemplate ? 'templates' : 'instances'}/${source.templateId}',
      ),
      borderRadius: BorderRadius.circular(tokens.radii.m),
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: tokens.spacing.step3,
          horizontal: tokens.spacing.step2,
        ),
        child: Row(
          children: [
            Container(
              width: tokens.spacing.step9,
              height: tokens.spacing.step9,
              decoration: BoxDecoration(
                color: context.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(tokens.radii.s),
              ),
              child: Icon(
                Icons.smart_toy_outlined,
                color: context.colorScheme.onPrimaryContainer,
                size: tokens.spacing.step6,
              ),
            ),
            SizedBox(width: tokens.spacing.step3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    source.displayName,
                    style: context.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: tokens.spacing.step1),
                  Text(
                    _activityDescription(context, source),
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (source.isHighUsage)
              Padding(
                padding: EdgeInsets.only(right: tokens.spacing.step2),
                child: Icon(
                  Icons.error_rounded,
                  color: warningColor,
                  size: tokens.spacing.step5,
                ),
              ),
            Text(
              '${source.percentage.round()} %',
              style: context.textTheme.bodyMedium?.copyWith(
                color: source.isHighUsage
                    ? warningColor
                    : context.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            SizedBox(width: tokens.spacing.step2),
            Icon(
              Icons.chevron_right,
              color: context.colorScheme.onSurfaceVariant,
              size: tokens.spacing.step5,
            ),
          ],
        ),
      ),
    );
  }

  String _activityDescription(
    BuildContext context,
    TokenSourceBreakdown source,
  ) {
    final parts = <String>[];
    if (source.totalDuration > Duration.zero) {
      parts.add(
        context.messages.agentStatsSourceActiveFor(
          _formatDuration(source.totalDuration),
        ),
      );
    }
    parts.add(context.messages.agentStatsSourceWakes(source.wakeCount));
    return parts.join(' \u00b7 ');
  }
}

// ── Dashed Line Painter ─────────────────────────────────────────────────────

/// Paints a dashed horizontal line at [fraction] of the canvas height
/// (measured from the bottom), directly on the canvas with no layout overhead.
class AverageDashedLinePainter extends CustomPainter {
  AverageDashedLinePainter({
    required this.fraction,
    required this.color,
  });

  final double fraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    const dashWidth = 4.0;
    const dashSpace = 3.0;
    final y = size.height * (1 - fraction);
    var startX = 0.0;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, y),
        Offset(math.min(startX + dashWidth, size.width), y),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(AverageDashedLinePainter oldDelegate) =>
      fraction != oldDelegate.fraction || color != oldDelegate.color;
}

// ── Helpers ─────────────────────────────────────────────────────────────────

String currentTimeString() {
  final now = clock.now().toLocal();
  return '${now.hour.toString().padLeft(2, '0')}:'
      '${now.minute.toString().padLeft(2, '0')}';
}

final NumberFormat _compactFormat = NumberFormat.compact();

String formatTokenCount(int tokens) => _compactFormat.format(tokens);

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours > 0) {
    return '${hours}h ${minutes}m';
  }
  return '${minutes}m';
}
