import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/keyboard/ui/app_command_host.dart';
import 'package:lotti/features/settings_v2/domain/settings_node.dart';
import 'package:lotti/features/settings_v2/state/settings_tree_controller.dart';
import 'package:lotti/features/settings_v2/ui/tree/settings_tree_node_widget.dart';
import 'package:lotti/features/settings_v2/ui/tree/settings_tree_row.dart';

import '../../../../widget_test_utils.dart';

SettingsNode _syncBranch() => const SettingsNode(
  id: 'sync',
  icon: Icons.sync_rounded,
  title: 'Sync',
  desc: 'Configure sync',
  children: [
    SettingsNode(
      id: 'sync/backfill',
      icon: Icons.cloud_download_outlined,
      title: 'Backfill',
      desc: 'Recover sync gaps',
      panel: 'sync-backfill',
    ),
  ],
);

SettingsNode _flagsLeaf() => const SettingsNode(
  id: 'flags',
  icon: Icons.flag_outlined,
  title: 'Flags',
  desc: 'Feature flags',
  panel: 'flags',
);

SettingsNode _branchWithHiddenChildren() => const SettingsNode(
  id: 'sync',
  icon: Icons.sync_rounded,
  title: 'Sync',
  desc: 'Configure sync',
  children: [
    SettingsNode(
      id: 'sync/backfill',
      icon: Icons.cloud_download_outlined,
      title: 'Backfill',
      desc: 'Recover sync gaps',
      panel: 'sync-backfill',
    ),
    SettingsNode(
      id: 'sync/conflicts',
      icon: Icons.warning_amber_rounded,
      title: 'Conflicts',
      desc: 'Resolve conflicts',
      panel: 'sync-conflicts',
    ),
    SettingsNode(
      id: 'sync/stats',
      icon: Icons.query_stats_rounded,
      title: 'Stats',
      desc: 'Inspect sync statistics',
      panel: 'sync-stats',
    ),
  ],
);

