import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/settings_v2/domain/settings_node.dart';
import 'package:lotti/features/settings_v2/domain/settings_tree_index.dart';
import 'package:lotti/features/settings_v2/ui/settings_tree_scope.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

void main() {
  group('SettingsTreeScope — InheritedWidget access', () {
    testWidgets(
      'maybeOf returns the scope when descendants are mounted under it',
      (tester) async {
        late SettingsTreeScope? captured;
        const tree = <SettingsNode>[
          SettingsNode(
            id: 'flags',
            icon: Icons.flag_outlined,
            title: 'Flags',
            desc: '',
            panel: 'flags',
          ),
        ];
        final index = SettingsTreeIndex.build(tree);

        await tester.pumpWidget(
          makeTestableWidgetNoScroll(
            SettingsTreeScope(
              tree: tree,
              index: index,
              child: Builder(
                builder: (context) {
                  captured = SettingsTreeScope.maybeOf(context);
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        );

        expect(captured, isNotNull);
        expect(captured!.tree, same(tree));
        expect(captured!.index, same(index));
      },
    );

    testWidgets(
      'maybeOf returns null when no scope is in the ancestry',
      (tester) async {
        late SettingsTreeScope? captured;
        await tester.pumpWidget(
          makeTestableWidgetNoScroll(
            Builder(
              builder: (context) {
                captured = SettingsTreeScope.maybeOf(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        expect(captured, isNull);
      },
    );

    testWidgets('of returns the scope when one exists', (tester) async {
      late SettingsTreeScope captured;
      const tree = <SettingsNode>[];
      final index = SettingsTreeIndex.build(tree);

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          SettingsTreeScope(
            tree: tree,
            index: index,
            child: Builder(
              builder: (context) {
                captured = SettingsTreeScope.of(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(captured.tree, same(tree));
      expect(captured.index, same(index));
    });
  });

  group('SettingsTreeScope — updateShouldNotify', () {
    test(
      'returns false when both tree and index are identical references',
      () {
        const tree = <SettingsNode>[];
        final index = SettingsTreeIndex.build(tree);
        final a = SettingsTreeScope(
          tree: tree,
          index: index,
          child: const SizedBox.shrink(),
        );
        final b = SettingsTreeScope(
          tree: tree,
          index: index,
          child: const SizedBox.shrink(),
        );
        expect(a.updateShouldNotify(b), isFalse);
      },
    );

    test('returns true when the tree reference changes', () {
      const treeA = <SettingsNode>[];
      const treeB = <SettingsNode>[
        SettingsNode(
          id: 'flags',
          icon: Icons.flag_outlined,
          title: 'Flags',
          desc: '',
          panel: 'flags',
        ),
      ];
      final indexA = SettingsTreeIndex.build(treeA);
      final indexB = SettingsTreeIndex.build(treeB);
      final a = SettingsTreeScope(
        tree: treeA,
        index: indexA,
        child: const SizedBox.shrink(),
      );
      final b = SettingsTreeScope(
        tree: treeB,
        index: indexB,
        child: const SizedBox.shrink(),
      );
      expect(a.updateShouldNotify(b), isTrue);
    });

    test('returns true when only the index reference changes', () {
      const tree = <SettingsNode>[];
      final indexA = SettingsTreeIndex.build(tree);
      final indexB = SettingsTreeIndex.build(tree);
      // indexA and indexB are distinct references, so the host should
      // notify even though the tree list is the same instance.
      final a = SettingsTreeScope(
        tree: tree,
        index: indexA,
        child: const SizedBox.shrink(),
      );
      final b = SettingsTreeScope(
        tree: tree,
        index: indexB,
        child: const SizedBox.shrink(),
      );
      expect(a.updateShouldNotify(b), isTrue);
    });
  });

  group('SettingsTreeScopeHost — flag-driven tree assembly', () {
    testWidgets(
      'publishes a tree built from the watched gating flags',
      (tester) async {
        // Stub config flag stream so the host emits with Agents on,
        // Habits/Dashboards/Matrix/WhatsNew off — the tree should
        // contain the agents branch and exclude the others.
        final mockJournalDb = MockJournalDb();
        registerFallbackValue('');
        when(
          () => mockJournalDb.watchConfigFlag(any()),
        ).thenAnswer((invocation) {
          final name = invocation.positionalArguments.first as String;
          final on = name == enableAgentsFlag;
          return Stream.value(on);
        });

        late SettingsTreeScope scope;
        await tester.pumpWidget(
          makeTestableWidgetNoScroll(
            SettingsTreeScopeHost(
              child: Builder(
                builder: (context) {
                  scope = SettingsTreeScope.of(context);
                  return const SizedBox.shrink();
                },
              ),
            ),
            overrides: [
              journalDbProvider.overrideWithValue(mockJournalDb),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Agents flag is on, so the agents branch should be present.
        expect(scope.index.findById('agents'), isNotNull);
        // Habits flag is off, so the habits leaf should not be in
        // the gated tree.
        expect(scope.index.findById('habits'), isNull);
        // Always-on leaves stay regardless of flag state.
        expect(scope.index.findById('flags'), isNotNull);
      },
    );
  });
}
