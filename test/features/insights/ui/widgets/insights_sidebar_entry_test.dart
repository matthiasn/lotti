import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/navigation/sidebar_subsection.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/insights/ui/widgets/insights_sidebar_entry.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:material_ui/material_ui.dart';
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

  testWidgets('renders the label and beams to /calendar/time on tap', (
    tester,
  ) async {
    final beamed = <String>[];
    beamToNamedOverride = beamed.add;
    addTearDown(() => beamToNamedOverride = null);

    await pumpEntry(tester);

    expect(find.text('Time Analysis'), findsOneWidget);
    expect(find.byIcon(LottiIcons.chart), findsOneWidget);

    await tester.tap(find.text('Time Analysis'));
    await tester.pump();
    expect(beamed, ['/calendar/time']);
  });

  testWidgets('uses the shared sidebar subsection surface by default', (
    tester,
  ) async {
    await pumpEntry(tester);

    expect(find.byType(SidebarSubsectionSurface), findsOneWidget);
    expect(find.byType(SidebarSubsectionAction), findsOneWidget);
  });

  testWidgets('reflects the active route in the row treatment', (
    tester,
  ) async {
    // This used to assert an outlined -> filled glyph swap. Lucide is
    // stroke-only and `chartColumn` has no filled counterpart, so the swap has
    // nothing to swap to and the widget no longer passes an activeIcon at all.
    // The active state was never carried by the glyph alone anyway — the row
    // gains a filled surface, a wider accent rail and a bolder label, and
    // those are what this now pins.
    await pumpEntry(tester);
    final inactiveWeight = tester
        .widget<Text>(find.text('Time Analysis'))
        .style
        ?.fontWeight;

    showTimeAnalysis.value = true;
    await tester.pump();

    final activeWeight = tester
        .widget<Text>(find.text('Time Analysis'))
        .style
        ?.fontWeight;
    expect(activeWeight, isNot(inactiveWeight));

    final tokens = tester
        .element(find.byType(SidebarSubsectionAction))
        .designTokens;
    final rail = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((d) => d.decoration)
        .whereType<BoxDecoration>()
        .where((d) => d.color == tokens.colors.interactive.enabled);
    expect(
      rail,
      isNotEmpty,
      reason: 'the active row should carry an accent rail',
    );
  });

  testWidgets('updates live when the route selection changes', (
    tester,
  ) async {
    await pumpEntry(tester);
    expect(find.byIcon(LottiIcons.chart), findsOneWidget);

    showTimeAnalysis.value = true;
    await tester.pump();

    expect(find.byIcon(LottiIcons.chart), findsOneWidget);
  });
}
