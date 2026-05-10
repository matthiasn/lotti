import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart'
    show
        Any,
        AnyUtils,
        BoolAny,
        CombinableAny,
        ExploreConfig,
        Generator,
        Glados,
        any;
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

enum _GeneratedSettingsUrlSuffix {
  none,
  trailingSlash,
  detailSegment,
  nestedDetailSegment,
}

class _GeneratedSettingsFlags {
  const _GeneratedSettingsFlags({
    required this.enableAgents,
    required this.enableHabits,
    required this.enableDashboards,
    required this.enableMatrix,
    required this.enableWhatsNew,
  });

  final bool enableAgents;
  final bool enableHabits;
  final bool enableDashboards;
  final bool enableMatrix;
  final bool enableWhatsNew;

  List<SettingsNode> buildTree() {
    return _tree(
      enableAgents: enableAgents,
      enableHabits: enableHabits,
      enableDashboards: enableDashboards,
      enableMatrix: enableMatrix,
      enableWhatsNew: enableWhatsNew,
    );
  }

  @override
  String toString() {
    return '_GeneratedSettingsFlags('
        'enableAgents: $enableAgents, '
        'enableHabits: $enableHabits, '
        'enableDashboards: $enableDashboards, '
        'enableMatrix: $enableMatrix, '
        'enableWhatsNew: $enableWhatsNew)';
  }
}

class _GeneratedSettingsUrl {
  const _GeneratedSettingsUrl({
    required this.entry,
    required this.suffix,
    required this.withQuery,
    required this.withFragment,
  });

  final MapEntry<String, String> entry;
  final _GeneratedSettingsUrlSuffix suffix;
  final bool withQuery;
  final bool withFragment;

  String get url {
    final suffixValue = switch (suffix) {
      _GeneratedSettingsUrlSuffix.none => '',
      _GeneratedSettingsUrlSuffix.trailingSlash => '/',
      _GeneratedSettingsUrlSuffix.detailSegment => '/generated-detail',
      _GeneratedSettingsUrlSuffix.nestedDetailSegment =>
        '/generated-detail/edit',
    };

    final query = withQuery ? '?focus=generated' : '';
    final fragment = withFragment ? '#section' : '';
    return '${entry.value}$suffixValue$query$fragment';
  }

  List<String> get expectedPath => _idToPathModel(entry.key);

  @override
  String toString() {
    return '_GeneratedSettingsUrl('
        'entry: ${entry.key} -> ${entry.value}, '
        'suffix: $suffix, '
        'withQuery: $withQuery, '
        'withFragment: $withFragment)';
  }
}

extension _AnySettingsTreeIndexScenario on Any {
  Generator<_GeneratedSettingsFlags> get settingsFlags => combine5(
    this.bool,
    this.bool,
    this.bool,
    this.bool,
    this.bool,
    (
      bool enableAgents,
      bool enableHabits,
      bool enableDashboards,
      bool enableMatrix,
      bool enableWhatsNew,
    ) => _GeneratedSettingsFlags(
      enableAgents: enableAgents,
      enableHabits: enableHabits,
      enableDashboards: enableDashboards,
      enableMatrix: enableMatrix,
      enableWhatsNew: enableWhatsNew,
    ),
  );

  Generator<_GeneratedSettingsUrlSuffix> get settingsUrlSuffix =>
      choose(_GeneratedSettingsUrlSuffix.values);

  Generator<_GeneratedSettingsUrl> get settingsUrl => combine4(
    choose(settingsNodeUrls.entries.toList()),
    settingsUrlSuffix,
    this.bool,
    this.bool,
    (
      MapEntry<String, String> entry,
      _GeneratedSettingsUrlSuffix suffix,
      bool withQuery,
      bool withFragment,
    ) => _GeneratedSettingsUrl(
      entry: entry,
      suffix: suffix,
      withQuery: withQuery,
      withFragment: withFragment,
    ),
  );
}

List<SettingsNode> _flattenTree(List<SettingsNode> nodes) {
  final result = <SettingsNode>[];
  void walk(List<SettingsNode> current) {
    for (final node in current) {
      result.add(node);
      final children = node.children;
      if (children != null) {
        walk(children);
      }
    }
  }

  walk(nodes);
  return result;
}

