import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/settings_v2/domain/settings_node.dart';
import 'package:lotti/features/settings_v2/ui/detail/default_panel.dart';
import 'package:lotti/features/settings_v2/ui/detail/leaf_panel.dart';

import '../../../../widget_test_utils.dart';

// LeafPanel uses deliberately-unregistered panel ids so every case
// exercises the dispatch path with DefaultPanel as the body. The
// registry tests (`panel_registry_test.dart`) cover real-panel
// resolution; duplicating that here would pull in the entire
// sync/backfill provider graph just to exercise the IndexedStack
// cache.
SettingsNode _backfillLeaf() => const SettingsNode(
  id: 'sync/backfill',
  icon: Icons.cloud_download_outlined,
  title: 'Backfill Sync',
  desc: '',
  panel: 'test-unregistered-sync-backfill',
);

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
  double height = 800,
}) async {
  await setUpTestGetIt();
  addTearDown(tearDownTestGetIt);
  await tester.pumpWidget(
    makeTestableWidgetNoScroll(
      Material(
        child: SizedBox(
          width: width,
          height: height,
          child: LeafPanel(ancestors: ancestors),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
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

  group('LeafPanel — chrome consolidated up to the page header', () {
    testWidgets(
      'renders no in-pane crumb trail (the page header owns the breadcrumbs)',
      (tester) async {
        // The chevron used by the old _LocalCrumbs row must not
        // appear in the LeafPanel subtree — its presence would mean
        // the header consolidation regressed and we'd be back to
        // duplicate breadcrumbs.
        await _pump(tester, ancestors: [_backfillLeaf()]);
        expect(
          find.descendant(
            of: find.byType(LeafPanel),
            matching: find.text('›'),
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'wraps no outer Padding around the body — the panel fills the pane '
      'edge-to-edge',
      (tester) async {
        // After the consolidation, LeafPanel.build returns the
        // IndexedStack directly. Asserting the IndexedStack matches
        // the LeafPanel size proves no Padding / SizedBox / etc. is
        // shrinking the body — the regression we want to catch is
        // someone reintroducing a step6/step5 gutter and silently
        // costing the user 24+ dp on each side.
        await _pump(
          tester,
          ancestors: [_backfillLeaf()],
          width: 900,
          height: 700,
        );
        final leafSize = tester.getSize(find.byType(LeafPanel));
        final stackSize = tester.getSize(find.byType(IndexedStack));
        expect(stackSize, leafSize);
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

    testWidgets(
      'returning to a cached leaf whose payload changed off-screen '
      'rebuilds its body instead of replaying the stale slot',
      (tester) async {
        // Scenario: leaf A is cached (Initial), the user navigates to
        // sibling B, then leaf A is mutated in place while it's
        // off-screen, then the user navigates back. `_ensureCached`
        // must spot that the cached `SettingsNode` differs from the
        // incoming one and rebuild — otherwise the user sees the old
        // payload (e.g. a `DefaultPanel` placeholder for a leaf whose
        // panel got wired up while they were away).
        const branch = SettingsNode(
          id: 'sync',
          icon: Icons.sync_rounded,
          title: 'Sync',
          desc: '',
        );
        const aInitial = SettingsNode(
          id: 'sync/backfill',
          icon: Icons.cloud_download_outlined,
          title: 'A Initial',
          desc: '',
          panel: 'unreg-revisit-a-initial',
        );
        const aUpdated = SettingsNode(
          id: 'sync/backfill',
          icon: Icons.cloud_download_outlined,
          title: 'A Updated',
          desc: '',
          panel: 'unreg-revisit-a-updated',
        );
        const sibling = SettingsNode(
          id: 'sync/stats',
          icon: Icons.bar_chart_rounded,
          title: 'Sibling',
          desc: '',
          panel: 'unreg-revisit-sibling',
        );

        await setUpTestGetIt();
        addTearDown(tearDownTestGetIt);
        const harness = _LeafPanelHarness(initial: [branch, aInitial]);
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

        expect(find.text('A Initial'), findsOneWidget);

        // Switch to the sibling leaf — A is now cached but off-screen.
        _LeafPanelHarnessState.current!.swap(const [branch, sibling]);
        await tester.pump();
        expect(find.text('Sibling'), findsOneWidget);

        // Return to A, but with a mutated payload. The cached slot
        // must refresh — without the fix, "A Initial" would still be
        // the body and "A Updated" would never appear.
        _LeafPanelHarnessState.current!.swap(const [branch, aUpdated]);
        await tester.pump();

        expect(find.text('A Updated'), findsOneWidget);
        expect(find.text('A Initial'), findsNothing);

        // Cache size unchanged — A's slot was rebuilt, not appended.
        final stack = tester.widget<IndexedStack>(find.byType(IndexedStack));
        expect(stack.children, hasLength(2));
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
        // (1500 dp here). Now that the outer Padding has been
        // removed too, the body matches the host exactly.
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
