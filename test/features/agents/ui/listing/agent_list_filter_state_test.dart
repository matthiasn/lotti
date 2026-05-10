import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/ui/listing/agent_list_data.dart';
import 'package:lotti/features/agents/ui/listing/agent_list_filter_state.dart';
import 'package:lotti/features/agents/ui/listing/widgets/soul_avatar.dart';

enum _GeneratedFilterOperationKind {
  toggleOption,
  clearAxis,
  setSearch,
  clearAll,
}

enum _GeneratedFilterAxisSlot { type, status, lifecycle }

enum _GeneratedFilterOptionSlot { first, second, third }

enum _GeneratedFilterSearchSlot { empty, whitespace, alpha, task, unmatched }

enum _GeneratedPipelineSelectionKind { none, first, second, firstAndSecond }

enum _GeneratedPipelineSearchKind { none, uppercaseAlpha, task, unmatched }

enum _GeneratedPipelineSortKind { recent, name, unknown }

enum _GeneratedPipelineGroupKind { all, type, unknown }

String _generatedAxisId(_GeneratedFilterAxisSlot slot) => slot.name;

String _generatedOptionId(_GeneratedFilterOptionSlot slot) =>
    'option-${slot.name}';

String _generatedSearch(_GeneratedFilterSearchSlot slot) {
  return switch (slot) {
    _GeneratedFilterSearchSlot.empty => '',
    _GeneratedFilterSearchSlot.whitespace => '   ',
    _GeneratedFilterSearchSlot.alpha => 'Alpha',
    _GeneratedFilterSearchSlot.task => 'task',
    _GeneratedFilterSearchSlot.unmatched => 'missing-query',
  };
}

Set<String> _generatedSelectionSet(
  _GeneratedPipelineSelectionKind kind,
  String first,
  String second,
) {
  return switch (kind) {
    _GeneratedPipelineSelectionKind.none => const <String>{},
    _GeneratedPipelineSelectionKind.first => {first},
    _GeneratedPipelineSelectionKind.second => {second},
    _GeneratedPipelineSelectionKind.firstAndSecond => {first, second},
  };
}

String _generatedPipelineSearch(_GeneratedPipelineSearchKind kind) {
  return switch (kind) {
    _GeneratedPipelineSearchKind.none => '',
    _GeneratedPipelineSearchKind.uppercaseAlpha => 'ALPHA',
    _GeneratedPipelineSearchKind.task => 'task',
    _GeneratedPipelineSearchKind.unmatched => 'zzzz',
  };
}

String _generatedSortAxisId(_GeneratedPipelineSortKind kind) {
  return switch (kind) {
    _GeneratedPipelineSortKind.recent => 'recent',
    _GeneratedPipelineSortKind.name => 'name',
    _GeneratedPipelineSortKind.unknown => 'unknown',
  };
}

String _generatedGroupAxisId(_GeneratedPipelineGroupKind kind) {
  return switch (kind) {
    _GeneratedPipelineGroupKind.all => 'all',
    _GeneratedPipelineGroupKind.type => 'type',
    _GeneratedPipelineGroupKind.unknown => 'unknown',
  };
}

class _GeneratedFilterOperation {
  const _GeneratedFilterOperation({
    required this.kind,
    required this.axisSlot,
    required this.optionSlot,
    required this.searchSlot,
  });

  final _GeneratedFilterOperationKind kind;
  final _GeneratedFilterAxisSlot axisSlot;
  final _GeneratedFilterOptionSlot optionSlot;
  final _GeneratedFilterSearchSlot searchSlot;

  String get axisId => _generatedAxisId(axisSlot);

  String get optionId => _generatedOptionId(optionSlot);

  String get search => _generatedSearch(searchSlot);

  @override
  String toString() {
    return '_GeneratedFilterOperation('
        'kind: $kind, axisSlot: $axisSlot, optionSlot: $optionSlot, '
        'searchSlot: $searchSlot)';
  }
}

class _GeneratedFilterScenario {
  const _GeneratedFilterScenario({required this.operations});

  final List<_GeneratedFilterOperation> operations;

  @override
  String toString() => '_GeneratedFilterScenario($operations)';
}

class _GeneratedPipelineScenario {
  const _GeneratedPipelineScenario({
    required this.typeSelection,
    required this.statusSelection,
    required this.search,
    required this.sort,
    required this.group,
  });

  final _GeneratedPipelineSelectionKind typeSelection;
  final _GeneratedPipelineSelectionKind statusSelection;
  final _GeneratedPipelineSearchKind search;
  final _GeneratedPipelineSortKind sort;
  final _GeneratedPipelineGroupKind group;

