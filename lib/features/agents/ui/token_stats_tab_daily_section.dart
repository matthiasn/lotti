import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/daily_token_usage.dart';
import 'package:lotti/features/agents/ui/token_stats_tab.dart';
import 'package:lotti/features/agents/ui/token_stats_tab_chart.dart';
import 'package:lotti/features/design_system/components/buttons/ds_segmented_toggle.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/ds_surface_elevation.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';

/// The Daily Usage hero: section heading with the period total as the
/// page's focal number, a 7D/30D range toggle, and the card holding the
/// comparison sentence, the Average/Today stat pair, the interactive
/// chart, and the selected day's detail rows.
///
/// Day selection is owned by the stats tab (shared with the per-model
/// cards) and arrives via [selectedIndex] / [onBarTap], so picking a day
/// here focuses the whole page on it.
class DailyUsageSection extends StatelessWidget {
  const DailyUsageSection({
    required this.days,
    required this.dailyAsync,
    required this.comparisonAsync,
    required this.onDaysChanged,
    required this.selectedIndex,
    required this.onBarTap,
    required this.onResetToToday,
    this.highUsageSource,
    super.key,
  });

  final int days;
  final AsyncValue<List<DailyTokenUsage>> dailyAsync;
  final AsyncValue<TokenUsageComparison> comparisonAsync;
  final ValueChanged<int> onDaysChanged;
  final int? selectedIndex;
  final ValueChanged<int> onBarTap;

  /// Snaps the page-wide selection back to today — the return leg of the
  /// explore loop, surfaced in the selected-day header when a past day is
  /// focused.
  final VoidCallback onResetToToday;

