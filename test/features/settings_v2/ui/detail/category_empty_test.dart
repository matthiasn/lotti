import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/settings_v2/domain/settings_node.dart';
import 'package:lotti/features/settings_v2/ui/detail/category_empty.dart';
import 'package:lotti/features/settings_v2/ui/detail/disable_v2_button.dart';

import '../../../../widget_test_utils.dart';

SettingsNode _syncBranch({String desc = 'Configure sync'}) => SettingsNode(
  id: 'sync',
  icon: Icons.sync_rounded,
  title: 'Sync',
  desc: desc,
  children: const [
    SettingsNode(
      id: 'sync/backfill',
      icon: Icons.cloud_download_outlined,
      title: 'Backfill',
      desc: '',
      panel: 'sync-backfill',
    ),
  ],
);

Future<void> _pump(WidgetTester tester, SettingsNode node) async {
  await setUpTestGetIt();
  addTearDown(tearDownTestGetIt);
  await tester.pumpWidget(
    makeTestableWidgetNoScroll(
      Material(
        child: SizedBox(
          width: 600,
          height: 600,
          child: CategoryEmpty(node: node),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('CategoryEmpty — content', () {
    testWidgets('renders the branch icon', (tester) async {
      await _pump(tester, _syncBranch());
      expect(find.byIcon(Icons.sync_rounded), findsOneWidget);
    });

    testWidgets("renders the branch's title as heading", (tester) async {
      await _pump(tester, _syncBranch());
      expect(find.text('Sync'), findsOneWidget);
    });

    testWidgets("renders the branch's description when non-empty", (
      tester,
    ) async {
      await _pump(tester, _syncBranch(desc: 'Multi-device sync'));
      expect(find.text('Multi-device sync'), findsOneWidget);
    });

    testWidgets('description block is omitted when desc is empty', (
      tester,
    ) async {
      await _pump(tester, _syncBranch(desc: ''));
      expect(find.text(''), findsNothing);
    });

    testWidgets('renders the "pick a sub-setting" helper line', (tester) async {
      await _pump(tester, _syncBranch());
      expect(find.text('Pick a sub-setting on the left.'), findsOneWidget);
    });
  });

  group('CategoryEmpty — escape hatch', () {
    testWidgets('does NOT render the DisableV2Button (user can collapse)', (
      tester,
    ) async {
      await _pump(tester, _syncBranch());
      expect(find.byType(DisableV2Button), findsNothing);
    });
  });
}
