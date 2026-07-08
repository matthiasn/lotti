import 'dart:async';

import 'package:clock/clock.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/ai_consumption/logic/consumption_formatting.dart';
import 'package:lotti/features/ai_consumption/model/consumption_aggregation_models.dart';
import 'package:lotti/features/ai_consumption/state/consumption_providers.dart';
import 'package:lotti/features/ai_consumption/ui/impact_analysis_body.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/impact_chart_card.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/impact_kpi_row.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/impact_model_table.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/impact_ranked_table.dart';
import 'package:lotti/features/categories/state/categories_list_controller.dart';
import 'package:lotti/features/insights/model/insights_models.dart'
    show InsightsPeriodUnit;
import 'package:lotti/features/insights/ui/widgets/insights_period_stepper.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/utils/device_region.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../../categories/test_utils.dart';

void main() {
  // Sunday, June 7 2026 — the controller's default landing selection is
  // June month-to-date (June 1 … 7).
  final fixedNow = DateTime(2026, 6, 7, 16);

  final categories = [
    CategoryTestUtils.createTestCategory(
      id: 'cat-a',
      name: 'Agents',
      color: '#3B82F6',
    ),
    CategoryTestUtils.createTestCategory(
      id: 'cat-b',
      name: 'Research',
      color: '#EF4444',
    ),
  ];

  late MockConsumptionRepository repository;

  setUpAll(() {
    registerFallbackValue(DateTime(2024));
  });

  setUp(() {
    repository = MockConsumptionRepository();
    // The per-call ledger (last dashboard section) pages the newest events
    // of the same period; default it to empty so tests opt into ledger
    // content explicitly.
    when(
      () => repository.newestEventsInRange(
        start: any(named: 'start'),
        end: any(named: 'end'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => []);
  });

  void stubRows(List<ConsumptionMetricRow> rows) {
    when(
      () => repository.metricRowsInRange(
        start: any(named: 'start'),
        end: any(named: 'end'),
      ),
    ).thenAnswer((_) async => rows);
  }

  Future<void> pumpBody(
    WidgetTester tester, {
    Size surface = const Size(1280, 1100),
    UpdateNotifications? notifications,
    bool unboundedHost = false,
  }) async {
    tester.view
      ..physicalSize = surface
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await withClock(Clock.fixed(fixedNow), () async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          mediaQueryData: MediaQueryData(size: surface),
          overrides: [
            consumptionRepositoryProvider.overrideWithValue(repository),
            consumptionRefetchThrottleProvider.overrideWithValue(null),
            maybeUpdateNotificationsProvider.overrideWith(
              (ref) => notifications,
            ),
            categoriesStreamProvider.overrideWith(
              (ref) => Stream.value(categories),
            ),
            // Deterministic Monday-start weeks regardless of host region.
            firstDayOfWeekIndexProvider.overrideWith(
              (ref) => DateTime.monday % 7,
            ),
          ],
          unboundedHost
              // The Settings ai-usage host: unbounded height, body
              // shrink-wraps and the host scrolls.
              ? const Scaffold(
                  body: SingleChildScrollView(child: ImpactAnalysisBody()),
                )
              : const Scaffold(body: ImpactAnalysisBody()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    });
  }

  ConsumptionMetricRow row({
    required int day,
    String? categoryId,
    double credits = 0,
    double energyKwh = 0,
    double carbonGCo2 = 0,
    int totalTokens = 0,
    String? modelId,
    String? providerModelId,
    String? dataCenter,
    double? renewablePercent,
  }) => ConsumptionMetricRow(
    createdAt: DateTime(2026, 6, day, 10),
    categoryId: categoryId,
    modelId: modelId,
    providerModelId: providerModelId,
    metrics: ConsumptionMetrics(
      callCount: 1,
      totalTokens: totalTokens,
      credits: credits,
      energyKwh: energyKwh,
      carbonGCo2: carbonGCo2,
    ),
    dataCenter: dataCenter,
    renewablePercent: renewablePercent,
  );

  // Credits picked so no table/KPI string collides with a chart axis tick:
  // the cost axis ceiling is €0.50, so ticks read €0.13/€0.25/€0.38/€0.50 —
  // none of €0.60 (KPI), €0.30, or €0.15 (table).
  List<ConsumptionMetricRow> scenarioRows() => [
    row(
      day: 5,
      categoryId: 'cat-a',
      credits: 0.3,
      energyKwh: 0.02,
      carbonGCo2: 5,
      totalTokens: 1000,
      modelId: 'configured-glm',
      providerModelId: 'glm-5.2',
      dataCenter: 'FI-HEL1',
      renewablePercent: 80,
    ),
    row(
      day: 6,
      categoryId: 'cat-b',
      credits: 0.15,
      energyKwh: 0.01,
      carbonGCo2: 2.5,
      totalTokens: 500,
      modelId: 'configured-voxtral',
      providerModelId: 'voxtral-small-24b-2507',
      dataCenter: 'SE',
      renewablePercent: 100,
    ),
    row(
      day: 4,
      credits: 0.15,
      energyKwh: 0.01,
      carbonGCo2: 2.5,
      totalTokens: 500,
      modelId: 'configured-glm',
      providerModelId: 'glm-5.2',
    ),
  ];

  testWidgets(
    'renders KPI figures, chart, and ranked table from stubbed rows',
    (tester) async {
      stubRows(scenarioRows());
      // Tall so both breakdown tables mount in the lazy list without scrolling.
      await pumpBody(tester, surface: const Size(1280, 2600));

      expect(find.text('AI Impact'), findsOneWidget);

      // KPI figures are the exact formatter outputs over the period totals.
      expect(find.text(formatCredits(0.6)), findsOneWidget); // €0.60
      expect(find.text(formatEnergyKwh(0.04)), findsOneWidget); // 40 Wh
      expect(find.text(formatCarbonGrams(10)), findsOneWidget); // 10 g
      expect(find.text(formatTokenCount(2000)), findsOneWidget); // 2K

      // Two always-visible charts for the default metric (cost): the category
      // breakdown and the model breakdown (this scenario has models).
      expect(find.text('Cost by category'), findsOneWidget);
      expect(find.text('Cost by model'), findsOneWidget);
      expect(find.byType(BarChart), findsNWidgets(2));

      // Ranked table: resolved names, formatted values, shares of the
      // period total (0.3 / 0.15 / 0.15 → 50% / 25% / 25%).
      final categoryTable = find.byType(ImpactRankedTable);
      expect(categoryTable, findsOneWidget);
      expect(
        find.descendant(of: categoryTable, matching: find.text('Agents')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: categoryTable, matching: find.text('€0.30')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: categoryTable, matching: find.text('50%')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: categoryTable, matching: find.text('Research')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: categoryTable,
          matching: find.text('Uncategorized'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: categoryTable, matching: find.text('€0.15')),
        findsNWidgets(2),
      );
      expect(
        find.descendant(of: categoryTable, matching: find.text('25%')),
        findsNWidgets(2),
      );

      // The model breakdown table renders alongside the category one — both
      // are always visible now, with no dimension toggle.
      final modelTable = find.byType(ImpactModelTable);
      expect(modelTable, findsOneWidget);
      expect(
        find.descendant(of: modelTable, matching: find.text('glm-5.2')),
        findsOneWidget,
      );

      // Location table: rows with provider-reported data centers are folded
      // by serving location and render energy, carbon, and renewable share.
      await tester.scrollUntilVisible(
        find.text('Impact by location'),
        300,
        scrollable: find.descendant(
          of: find.byType(ImpactAnalysisBody),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          ),
        ),
        maxScrolls: 20,
      );

      expect(find.text('Impact by location'), findsOneWidget);
      expect(find.text('FI'), findsOneWidget);
      expect(find.text('FI-HEL1'), findsOneWidget);
      expect(find.text('SE'), findsOneWidget);
      expect(find.text(formatEnergyKwh(0.02)), findsWidgets);
      expect(find.text(formatCarbonGrams(5)), findsWidgets);
      expect(find.text('80%'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
    },
  );

  testWidgets(
    'the category and model breakdowns render as two stacked charts + tables',
    (tester) async {
      stubRows(scenarioRows());
      // Tall so both (lazy ListView) breakdown tables mount without scrolling.
      await pumpBody(tester, surface: const Size(1280, 2600));

      // Both chart cards are present at once, no toggle between them.
      expect(find.text('Cost by category'), findsOneWidget);
      expect(find.text('Cost by model'), findsOneWidget);
      expect(find.byType(ImpactRankedTable), findsOneWidget);

      final modelTable = find.byType(ImpactModelTable);
      expect(modelTable, findsOneWidget);
      // Model totals over the scenario: glm-5.2 €0.45 (75%), voxtral €0.15.
      expect(
        find.descendant(of: modelTable, matching: find.text('glm-5.2')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: modelTable, matching: find.text('€0.45')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: modelTable, matching: find.text('75%')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: modelTable,
          matching: find.text('voxtral-small-24b-2507'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'a breakdown table row isolates that series across chart and table',
    (tester) async {
      stubRows(scenarioRows());
      // Tall so the (lazy ListView) table is mounted without scrolling.
      await pumpBody(tester, surface: const Size(1280, 2400));

      Finder dimmedRows() => find.byWidgetPredicate(
        (w) => w is Opacity && w.opacity == 0.4,
      );
      expect(dimmedRows(), findsNothing);

      Finder agentsRow() => find.descendant(
        of: find.byType(ImpactRankedTable),
        matching: find.text('Agents'),
      );

      await withClock(Clock.fixed(fixedNow), () async {
        await tester.tap(agentsRow());
        await tester.pump();
      });

      // The other category rows fade, and the category chart (the first of the
      // two) re-baselines to the one isolated series (each drawn bar has at
      // most one stacked segment).
      expect(dimmedRows(), findsWidgets);
      final chart = tester.widget<BarChart>(find.byType(BarChart).first);
      for (final group in chart.data.barGroups) {
        expect(
          group.barRods.single.rodStackItems.length,
          lessThanOrEqualTo(1),
        );
      }

      // Tapping the same row again clears the isolation.
      await withClock(Clock.fixed(fixedNow), () async {
        await tester.tap(agentsRow());
        await tester.pump();
      });
      expect(dimmedRows(), findsNothing);
    },
  );

  testWidgets('tapping a KPI tile switches the chart and table to that metric', (
    tester,
  ) async {
    stubRows(scenarioRows());
    await pumpBody(tester);

    // Scope the cost value to the table: €0.30 is also a nice-number cost axis
    // tick (0.10/0.20/0.30/0.40/0.50), so an unscoped match would find both.
    Finder inCategoryTable(String text) => find.descendant(
      of: find.byType(ImpactRankedTable),
      matching: find.text(text),
    );
    expect(find.text('Cost by category'), findsOneWidget);
    expect(inCategoryTable('€0.30'), findsOneWidget);

    await withClock(Clock.fixed(fixedNow), () async {
      // The KPI tiles are the metric selector — tap the ENERGY tile (its
      // eyebrow label; scoped to the KPI row since the location table also has
      // an "ENERGY" column header) to drive the chart + table onto energy.
      await tester.tap(
        find.descendant(
          of: find.byType(ImpactKpiRow),
          matching: find.text('ENERGY'),
        ),
      );
      await tester.pump();
    });

    expect(find.text('Energy by category'), findsOneWidget);
    expect(find.text('Cost by category'), findsNothing);
    // Table now formats through the energy formatter; the euro table value gone.
    expect(find.text(formatEnergyKwh(0.02)), findsWidgets); // 20 Wh
    expect(inCategoryTable('€0.30'), findsNothing);
    // Shares are metric-relative and unchanged here (same proportions).
    expect(inCategoryTable('50%'), findsOneWidget);
  });

  testWidgets(
    'selecting a chart bucket scopes the ledger and the chip clears it',
    (tester) async {
      stubRows(scenarioRows());
      // Tall enough that the (lazy ListView) drill chip above the ledger is
      // mounted without scrolling.
      await pumpBody(tester, surface: const Size(1280, 2400));

      // The scope chip is marked by its filter icon.
      final chip = find.byIcon(Icons.filter_alt_outlined);
      expect(chip, findsNothing);

      // Drive the chart's bucket-selected callback (the chart→ledger drill
      // hook; the bar hit-test itself is covered in the charts test) with a
      // day inside the current June range. Keep the fixed clock so the
      // rebuild's date math stays on June 7.
      await withClock(Clock.fixed(fixedNow), () async {
        // Drive the category (first) chart's bucket-selected callback.
        final card = tester.widget<ImpactChartCard>(
          find.byType(ImpactChartCard).first,
        );
        card.onBucketSelected!(DateTime(2026, 6, 5));
        await tester.pump();
        await tester.pump();

        // A pure drill (no isolation) shows one clearable chip above the
        // ledger, labelled Jun 5 — the tapped bar's own accent outline is the
        // in-viewport feedback, so there is no duplicate chip under the chart.
        expect(chip, findsOneWidget);
        expect(find.textContaining('Jun 5'), findsWidgets);
        // Re-selecting the same bucket toggles the drill off.
        card.onBucketSelected!(DateTime(2026, 6, 5));
        await tester.pump();
        expect(chip, findsNothing);

        // Select again, then clear via the chip's tap target.
        card.onBucketSelected!(DateTime(2026, 6, 5));
        await tester.pump();
        expect(chip, findsOneWidget);
        await tester.tap(chip);
        await tester.pump();
        expect(chip, findsNothing);
      });
    },
  );

  testWidgets('isolating a model scopes the ledger and shows a scope chip', (
    tester,
  ) async {
    stubRows(scenarioRows());
    await pumpBody(tester, surface: const Size(1280, 2600));

    await withClock(Clock.fixed(fixedNow), () async {
      // The model table is always visible — isolate glm-5.2 by tapping its row.
      await tester.tap(
        find.descendant(
          of: find.byType(ImpactModelTable),
          matching: find.text('glm-5.2'),
        ),
      );
      await tester.pump();

      // Two chips: the in-viewport one under the model chart and the combined
      // one above the ledger, both labelled with the model.
      expect(find.byIcon(Icons.filter_alt_outlined), findsNWidgets(2));
      expect(find.textContaining('glm-5.2'), findsWidgets);
    });
  });

  testWidgets('a period change clears an active drill; period controls fire', (
    tester,
  ) async {
    stubRows(scenarioRows());
    await pumpBody(tester, surface: const Size(1280, 2400));

    await withClock(Clock.fixed(fixedNow), () async {
      final card = tester.widget<ImpactChartCard>(
        find.byType(ImpactChartCard).first,
      );
      card.onBucketSelected!(DateTime(2026, 6, 5));
      await tester.pump();
      expect(find.byIcon(Icons.filter_alt_outlined), findsOneWidget);

      final stepper = tester.widget<InsightsPeriodStepper>(
        find.byType(InsightsPeriodStepper),
      );
      // Stepping to the previous period clears the drill.
      stepper.onStep(-1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byIcon(Icons.filter_alt_outlined), findsNothing);

      // The other period controls are wired too (and also clear the drill).
      stepper.onSelectUnit(InsightsPeriodUnit.month);
      await tester.pump(const Duration(milliseconds: 600));
      stepper.onSelectToDate!(InsightsPeriodUnit.year);
      await tester.pump(const Duration(milliseconds: 600));

      // Year-to-date is a weekly range; drilling it exercises the weekly
      // date-range chip label.
      final weeklyCard = tester.widget<ImpactChartCard>(
        find.byType(ImpactChartCard).first,
      );
      weeklyCard.onBucketSelected!(DateTime(2026, 3, 2));
      await tester.pump();
      expect(find.byIcon(Icons.filter_alt_outlined), findsOneWidget);
    });
  });

  testWidgets('shows the empty state when the range has no consumption', (
    tester,
  ) async {
    stubRows(const []);
    await pumpBody(tester);

    expect(find.text('No AI usage in this range'), findsOneWidget);
    expect(
      find.text('AI calls from your tasks and agents will show up here.'),
      findsOneWidget,
    );
    expect(find.byType(BarChart), findsNothing);
    // The header + period stepper stay available for navigating away.
    expect(find.text('AI Impact'), findsOneWidget);
  });

  testWidgets('renders without overflow at phone width', (tester) async {
    stubRows(scenarioRows());
    await pumpBody(tester, surface: const Size(390, 844));

    // No RenderFlex overflow (the Settings ai-usage panel embeds this body
    // on ~390 px phone panes).
    expect(tester.takeException(), isNull);
    // Real content still renders: title, KPI figures, at least the first chart
    // (the second is below the fold in the lazy list at phone height).
    expect(find.text('AI Impact'), findsOneWidget);
    expect(find.text(formatCredits(0.6)), findsOneWidget);
    expect(find.text(formatCarbonGrams(10)), findsOneWidget);
    expect(find.byType(BarChart), findsWidgets);
  });

  testWidgets('renders without overflow at phone width when empty', (
    tester,
  ) async {
    stubRows(const []);
    await pumpBody(tester, surface: const Size(390, 844));

    expect(tester.takeException(), isNull);
    expect(find.text('No AI usage in this range'), findsOneWidget);
  });

  testWidgets('surfaces a load error when the first fetch fails', (
    tester,
  ) async {
    when(
      () => repository.metricRowsInRange(
        start: any(named: 'start'),
        end: any(named: 'end'),
      ),
    ).thenAnswer((_) async => throw Exception('db gone'));
    await pumpBody(tester);

    expect(find.text("Couldn't load AI impact data"), findsOneWidget);
    expect(find.byType(BarChart), findsNothing);
  });

  testWidgets('shrink-wraps in an unbounded host (settings panel) instead '
      'of mounting its own ListView', (tester) async {
    stubRows([
      row(day: 3, categoryId: 'cat-a', credits: 0.4),
    ]);
    await pumpBody(tester, unboundedHost: true);

    expect(tester.takeException(), isNull);
    // The scrollable belongs to the host; the body renders its column.
    expect(
      find.descendant(
        of: find.byType(ImpactAnalysisBody),
        matching: find.byType(ListView),
      ),
      findsNothing,
    );
    expect(find.text('AI Impact'), findsOneWidget);
    expect(find.byType(BarChart), findsOneWidget);
  });

  testWidgets('a failed refetch keeps the dashboard and shows the stale '
      'strip instead of an error shell', (tester) async {
    final notifications = MockUpdateNotifications();
    final controller = StreamController<Set<String>>.broadcast();
    addTearDown(controller.close);
    when(
      () => notifications.updateStream,
    ).thenAnswer((_) => controller.stream);

    stubRows([
      row(day: 3, categoryId: 'cat-a', credits: 0.4),
    ]);
    await pumpBody(tester, notifications: notifications);
    expect(find.byType(BarChart), findsOneWidget);
    expect(find.byIcon(Icons.sync_problem_rounded), findsNothing);

    // The next window fetch fails; the established dashboard must stay.
    when(
      () => repository.metricRowsInRange(
        start: any(named: 'start'),
        end: any(named: 'end'),
      ),
    ).thenAnswer((_) async => throw Exception('db gone'));
    controller.add({aiConsumptionNotification});
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.byType(BarChart), findsOneWidget);
    expect(find.byIcon(Icons.sync_problem_rounded), findsOneWidget);
    expect(
      find.text("Couldn't refresh — showing the last loaded data"),
      findsOneWidget,
    );
  });

  testWidgets("a per-chart scope chip clears only that chart's isolation", (
    tester,
  ) async {
    stubRows(scenarioRows());
    await pumpBody(tester, surface: const Size(1280, 2600));

    await withClock(Clock.fixed(fixedNow), () async {
      Finder chips() => find.byIcon(Icons.filter_alt_outlined);
      // Isolate a category → an in-chart chip + the combined ledger chip.
      await tester.tap(
        find.descendant(
          of: find.byType(ImpactRankedTable),
          matching: find.text('Agents'),
        ),
      );
      await tester.pump();
      expect(chips(), findsNWidgets(2));
      // The first chip sits under the category chart; tapping it clears just
      // that isolation (onClearCategoryIsolation), leaving no scope active.
      await tester.tap(chips().first);
      await tester.pump();
      expect(chips(), findsNothing);

      // Repeat for the model chart → onClearModelIsolation.
      await tester.tap(
        find.descendant(
          of: find.byType(ImpactModelTable),
          matching: find.text('glm-5.2'),
        ),
      );
      await tester.pump();
      expect(chips(), findsNWidgets(2));
      await tester.tap(chips().first);
      await tester.pump();
      expect(chips(), findsNothing);
    });
  });

  testWidgets("switching to the week unit renders that week's totals", (
    tester,
  ) async {
    // Exercises the week/day branch of the trend-baseline label. The June 1–7
    // week holds all the scenario data (days 4/5/6), so the cost total is €0.60.
    stubRows(scenarioRows());
    await pumpBody(tester);

    await withClock(Clock.fixed(fixedNow), () async {
      final stepper = tester.widget<InsightsPeriodStepper>(
        find.byType(InsightsPeriodStepper),
      );
      stepper.onSelectUnit(InsightsPeriodUnit.week);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    });

    expect(find.text('Cost by category'), findsOneWidget);
    expect(find.text(formatCredits(0.6)), findsOneWidget); // €0.60
  });

  testWidgets('the By model view hides every category name (screenshot-safe)', (
    tester,
  ) async {
    stubRows(scenarioRows());
    await pumpBody(tester, surface: const Size(1280, 2600));

    await withClock(Clock.fixed(fixedNow), () async {
      await tester.tap(find.text('By model').last);
      await tester.pump();
    });

    // The model breakdown stays; the category chart + table are gone.
    expect(find.text('Cost by model'), findsOneWidget);
    expect(find.text('Cost by category'), findsNothing);
    expect(find.byType(ImpactRankedTable), findsNothing);
    // No category label leaks anywhere — the whole point of the view.
    for (final name in const ['Agents', 'Research', 'Journaling', 'Coding']) {
      expect(find.text(name), findsNothing, reason: '$name leaked');
    }
  });

  testWidgets('the By category view hides the model breakdown', (tester) async {
    stubRows(scenarioRows());
    await pumpBody(tester, surface: const Size(1280, 2600));

    await withClock(Clock.fixed(fixedNow), () async {
      await tester.tap(find.text('By category').last);
      await tester.pump();
    });

    expect(find.text('Cost by category'), findsOneWidget);
    expect(find.text('Cost by model'), findsNothing);
    expect(find.byType(ImpactModelTable), findsNothing);
  });

  testWidgets('the breakdown-view picker is hidden when there are no models', (
    tester,
  ) async {
    // A single category call with no model → nothing to switch to.
    stubRows([row(day: 5, categoryId: 'cat-a', credits: 0.3)]);
    await pumpBody(tester);

    expect(find.text('By model'), findsNothing);
    expect(find.text('Both'), findsNothing);
    // The category breakdown still renders.
    expect(find.text('Cost by category'), findsOneWidget);
  });

  testWidgets('a stale By-model selection falls back to category when the '
      'period loses its models', (tester) async {
    final notifications = MockUpdateNotifications();
    final controller = StreamController<Set<String>>.broadcast();
    addTearDown(controller.close);
    when(
      () => notifications.updateStream,
    ).thenAnswer((_) => controller.stream);

    stubRows(scenarioRows());
    await pumpBody(
      tester,
      notifications: notifications,
      surface: const Size(1280, 2600),
    );

    // Select By model — only reachable while there IS model data.
    await withClock(Clock.fixed(fixedNow), () async {
      await tester.tap(find.text('By model').last);
      await tester.pump();
    });
    expect(find.text('Cost by model'), findsOneWidget);

    // The data refreshes to a model-less period. The picker vanishes, so
    // without the fallback nothing would render and there'd be no way back —
    // the category breakdown must take over.
    stubRows([row(day: 5, categoryId: 'cat-a', credits: 0.3)]);
    await withClock(Clock.fixed(fixedNow), () async {
      controller.add({aiConsumptionNotification});
      await tester.pump();
      await tester.pump();
      await tester.pump();
    });

    expect(find.text('Cost by category'), findsOneWidget);
    expect(find.text('Cost by model'), findsNothing);
    expect(find.text('By model'), findsNothing); // picker gone
    expect(find.text('No AI usage in this range'), findsNothing); // not empty
  });

  testWidgets('selecting Requests titles the model chart "Requests by model"', (
    tester,
  ) async {
    stubRows(scenarioRows());
    await pumpBody(tester, surface: const Size(1280, 2600));

    await withClock(Clock.fixed(fixedNow), () async {
      await tester.tap(
        find.descendant(
          of: find.byType(ImpactKpiRow),
          matching: find.text('REQUESTS'),
        ),
      );
      await tester.pump();
    });

    // The model chart's title uses the Requests metric label.
    expect(find.text('Requests by model'), findsOneWidget);
    expect(find.text('Requests by category'), findsOneWidget);
  });
}
