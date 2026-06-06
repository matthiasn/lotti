import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/listing/agent_list_data.dart';
import 'package:lotti/features/agents/ui/listing/agent_list_filter_state.dart';
import 'package:lotti/features/agents/ui/listing/widgets/agent_list_toolbar.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../../../widget_test_utils.dart';

const _initialState = AgentListFilterState(
  groupAxisId: 'soul',
  sortAxisId: 'recent',
);

final _filterAxes = [
  const AgentListFilterAxis(
    id: 'type',
    sectionLabel: 'Type',
    options: [
      AgentListFilterOption(id: 'taskAgent', label: 'Task agent', count: 7),
      AgentListFilterOption(id: 'dayAgent', label: 'Day agent', count: 2),
    ],
  ),
  const AgentListFilterAxis(
    id: 'status',
    sectionLabel: 'Status',
    options: [
      AgentListFilterOption(id: 'active', label: 'Active', count: 5),
      AgentListFilterOption(id: 'archived', label: 'Archived', count: 4),
    ],
  ),
];

List<AgentListGroupAxis> _groupAxes() => [
  AgentListGroupAxis(id: 'soul', label: 'Soul', buildGroups: (rows) => []),
  AgentListGroupAxis(id: 'status', label: 'Status', buildGroups: (rows) => []),
];

List<AgentListSortAxis> _sortAxes() => [
  AgentListSortAxis(id: 'recent', label: 'Recent', compare: (a, b) => 0),
  AgentListSortAxis(id: 'name', label: 'Name', compare: (a, b) => 0),
];

/// Stateful host: applies every `onChanged` so the toolbar re-renders with
/// the new state, mirroring how `AgentListingShell` owns the state.
class _ToolbarHost extends StatefulWidget {
  const _ToolbarHost({this.onState});

  final ValueChanged<AgentListFilterState>? onState;

  @override
  State<_ToolbarHost> createState() => _ToolbarHostState();
}

class _ToolbarHostState extends State<_ToolbarHost> {
  AgentListFilterState state = _initialState;

  @override
  Widget build(BuildContext context) {
    return AgentListToolbar(
      state: state,
      onChanged: (next) {
        setState(() => state = next);
        widget.onState?.call(next);
      },
      totalBeforeFilter: 9,
      totalAfterFilter: state.isAnyFilterActive ? 5 : 9,
      filterAxes: _filterAxes,
      groupAxes: _groupAxes(),
      sortAxes: _sortAxes(),
      searchPlaceholder: 'Search agents…',
    );
  }
}

