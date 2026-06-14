import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/state/categories_list_controller.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/features/insights/logic/period_navigation.dart';
import 'package:lotti/features/insights/logic/range_presets.dart';
import 'package:lotti/features/insights/logic/time_bucketing.dart';
import 'package:lotti/features/insights/model/insights_models.dart';
import 'package:lotti/features/insights/state/insights_preferences_controller.dart';
import 'package:lotti/features/insights/state/insights_providers.dart';
import 'package:lotti/features/insights/ui/widgets/insights_category_resolver.dart';
import 'package:lotti/features/insights/ui/widgets/insights_chart_card.dart';
import 'package:lotti/features/insights/ui/widgets/insights_kpi_row.dart';
import 'package:lotti/features/insights/ui/widgets/insights_period_picker.dart';
import 'package:lotti/features/insights/ui/widgets/insights_period_stepper.dart';
import 'package:lotti/features/insights/ui/widgets/insights_pill_button.dart';
import 'package:lotti/features/insights/ui/widgets/insights_surfaces.dart';
import 'package:lotti/features/insights/ui/widgets/insights_table.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Desktop time-analysis dashboard under the Insights tab.
///
/// The page is the single provider consumer: it watches the bucket window,
/// range, preferences, and categories, derives chart/table/KPI values via
/// the pure logic functions (~1-3ms per build at 10k-50k entries, measured
/// — well within a frame),
/// and passes plain values to dumb child widgets.
/// **keepPreviousData.** [insightsBucketsProvider] is an `autoDispose.family`
/// keyed by calendar year ([insightsWindowFor]). Stepping between periods of
/// the *same* year reuses one cached bucket set — no fetch, no loading. But
/// stepping across a year boundary (every step at year granularity; Jan↔Dec
/// for months; the odd week or quarter) is a *new* family instance that starts
/// at `AsyncLoading` with no value — and `skipLoadingOnReload` cannot bridge
/// it, since it only retains a value *within* one instance. Left alone, that
/// flashes a spinner over the whole dashboard on every year-crossing step. So
/// the last fully-loaded generation is retained by the state and kept on
/// screen until the new window resolves, while the header/stepper always tracks
/// the live selection for instant feedback — the Riverpod equivalent of
/// `keepPreviousData: true`.
class TimeAnalysisPage extends ConsumerStatefulWidget {
  const TimeAnalysisPage({super.key});

  @override
  ConsumerState<TimeAnalysisPage> createState() => _TimeAnalysisPageState();
}

class _TimeAnalysisPageState extends ConsumerState<TimeAnalysisPage> {
  /// The most recent generation whose buckets had fully loaded. Retained across
  /// builds so a year-boundary window switch keeps rendering it until the new
  /// buckets arrive, instead of blanking to a spinner. Null only before the
  /// very first load resolves (or until a cold cache fills on return).
  _DashboardData? _lastData;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;

    final selection = ref.watch(insightsRangeControllerProvider);
    final controller = ref.read(insightsRangeControllerProvider.notifier);
    final bucketsAsync = ref.watch(
      insightsBucketsProvider(insightsWindowFor(selection.range)),
    );
    // Previous-period buckets drive the comparison deltas. The range comes
    // from the controller so it uses the same region-aligned first weekday as
    // the current range (deriving it here with the Monday default misaligned
    // the comparison week for Sunday/Saturday-first regions). `.value`
    // (valueOrNull) so a still-loading previous window never blanks or blocks
    // the established dashboard.
    final previousRange = controller.previousComparisonRange;
    final previousBuckets = previousRange == null
        ? null
        : ref
              .watch(insightsBucketsProvider(insightsWindowFor(previousRange)))
              .value;

