import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart'
    show Any, BoolAny, CombinableAny, ExploreConfig, Generator, Glados, any;
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/domain/settings_node.dart';
import 'package:lotti/features/settings/domain/settings_tree_data.dart';
import 'package:lotti/features/settings/domain/settings_tree_index.dart';
import 'package:material_ui/material_ui.dart';

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

class _GeneratedSettingsFlags {
  const _GeneratedSettingsFlags({
    required this.enableHabits,
    required this.enableDashboards,
    required this.enableMatrix,
    required this.enableWhatsNew,
  });

  final bool enableHabits;
  final bool enableDashboards;
  final bool enableMatrix;
  final bool enableWhatsNew;

  List<SettingsNode> buildTree() {
    return _tree(
      enableHabits: enableHabits,
      enableDashboards: enableDashboards,
      enableMatrix: enableMatrix,
      enableWhatsNew: enableWhatsNew,
    );
  }

  @override
  String toString() {
    return '_GeneratedSettingsFlags('
        'enableHabits: $enableHabits, '
        'enableDashboards: $enableDashboards, '
        'enableMatrix: $enableMatrix, '
        'enableWhatsNew: $enableWhatsNew)';
  }
}

extension _AnySettingsTreeIndexScenario on Any {
  Generator<_GeneratedSettingsFlags> get settingsFlags => combine4(
    this.bool,
    this.bool,
    this.bool,
    this.bool,
    (
      bool enableHabits,
      bool enableDashboards,
      bool enableMatrix,
      bool enableWhatsNew,
    ) => _GeneratedSettingsFlags(
      enableHabits: enableHabits,
      enableDashboards: enableDashboards,
      enableMatrix: enableMatrix,
      enableWhatsNew: enableWhatsNew,
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
  group('SettingsTreeIndex.build', () {
    test('indexes every node at every depth', () {
      final index = SettingsTreeIndex.build(_tree());
      expect(index.findById('preferences'), isNotNull);
      expect(index.findById('preferences/theming'), isNotNull);
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
      // Sync is all-or-nothing: every Sync id disappears when the
      // matrix flag is off, including the branch itself and conflicts.
      expect(index.findById('sync'), isNull);
      expect(index.findById('sync/backfill'), isNull);
      expect(index.findById('sync/matrix-maintenance'), isNull);
      expect(index.findById('sync/conflicts'), isNull);
    });

    test('empty tree input produces an empty index', () {
      final index = SettingsTreeIndex.build(const <SettingsNode>[]);
      expect(index.findById('ai'), isNull);
      expect(index.ancestors('ai'), isNull);
    });

    Glados(any.settingsFlags, ExploreConfig(numRuns: 80)).test(
      'matches generated flag-gated tree ancestor invariants',
      (flags) {
        final tree = flags.buildTree();
        final index = SettingsTreeIndex.build(tree);
        final nodes = _flattenTree(tree);
        for (final node in nodes) {
          final expectedPath = _idToPathModel(node.id);
          expect(index.findById(node.id)?.id, node.id, reason: '$flags');
          expect(index.ancestors(node.id), expectedPath, reason: '$flags');
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
      expect(node!.id, 'sync/backfill');
      expect(node.children, isNull);
      expect(node.icon, isA<IconData>());
    });

    test('returns the full node for a branch (with children)', () {
      final index = SettingsTreeIndex.build(_tree());
      final node = index.findById('sync');
      expect(node, isNotNull);
      expect(node!.hasChildren, isTrue);
      // provisioned / node-profile / backfill / stats / outbox / conflicts /
      // matrix-maintenance.
      expect(node.children!.length, 7);
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

    test('a preference leaf reports the preferences branch as its parent', () {
      // The breadcrumb and the desktop tree seed both read this chain, so
      // it is what makes a `/settings/theming` deep link land with the
      // Preferences branch expanded rather than on a stray root row.
      final index = SettingsTreeIndex.build(_tree());
      expect(index.ancestors('preferences/theming'), [
        'preferences',
        'preferences/theming',
      ]);
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

  group('SettingsTreeIndex duplicate-id handling', () {
    final duplicate = [
      const SettingsNode(
        id: 'dup',
        icon: LottiIcons.star,
        title: 'first',
        desc: 'desc',
      ),
      const SettingsNode(
        id: 'dup',
        icon: LottiIcons.star,
        title: 'second',
        desc: 'desc',
      ),
    ];

    test('reports the duplicate id, then trips the debug assert', () {
      final printed = <String?>[];
      final originalDebugPrint = debugPrint;
      debugPrint = (message, {wrapWidth}) => printed.add(message);
      addTearDown(() => debugPrint = originalDebugPrint);

      expect(
        () => SettingsTreeIndex.build(duplicate),
        throwsA(isA<AssertionError>()),
      );
      const reported =
          'Duplicate SettingsNode id "dup" at depth 0. Node ids must be '
          'unique across the tree.';
      expect(printed, [reported]);
    });
  });
}
