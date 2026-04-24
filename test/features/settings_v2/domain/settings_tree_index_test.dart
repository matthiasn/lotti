import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/settings_v2/domain/settings_node.dart';
import 'package:lotti/features/settings_v2/domain/settings_tree_data.dart';
import 'package:lotti/features/settings_v2/domain/settings_tree_index.dart';

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

void main() {
  group('pathToBeamUrl', () {
    test('empty path returns /settings', () {
      expect(pathToBeamUrl(const []), '/settings');
    });

    test('leaf path uses the last id', () {
      expect(
        pathToBeamUrl(['sync', 'sync/backfill']),
        '/settings/sync/backfill',
      );
    });

    test('branch-only path uses the branch url', () {
      expect(pathToBeamUrl(['sync']), '/settings/sync');
    });

    test('unknown id falls back to /settings (e.g. in-pane whats-new)', () {
      expect(pathToBeamUrl(['whats-new']), '/settings');
    });

    test('advanced/logging maps to the canonical logging_domains url', () {
      expect(
        pathToBeamUrl(['advanced', 'advanced/logging']),
        '/settings/advanced/logging_domains',
      );
    });

    test('sync/matrix-maintenance maps to the slash-split matrix url', () {
      expect(
        pathToBeamUrl(['sync', 'sync/matrix-maintenance']),
        '/settings/sync/matrix/maintenance',
      );
    });

    test('advanced/maintenance maps to /settings/advanced/maintenance', () {
      expect(
        pathToBeamUrl(['advanced', 'advanced/maintenance']),
        '/settings/advanced/maintenance',
      );
    });
  });

  group('beamUrlToPath — base cases', () {
    test('exact /settings returns an empty path', () {
      expect(beamUrlToPath('/settings'), isEmpty);
    });

    test('URL outside /settings returns an empty path', () {
      expect(beamUrlToPath('/tasks'), isEmpty);
      expect(beamUrlToPath('/settingsx'), isEmpty);
      expect(beamUrlToPath('/'), isEmpty);
    });

    test('trailing slash on /settings/ is canonicalized to /settings', () {
      expect(beamUrlToPath('/settings/'), isEmpty);
    });

    test('unknown leaf under /settings returns an empty path', () {
      expect(beamUrlToPath('/settings/completely-unknown'), isEmpty);
    });
  });

  group('beamUrlToPath — greedy longest-prefix', () {
    test('/settings/advanced → [advanced]', () {
      expect(beamUrlToPath('/settings/advanced'), ['advanced']);
    });

    test(
      '/settings/advanced/maintenance wins over /settings/advanced (longest prefix)',
      () {
        expect(beamUrlToPath('/settings/advanced/maintenance'), [
          'advanced',
          'advanced/maintenance',
        ]);
      },
    );

    test(
      '/settings/advanced/logging_domains → [advanced, advanced/logging]',
      () {
        expect(beamUrlToPath('/settings/advanced/logging_domains'), [
          'advanced',
          'advanced/logging',
        ]);
      },
    );

    test(
      '/settings/sync/matrix/maintenance → [sync, sync/matrix-maintenance]',
      () {
        expect(beamUrlToPath('/settings/sync/matrix/maintenance'), [
          'sync',
          'sync/matrix-maintenance',
        ]);
      },
    );
  });

  group('beamUrlToPath — panel-local trailing segments', () {
    test('category detail UUID is treated as panel-local', () {
      expect(
        beamUrlToPath('/settings/categories/abc-123'),
        ['categories'],
      );
    });

    test('label detail UUID is treated as panel-local', () {
      expect(
        beamUrlToPath('/settings/labels/some-label-id'),
        ['labels'],
      );
    });

    test('habit detail UUID is treated as panel-local', () {
      expect(
        beamUrlToPath('/settings/habits/by_id/some-habit'),
        ['habits'],
      );
    });

    test('agents template detail UUID is treated as panel-local', () {
      expect(
        beamUrlToPath('/settings/agents/templates/tpl-1'),
        ['agents', 'agents/templates'],
      );
    });

    test('advanced/conflicts/:id is treated as panel-local', () {
      expect(
        beamUrlToPath('/settings/advanced/conflicts/conflict-id'),
        ['advanced', 'advanced/conflicts'],
      );
    });
  });

  group('beamUrlToPath ↔ pathToBeamUrl round-trip', () {
    test('every registered node id round-trips through URL and back', () {
      for (final entry in settingsNodeUrls.entries) {
        final roundTrip = beamUrlToPath(entry.value);
        expect(
          pathToBeamUrl(roundTrip),
          entry.value,
          reason: 'round-trip for ${entry.key}',
        );
      }
    });
  });

  group('SettingsTreeIndex.build', () {
    test('indexes every node at every depth', () {
      final index = SettingsTreeIndex.build(_tree());
      expect(index.findById('ai'), isNotNull);
      expect(index.findById('ai/profiles'), isNotNull);
      expect(index.findById('sync'), isNotNull);
      expect(index.findById('sync/backfill'), isNotNull);
      expect(index.findById('sync/matrix-maintenance'), isNotNull);
      expect(index.findById('agents/instances'), isNotNull);
      expect(index.findById('advanced/about'), isNotNull);
    });

    test('returns null for ids gated off by a flag', () {
      final index = SettingsTreeIndex.build(_tree(enableMatrix: false));
      expect(index.findById('sync'), isNull);
      expect(index.findById('sync/backfill'), isNull);
    });

    test('empty tree input produces an empty index', () {
      final index = SettingsTreeIndex.build(const <SettingsNode>[]);
      expect(index.findById('ai'), isNull);
      expect(index.ancestors('ai'), isNull);
      expect(index.isValidPath(const []), isTrue);
      expect(index.isValidPath(const ['ai']), isFalse);
    });
  });

  group('SettingsTreeIndex.findById', () {
    test('returns the full node for a leaf', () {
      final index = SettingsTreeIndex.build(_tree());
      final node = index.findById('sync/backfill');
      expect(node, isNotNull);
      expect(node!.panel, 'sync-backfill');
      expect(node.icon, isA<IconData>());
    });

    test('returns the full node for a branch (with children)', () {
      final index = SettingsTreeIndex.build(_tree());
      final node = index.findById('sync');
      expect(node, isNotNull);
      expect(node!.hasChildren, isTrue);
      expect(node.children!.length, 4);
    });

    test('returns null for an id that was never in the tree', () {
      final index = SettingsTreeIndex.build(_tree());
      expect(index.findById('made-up-id'), isNull);
    });
  });

  group('SettingsTreeIndex.ancestors', () {
    test('root node ancestors contains only the node itself', () {
      final index = SettingsTreeIndex.build(_tree());
      expect(index.ancestors('ai'), ['ai']);
    });

    test('nested node returns parent → self inclusive', () {
      final index = SettingsTreeIndex.build(_tree());
      expect(index.ancestors('sync/backfill'), ['sync', 'sync/backfill']);
    });

    test('deep nested chain returns full root → self list', () {
      final index = SettingsTreeIndex.build(_tree());
      expect(
        index.ancestors('agents/templates'),
        ['agents', 'agents/templates'],
      );
    });

    test('returns null for an absent id', () {
      final index = SettingsTreeIndex.build(_tree());
      expect(index.ancestors('nope'), isNull);
    });

    test('returned list is unmodifiable', () {
      final index = SettingsTreeIndex.build(_tree());
      final list = index.ancestors('sync/backfill');
      expect(() => list!.add('x'), throwsUnsupportedError);
    });

    test('two reads return equal lists (no caller mutation leaks back)', () {
      final index = SettingsTreeIndex.build(_tree());
      final a = index.ancestors('sync/backfill');
      final b = index.ancestors('sync/backfill');
      expect(a, equals(b));
    });
  });

  group('SettingsTreeIndex.isValidPath', () {
    test('empty path is always valid', () {
      final index = SettingsTreeIndex.build(_tree());
      expect(index.isValidPath(const []), isTrue);
    });

    test('all-present path is valid', () {
      final index = SettingsTreeIndex.build(_tree());
      expect(index.isValidPath(['sync', 'sync/backfill']), isTrue);
    });

    test('single missing id invalidates the whole path', () {
      final index = SettingsTreeIndex.build(_tree(enableMatrix: false));
      expect(index.isValidPath(['sync']), isFalse);
      expect(index.isValidPath(['sync', 'sync/backfill']), isFalse);
    });

    test('path with one unknown id is invalid even if the rest is valid', () {
      final index = SettingsTreeIndex.build(_tree());
      expect(index.isValidPath(['sync', 'sync/nonexistent']), isFalse);
    });

    test('non-contiguous chain is invalid (missing ancestor)', () {
      // `sync/backfill` exists, but without its `sync` ancestor the
      // chain is malformed — install would produce a dangling tree
      // state.
      final index = SettingsTreeIndex.build(_tree());
      expect(index.isValidPath(['sync/backfill']), isFalse);
    });

    test('chain with wrong parent is invalid', () {
      // `sync/backfill` is a valid id and `advanced` is a valid id,
      // but `advanced` is not the parent of `sync/backfill`.
      final index = SettingsTreeIndex.build(_tree());
      expect(index.isValidPath(['advanced', 'sync/backfill']), isFalse);
    });
  });

  group('SettingsTreeIndex duplicate-id handling', () {
    final duplicate = [
      const SettingsNode(
        id: 'dup',
        icon: Icons.star,
        title: 'first',
        desc: 'desc',
      ),
      const SettingsNode(
        id: 'dup',
        icon: Icons.star_border,
        title: 'second',
        desc: 'desc',
      ),
    ];

    test('debug build trips the duplicate-id assert', () {
      expect(
        () => SettingsTreeIndex.build(duplicate),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
