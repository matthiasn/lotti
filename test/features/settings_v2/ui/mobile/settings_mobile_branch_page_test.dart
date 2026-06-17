import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/settings_v2/ui/mobile/settings_mobile_branch_page.dart';
import 'package:lotti/features/settings_v2/ui/mobile/settings_mobile_shell.dart';
import 'package:lotti/features/settings_v2/ui/tree/outbox_count_indicator.dart';
import 'package:lotti/features/settings_v2/ui/tree/settings_tree_row.dart';
import 'package:lotti/features/sync/ui/provisioned/provisioned_sync_modal.dart';
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
  // Branch hubs always show the back button; elapse its 1s fade-in so no
  // animation timer is left pending.
  await tester.pump(const Duration(seconds: 1));
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

  testWidgets(
    'pure-navigation hubs render no landing-panel header',
    (tester) async {
      await _pump(tester, branchId: 'definitions', overrides: _flags());
      // `definitions` has no `panel`, so no provisioned card leaks in.
      expect(find.byType(ProvisionedSyncSettingsCard), findsNothing);
    },
  );

  testWidgets(
    'sync hub renders its children with no landing-panel header, in the '
    'shared-tree order with provisioned first',
    (tester) async {
      await _pump(tester, branchId: 'sync', overrides: _flags());

      // The `sync` branch no longer carries a landing panel, so the
      // provisioned card is not rendered as a header here — it is reached
      // via the `sync/provisioned` leaf row instead.
      expect(find.byType(ProvisionedSyncSettingsCard), findsNothing);

      // Children come straight from `buildSettingsTree`, so the mobile
      // order matches the desktop sidebar. Provisioned Sync is the first
      // row, replacing the old header.
      final rowIds = tester
          .widgetList<SettingsTreeRow>(find.byType(SettingsTreeRow))
          .map((row) => row.node.id)
          .toList();
      expect(rowIds, [
        'sync/provisioned',
        'sync/node-profile',
        'sync/backfill',
        'sync/stats',
        'sync/outbox',
        'sync/conflicts',
        'sync/matrix-maintenance',
      ]);

      // The outbox row carries the live pending-count indicator (wired via
      // settingsNodeIndicatorFor) so the at-a-glance backlog count the old
      // SyncSettingsPage showed is preserved on the unified row.
      expect(find.byType(OutboxCountIndicator), findsOneWidget);

      // Sync rows keep the teal icon treatment the standalone page had.
      final rows = tester.widgetList<SettingsTreeRow>(
        find.byType(SettingsTreeRow),
      );
      expect(rows.every((row) => row.accentIcon), isTrue);
    },
  );

  testWidgets(
    'non-sync hubs render grey (non-accent) icons',
    (tester) async {
      await _pump(tester, branchId: 'definitions', overrides: _flags());
      final rows = tester.widgetList<SettingsTreeRow>(
        find.byType(SettingsTreeRow),
      );
      expect(rows.every((row) => !row.accentIcon), isTrue);
    },
  );

  testWidgets(
    'tapping the provisioned-sync row beams to its leaf URL',
    (tester) async {
      await _pump(tester, branchId: 'sync', overrides: _flags());
      await tester.tap(find.byKey(const ValueKey('sync/provisioned')));
      await tester.pump();
      expect(beamed, '/settings/sync/provisioned');
    },
  );

  testWidgets(
    'tapping a sync child beams to its (legacy-compatible) leaf URL',
    (tester) async {
      await _pump(tester, branchId: 'sync', overrides: _flags());
      // Conflicts keeps its legacy `/settings/advanced/conflicts` URL even
      // though the node lives under the `sync` branch.
      await tester.tap(find.byKey(const ValueKey('sync/conflicts')));
      await tester.pump();
      expect(beamed, '/settings/advanced/conflicts');
    },
  );

  testWidgets(
    'asserts when a node reuses a non-scrollable panel as a header',
    (tester) async {
      // `advanced/flags` resolves to the `flags` panel, which is
      // registered with scrollable: false (it owns its own scroll view).
      // Reusing such a body as a hub header would crash inside the hub
      // ListView, so the guard must fire before that can happen.
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const SettingsMobileBranchPage(branchId: 'advanced/flags'),
          overrides: _flags(),
        ),
      );
      expect(tester.takeException(), isA<AssertionError>());
    },
  );
}
