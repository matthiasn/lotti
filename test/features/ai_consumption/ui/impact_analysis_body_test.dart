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
import 'package:lotti/features/ai_consumption/ui/widgets/impact_model_table.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/impact_ranked_table.dart';
import 'package:lotti/features/categories/state/categories_list_controller.dart';
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
      await pumpBody(tester);

      expect(find.text('AI Impact'), findsOneWidget);

      // KPI figures are the exact formatter outputs over the period totals.
      expect(find.text(formatCredits(0.6)), findsOneWidget); // €0.60
      expect(find.text(formatEnergyKwh(0.04)), findsOneWidget); // 40 Wh
      expect(find.text(formatCarbonGrams(10)), findsOneWidget); // 10 g
      expect(find.text(formatTokenCount(2000)), findsOneWidget); // 2K

      // Chart card for the default metric (cost), with real bars.
      expect(find.text('Cost by category'), findsOneWidget);
      expect(find.byType(BarChart), findsOneWidget);

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

      // Model table: same metric, but grouped by provider model id.
      final modelTable = find.byType(ImpactModelTable);
      expect(modelTable, findsOneWidget);
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
      expect(
        find.descendant(of: modelTable, matching: find.text('€0.15')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: modelTable, matching: find.text('25%')),
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

  testWidgets('metric toggle switches the chart and table to that metric', (
    tester,
  ) async {
    stubRows(scenarioRows());
    await pumpBody(tester);

    expect(find.text('Cost by category'), findsOneWidget);
    expect(find.text('€0.30'), findsOneWidget);

    await withClock(Clock.fixed(fixedNow), () async {
      // The segmented toggle renders each label twice (an invisible
      // width-reserving ghost first, then the visible text) — tap the
      // visible one so the hit test lands.
      await tester.tap(find.text('Energy').last);
      await tester.pump();
    });

    expect(find.text('Energy by category'), findsOneWidget);
    expect(find.text('Cost by category'), findsNothing);
    // Table (and axis) now format through the energy formatter, and every
    // euro figure outside the KPI row is gone.
    expect(find.text(formatEnergyKwh(0.02)), findsWidgets); // 20 Wh
    expect(find.text('€0.30'), findsNothing);
    // Shares are metric-relative and unchanged here (same proportions).
    expect(find.text('50%'), findsOneWidget);
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
    // Real content still renders: title, KPI figures, chart.
    expect(find.text('AI Impact'), findsOneWidget);
    expect(find.text(formatCredits(0.6)), findsOneWidget);
    expect(find.text(formatCarbonGrams(10)), findsOneWidget);
    expect(find.byType(BarChart), findsOneWidget);
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
}