void main() {
  setUp(() async {
    await setUpTestGetIt();
  });
  tearDown(tearDownTestGetIt);

  late BuildContext capturedContext;

  Future<_ToolbarHostState> pumpToolbar(
    WidgetTester tester, {
    ValueChanged<AgentListFilterState>? onState,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: Builder(
            builder: (context) {
              capturedContext = context;
              return _ToolbarHost(onState: onState);
            },
          ),
        ),
        mediaQueryData: const MediaQueryData(size: Size(1200, 900)),
      ),
    );
    await tester.pump();
    return tester.state<_ToolbarHostState>(find.byType(_ToolbarHost));
  }

  Future<void> openFilters(WidgetTester tester) async {
    await tester.tap(
      find.text(capturedContext.messages.agentInstancesToolbarFilters),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  group('AgentListToolbar', () {
    testWidgets(
      'renders the buttons, search field and the unfiltered result count',
      (tester) async {
        await pumpToolbar(tester);
        final messages = capturedContext.messages;

        expect(
          find.text(messages.agentInstancesToolbarFilters),
          findsOneWidget,
        );
        // Group-by button shows the current axis label, sort its label.
        expect(
          find.textContaining(messages.agentInstancesToolbarGroupBy),
          findsOneWidget,
        );
        expect(find.text('Recent'), findsOneWidget);
        expect(find.text('Search agents…'), findsOneWidget);
        expect(
          find.text(messages.agentInstancesResultCountAll(9)),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'filters popover shows one section per axis with per-option counts',
      (tester) async {
        await pumpToolbar(tester);
        await openFilters(tester);

        // Section headers render uppercased.
        expect(find.text('TYPE'), findsOneWidget);
        expect(find.text('STATUS'), findsOneWidget);
        // Option rows with their full-dataset count badges.
        expect(find.text('Task agent'), findsOneWidget);
        expect(find.text('7'), findsOneWidget);
        expect(find.text('Day agent'), findsOneWidget);
        expect(find.text('2'), findsOneWidget);
        expect(find.text('Active'), findsOneWidget);
        expect(find.text('5'), findsOneWidget);
        expect(find.text('Archived'), findsOneWidget);
        expect(find.text('4'), findsOneWidget);
      },
    );

    testWidgets('tapping outside the popover closes it', (tester) async {
      await pumpToolbar(tester);
      await openFilters(tester);
      expect(find.text('Task agent'), findsOneWidget);

      // The barrier covers the whole screen; tap far away from the panel.
      await tester.tapAt(const Size(1200, 900).center(Offset.zero));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Task agent'), findsNothing);
    });

    testWidgets(
      'toggling an option on updates state and the Filters count badge, '
      'toggling it off restores the unfiltered toolbar',
      (tester) async {
        final states = <AgentListFilterState>[];
        final host = await pumpToolbar(tester, onState: states.add);
        final messages = capturedContext.messages;

        await openFilters(tester);
        await tester.tap(find.text('Active'));
        await tester.pump();

        expect(states.last.selectionsFor('status'), {'active'});
        expect(host.state.activeFilterCount, 1);

        // Close the popover: the Filters button now carries a '1' badge and
        // the count text switches to the filtered variant.
        await tester.tapAt(const Size(1200, 900).center(Offset.zero));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.text('1'), findsOneWidget);
        expect(
          find.text(messages.agentInstancesResultCountFiltered(5, 9)),
          findsOneWidget,
        );

        // Toggle the same option off again.
        await openFilters(tester);
        await tester.tap(find.text('Active'));
        await tester.pump();
        await tester.tapAt(const Size(1200, 900).center(Offset.zero));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(host.state.activeFilterCount, 0);
        expect(find.text('1'), findsNothing);
        expect(
          find.text(messages.agentInstancesResultCountAll(9)),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      "the section's Clear link wipes only that axis's selections",
      (tester) async {
        final host = await pumpToolbar(tester);

        await openFilters(tester);
        await tester.tap(find.text('Task agent'));
        await tester.pump();
        await tester.tap(find.text('Active'));
        await tester.pump();
        expect(host.state.activeFilterCount, 2);

        // Each section with selections shows its own Clear link.
        final messages = capturedContext.messages;
        final clearLinks = find.text(messages.agentInstancesFilterClearSection);
        expect(clearLinks, findsNWidgets(2));

        await tester.tap(clearLinks.first);
        await tester.pump();

        expect(host.state.selectionsFor('type'), isEmpty);
        expect(host.state.selectionsFor('status'), {'active'});
      },
    );

    testWidgets('group-by popover switches the group axis', (tester) async {
      final host = await pumpToolbar(tester);
      final messages = capturedContext.messages;

      await tester.tap(
        find.textContaining(messages.agentInstancesToolbarGroupBy),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Menu lists both axes; pick the non-current one.
      await tester.tap(find.text('Status').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(host.state.groupAxisId, 'status');
      expect(
        find.textContaining(messages.agentInstancesToolbarGroupBy),
        findsOneWidget,
      );
    });

    testWidgets('sort popover switches the sort axis and the button label', (
      tester,
    ) async {
      final host = await pumpToolbar(tester);

      await tester.tap(find.text('Recent'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.text('Name').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(host.state.sortAxisId, 'name');
      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Recent'), findsNothing);
    });

    testWidgets('typing into the search field updates state.search', (
      tester,
    ) async {
      final host = await pumpToolbar(tester);

      await tester.enterText(find.byType(TextField), 'laura');
      await tester.pump();

      expect(host.state.search, 'laura');
    });
  });
}
