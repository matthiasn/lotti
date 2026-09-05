import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/impact_sidebar_entry.dart';
import 'package:lotti/features/design_system/components/navigation/sidebar_subsection.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:material_ui/material_ui.dart';
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
    expect(find.byIcon(LottiIcons.eco), findsOneWidget);
    expect(find.byType(SidebarSubsectionSurface), findsOneWidget);
    expect(find.byType(SidebarSubsectionAction), findsOneWidget);
  });

  testWidgets('bolds the label when the impact route is showing', (
    tester,
  ) async {
    // No longer an icon swap: `leaf` is stroke-only like the rest of Lucide,
    // so the entry passes no activeIcon and the row's own treatment carries
    // the state. `isNotNull` proved nothing either way, so this compares the
    // two states instead.
    await tester.pumpWidget(makeTestableWidget(const ImpactSidebarEntry()));
    await tester.pump();
    final inactive = tester
        .widget<Text>(find.text('AI Impact'))
        .style
        ?.fontWeight;

    showAiImpact.value = true;
    await tester.pump();

    final active = tester
        .widget<Text>(find.text('AI Impact'))
        .style
        ?.fontWeight;
    expect(active, isNot(inactive));
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
    expect(find.byIcon(LottiIcons.eco), findsOneWidget);

    showAiImpact.value = true;
    await tester.pump();

    expect(find.byIcon(LottiIcons.eco), findsOneWidget);
  });
}
