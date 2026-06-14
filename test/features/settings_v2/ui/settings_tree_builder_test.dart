import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/settings_v2/domain/settings_node.dart';
import 'package:lotti/features/settings_v2/ui/settings_tree_builder.dart';
import 'package:lotti/utils/consts.dart';

import '../../../widget_test_utils.dart';

List<Override> _flags({
  bool matrix = true,
  bool habits = true,
  bool dashboards = true,
  bool whatsNew = false,
}) => [
  configFlagProvider(
    enableMatrixFlag,
  ).overrideWith((ref) => Stream.value(matrix)),
  configFlagProvider(
    enableHabitsPageFlag,
  ).overrideWith((ref) => Stream.value(habits)),
  configFlagProvider(
    enableDashboardsPageFlag,
  ).overrideWith((ref) => Stream.value(dashboards)),
  configFlagProvider(
    enableWhatsNewFlag,
  ).overrideWith((ref) => Stream.value(whatsNew)),
];

/// Pumps a consumer that captures the tree built by [watchSettingsTree].
Future<List<SettingsNode>> _buildTree(
  WidgetTester tester, {
  required List<Override> overrides,
}) async {
  late List<SettingsNode> tree;
  await tester.pumpWidget(
    makeTestableWidgetNoScroll(
      Consumer(
        builder: (context, ref, _) {
          tree = watchSettingsTree(context, ref);
          return const SizedBox.shrink();
        },
      ),
      overrides: overrides,
    ),
  );
  // Let the overridden config-flag streams emit so the captured tree
  // reflects the resolved flag values, not the initial loading state.
  await tester.pumpAndSettle();
  return tree;
}

Set<String> _ids(List<SettingsNode> nodes) {
  final ids = <String>{};
  void walk(List<SettingsNode> ns) {
    for (final n in ns) {
      ids.add(n.id);
      if (n.children != null) walk(n.children!);
    }
  }

  walk(nodes);
  return ids;
}

void main() {
  testWidgets('top level matches the desktop tree order', (tester) async {
    final tree = await _buildTree(tester, overrides: _flags());
    expect(
      tree.map((n) => n.id).toList(),
      ['ai', 'agents', 'sync', 'definitions', 'theming', 'advanced'],
    );
  });

  // NOTE: one pumpWidget per scenario — ProviderScope overrides are read
  // at mount, so two _buildTree calls in a single test would reuse the
  // first call's overrides.

  testWidgets('sync branch is present when the matrix flag is on', (
    tester,
  ) async {
    final ids = _ids(await _buildTree(tester, overrides: _flags()));
    expect(ids.contains('sync'), isTrue);
  });

  testWidgets('matrix flag off drops the entire sync branch', (tester) async {
    final ids = _ids(
      await _buildTree(tester, overrides: _flags(matrix: false)),
    );
    expect(ids.contains('sync'), isFalse);
  });

  testWidgets('habits and dashboards flags gate their definition leaves', (
    tester,
  ) async {
    final ids = _ids(
      await _buildTree(
        tester,
        overrides: _flags(habits: false, dashboards: false),
      ),
    );
    expect(ids.contains('definitions/habits'), isFalse);
    expect(ids.contains('definitions/dashboards'), isFalse);
    // Always-on definition leaves remain.
    expect(ids.contains('definitions/categories'), isTrue);
    expect(ids.contains('definitions/measurables'), isTrue);
  });

  testWidgets('whats-new is absent when its flag is off', (tester) async {
    final ids = _ids(await _buildTree(tester, overrides: _flags()));
    expect(ids.contains('whats-new'), isFalse);
  });

  testWidgets('whats-new appears when its flag is on', (tester) async {
    final ids = _ids(
      await _buildTree(tester, overrides: _flags(whatsNew: true)),
    );
    expect(ids.contains('whats-new'), isTrue);
  });
}
