import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/impact_sidebar_entry.dart';
import 'package:lotti/features/design_system/components/navigation/sidebar_subsection.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

void main() {
  late MockNavService navService;
  late ValueNotifier<bool> showAiImpact;

  setUp(() async {
    navService = MockNavService();
    showAiImpact = ValueNotifier<bool>(false);
    when(() => navService.desktopShowAiImpact).thenReturn(showAiImpact);
    await setUpTestGetIt(
      additionalSetup: () {
        getIt.registerSingleton<NavService>(navService);
      },
    );
  });

  tearDown(() async {
    await tearDownTestGetIt();
    showAiImpact.dispose();
  });

  testWidgets('renders the localized AI Impact label with the inactive icon '
      'when the route is not showing', (tester) async {
    await tester.pumpWidget(makeTestableWidget(const ImpactSidebarEntry()));
    await tester.pump();

    expect(find.text('AI Impact'), findsOneWidget);
    expect(find.byIcon(Icons.eco_outlined), findsOneWidget);
    expect(find.byIcon(Icons.eco_rounded), findsNothing);
    expect(find.byType(SidebarSubsectionSurface), findsOneWidget);
    expect(find.byType(SidebarSubsectionAction), findsOneWidget);
  });

  testWidgets('switches to the active icon and bold label when the impact '
      'route is showing', (tester) async {
    showAiImpact.value = true;
    await tester.pumpWidget(makeTestableWidget(const ImpactSidebarEntry()));
    await tester.pump();

    expect(find.byIcon(Icons.eco_rounded), findsOneWidget);
    expect(find.byIcon(Icons.eco_outlined), findsNothing);
    final label = tester.widget<Text>(find.text('AI Impact'));
    expect(label.style?.fontWeight, isNotNull);
  });

  testWidgets('beams to /dashboards/impact on tap', (tester) async {
    final beamed = <String>[];
    beamToNamedOverride = beamed.add;
    addTearDown(() => beamToNamedOverride = null);

    await tester.pumpWidget(makeTestableWidget(const ImpactSidebarEntry()));
    await tester.pump();

    await tester.tap(find.text('AI Impact'));
    await tester.pump();
    expect(beamed, ['/dashboards/impact']);
  });

  testWidgets('reacts to highlight flips without a rebuild from above', (
    tester,
  ) async {
    await tester.pumpWidget(makeTestableWidget(const ImpactSidebarEntry()));
    await tester.pump();
    expect(find.byIcon(Icons.eco_outlined), findsOneWidget);

    showAiImpact.value = true;
    await tester.pump();

    expect(find.byIcon(Icons.eco_rounded), findsOneWidget);
  });
}
