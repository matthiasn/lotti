import 'package:flutter/foundation.dart';
import 'package:lotti/features/agents/ui/listing/agent_list_data.dart';

/// Local UI state owned by `AgentListingShell`: which option ids are
/// selected per axis, the search string, and the current group + sort
/// axis. Identifies axes/options by string id so the state class itself
/// stays free of typed enums (each tab has its own enums).
@immutable
class AgentListFilterState {
  const AgentListFilterState({
    required this.groupAxisId,
    required this.sortAxisId,
    this.selectionsByAxis = const {},
    this.search = '',
  });

  /// `axis.id → set of selected option.id`. Empty set / missing key means
  /// "all" (no constraint), matching the design.
  final Map<String, Set<String>> selectionsByAxis;
  final String search;
  final String groupAxisId;
  final String sortAxisId;

  bool get hasSearch => search.trim().isNotEmpty;

  bool get isAnyFilterActive =>
      hasSearch || selectionsByAxis.values.any((s) => s.isNotEmpty);

  int get activeFilterCount =>
      selectionsByAxis.values.fold<int>(0, (n, s) => n + s.length) +
      (hasSearch ? 1 : 0);

  Set<String> selectionsFor(String axisId) =>
      selectionsByAxis[axisId] ?? const <String>{};

  AgentListFilterState copyWith({
    Map<String, Set<String>>? selectionsByAxis,
    String? search,
    String? groupAxisId,
    String? sortAxisId,
  }) {
    return AgentListFilterState(
      selectionsByAxis: selectionsByAxis ?? this.selectionsByAxis,
      search: search ?? this.search,
      groupAxisId: groupAxisId ?? this.groupAxisId,
      sortAxisId: sortAxisId ?? this.sortAxisId,
    );
  }

  AgentListFilterState toggleOption(String axisId, String optionId) {
    final current = selectionsFor(axisId);
    final next = Set<String>.from(current);
    if (!next.add(optionId)) next.remove(optionId);
    final nextByAxis = Map<String, Set<String>>.from(selectionsByAxis)
      ..[axisId] = next;
    return copyWith(selectionsByAxis: nextByAxis);
  }

  AgentListFilterState clearAxis(String axisId) {
    final nextByAxis = Map<String, Set<String>>.from(selectionsByAxis)
      ..[axisId] = const <String>{};
    return copyWith(selectionsByAxis: nextByAxis);
  }

  AgentListFilterState clearAll() {
    return copyWith(
      selectionsByAxis: const <String, Set<String>>{},
      search: '',
    );
  }
}

/// Output of the filter → sort → group pipeline.
@immutable
class AgentListPipelineResult {
  const AgentListPipelineResult({
    required this.totalBeforeFilter,
    required this.totalAfterFilter,
    required this.groups,
  });

  final int totalBeforeFilter;
  final int totalAfterFilter;
  final List<AgentListGroup> groups;
}

/// Page-supplied predicate. Returns true if [row] passes [axisId]'s
/// selection set [selectedOptionIds] (the page knows how to map an
/// option id back to its enum).
typedef AgentListAxisMatcher =
    bool Function(
      String axisId,
      Set<String> selectedOptionIds,
      AgentListRowData row,
    );

/// Pure transform: filter → sort → group. Side-effect-free so the page
/// can call it directly from `build` and tests can drive it without
/// pumping a widget.
AgentListPipelineResult buildGroupedAgentList({
  required List<AgentListRowData> all,
  required AgentListFilterState state,
  required List<AgentListFilterAxis> filterAxes,
  required List<AgentListGroupAxis> groupAxes,
  required List<AgentListSortAxis> sortAxes,
  required AgentListAxisMatcher axisMatcher,
}) {
  final query = state.search.trim().toLowerCase();
  final filtered = all.where((row) {
    for (final axis in filterAxes) {
      final selected = state.selectionsFor(axis.id);
      if (selected.isEmpty) continue;
      if (!axisMatcher(axis.id, selected, row)) return false;
    }
    if (query.isNotEmpty && !row.searchKey.contains(query)) return false;
    return true;
  }).toList();

  final sortAxis = sortAxes.firstWhere(
    (a) => a.id == state.sortAxisId,
    orElse: () => sortAxes.first,
  );
  filtered.sort(sortAxis.compare);

  final groupAxis = groupAxes.firstWhere(
    (a) => a.id == state.groupAxisId,
    orElse: () => groupAxes.first,
  );
  final groups = groupAxis.buildGroups(filtered);

  return AgentListPipelineResult(
    totalBeforeFilter: all.length,
    totalAfterFilter: filtered.length,
    groups: groups,
  );
}

/// Stable hue (0..359) derived from [seed]. Same string in → same hue
/// out, so a soul / template gets a consistent avatar tint without
/// storing a colour on the entity. FNV-1a hash, plenty for this use.
///
/// Lives here (not on `SoulAvatar`) so adapters can compute a hue once
/// and bake it into [AgentListAvatarLeading].
int hueForSeed(String seed) {
  if (seed.isEmpty) return 0;
  var h = 2166136261;
  for (final code in seed.codeUnits) {
    h = (h ^ code) & 0xFFFFFFFF;
    h = (h * 16777619) & 0xFFFFFFFF;
  }
  return h % 360;
}
