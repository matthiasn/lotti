import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings_v2/domain/settings_node.dart';
import 'package:lotti/features/settings_v2/domain/settings_tree_index.dart';
import 'package:lotti/features/settings_v2/state/settings_tree_controller.dart';
import 'package:lotti/features/settings_v2/ui/settings_tree_scope.dart';
import 'package:lotti/features/settings_v2/ui/widgets/settings_v2_top_crumbs.dart';

import '../../../../widget_test_utils.dart';

/// Synthetic tree fixed enough for crumb-rendering: a Sync branch
/// with a Backfill child plus a sibling Stats child. Avoids depending
/// on the live `buildSettingsTree` (which would couple this test to
/// flag-gated tree shape changes).
const _syncBranch = SettingsNode(
  id: 'sync',
  icon: Icons.sync_rounded,
  title: 'Sync Settings',
  desc: '',
  children: [
    SettingsNode(
      id: 'sync/backfill',
      icon: Icons.cloud_download_outlined,
      title: 'Backfill Sync',
      desc: '',
      panel: 'sync-backfill',
    ),
    SettingsNode(
      id: 'sync/stats',
      icon: Icons.bar_chart_rounded,
      title: 'Sync Stats',
      desc: '',
      panel: 'sync-stats',
    ),
  ],
);

final _fixtureIndex = SettingsTreeIndex.build(const [_syncBranch]);

Future<void> _pump(
  WidgetTester tester, {
  required List<String> initialPath,
  bool withScope = true,
  List<SettingsNode>? tree,
  SettingsTreeIndex? index,
}) async {
  await setUpTestGetIt();
  addTearDown(tearDownTestGetIt);
  // Mirror the production header: the crumb widget renders inside a
  // fixed-height slot, left-aligned, with no width-restricting
  // ancestor of its own — overflow handling is the crumb widget's
  // responsibility.
  const body = SizedBox(
    height: 56,
    child: Align(
      alignment: AlignmentDirectional.centerStart,
      child: SettingsV2TopCrumbs(),
    ),
  );
  final widget = withScope
      ? SettingsTreeScope(
          tree: tree ?? const [_syncBranch],
          index: index ?? _fixtureIndex,
          child: const Material(child: body),
        )
      : const Material(child: body);

  await tester.pumpWidget(
    makeTestableWidgetNoScroll(
      widget,
      overrides: [
        settingsTreePathProvider.overrideWith(
          () => _SeededTreePath(initialPath),
        ),
      ],
    ),
  );
  await tester.pump();
}

class _SeededTreePath extends SettingsTreePath {
  _SeededTreePath(this._seed);

  final List<String> _seed;

  @override
  List<String> build() => _seed;
}