  /// A source running unusually hot today, if any — surfaced as an amber
  /// notice chip right under the hero sentence so the page's one real
  /// warning is visible before any scrolling, and tappable straight
  /// through to the named agent.
  final TokenSourceBreakdown? highUsageSource;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final daysList = dailyAsync.value;
    final comparison = comparisonAsync.value;
    final isAboveAverage = comparison?.isAboveAverage ?? false;
    final periodTotal =
        daysList?.fold<int>(0, (s, d) => s + d.totalTokens) ?? 0;
    final periodWakes = daysList?.fold<int>(0, (s, d) => s + d.wakeCount) ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StatsSectionHeading(
          title: context.messages.agentStatsDailyUsageHeading,
          trailing: DsSegmentedToggle<int>(
            segments: [
              for (final option in const [7, 30])
                DsSegment(
                  option,
                  context.messages.agentStatsDayRangeLabel(option),
                ),
            ],
            selected: days,
            onChanged: onDaysChanged,
          ),
        ),
        // The page's focal number: what the period cost, in one glance.
        if (periodTotal > 0)
          Padding(
            padding: EdgeInsets.only(top: tokens.spacing.step1),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  formatTokenCount(periodTotal),
                  style: tokens.typography.styles.heading.heading2.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                SizedBox(width: tokens.spacing.step2),
                // Scope the focal number: 134K reads as "today" without
                // the range spelled out beside it.
                Flexible(
                  child: Text(
                    '${context.messages.agentStatsTokensUnit}'
                    ' · ${context.messages.agentStatsLastNDays(days)}'
                    '${periodWakes > 0 ? ' · ${context.messages.agentStatsSourceWakes(periodWakes)}' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.typography.styles.body.bodySmall.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        SizedBox(height: tokens.spacing.step3),

        // Card.
        Container(
          decoration: BoxDecoration(
            color: dsCardSurface(context),
            borderRadius: BorderRadius.circular(tokens.radii.sectionCards),
          ),
          padding: EdgeInsets.all(tokens.spacing.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ComparisonSummary(
                comparisonAsync: comparisonAsync,
                highUsageSource: highUsageSource,
              ),
              _ComparisonMetrics(comparisonAsync: comparisonAsync),
              SizedBox(height: tokens.spacing.step5),
              InteractiveWeeklyChart(
                days: daysList,
                selectedIndex: selectedIndex,
                todayIsAboveAverage: isAboveAverage,
                onBarTap: onBarTap,
              ),
              // Detail rows for the selected day.
              if (selectedIndex != null &&
                  daysList != null &&
                  selectedIndex! < daysList.length)
                Padding(
                  padding: EdgeInsets.only(top: tokens.spacing.step4),
                  // No inner width cap: the tab's section rail already
                  // sizes the card to the chart's content width, so the
                  // detail block ends on the same edge by construction.
                  child: SelectedDayDetail(
                    day: daysList[selectedIndex!],
                    onResetToToday: onResetToToday,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Comparison Summary ──────────────────────────────────────────────────────

class _ComparisonSummary extends StatelessWidget {
  const _ComparisonSummary({
    required this.comparisonAsync,
    this.highUsageSource,
  });

  final AsyncValue<TokenUsageComparison> comparisonAsync;

  /// A source running unusually hot today, if any — rendered as a notice
  /// chip under the sentence so the anomaly leads the page instead of
  /// hiding below the fold in the source list.
  final TokenSourceBreakdown? highUsageSource;

  /// The anomaly notice chip, shown whenever a source runs hot today —
  /// independent of the sentence, so an at-average day cannot hide it.
  /// Dot + caption, the same grammar as the source row's own marker: the
  /// sentence keeps the hero's one full-voice amber, and this reads as
  /// its qualifier even when both fire. Tapping routes to the named
  /// agent — the notice names an action, so it offers one.
  Widget? _notice(BuildContext context) {
    final source = highUsageSource;
    if (source == null) return null;
    final tokens = context.designTokens;
    return Padding(
      padding: EdgeInsets.only(bottom: tokens.spacing.step5),
      child: InkWell(
        onTap: () => beamToNamed(
          '/settings/agents/${source.isTemplate ? 'templates' : 'instances'}/${source.templateId}',
        ),
        borderRadius: BorderRadius.circular(tokens.radii.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: tokens.spacing.step2,
              height: tokens.spacing.step2,
              decoration: BoxDecoration(
                color: warningTextColor(context),
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: tokens.spacing.step2),
            Flexible(
              child: Text(
                context.messages.agentStatsHeroHighUsage(source.displayName),
                style: tokens.typography.styles.others.caption.copyWith(
                  color: warningTextColor(context),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final comparison = comparisonAsync.value;
    final tokens = context.designTokens;
    if (comparison == null || !comparison.hasBaseline) {
      // Reserve the sentence's real height while loading (or when there
      // is no baseline): both possible messages render invisibly and the
      // taller sizes the box, so the reserve matches the resolved text
      // even when a long translation wraps at narrow widths. The notice
      // still renders — a hot source must warn even before the page has
      // a baseline to compare against.
      final timeStr = currentTimeString();
      final style = tokens.typography.styles.body.bodyMedium;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: tokens.spacing.step5),
            child: ExcludeSemantics(
              child: Opacity(
                opacity: 0,
                child: Stack(
                  children: [
                    Text(
                      context.messages.agentStatsUsageAboveAverage(timeStr),
                      style: style,
                    ),
                    Text(
                      context.messages.agentStatsUsageBelowAverage(timeStr),
                      style: style,
                    ),
                  ],
                ),
              ),
            ),
          ),
          ?_notice(context),
        ],
      );
    }

    final notice = _notice(context);

    // Exactly at average: no sentence, and no stray gap either — the gap
    // below belongs to the sentence and disappears with it. The notice
    // stands alone if present.
    if (comparison.isAtAverage) return notice ?? const SizedBox.shrink();

    final timeStr = currentTimeString();
    final message = comparison.isAboveAverage
        ? context.messages.agentStatsUsageAboveAverage(timeStr)
        : context.messages.agentStatsUsageBelowAverage(timeStr);

    final sentence = Padding(
      // Two facts, two breaths: the sentence-to-notice gap stays a real
      // step so the pair cannot clot into one amber paragraph.
      padding: EdgeInsets.only(
        bottom: notice == null ? tokens.spacing.step5 : tokens.spacing.step3,
      ),
      child: Text(
        message,
        // The judgment escalates where the eye lands first: the sentence
        // itself carries the warning colour while today runs hot, through
        // the same expression as every other amber text.
        style: tokens.typography.styles.body.bodyMedium.copyWith(
          color: comparison.isAboveAverage ? warningTextColor(context) : null,
        ),
      ),
    );

    if (notice == null) return sentence;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [sentence, notice],
    );
  }
}

// ── Average vs Today Metrics ────────────────────────────────────────────────

class _ComparisonMetrics extends StatelessWidget {
  const _ComparisonMetrics({required this.comparisonAsync});

  final AsyncValue<TokenUsageComparison> comparisonAsync;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final comparison = comparisonAsync.value;
    if (comparison == null) {
      // Label line + value line at their real styles, so the resolved
      // stat pair swaps in without moving the chart below.
      return ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(' ', style: tokens.typography.styles.subtitle.subtitle2),
            SizedBox(height: tokens.spacing.step1),
            Text(' ', style: tokens.typography.styles.subtitle.subtitle1),
          ],
        ),
      );
    }

    return Row(
      children: [
        _MetricColumn(
          label: context.messages.agentStatsAverageLabel,
          value: formatTokenCount(comparison.averageTokensByTimeOfDay),
          unit: context.messages.agentStatsTokensUnit,
          valueColor: context.colorScheme.onSurfaceVariant,
        ),
        SizedBox(width: tokens.spacing.step7),
        _MetricColumn(
          label: context.messages.agentStatsTodayLabel,
          value: formatTokenCount(comparison.todayTokens),
          unit: context.messages.agentStatsTokensUnit,
          // Same expression as today's chart bar, so the two can never
          // disagree about whether today is running hot. `forText` swaps
          // in the darker amber step in light mode, where the bar-fill
          // amber is too faint for small text.
          valueColor: todayAccentColor(
            context,
            aboveAverage: comparison.isAboveAverage,
            forText: true,
          ),
        ),
      ],
    );
  }
}

class _MetricColumn extends StatelessWidget {
  const _MetricColumn({
    required this.label,
    required this.value,
    required this.unit,
    required this.valueColor,
  });

  final String label;
  final String value;
  final String unit;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Labels stay neutral — the VALUE alone carries the state colour,
        // so 'Average' and 'Today' read as one label tier.
        Text(
          label,
          style: tokens.typography.styles.subtitle.subtitle2.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: tokens.spacing.step1),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: tokens.typography.styles.subtitle.subtitle1.copyWith(
                color: valueColor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            SizedBox(width: tokens.spacing.step2),
            // The unit stays neutral like the label: only the numeral
            // carries the state colour, so the amber moment is one word
            // wide, not a whole phrase.
            Text(
              unit,
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
