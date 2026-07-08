import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/ai_consumption/logic/consumption_formatting.dart'
    show formatCallCount;
import 'package:lotti/features/ai_consumption/logic/impact_dashboard_data.dart';
import 'package:lotti/features/ai_consumption/model/consumption_aggregation_models.dart';
import 'package:lotti/features/ai_consumption/model/impact_dashboard_models.dart';
import 'package:lotti/features/ai_consumption/state/consumption_providers.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/impact_call_ledger.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/impact_chart_card.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/impact_kpi_row.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/impact_location_table.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/impact_model_table.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/impact_ranked_table.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/series_resolver.dart';
import 'package:lotti/features/categories/state/categories_list_controller.dart';
import 'package:lotti/features/design_system/components/buttons/ds_segmented_toggle.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/features/insights/logic/period_navigation.dart'
    show previousPeriod;
import 'package:lotti/features/insights/logic/range_presets.dart';
import 'package:lotti/features/insights/logic/time_bucketing.dart'
    show dayStart, epochDay;
import 'package:lotti/features/insights/model/insights_models.dart';
import 'package:lotti/features/insights/ui/widgets/insights_category_resolver.dart';
import 'package:lotti/features/insights/ui/widgets/insights_period_stepper.dart';
import 'package:lotti/features/insights/ui/widgets/insights_surfaces.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Which breakdown charts + tables the dashboard shows. `both` (the default)
/// stacks the category and model breakdowns; `category`/`model` narrow to one.
/// `model` is the screenshot-safe view — it never renders a category name, so a
/// shared image can't leak private category labels.
enum ImpactBreakdownView { both, category, model }