Future<void> _pumpNode(
  WidgetTester tester, {
  required SettingsNode node,
  int depth = 0,
}) async {
  await tester.pumpWidget(
    makeTestableWidgetNoScroll(
      Material(
        child: SizedBox(
          width: 400,
          child: AppCommandHost(
            handlers: const {},
            child: FocusScope(
              debugLabel: 'settings-tree-test',
              child: SettingsTreeNodeWidget(node: node, depth: depth),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

ProviderContainer _containerOf(WidgetTester tester) {
  return ProviderScope.containerOf(
    tester.element(find.byType(SettingsTreeNodeWidget).first),
    listen: false,
  );
}

void main() {
  group('SettingsTreeNodeWidget — rendering', () {
    testWidgets('renders a single row for a leaf with no children slot', (
      tester,
    ) async {
      await _pumpNode(tester, node: _flagsLeaf());
      expect(find.byType(SettingsTreeRow), findsOneWidget);
    });

    testWidgets(
      'branch renders its row and keeps children mounted at 0 height '
      'while collapsed (so AnimatedOpacity can fade them smoothly)',
      (tester) async {
        await _pumpNode(tester, node: _syncBranch());
        expect(find.text('Sync'), findsOneWidget);
        // Children ARE in the tree (kept mounted for the fade-out
        // animation), but the enclosing Align collapses to 0 height
        // via ClipRect so they're visually hidden.
        expect(find.text('Backfill'), findsOneWidget);
        final align = tester.widget<Align>(
          find.descendant(
            of: find.byType(ClipRect),
            matching: find.byType(Align),
          ),
        );
        expect(align.heightFactor, 0.0);
      },
    );
  });

  group('SettingsTreeNodeWidget — tap dispatch to SettingsTreePath', () {
    // Children are always mounted (see the collapse-animation test
    // above), so `.first` consistently targets the branch row even
    // in the initial collapsed state.
    testWidgets('tapping a branch opens it at the correct depth', (
      tester,
    ) async {
      await _pumpNode(tester, node: _syncBranch());
      await tester.tap(find.byType(SettingsTreeRow).first, warnIfMissed: false);
      await tester.pump();
      final path = _containerOf(tester).read(settingsTreePathProvider);
      expect(path, ['sync']);
    });

    testWidgets('tapping a leaf selects it', (tester) async {
      await _pumpNode(tester, node: _flagsLeaf());
      await tester.tap(find.byType(SettingsTreeRow));
      await tester.pump();
      final path = _containerOf(tester).read(settingsTreePathProvider);
      expect(path, ['flags']);
    });

    testWidgets('tapping a re-tapped open branch collapses it', (tester) async {
      await _pumpNode(tester, node: _syncBranch());
      await tester.tap(find.byType(SettingsTreeRow).first, warnIfMissed: false);
      // Apply the open state, then advance a fixed 400 ms (longer than
      // every branch animation in SettingsV2Constants) so the implicit
      // AnimatedSize/AnimatedOpacity tickers settle deterministically —
      // a bounded `pump(duration)` replaces `pumpAndSettle` so there is
      // no 10 s settle-loop and no leaked animation timer.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byType(SettingsTreeRow).first);
      await tester.pump();
      final path = _containerOf(tester).read(settingsTreePathProvider);
      expect(path, isEmpty);
    });
  });

  group('SettingsTreeNodeWidget — keyboard tree navigation', () {
    testWidgets(
      'Right expands and enters a branch; Left returns and collapses it',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        try {
          await _pumpNode(tester, node: _syncBranch());
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();

          await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
          await tester.pump();
          expect(
            _containerOf(tester).read(settingsTreePathProvider),
            ['sync'],
          );

          await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
          await tester.pump();
          expect(
            FocusManager.instance.primaryFocus?.context
                ?.findAncestorWidgetOfExactType<SettingsTreeRow>()
                ?.node
                .id,
            'sync/backfill',
          );

          await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
          await tester.pump();
          expect(
            FocusManager.instance.primaryFocus?.context
                ?.findAncestorWidgetOfExactType<SettingsTreeRow>()
                ?.node
                .id,
            'sync',
          );

          await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
          await tester.pump();
          expect(_containerOf(tester).read(settingsTreePathProvider), isEmpty);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );

    testWidgets('Down and Up move focus between tree rows', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        await tester.pumpWidget(
          makeTestableWidgetNoScroll(
            Material(
              child: AppCommandHost(
                handlers: const {},
                child: Column(
                  children: [
                    SettingsTreeNodeWidget(node: _flagsLeaf(), depth: 0),
                    const SettingsTreeNodeWidget(
                      node: SettingsNode(
                        id: 'about',
                        icon: Icons.info_outline,
                        title: 'About',
                        desc: 'About Lotti',
                        panel: 'about',
                      ),
                      depth: 0,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final firstFocus = FocusManager.instance.primaryFocus;
        expect(firstFocus, isNotNull);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        final secondFocus = FocusManager.instance.primaryFocus;
        expect(secondFocus, isNot(firstFocus));

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump();
        expect(FocusManager.instance.primaryFocus, firstFocus);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets(
      'Down skips collapsed children and tree boundaries keep focus away '
      'from the resize handle',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        final resizeHandleFocus = FocusNode(debugLabel: 'resize-handle');
        addTearDown(resizeHandleFocus.dispose);
        try {
          await tester.pumpWidget(
            makeTestableWidgetNoScroll(
              Material(
                child: AppCommandHost(
                  handlers: const {},
                  child: Row(
                    children: [
                      Expanded(
                        child: FocusScope(
                          debugLabel: 'settings-tree-test',
                          child: Column(
                            children: [
                              SettingsTreeNodeWidget(
                                node: _branchWithHiddenChildren(),
                                depth: 0,
                              ),
                              SettingsTreeNodeWidget(
                                node: _flagsLeaf(),
                                depth: 0,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Focus(
                        focusNode: resizeHandleFocus,
                        child: const SizedBox(width: 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );

          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
          await tester.pump();

          final focusedRow = FocusManager.instance.primaryFocus?.context
              ?.findAncestorWidgetOfExactType<SettingsTreeRow>();
          expect(focusedRow?.node.id, 'flags');

          await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
          await tester.pump();

          expect(resizeHandleFocus.hasFocus, isFalse);
          expect(
            FocusManager.instance.primaryFocus?.context
                ?.findAncestorWidgetOfExactType<SettingsTreeRow>()
                ?.node
                .id,
            'flags',
          );
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  });

  group('SettingsTreeNodeWidget — recursion', () {
    testWidgets(
      'opening a branch reveals its children rendered recursively via '
      'nested SettingsTreeNodeWidgets',
      (tester) async {
        await _pumpNode(tester, node: _syncBranch());
        // Tap the branch row; `.first` in case children are also
        // mounted as rows beneath (they always are — see the
        // collapse-animation test above).
        await tester.tap(
          find.byType(SettingsTreeRow).first,
          warnIfMissed: false,
        );
        // Apply the open state, then advance a fixed 400 ms so the
        // branch reveal animations settle deterministically without a
        // `pumpAndSettle` settle-loop or a leaked ticker.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('Backfill'), findsOneWidget);
        // Two node widgets: the branch + the leaf child.
        expect(find.byType(SettingsTreeNodeWidget), findsNWidgets(2));
        // After opening, the Align reveals its child (heightFactor 1).
        final align = tester.widget<Align>(
          find.descendant(
            of: find.byType(ClipRect),
            matching: find.byType(Align),
          ),
        );
        expect(align.heightFactor, 1.0);
      },
    );
  });

  group('SettingsTreeNodeWidget — depth-aware active-path derivation', () {
    testWidgets(
      'a node renders as selected only when its depth aligns with the '
      'matching id in the path',
      (tester) async {
        await _pumpNode(tester, node: _flagsLeaf(), depth: 1);
        final container = _containerOf(tester);
        // Place "flags" at depth 1 — i.e. `['other', 'flags']`.
        container
            .read(settingsTreePathProvider.notifier)
            .onNodeTap('other', depth: 0, hasChildren: true);
        container
            .read(settingsTreePathProvider.notifier)
            .onNodeTap('flags', depth: 1, hasChildren: false);
        await tester.pump();

        final row = tester.widget<SettingsTreeRow>(
          find.byType(SettingsTreeRow),
        );
        expect(row.onActivePath, isTrue);
      },
    );

    testWidgets(
      'same id at the wrong depth does NOT register as active',
      (tester) async {
        await _pumpNode(tester, node: _flagsLeaf());
        final container = _containerOf(tester);
        container
            .read(settingsTreePathProvider.notifier)
            .onNodeTap('advanced', depth: 0, hasChildren: true);
        container
            .read(settingsTreePathProvider.notifier)
            .onNodeTap('flags', depth: 1, hasChildren: false);
        await tester.pump();

        final row = tester.widget<SettingsTreeRow>(
          find.byType(SettingsTreeRow),
        );
        // `flags` is selected at depth 1, but this instance is at depth 0.
        expect(row.onActivePath, isFalse);
      },
    );
  });
}
