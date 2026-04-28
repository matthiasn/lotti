import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/settings_v2/state/settings_tree_controller.dart';
import 'package:lotti/features/settings_v2/ui/tree/settings_tree_node_widget.dart';
import 'package:lotti/features/settings_v2/ui/tree/settings_tree_row.dart';
import 'package:lotti/features/settings_v2/ui/tree/settings_tree_view.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../widget_test_utils.dart';

/// Stubs the feature flags the tree reads and pumps the view at a
/// desktop-sized viewport.
Future<void> _pumpView(
  WidgetTester tester, {
  Map<String, bool> flags = const {},
}) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final mocks = await setUpTestGetIt();
  addTearDown(tearDownTestGetIt);
  when(() => mocks.journalDb.watchConfigFlag(any())).thenAnswer(
    (invocation) {
      final name = invocation.positionalArguments.first as String;
      return Stream.value(flags[name] ?? false);
    },
  );

  await tester.pumpWidget(
    makeTestableWidgetNoScroll(
      const Material(
        child: SizedBox(
          width: 400,
          height: 900,
          child: SettingsTreeView(),
        ),
      ),
      overrides: [journalDbProvider.overrideWithValue(mocks.journalDb)],
    ),
  );
  await tester.pump();
}

void main() {
  group('SettingsTreeView — flag-off baseline', () {
    testWidgets(
      'renders every always-on top-level section (categories, labels, '
      'measurables, theming, flags, ai, sync, advanced)',
      (tester) async {
        await _pumpView(tester);
        expect(find.text('AI Settings'), findsOneWidget);
        expect(find.text('Categories'), findsOneWidget);
        expect(find.text('Labels'), findsOneWidget);
        expect(find.text('Measurable Types'), findsOneWidget);
        expect(find.text('Theming'), findsOneWidget);
        expect(find.text('Config Flags'), findsOneWidget);
        // Sync stays visible regardless of Matrix so the Conflicts
        // leaf inside it is always reachable.
        expect(find.text('Sync Settings'), findsOneWidget);
        expect(find.text('Advanced Settings'), findsOneWidget);
      },
    );

    testWidgets('does NOT render flag-gated sections when flags are off', (
      tester,
    ) async {
      await _pumpView(tester);
      expect(find.text("What's New"), findsNothing);
      expect(find.text('Agents'), findsNothing);
      expect(find.text('Habits'), findsNothing);
      expect(find.text('Dashboards'), findsNothing);
    });
  });

  group('SettingsTreeView — flag-gated visibility', () {
    testWidgets(
      'enableMatrix on surfaces the matrix-only Sync leaves',
      (tester) async {
        await _pumpView(tester, flags: {enableMatrixFlag: true});
        // Sync branch is always visible; Matrix gates the leaves
        // inside it.
        expect(find.text('Sync Settings'), findsOneWidget);
      },
    );

    testWidgets('enableAgents on surfaces the Agents branch', (tester) async {
      await _pumpView(tester, flags: {enableAgentsFlag: true});
      expect(find.text('Agents'), findsOneWidget);
    });

    testWidgets('enableHabits on surfaces the Habits leaf', (tester) async {
      await _pumpView(tester, flags: {enableHabitsPageFlag: true});
      expect(find.text('Habits'), findsOneWidget);
    });

    testWidgets('enableDashboards on surfaces the Dashboards leaf', (
      tester,
    ) async {
      await _pumpView(tester, flags: {enableDashboardsPageFlag: true});
      expect(find.text('Dashboards'), findsOneWidget);
    });

    testWidgets("enableWhatsNew on surfaces the What's New leaf", (
      tester,
    ) async {
      await _pumpView(tester, flags: {enableWhatsNewFlag: true});
      expect(find.text("What's New"), findsOneWidget);
    });
  });

  group('SettingsTreeView — root node widgets', () {
    testWidgets(
      'every root node renders through SettingsTreeNodeWidget (not raw rows)',
      (tester) async {
        // With every flag off the root list is the always-on set
        // declared in `buildSettingsTree`: ai, categories, labels,
        // sync, measurables, theming, flags, advanced. Sync stays
        // visible so the always-on Conflicts leaf inside it remains
        // reachable. A depth-0 `SettingsTreeNodeWidget` per root
        // proves every entry rendered through the widget, not a raw
        // row.
        await _pumpView(tester);
        final rootNodeFinder = find.byWidgetPredicate(
          (w) => w is SettingsTreeNodeWidget && w.depth == 0,
        );
        expect(rootNodeFinder, findsNWidgets(8));
        for (final title in const [
          'AI Settings',
          'Categories',
          'Labels',
          'Sync Settings',
          'Measurable Types',
          'Theming',
          'Config Flags',
          'Advanced Settings',
        ]) {
          expect(
            find.descendant(of: rootNodeFinder, matching: find.text(title)),
            findsOneWidget,
            reason: 'root node "$title" should render through the widget',
          );
        }
      },
    );

    testWidgets(
      'tapping a leaf row updates settingsTreePathProvider to its id',
      (tester) async {
        await _pumpView(tester);
        final flagsRow = find.ancestor(
          of: find.text('Config Flags'),
          matching: find.byType(SettingsTreeRow),
        );
        await tester.tap(flagsRow);
        await tester.pump();
        final container = ProviderScope.containerOf(
          tester.element(find.byType(SettingsTreeView)),
          listen: false,
        );
        expect(container.read(settingsTreePathProvider), ['flags']);
      },
    );
  });
}
