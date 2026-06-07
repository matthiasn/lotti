import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/insights/ui/widgets/insights_sidebar_entry.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

void main() {
  late MockNavService navService;
  late ValueNotifier<bool> showTimeAnalysis;

  setUp(() {
    navService = MockNavService();
    showTimeAnalysis = ValueNotifier<bool>(false);
    when(
      () => navService.desktopShowTimeAnalysis,
    ).thenReturn(showTimeAnalysis);
    if (getIt.isRegistered<NavService>()) {
      getIt.unregister<NavService>();
    }
    getIt.registerSingleton<NavService>(navService);
  });

  tearDown(() {
    showTimeAnalysis.dispose();
    getIt.unregister<NavService>();
  });

  Future<void> pumpEntry(WidgetTester tester) => tester.pumpWidget(
    makeTestableWidget(
      const SizedBox(width: 280, child: InsightsSidebarEntry()),
    ),
  );

  testWidgets('renders the label and beams to /dashboards/time on tap', (
    tester,
  ) async {
    final beamed = <String>[];
    beamToNamedOverride = beamed.add;
    addTearDown(() => beamToNamedOverride = null);

    await pumpEntry(tester);

    expect(find.text('Time Analysis'), findsOneWidget);
    expect(find.byIcon(Icons.bar_chart_outlined), findsOneWidget);

    await tester.tap(find.text('Time Analysis'));
    await tester.pump();
    expect(beamed, ['/dashboards/time']);
  });

  testWidgets('reflects the active route with the filled icon', (
    tester,
  ) async {
    showTimeAnalysis.value = true;
    await pumpEntry(tester);

    expect(find.byIcon(Icons.bar_chart_rounded), findsOneWidget);
    expect(find.byIcon(Icons.bar_chart_outlined), findsNothing);
  });

  testWidgets('updates live when the route selection changes', (
    tester,
  ) async {
    await pumpEntry(tester);
    expect(find.byIcon(Icons.bar_chart_outlined), findsOneWidget);

    showTimeAnalysis.value = true;
    await tester.pump();

    expect(find.byIcon(Icons.bar_chart_rounded), findsOneWidget);
  });
}
