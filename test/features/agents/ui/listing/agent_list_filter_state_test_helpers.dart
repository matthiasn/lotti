import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/ui/listing/agent_list_data.dart';
import 'package:lotti/features/agents/ui/listing/agent_list_filter_state.dart';

enum GeneratedFilterOperationKind {
  toggleOption,
  clearAxis,
  setSearch,
  clearAll,
}

enum GeneratedFilterAxisSlot { type, status, lifecycle }

enum GeneratedFilterOptionSlot { first, second, third }

enum GeneratedFilterSearchSlot { empty, whitespace, alpha, task, unmatched }

enum GeneratedPipelineSelectionKind { none, first, second, firstAndSecond }

enum GeneratedPipelineSearchKind { none, uppercaseAlpha, task, unmatched }

enum GeneratedPipelineSortKind { recent, name, unknown }

enum GeneratedPipelineGroupKind { all, type, unknown }

String hGeneratedAxisId(GeneratedFilterAxisSlot slot) => slot.name;

String hGeneratedOptionId(GeneratedFilterOptionSlot slot) =>
    'option-${slot.name}';

String hGeneratedSearch(GeneratedFilterSearchSlot slot) {
  return switch (slot) {
    GeneratedFilterSearchSlot.empty => '',
    GeneratedFilterSearchSlot.whitespace => '   ',
    GeneratedFilterSearchSlot.alpha => 'Alpha',
    GeneratedFilterSearchSlot.task => 'task',
    GeneratedFilterSearchSlot.unmatched => 'missing-query',
  };
}

Set<String> hGeneratedSelectionSet(
  GeneratedPipelineSelectionKind kind,
  String first,
  String second,
) {
  return switch (kind) {
    GeneratedPipelineSelectionKind.none => const <String>{},
    GeneratedPipelineSelectionKind.first => {first},
    GeneratedPipelineSelectionKind.second => {second},
    GeneratedPipelineSelectionKind.firstAndSecond => {first, second},
  };
}

String hGeneratedPipelineSearch(GeneratedPipelineSearchKind kind) {
  return switch (kind) {
    GeneratedPipelineSearchKind.none => '',
    GeneratedPipelineSearchKind.uppercaseAlpha => 'ALPHA',
    GeneratedPipelineSearchKind.task => 'task',
    GeneratedPipelineSearchKind.unmatched => 'zzzz',
  };
}

String hGeneratedSortAxisId(GeneratedPipelineSortKind kind) {
  return switch (kind) {
    GeneratedPipelineSortKind.recent => 'recent',
    GeneratedPipelineSortKind.name => 'name',
    GeneratedPipelineSortKind.unknown => 'unknown',
  };
}

String hGeneratedGroupAxisId(GeneratedPipelineGroupKind kind) {
  return switch (kind) {
    GeneratedPipelineGroupKind.all => 'all',
    GeneratedPipelineGroupKind.type => 'type',
    GeneratedPipelineGroupKind.unknown => 'unknown',
  };
}

class GeneratedFilterOperation {
  const GeneratedFilterOperation({
    required this.kind,
    required this.axisSlot,
    required this.optionSlot,
    required this.searchSlot,
  });

  final GeneratedFilterOperationKind kind;
  final GeneratedFilterAxisSlot axisSlot;
  final GeneratedFilterOptionSlot optionSlot;
  final GeneratedFilterSearchSlot searchSlot;

  String get axisId => hGeneratedAxisId(axisSlot);

  String get optionId => hGeneratedOptionId(optionSlot);

  String get search => hGeneratedSearch(searchSlot);

  @override
  String toString() {
    return 'GeneratedFilterOperation('
        'kind: $kind, axisSlot: $axisSlot, optionSlot: $optionSlot, '
        'searchSlot: $searchSlot)';
  }
}

class GeneratedFilterScenario {
  const GeneratedFilterScenario({required this.operations});

  final List<GeneratedFilterOperation> operations;

