import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/hourly_wake_activity.dart';
import 'package:lotti/features/agents/state/agent_pending_wake_providers.dart';
import 'package:lotti/features/agents/ui/wake_activity_chart.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../widget_test_utils.dart';

void main() {
  setUp(() async {
    await setUpTestGetIt();
  });

  tearDown(() async {
    await tearDownTestGetIt();
  });

  List<HourlyWakeActivity> makeBuckets({
    Map<int, Map<String, int>> dataByHour = const {},
  }) {
    return List.generate(24, (i) {
      final reasons = dataByHour[i] ?? const {};
      final count = reasons.values.fold<int>(0, (s, c) => s + c);
      return HourlyWakeActivity(
        hour: DateTime(2026, 4, 4, i),
        count: count,
        reasons: reasons,
      );
    });
  }

  Widget buildSubject({required List<HourlyWakeActivity> buckets}) {
    return makeTestableWidgetNoScroll(
      const WakeActivityChart(),
      theme: DesignSystemTheme.light(),
      overrides: [
        hourlyWakeActivityProvider.overrideWith((ref) async => buckets),
      ],
    );
  }

  testWidgets('hides chart when all buckets are empty', (tester) async {
    await tester.pumpWidget(buildSubject(buckets: makeBuckets()));
    await tester.pumpAndSettle();

    expect(find.byType(WakeActivityChart), findsOneWidget);
    expect(find.byIcon(Icons.bar_chart_rounded), findsNothing);
  });

  testWidgets('shows title, total, Y-axis labels, and X-axis labels', (
    tester,
  ) async {
    final buckets = makeBuckets(
      dataByHour: {
        10: const {'subscription': 3, 'creation': 2},
      },
    );

    await tester.pumpWidget(buildSubject(buckets: buckets));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(WakeActivityChart));
    expect(
      find.text(context.messages.agentPendingWakesActivityTitle),
      findsOneWidget,
    );
    expect(
      find.text(context.messages.agentPendingWakesActivityTotal(5)),
      findsOneWidget,
    );

    // Y-axis: max label and zero
    expect(find.text('5'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    // Y-axis: midpoint label (5 ~/ 2 = 2)
    expect(find.text('2'), findsOneWidget);

    // X-axis: 5 labels at hours 0, 6, 12, 18, 23
    expect(find.text('00:00'), findsOneWidget);
    expect(find.text('06:00'), findsOneWidget);
    expect(find.text('12:00'), findsOneWidget);
    expect(find.text('18:00'), findsOneWidget);
    expect(find.text('23:00'), findsOneWidget);
  });

  testWidgets('tap on bar shows localized detail text', (tester) async {
    final buckets = makeBuckets(
      dataByHour: {
        5: const {'subscription': 7, 'creation': 4},
      },
    );

    await tester.pumpWidget(buildSubject(buckets: buckets));
    await tester.pumpAndSettle();

    // Find the Semantics widget for hour 5
    final barSemantics = find.bySemanticsLabel('05:00: 11');
    expect(barSemantics, findsOneWidget);

    // Tap the bar
    await tester.tap(barSemantics);
    await tester.pump();

    // Localized detail text should appear
    final context = tester.element(find.byType(WakeActivityChart));
    expect(
      find.text(
        context.messages.agentPendingWakesActivityHourDetail(
          '05:00',
          11,
          'subscription: 7, creation: 4',
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('tap toggles selection off when same bar tapped again', (
    tester,
  ) async {
    final buckets = makeBuckets(
      dataByHour: {
        12: const {'subscription': 3},
      },
    );

    await tester.pumpWidget(buildSubject(buckets: buckets));
    await tester.pumpAndSettle();

    final bar = find.bySemanticsLabel('12:00: 3');

    // First tap — detail appears
    await tester.tap(bar);
    await tester.pump();

    final context = tester.element(find.byType(WakeActivityChart));
    expect(
      find.text(
        context.messages.agentPendingWakesActivityHourDetail(
          '12:00',
          3,
          'subscription: 3',
        ),
      ),
      findsOneWidget,
    );

    // Second tap — detail disappears
    await tester.tap(bar);
    await tester.pump();

    expect(
      find.text(
        context.messages.agentPendingWakesActivityHourDetail(
          '12:00',
          3,
          'subscription: 3',
        ),
      ),
      findsNothing,
    );
  });

  testWidgets('renders bar colors based on count thresholds', (tester) async {
    final buckets = makeBuckets(
      dataByHour: {
        3: const {'subscription': 2},
        10: const {'subscription': 7},
        18: const {'subscription': 12},
      },
    );

    await tester.pumpWidget(buildSubject(buckets: buckets));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.bar_chart_rounded), findsOneWidget);
    // Max count is 12
    expect(find.text('12'), findsOneWidget);
    // All three bars have accessible labels
    expect(find.bySemanticsLabel('03:00: 2'), findsOneWidget);
    expect(find.bySemanticsLabel('10:00: 7'), findsOneWidget);
    expect(find.bySemanticsLabel('18:00: 12'), findsOneWidget);
  });

  testWidgets('omits midpoint label when maxCount is 1', (tester) async {
    final buckets = makeBuckets(
      dataByHour: {
        5: const {'subscription': 1},
      },
    );

    await tester.pumpWidget(buildSubject(buckets: buckets));
    await tester.pumpAndSettle();

    expect(find.text('1'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('bars for empty hours have accessible labels', (tester) async {
    final buckets = makeBuckets(
      dataByHour: {
        10: const {'subscription': 1},
      },
    );

    await tester.pumpWidget(buildSubject(buckets: buckets));
    await tester.pumpAndSettle();

    // Empty hour bar still has semantics
    expect(find.bySemanticsLabel('00:00: 0'), findsOneWidget);
    // Active hour bar
    expect(find.bySemanticsLabel('10:00: 1'), findsOneWidget);
  });
}
