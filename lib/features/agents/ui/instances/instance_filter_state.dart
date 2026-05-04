import 'package:flutter/foundation.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/ui/instances/instance_view_model.dart';

/// Axis the page is grouping the rows by.
enum InstancesGroupKey { soul, type, status }

/// Comparator used to order rows before grouping.
enum InstancesSortKey { recent, oldest, name }

/// Local UI state for the instances page (filters + sort + group + search).
///
/// Held in `setState` rather than a provider — it's all per-page UI state
/// and the page is a single mount point.
@immutable
class InstancesFilterState {
  const InstancesFilterState({
    this.types = const <InstanceType>{},
    this.statuses = const <AgentLifecycle>{},
    this.soulIds = const <String>{},
    this.search = '',
    this.groupKey = InstancesGroupKey.soul,
    this.sortKey = InstancesSortKey.recent,
  });

  /// Empty set means "all" (no constraint), matching the design spec.
  final Set<InstanceType> types;
  final Set<AgentLifecycle> statuses;
  final Set<String> soulIds;
  final String search;
  final InstancesGroupKey groupKey;
  final InstancesSortKey sortKey;

  bool get isAnyFilterActive =>
      types.isNotEmpty ||
      statuses.isNotEmpty ||
      soulIds.isNotEmpty ||
      search.isNotEmpty;

  int get activeFilterCount =>
      types.length +
      statuses.length +
      soulIds.length +
      (search.isEmpty ? 0 : 1);

  InstancesFilterState copyWith({
    Set<InstanceType>? types,
    Set<AgentLifecycle>? statuses,
    Set<String>? soulIds,
    String? search,
    InstancesGroupKey? groupKey,
    InstancesSortKey? sortKey,
  }) {
    return InstancesFilterState(
      types: types ?? this.types,
      statuses: statuses ?? this.statuses,
      soulIds: soulIds ?? this.soulIds,
      search: search ?? this.search,
      groupKey: groupKey ?? this.groupKey,
      sortKey: sortKey ?? this.sortKey,
    );
  }

  InstancesFilterState toggleType(InstanceType v) =>
      copyWith(types: _toggle(types, v));
  InstancesFilterState toggleStatus(AgentLifecycle v) =>
      copyWith(statuses: _toggle(statuses, v));
  InstancesFilterState toggleSoul(String id) =>
      copyWith(soulIds: _toggle(soulIds, id));

  InstancesFilterState clearAll() => copyWith(
    types: const <InstanceType>{},
    statuses: const <AgentLifecycle>{},
    soulIds: const <String>{},
    search: '',
  );
}

Set<T> _toggle<T>(Set<T> source, T value) {
  final next = Set<T>.from(source);
  if (!next.add(value)) next.remove(value);
  return next;
}

/// Pipeline result: rows after filter+sort, then grouped by [InstancesGroupKey].
class InstancesGroupedResult {
  const InstancesGroupedResult({
    required this.totalBeforeFilter,
    required this.totalAfterFilter,
    required this.groups,
  });

  final int totalBeforeFilter;
  final int totalAfterFilter;
  final List<InstancesGroup> groups;
}

class InstancesGroup {
  const InstancesGroup({
    required this.id,
    required this.label,
    required this.items,
    this.soulId,
    this.type,
    this.status,
  });

  /// Stable id used for collapse-state tracking.
  final String id;
  final String label;
  final List<InstanceVm> items;
  final String? soulId;
  final InstanceType? type;
  final AgentLifecycle? status;

  int get activeCount =>
      items.where((i) => i.status == AgentLifecycle.active).length;
}

/// Pure transform: filter → sort → group. Kept side-effect-free so it can
/// be tested directly and so the widget can call it inside `build`.
InstancesGroupedResult buildGroupedInstances({
  required List<InstanceVm> all,
  required InstancesFilterState state,
  required String unassignedSoulLabel,
}) {
  final query = state.search.trim().toLowerCase();
  final filtered =
      all.where((vm) {
        if (state.types.isNotEmpty && !state.types.contains(vm.type)) {
          return false;
        }
        if (state.statuses.isNotEmpty && !state.statuses.contains(vm.status)) {
          return false;
        }
        if (state.soulIds.isNotEmpty &&
            !state.soulIds.contains(vm.soulGroupId())) {
          return false;
        }
        if (query.isNotEmpty && !vm.searchKey.contains(query)) return false;
        return true;
      }).toList()..sort(switch (state.sortKey) {
        InstancesSortKey.recent => (a, b) => b.updatedAt.compareTo(a.updatedAt),
        InstancesSortKey.oldest => (a, b) => a.updatedAt.compareTo(b.updatedAt),
        InstancesSortKey.name => (a, b) {
          final byName = a.displayName.toLowerCase().compareTo(
            b.displayName.toLowerCase(),
          );
          if (byName != 0) return byName;
          return a.id.compareTo(b.id);
        },
      });

  final buckets = <String, List<InstanceVm>>{};
  final order = <String>[];
  for (final vm in filtered) {
    final key = switch (state.groupKey) {
      InstancesGroupKey.soul => vm.soulGroupId(),
      InstancesGroupKey.type => vm.type.name,
      InstancesGroupKey.status => vm.status.name,
    };
    if (!buckets.containsKey(key)) {
      buckets[key] = [];
      order.add(key);
    }
    buckets[key]!.add(vm);
  }

  final groups = order.map((key) {
    final items = buckets[key]!;
    return switch (state.groupKey) {
      InstancesGroupKey.soul => InstancesGroup(
        id: 'soul:$key',
        label: items.first.soulGroupLabel(unassignedSoulLabel),
        items: items,
        soulId: items.first.soulId,
      ),
      InstancesGroupKey.type => InstancesGroup(
        id: 'type:$key',
        label: items.first.type.name,
        items: items,
        type: items.first.type,
      ),
      InstancesGroupKey.status => InstancesGroup(
        id: 'status:$key',
        label: items.first.status.name,
        items: items,
        status: items.first.status,
      ),
    };
  }).toList();

  // Soul groups: descending by member count (matches the design's
  // "largest persona first" priority). Other axes: alpha by label.
  if (state.groupKey == InstancesGroupKey.soul) {
    groups.sort((a, b) => b.items.length.compareTo(a.items.length));
  } else {
    groups.sort((a, b) => a.label.compareTo(b.label));
  }

  return InstancesGroupedResult(
    totalBeforeFilter: all.length,
    totalAfterFilter: filtered.length,
    groups: groups,
  );
}
