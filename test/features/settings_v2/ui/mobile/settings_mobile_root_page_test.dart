import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/settings_v2/ui/mobile/settings_mobile_root_page.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/consts.dart';

import '../../../../widget_test_utils.dart';

List<Override> _flags({bool matrix = true, bool whatsNew = false}) => [
  configFlagProvider(
    enableMatrixFlag,
  ).overrideWith((ref) => Stream.value(matrix)),
  configFlagProvider(
    enableHabitsPageFlag,
  ).overrideWith((ref) => Stream.value(true)),
  configFlagProvider(
    enableDashboardsPageFlag,
  ).overrideWith((ref) => Stream.value(true)),
  configFlagProvider(
    enableWhatsNewFlag,
  ).overrideWith((ref) => Stream.value(whatsNew)),
];

Future<void> _pump(
  WidgetTester tester, {
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    makeTestableWidgetNoScroll(
      const SettingsMobileRootPage(),
      overrides: overrides,
    ),
  );
  await tester.pump();
}

void main() {
  String? beamed;

  setUp(() {
    beamed = null;
    beamToNamedOverride = (path) => beamed = path;
  });

  tearDown(() => beamToNamedOverride = null);

  testWidgets('renders the top-level settings sections', (tester) async {
    await _pump(tester, overrides: _flags());
    // Onboarding is unconditional — it has no flag of its own.
    expect(find.text('Onboarding'), findsOneWidget);
    expect(find.text('AI Settings'), findsOneWidget);
    expect(find.text('Agents'), findsOneWidget);
    expect(find.text('Sync Settings'), findsOneWidget);
    expect(find.text('Definitions'), findsOneWidget);
    expect(find.text('Theming'), findsOneWidget);
    // The list outgrows the viewport, so the tail needs scrolling into view.
    for (final title in const ['Keyboard shortcuts', 'Advanced Settings']) {
      await tester.scrollUntilVisible(find.text(title), 200);
      expect(find.text(title), findsOneWidget);
    }
  });

  testWidgets('hides Sync when the matrix flag is off', (tester) async {
    await _pump(tester, overrides: _flags(matrix: false));
    expect(find.text('Sync Settings'), findsNothing);
    // The rest of the menu still renders.
    expect(find.text('Definitions'), findsOneWidget);
  });

  testWidgets('tapping a section beams to its settings route', (tester) async {
    await _pump(tester, overrides: _flags());
    // Theming sits near the bottom of a list that outgrows the viewport.
    // `ensureVisible` scrolls it in without leaving drag momentum that would
    // swallow the tap.
    await tester.ensureVisible(find.text('Theming'));
    await tester.pump();
    await tester.tap(find.text('Theming'));
    await tester.pump();
    expect(beamed, '/settings/theming');
  });

  testWidgets('tapping Definitions beams into the Definitions hub', (
    tester,
  ) async {
    await _pump(tester, overrides: _flags());
    await tester.tap(find.text('Definitions'));
    await tester.pump();
    expect(beamed, '/settings/definitions');
  });
}