void main() {
  group('SettingsV2TopCrumbs — empty path', () {
    testWidgets(
      'renders only the localized root label and renders it as the '
      'terminal (non-tappable) segment',
      (tester) async {
        await _pump(tester, initialPath: const []);

        // Exactly one "Settings" Text — no chevrons, no other crumbs.
        expect(find.text('Settings'), findsOneWidget);
        expect(find.text('›'), findsNothing);

        // Root with empty path is the terminal segment, not a link —
        // tapping it would no-op anyway, so the widget renders it as
        // plain Text rather than an InkWell.
        final inkWellAncestor = find.ancestor(
          of: find.text('Settings'),
          matching: find.byType(InkWell),
        );
        expect(
          inkWellAncestor,
          findsNothing,
          reason:
              'Empty-path root must not be tappable — there is no shorter '
              'path to truncate to.',
        );
      },
    );
  });

  group('SettingsV2TopCrumbs — branch path', () {
    testWidgets('renders Settings › <Branch> with the branch as terminal', (
      tester,
    ) async {
      await _pump(tester, initialPath: const ['sync']);

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Sync Settings'), findsOneWidget);
      expect(find.text('›'), findsOneWidget);

      // Branch is terminal here — not in an InkWell.
      final branchInkWell = find.ancestor(
        of: find.text('Sync Settings'),
        matching: find.byType(InkWell),
      );
      expect(branchInkWell, findsNothing);

      // Root IS tappable (truncates back to []).
      final rootInkWell = find.ancestor(
        of: find.text('Settings'),
        matching: find.byType(InkWell),
      );
      expect(rootInkWell, findsOneWidget);
    });
  });

  group('SettingsV2TopCrumbs — leaf path', () {
    testWidgets(
      'renders Settings › <Branch> › <Leaf> with the leaf as terminal',
      (tester) async {
        await _pump(
          tester,
          initialPath: const ['sync', 'sync/backfill'],
        );

        expect(find.text('Settings'), findsOneWidget);
        expect(find.text('Sync Settings'), findsOneWidget);
        expect(find.text('Backfill Sync'), findsOneWidget);
        expect(find.text('›'), findsNWidgets(2));

        final leafInkWell = find.ancestor(
          of: find.text('Backfill Sync'),
          matching: find.byType(InkWell),
        );
        expect(leafInkWell, findsNothing);

        // Both Settings and Sync Settings should be tappable links.
        expect(
          find.ancestor(
            of: find.text('Settings'),
            matching: find.byType(InkWell),
          ),
          findsOneWidget,
        );
        expect(
          find.ancestor(
            of: find.text('Sync Settings'),
            matching: find.byType(InkWell),
          ),
          findsOneWidget,
        );
      },
    );
  });

  group('SettingsV2TopCrumbs — interactions', () {
    testWidgets(
      'tapping the root crumb truncates the path to []',
      (tester) async {
        await _pump(
          tester,
          initialPath: const ['sync', 'sync/backfill'],
        );

        final container = ProviderScope.containerOf(
          tester.element(find.byType(SettingsV2TopCrumbs)),
        );
        expect(
          container.read(settingsTreePathProvider),
          ['sync', 'sync/backfill'],
        );

        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();

        expect(container.read(settingsTreePathProvider), isEmpty);
      },
    );

    testWidgets(
      'tapping an intermediate crumb truncates to that depth',
      (tester) async {
        await _pump(
          tester,
          initialPath: const ['sync', 'sync/backfill'],
        );

        final container = ProviderScope.containerOf(
          tester.element(find.byType(SettingsV2TopCrumbs)),
        );

        // Sync Settings is at index 1 → truncateTo(1) drops the leaf.
        await tester.tap(find.text('Sync Settings'));
        await tester.pumpAndSettle();

        expect(container.read(settingsTreePathProvider), ['sync']);
      },
    );

    testWidgets(
      'hovering a non-leaf crumb repaints its label in the interactive accent',
      (tester) async {
        await _pump(
          tester,
          initialPath: const ['sync', 'sync/backfill'],
        );

        final tokens = tester
            .element(find.byType(SettingsV2TopCrumbs))
            .designTokens;
        final accent = tokens.colors.interactive.enabled;
        final mediumEmphasis = tokens.colors.text.mediumEmphasis;

        // The "Sync Settings" link starts at mediumEmphasis. The
        // header crumb texts can render as multiple Text widgets in
        // theory (the Wrap layout doesn't merge them) — pick the one
        // currently colored with either of the two states.
        Text crumbText() => tester
            .widgetList<Text>(find.text('Sync Settings'))
            .firstWhere(
              (t) =>
                  t.style?.color == mediumEmphasis || t.style?.color == accent,
            );

        expect(crumbText().style?.color, mediumEmphasis);

        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        addTearDown(gesture.removePointer);
        await gesture.addPointer(location: Offset.zero);
        await gesture.moveTo(tester.getCenter(find.text('Sync Settings')));
        await tester.pump();

        expect(crumbText().style?.color, accent);
      },
    );
  });

  group('SettingsV2TopCrumbs — overflow handling', () {
    // Long-title fixture: the leaf carries a label long enough to
    // overflow any sane header width, so the test forces the
    // ellipsis path even on the default 800 dp test viewport.
    const longLeafTitle =
        'Backfill Sync With An Extremely Long Localized Title For Overflow';
    const overflowBranch = SettingsNode(
      id: 'sync',
      icon: Icons.sync_rounded,
      title: 'Sync Settings',
      desc: '',
      children: [
        SettingsNode(
          id: 'sync/backfill',
          icon: Icons.cloud_download_outlined,
          title: longLeafTitle,
          desc: '',
          panel: 'sync-backfill',
        ),
      ],
    );
    final overflowIndex = SettingsTreeIndex.build(const [overflowBranch]);

    testWidgets(
      'leaf segment is configured to ellipsize on a single line, with a '
      'tooltip exposing the full title',
      (tester) async {
        await _pump(
          tester,
          initialPath: const ['sync', 'sync/backfill'],
          tree: const [overflowBranch],
          index: overflowIndex,
        );

        // The leaf Text must be configured to ellipsize on a single
        // line. The Wrap-era code path silently clipped when the
        // header's fixed height couldn't fit a second line, so this
        // test locks in the new single-line guarantee at the
        // configuration level.
        final leafText = tester.widget<Text>(
          find.descendant(
            of: find.byType(SettingsV2TopCrumbs),
            matching: find.text(longLeafTitle),
          ),
        );
        expect(leafText.maxLines, 1);
        expect(leafText.overflow, TextOverflow.ellipsis);
        expect(leafText.softWrap, isFalse);

        // Tooltip exposes the full title for users who can't read
        // the ellipsized version.
        final tooltip = tester.widget<Tooltip>(
          find.ancestor(
            of: find.text(longLeafTitle),
            matching: find.byType(Tooltip),
          ),
        );
        expect(tooltip.message, longLeafTitle);
      },
    );

    testWidgets(
      'leaf is wrapped in Flexible so it can shrink inside a constrained Row',
      (tester) async {
        await _pump(
          tester,
          initialPath: const ['sync', 'sync/backfill'],
          tree: const [overflowBranch],
          index: overflowIndex,
        );

        // The single Flexible inside the crumb subtree is the leaf
        // segment — non-leaf links are intentionally rigid so the
        // ellipsis is taken on the title rather than mid-trail. If
        // someone removes the Flexible (or wraps the trail in a
        // Wrap again), this assertion catches it.
        final flexibles = tester.widgetList<Flexible>(
          find.descendant(
            of: find.byType(SettingsV2TopCrumbs),
            matching: find.byType(Flexible),
          ),
        );
        expect(flexibles, hasLength(1));
      },
    );

    testWidgets(
      'no overflow exception at the realistic narrow detail-pane width even '
      'with a label far longer than that width',
      (tester) async {
        // 600 dp roughly matches the narrow desktop case after the
        // tree-nav column eats its share. The long-leaf fixture above
        // is wider than 600 dp on its own — so this test fails
        // closed if the leaf ever stops ellipsizing.
        await tester.binding.setSurfaceSize(const Size(600, 600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await _pump(
          tester,
          initialPath: const ['sync', 'sync/backfill'],
          tree: const [overflowBranch],
          index: overflowIndex,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('SettingsV2TopCrumbs — missing scope', () {
    testWidgets(
      'falls back to the localized root label only when no '
      'SettingsTreeScope is mounted, even with a non-empty path',
      (tester) async {
        // The path notifier says we're deep in the tree, but no scope
        // is in the ancestry — the widget must NOT crash and must NOT
        // surface raw ids. The only visible segment is the localized
        // root.
        await _pump(
          tester,
          initialPath: const ['sync', 'sync/backfill'],
          withScope: false,
        );

        expect(find.text('Settings'), findsOneWidget);
        expect(find.text('Sync Settings'), findsNothing);
        expect(find.text('Backfill Sync'), findsNothing);
        expect(find.text('›'), findsNothing);
      },
    );

    testWidgets(
      'silently drops segments whose id is not in the scoped index '
      '(e.g. a flag-gated leaf that became unreachable mid-session)',
      (tester) async {
        // Path includes a stale id ('agents') that is NOT in the
        // fixture index. The visible trail collapses to whatever ids
        // do resolve — and the trailing visible segment becomes the
        // terminal one.
        await _pump(
          tester,
          initialPath: const ['sync', 'agents'],
        );

        expect(find.text('Settings'), findsOneWidget);
        expect(find.text('Sync Settings'), findsOneWidget);
        // Only one chevron — between Settings and the resolved Sync
        // Settings; the missing 'agents' is silently dropped.
        expect(find.text('›'), findsOneWidget);
      },
    );
  });
}
