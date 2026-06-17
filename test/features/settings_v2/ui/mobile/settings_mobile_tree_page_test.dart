import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/settings_v2/domain/settings_node.dart';
import 'package:lotti/features/settings_v2/ui/mobile/settings_mobile_shell.dart';
import 'package:lotti/features/settings_v2/ui/mobile/settings_mobile_tree_page.dart';
import 'package:lotti/features/settings_v2/ui/tree/settings_tree_row.dart';

import '../../../../widget_test_utils.dart';

const _branch = SettingsNode(
  id: 'definitions',
  icon: Icons.account_tree_outlined,
  title: 'Definitions',
  desc: 'Habits, categories, labels',
  children: [
    SettingsNode(
      id: 'definitions/categories',
      icon: Icons.category_rounded,
      title: 'Categories',
      desc: 'Categories with AI settings',
      panel: 'categories',
    ),
  ],
);

const _leaf = SettingsNode(
  id: 'theming',
  icon: Icons.palette_outlined,
  title: 'Theming',
  desc: 'Customize app appearance',
  panel: 'theming',
);

Future<void> pump(
  WidgetTester tester, {
  required void Function(SettingsNode) onNodeTap,
  bool showBack = false,
  List<SettingsNode> nodes = const [_branch, _leaf],
  Widget? header,
}) async {
  await tester.pumpWidget(
    makeTestableWidgetNoScroll(
      SettingsMobileTreePage(
        title: 'Settings',
        nodes: nodes,
        showBack: showBack,
        header: header,
        onNodeTap: onNodeTap,
      ),
    ),
  );
  // Elapse the BackWidget's 1s fade-in (shown when showBack is true) so
  // no animation timer is left pending.
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('renders a row per node with title and description', (
    tester,
  ) async {
    await pump(tester, onNodeTap: (_) {});
    expect(find.byType(SettingsTreeRow), findsNWidgets(2));
    expect(find.text('Definitions'), findsOneWidget);
    expect(find.text('Habits, categories, labels'), findsOneWidget);
    expect(find.text('Theming'), findsOneWidget);
  });

  testWidgets('tapping a row reports the tapped node', (tester) async {
    SettingsNode? tapped;
    await pump(tester, onNodeTap: (node) => tapped = node);
    await tester.tap(find.text('Theming'));
    await tester.pump();
    expect(tapped?.id, 'theming');
  });

  testWidgets('leaf rows expose a navigational chevron', (tester) async {
    await pump(tester, onNodeTap: (_) {});
    // Both the branch and the leaf show a chevron on the drill-down
    // surface (every row pushes a page), unlike the desktop tree where
    // leaves select in place and carry no chevron.
    expect(find.byIcon(Icons.chevron_right_rounded), findsNWidgets(2));
  });

  testWidgets('rows drop the active-path rail (no dead left gutter)', (
    tester,
  ) async {
    await pump(tester, onNodeTap: (_) {});
    final rows = tester.widgetList<SettingsTreeRow>(
      find.byType(SettingsTreeRow),
    );
    expect(rows, isNotEmpty);
    expect(rows.every((r) => !r.showActiveRail), isTrue);
  });

  testWidgets('passes showBack through to the shell', (tester) async {
    await pump(tester, onNodeTap: (_) {}, showBack: true);
    final shell = tester.widget<SettingsMobileShell>(
      find.byType(SettingsMobileShell),
    );
    expect(shell.showBack, isTrue);
  });

  testWidgets('renders an optional header above the rows', (tester) async {
    await pump(
      tester,
      onNodeTap: (_) {},
      header: const Text('landing-panel-header'),
    );
    expect(find.text('landing-panel-header'), findsOneWidget);
    // Header is the first list child, ahead of every node row.
    final headerY = tester.getTopLeft(find.text('landing-panel-header')).dy;
    final firstRowY = tester.getTopLeft(find.byType(SettingsTreeRow).first).dy;
    expect(headerY, lessThan(firstRowY));
  });

  testWidgets('omits the header region when none is supplied', (tester) async {
    await pump(tester, onNodeTap: (_) {});
    expect(find.text('landing-panel-header'), findsNothing);
    expect(find.byType(SettingsTreeRow), findsNWidgets(2));
  });
}
