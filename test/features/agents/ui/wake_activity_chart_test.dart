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

  Widget buildSubject({
    required List<HourlyWakeActivity> buckets,
  }) {
    return makeTestableWidgetNoScroll(
      const WakeActivityChart(),
      theme: DesignSystemTheme.light(),
      overrides: [
        hourlyWakeActivityProvider.overrideWith((ref) async => buckets),
      ],
    );
  }

  testWidgets('hides chart when all buckets are empty', (tester) async {
    final buckets = List.generate(
      24,
      (i) => HourlyWakeActivity(
        hour: DateTime(2026, 4, 4, i),
        count: 0,
        reasons: const {},
      ),
    );

    await tester.pumpWidget(buildSubject(buckets: buckets));
    await tester.pumpAndSettle();

    expect(find.byType(WakeActivityChart), findsOneWidget);
    // The chart renders a SizedBox.shrink when all empty.
    expect(find.byIcon(Icons.bar_chart_rounded), findsNothing);
  });

  testWidgets('shows chart with title and total when data is present', (
    tester,
  ) async {
    final buckets = List.generate(
      24,
      (i) => HourlyWakeActivity(
        hour: DateTime(2026, 4, 4, i),
        count: i == 10 ? 5 : 0,
        reasons: i == 10 ? const {'subscription': 3, 'creation': 2} : const {},
      ),
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
    expect(find.byIcon(Icons.bar_chart_rounded), findsOneWidget);
  });

  testWidgets('displays hour labels at start and end', (tester) async {
    final buckets = List.generate(
      24,
      (i) => HourlyWakeActivity(
        hour: DateTime(2026, 4, 4, i),
        count: i == 5 ? 3 : 0,
        reasons: i == 5 ? const {'subscription': 3} : const {},
      ),
    );

    await tester.pumpWidget(buildSubject(buckets: buckets));
    await tester.pumpAndSettle();

    expect(find.text('00:00'), findsOneWidget);
    expect(find.text('23:00'), findsOneWidget);
  });
}