List<String> _idToPathModel(String id) {
  final segments = id.split('/');
  return [
    for (var index = 0; index < segments.length; index++)
      segments.take(index + 1).join('/'),
  ];
}

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

    test('query string is stripped before prefix matching', () {
      expect(beamUrlToPath('/settings/categories?focus=new'), [
        'definitions',
        'definitions/categories',
      ]);
    });

    test('fragment is stripped before prefix matching', () {
      expect(beamUrlToPath('/settings/sync/backfill#anchor'), [
        'sync',
        'sync/backfill',
      ]);
    });

    test('query and fragment together both stripped', () {
      expect(beamUrlToPath('/settings/flags?x=1#top'), [
        'advanced',
        'advanced/flags',
      ]);
    });

    test(
      'a malformed URL that crashes Uri.parse falls back to the raw input',
      () {
        // Invalid percent-encoding (`%2`) makes Uri.parse throw a
        // FormatException; the canonicalizer must catch it and treat
        // the raw string as the path. The raw input does not match
        // the /settings prefix, so we expect an empty path — the key
        // assertion is that the call doesn't throw, exercising the
        // FormatException catch in _canonicalize.
        expect(beamUrlToPath('/settings/flags%2'), isEmpty);
      },
    );
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
        ['definitions', 'definitions/categories'],
      );
    });

    test('label detail UUID is treated as panel-local', () {
      expect(
        beamUrlToPath('/settings/labels/some-label-id'),
        ['definitions', 'definitions/labels'],
      );
    });

    test('habit detail UUID is treated as panel-local', () {
      expect(
        beamUrlToPath('/settings/habits/by_id/some-habit'),
        ['definitions', 'definitions/habits'],
      );
    });

    test('agents template detail UUID is treated as panel-local', () {
      expect(
        beamUrlToPath('/settings/agents/templates/tpl-1'),
        ['agents', 'agents/templates'],
      );
    });

    test(
      'advanced/conflicts/:id resolves under the Sync branch (the leaf '
      'lives under sync/* in the tree even though the URL still wears '
      'the legacy advanced/* path)',
      () {
        expect(
          beamUrlToPath('/settings/advanced/conflicts/conflict-id'),
          ['sync', 'sync/conflicts'],
        );
      },
    );
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

    Glados(any.settingsUrl, ExploreConfig(numRuns: 180)).test(
      'greedily resolves generated registered URLs with local suffixes',
      (scenario) {
        final path = beamUrlToPath(scenario.url);

        expect(
          path,
          scenario.expectedPath,
          reason:
              'Generated URL should resolve to its registered node path: '
              '$scenario',
        );
        expect(pathToBeamUrl(path), scenario.entry.value);
      },
      tags: 'glados',
    );
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
      // Matrix-only leaves disappear …
      expect(index.findById('sync/backfill'), isNull);
      expect(index.findById('sync/matrix-maintenance'), isNull);
      // … but the Sync branch + the always-on conflicts leaf survive.
      expect(index.findById('sync'), isNotNull);
      expect(index.findById('sync/conflicts'), isNotNull);
    });

    test('empty tree input produces an empty index', () {
      final index = SettingsTreeIndex.build(const <SettingsNode>[]);
      expect(index.findById('ai'), isNull);
      expect(index.ancestors('ai'), isNull);
      expect(index.isValidPath(const []), isTrue);
      expect(index.isValidPath(const ['ai']), isFalse);
    });

    Glados(any.settingsFlags, ExploreConfig(numRuns: 80)).test(
      'matches generated flag-gated tree ancestor invariants',
      (flags) {
        final tree = flags.buildTree();
        final index = SettingsTreeIndex.build(tree);
        final nodes = _flattenTree(tree);
        final visibleIds = nodes.map((node) => node.id).toSet();

        for (final node in nodes) {
          final expectedPath = _idToPathModel(node.id);
          expect(index.findById(node.id)?.id, node.id, reason: '$flags');
          expect(index.ancestors(node.id), expectedPath, reason: '$flags');
          expect(index.isValidPath(expectedPath), isTrue, reason: '$flags');

          if (expectedPath.length > 1) {
            expect(index.isValidPath([node.id]), isFalse, reason: '$flags');
          }
        }

        for (final entry in settingsNodeUrls.entries) {
          expect(
            index.isValidPath(_idToPathModel(entry.key)),
            visibleIds.contains(entry.key),
            reason:
                'Registered URL visibility should match tree visibility '
                'for ${entry.key} under $flags',
          );
        }
      },
      tags: 'glados',
    );
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
      // backfill / stats / outbox / conflicts / matrix-maintenance.
      expect(node.children!.length, 5);
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
      // `sync/backfill` is gated off by Matrix; `sync` itself stays
      // (the conflicts leaf is always-visible) but the leaf below it
      // is gone, so any path that touches `sync/backfill` is invalid.
      expect(index.isValidPath(['sync', 'sync/backfill']), isFalse);
      expect(index.isValidPath(['sync/backfill']), isFalse);
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