  Set<String> get selectedTypes =>
      _generatedSelectionSet(typeSelection, 'task', 'project');

  Set<String> get selectedStatuses =>
      _generatedSelectionSet(statusSelection, 'active', 'dormant');

  AgentListFilterState get state {
    return AgentListFilterState(
      groupAxisId: _generatedGroupAxisId(group),
      sortAxisId: _generatedSortAxisId(sort),
      search: _generatedPipelineSearch(search),
      selectionsByAxis: {
        'type': selectedTypes,
        'status': selectedStatuses,
      },
    );
  }

  @override
  String toString() {
    return '_GeneratedPipelineScenario('
        'typeSelection: $typeSelection, statusSelection: $statusSelection, '
        'search: $search, sort: $sort, group: $group)';
  }
}

extension _AnyGeneratedAgentListFilterState on glados.Any {
  glados.Generator<_GeneratedFilterOperationKind> get filterOperationKind =>
      glados.AnyUtils(this).choose(_GeneratedFilterOperationKind.values);

  glados.Generator<_GeneratedFilterAxisSlot> get filterAxisSlot =>
      glados.AnyUtils(this).choose(_GeneratedFilterAxisSlot.values);

  glados.Generator<_GeneratedFilterOptionSlot> get filterOptionSlot =>
      glados.AnyUtils(this).choose(_GeneratedFilterOptionSlot.values);

  glados.Generator<_GeneratedFilterSearchSlot> get filterSearchSlot =>
      glados.AnyUtils(this).choose(_GeneratedFilterSearchSlot.values);

  glados.Generator<_GeneratedFilterOperation> get filterOperation =>
      glados.CombinableAny(this).combine4(
        filterOperationKind,
        filterAxisSlot,
        filterOptionSlot,
        filterSearchSlot,
        (
          _GeneratedFilterOperationKind kind,
          _GeneratedFilterAxisSlot axisSlot,
          _GeneratedFilterOptionSlot optionSlot,
          _GeneratedFilterSearchSlot searchSlot,
        ) => _GeneratedFilterOperation(
          kind: kind,
          axisSlot: axisSlot,
          optionSlot: optionSlot,
          searchSlot: searchSlot,
        ),
      );

  glados.Generator<_GeneratedFilterScenario> get filterScenario =>
      glados.ListAnys(this)
          .listWithLengthInRange(0, 45, filterOperation)
          .map(
            (operations) => _GeneratedFilterScenario(
              operations: operations,
            ),
          );

  glados.Generator<_GeneratedPipelineSelectionKind> get pipelineSelectionKind =>
      glados.AnyUtils(this).choose(_GeneratedPipelineSelectionKind.values);

  glados.Generator<_GeneratedPipelineSearchKind> get pipelineSearchKind =>
      glados.AnyUtils(this).choose(_GeneratedPipelineSearchKind.values);

  glados.Generator<_GeneratedPipelineSortKind> get pipelineSortKind =>
      glados.AnyUtils(this).choose(_GeneratedPipelineSortKind.values);

  glados.Generator<_GeneratedPipelineGroupKind> get pipelineGroupKind =>
      glados.AnyUtils(this).choose(_GeneratedPipelineGroupKind.values);

  glados.Generator<_GeneratedPipelineScenario> get pipelineScenario =>
      glados.CombinableAny(this).combine5(
        pipelineSelectionKind,
        pipelineSelectionKind,
        pipelineSearchKind,
        pipelineSortKind,
        pipelineGroupKind,
        (
          _GeneratedPipelineSelectionKind typeSelection,
          _GeneratedPipelineSelectionKind statusSelection,
          _GeneratedPipelineSearchKind search,
          _GeneratedPipelineSortKind sort,
          _GeneratedPipelineGroupKind group,
        ) => _GeneratedPipelineScenario(
          typeSelection: typeSelection,
          statusSelection: statusSelection,
          search: search,
          sort: sort,
          group: group,
        ),
      );
}

AgentListRowData _row({
  required String id,
  required String title,
  required DateTime sortAt,
  String? subtitle,
  AgentListLeading? leading,
  List<AgentListPill> pills = const [],
}) {
  return AgentListRowData(
    id: id,
    title: title,
    subtitle: subtitle,
    leading: leading,
    pills: pills,
    sortAt: sortAt,
    searchKey: '$title $id ${subtitle ?? ''}'.toLowerCase(),
  );
}

AgentListFilterAxis _typeAxis({
  required Map<String, int> counts,
  String id = 'type',
}) {
  return AgentListFilterAxis(
    id: id,
    sectionLabel: id,
    options: counts.entries
        .map(
          (e) => AgentListFilterOption(id: e.key, label: e.key, count: e.value),
        )
        .toList(),
  );
}

