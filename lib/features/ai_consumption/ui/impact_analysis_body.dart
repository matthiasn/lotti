import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/ai_consumption/logic/impact_dashboard_data.dart';
import 'package:lotti/features/ai_consumption/model/consumption_aggregation_models.dart';
import 'package:lotti/features/ai_consumption/model/impact_dashboard_models.dart';
import 'package:lotti/features/ai_consumption/state/consumption_providers.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/impact_call_ledger.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/impact_chart_card.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/impact_kpi_row.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/impact_ranked_table.dart';
import 'package:lotti/features/categories/state/categories_list_controller.dart';
import 'package:lotti/features/design_system/components/buttons/ds_segmented_toggle.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/features/insights/logic/range_presets.dart';
import 'package:lotti/features/insights/model/insights_models.dart';
import 'package:lotti/features/insights/ui/widgets/insights_category_resolver.dart';
import 'package:lotti/features/insights/ui/widgets/insights_period_stepper.dart';
import 'package:lotti/features/insights/ui/widgets/insights_surfaces.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Host-independent core of the AI Impact dashboard: per-category,
/// time-bucketed consumption (cost, energy, CO₂e, tokens).
///
/// Embedded by `ImpactAnalysisPage` (the `/calendar/impact` route) and by the
/// Settings `ai-usage` panel, so both navigation paths render the same
/// dashboard. The two hosts constrain height differently — the page gives a
/// bounded viewport, the settings panel wraps the body in a
/// `SingleChildScrollView` — so the content scrolls itself only when the
/// incoming constraints are bounded (see `_DashboardContent`).
///
/// This widget is the single provider consumer: it watches the period
/// selection, the year-windowed consumption buckets, and the category list,
/// then passes plain values to dumb children.
///
/// **keepPreviousData.** `consumptionBucketsProvider` is an
/// `autoDispose.family` keyed by calendar year (`insightsWindowFor`), the
/// same shape as the Insights buckets: stepping within a year reuses one
/// cached bucket set, but crossing a year boundary starts a fresh family
/// instance at `AsyncLoading`. The last fully-loaded generation is retained
/// in state and kept on screen until the new window resolves, so refetches
/// and window switches never flash a loading shell over the established
/// dashboard (the header/stepper always tracks the live selection).
class ImpactAnalysisBody extends ConsumerStatefulWidget {
  const ImpactAnalysisBody({super.key});

  @override
  ConsumerState<ImpactAnalysisBody> createState() => _ImpactAnalysisBodyState();
}

class _ImpactAnalysisBodyState extends ConsumerState<ImpactAnalysisBody> {
  /// The metric the chart + ranked table break down. The KPI row always
  /// shows all four.
  ConsumptionMetric _metric = ConsumptionMetric.cost;

  /// The most recent generation whose buckets had fully loaded — the
  /// keepPreviousData retention (see class docs). Null only before the very
  /// first load resolves.
  _ImpactDashboardData? _lastData;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;

    final selection = ref.watch(consumptionRangeControllerProvider);
    final controller = ref.read(consumptionRangeControllerProvider.notifier);
    final bucketsAsync = ref.watch(
      consumptionBucketsProvider(insightsWindowFor(selection.range)),
    );

    // Capture the freshest fully-loaded generation, pairing the buckets
    // with the exact selection they cover — rendering one period's buckets
    // against another period's range would zero-fill the dashboard.
    final buckets = bucketsAsync.value;
    if (buckets != null) {
      _lastData = _ImpactDashboardData(selection: selection, buckets: buckets);
    }
    final data = _lastData;

    final categories =
        ref.watch(categoriesStreamProvider).value ??
        const <CategoryDefinition>[];
    final resolver = InsightsCategoryResolver(
      categoriesById: {for (final c in categories) c.id: c},
      uncategorizedLabel: messages.insightsUncategorized,
      otherLabel: messages.insightsOtherCategories,
      deletedLabel: messages.insightsDeletedCategory,
    );

