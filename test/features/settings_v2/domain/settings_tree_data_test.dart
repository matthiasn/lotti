import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/settings_v2/domain/settings_node.dart';
import 'package:lotti/features/settings_v2/domain/settings_tree_data.dart';

/// Deterministic labels keyed off the node id — keeps the tests
/// focused on tree *shape* (which ids appear, in what order, with
/// what parent/child relationship) rather than string equality.
SettingsTreeLabel _labels(String id) => (title: 'title:$id', desc: 'desc:$id');

List<SettingsNode> _tree({
  bool enableHabits = true,
  bool enableDashboards = true,
  bool enableMatrix = true,
  bool enableWhatsNew = true,
}) => buildSettingsTree(
  labels: _labels,
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
      // Entity definitions (habits / categories / labels / dashboards
      // / measurables) collapse into the single `definitions` branch;
      // config flags reparent under `advanced`. Root reads as
      // AI · Agents · Sync · Definitions · Theming · Advanced.
      final rootIds = _tree().map((n) => n.id).toList();
      expect(rootIds, [
        'whats-new',
        'ai',
        'agents',
        'sync',
        'definitions',
        'theming',
        'advanced',
      ]);
    });

    test(
      'categories, labels, measurables, theming, advanced/flags always present',
      () {
        final ids = _ids(
          _tree(
            enableHabits: false,
            enableDashboards: false,
            enableMatrix: false,
            enableWhatsNew: false,
          ),
        );
        expect(
          ids,
          containsAll(<String>[
            'definitions',
            'definitions/categories',
            'definitions/labels',
            'definitions/measurables',
            'theming',
            'advanced/flags',
          ]),
        );
      },
    );

    test('AI, Sync, and Advanced branches are unconditional', () {
      final ids = _ids(
        _tree(
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
          'sync',
          'sync/conflicts',
          'advanced',
          'advanced/logging',
          'advanced/maintenance',
          'advanced/about',
        ]),
      );
    });

    test(
      'sync/conflicts stays reachable regardless of enableMatrix',
      () {
        // Conflicts can predate or outlive Matrix sync (legacy data,
        // local-only divergence). The leaf must remain reachable so
        // turning Matrix off does not strand existing conflicts.
        expect(_ids(_tree()), contains('sync/conflicts'));
        expect(_ids(_tree(enableMatrix: false)), contains('sync/conflicts'));
      },
    );
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

  group('buildSettingsTree — agents branch', () {
    test('children mirror the tab order in AgentSettingsBody', () {
      // Stats / Templates / Instances / Souls / Pending Wakes — same
      // order as the in-page TabBar, so the tree shape matches the
      // right-pane tab strip when the user lands on Agents.
      final agents = _tree().firstWhere((n) => n.id == 'agents');
      expect(agents.hasChildren, isTrue);
      expect(agents.children!.map((n) => n.id).toList(), [
        'agents/stats',
        'agents/templates',
        'agents/instances',
        'agents/souls',
        'agents/pending-wakes',
      ]);
      expect(agents.badge, isNull);
    });
  });

  group('buildSettingsTree — enableHabits', () {
    test('omits habits leaf when off; siblings under definitions remain', () {
      final ids = _ids(_tree(enableHabits: false));
      expect(ids, isNot(contains('definitions/habits')));
      expect(ids, contains('definitions'));
      expect(ids, contains('definitions/categories'));
    });

    test('renders habits leaf under definitions with the habits panel', () {
      final habits = SettingsTreeIndexTestHelper.findInTree(
        _tree(),
        'definitions/habits',
      );
      expect(habits, isNotNull);
      expect(habits!.hasChildren, isFalse);
      expect(habits.panel, 'habits');
    });
  });

  group('buildSettingsTree — enableDashboards', () {
    test(
      'omits dashboards leaf when off; siblings under definitions remain',
      () {
        final ids = _ids(_tree(enableDashboards: false));
        expect(ids, isNot(contains('definitions/dashboards')));
        expect(ids, contains('definitions'));
        expect(ids, contains('definitions/measurables'));
      },
    );

    test(
      'renders dashboards leaf under definitions with the dashboards panel',
      () {
        final dashboards = SettingsTreeIndexTestHelper.findInTree(
          _tree(),
          'definitions/dashboards',
        );
        expect(dashboards, isNotNull);
        expect(dashboards!.hasChildren, isFalse);
        expect(dashboards.panel, 'dashboards');
      },
    );
  });

  group('buildSettingsTree — definitions branch', () {
    test('definitions is a pure branch (no panel) with stable child order', () {
      final definitions = _tree().firstWhere((n) => n.id == 'definitions');
      expect(definitions.panel, isNull);
      expect(definitions.children!.map((n) => n.id).toList(), [
        'definitions/habits',
        'definitions/categories',
        'definitions/labels',
        'definitions/dashboards',
        'definitions/measurables',
      ]);
    });

    test(
      'with habits and dashboards off, definitions keeps its other leaves',
      () {
        final tree = _tree(enableHabits: false, enableDashboards: false);
        final definitions = tree.firstWhere((n) => n.id == 'definitions');
        expect(definitions.children!.map((n) => n.id).toList(), [
          'definitions/categories',
          'definitions/labels',
          'definitions/measurables',
        ]);
      },
    );
  });

  group('buildSettingsTree — advanced/flags reparenting', () {
    test('advanced branch carries flags as its first child', () {
      final advanced = _tree().firstWhere((n) => n.id == 'advanced');
      expect(advanced.children!.map((n) => n.id).toList(), [
        'advanced/flags',
        'advanced/logging',
        'advanced/maintenance',
        'advanced/about',
      ]);
    });

    test('advanced/flags carries the flags panel', () {
      final flags = SettingsTreeIndexTestHelper.findInTree(
        _tree(),
        'advanced/flags',
      );
      expect(flags, isNotNull);
      expect(flags!.panel, 'flags');
    });
  });

  group('buildSettingsTree — enableMatrix', () {
    test('drops only the matrix-specific leaves when off; keeps conflicts', () {
      final ids = _ids(_tree(enableMatrix: false));
      // Sync branch and conflicts leaf remain reachable.
      expect(ids, contains('sync'));
      expect(ids, contains('sync/conflicts'));
      // Matrix-only surfaces are hidden.
      expect(ids, isNot(contains('sync/backfill')));
      expect(ids, isNot(contains('sync/stats')));
      expect(ids, isNot(contains('sync/outbox')));
      expect(ids, isNot(contains('sync/matrix-maintenance')));
    });

    test(
      'emits Sync with exactly backfill/stats/outbox/conflicts/ '
      'matrix-maintenance',
      () {
        final sync = _tree().firstWhere((n) => n.id == 'sync');
        expect(sync.hasChildren, isTrue);
        expect(sync.children!.map((n) => n.id).toList(), [
          'sync/backfill',
          'sync/stats',
          'sync/outbox',
          'sync/conflicts',
          'sync/matrix-maintenance',
        ]);
      },
    );

    test('with Matrix off, Sync collapses to just the conflicts leaf', () {
      final sync = _tree(
        enableMatrix: false,
      ).firstWhere((n) => n.id == 'sync');
      expect(sync.children!.map((n) => n.id).toList(), ['sync/conflicts']);
    });
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
        // AI Settings v4 added per-tab leaves under `ai` so the
        // sidebar exposes Providers / Models / Profiles directly
        // instead of forcing the user to drill into the AI landing
        // and switch tabs from there.
        'ai/providers': 'ai-providers',
        'ai/models': 'ai-models',
        'ai/profiles': 'ai-profiles',
        'agents/stats': 'agents-stats',
        'agents/templates': 'agents-templates',
        'agents/instances': 'agents-instances',
        'agents/souls': 'agents-souls',
        'agents/pending-wakes': 'agents-pending-wakes',
        'definitions/habits': 'habits',
        'definitions/categories': 'categories',
        'definitions/labels': 'labels',
        'sync/backfill': 'sync-backfill',
        'sync/stats': 'sync-stats',
        'sync/outbox': 'sync-outbox',
        'sync/conflicts': 'sync-conflicts',
        'sync/matrix-maintenance': 'sync-matrix-maintenance',
        'definitions/dashboards': 'dashboards',
        'definitions/measurables': 'measurables',
        'theming': 'theming',
        'advanced/flags': 'flags',
        'advanced/logging': 'advanced-logging',
        'advanced/maintenance': 'advanced-maintenance',
        'advanced/about': 'advanced-about',
      });
    });

    test('pure branch nodes have no panel', () {
      // `advanced` and `definitions` are pure (landing-page-less)
      // branches. `ai`, `agents`, and `sync` carry their own landing
      // panel (asserted separately below).
      for (final id in ['advanced', 'definitions']) {
        final tree = _tree();
        final node = SettingsTreeIndexTestHelper.findInTree(tree, id);
        expect(node, isNotNull, reason: 'expected $id to be present');
        expect(node!.panel, isNull, reason: '$id is a pure branch, no panel');
      }
    });

    test('branches that carry a landing panel expose it', () {
      // AI / Agents / Sync branches render their own detail panel
      // when the user lands on the branch itself (not a descendant
      // leaf). For Sync, the landing panel surfaces the
      // ProvisionedSyncSettingsCard so QR-pairing is reachable on
      // desktop V2 the same way it is on mobile.
      const expected = {'ai': 'ai', 'agents': 'agents', 'sync': 'sync'};
      for (final entry in expected.entries) {
        final tree = _tree();
        final node = SettingsTreeIndexTestHelper.findInTree(tree, entry.key);
        expect(node, isNotNull, reason: 'expected ${entry.key} to be present');
        expect(node!.panel, entry.value);
      }
    });
  });

  group('buildSettingsTree — child ordering', () {
    test('AI has Providers / Models / Profiles in tab order', () {
      // v4 split the AI branch into per-tab leaves so the sidebar
      // exposes the same three surfaces as the in-page tab bar
      // (Providers → Models → Profiles), keeping the navigation grammar
      // consistent between desktop sidebar and mobile tabs.
      final ai = _tree().firstWhere((n) => n.id == 'ai');
      expect(ai.children!.map((n) => n.id).toList(), [
        'ai/providers',
        'ai/models',
        'ai/profiles',
      ]);
    });

    test('Advanced has flags / logging / maintenance / about in order', () {
      // Conflicts moved out of Advanced and into Sync; flags moved
      // in from the root list. The order locks visual stability
      // across the menu.
      final advanced = _tree().firstWhere((n) => n.id == 'advanced');
      expect(advanced.children!.map((n) => n.id).toList(), [
        'advanced/flags',
        'advanced/logging',
        'advanced/maintenance',
        'advanced/about',
      ]);
    });

    test(
      'Sync has backfill / stats / outbox / conflicts / matrix-maintenance '
      'in order',
      () {
        final sync = _tree().firstWhere((n) => n.id == 'sync');
        expect(sync.children!.map((n) => n.id).toList(), [
          'sync/backfill',
          'sync/stats',
          'sync/outbox',
          'sync/conflicts',
          'sync/matrix-maintenance',
        ]);
      },
    );
  });

  group('buildSettingsTree — flag combinations', () {
    test('every flag off: minimal always-on tree', () {
      final ids = _tree(
        enableHabits: false,
        enableDashboards: false,
        enableMatrix: false,
        enableWhatsNew: false,
      ).map((n) => n.id).toList();

      expect(ids, [
        'ai',
        'agents',
        // Sync branch stays so the conflicts leaf remains reachable —
        // and sits directly below the AI/Agents-family slot regardless
        // of which optional taxonomy branches are gated off.
        'sync',
        'definitions',
        'theming',
        'advanced',
      ]);
    });

    test(
      'sync flag independence: toggling Matrix only changes Sync children, '
      'not the root order',
      () {
        final on = _tree();
        final off = _tree(enableMatrix: false);

        // Root order is preserved across the toggle; only the Sync
        // branch's children differ.
        expect(
          off.map((n) => n.id).toList(),
          on.map((n) => n.id).toList(),
        );
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
