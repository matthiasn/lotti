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

List<Override> _flags({
  bool habits = true,
  bool dashboards = true,
  bool speechTts = false,
}) => [
  configFlagProvider(
    enableAiSummaryTtsFlag,
  ).overrideWith((ref) => Stream.value(speechTts)),
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

  testWidgets(
    'preferences hub lists its children in tree order, with a back button',
    (tester) async {
      await _pump(
        tester,
        branchId: 'preferences',
        overrides: _flags(speechTts: true),
      );
      final rowIds = tester
          .widgetList<SettingsTreeRow>(find.byType(SettingsTreeRow))
          .map((row) => row.node.id)
          .toList();
      expect(rowIds, [
        'preferences/theming',
        'preferences/animations',
        'preferences/recording-style',
        'preferences/speech',
        'preferences/keyboard-shortcuts',
      ]);
      final shell = tester.widget<SettingsMobileShell>(
        find.byType(SettingsMobileShell),
      );
      expect(shell.showBack, isTrue);
    },
  );

  testWidgets('preferences hub honours the speech (TTS) flag', (tester) async {
    await _pump(tester, branchId: 'preferences', overrides: _flags());
    expect(find.text('Speech'), findsNothing);
    // The unconditional siblings still render.
    expect(find.text('Theming'), findsOneWidget);
    expect(find.text('Keyboard shortcuts'), findsOneWidget);
    expect(find.text('Recording Style'), findsOneWidget);
  });

  testWidgets(
    'tapping a preference child beams to its flat, legacy-compatible URL',
    (tester) async {
      // The node id is `preferences/theming`, but the URL that ships and
      // that old links point at is still `/settings/theming`.
      await _pump(tester, branchId: 'preferences', overrides: _flags());
      await tester.tap(find.byKey(const ValueKey('preferences/theming')));
      await tester.pump();
      expect(beamed, '/settings/theming');
    },
  );

  testWidgets(
    'every preference child beams to the URL it had before the regrouping',
    (tester) async {
      await _pump(
        tester,
        branchId: 'preferences',
        overrides: _flags(speechTts: true),
      );
      const expected = {
        'preferences/theming': '/settings/theming',
        // Animations came from Advanced and kept that URL.
        'preferences/animations': '/settings/advanced/animations',
        'preferences/recording-style': '/settings/recording-style',
        'preferences/speech': '/settings/speech',
        'preferences/keyboard-shortcuts': '/settings/keyboard-shortcuts',
      };
      for (final entry in expected.entries) {
        await tester.tap(find.byKey(ValueKey(entry.key)));
        await tester.pump();
        expect(beamed, entry.value, reason: entry.key);
      }
    },
  );

  testWidgets('preferences hub renders no landing-panel header', (
    tester,
  ) async {
    // `preferences` is a pure branch: it carries no `panel`, so the hub
    // must show rows only. A branch panel here would have to be
    // scrollable: false-safe (see the assert the hub carries).
    await _pump(tester, branchId: 'preferences', overrides: _flags());
    expect(find.byType(SyncSetupEmptyState), findsNothing);
  });

  testWidgets('advanced hub lists its tooling children', (tester) async {
    await _pump(tester, branchId: 'advanced', overrides: _flags());
    expect(find.text('Config Flags'), findsOneWidget);
    expect(find.text('About Lotti'), findsOneWidget);
  });

  testWidgets('advanced hub no longer lists Animations', (tester) async {
    // It is a matter of taste, not a maintenance tool, so it now sits in
    // Preferences. Appearing in both hubs would be the regression.
    await _pump(tester, branchId: 'advanced', overrides: _flags());
    expect(find.text('Animations'), findsNothing);
  });

  testWidgets(
    'pure-navigation hubs render no landing-panel header',
    (tester) async {
      await _pump(tester, branchId: 'definitions', overrides: _flags());
      // `definitions` has no `panel`, so no provisioned card leaks in.
      expect(find.byType(SyncSetupEmptyState), findsNothing);
    },
  );

  testWidgets(
    'sync hub renders its children with no landing-panel header, in the '
    'shared-tree order with Devices first',
    (tester) async {
      await _pump(tester, branchId: 'sync', overrides: _flags());

      // The `sync` branch no longer carries a landing panel, so the
      // provisioned card is not rendered as a header here — it is reached
      // via the `sync/provisioned` leaf row instead.
      expect(find.byType(SyncSetupEmptyState), findsNothing);

      // Children come straight from `buildSettingsTree`, so the mobile
      // order matches the desktop sidebar. Devices is the first
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