    // Capture the freshest fully-loaded generation, pairing the buckets with
    // the exact selection they cover. `.value` is non-null both for a settled
    // AsyncData and for a same-instance reload (Riverpod retains the prior
    // value), so within a year this simply tracks the current data; across a
    // year it stops updating while the new window loads, freezing [_lastData]
    // on the previous period. Assigning a field in build() is safe here: it
    // feeds only this build and the next, and never itself schedules a rebuild.
    final buckets = bucketsAsync.value;
    if (buckets != null) {
      _lastData = _DashboardData(
        selection: selection,
        buckets: buckets,
        previousRange: previousRange,
        previousBuckets: previousBuckets,
      );
    }
    final data = _lastData;

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
      // Darker page canvas with the cards a step lighter on it — conventional
      // elevation in both themes (see insights_surfaces.dart; the DS ramp
      // inverts between light and dark, so page/card swap by brightness).
      backgroundColor: insightsPageSurface(context),
      body: SafeArea(
        // First paint only: no generation has loaded yet, so a loading shell
        // (or the error message if that very first fetch failed) is all there
        // is to show. Once any generation has rendered, a loading new window or
        // a transient error keeps the last one on screen rather than blanking.
        child: data == null
            ? (bucketsAsync.hasError
                  ? Center(
                      child: Text(
                        messages.insightsLoadError,
                        style: tokens.typography.styles.body.bodySmall.copyWith(
                          color: tokens.colors.text.lowEmphasis,
                        ),
                      ),
                    )
                  : const Center(child: CircularProgressIndicator()))
            : _DashboardContent(
                selection: selection,
                data: data,
                resolver: resolver,
                categories: categories,
                focusCategoryIds: preferences.focusCategoryIds,
                onSelectUnit: controller.selectUnit,
                onStep: controller.step,
                onSelectToDate: controller.selectToDate,
                onOpenCalendar: () =>
                    showInsightsPeriodPicker(context: context),
                onToggleCompare: controller.toggleCompare,
                onToggleFocusCategory: ref
                    .read(insightsPreferencesControllerProvider.notifier)
                    .toggleFocusCategory,
              ),
      ),
    );
  }
}

/// A fully-resolved dashboard generation: a bucket set paired with the exact
/// [selection] (and comparison window) it was computed for. Buckets are
/// year-windowed, so the range they cover and the buckets must always travel
/// together — rendering one period's buckets against another period's range
/// would zero-fill the dashboard. Retained by [_TimeAnalysisPageState] for
/// keepPreviousData across year-boundary loads.
@immutable
class _DashboardData {
  const _DashboardData({
    required this.selection,
    required this.buckets,
    required this.previousRange,
    required this.previousBuckets,
  });

  final InsightsPeriodSelection selection;
  final InsightsDayBuckets buckets;

