import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/listing/agent_list_data.dart';
import 'package:lotti/features/agents/ui/listing/agent_list_filter_state.dart';
import 'package:lotti/features/agents/ui/listing/agent_listing_shell.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../../widget_test_utils.dart';

AgentListRowData _row({
  required String id,
  required String title,
  String? subtitle,
  Widget Function(BuildContext)? trailing,
  VoidCallback? onTap,
}) {
  return AgentListRowData(
    id: id,
    title: title,
    subtitle: subtitle,
    sortAt: DateTime(2026),
    searchKey: '$title $id ${subtitle ?? ''}'.toLowerCase(),
    trailing: trailing,
    onTap: onTap,
  );
}

AgentListGroupAxis _flatGroup() => AgentListGroupAxis(
  id: 'all',
  label: 'All',
  // Skip the group entirely when there are no rows so the shell's
  // empty-state branch fires (matches what real adapters do).
  buildGroups: (rows) => rows.isEmpty
      ? const []
      : [AgentListGroup(id: 'all', label: 'All', items: rows)],
);

/// A group axis whose single group is labelled after [id]+[label], so a
/// test can read off *which* group axis the shell is currently using
/// straight from the rendered group header.
AgentListGroupAxis _group(String id, String label) => AgentListGroupAxis(
  id: id,
  label: label,
  buildGroups: (rows) => rows.isEmpty
      ? const []
      : [AgentListGroup(id: 'grp:$id', label: 'GROUP[$label]', items: rows)],
);

AgentListSortAxis _byName() => AgentListSortAxis(
  id: 'name',
  label: 'Name',
  compare: (a, b) => a.title.compareTo(b.title),
);

/// A sort axis with a recognizable id/label and a caller-supplied
/// comparator, so the two sort axes a reseat test swaps between can impose
/// *genuinely different* row orderings. The default is an ascending
/// title sort; pass [descending] to flip it. Because the two axes order the
/// same rows oppositely, a reseat of `sortAxisId` becomes observable: the
/// rendered row order flips iff the sort axis actually changed.
AgentListSortAxis _sort(String id, String label, {bool descending = false}) =>
    AgentListSortAxis(
      id: id,
      label: label,
      compare: descending
          ? (a, b) => b.title.compareTo(a.title)
          : (a, b) => a.title.compareTo(b.title),
    );

/// Reads the rendered vertical order of the two seeded rows: returns
/// `true` when "Alpha" sits above "Bravo".
bool _alphaAboveBravo(WidgetTester tester) =>
    tester.getTopLeft(find.text('Alpha')).dy <
    tester.getTopLeft(find.text('Bravo')).dy;