/// Host-independent core of the AI Impact dashboard: time-bucketed
/// consumption (cost, energy, CO₂e, tokens, requests) broken down by category
/// or model.
///
/// Embedded by `ImpactAnalysisPage` (the `/dashboards/impact` route) and by the
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
  /// The metric every chart + table breaks down. The KPI row (which is the
  /// selector) always shows all of them.
  ConsumptionMetric _metric = ConsumptionMetric.cost;

  /// Start of the chart bucket the call ledger is drilled into, or null when
  /// the ledger shows the whole period. Shared by both charts (they bucket the
  /// same range) and cleared on any period change (a stale bucket would point
  /// outside the new range).
  DateTime? _ledgerBucketStart;

  /// The isolated series in the category chart (a category id, `null` =
  /// uncategorized), independent of the model chart's isolation.
  String? _isolatedCategoryKey;

  /// The isolated series in the model chart (a model id), independent of the
  /// category chart's isolation.
  String? _isolatedModelKey;

  /// Which breakdown charts are shown — both (default), or narrowed to the
  /// category or model one (Model being the screenshot-safe view).
  ImpactBreakdownView _breakdownView = ImpactBreakdownView.both;

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

    // Trend baseline: the previous equal-length period. When it falls in the
    // same loaded window we read the current buckets; when it falls in a
    // different calendar-year window (e.g. the year view's prior year) we watch
    // that window too, so the KPI trend deltas are never absent on the landing
    // view — they simply fill in once the prior window resolves.
    final prevRange = previousPeriod(data.selection.range, data.selection.unit);
    final prevWindow = insightsWindowFor(prevRange);
    final prevBuckets = prevWindow == insightsWindowFor(data.selection.range)
        ? data.buckets
        : ref.watch(consumptionBucketsProvider(prevWindow)).value;
    final previousTotals = prevBuckets != null
        ? impactTotalsInRange(prevBuckets, prevRange)
        : null;
    final previousLabel = previousTotals != null
        ? _previousPeriodLabel(context, prevRange, data.selection.unit)
        : null;

    return _DashboardContent(
      selection: selection,
      data: data,
      resolver: resolver,
      metric: _metric,
      previousTotals: previousTotals,
      previousLabel: previousLabel,
      ledgerBucketStart: _ledgerBucketStart,
      isolatedCategoryKey: _isolatedCategoryKey,
      isolatedModelKey: _isolatedModelKey,
      breakdownView: _breakdownView,
      showStaleNotice: bucketsAsync.hasError,
      onSelectMetric: (metric) => setState(() => _metric = metric),
      onSelectBreakdownView: (view) => setState(() {
        _breakdownView = view;
        // Narrowing hides one dimension; drop its isolation (and the shared
        // drill) so a hidden filter can't linger — or leak via the ledger chip
        // when the model-only view is meant to be screenshot-safe.
        _isolatedCategoryKey = null;
        _isolatedModelKey = null;
        _ledgerBucketStart = null;
      }),
      onToggleCategorySeries: (key) => setState(() {
        _isolatedCategoryKey = _isolatedCategoryKey == key ? null : key;
      }),
      onToggleModelSeries: (key) => setState(() {
        _isolatedModelKey = _isolatedModelKey == key ? null : key;
      }),
      onSelectBucket: (bucketStart) => setState(() {
        // Tapping the drilled bucket again clears the drill.
        _ledgerBucketStart = _ledgerBucketStart == bucketStart
            ? null
            : bucketStart;
      }),
      onClearScope: () => setState(() {
        // The ledger chip is the ledger's whole scope — clear the drill and
        // both isolations at once.
        _ledgerBucketStart = null;
        _isolatedCategoryKey = null;
        _isolatedModelKey = null;
      }),
      onClearCategoryIsolation: () =>
          setState(() => _isolatedCategoryKey = null),
      onClearModelIsolation: () => setState(() => _isolatedModelKey = null),
      onSelectUnit: (unit) {
        controller.selectUnit(unit);
        setState(() => _ledgerBucketStart = null);
      },
      onStep: (delta) {
        controller.step(delta);
        setState(() => _ledgerBucketStart = null);
      },
      onSelectToDate: (unit) {
        controller.selectToDate(unit);
        setState(() => _ledgerBucketStart = null);
      },
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

/// Short calendar name of the previous period for the KPI trend baseline
/// ("vs May" / "vs 2025" / "vs Q1" / "vs Jun 1"), so the delta discloses what
/// it is measured against instead of a bare "vs prev". Only reached when that
/// prior period is in the loaded window.
String _previousPeriodLabel(
  BuildContext context,
  InsightsRange prevRange,
  InsightsPeriodUnit unit,
) {
  final locale = Localizations.localeOf(context).toString();
  final start = dayStart(prevRange.startDay);
  return switch (unit) {
    InsightsPeriodUnit.year => DateFormat.y(locale).format(start),
    // ICU quarter pattern is locale-aware ("Q1", localized where it differs).
    InsightsPeriodUnit.quarter => DateFormat('QQQ', locale).format(start),
    InsightsPeriodUnit.month => DateFormat.MMM(locale).format(start),
    InsightsPeriodUnit.week ||
    InsightsPeriodUnit.day => DateFormat.MMMd(locale).format(start),
  };
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.selection,
    required this.data,
    required this.resolver,
    required this.metric,
    required this.previousTotals,
    required this.previousLabel,
    required this.ledgerBucketStart,
    required this.isolatedCategoryKey,
    required this.isolatedModelKey,
    required this.breakdownView,
    required this.showStaleNotice,
    required this.onSelectMetric,
    required this.onSelectBreakdownView,
    required this.onToggleCategorySeries,
    required this.onToggleModelSeries,
    required this.onSelectBucket,
    required this.onClearScope,
    required this.onClearCategoryIsolation,
    required this.onClearModelIsolation,
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

  /// Totals for the previous equal-length period (from whichever window holds
  /// it), or null when none is loaded yet — drives the KPI trend deltas.
  final ConsumptionMetrics? previousTotals;

  /// Short calendar name of that previous period ("May" / "2025"), for the
  /// selected tile's "vs …" baseline.
  final String? previousLabel;

  /// Start of the chart bucket the ledger is drilled into, or null for the
  /// whole period. Shared by both charts.
  final DateTime? ledgerBucketStart;

  /// The isolated series of the category chart (independent of the model one).
  final String? isolatedCategoryKey;

  /// The isolated series of the model chart (independent of the category one).
  final String? isolatedModelKey;

  /// Which breakdown charts + tables to show (both / category / model).
  final ImpactBreakdownView breakdownView;

  /// Whether a window load failed while the retained generation stays on
  /// screen — surfaced as a slim, non-blocking strip instead of an error
  /// shell, so a failed step never silently mislabels the previous
  /// period's figures as the newly selected one.
  final bool showStaleNotice;

  final ValueChanged<ConsumptionMetric> onSelectMetric;
  final ValueChanged<ImpactBreakdownView> onSelectBreakdownView;
  final ValueChanged<String?> onToggleCategorySeries;
  final ValueChanged<String?> onToggleModelSeries;
  final ValueChanged<DateTime> onSelectBucket;
  final VoidCallback onClearScope;
  final VoidCallback onClearCategoryIsolation;
  final VoidCallback onClearModelIsolation;
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
    final modelDaily = dailyModelMetricTotals(buckets, range, metric);
    final rankedModels = rankedModelMetrics(buckets, range, metric);
    final locationTotals = rankedImpactLocationTotals(buckets, range);
    final categoryChart = buildImpactChartData(
      buckets,
      range,
      metric,
      precomputedDaily: daily,
    );
    final modelChart = buildImpactChartData(
      buckets,
      range,
      metric,
      precomputedDaily: modelDaily,
    );

    // The model chart + table appear only when the period has at least one
    // *identified* model — a lone "Unknown model" band is noise, not a
    // breakdown. The category chart is always shown.
    final hasModelData = buckets.modelDays.values.any(
      (cells) => cells.keys.any((key) => key != null),
    );

    // The breakdown-view picker narrows the two charts to one. Category is
    // shown for both/category; model for both/model when the data exists.
    final showCategory = breakdownView != ImpactBreakdownView.model;
    final showModel =
        breakdownView != ImpactBreakdownView.category && hasModelData;

    // Palette colors are assigned by a stable, metric-independent ordering of
    // every model in the window (sorted ids), so a model keeps its color
    // across metric switches, across the chart/legend/table, and — within a
    // window — across period steps.
    final orderedModelKeys = <String>{
      for (final day in buckets.modelDays.values)
        for (final key in day.keys) ?key,
    }.toList()..sort();
    final categorySeriesResolver = CategorySeriesResolver(resolver);
    final modelResolver = PaletteSeriesResolver(
      orderedKeys: orderedModelKeys,
      unknownLabel: messages.aiImpactModelUnknown,
      otherLabel: messages.aiImpactModelOther,
    );

    // Drill-down: a tapped bar (on either chart — both bucket the same range)
    // scopes the ledger to that bucket's days and highlights it on both.
    // Ignore a stale bucket that no longer falls in the current range.
    final granularity = categoryChart.granularity;
    final drilledStart = ledgerBucketStart;
    InsightsRange? ledgerRange;
    String? ledgerFilterLabel;
    int? selectedBucketIndex;
    if (drilledStart != null) {
      final startDay = epochDay(drilledStart);
      final index = categoryChart.bucketStarts.indexWhere(
        (d) => epochDay(d) == startDay,
      );
      if (index >= 0) selectedBucketIndex = index;
      if (startDay >= range.startDay && startDay < range.endDayExclusive) {
        final span = granularity == InsightsGranularity.week ? 7 : 1;
        ledgerRange = InsightsRange(
          startDay: startDay,
          endDayExclusive: startDay + span,
        );
        final locale = Localizations.localeOf(context).toString();
        ledgerFilterLabel = granularity == InsightsGranularity.week
            ? '${DateFormat.MMMd(locale).format(drilledStart)} – '
                  // Calendar arithmetic (not Duration) so a DST transition in
                  // the week can't shift the end date to the wrong day.
                  '${DateFormat.MMMd(locale).format(DateTime(drilledStart.year, drilledStart.month, drilledStart.day + 6))}'
            : DateFormat.MMMd(locale).format(drilledStart);
      }
    }
    final effectiveRange = ledgerRange ?? range;

    // Each chart isolates its own series independently; isolation scopes the
    // ledger (category ∩ model ∩ drilled week) and shows an in-viewport chip
    // under the chart it belongs to.
    final categoryKey = isolatedCategoryKey;
    final canScopeCategory =
        categoryKey != null && categoryKey != kInsightsOtherCategoryKey;
    final categoryLabel = canScopeCategory
        ? categorySeriesResolver.labelFor(categoryKey)
        : null;
    final modelKey = isolatedModelKey;
    final canScopeModel =
        modelKey != null && modelKey != kInsightsOtherCategoryKey;
    final modelLabel = canScopeModel ? modelResolver.labelFor(modelKey) : null;

    // Counts come from the buckets (the full count, not the ledger's capped
    // slice). "N calls · <series>" under each chart.
    String chipFor(String label, int count) => [
      messages.aiImpactModelCallsLabel(formatCallCount(count)),
      label,
    ].join(' · ');
    final categoryChipLabel = canScopeCategory
        ? chipFor(
            categoryLabel!,
            scopedCallCount(buckets, effectiveRange, seriesKey: categoryKey),
          )
        : '';
    final modelChipLabel = canScopeModel
        ? chipFor(
            modelLabel!,
            scopedCallCount(
              buckets,
              effectiveRange,
              isModel: true,
              seriesKey: modelKey,
            ),
          )
        : '';

    // The combined "Recent calls" scope chip lists every active filter. A true
    // count is shown only when a single dimension scopes it — an intersection
    // of two dimensions has no single bucket cell to count.
    final scopeParts = [?categoryLabel, ?modelLabel, ?ledgerFilterLabel];
    final hasLedgerFilter = scopeParts.isNotEmpty;
    int? ledgerCount;
    if (canScopeCategory && !canScopeModel) {
      ledgerCount = scopedCallCount(
        buckets,
        effectiveRange,
        seriesKey: categoryKey,
      );
    } else if (canScopeModel && !canScopeCategory) {
      ledgerCount = scopedCallCount(
        buckets,
        effectiveRange,
        isModel: true,
        seriesKey: modelKey,
      );
    } else if (!canScopeCategory && !canScopeModel && ledgerRange != null) {
      ledgerCount = scopedCallCount(buckets, effectiveRange);
    }
    final ledgerChipLabel = hasLedgerFilter
        ? [
            if (ledgerCount != null)
              messages.aiImpactModelCallsLabel(formatCallCount(ledgerCount)),
            ...scopeParts,
          ].join(' · ')
        : '';

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
        // The KPI tiles are themselves the metric selector — tapping one drives
        // the chart + breakdown table — so there is no separate segmented
        // toggle duplicating these same five labels. The selected tile carries
        // the trend delta against the previous period.
        ImpactKpiRow(
          totals: totals,
          selectedMetric: metric,
          onSelectMetric: onSelectMetric,
          previousTotals: previousTotals,
          previousLabel: previousLabel,
        ),
        SizedBox(height: tokens.spacing.sectionGap),
        // Breakdown-view picker — Both / By category / By model. "By model" is
        // the screenshot-safe view (no category name is ever rendered). Only
        // offered when there is a model breakdown to switch to.
        if (hasModelData) ...[
          _BreakdownViewPicker(
            view: breakdownView,
            onSelect: onSelectBreakdownView,
          ),
          SizedBox(height: tokens.spacing.sectionGap),
        ],
        // Category breakdown: chart + companion table (hidden in Model view).
        if (showCategory) ...[
          ImpactChartCard(
            chartData: categoryChart,
            resolver: categorySeriesResolver,
            metric: metric,
            // null → the card titles it "<Metric> by category".
            selectedBucketIndex: selectedBucketIndex,
            isolatedKey: isolatedCategoryKey,
            onToggleSeries: onToggleCategorySeries,
            onBucketSelected: onSelectBucket,
          ),
          // In-viewport confirmation of this chart's isolation (the ledger it
          // also scopes can be far down a long page).
          if (canScopeCategory) ...[
            SizedBox(height: tokens.spacing.step4),
            _LedgerFilterChip(
              label: categoryChipLabel,
              onClear: onClearCategoryIsolation,
            ),
          ],
          SizedBox(height: tokens.spacing.sectionGap),
          ImpactRankedTable(
            entries: ranked,
            resolver: resolver,
            metric: metric,
            isolatedKey: isolatedCategoryKey,
            onToggleSeries: onToggleCategorySeries,
          ),
        ],
        // Model breakdown: chart + table (the "favorite models over time"
        // view), hidden in Category view or when there are no models.
        if (showModel) ...[
          if (showCategory) SizedBox(height: tokens.spacing.sectionGap),
          ImpactChartCard(
            chartData: modelChart,
            resolver: modelResolver,
            metric: metric,
            title: messages.aiImpactChartTitleModel(
              consumptionMetricLabel(messages, metric),
            ),
            // A cloud-only metric drops local models from this chart; say so
            // specifically here rather than repeating the global KPI caveat.
            coverageNote: metric.isCloudOnly
                ? messages.aiImpactModelCoverageNote
                : null,
            selectedBucketIndex: selectedBucketIndex,
            isolatedKey: isolatedModelKey,
            onToggleSeries: onToggleModelSeries,
            onBucketSelected: onSelectBucket,
          ),
          if (canScopeModel) ...[
            SizedBox(height: tokens.spacing.step4),
            _LedgerFilterChip(
              label: modelChipLabel,
              onClear: onClearModelIsolation,
            ),
          ],
          SizedBox(height: tokens.spacing.sectionGap),
          ImpactModelTable(
            entries: rankedModels,
            resolver: modelResolver,
            metric: metric,
            isolatedKey: isolatedModelKey,
            onToggleSeries: onToggleModelSeries,
          ),
        ],
        if (locationTotals.isNotEmpty) ...[
          SizedBox(height: tokens.spacing.sectionGap),
          ImpactLocationTable(entries: locationTotals),
        ],
        SizedBox(height: tokens.spacing.sectionGap),
        // Per-call ledger: the newest individual calls in the period, scoped by
        // the drilled bucket + either chart's isolation. Watches its own
        // provider, so it rides the generation's range without threading
        // through the retained dashboard data.
        if (hasLedgerFilter) ...[
          _LedgerFilterChip(label: ledgerChipLabel, onClear: onClearScope),
          SizedBox(height: tokens.spacing.step3),
        ],
        ImpactCallLedger(
          range: effectiveRange,
          modelFilter: canScopeModel ? modelKey : null,
          categoryFilter: canScopeCategory ? categoryKey : null,
        ),
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

/// Segmented picker choosing which breakdown charts show: Both / By category /
/// By model. "By model" hides every category name, so its screenshot is safe to
/// share. Scrolls horizontally on tight panes (the repo's wide-content rule).
class _BreakdownViewPicker extends StatelessWidget {
  const _BreakdownViewPicker({required this.view, required this.onSelect});

  final ImpactBreakdownView view;
  final ValueChanged<ImpactBreakdownView> onSelect;

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DsSegmentedToggle<ImpactBreakdownView>(
        selected: view,
        onChanged: onSelect,
        segments: [
          DsSegment(ImpactBreakdownView.both, messages.aiImpactBreakdownBoth),
          DsSegment(
            ImpactBreakdownView.category,
            messages.aiImpactBreakdownCategory,
          ),
          DsSegment(
            ImpactBreakdownView.model,
            messages.aiImpactBreakdownModel,
          ),
        ],
      ),
    );
  }
}

/// Clearable pill shown above the call ledger (and under a chart) while a
/// scope is active — a drilled bucket and/or an isolated series. Tapping it
/// (or its close icon) clears that scope.
class _LedgerFilterChip extends StatelessWidget {
  const _LedgerFilterChip({required this.label, required this.onClear});

  final String label;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;

    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        button: true,
        label: messages.aiImpactLedgerClearFilter,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onClear,
            borderRadius: BorderRadius.circular(tokens.radii.m),
            child: Container(
              decoration: BoxDecoration(
                color: tokens.colors.background.level02,
                borderRadius: BorderRadius.circular(tokens.radii.m),
                border: Border.all(color: tokens.colors.decorative.level01),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spacing.step3,
                vertical: tokens.spacing.step2,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.filter_alt_outlined,
                    size: tokens.spacing.step4,
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                  SizedBox(width: tokens.spacing.step2),
                  Flexible(
                    child: Text(
                      label,
                      style: tokens.typography.styles.others.caption.copyWith(
                        color: tokens.colors.text.highEmphasis,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: tokens.spacing.step3),
                  Icon(
                    Icons.close_rounded,
                    size: tokens.spacing.step4,
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                ],
              ),
            ),
          ),
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