AgentListGroupAxis _flatAxis(String id, String label) {
  return AgentListGroupAxis(
    id: id,
    label: label,
    buildGroups: (rows) => [
      AgentListGroup(id: 'all', label: 'All', items: rows),
    ],
  );
}

AgentListSortAxis _recentAxis() {
  return AgentListSortAxis(
    id: 'recent',
    label: 'Recent',
    compare: (a, b) => b.sortAt.compareTo(a.sortAt),
  );
}

AgentListSortAxis _nameAxis() {
  return AgentListSortAxis(
    id: 'name',
    label: 'Name',
    compare: (a, b) {
      final by = a.title.toLowerCase().compareTo(b.title.toLowerCase());
      if (by != 0) return by;
      return a.id.compareTo(b.id);
    },
  );
}

AgentListGroupAxis _typeGroupAxis(Map<String, String> typesById) {
  return AgentListGroupAxis(
    id: 'type',
    label: 'Type',
    buildGroups: (rows) {
      final grouped = <String, List<AgentListRowData>>{};
      for (final row in rows) {
        (grouped[typesById[row.id] ?? 'unknown'] ??= []).add(row);
      }
      return grouped.entries
          .map(
            (entry) => AgentListGroup(
              id: entry.key,
              label: entry.key,
              items: entry.value,
            ),
          )
          .toList();
    },
  );
}

List<AgentListRowData> _generatedPipelineRows() {
  return [
    _row(
      id: 'task-alpha',
      title: 'Alpha Task',
      subtitle: 'active task',
      sortAt: DateTime(2026, 1, 4),
    ),
    _row(
      id: 'project-beta',
      title: 'Beta Project',
      subtitle: 'active project',
      sortAt: DateTime(2026, 1, 3),
    ),
    _row(
      id: 'task-gamma',
      title: 'Gamma Task',
      subtitle: 'dormant task',
      sortAt: DateTime(2026, 1, 2),
    ),
    _row(
      id: 'project-delta',
      title: 'Delta Project',
      subtitle: 'dormant project',
      sortAt: DateTime(2026),
    ),
  ];
}

final _generatedTypesById = <String, String>{
  'task-alpha': 'task',
  'project-beta': 'project',
  'task-gamma': 'task',
  'project-delta': 'project',
};

final _generatedStatusesById = <String, String>{
  'task-alpha': 'active',
  'project-beta': 'active',
  'task-gamma': 'dormant',
  'project-delta': 'dormant',
};

List<String> _expectedPipelineIds(
  _GeneratedPipelineScenario scenario,
  List<AgentListRowData> rows,
) {
  final query = _generatedPipelineSearch(scenario.search).trim().toLowerCase();
  final filtered = rows.where((row) {
    if (scenario.selectedTypes.isNotEmpty &&
        !scenario.selectedTypes.contains(_generatedTypesById[row.id])) {
      return false;
    }
    if (scenario.selectedStatuses.isNotEmpty &&
        !scenario.selectedStatuses.contains(_generatedStatusesById[row.id])) {
      return false;
    }
    return query.isEmpty || row.searchKey.contains(query);
  }).toList();

  final sortKind = scenario.sort == _GeneratedPipelineSortKind.unknown
      ? _GeneratedPipelineSortKind.recent
      : scenario.sort;
  switch (sortKind) {
    case _GeneratedPipelineSortKind.recent:
    case _GeneratedPipelineSortKind.unknown:
      filtered.sort((a, b) => b.sortAt.compareTo(a.sortAt));
    case _GeneratedPipelineSortKind.name:
      filtered.sort((a, b) {
        final by = a.title.toLowerCase().compareTo(b.title.toLowerCase());
        if (by != 0) return by;
        return a.id.compareTo(b.id);
      });
  }

  if (scenario.group == _GeneratedPipelineGroupKind.type) {
    final grouped = <String, List<AgentListRowData>>{};
    for (final row in filtered) {
      (grouped[_generatedTypesById[row.id] ?? 'unknown'] ??= []).add(row);
    }
    return grouped.values.expand((rows) => rows).map((row) => row.id).toList();
  }

  return filtered.map((row) => row.id).toList();
}