void main() {
  setUp(() async {
    await setUpTestGetIt();
  });
  tearDown(() async {
    await tearDownTestGetIt();
  });

  Future<void> pumpShell(
    WidgetTester tester, {
    required AsyncValue<List<AgentListRowData>> rowsAsync,
    List<AgentListFilterAxis> filterAxes = const [],
    String empty = 'Nothing here',
    String placeholder = 'Search…',
    AgentListAxisMatcher matcher = _alwaysMatch,
    bool settle = true,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: AgentListingShell(
            rowsAsync: rowsAsync,
            filterAxes: filterAxes,
            groupAxes: [_flatGroup()],
            sortAxes: [_byName()],
            searchPlaceholder: placeholder,
            emptyMessage: empty,
            axisMatcher: matcher,
          ),
        ),
        mediaQueryData: const MediaQueryData(size: Size(1200, 900)),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      // Avoid pumpAndSettle when a CircularProgressIndicator is on screen
      // — it animates indefinitely and the test would time out.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  group('AgentListingShell — async branches', () {
    testWidgets('loading shows a spinner', (tester) async {
      await pumpShell(
        tester,
        rowsAsync: const AsyncValue.loading(),
        settle: false,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('error shows the localized common error message', (
      tester,
    ) async {
      await pumpShell(
        tester,
        rowsAsync: AsyncValue.error('boom', StackTrace.current),
      );
      final ctx = tester.element(find.byType(AgentListingShell));
      expect(find.text(ctx.messages.commonError), findsOneWidget);
    });

    testWidgets('empty data shows the page-supplied empty message', (
      tester,
    ) async {
      await pumpShell(
        tester,
        rowsAsync: const AsyncValue.data(<AgentListRowData>[]),
        empty: 'Nothing yet',
      );
      expect(find.text('Nothing yet'), findsOneWidget);
    });
  });

  group('AgentListingShell — trailing slot', () {
    testWidgets(
      'each row renders its custom trailing builder instead of the chevron',
      (tester) async {
        await pumpShell(
          tester,
          rowsAsync: AsyncValue.data([
            _row(
              id: 'r1',
              title: 'Row 1',
              trailing: (_) => const Text('CUSTOM-TRAIL-1'),
            ),
            _row(
              id: 'r2',
              title: 'Row 2',
              trailing: (_) => const Text('CUSTOM-TRAIL-2'),
            ),
          ]),
        );
        expect(find.text('CUSTOM-TRAIL-1'), findsOneWidget);
        expect(find.text('CUSTOM-TRAIL-2'), findsOneWidget);
        // Default chevron shouldn't render when trailing is supplied.
        expect(find.byIcon(Icons.chevron_right), findsNothing);
      },
    );

    testWidgets(
      'actionable rows without a trailing builder fall back to the chevron',
      (tester) async {
        await pumpShell(
          tester,
          rowsAsync: AsyncValue.data([
            _row(id: 'r1', title: 'Row 1', onTap: () {}),
          ]),
        );
        expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      },
    );

    testWidgets(
      'non-actionable rows render no chevron and no custom trailing',
      (tester) async {
        await pumpShell(
          tester,
          rowsAsync: AsyncValue.data([_row(id: 'r1', title: 'Row 1')]),
        );
        expect(find.byIcon(Icons.chevron_right), findsNothing);
      },
    );
  });

  group('AgentListingShell — search', () {
    testWidgets('typing narrows the visible row count', (tester) async {
      await pumpShell(
        tester,
        rowsAsync: AsyncValue.data([
          _row(id: 'a', title: 'Alpha'),
          _row(id: 'b', title: 'Bravo'),
        ]),
      );

      await tester.enterText(find.byType(TextField), 'alp');
      await tester.pumpAndSettle();

      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Bravo'), findsNothing);
    });
  });

  group('AgentListingShell — empty-state clear action', () {
    testWidgets(
      'filtering down to nothing surfaces a Clear-all button that restores '
      'the rows when tapped',
      (tester) async {
        await pumpShell(
          tester,
          rowsAsync: AsyncValue.data([
            _row(id: 'a', title: 'Alpha'),
            _row(id: 'b', title: 'Bravo'),
          ]),
        );

        // Search for something no row matches: the pipeline filters down to
        // zero rows, the flat group axis yields no groups, and the shell
        // renders `_EmptyState` with an active filter -> Clear-all visible.
        await tester.enterText(find.byType(TextField), 'zzz-no-match');
        await tester.pumpAndSettle();

        expect(find.text('Alpha'), findsNothing);
        expect(find.text('Bravo'), findsNothing);
        expect(find.text('Nothing here'), findsOneWidget);

        final ctx = tester.element(find.byType(AgentListingShell));
        final clearLabel = ctx.messages.agentInstancesFilterClearAll;
        final clearButton = find.widgetWithText(TextButton, clearLabel);
        expect(clearButton, findsOneWidget);

        // Tapping it runs the shell's onClear -> _setFilters(clearAll()).
        await tester.tap(clearButton);
        await tester.pumpAndSettle();

        // Filter is gone: both rows are back and the empty state (with its
        // Clear-all button) is no longer on screen.
        expect(find.text('Alpha'), findsOneWidget);
        expect(find.text('Bravo'), findsOneWidget);
        expect(find.text('Nothing here'), findsNothing);
        expect(find.widgetWithText(TextButton, clearLabel), findsNothing);
      },
    );

    testWidgets(
      'an empty dataset with no active filter shows no Clear-all button',
      (tester) async {
        await pumpShell(
          tester,
          rowsAsync: const AsyncValue.data(<AgentListRowData>[]),
        );

        final ctx = tester.element(find.byType(AgentListingShell));
        expect(find.text('Nothing here'), findsOneWidget);
        // onClear is null here, so the TextButton is not built at all.
        expect(
          find.widgetWithText(
            TextButton,
            ctx.messages.agentInstancesFilterClearAll,
          ),
          findsNothing,
        );
      },
    );
  });

  group('AgentListingShell — didUpdateWidget axis reseat', () {
    // Reseat only fires when the *currently selected* axis id disappears
    // from the new axis list. The shell seeds its selection from
    // `groupAxes.first.id` / `sortAxes.first.id` in initState, so the
    // harness starts with one set of axes and swaps to a disjoint set.
    testWidgets(
      'swapping in a group axis list without the selected id reseats to the '
      'new first group axis and regroups the rows',
      (tester) async {
        final harness = _AxisSwapHarness(
          // Two rows the two sort axes order oppositely, so a wrong sort
          // reseat would visibly flip them. Here the sort id survives, so
          // we assert the order does NOT flip.
          rows: [
            _row(id: 'a', title: 'Alpha'),
            _row(id: 'b', title: 'Bravo'),
          ],
          initialGroupAxes: [_group('g1', 'One')],
          // Ascending sort -> Alpha above Bravo.
          initialSortAxes: [_sort('s1', 'SortOne')],
          // New group axis list shares no id with 'g1' -> groupOk == false.
          swappedGroupAxes: [_group('g2', 'Two')],
          // Sort id 's1' survives -> sortOk == true (covers the `sortOk`
          // true branch of the reseat ternary). It is still ascending, so
          // the row order must stay Alpha-above-Bravo across the swap even
          // though a *descending* axis is offered second.
          swappedSortAxes: [
            _sort('s1', 'SortOne'),
            _sort('s2', 'SortTwo', descending: true),
          ],
        );
        final key = GlobalKey<_AxisSwapHarnessState>();

        await tester.binding.setSurfaceSize(const Size(1200, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          makeTestableWidgetNoScroll(
            Scaffold(
              body: _AxisSwapHost(key: key, config: harness),
            ),
            mediaQueryData: const MediaQueryData(size: Size(1200, 900)),
          ),
        );
        await tester.pumpAndSettle();

        // Before the swap the shell groups by 'g1' and sorts ascending.
        expect(find.text('GROUP[One]'), findsOneWidget);
        expect(find.text('GROUP[Two]'), findsNothing);
        expect(_alphaAboveBravo(tester), isTrue);

        key.currentState!.swap();
        await tester.pumpAndSettle();

        // After the reseat the dead 'g1' selection is replaced by 'g2', so
        // the rows are now grouped under the new axis's header. The still-
        // valid 's1' sort selection is preserved (not reset to the new
        // first axis 's2'), so the rows stay Alpha-above-Bravo — proving the
        // sort was NOT wrongly reseated when only the group axis changed.
        expect(find.text('GROUP[One]'), findsNothing);
        expect(find.text('GROUP[Two]'), findsOneWidget);
        expect(_alphaAboveBravo(tester), isTrue);
      },
    );

    testWidgets(
      'swapping in a sort axis list without the selected id reseats the sort '
      'while keeping the still-valid group selection',
      (tester) async {
        final harness = _AxisSwapHarness(
          // Two rows the two sort axes order oppositely, so the reseat of
          // the dead sort id to the new first axis is *observable*: the
          // rendered row order must flip after the swap.
          rows: [
            _row(id: 'a', title: 'Alpha'),
            _row(id: 'b', title: 'Bravo'),
          ],
          initialGroupAxes: [_group('g1', 'One')],
          // Ascending sort -> Alpha above Bravo before the swap.
          initialSortAxes: [_sort('s1', 'SortOne')],
          // Group id 'g1' survives -> groupOk == true (covers the `groupOk`
          // true branch of the reseat ternary).
          swappedGroupAxes: [_group('g1', 'One')],
          // Sort id 's1' is gone -> sortOk == false, forcing the reseat to
          // the new first axis 's2', which sorts *descending*. The new
          // ordering is the opposite of 's1', so the rows must flip.
          swappedSortAxes: [_sort('s2', 'SortTwo', descending: true)],
        );
        final key = GlobalKey<_AxisSwapHarnessState>();

        await tester.binding.setSurfaceSize(const Size(1200, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          makeTestableWidgetNoScroll(
            Scaffold(
              body: _AxisSwapHost(key: key, config: harness),
            ),
            mediaQueryData: const MediaQueryData(size: Size(1200, 900)),
          ),
        );
        await tester.pumpAndSettle();

        // Before the swap the surviving 's1' axis sorts ascending.
        expect(_alphaAboveBravo(tester), isTrue);

        key.currentState!.swap();
        await tester.pumpAndSettle();

        // Group selection 'g1' was still valid, so the group header is
        // unchanged; the reseat replaced the dead 's1' with the new first
        // axis 's2'. Because 's2' sorts descending, the rendered row order
        // flips to Bravo-above-Alpha — an observable consequence that would
        // fail if `sortAxisId` were never reseated.
        expect(find.text('GROUP[One]'), findsOneWidget);
        expect(_alphaAboveBravo(tester), isFalse);
      },
    );
  });
}

/// Static config the [_AxisSwapHost] flips between when its state is
/// swapped.
class _AxisSwapHarness {
  _AxisSwapHarness({
    required this.rows,
    required this.initialGroupAxes,
    required this.initialSortAxes,
    required this.swappedGroupAxes,
    required this.swappedSortAxes,
  });

  final List<AgentListRowData> rows;
  final List<AgentListGroupAxis> initialGroupAxes;
  final List<AgentListSortAxis> initialSortAxes;
  final List<AgentListGroupAxis> swappedGroupAxes;
  final List<AgentListSortAxis> swappedSortAxes;
}

/// Hosts a single [AgentListingShell] and rebuilds it with the harness's
/// swapped axes on demand, so the shell's `didUpdateWidget` fires against a
/// preserved State (the only way to exercise the axis-reseat path).
class _AxisSwapHost extends StatefulWidget {
  const _AxisSwapHost({required this.config, super.key});
  final _AxisSwapHarness config;

  @override
  State<_AxisSwapHost> createState() => _AxisSwapHarnessState();
}

class _AxisSwapHarnessState extends State<_AxisSwapHost> {
  bool _swapped = false;

  void swap() => setState(() => _swapped = true);

  @override
  Widget build(BuildContext context) {
    final c = widget.config;
    return AgentListingShell(
      rowsAsync: AsyncValue.data(c.rows),
      filterAxes: const [],
      groupAxes: _swapped ? c.swappedGroupAxes : c.initialGroupAxes,
      sortAxes: _swapped ? c.swappedSortAxes : c.initialSortAxes,
      searchPlaceholder: 'Search…',
      emptyMessage: 'Nothing here',
      axisMatcher: _alwaysMatch,
    );
  }
}

bool _alwaysMatch(String _, Set<String> _, AgentListRowData _) => true;