    // First paint only: no generation has loaded yet, so a loading shell
    // (or the error message if that very first fetch failed) is all there
    // is to show. Afterwards a loading window or transient error keeps the
    // last generation on screen rather than blanking.
    if (data == null) {
      return bucketsAsync.hasError
          ? Center(
              child: Text(
                messages.aiImpactLoadError,
                style: tokens.typography.styles.body.bodySmall.copyWith(
                  color: tokens.colors.text.lowEmphasis,
                ),
              ),
            )
          : const Center(child: CircularProgressIndicator());
    }

    return _DashboardContent(
      selection: selection,
      data: data,
      resolver: resolver,
      metric: _metric,
      showStaleNotice: bucketsAsync.hasError,
      onSelectMetric: (metric) => setState(() => _metric = metric),
      onSelectUnit: controller.selectUnit,
      onStep: controller.step,
      onSelectToDate: controller.selectToDate,
    );
  }
}

/// A fully-resolved dashboard generation: a bucket set paired with the
/// exact [selection] it was computed for. Retained by the body state for
/// keepPreviousData across year-boundary loads.
@immutable
class _ImpactDashboardData {
  const _ImpactDashboardData({required this.selection, required this.buckets});

  final InsightsPeriodSelection selection;
  final ConsumptionDayBuckets buckets;
}