void main() {
  group('buildGroupedAgentList', () {
    test('search lowercases and matches the precomputed searchKey', () {
      final rows = [
        _row(id: 'a', title: 'Alpha', sortAt: DateTime(2026)),
        _row(id: 'b', title: 'Bravo', sortAt: DateTime(2026, 1, 2)),
      ];

      final result = buildGroupedAgentList(
        all: rows,
        state: const AgentListFilterState(
          groupAxisId: 'all',
          sortAxisId: 'recent',
          search: 'AL',
        ),
        filterAxes: const [],
        groupAxes: [_flatAxis('all', 'All')],
        sortAxes: [_recentAxis()],
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
        _row(id: 't', title: 'Task one', sortAt: DateTime(2026)),
        _row(id: 'p', title: 'Project one', sortAt: DateTime(2026)),
        _row(id: 'e', title: 'Evolution one', sortAt: DateTime(2026)),
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
          _typeAxis(counts: const {'task': 1, 'project': 1, 'evolution': 1}),
        ],
        groupAxes: [_flatAxis('all', 'All')],
        sortAxes: [_recentAxis()],
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
        _row(id: 'b', title: 'beta', sortAt: DateTime(2026)),
        _row(id: 'a2', title: 'Alpha', sortAt: DateTime(2026)),
        _row(id: 'a1', title: 'Alpha', sortAt: DateTime(2026)),
      ];

      final result = buildGroupedAgentList(
        all: rows,
        state: const AgentListFilterState(
          groupAxisId: 'all',
          sortAxisId: 'name',
        ),
        filterAxes: const [],
        groupAxes: [_flatAxis('all', 'All')],
        sortAxes: [_nameAxis()],
        axisMatcher: (_, _, _) => true,
      );

      expect(
        result.groups.expand((g) => g.items).map((r) => r.id).toList(),
        ['a1', 'a2', 'b'],
      );
    });

    test('selecting an unknown sort axis falls back to the first axis', () {
      final rows = [
        _row(id: 'a', title: 'Alpha', sortAt: DateTime(2026, 1, 2)),
        _row(id: 'b', title: 'Bravo', sortAt: DateTime(2026)),
      ];

      final result = buildGroupedAgentList(
        all: rows,
        state: const AgentListFilterState(
          groupAxisId: 'all',
          sortAxisId: 'unknown',
        ),
        filterAxes: const [],
        groupAxes: [_flatAxis('all', 'All')],
        sortAxes: [_recentAxis()],
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
        final rows = _generatedPipelineRows();
        final result = buildGroupedAgentList(
          all: rows,
          state: scenario.state,
          filterAxes: [
            _typeAxis(counts: const {'task': 2, 'project': 2}),
            _typeAxis(counts: const {'active': 2, 'dormant': 2}, id: 'status'),
          ],
          groupAxes: [
            _flatAxis('all', 'All'),
            _typeGroupAxis(_generatedTypesById),
          ],
          sortAxes: [_recentAxis(), _nameAxis()],
          axisMatcher: (axisId, selected, row) {
            return switch (axisId) {
              'type' => selected.contains(_generatedTypesById[row.id]),
              'status' => selected.contains(_generatedStatusesById[row.id]),
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
          _expectedPipelineIds(scenario, rows).length,
        );
        expect(
          actualIds,
          _expectedPipelineIds(scenario, rows),
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
          case _GeneratedFilterOperationKind.toggleOption:
            state = state.toggleOption(operation.axisId, operation.optionId);
            final selected = Set<String>.from(
              expectedSelections[operation.axisId] ?? const <String>{},
            );
            if (!selected.add(operation.optionId)) {
              selected.remove(operation.optionId);
            }
            expectedSelections[operation.axisId] = selected;

          case _GeneratedFilterOperationKind.clearAxis:
            state = state.clearAxis(operation.axisId);
            expectedSelections[operation.axisId] = const <String>{};

          case _GeneratedFilterOperationKind.setSearch:
            state = state.copyWith(search: operation.search);
            expectedSearch = operation.search;

          case _GeneratedFilterOperationKind.clearAll:
            state = state.clearAll();
            expectedSelections = <String, Set<String>>{};
            expectedSearch = '';
        }
      }

      for (final axis in _GeneratedFilterAxisSlot.values.map(
        _generatedAxisId,
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

  group('SoulAvatar', () {
    testWidgets(
      'whitespace-only label falls back to "?" rather than a blank glyph',
      (tester) async {
        await tester.pumpWidget(
          const Directionality(
            textDirection: TextDirection.ltr,
            child: Center(child: SoulAvatar(label: '   ', hue: 200)),
          ),
        );
        expect(find.text('?'), findsOneWidget);
      },
    );

    testWidgets('non-empty label uses its first character (uppercased)', (
      tester,
    ) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(child: SoulAvatar(label: 'laura', hue: 142)),
        ),
      );
      expect(find.text('L'), findsOneWidget);
    });
  });
}
