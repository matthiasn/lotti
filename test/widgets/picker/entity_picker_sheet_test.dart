import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/checkboxes/design_system_checkbox.dart';
import 'package:lotti/features/design_system/components/selection/design_system_selection_row.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/widgets/picker/entity_picker_sheet.dart';
import 'package:material_ui/material_ui.dart';

import '../../test_helper.dart';

/// Direct tests for the feature-agnostic [EntityPickerSheet]. The category and
/// label adapters cover their own wiring; this file exercises the generic body
/// itself with synthetic entries — including the rows the adapters never emit
/// (disabled items, dividers) so every branch is covered at the source.
void main() {
  PickerItem item(
    String id, {
    String? title,
    String? subtitle,
    String? semanticLabel,
    bool enabled = true,
    List<Widget> badges = const [],
  }) => PickerItem(
    id: id,
    rowKey: ValueKey('row-$id'),
    leading: const SizedBox(width: 24, height: 24),
    title: title ?? id,
    subtitle: subtitle,
    semanticLabel: semanticLabel,
    enabled: enabled,
    badges: badges,
  );

  Future<void> pumpSheet(
    WidgetTester tester, {
    required PickerMode mode,
    required List<PickerItem> Function(String query) entriesBuilder,
    String? selectedId,
    ValueNotifier<Set<String>>? staged,
    FutureOr<void> Function(String id)? onPick,
    Future<String?> Function(String query)? createFromQuery,
    bool Function(String query)? shouldShowCreate,
    int titleMaxLines = 1,
    Future<void> Function(String query)? onQueryResolve,
  }) async {
    await tester.pumpWidget(
      WidgetTestBench(
        child: Material(
          child: EntityPickerSheet(
            mode: mode,
            titleMaxLines: titleMaxLines,
            entriesBuilder: entriesBuilder,
            searchHintText: 'Search',
            emptyMessage: 'Nothing here',
            selectedId: selectedId,
            stagedNotifier: staged,
            // Single mode requires an onPick; default to a no-op for tests that
            // don't assert on picking.
            onPick: onPick ?? (mode == PickerMode.single ? (_) {} : null),
            createFromQuery: createFromQuery,
            shouldShowCreate: shouldShowCreate,
            createRowKey: const ValueKey('create'),
            onQueryResolve: onQueryResolve,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // Creating is an exclusive act: the rows stay mounted and hit-testable
  // across the await, and whatever the pick starts (a link write, in the task
  // picker) outlives the callback that returned. Both are races that produce
  // duplicate entities or duplicate links.
  group('create exclusivity', () {
    testWidgets('a second tap while a create is pending is ignored', (
      tester,
    ) async {
      final write = Completer<String?>();
      var createCalls = 0;

      await pumpSheet(
        tester,
        mode: PickerMode.single,
        entriesBuilder: (_) => [],
        shouldShowCreate: (query) => query.isNotEmpty,
        createFromQuery: (_) {
          createCalls++;
          return write.future;
        },
      );

      await tester.enterText(find.byType(TextField), 'New thing');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('create')));
      await tester.pump();

      await tester.tap(
        find.byKey(const ValueKey('create')),
        warnIfMissed: false,
      );
      await tester.pump();

      expect(createCalls, 1);
      write.complete(null);
      await tester.pumpAndSettle();
    });

    testWidgets('existing rows are inert while a create is pending', (
      tester,
    ) async {
      final write = Completer<String?>();
      String? picked;

      await pumpSheet(
        tester,
        mode: PickerMode.single,
        onPick: (id) => picked = id,
        entriesBuilder: (_) => [item('alpha')],
        shouldShowCreate: (query) => query.isNotEmpty,
        createFromQuery: (_) => write.future,
      );

      await tester.enterText(find.byType(TextField), 'alpha extra');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('create')));
      await tester.pump();

      // Picking an existing row mid-create would commit whatever the caller
      // does on pick while the create was still pending — and the create's
      // own completion would then commit a second one.
      await tester.tap(
        find.byKey(const ValueKey('row-alpha')),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(picked, isNull);

      write.complete(null);
      await tester.pumpAndSettle();
    });

    testWidgets(
      'Enter cannot pick an existing item while a create is pending',
      (
        tester,
      ) async {
        final write = Completer<String?>();
        String? picked;

        await pumpSheet(
          tester,
          mode: PickerMode.single,
          onPick: (id) => picked = id,
          entriesBuilder: (_) => [item('alpha')],
          shouldShowCreate: (query) => query == 'brand new',
          createFromQuery: (_) => write.future,
        );

        await tester.enterText(find.byType(TextField), 'brand new');
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('create')));
        await tester.pump();

        // The field stays enabled during a create — the query is still worth
        // editing — so changing it to something that matches and pressing Enter
        // would otherwise pick an existing item mid-create.
        await tester.enterText(find.byType(TextField), 'alpha');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();
        expect(picked, isNull);

        write.complete(null);
        await tester.pumpAndSettle();
      },
    );

    testWidgets("the lock is held until the pick's own work completes", (
      tester,
    ) async {
      final linkWrite = Completer<void>();
      var picks = 0;

      await pumpSheet(
        tester,
        mode: PickerMode.single,
        onPick: (_) {
          picks++;
          return linkWrite.future;
        },
        entriesBuilder: (_) => [item('alpha')],
        shouldShowCreate: (query) => query.isNotEmpty,
        createFromQuery: (_) async => 'created-id',
      );

      await tester.enterText(find.byType(TextField), 'New thing');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('create')));
      await tester.pump();

      expect(picks, 1);

      // The create resolved, but the pick it triggered has not. Releasing the
      // lock on the callback's *return* rather than its completion would let
      // a second tap start another link here.
      await tester.tap(
        find.byKey(const ValueKey('row-alpha')),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(picks, 1);

      linkWrite.complete();
      await tester.pumpAndSettle();

      // Released once the pick's work landed.
      await tester.tap(find.byKey(const ValueKey('row-alpha')));
      await tester.pump();
      expect(picks, 2);
    });
  });

  group('single mode', () {
    testWidgets('renders items without dividers and applies the tapped id', (
      tester,
    ) async {
      String? picked;
      await pumpSheet(
        tester,
        mode: PickerMode.single,
        onPick: (id) => picked = id,
        entriesBuilder: (_) => [item('alpha'), item('beta')],
      );

      expect(find.text('alpha'), findsOneWidget);
      expect(find.text('beta'), findsOneWidget);
      expect(find.byType(Divider), findsNothing);

      await tester.tap(find.text('beta'));
      await tester.pump();
      expect(picked, 'beta');
    });

    testWidgets('the selected id shows a trailing check, others do not', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        mode: PickerMode.single,
        selectedId: 'beta',
        entriesBuilder: (_) => [item('alpha'), item('beta')],
      );

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('row-beta')),
          matching: find.byIcon(LottiIcons.confirm),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('row-alpha')),
          matching: find.byIcon(LottiIcons.confirm),
        ),
        findsNothing,
      );
    });

    testWidgets('renders row metadata badges before the selection marker', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        mode: PickerMode.single,
        selectedId: 'alpha',
        entriesBuilder: (_) => [
          item(
            'alpha',
            badges: const [Text('Default')],
          ),
        ],
      );

      final row = find.byKey(const ValueKey('row-alpha'));
      expect(
        find.descendant(of: row, matching: find.text('Default')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: row,
          matching: find.byIcon(LottiIcons.confirm),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Enter applies the first filtered item', (tester) async {
      String? picked;
      await pumpSheet(
        tester,
        mode: PickerMode.single,
        onPick: (id) => picked = id,
        entriesBuilder: (query) => [
          for (final id in ['alpha', 'beta'])
            if (query.isEmpty || id.contains(query)) item(id),
        ],
      );

      await tester.enterText(find.byType(TextField), 'bet');
      await tester.pump();
      await tester.showKeyboard(find.byType(TextField));
      await tester.testTextInput.receiveAction(TextInputAction.search);

      expect(picked, 'beta');
    });
  });

  group('disabled rows', () {
    testWidgets('a disabled row is not tappable and is dimmed', (tester) async {
      String? picked;
      await pumpSheet(
        tester,
        mode: PickerMode.single,
        onPick: (id) => picked = id,
        entriesBuilder: (_) => [
          item('on'),
          item('off', enabled: false),
        ],
      );

      await tester.tap(find.text('off'));
      await tester.pump();
      // The disabled row swallows the tap: onPick was never called.
      expect(picked, isNull);

      final disabledOpacity = tester.widget<Opacity>(
        find.descendant(
          of: find.byKey(const ValueKey('row-off')),
          matching: find.byType(Opacity),
        ),
      );
      expect(
        disabledOpacity.opacity,
        tester
            .element(find.byType(EntityPickerSheet))
            .designTokens
            .colors
            .text
            .lowEmphasis
            .a,
      );
    });

    testWidgets('a disabled row announces a disabled semantics state', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpSheet(
        tester,
        mode: PickerMode.single,
        entriesBuilder: (_) => [item('off', enabled: false)],
      );

      final node = tester
          .getSemantics(find.byKey(const ValueKey('row-off')))
          .getSemanticsData()
          .flagsCollection;
      expect(node.isEnabled, Tristate.isFalse);

      handle.dispose();
    });
  });

  group('multi mode', () {
    testWidgets('checkbox toggles the staged set', (tester) async {
      final staged = ValueNotifier<Set<String>>({});
      addTearDown(staged.dispose);

      await pumpSheet(
        tester,
        mode: PickerMode.multi,
        staged: staged,
        entriesBuilder: (_) => [item('alpha'), item('beta')],
      );

      await tester.tap(find.text('alpha'));
      await tester.pump();
      expect(staged.value, {'alpha'});

      await tester.tap(find.text('alpha'));
      await tester.pump();
      expect(staged.value, isEmpty);
    });

    testWidgets('a seeded id renders its checkbox as checked', (tester) async {
      final staged = ValueNotifier<Set<String>>({'beta'});
      addTearDown(staged.dispose);

      await pumpSheet(
        tester,
        mode: PickerMode.multi,
        staged: staged,
        entriesBuilder: (_) => [item('alpha'), item('beta')],
      );

      bool? checked(String id) => tester
          .widget<DesignSystemCheckbox>(
            find.descendant(
              of: find.byKey(ValueKey('row-$id')),
              matching: find.byType(DesignSystemCheckbox),
            ),
          )
          .value;
      expect(checked('beta'), isTrue);
      expect(checked('alpha'), isFalse);
    });
  });

  group('empty + create', () {
    testWidgets('shows the empty message when there are no items', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        mode: PickerMode.single,
        entriesBuilder: (_) => const [],
      );

      expect(find.text('Nothing here'), findsOneWidget);
    });

    testWidgets('single create picks the returned id', (tester) async {
      String? picked;
      await pumpSheet(
        tester,
        mode: PickerMode.single,
        onPick: (id) => picked = id,
        createFromQuery: (query) async => 'created-$query',
        shouldShowCreate: (query) => query.isNotEmpty,
        entriesBuilder: (_) => const [],
      );

      await tester.enterText(find.byType(TextField), 'new');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('create')));
      await tester.pump();

      expect(picked, 'created-new');
    });

    testWidgets('submitting the query while the create row shows fires create', (
      tester,
    ) async {
      String? picked;
      await pumpSheet(
        tester,
        mode: PickerMode.single,
        onPick: (id) => picked = id,
        createFromQuery: (query) async => 'created-$query',
        shouldShowCreate: (query) => query.isNotEmpty,
        entriesBuilder: (_) => const [],
      );

      await tester.enterText(find.byType(TextField), 'new');
      await tester.pump();
      // Enter while the create row is shown creates rather than picking a match.
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();

      expect(picked, 'created-new');
    });

    testWidgets('the search clear button resets the query', (tester) async {
      var lastQuery = '<none>';
      await pumpSheet(
        tester,
        mode: PickerMode.single,
        entriesBuilder: (query) {
          lastQuery = query;
          return [item('alpha'), item('beta')];
        },
      );

      await tester.enterText(find.byType(TextField), 'beta');
      await tester.pump();
      expect(lastQuery, 'beta');

      // The clear affordance (cancel glyph) empties the query.
      await tester.tap(find.byIcon(LottiIcons.closeCircled));
      await tester.pump();
      expect(lastQuery, '');
    });

    testWidgets('multi create stages the new id and clears the query', (
      tester,
    ) async {
      final staged = ValueNotifier<Set<String>>({});
      addTearDown(staged.dispose);

      await pumpSheet(
        tester,
        mode: PickerMode.multi,
        staged: staged,
        createFromQuery: (query) async => 'created-$query',
        shouldShowCreate: (query) => query.isNotEmpty,
        entriesBuilder: (_) => const [],
      );

      await tester.enterText(find.byType(TextField), 'new');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('create')));
      await tester.pump();

      expect(staged.value, {'created-new'});
      // The query was cleared, so the stale create row is gone.
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(find.byKey(const ValueKey('create')), findsNothing);
    });
  });

  group('layout', () {
    testWidgets(
      'insets the search field from the modal header instead of welding it '
      'to the divider',
      (tester) async {
        await pumpSheet(
          tester,
          mode: PickerMode.single,
          entriesBuilder: (_) => [item('alpha')],
        );

        // Callers pass padding: EdgeInsets.zero to the modal to control the
        // row indent, so the sheet has to supply its own top inset.
        final sheetTop = tester.getTopLeft(find.byType(EntityPickerSheet)).dy;
        final searchTop = tester.getTopLeft(find.byType(TextField)).dy;
        expect(searchTop - sheetTop, greaterThan(0));
      },
    );

    testWidgets(
      'caps row titles at one line by default and honours a raised cap',
      (tester) async {
        await pumpSheet(
          tester,
          mode: PickerMode.single,
          entriesBuilder: (_) => [item('alpha', title: 'A very long title')],
        );
        expect(
          tester
              .widget<DesignSystemSelectionRow>(
                find.byType(DesignSystemSelectionRow),
              )
              .titleMaxLines,
          1,
        );

        await pumpSheet(
          tester,
          mode: PickerMode.single,
          entriesBuilder: (_) => [item('alpha', title: 'A very long title')],
          titleMaxLines: 2,
        );
        expect(
          tester
              .widget<DesignSystemSelectionRow>(
                find.byType(DesignSystemSelectionRow),
              )
              .titleMaxLines,
          2,
        );
      },
    );
  });

  group('construction contracts', () {
    test('multi mode requires a stagedNotifier', () {
      expect(
        () => EntityPickerSheet(
          mode: PickerMode.multi,
          entriesBuilder: (_) => const [],
          searchHintText: 'Search',
          emptyMessage: 'Nothing here',
        ),
        throwsAssertionError,
      );
    });

    test('single mode requires an onPick callback', () {
      expect(
        () => EntityPickerSheet(
          mode: PickerMode.single,
          entriesBuilder: (_) => const [],
          searchHintText: 'Search',
          emptyMessage: 'Nothing here',
        ),
        throwsAssertionError,
      );
    });
  });

  group('semantics', () {
    testWidgets('the row announces its explicit semanticLabel', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpSheet(
        tester,
        mode: PickerMode.single,
        entriesBuilder: (_) => [
          item('alpha', title: 'Alpha', semanticLabel: 'Alpha, favorite'),
        ],
      );

      final node = tester.getSemantics(find.byKey(const ValueKey('row-alpha')));
      expect(node.label, 'Alpha, favorite');

      handle.dispose();
    });
  });

  // A picker whose rows depend on a database lookup used to recompute on every
  // keystroke against results that had not caught up, so a query mid-flight
  // rendered as "nothing found" with no create row and the sheet resized twice
  // per character. These pin the settling contract that replaced it: the sheet
  // holds the last complete answer until the next one is ready.
  group('async query settling', () {
    /// What each query is worth, so "which query is the sheet showing" reads
    /// straight off the tree.
    const catalog = <String, List<String>>{
      '': ['alpha', 'beta'],
      'al': ['alpha'],
      'zz': <String>[],
    };

    List<PickerItem> catalogBuilder(String query) => [
      for (final id in catalog[query] ?? const <String>[]) item(id),
    ];

    Finder row(String id) => find.byKey(ValueKey('row-$id'));
    Finder emptyState() => find.text('Nothing here');

    /// Types [query] without letting the debounce elapse.
    Future<void> type(WidgetTester tester, String query) =>
        tester.enterText(find.byType(TextField), query);

    /// Types [query] and lets the debounce fire, leaving the resolve in
    /// flight for the test to release.
    Future<void> typeAndDebounce(WidgetTester tester, String query) async {
      await type(tester, query);
      await tester.pump(entityPickerSearchDebounce);
    }

    testWidgets(
      'holds the last complete result set on screen while the next query '
      'resolves, instead of flashing the empty state',
      (tester) async {
        final gate = _ResolveGate();
        await pumpSheet(
          tester,
          mode: PickerMode.single,
          entriesBuilder: catalogBuilder,
          onQueryResolve: gate.call,
        );
        expect(row('alpha'), findsOneWidget);

        await typeAndDebounce(tester, 'zz');

        // The lookup for "zz" is out. Recomputing here is what produced the
        // false "nothing found" — the sheet has no answer for "zz" yet, so it
        // must keep showing the one it does have.
        expect(gate.queries, ['zz']);
        expect(row('alpha'), findsOneWidget);
        expect(row('beta'), findsOneWidget);
        expect(emptyState(), findsNothing);

        gate.release();
        await tester.pump();

        // Resolved: now the empty state is the truth rather than a gap.
        expect(row('alpha'), findsNothing);
        expect(emptyState(), findsOneWidget);
      },
    );

    testWidgets('a burst of keystrokes resolves once, for the final query', (
      tester,
    ) async {
      final gate = _ResolveGate();
      await pumpSheet(
        tester,
        mode: PickerMode.single,
        entriesBuilder: catalogBuilder,
        onQueryResolve: gate.call,
      );

      // Three characters inside one debounce window.
      await type(tester, 'a');
      await tester.pump(const Duration(milliseconds: 60));
      await type(tester, 'al');
      await tester.pump(const Duration(milliseconds: 60));
      await type(tester, 'zz');
      expect(gate.queries, isEmpty);

      await tester.pump(entityPickerSearchDebounce);

      // One lookup for the query that survived, not one per character.
      expect(gate.queries, ['zz']);
    });

    testWidgets('an emptied field applies at once, with no lookup at all', (
      tester,
    ) async {
      final gate = _ResolveGate();
      await pumpSheet(
        tester,
        mode: PickerMode.single,
        entriesBuilder: catalogBuilder,
        onQueryResolve: gate.call,
      );

      await typeAndDebounce(tester, 'al');
      gate.release();
      await tester.pump();
      expect(row('beta'), findsNothing);

      await type(tester, '');
      await tester.pump();

      // Clearing is not a search: there is nothing to look up, so the full
      // list snaps back in the same frame rather than after a debounce.
      expect(gate.queries, ['al']);
      expect(row('beta'), findsOneWidget);
    });

    testWidgets('clearing the field strands the lookup it interrupted', (
      tester,
    ) async {
      final gate = _ResolveGate();
      await pumpSheet(
        tester,
        mode: PickerMode.single,
        entriesBuilder: catalogBuilder,
        onQueryResolve: gate.call,
      );

      await typeAndDebounce(tester, 'al');
      await type(tester, '');
      await tester.pump();
      expect(row('beta'), findsOneWidget);

      gate.release();
      await tester.pump();

      // The abandoned query must not reassert itself over the cleared field.
      expect(row('beta'), findsOneWidget);
    });

    testWidgets('a lookup that throws still advances the query', (
      tester,
    ) async {
      final gate = _ResolveGate();
      await pumpSheet(
        tester,
        mode: PickerMode.single,
        entriesBuilder: catalogBuilder,
        onQueryResolve: gate.call,
      );

      await typeAndDebounce(tester, 'zz');
      gate.fail();
      await tester.pump();

      // An index that is simply unavailable must not freeze the list on a
      // query the user has already left.
      expect(row('alpha'), findsNothing);
      expect(emptyState(), findsOneWidget);
    });

    testWidgets('a keystroke supersedes an in-flight lookup immediately', (
      tester,
    ) async {
      final gate = _ResolveGate();
      await pumpSheet(
        tester,
        mode: PickerMode.single,
        entriesBuilder: catalogBuilder,
        onQueryResolve: gate.call,
      );

      // "al" gets far enough to start its lookup...
      await typeAndDebounce(tester, 'al');
      expect(gate.queries, ['al']);

      // ...then the user types on, while that lookup is still out. The next
      // debounce has not fired yet, so nothing new has started.
      await type(tester, 'alp');
      gate.release(0);
      await tester.pump();

      // Superseding only when the *next* resolve started left the old lookup
      // holding the current generation for the whole debounce window, so it
      // committed and the sheet showed "al" rows while the field read "alp".
      //
      // "beta" is the discriminator: it belongs to the settled "" and not to
      // "al", so its presence is what says the abandoned query never landed.
      // ("alpha" is in both catalogs and would prove nothing either way.)
      expect(row('beta'), findsOneWidget, reason: 'still the settled ""');
      expect(row('alpha'), findsOneWidget, reason: '"" lists both');
    });

    testWidgets('a superseded lookup never commits over a newer one', (
      tester,
    ) async {
      final gate = _ResolveGate();
      await pumpSheet(
        tester,
        mode: PickerMode.single,
        entriesBuilder: catalogBuilder,
        onQueryResolve: gate.call,
      );

      await typeAndDebounce(tester, 'al');
      await typeAndDebounce(tester, 'zz');
      expect(gate.queries, ['al', 'zz']);

      // The older lookup lands last.
      gate.release(0);
      await tester.pump();
      expect(row('alpha'), findsOneWidget, reason: 'still the settled ""');
      expect(row('beta'), findsOneWidget);

      gate.release(1);
      await tester.pumpAndSettle();
      expect(emptyState(), findsOneWidget);
    });

    testWidgets('without a resolve hook every keystroke applies at once', (
      tester,
    ) async {
      // The category and label pickers filter a list they already hold; making
      // them wait would add latency and buy nothing.
      await pumpSheet(
        tester,
        mode: PickerMode.single,
        entriesBuilder: catalogBuilder,
      );

      await type(tester, 'al');
      await tester.pump();

      expect(row('alpha'), findsOneWidget);
      expect(row('beta'), findsNothing);
    });

    testWidgets('the create row shows the settled query, not the typed one', (
      tester,
    ) async {
      final gate = _ResolveGate();
      await pumpSheet(
        tester,
        mode: PickerMode.single,
        entriesBuilder: catalogBuilder,
        createFromQuery: (query) async => 'created-$query',
        shouldShowCreate: (query) => query.isNotEmpty,
        onQueryResolve: gate.call,
      );

      Finder createRowText(String text) => find.descendant(
        of: find.byKey(const ValueKey('create')),
        matching: find.text(text),
      );

      await typeAndDebounce(tester, 'al');
      gate.release();
      await tester.pump();
      expect(createRowText('al'), findsOneWidget);

      await typeAndDebounce(tester, 'zz');

      // Its label, its eligibility and the rows beside it all describe one
      // query. Labelling it from the live field while its eligibility came
      // from the settled one would offer to create a name nothing had checked.
      expect(createRowText('al'), findsOneWidget);
      expect(createRowText('zz'), findsNothing);
    });

    testWidgets('Enter flushes a pending debounce and acts on what was typed', (
      tester,
    ) async {
      final gate = _ResolveGate();
      String? picked;
      await pumpSheet(
        tester,
        mode: PickerMode.single,
        entriesBuilder: catalogBuilder,
        onPick: (id) => picked = id,
        onQueryResolve: gate.call,
      );

      // Enter lands inside the debounce window, before any lookup has run.
      await type(tester, 'al');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      expect(gate.queries, ['al']);

      gate.release();
      await tester.pumpAndSettle();

      // Not "alpha, beta" — Enter waited for its own query's answer rather
      // than applying the first row of the previous one.
      expect(picked, 'alpha');
    });

    testWidgets('Enter does nothing when a keystroke overtakes its flush', (
      tester,
    ) async {
      final gate = _ResolveGate();
      String? picked;
      await pumpSheet(
        tester,
        mode: PickerMode.single,
        entriesBuilder: catalogBuilder,
        onPick: (id) => picked = id,
        onQueryResolve: gate.call,
      );

      await type(tester, 'al');
      await tester.testTextInput.receiveAction(TextInputAction.search);

      // The user keeps typing while the flush is still out.
      await type(tester, 'zz');
      gate.release();
      await tester.pumpAndSettle();

      // Applying "al"'s first row now would commit a task the user had already
      // typed past.
      expect(picked, isNull);
    });

    testWidgets('Enter does nothing when the field is emptied mid-flush', (
      tester,
    ) async {
      final gate = _ResolveGate();
      String? picked;
      await pumpSheet(
        tester,
        mode: PickerMode.single,
        entriesBuilder: catalogBuilder,
        onPick: (id) => picked = id,
        onQueryResolve: gate.call,
      );

      await type(tester, 'al');
      await tester.testTextInput.receiveAction(TextInputAction.search);

      // Clearing moves the typed query *and* the settled query to '', so a
      // guard that re-read the typed value would find them equal and fall
      // through — applying the first row of the unfiltered list and linking a
      // task the user never picked.
      await type(tester, '');
      gate.release();
      await tester.pumpAndSettle();

      expect(picked, isNull);
      // The cleared field is what the sheet ended up showing, not "al".
      expect(row('beta'), findsOneWidget);
    });

    testWidgets('Enter stays a no-op in multi mode after the flush', (
      tester,
    ) async {
      final gate = _ResolveGate();
      final staged = ValueNotifier<Set<String>>({});
      addTearDown(staged.dispose);

      await pumpSheet(
        tester,
        mode: PickerMode.multi,
        staged: staged,
        entriesBuilder: catalogBuilder,
        onQueryResolve: gate.call,
      );

      await type(tester, 'al');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      gate.release();
      await tester.pumpAndSettle();

      // There is no single submit target in multi mode; selection is toggled
      // per row and committed via the Apply footer. Flushing must not turn
      // Enter into a silent selection of the first match.
      expect(staged.value, isEmpty);
      expect(row('alpha'), findsOneWidget);
    });

    testWidgets('disposing cancels a pending debounce', (tester) async {
      final gate = _ResolveGate();
      await pumpSheet(
        tester,
        mode: PickerMode.single,
        entriesBuilder: catalogBuilder,
        onQueryResolve: gate.call,
      );

      await type(tester, 'al');
      // Torn down mid-window. An uncancelled timer fails the test at teardown,
      // which is the whole assertion here.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(entityPickerSearchDebounce);

      expect(gate.queries, isEmpty);
    });

    testWidgets('a lookup landing after disposal is dropped quietly', (
      tester,
    ) async {
      final gate = _ResolveGate();
      await pumpSheet(
        tester,
        mode: PickerMode.single,
        entriesBuilder: catalogBuilder,
        onQueryResolve: gate.call,
      );

      await typeAndDebounce(tester, 'al');
      await tester.pumpWidget(const SizedBox.shrink());

      gate.release();
      await tester.pump();

      // setState on a disposed State throws; the commit has to notice.
      expect(tester.takeException(), isNull);
    });
  });
}

/// A controllable [EntityPickerSheet.onQueryResolve].
///
/// Records the queries it is asked to resolve and holds each one open until
/// the test releases it, so the window between a keystroke and its answer —
/// invisible in production, and where the flicker lived — can be asserted on.
///
/// Instantiated inside a test body, never in `setUp`: a completer created
/// outside the test's fake-async zone never resolves inside it.
class _ResolveGate {
  final List<String> queries = [];
  final List<Completer<void>> _gates = [];

  Future<void> call(String query) {
    queries.add(query);
    final gate = Completer<void>();
    _gates.add(gate);
    return gate.future;
  }

  /// Releases the resolve for `queries[index]`, or the most recent one.
  void release([int? index]) => _gates[index ?? _gates.length - 1].complete();

  /// Fails the resolve for `queries[index]`, or the most recent one.
  void fail([int? index]) => _gates[index ?? _gates.length - 1].completeError(
    Exception('lookup unavailable'),
  );
}