/// Below this content width the metric toggle switches to the design
/// system's fill-width `expand` mode (equal-width, dense segments): the four
/// shrink-wrapped segments have a fixed intrinsic width that overflows
/// phone-width panes such as the Settings `ai-usage` panel (~390 px).
const double _kMetricToggleShrinkMinWidth = 480;

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.selection,
    required this.data,
    required this.resolver,
    required this.metric,
    required this.showStaleNotice,
    required this.onSelectMetric,
    required this.onSelectUnit,
    required this.onStep,
    required this.onSelectToDate,
  });

  /// The live selection — drives the header/stepper only, so a
  /// year-boundary step gets instant feedback even while [data] is still
  /// the previous generation. Every body figure reads [data].selection.
  final InsightsPeriodSelection selection;

  /// The generation rendered in the body — possibly the previous period
  /// while a new window loads (keepPreviousData).
  final _ImpactDashboardData data;

  final InsightsCategoryResolver resolver;
  final ConsumptionMetric metric;

  /// Whether a window load failed while the retained generation stays on
  /// screen — surfaced as a slim, non-blocking strip instead of an error
  /// shell, so a failed step never silently mislabels the previous
  /// period's figures as the newly selected one.
  final bool showStaleNotice;

  final ValueChanged<ConsumptionMetric> onSelectMetric;
  final ValueChanged<InsightsPeriodUnit> onSelectUnit;
  final ValueChanged<int> onStep;
  final ValueChanged<InsightsPeriodUnit> onSelectToDate;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    // Body figures derive from the generation's own selection/buckets —
    // never the live [selection], whose range may point at a year still
    // loading (which would zero-fill every derivation below).
    final range = data.selection.range;
    final buckets = data.buckets;

    // Pure derivations, recomputed per build. The daily pass is shared
    // between the ranking and the chart builder.
    final totals = impactTotalsInRange(buckets, range);
    final isEmpty = totals == ConsumptionMetrics.zero;
    final daily = dailyMetricTotals(buckets, range, metric);
    final ranked = rankedImpactCategoryTotals(daily);
    final chartData = buildImpactChartData(
      buckets,
      range,
      metric,
      precomputedDaily: daily,
    );

    final children = <Widget>[
      if (showStaleNotice) ...[
        const _StaleDataNotice(),
        SizedBox(height: tokens.spacing.step4),
      ],
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: tokens.spacing.step3,
        children: [
          Text(messages.aiImpactTitle, style: calmPageTitleStyle(tokens)),
          // The stepper's segmented cluster + to-date pills are a fixed
          // intrinsic-width strip that cannot compress, so on panes
          // narrower than it (the phone-width Settings `ai-usage` panel)
          // it scrolls horizontally instead of overflowing — the repo's
          // wide-content rule. On wide layouts the scroller shrink-wraps
          // and is inert.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: InsightsPeriodStepper(
              // Compare and the calendar picker stay off: comparison is
              // not in v1, and the shared period picker drives the
              // Insights range controller, not this dashboard's.
              selection: selection,
              onSelectUnit: onSelectUnit,
              onStep: onStep,
              onSelectToDate: onSelectToDate,
            ),
          ),
        ],
      ),
      SizedBox(height: tokens.spacing.sectionGap),
      if (isEmpty)
        _EmptyState(
          title: messages.aiImpactEmptyTitle,
          body: messages.aiImpactEmptyBody,
        )
      else ...[
        // Shrink-wrapped and left-aligned when there is room; on narrow
        // panes the toggle fills the width in the design system's dense
        // `expand` mode instead — its four shrink-wrapped segments would
        // otherwise overflow (the control cannot compress below its
        // intrinsic width).
        LayoutBuilder(
          builder: (context, constraints) {
            final expand = constraints.maxWidth < _kMetricToggleShrinkMinWidth;
            final toggle = DsSegmentedToggle<ConsumptionMetric>(
              selected: metric,
              onChanged: onSelectMetric,
              expand: expand,
              segments: [
                for (final value in ConsumptionMetric.values)
                  DsSegment(value, consumptionMetricLabel(messages, value)),
              ],
            );
            if (expand) return toggle;
            return Align(alignment: Alignment.centerLeft, child: toggle);
          },
        ),
        SizedBox(height: tokens.spacing.sectionGap),
        ImpactKpiRow(totals: totals),
        SizedBox(height: tokens.spacing.sectionGap),
        ImpactChartCard(
          chartData: chartData,
          resolver: resolver,
          metric: metric,
        ),
        SizedBox(height: tokens.spacing.sectionGap),
        ImpactRankedTable(entries: ranked, resolver: resolver, metric: metric),
        SizedBox(height: tokens.spacing.sectionGap),
        // Per-call ledger: the newest individual calls in the same period.
        // Watches its own provider, so it rides the generation's range
        // without threading through the retained dashboard data.
        ImpactCallLedger(range: range),
      ],
      SizedBox(height: tokens.spacing.step6),
    ];

    final padding = EdgeInsets.symmetric(
      horizontal: tokens.spacing.step6,
      vertical: tokens.spacing.step5,
    );

    // Bounded host (the impact page): the body owns scrolling. Unbounded
    // host (the settings panel's SingleChildScrollView): shrink-wrap and
    // let the host scroll — a ListView here would blow up on infinite
    // height.
    return LayoutBuilder(
      builder: (context, constraints) => constraints.hasBoundedHeight
          ? ListView(padding: padding, children: children)
          : Padding(
              padding: padding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
    );
  }
}

/// Slim, non-blocking strip shown above the retained dashboard when a
/// window load fails — the project's "background refresh uses a subtle
/// affordance, never an error shell" rule.
class _StaleDataNotice extends StatelessWidget {
  const _StaleDataNotice();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Row(
      children: [
        Icon(
          Icons.sync_problem_rounded,
          size: tokens.spacing.step5,
          color: tokens.colors.text.lowEmphasis,
        ),
        SizedBox(width: tokens.spacing.step2),
        Flexible(
          child: Text(
            context.messages.insightsRefreshError,
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.text.lowEmphasis,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Calm empty state for a period with no AI consumption: icon plus a short
/// explanation, in the dashboard's card idiom.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.body});

  final String title;
  final String body;

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
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.step6,
          vertical: tokens.spacing.step9,
        ),
        child: Column(
          children: [
            Icon(
              Icons.eco_outlined,
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
          ],
        ),
      ),
    );
  }
}
