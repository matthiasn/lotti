import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings_v2/domain/settings_node.dart';
import 'package:lotti/features/settings_v2/state/settings_tree_controller.dart';
import 'package:lotti/features/settings_v2/ui/detail/default_panel.dart';
import 'package:lotti/features/settings_v2/ui/detail/leaf_panel.dart';

import '../../../../widget_test_utils.dart';

// The leaf test uses deliberately-unregistered panel ids so every
// case exercises the LeafPanel chrome with DefaultPanel as the
// body. The registry tests (`panel_registry_test.dart`) cover
// real-panel resolution; duplicating that here would pull in the
// entire sync/backfill provider graph just to assert breadcrumbs.
SettingsNode _syncBranch() => const SettingsNode(
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
      panel: 'test-unregistered-sync-backfill',
    ),
  ],
);

SettingsNode _backfillLeaf() => _syncBranch().children!.first;

SettingsNode _unregisteredLeaf() => const SettingsNode(
  id: 'ghost',
  icon: Icons.question_mark_rounded,
  title: 'Ghost Panel',
  desc: '',
  panel: 'ghost-panel',
);

Future<void> _pump(
  WidgetTester tester, {
  required List<SettingsNode> ancestors,
  double width = 1000,
}) async {
  await setUpTestGetIt();
  addTearDown(tearDownTestGetIt);
  await tester.pumpWidget(
    makeTestableWidgetNoScroll(
      Material(
        child: SizedBox(
          width: width,
          height: 800,
          child: LeafPanel(ancestors: ancestors),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('LeafPanel — local header', () {
    testWidgets('renders the localized root crumb "Settings"', (tester) async {
      await _pump(
        tester,
        ancestors: [_syncBranch(), _backfillLeaf()],
      );
      // Anchor the assertion to the *root crumb* specifically rather
      // than just any text reading "Settings": the root crumb must be
      // tappable (truncates the path back to []), so the matching Text
      // sits inside an InkWell ancestor. The leaf segment renders as
      // plain Text, not InkWell — so this assertion fails closed if
      // the synthetic root crumb is ever removed or downgraded to
      // non-interactive copy.
      final rootCrumb = find.ancestor(
        of: find.text('Settings'),
        matching: find.byType(InkWell),
      );
      expect(
        rootCrumb,
        findsOneWidget,
        reason:
            'Expected "Settings" to render inside a tappable InkWell '
            '(the root breadcrumb link).',
      );
    });

    testWidgets('includes each ancestor title in the crumb trail', (
      tester,
    ) async {
      await _pump(
        tester,
        ancestors: [_syncBranch(), _backfillLeaf()],
      );
      expect(find.text('Sync Settings'), findsOneWidget);
      expect(find.text('Backfill Sync'), findsWidgets);
    });

    testWidgets('uses the chevron (U+203A) as the crumb separator', (
      tester,
    ) async {
      await _pump(
        tester,
        ancestors: [_syncBranch(), _backfillLeaf()],
      );
      // Two segments → one separator between Settings and Sync
      // and another between Sync and Backfill.
      expect(find.text('›'), findsNWidgets(2));
    });

    testWidgets('renders the leaf title below the crumbs at Heading 3', (
      tester,
    ) async {
      await _pump(tester, ancestors: [_backfillLeaf()]);
      // The leaf title appears in two places — the trailing breadcrumb
      // segment (caption style) and the Heading 3 below the trail.
      // Locate the latter by matching the heading3 fontSize/weight from
      // the active design tokens, so the test breaks if the title is
      // ever demoted to body or caption typography.
      final tokensContext = tester.element(find.byType(LeafPanel));
      final heading3 =
          tokensContext.designTokens.typography.styles.heading.heading3;
      final headingTexts = tester.widgetList<Text>(find.text('Backfill Sync'));
      final headingMatch = headingTexts.where(
        (t) =>
            t.style?.fontSize == heading3.fontSize &&
            t.style?.fontWeight == heading3.fontWeight,
      );
      expect(
        headingMatch,
        hasLength(1),
        reason:
            'Expected exactly one "Backfill Sync" Text rendered at the '
            'Heading 3 typography (fontSize ${heading3.fontSize}, '
            'fontWeight ${heading3.fontWeight}); got '
            '${headingTexts.map((t) => '${t.style?.fontSize}/${t.style?.fontWeight}').toList()}',
      );
    });
  });

  group('LeafPanel — panel registry dispatch', () {
    testWidgets(
      'an unregistered panel id falls back to DefaultPanel',
      (tester) async {
        await _pump(tester, ancestors: [_unregisteredLeaf()]);
        expect(find.byType(DefaultPanel), findsOneWidget);
        // DefaultPanel must actually consume the leaf — the leaf
        // title surfaces inside the placeholder so contributors
        // can spot the unregistered id during development. If
        // DefaultPanel ever stopped honoring its `node` argument
        // this assertion would fail closed.
        expect(
          find.descendant(
            of: find.byType(DefaultPanel),
            matching: find.text('Ghost Panel'),
          ),
          findsOneWidget,
        );
      },
    );
  });

  group('LeafPanel — leaf change preserves prior bodies', () {
    testWidgets(
      'switching to a sibling leaf keeps both bodies mounted in the '
      'IndexedStack so internal state survives the swap',
      (tester) async {
        // Sibling leaves under the same branch — the IndexedStack
        // cache should retain the first leaf's body (kept at index 0)
        // when we swap in the second. We host LeafPanel inside a
        // stateful harness so the ancestors swap reaches the same
        // _LeafPanelState (rather than tearing down + remounting via
        // a fresh root pump).
        const branch = SettingsNode(
          id: 'sync',
          icon: Icons.sync_rounded,
          title: 'Sync',
          desc: '',
        );
        const first = SettingsNode(
          id: 'sync/backfill',
          icon: Icons.cloud_download_outlined,
          title: 'Backfill',
          desc: '',
          panel: 'unregistered-first',
        );
        const second = SettingsNode(
          id: 'sync/stats',
          icon: Icons.bar_chart_rounded,
          title: 'Stats',
          desc: '',
          panel: 'unregistered-second',
        );

        await setUpTestGetIt();
        addTearDown(tearDownTestGetIt);
        const harness = _LeafPanelHarness(
          initial: [branch, first],
        );
        await tester.pumpWidget(
          makeTestableWidgetNoScroll(
            const Material(
              child: SizedBox(
                width: 1000,
                height: 800,
                child: harness,
              ),
            ),
          ),
        );
        await tester.pump();

        // After the initial mount, the cache holds exactly one body.
        IndexedStack stackNow() =>
            tester.widget<IndexedStack>(find.byType(IndexedStack));
        expect(stackNow().children, hasLength(1));
        expect(stackNow().index, 0);

        // Mutate the ancestors via the harness — same LeafPanel widget
        // instance, didUpdateWidget fires, _ensureCached appends.
        _LeafPanelHarnessState.current!.swap(const [branch, second]);
        await tester.pump();

        // Both bodies are now cached and the active index points at
        // the second one (appended at position 1).
        expect(stackNow().children, hasLength(2));
        expect(stackNow().index, 1);

        // Swapping back to a leaf that was already visited must NOT
        // add a third cache entry — _ensureCached is idempotent — but
        // it MUST move the active index back to the existing slot.
        _LeafPanelHarnessState.current!.swap(const [branch, first]);
        await tester.pump();

        expect(stackNow().children, hasLength(2));
        expect(stackNow().index, 0);
      },
    );

    testWidgets(
      'a same-id leaf with a different payload rebuilds its cached body',
      (tester) async {
        // First mount uses an unregistered panel id → DefaultPanel
        // is cached for the leaf. Then the same id arrives with a
        // different node payload (a new title); the cache must
        // refresh so the rendered DefaultPanel reflects the new
        // payload — otherwise a regression that mutates a leaf in
        // place would surface the stale body forever.
        const branch = SettingsNode(
          id: 'sync',
          icon: Icons.sync_rounded,
          title: 'Sync',
          desc: '',
        );
        const initial = SettingsNode(
          id: 'sync/backfill',
          icon: Icons.cloud_download_outlined,
          title: 'Initial Title',
          desc: '',
          panel: 'unreg-payload-initial',
        );
        const updated = SettingsNode(
          id: 'sync/backfill',
          icon: Icons.cloud_download_outlined,
          title: 'Updated Title',
          desc: '',
          panel: 'unreg-payload-updated',
        );

        await setUpTestGetIt();
        addTearDown(tearDownTestGetIt);
        const harness = _LeafPanelHarness(initial: [branch, initial]);
        await tester.pumpWidget(
          makeTestableWidgetNoScroll(
            const Material(
              child: SizedBox(
                width: 1000,
                height: 800,
                child: harness,
              ),
            ),
          ),
        );
        await tester.pump();

        // Initial DefaultPanel surfaces the initial title.
        expect(
          find.descendant(
            of: find.byType(DefaultPanel),
            matching: find.text('Initial Title'),
          ),
          findsOneWidget,
        );

        // Same id, new payload — body must be rebuilt.
        _LeafPanelHarnessState.current!.swap(const [branch, updated]);
        await tester.pump();

        expect(
          find.descendant(
            of: find.byType(DefaultPanel),
            matching: find.text('Updated Title'),
          ),
          findsOneWidget,
        );
        expect(find.text('Initial Title'), findsNothing);

        // Cache stays single-entry — same id should never grow the
        // IndexedStack.
        final stack = tester.widget<IndexedStack>(find.byType(IndexedStack));
        expect(stack.children, hasLength(1));
      },
    );
  });

  group('LeafPanel — crumb interactions', () {
    testWidgets(
      'tapping a non-leaf crumb truncates the tree path to that depth',
      (tester) async {
        const branch = SettingsNode(
          id: 'sync',
          icon: Icons.sync_rounded,
          title: 'Sync Settings',
          desc: '',
        );
        const leaf = SettingsNode(
          id: 'sync/backfill',
          icon: Icons.cloud_download_outlined,
          title: 'Backfill Sync',
          desc: '',
          panel: 'unreg-backfill',
        );

        await _pump(tester, ancestors: const [branch, leaf]);

        final container = ProviderScope.containerOf(
          tester.element(find.byType(LeafPanel)),
        );
        // Seed a path so truncation has something to chop.
        container
            .read(settingsTreePathProvider.notifier)
            .syncFromUrl('/settings/sync/backfill');
        expect(
          container.read(settingsTreePathProvider),
          ['sync', 'sync/backfill'],
        );

        // Tap the "Sync Settings" crumb — depth 1, which should drop
        // the trailing leaf and leave the path at ['sync'].
        await tester.tap(find.text('Sync Settings'));
        await tester.pumpAndSettle();

        expect(container.read(settingsTreePathProvider), ['sync']);
      },
    );

    testWidgets(
      'tapping the synthetic root "Settings" crumb resets the path to []',
      (tester) async {
        const branch = SettingsNode(
          id: 'advanced',
          icon: Icons.settings_suggest_outlined,
          title: 'Advanced',
          desc: '',
        );
        const leaf = SettingsNode(
          id: 'advanced/about',
          icon: Icons.info_outline_rounded,
          title: 'About',
          desc: '',
          panel: 'unreg-about',
        );

        await _pump(tester, ancestors: const [branch, leaf]);

        final container = ProviderScope.containerOf(
          tester.element(find.byType(LeafPanel)),
        );
        container
            .read(settingsTreePathProvider.notifier)
            .syncFromUrl('/settings/advanced/about');
        expect(container.read(settingsTreePathProvider), isNotEmpty);

        // The root crumb is at index 0; the InkWell finder picks the
        // first crumb link.
        await tester.tap(find.text('Settings').first);
        await tester.pumpAndSettle();

        expect(container.read(settingsTreePathProvider), isEmpty);
      },
    );

    testWidgets(
      'hovering a crumb link repaints its label in the interactive accent',
      (tester) async {
        const branch = SettingsNode(
          id: 'sync',
          icon: Icons.sync_rounded,
          title: 'Sync Settings',
          desc: '',
        );
        const leaf = SettingsNode(
          id: 'sync/backfill',
          icon: Icons.cloud_download_outlined,
          title: 'Backfill Sync',
          desc: '',
          panel: 'unreg-backfill',
        );

        await _pump(tester, ancestors: const [branch, leaf]);

        final tokens = tester.element(find.byType(LeafPanel)).designTokens;
        final accent = tokens.colors.interactive.enabled;
        final defaultMid = tokens.colors.text.mediumEmphasis;

        // Locate the "Sync Settings" crumb-link Text widget — it is a
        // non-terminal segment so it's wrapped in _CrumbLink (an
        // InkWell). Pre-hover, its color must be the medium-emphasis
        // text token.
        Text crumbText() => tester
            .widgetList<Text>(find.text('Sync Settings'))
            .firstWhere(
              (t) => t.style?.color == defaultMid || t.style?.color == accent,
            );

        expect(crumbText().style?.color, defaultMid);

        // Send a hover event over the crumb's tap surface. We move
        // through the InkWell's hit region so MouseRegion fires
        // onEnter -> onHover(true).
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

  group('LeafPanel — full-width panel body', () {
    testWidgets(
      'fills the detail-pane width instead of centering under a cap',
      (tester) async {
        tester.view.physicalSize = const Size(1500, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await _pump(
          tester,
          ancestors: [_backfillLeaf()],
          width: 1500,
        );

        // Regression guard against the old 720 dp center-and-cap
        // treatment: no widget in the subtree should be limiting
        // the panel width to that value.
        final capped = find.descendant(
          of: find.byType(LeafPanel),
          matching: find.byWidgetPredicate(
            (w) => w is ConstrainedBox && w.constraints.maxWidth == 720,
          ),
        );
        expect(capped, findsNothing);

        // The panel itself should size to the full host width
        // (1500 dp here); the internal Padding shrinks the body by
        // step6 on each side but the outer widget still matches.
        expect(tester.getSize(find.byType(LeafPanel)).width, 1500);
      },
    );
  });
}

/// Stateful host that lets a single [LeafPanel] survive ancestors
/// swaps in-place. Without this, calling `tester.pumpWidget` again
/// would tear the widget down + remount, losing the indexed-stack
/// cache we're trying to verify.
class _LeafPanelHarness extends StatefulWidget {
  const _LeafPanelHarness({required this.initial});

  final List<SettingsNode> initial;

  @override
  State<_LeafPanelHarness> createState() => _LeafPanelHarnessState();
}

class _LeafPanelHarnessState extends State<_LeafPanelHarness> {
  static _LeafPanelHarnessState? current;
  late List<SettingsNode> _ancestors;

  @override
  void initState() {
    super.initState();
    _ancestors = widget.initial;
    current = this;
  }

  @override
  void dispose() {
    if (current == this) current = null;
    super.dispose();
  }

  void swap(List<SettingsNode> next) => setState(() => _ancestors = next);

  @override
  Widget build(BuildContext context) => LeafPanel(ancestors: _ancestors);
}
