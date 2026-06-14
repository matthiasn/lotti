import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/settings_v2/ui/mobile/settings_mobile_branch_page.dart';
import 'package:lotti/features/settings_v2/ui/mobile/settings_mobile_shell.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/consts.dart';

import '../../../../widget_test_utils.dart';

List<Override> _flags({bool habits = true, bool dashboards = true}) => [
  configFlagProvider(
    enableMatrixFlag,
  ).overrideWith((ref) => Stream.value(true)),
  configFlagProvider(
    enableHabitsPageFlag,
  ).overrideWith((ref) => Stream.value(habits)),
  configFlagProvider(
    enableDashboardsPageFlag,
  ).overrideWith((ref) => Stream.value(dashboards)),
  configFlagProvider(
    enableWhatsNewFlag,
  ).overrideWith((ref) => Stream.value(false)),
];

Future<void> _pump(
  WidgetTester tester, {
  required String branchId,
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    makeTestableWidgetNoScroll(
      SettingsMobileBranchPage(branchId: branchId),
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

  testWidgets('definitions hub lists its children and shows a back button', (
    tester,
  ) async {
    await _pump(tester, branchId: 'definitions', overrides: _flags());
    expect(find.text('Categories'), findsOneWidget);
    expect(find.text('Labels'), findsOneWidget);
    expect(find.text('Measurables'), findsOneWidget);
    expect(find.text('Habits'), findsOneWidget);
    expect(find.text('Dashboards'), findsOneWidget);
    final shell = tester.widget<SettingsMobileShell>(
      find.byType(SettingsMobileShell),
    );
    expect(shell.showBack, isTrue);
  });

  testWidgets('definitions hub honours habit/dashboard gating', (tester) async {
    await _pump(
      tester,
      branchId: 'definitions',
      overrides: _flags(habits: false, dashboards: false),
    );
    expect(find.text('Categories'), findsOneWidget);
    expect(find.text('Habits'), findsNothing);
    expect(find.text('Dashboards'), findsNothing);
  });

  testWidgets('tapping a child beams to its (flat) leaf URL', (tester) async {
    await _pump(tester, branchId: 'definitions', overrides: _flags());
    await tester.tap(find.text('Categories'));
    await tester.pump();
    expect(beamed, '/settings/categories');
  });

  testWidgets('advanced hub lists its tooling children', (tester) async {
    await _pump(tester, branchId: 'advanced', overrides: _flags());
    expect(find.text('Config Flags'), findsOneWidget);
    expect(find.text('About Lotti'), findsOneWidget);
  });
}
