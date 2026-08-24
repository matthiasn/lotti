import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/settings_v2/ui/mobile/settings_mobile_root_page.dart';
import 'package:lotti/features/settings_v2/ui/tree/settings_tree_row.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/consts.dart';

import '../../../../widget_test_utils.dart';

List<Override> _flags({
  bool matrix = true,
  bool whatsNew = false,
  bool speechTts = false,
}) => [
  configFlagProvider(
    enableAiSummaryTtsFlag,
  ).overrideWith((ref) => Stream.value(speechTts)),
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

/// Phone-width viewport, optionally tall enough that the whole root level
/// mounts in a single frame.
///
/// `ListView(children: [...])` only mounts what fits the render viewport plus
/// its cache extent, so at the real 844 pt height an
/// `expect(..., findsNothing)` cannot tell "this row is gone" from "this row
/// is below the fold" — and a regression that put a leaf back at the root
/// would make the list *longer*, which is exactly when such an assertion
/// would start lying. [tallEnoughForWholeLevel] sizes the render surface
/// too, not just the `MediaQuery`, which is what actually mounts every row.
Future<void> _pump(
  WidgetTester tester, {
  List<Override> overrides = const [],
  bool tallEnoughForWholeLevel = false,
}) async {
  const width = 390.0;
  final height = tallEnoughForWholeLevel ? 2000.0 : 844.0;
  tester.view
    ..physicalSize = Size(width, height)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    makeTestableWidgetNoScroll(
      const SettingsMobileRootPage(),
      overrides: overrides,
      mediaQueryData: MediaQueryData(
        size: Size(width, height),
        padding: const EdgeInsets.only(top: 47, bottom: 34),
      ),
    ),
  );
  await tester.pump();
}

/// Ids of every row rendered at the level currently pumped, in order.
List<String> _rowIds(WidgetTester tester) => tester
    .widgetList<SettingsTreeRow>(find.byType(SettingsTreeRow))
    .map((row) => row.node.id)
    .toList();

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
    // The list outgrows the viewport, so the tail needs scrolling into view.
    for (final title in const ['Preferences', 'Advanced Settings']) {
      await tester.scrollUntilVisible(find.text(title), 200);
      expect(find.text(title), findsOneWidget);
    }
  });

  testWidgets('the root level renders exactly the top-level nodes, in order', (
    tester,
  ) async {
    // One exhaustive assertion rather than a spot check: it pins the
    // ordering (Preferences directly above Advanced Settings, which is the
    // point of the grouping) AND proves the four reparented leaves are gone
    // from this level — a leaf put back at the root would show up here as an
    // extra id, wherever in the list it landed.
    //
    // The TTS flag is on, so Speech would be present if it were still a root
    // entry.
    await _pump(
      tester,
      overrides: _flags(speechTts: true),
      tallEnoughForWholeLevel: true,
    );
    expect(_rowIds(tester), [
      'onboarding',
      'ai',
      'agents',
      'daily-os',
      'sync',
      'definitions',
      'preferences',
      'advanced',
      'manual',
    ]);
  });

  testWidgets('hides Sync when the matrix flag is off', (tester) async {
    await _pump(tester, overrides: _flags(matrix: false));
    expect(find.text('Sync Settings'), findsNothing);
    // The rest of the menu still renders.
    expect(find.text('Definitions'), findsOneWidget);
  });

  testWidgets('tapping a section beams to its settings route', (tester) async {
    await _pump(tester, overrides: _flags());
    // Daily OS sits near the bottom of a list that outgrows the viewport.
    // `ensureVisible` scrolls it in without leaving drag momentum that would
    // swallow the tap.
    await tester.ensureVisible(find.text('Daily OS'));
    await tester.pump();
    await tester.tap(find.text('Daily OS'));
    await tester.pump();
    expect(beamed, '/settings/daily-os');
  });

  testWidgets('tapping Preferences beams into the Preferences hub', (
    tester,
  ) async {
    await _pump(tester, overrides: _flags());
    await tester.ensureVisible(find.text('Preferences'));
    await tester.pump();
    await tester.tap(find.text('Preferences'));
    await tester.pump();
    expect(beamed, '/settings/preferences');
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
