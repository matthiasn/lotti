import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/ui/listing/agent_list_filter_state.dart';
import 'agent_list_filter_state_test_helpers.dart';

void main() {
  group('buildGroupedAgentList', () {
    test('search lowercases and matches the precomputed searchKey', () {
      final rows = [
        hRow(id: 'a', title: 'Alpha', sortAt: DateTime(2026)),
        hRow(id: 'b', title: 'Bravo', sortAt: DateTime(2026, 1, 2)),
      ];

      final result = buildGroupedAgentList(
        all: rows,
        state: const AgentListFilterState(
          groupAxisId: 'all',
          sortAxisId: 'recent',
          search: 'AL',
        ),
        filterAxes: const [],
        groupAxes: [hFlatAxis('all', 'All')],
        sortAxes: [hRecentAxis()],
        axisMatcher: (_, _, _) => true,
      );

      expect(result.totalBeforeFilter, 2);
      expect(result.totalAfterFilter, 1);
      expect(
        result.groups.expand((g) => g.items).map((r) => r.id).toList(),
        ['a'],
      );
    });

    test('multi-select axis filter ORs within axis (via matcher)', () {
      final rows = [
        hRow(id: 't', title: 'Task one', sortAt: DateTime(2026)),
        hRow(id: 'p', title: 'Project one', sortAt: DateTime(2026)),
        hRow(id: 'e', title: 'Evolution one', sortAt: DateTime(2026)),
      ];

      final hints = <String, String>{
        't': 'task',
        'p': 'project',
        'e': 'evolution',
      };

      final result = buildGroupedAgentList(
        all: rows,
        state: const AgentListFilterState(
          groupAxisId: 'all',
          sortAxisId: 'recent',
          selectionsByAxis: {
            'type': {'task', 'evolution'},
          },
        ),
        filterAxes: [
          hTypeAxis(counts: const {'task': 1, 'project': 1, 'evolution': 1}),
        ],
        groupAxes: [hFlatAxis('all', 'All')],
        sortAxes: [hRecentAxis()],
        axisMatcher: (axisId, selected, row) =>
            axisId != 'type' || selected.contains(hints[row.id]),
      );

      expect(
        result.groups.expand((g) => g.items).map((r) => r.id).toSet(),
        {'t', 'e'},
      );
    });

    test('sort=name uses lower-cased title then id tie-break', () {
      final rows = [
        hRow(id: 'b', title: 'beta', sortAt: DateTime(2026)),
        hRow(id: 'a2', title: 'Alpha', sortAt: DateTime(2026)),
        hRow(id: 'a1', title: 'Alpha', sortAt: DateTime(2026)),
      ];

      final result = buildGroupedAgentList(
        all: rows,
        state: const AgentListFilterState(
          groupAxisId: 'all',
          sortAxisId: 'name',
        ),
        filterAxes: const [],
        groupAxes: [hFlatAxis('all', 'All')],
        sortAxes: [hNameAxis()],
        axisMatcher: (_, _, _) => true,
      );

      expect(
        result.groups.expand((g) => g.items).map((r) => r.id).toList(),
        ['a1', 'a2', 'b'],
      );
    });

    test('selecting an unknown sort axis falls back to the first axis', () {
      final rows = [
        hRow(id: 'a', title: 'Alpha', sortAt: DateTime(2026, 1, 2)),
        hRow(id: 'b', title: 'Bravo', sortAt: DateTime(2026)),
      ];

      final result = buildGroupedAgentList(
        all: rows,
        state: const AgentListFilterState(
          groupAxisId: 'all',
          sortAxisId: 'unknown',
        ),
        filterAxes: const [],
        groupAxes: [hFlatAxis('all', 'All')],
        sortAxes: [hRecentAxis()],
        axisMatcher: (_, _, _) => true,
      );
      expect(
        result.groups.single.items.map((r) => r.id).toList(),
        ['a', 'b'],
      );
    });

    glados.Glados(
      glados.any.pipelineScenario,
      glados.ExploreConfig(numRuns: 180),
    ).test(
      'matches generated filter, sort, and group pipeline semantics',
      (
        scenario,
      ) {
        final rows = hGeneratedPipelineRows();
        final result = buildGroupedAgentList(
          all: rows,
          state: scenario.state,
          filterAxes: [
            hTypeAxis(counts: const {'task': 2, 'project': 2}),
            hTypeAxis(counts: const {'active': 2, 'dormant': 2}, id: 'status'),
          ],
          groupAxes: [
            hFlatAxis('all', 'All'),
            hTypeGroupAxis(hGeneratedTypesById),
          ],
          sortAxes: [hRecentAxis(), hNameAxis()],
          axisMatcher: (axisId, selected, row) {
            return switch (axisId) {
              'type' => selected.contains(hGeneratedTypesById[row.id]),
              'status' => selected.contains(hGeneratedStatusesById[row.id]),
              _ => true,
            };
          },
        );

        final actualIds = result.groups
            .expand((group) => group.items)
            .map((row) => row.id)
            .toList();

        expect(result.totalBeforeFilter, rows.length);
        expect(
          result.totalAfterFilter,
          hExpectedPipelineIds(scenario, rows).length,
        );
        expect(
          actualIds,
          hExpectedPipelineIds(scenario, rows),
          reason: '$scenario',
        );
      },
      tags: 'glados',
    );
  });

  group('AgentListFilterState', () {
    test('toggleOption flips an option in the right axis', () {
      const s = AgentListFilterState(groupAxisId: 'all', sortAxisId: 'recent');
      final s1 = s.toggleOption('type', 'task');
      expect(s1.selectionsFor('type'), {'task'});
      final s2 = s1.toggleOption('type', 'task');
      expect(s2.selectionsFor('type'), <String>{});
      final s3 = s1.toggleOption('status', 'active');
      expect(s3.selectionsFor('type'), {'task'});
      expect(s3.selectionsFor('status'), {'active'});
    });

    test('clearAxis empties one axis without touching the others', () {
      final s = const AgentListFilterState(
        groupAxisId: 'all',
        sortAxisId: 'recent',
      ).toggleOption('type', 'task').toggleOption('status', 'active');
      final cleared = s.clearAxis('type');
      expect(cleared.selectionsFor('type'), isEmpty);
      expect(cleared.selectionsFor('status'), {'active'});
    });

    test('clearAll wipes search + every axis', () {
      final s = const AgentListFilterState(
        groupAxisId: 'all',
        sortAxisId: 'recent',
        search: 'foo',
      ).toggleOption('type', 'task').toggleOption('status', 'active');
      final cleared = s.clearAll();
      expect(cleared.isAnyFilterActive, isFalse);
      expect(cleared.search, '');
    });

    test('activeFilterCount counts each selection plus search-when-set', () {
      const empty = AgentListFilterState(
        groupAxisId: 'all',
        sortAxisId: 'recent',
      );
      expect(empty.activeFilterCount, 0);
      final loaded = empty
          .toggleOption('type', 'task')
          .toggleOption('type', 'evolution')
          .toggleOption('status', 'active')
          .copyWith(search: 'q');
      expect(loaded.activeFilterCount, 4);
    });

    test('whitespace-only search is treated as empty', () {
      const s = AgentListFilterState(
        groupAxisId: 'all',
        sortAxisId: 'recent',
        search: '   ',
      );
      expect(s.hasSearch, isFalse);
      expect(s.isAnyFilterActive, isFalse);
      expect(s.activeFilterCount, 0);
    });

    glados.Glados(
      glados.any.filterScenario,
      glados.ExploreConfig(numRuns: 180),
    ).test('matches generated toggle, clear, and search semantics', (
      scenario,
    ) {
      var state = const AgentListFilterState(
        groupAxisId: 'all',
        sortAxisId: 'recent',
      );
      var expectedSelections = <String, Set<String>>{};
      var expectedSearch = '';

      for (final operation in scenario.operations) {
        switch (operation.kind) {
          case GeneratedFilterOperationKind.toggleOption:
            state = state.toggleOption(operation.axisId, operation.optionId);
            final selected = Set<String>.from(
              expectedSelections[operation.axisId] ?? const <String>{},
            );
            if (!selected.add(operation.optionId)) {
              selected.remove(operation.optionId);
            }
            expectedSelections[operation.axisId] = selected;

          case GeneratedFilterOperationKind.clearAxis:
            state = state.clearAxis(operation.axisId);
            expectedSelections[operation.axisId] = const <String>{};

          case GeneratedFilterOperationKind.setSearch:
            state = state.copyWith(search: operation.search);
            expectedSearch = operation.search;

          case GeneratedFilterOperationKind.clearAll:
            state = state.clearAll();
            expectedSelections = <String, Set<String>>{};
            expectedSearch = '';
        }
      }

      for (final axis in GeneratedFilterAxisSlot.values.map(
        hGeneratedAxisId,
      )) {
        expect(
          state.selectionsFor(axis),
          expectedSelections[axis] ?? const <String>{},
          reason: '$scenario',
        );
      }
      final expectedHasSearch = expectedSearch.trim().isNotEmpty;
      final expectedFilterCount =
          expectedSelections.values.fold<int>(
            0,
            (sum, set) => sum + set.length,
          ) +
          (expectedHasSearch ? 1 : 0);

      expect(state.search, expectedSearch);
      expect(state.hasSearch, expectedHasSearch);
      expect(state.activeFilterCount, expectedFilterCount);
      expect(state.isAnyFilterActive, expectedFilterCount > 0);
    }, tags: 'glados');
  });

  group('hueForSeed', () {
    test('returns a stable value in [0, 360) for the same seed', () {
      expect(hueForSeed('Laura'), hueForSeed('Laura'));
      expect(hueForSeed('Laura'), inInclusiveRange(0, 359));
    });

    test('returns 0 for an empty seed', () {
      expect(hueForSeed(''), 0);
    });
  });
}
