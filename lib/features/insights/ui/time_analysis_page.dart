import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/state/categories_list_controller.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/features/insights/logic/range_presets.dart';
import 'package:lotti/features/insights/logic/time_bucketing.dart';
import 'package:lotti/features/insights/model/insights_models.dart';
import 'package:lotti/features/insights/state/insights_preferences_controller.dart';
import 'package:lotti/features/insights/state/insights_providers.dart';
import 'package:lotti/features/insights/ui/widgets/insights_category_resolver.dart';
import 'package:lotti/features/insights/ui/widgets/insights_chart_card.dart';
import 'package:lotti/features/insights/ui/widgets/insights_kpi_row.dart';
import 'package:lotti/features/insights/ui/widgets/insights_range_selector.dart';
import 'package:lotti/features/insights/ui/widgets/insights_table.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Desktop time-analysis dashboard under the Insights tab.
///
/// The page is the single provider consumer: it watches the bucket window,
/// range, preferences, and categories, derives chart/table/KPI values via
/// the pure logic functions (~1-3ms per build at 10k-50k entries, measured
/// — well within a frame),
/// and passes plain values to dumb child widgets.
class TimeAnalysisPage extends ConsumerWidget {
  const TimeAnalysisPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;

    final range = ref.watch(insightsRangeControllerProvider);
    final bucketsAsync = ref.watch(
      insightsBucketsProvider(windowStartDayFor(range)),
    );
    final preferences = ref.watch(insightsPreferencesControllerProvider);
    final categories =
        ref.watch(categoriesStreamProvider).value ??
        const <CategoryDefinition>[];

    final resolver = InsightsCategoryResolver(
      categoriesById: {for (final c in categories) c.id: c},
      uncategorizedLabel: messages.insightsUncategorized,
      otherLabel: messages.insightsOtherCategories,
      deletedLabel: messages.insightsDeletedCategory,
    );

    return Scaffold(
      body: SafeArea(
        child: bucketsAsync.when(
          // Background refreshes and window switches must never blank the
          // established dashboard — loading shells are for first paint only.
          skipLoadingOnReload: true,
          skipLoadingOnRefresh: true,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Text(
              messages.insightsLoadError,
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: tokens.colors.text.lowEmphasis,
              ),
            ),
          ),
          data: (buckets) => _DashboardContent(
            buckets: buckets,
            range: range,
            resolver: resolver,
            categories: categories,
            focusCategoryIds: preferences.focusCategoryIds,
            onPresetSelected: ref
                .read(insightsRangeControllerProvider.notifier)
                .selectPreset,
            onCustomRangeSelected: ref
                .read(insightsRangeControllerProvider.notifier)
                .selectCustom,
            onToggleFocusCategory: ref
                .read(insightsPreferencesControllerProvider.notifier)
                .toggleFocusCategory,
          ),
        ),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.buckets,
    required this.range,
    required this.resolver,
    required this.categories,
    required this.focusCategoryIds,
    required this.onPresetSelected,
    required this.onCustomRangeSelected,
    required this.onToggleFocusCategory,
  });

  final InsightsDayBuckets buckets;
  final InsightsRange range;
  final InsightsCategoryResolver resolver;
  final List<CategoryDefinition> categories;
  final Set<String> focusCategoryIds;
  final ValueChanged<InsightsRangePreset> onPresetSelected;
  final void Function(DateTime start, DateTime end) onCustomRangeSelected;
  final ValueChanged<String> onToggleFocusCategory;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;

    // Pure derivations, recomputed per build (~1-3ms at 10k-50k entries,
    // measured — well within a frame). The daily/ranked aggregation is
    // shared across the three builders; it dominates the cost.
    final daily = dailyTotals(buckets, range);
    final ranked = rankedCategoryTotals(daily);
    final chartData = buildChartData(buckets, range, precomputedDaily: daily);
    final tableRows = buildTableRows(
      buckets,
      range,
      precomputedRanked: ranked,
    );
    final kpis = buildKpis(
      buckets,
      range,
      focusCategoryIds: focusCategoryIds,
      precomputedRanked: ranked,
    );
    final isEmpty = kpis.totalSeconds == 0;

    return ListView(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step6,
        vertical: tokens.spacing.step5,
      ),
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: tokens.spacing.step3,
          children: [
            Text(
              messages.insightsTimeAnalysisTitle,
              style: calmPageTitleStyle(tokens),
            ),
            InsightsRangeSelector(
              range: range,
              onPresetSelected: onPresetSelected,
              onCustomRangeSelected: onCustomRangeSelected,
            ),
          ],
        ),
        SizedBox(height: tokens.spacing.sectionGap),
        if (isEmpty)
          _EmptyState(
            title: messages.insightsEmptyTitle,
            body: messages.insightsEmptyBody,
            // Don't strand the user on a dead range: one click jumps to
            // the widest preset, where data is most likely to exist.
            actionLabel: range.preset != InsightsRangePreset.ytd
                ? messages.insightsEmptyShowYtd
                : null,
            onAction: () => onPresetSelected(InsightsRangePreset.ytd),
          )
        else ...[
          InsightsKpiRow(
            kpis: kpis,
            categories: categories,
            focusCategoryIds: focusCategoryIds,
            onToggleFocusCategory: onToggleFocusCategory,
          ),
          SizedBox(height: tokens.spacing.sectionGap),
          InsightsChartCard(chartData: chartData, resolver: resolver),
          SizedBox(height: tokens.spacing.sectionGap),
          InsightsTable(
            rows: tableRows,
            resolver: resolver,
            // avg/day equals the total on a single-day range — noise.
            showAvgPerDay: range.dayCount > 1,
          ),
        ],
        SizedBox(height: tokens.spacing.step6),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.body,
    required this.onAction,
    this.actionLabel,
  });

  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        borderRadius: BorderRadius.circular(tokens.radii.m),
        border: Border.all(color: tokens.colors.decorative.level01),
      ),
      child: Padding(
        // Generous vertical presence so the page doesn't read as a
        // truncated letterbox; slightly more below than above anchors the
        // content block just above center, which reads as intentional.
        padding: EdgeInsets.fromLTRB(
          tokens.spacing.step6,
          tokens.spacing.step12,
          tokens.spacing.step6,
          tokens.spacing.step13,
        ),
        child: Column(
          children: [
            Icon(
              Icons.hourglass_empty_rounded,
              size: tokens.spacing.step9,
              color: tokens.colors.text.lowEmphasis,
            ),
            SizedBox(height: tokens.spacing.step5),
            Text(
              title,
              style: tokens.typography.styles.body.bodyMedium.copyWith(
                color: tokens.colors.text.highEmphasis,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: tokens.spacing.step2),
            Text(
              body,
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: tokens.colors.text.lowEmphasis,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null) ...[
              SizedBox(height: tokens.spacing.step5),
              TextButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