  @override
  String toString() => 'GeneratedFilterScenario($operations)';
}

class GeneratedPipelineScenario {
  const GeneratedPipelineScenario({
    required this.typeSelection,
    required this.statusSelection,
    required this.search,
    required this.sort,
    required this.group,
  });

  final GeneratedPipelineSelectionKind typeSelection;
  final GeneratedPipelineSelectionKind statusSelection;
  final GeneratedPipelineSearchKind search;
  final GeneratedPipelineSortKind sort;
  final GeneratedPipelineGroupKind group;

  Set<String> get selectedTypes =>
      hGeneratedSelectionSet(typeSelection, 'task', 'project');

  Set<String> get selectedStatuses =>
      hGeneratedSelectionSet(statusSelection, 'active', 'dormant');

  AgentListFilterState get state {
    return AgentListFilterState(
      groupAxisId: hGeneratedGroupAxisId(group),
      sortAxisId: hGeneratedSortAxisId(sort),
      search: hGeneratedPipelineSearch(search),
      selectionsByAxis: {
        'type': selectedTypes,
        'status': selectedStatuses,
      },
    );
  }

  @override
  String toString() {
    return 'GeneratedPipelineScenario('
        'typeSelection: $typeSelection, statusSelection: $statusSelection, '
        'search: $search, sort: $sort, group: $group)';
  }
}

extension AnyGeneratedAgentListFilterState on glados.Any {
  glados.Generator<GeneratedFilterOperationKind> get filterOperationKind =>
      glados.AnyUtils(this).choose(GeneratedFilterOperationKind.values);

  glados.Generator<GeneratedFilterAxisSlot> get filterAxisSlot =>
      glados.AnyUtils(this).choose(GeneratedFilterAxisSlot.values);

  glados.Generator<GeneratedFilterOptionSlot> get filterOptionSlot =>
      glados.AnyUtils(this).choose(GeneratedFilterOptionSlot.values);

  glados.Generator<GeneratedFilterSearchSlot> get filterSearchSlot =>
      glados.AnyUtils(this).choose(GeneratedFilterSearchSlot.values);

  glados.Generator<GeneratedFilterOperation> get filterOperation =>
      glados.CombinableAny(this).combine4(
        filterOperationKind,
        filterAxisSlot,
        filterOptionSlot,
        filterSearchSlot,
        (
          GeneratedFilterOperationKind kind,
          GeneratedFilterAxisSlot axisSlot,
          GeneratedFilterOptionSlot optionSlot,
          GeneratedFilterSearchSlot searchSlot,
        ) => GeneratedFilterOperation(
          kind: kind,
          axisSlot: axisSlot,
          optionSlot: optionSlot,
          searchSlot: searchSlot,
        ),
      );

  glados.Generator<GeneratedFilterScenario> get filterScenario =>
      glados.ListAnys(this)
          .listWithLengthInRange(0, 45, filterOperation)
          .map(
            (operations) => GeneratedFilterScenario(
              operations: operations,
            ),
          );

  glados.Generator<GeneratedPipelineSelectionKind> get pipelineSelectionKind =>
      glados.AnyUtils(this).choose(GeneratedPipelineSelectionKind.values);

  glados.Generator<GeneratedPipelineSearchKind> get pipelineSearchKind =>
      glados.AnyUtils(this).choose(GeneratedPipelineSearchKind.values);

  glados.Generator<GeneratedPipelineSortKind> get pipelineSortKind =>
      glados.AnyUtils(this).choose(GeneratedPipelineSortKind.values);

  glados.Generator<GeneratedPipelineGroupKind> get pipelineGroupKind =>
      glados.AnyUtils(this).choose(GeneratedPipelineGroupKind.values);