  /// Comparison window + its buckets when compare is on (else null). The
  /// buckets can be null even here if the comparison window had not finished
  /// loading when this generation was captured; the body simply omits the
  /// comparison columns until a later generation carries them.
  final InsightsRange? previousRange;
  final InsightsDayBuckets? previousBuckets;
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.selection,
    required this.data,
    required this.resolver,
    required this.categories,
    required this.focusCategoryIds,
    required this.onSelectUnit,
    required this.onStep,
    required this.onSelectToDate,
    required this.onOpenCalendar,
    required this.onToggleCompare,
    required this.onToggleFocusCategory,
  });

  /// The live selection — drives the header/stepper only, so a year-boundary
  /// step gets instant feedback even while [data] is still the previous
  /// generation. Every body figure reads [data].selection instead.
  final InsightsPeriodSelection selection;

  /// The generation rendered in the body — possibly the previous period while a
  /// new window loads (keepPreviousData). Its buckets and range are a matched
  /// pair, never mixed across generations.
  final _DashboardData data;

  final InsightsCategoryResolver resolver;
  final List<CategoryDefinition> categories;
  final Set<String> focusCategoryIds;
  final ValueChanged<InsightsPeriodUnit> onSelectUnit;
  final ValueChanged<int> onStep;
  final ValueChanged<InsightsPeriodUnit> onSelectToDate;
  final VoidCallback onOpenCalendar;
  final VoidCallback onToggleCompare;
  final ValueChanged<String> onToggleFocusCategory;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    // Body figures derive from the generation's own selection/buckets — never
    // the live [selection], whose range may point at a year still loading
    // (which would zero-fill every derivation below).
    final bodySelection = data.selection;
    final range = bodySelection.range;
    final buckets = data.buckets;

    // Pure derivations, recomputed per build (~1-3ms at 10k-50k entries,
    // measured — well within a frame). The daily/ranked aggregation is
    // shared across the three builders; it dominates the cost.
    final daily = dailyTotals(buckets, range);
    final ranked = rankedCategoryTotals(daily);
    final chartData = buildChartData(buckets, range, precomputedDaily: daily);
    // Elapsed days of the (possibly in-progress) period — drives both the
    // avg/day denominator and whether avg/day is worth showing at all.
    final elapsedDays = elapsedPortion(range, clock.now()).dayCount;
    final tableRows = buildTableRows(
      buckets,
      range,
      precomputedRanked: ranked,
      // Average over elapsed days for an in-progress period so the daily pace
      // matches the MTD view instead of being diluted by future calendar days.
      avgDayCount: elapsedDays,
    );
    final kpis = buildKpis(
      buckets,
      range,
      focusCategoryIds: focusCategoryIds,
      precomputedRanked: ranked,
    );
    final isEmpty = kpis.totalSeconds == 0;

    // Comparison derivations — only once the previous window has loaded. The
    // comparison is surfaced numerically (KPI deltas + the table's Δ% /
    // Previous columns), never as a second chart series: a previous-period
    // reference bar fights the focal data and reads as a loading/empty bar.
    final compareRange = data.previousRange;
    final prevBuckets = data.previousBuckets;
    InsightsKpis? previousKpis;
    Map<String?, int>? previousByCategory;
    if (compareRange != null && prevBuckets != null) {
      previousKpis = buildKpis(
        prevBuckets,
        compareRange,
        focusCategoryIds: focusCategoryIds,
      );
      previousByCategory = {
        for (final row in buildTableRows(prevBuckets, compareRange))
          row.categoryId: row.seconds,
      };
    }

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
            InsightsPeriodStepper(
              selection: selection,
              onSelectUnit: onSelectUnit,
              onStep: onStep,
              onSelectToDate: onSelectToDate,
              onOpenCalendar: onOpenCalendar,
              onToggleCompare: onToggleCompare,
            ),
          ],
        ),
        SizedBox(height: tokens.spacing.sectionGap),
        if (isEmpty)
          _EmptyState(
            title: messages.insightsEmptyTitle,
            body: messages.insightsEmptyBody,
            // The likeliest intent on a dead current period is "show me the
            // last one" — so it leads as the primary (pill) action.
            actionLabel: messages.insightsEmptyPreviousPeriod,
            onAction: () => onStep(-1),
            // Don't strand the user on a dead period: widening to the whole
            // year (where data is likeliest) is the quieter secondary path,
            // dropped once already viewing the year.
            secondaryActionLabel: bodySelection.unit != InsightsPeriodUnit.year
                ? messages.insightsEmptyShowYear
                : null,
            onSecondaryAction: bodySelection.unit != InsightsPeriodUnit.year
                ? () => onSelectUnit(InsightsPeriodUnit.year)
                : null,
          )
        else ...[
          InsightsKpiRow(
            kpis: kpis,
            previousKpis: previousKpis,
            comparisonInProgress: isInProgress(range, clock.now()),
            categories: categories,
            focusCategoryIds: focusCategoryIds,
            onToggleFocusCategory: onToggleFocusCategory,
            // Largest category (rows are ranked desc) — surfaced under Total so
            // the headline answers "where did my time go". Only when there is
            // something to rank.
            topCategoryLabel: tableRows.length > 1
                ? resolver.labelFor(tableRows.first.categoryId)
                : null,
            topCategoryShare: tableRows.length > 1
                ? tableRows.first.share
                : null,
          ),
          SizedBox(height: tokens.spacing.sectionGap),
          InsightsChartCard(
            chartData: chartData,
            resolver: resolver,
            comparing: previousByCategory != null,
          ),
          SizedBox(height: tokens.spacing.sectionGap),
          InsightsTable(
            rows: tableRows,
            resolver: resolver,
            // avg/day equals the total when only one day has elapsed — noise.
            showAvgPerDay: elapsedDays > 1,
            previousSecondsByCategory: previousByCategory,
            comparisonInProgress: isInProgress(range, clock.now()),
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
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: insightsCardSurface(context),
        borderRadius: BorderRadius.circular(tokens.radii.m),
        border: Border.all(color: tokens.colors.decorative.level01),
      ),
      child: Padding(
        // Calm, content-sized presence — balanced top/bottom so the message
        // reads as centered rather than clustered atop a tall letterbox.
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.step6,
          vertical: tokens.spacing.step9,
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
            if (actionLabel != null || onSecondaryAction != null) ...[
              SizedBox(height: tokens.spacing.step5),
              Wrap(
                spacing: tokens.spacing.step3,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.center,
                children: [
                  // Primary recovery rendered in the page's bordered button
                  // idiom (the same pill chrome as the header) so the empty
                  // state offers a real, button-shaped action — not a bare
                  // text link adrift in the card.
                  if (actionLabel != null)
                    InsightsPillButton(
                      label: actionLabel!,
                      outlined: true,
                      active: false,
                      onTap: onAction,
                    ),
                  // The widen-to-year escape hatch stays a quieter text link,
                  // a clear step down in emphasis from the primary pill.
                  if (onSecondaryAction != null && secondaryActionLabel != null)
                    TextButton(
                      onPressed: onSecondaryAction,
                      child: Text(secondaryActionLabel!),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
