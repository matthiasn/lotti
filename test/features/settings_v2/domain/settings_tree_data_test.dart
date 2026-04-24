import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/settings_v2/domain/settings_node.dart';
import 'package:lotti/features/settings_v2/domain/settings_tree_data.dart';

/// Deterministic labels keyed off the node id — keeps the tests
/// focused on tree *shape* (which ids appear, in what order, with
/// what parent/child relationship) rather than string equality.
SettingsTreeLabel _labels(String id) => (title: 'title:$id', desc: 'desc:$id');

List<SettingsNode> _tree({
  bool enableAgents = true,
  bool enableHabits = true,
  bool enableDashboards = true,
  bool enableMatrix = true,
  bool enableWhatsNew = true,
}) => buildSettingsTree(
  labels: _labels,
  enableAgents: enableAgents,
  enableHabits: enableHabits,
  enableDashboards: enableDashboards,
  enableMatrix: enableMatrix,
  enableWhatsNew: enableWhatsNew,
);

Set<String> _ids(List<SettingsNode> nodes) {
  final out = <String>{};
  void walk(List<SettingsNode> list) {
    for (final n in list) {
      out.add(n.id);
      final c = n.children;
      if (c != null) walk(c);
    }
  }

  walk(nodes);
  return out;
}

void main() {
  group('buildSettingsTree — labels', () {
    test('every node is populated via the passed label resolver', () {
      final tree = _tree();
      final seen = <String>{};
      void walk(List<SettingsNode> nodes) {
        for (final n in nodes) {
          seen.add(n.id);
          expect(n.title, 'title:${n.id}', reason: 'title for ${n.id}');
          expect(n.desc, 'desc:${n.id}', reason: 'desc for ${n.id}');
          final c = n.children;
          if (c != null) walk(c);
        }
      }

      walk(tree);
      expect(seen, isNotEmpty);
    });
  });

  group('buildSettingsTree — always-on nodes', () {
    test('root order is stable with every flag on', () {
      final rootIds = _tree().map((n) => n.id).toList();
      expect(rootIds, [
        'whats-new',
        'ai',
        'agents',
        'habits',
        'categories',
        'labels',
        'sync',
        'dashboards',
        'measurables',
        'theming',
        'flags',
        'advanced',
      ]);
    });

    test('categories, labels, measurables, theming, flags always present', () {
      final ids = _ids(
        _tree(
          enableAgents: false,
          enableHabits: false,
          enableDashboards: false,
          enableMatrix: false,
          enableWhatsNew: false,
        ),
      );
      expect(
        ids,
        containsAll(<String>[
          'categories',
          'labels',
          'measurables',
          'theming',
          'flags',
        ]),
      );
    });

    test('AI and Advanced branches are unconditional', () {
      final ids = _ids(
        _tree(
          enableAgents: false,
          enableHabits: false,
          enableDashboards: false,
          enableMatrix: false,
          enableWhatsNew: false,
        ),
      );
      expect(
        ids,
        containsAll(<String>[
          'ai',
          'ai/profiles',
          'advanced',
          'advanced/logging',
          'advanced/conflicts',
          'advanced/maintenance',
          'advanced/about',
        ]),
      );
    });
  });

  group('buildSettingsTree — enableWhatsNew', () {
    test('omits whats-new when off', () {
      expect(_ids(_tree(enableWhatsNew: false)), isNot(contains('whats-new')));
    });

    test('includes whats-new with no badge when on', () {
      final whatsNew = _tree().firstWhere((n) => n.id == 'whats-new');
      expect(whatsNew.badge, isNull);
    });
  });

  group('buildSettingsTree — enableAgents', () {
    test('omits the Agents branch and all its children when off', () {
      final ids = _ids(_tree(enableAgents: false));
      expect(ids, isNot(contains('agents')));
      expect(ids, isNot(contains('agents/templates')));
      expect(ids, isNot(contains('agents/souls')));
      expect(ids, isNot(contains('agents/instances')));
    });

    test('emits Agents with three leaves and no badge when on', () {
      final agents = _tree().firstWhere((n) => n.id == 'agents');
      expect(agents.hasChildren, isTrue);
      expect(agents.children!.map((n) => n.id).toList(), [
        'agents/templates',
        'agents/souls',
        'agents/instances',
      ]);
      expect(agents.badge, isNull);
    });
  });

  group('buildSettingsTree — enableHabits', () {
    test('omits habits when off', () {
      expect(_ids(_tree(enableHabits: false)), isNot(contains('habits')));
    });

    test('renders habits as a leaf with the habits panel when on', () {
      final habits = _tree().firstWhere((n) => n.id == 'habits');
      expect(habits.hasChildren, isFalse);
      expect(habits.panel, 'habits');
    });
  });

  group('buildSettingsTree — enableDashboards', () {
    test('omits dashboards when off', () {
      expect(
        _ids(_tree(enableDashboards: false)),
        isNot(contains('dashboards')),
      );
    });

    test('renders dashboards as a leaf with the dashboards panel when on', () {
      final dashboards = _tree().firstWhere((n) => n.id == 'dashboards');
      expect(dashboards.hasChildren, isFalse);
      expect(dashboards.panel, 'dashboards');
    });
  });

  group('buildSettingsTree — enableMatrix', () {
    test('omits the Sync branch and all its children when off', () {
      final ids = _ids(_tree(enableMatrix: false));
      expect(ids, isNot(contains('sync')));
      expect(ids, isNot(contains('sync/backfill')));
      expect(ids, isNot(contains('sync/stats')));
      expect(ids, isNot(contains('sync/outbox')));
      expect(ids, isNot(contains('sync/matrix-maintenance')));
    });

    test(
      'emits Sync with exactly backfill/stats/outbox/matrix-maintenance',
      () {
        final sync = _tree().firstWhere((n) => n.id == 'sync');
        expect(sync.hasChildren, isTrue);
        expect(sync.children!.map((n) => n.id).toList(), [
          'sync/backfill',
          'sync/stats',
          'sync/outbox',
          'sync/matrix-maintenance',
        ]);
      },
    );
  });

  group('buildSettingsTree — panel assignments', () {
    test('every leaf registered with the expected panel id', () {
      final leafPanels = <String, String>{};
      void walk(List<SettingsNode> nodes) {
        for (final n in nodes) {
          final c = n.children;
          if (c == null) {
            expect(n.panel, isNotNull, reason: '${n.id} leaf needs a panel');
            leafPanels[n.id] = n.panel!;
          } else {
            walk(c);
          }
        }
      }

      walk(_tree());
      expect(leafPanels, {
        'whats-new': 'whats-new',
        'ai/profiles': 'ai-profiles',
        'agents/templates': 'agents-templates',
        'agents/souls': 'agents-souls',
        'agents/instances': 'agents-instances',
        'habits': 'habits',
        'categories': 'categories',
        'labels': 'labels',
        'sync/backfill': 'sync-backfill',
        'sync/stats': 'sync-stats',
        'sync/outbox': 'sync-outbox',
        'sync/matrix-maintenance': 'sync-matrix-maintenance',
        'dashboards': 'dashboards',
        'measurables': 'measurables',
        'theming': 'theming',
        'flags': 'flags',
        'advanced/logging': 'advanced-logging',
        'advanced/conflicts': 'advanced-conflicts',
        'advanced/maintenance': 'advanced-maintenance',
        'advanced/about': 'advanced-about',
      });
    });

    test('branch nodes have no panel', () {
      for (final id in ['ai', 'agents', 'sync', 'advanced']) {
        final tree = _tree();
        final node = SettingsTreeIndexTestHelper.findInTree(tree, id);
        expect(node, isNotNull, reason: 'expected $id to be present');
        expect(node!.panel, isNull, reason: '$id is a branch, no panel');
      }
    });
  });

  group('buildSettingsTree — child ordering', () {
    test('AI has Profiles only', () {
      final ai = _tree().firstWhere((n) => n.id == 'ai');
      expect(ai.children!.map((n) => n.id).toList(), ['ai/profiles']);
    });

    test('Advanced has logging / conflicts / maintenance / about in order', () {
      final advanced = _tree().firstWhere((n) => n.id == 'advanced');
      expect(advanced.children!.map((n) => n.id).toList(), [
        'advanced/logging',
        'advanced/conflicts',
        'advanced/maintenance',
        'advanced/about',
      ]);
    });
  });

  group('buildSettingsTree — flag combinations', () {
    test('every flag off: minimal always-on tree', () {
      final ids = _tree(
        enableAgents: false,
        enableHabits: false,
        enableDashboards: false,
        enableMatrix: false,
        enableWhatsNew: false,
      ).map((n) => n.id).toList();

      expect(ids, [
        'ai',
        'categories',
        'labels',
        'measurables',
        'theming',
        'flags',
        'advanced',
      ]);
    });

    test(
      'sync flag independence: toggling Matrix does not affect siblings',
      () {
        final on = _tree();
        final off = _tree(enableMatrix: false);

        final onWithoutSync = on
            .where((n) => !n.id.startsWith('sync'))
            .map((n) => n.id)
            .toList();
        final offIds = off.map((n) => n.id).toList();

        expect(offIds, onWithoutSync);
      },
    );
  });
}

/// Local helper that walks the whole tree to find a node by id —
/// keeps the test file independent of `SettingsTreeIndex` so the
/// tree-data tests don't reach into another implementation.
class SettingsTreeIndexTestHelper {
  static SettingsNode? findInTree(List<SettingsNode> tree, String id) {
    for (final n in tree) {
      if (n.id == id) return n;
      final c = n.children;
      if (c != null) {
        final hit = findInTree(c, id);
        if (hit != null) return hit;
      }
    }
    return null;
  }
}