  glados.Generator<GeneratedPipelineScenario> get pipelineScenario =>
      glados.CombinableAny(this).combine5(
        pipelineSelectionKind,
        pipelineSelectionKind,
        pipelineSearchKind,
        pipelineSortKind,
        pipelineGroupKind,
        (
          GeneratedPipelineSelectionKind typeSelection,
          GeneratedPipelineSelectionKind statusSelection,
          GeneratedPipelineSearchKind search,
          GeneratedPipelineSortKind sort,
          GeneratedPipelineGroupKind group,
        ) => GeneratedPipelineScenario(
          typeSelection: typeSelection,
          statusSelection: statusSelection,
          search: search,
          sort: sort,
          group: group,
        ),
      );
}

AgentListRowData hRow({
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

AgentListFilterAxis hTypeAxis({
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

AgentListGroupAxis hFlatAxis(String id, String label) {
  return AgentListGroupAxis(
    id: id,
    label: label,
    buildGroups: (rows) => [
      AgentListGroup(id: 'all', label: 'All', items: rows),
    ],
  );
}

AgentListSortAxis hRecentAxis() {
  return AgentListSortAxis(
    id: 'recent',
    label: 'Recent',
    compare: (a, b) => b.sortAt.compareTo(a.sortAt),
  );
}

AgentListSortAxis hNameAxis() {
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

AgentListGroupAxis hTypeGroupAxis(Map<String, String> typesById) {
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

List<AgentListRowData> hGeneratedPipelineRows() {
  return [
    hRow(
      id: 'task-alpha',
      title: 'Alpha Task',
      subtitle: 'active task',
      sortAt: DateTime(2026, 1, 4),
    ),
    hRow(
      id: 'project-beta',
      title: 'Beta Project',
      subtitle: 'active project',
      sortAt: DateTime(2026, 1, 3),
    ),
    hRow(
      id: 'task-gamma',
      title: 'Gamma Task',
      subtitle: 'dormant task',
      sortAt: DateTime(2026, 1, 2),
    ),
    hRow(
      id: 'project-delta',
      title: 'Delta Project',
      subtitle: 'dormant project',
      sortAt: DateTime(2026),
    ),
  ];
}

final hGeneratedTypesById = <String, String>{
  'task-alpha': 'task',
  'project-beta': 'project',
  'task-gamma': 'task',
  'project-delta': 'project',
};

final hGeneratedStatusesById = <String, String>{
  'task-alpha': 'active',
  'project-beta': 'active',
  'task-gamma': 'dormant',
  'project-delta': 'dormant',
};

List<String> hExpectedPipelineIds(
  GeneratedPipelineScenario scenario,
  List<AgentListRowData> rows,
) {
  final query = hGeneratedPipelineSearch(scenario.search).trim().toLowerCase();
  final filtered = rows.where((row) {
    if (scenario.selectedTypes.isNotEmpty &&
        !scenario.selectedTypes.contains(hGeneratedTypesById[row.id])) {
      return false;
    }
    if (scenario.selectedStatuses.isNotEmpty &&
        !scenario.selectedStatuses.contains(hGeneratedStatusesById[row.id])) {
      return false;
    }
    return query.isEmpty || row.searchKey.contains(query);
  }).toList();

  final sortKind = scenario.sort == GeneratedPipelineSortKind.unknown
      ? GeneratedPipelineSortKind.recent
      : scenario.sort;
  switch (sortKind) {
    case GeneratedPipelineSortKind.recent:
    case GeneratedPipelineSortKind.unknown:
      filtered.sort((a, b) => b.sortAt.compareTo(a.sortAt));
    case GeneratedPipelineSortKind.name:
      filtered.sort((a, b) {
        final by = a.title.toLowerCase().compareTo(b.title.toLowerCase());
        if (by != 0) return by;
        return a.id.compareTo(b.id);
      });
  }

  if (scenario.group == GeneratedPipelineGroupKind.type) {
    final grouped = <String, List<AgentListRowData>>{};
    for (final row in filtered) {
      (grouped[hGeneratedTypesById[row.id] ?? 'unknown'] ??= []).add(row);
    }
    return grouped.values.expand((rows) => rows).map((row) => row.id).toList();
  }

  return filtered.map((row) => row.id).toList();
}
