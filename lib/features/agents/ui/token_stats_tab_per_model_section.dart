import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/daily_token_usage.dart';
import 'package:lotti/features/agents/ui/agent_token_usage_section.dart';
import 'package:lotti/features/agents/ui/token_stats_tab.dart';
import 'package:lotti/features/agents/ui/token_stats_tab_chart.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/ds_surface_elevation.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

/// One demoted card per model: name, period total, and a compact echo of
/// the hero chart. Hidden entirely when only one model is in play — the
/// hero already tells that story.
///
/// The cards share the tab's day selection: they highlight the same day
/// the hero chart has selected and show that day's breakdown for their
/// model, so a tap anywhere refocuses the whole page rather than each
/// card keeping a private, contradictory selection.
class PerModelChartsSection extends StatelessWidget {
  const PerModelChartsSection({
    required this.byModelAsync,
    required this.days,
    required this.selectedIndex,
    required this.onDayTap,
    this.todayIsAboveAverage = false,
    super.key,
  });

  final AsyncValue<Map<String, List<DailyTokenUsage>>> byModelAsync;

  /// The page's selected day range, named in the heading so the section
  /// visibly rides the same 7D/30D toggle as the hero.
  final int days;
  final int? selectedIndex;

  /// Reports the tapped day's calendar date, resolved from the tapped
  /// card's own list — never by index identity against the hero's list,
  /// which may cover a different window length.
  final ValueChanged<DateTime> onDayTap;

  /// The hero's accent flag, forwarded to every compact chart so today's
  /// bar resolves through the same `todayAccentColor` expression on every
  /// card — amber above average, teal otherwise, never both at once.
  final bool todayIsAboveAverage;

  @override
  Widget build(BuildContext context) {
    final byModel = byModelAsync.value;
    if (byModel == null || byModel.length <= 1) {
      return const SizedBox.shrink();
    }

    final tokens = context.designTokens;
    final entries = byModel.entries.toList();
    // Denominator for the cards' cross-model length encoding: the
    // selected day's total across every model.
    final selectedDayTotal = selectedIndex == null
        ? 0
        : entries.fold<int>(
            0,
            (sum, e) => selectedIndex! < e.value.length
                ? sum + e.value[selectedIndex!].totalTokens
                : sum,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The scope caption says this section rides the 7D/30D toggle.
        StatsSectionHeading(
          title: context.messages.agentStatsByModelHeading,
          caption: context.messages.agentStatsLastNDays(days),
        ),
        SizedBox(height: tokens.spacing.step3),
        for (final (index, entry) in entries.indexed) ...[
          if (index > 0) SizedBox(height: tokens.spacing.cardItemSpacing),
          _ModelChartCard(
            modelId: entry.key,
            days: entry.value,
            selectedIndex: selectedIndex,
            selectedDayTotalAcrossModels: selectedDayTotal,
            todayIsAboveAverage: todayIsAboveAverage,
            onDayTap: onDayTap,
          ),
        ],
      ],
    );
  }
}

class _ModelChartCard extends StatelessWidget {
  const _ModelChartCard({
    required this.modelId,
    required this.days,
    required this.selectedIndex,
    required this.selectedDayTotalAcrossModels,
    required this.todayIsAboveAverage,
    required this.onDayTap,
  });

  final String modelId;
  final List<DailyTokenUsage> days;
  final int? selectedIndex;
  final int selectedDayTotalAcrossModels;
  final bool todayIsAboveAverage;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final totalTokens = days.fold<int>(0, (s, d) => s + d.totalTokens);
    final shortName = shortModelName(modelId);

    return Container(
      decoration: BoxDecoration(
        color: dsCardSurface(context),
        borderRadius: BorderRadius.circular(tokens.radii.sectionCards),
      ),
      padding: EdgeInsets.all(tokens.spacing.cardPadding),
      // One content width per card: header, chart, and day echo all end
      // on the same rail instead of stranding the trailing total across
      // a dead desktop gutter.
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: chartContentMaxWidth(
              context,
              columnCount: days.length,
              compact: true,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      shortName,
                      style: tokens.typography.styles.subtitle.subtitle2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // The trailing total names its own window: this card
                  // also shows a selected-day figure below, and two
                  // unlabeled numbers three lines apart must never leave
                  // the reader to guess which is which.
                  Flexible(
                    child: Text(
                      '${formatTokenCount(totalTokens)} '
                      '${context.messages.agentStatsTokensUnit}'
                      ' · ${context.messages.agentStatsLastNDays(days.length)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: tokens.typography.styles.body.bodySmall.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: tokens.spacing.step3),
              InteractiveWeeklyChart(
                days: days,
                selectedIndex: selectedIndex,
                todayIsAboveAverage: todayIsAboveAverage,
                onBarTap: (i) => onDayTap(days[i].date),
                compact: true,
              ),
              if (selectedIndex != null && selectedIndex! < days.length)
                Padding(
                  padding: EdgeInsets.only(top: tokens.spacing.step4),
                  // Compact echo: breakdown bars only. The hero names the
                  // selected day; repeating its header and wake metrics per
                  // model would scale page height with model count.
                  child: SelectedDayDetail(
                    day: days[selectedIndex!],
                    compact: true,
                    // Width says the ranking: this model's slice of the day.
                    shareOfTotal: selectedDayTotalAcrossModels > 0
                        ? days[selectedIndex!].totalTokens /
                              selectedDayTotalAcrossModels
                        : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
