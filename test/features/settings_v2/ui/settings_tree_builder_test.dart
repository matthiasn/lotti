import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/profiles/model/profile.dart';
import 'package:lotti/features/profiles/model/profile_context.dart';
import 'package:lotti/features/profiles/state/profile_providers.dart';
import 'package:lotti/features/settings_v2/domain/settings_node.dart';
import 'package:lotti/features/settings_v2/ui/settings_tree_builder.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/platform.dart' as platform;
import 'package:material_ui/material_ui.dart';

import '../../../widget_test_utils.dart';

/// Overrides the active profile with a guest (demo) or real world.
Override _profile({required bool guest}) =>
    profileContextProvider.overrideWithValue(
      ProfileContext.forProfile(
        profile: guest
            ? Profile(
                id: 'demo-guest',
                type: ProfileType.guest,
                name: 'Demo',
                dirName: 'guest_profiles/demo-guest',
                createdAt: DateTime(2026),
              )
            : Profile.realDefault(),
        root: Directory.systemTemp,
      ),
    );

List<Override> _flags({
  bool matrix = true,
  bool habits = true,
  bool dashboards = true,
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
      [
        'onboarding',
        'ai',
        'agents',
        'daily-os',
        'sync',
        'definitions',
        'preferences',
        'advanced',
        'manual',
      ],
    );
  });

  testWidgets('the preferences branch reaches the mobile drill-down too', (
    tester,
  ) async {
    // `watchSettingsTree` is the single source both surfaces build from,
    // so this is what guarantees the mobile root shows Preferences rather
    // than the four loose leaves the desktop sidebar stopped showing.
    final tree = await _buildTree(tester, overrides: _flags());
    final preferences = tree.firstWhere((n) => n.id == 'preferences');
    expect(preferences.children!.map((n) => n.id).toList(), [
      'preferences/theming',
      'preferences/animations',
      'preferences/recording-style',
      'preferences/keyboard-shortcuts',
    ]);
  });

  testWidgets('the TTS flag adds the speech leaf inside preferences', (
    tester,
  ) async {
    // The flag is read by `watchSettingsTree`, not by `buildSettingsTree`
    // directly, so the wiring needs its own coverage: a leaf that lands
    // at the root instead of inside the branch would pass the pure
    // tree-data tests and still regress the menu.
    final ids = _ids(
      await _buildTree(tester, overrides: _flags(speechTts: true)),
    );
    expect(ids.contains('preferences/speech'), isTrue);
  });

  testWidgets('the speech leaf is absent while the TTS flag is off', (
    tester,
  ) async {
    final ids = _ids(await _buildTree(tester, overrides: _flags()));
    expect(ids.contains('preferences/speech'), isFalse);
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

  testWidgets(
    'guest world swaps the sync branch for the explainer tile — '
    'even with the matrix flag on',
    (tester) async {
      final ids = _ids(
        await _buildTree(
          tester,
          overrides: [..._flags(), _profile(guest: true)],
        ),
      );
      expect(ids.contains('sync'), isFalse);
      expect(ids.contains('sync/outbox'), isFalse);
      expect(ids.contains('sync-unavailable'), isTrue);
    },
  );

  testWidgets('real world keeps the full sync branch, no explainer tile', (
    tester,
  ) async {
    final ids = _ids(
      await _buildTree(
        tester,
        overrides: [..._flags(), _profile(guest: false)],
      ),
    );
    expect(ids.contains('sync'), isTrue);
    expect(ids.contains('sync-unavailable'), isFalse);
  });

  testWidgets('guest world hides the mobile health-import leaf', (
    tester,
  ) async {
    final wasMobile = platform.isMobile;
    platform.isMobile = true;
    addTearDown(() => platform.isMobile = wasMobile);

    final ids = _ids(
      await _buildTree(
        tester,
        overrides: [..._flags(), _profile(guest: true)],
      ),
    );
    expect(ids.contains('advanced/health-import'), isFalse);
  });

  testWidgets('real world keeps the mobile health-import leaf', (
    tester,
  ) async {
    final wasMobile = platform.isMobile;
    platform.isMobile = true;
    addTearDown(() => platform.isMobile = wasMobile);

    final ids = _ids(
      await _buildTree(
        tester,
        overrides: [..._flags(), _profile(guest: false)],
      ),
    );
    expect(ids.contains('advanced/health-import'), isTrue);
  });
}
