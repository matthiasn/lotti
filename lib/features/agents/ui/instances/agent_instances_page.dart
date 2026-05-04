import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/ui/instances/instance_view_model.dart';
import 'package:lotti/features/agents/ui/listing/agent_list_data.dart';
import 'package:lotti/features/agents/ui/listing/agent_list_filter_state.dart';
import 'package:lotti/features/agents/ui/listing/agent_listing_shell.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';

const String _typeAxisId = 'type';
const String _statusAxisId = 'status';
const String _soulAxisId = 'soul';

const String _groupBySoul = 'soul';
const String _groupByType = 'type';
const String _groupByStatus = 'status';

const String _sortRecent = 'recent';
const String _sortOldest = 'oldest';
const String _sortName = 'name';

/// Settings → Agents → Instances page. Adapts the domain VMs into the
/// shared [AgentListingShell].
class AgentInstancesPage extends ConsumerWidget {
  const AgentInstancesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = context.messages;
    final asyncVms = ref.watch(agentInstanceVmsProvider);

    final adapted = asyncVms.whenData(
      (vms) => _AdaptedRows.from(vms, messages),
    );

    final filterAxes = adapted.maybeWhen(
      data: (a) => _buildFilterAxes(a, messages),
      orElse: () => const <AgentListFilterAxis>[],
    );

    return AgentListingShell(
      rowsAsync: adapted.whenData((a) => a.rows),
      filterAxes: filterAxes,
      groupAxes: _buildGroupAxes(messages, adapted),
      sortAxes: _buildSortAxes(messages),
      searchPlaceholder: messages.agentInstancesSearchPlaceholder,
      emptyMessage: messages.agentInstancesEmptyFiltered,
      axisMatcher: (axisId, selected, row) =>
          _matchRow(adapted, row, axisId, selected),
    );
  }
}

/// Adapter output: the row list + side-channel hints keyed by row id so
/// the axis matcher / group functions can recover the typed enums
/// without decoding localized pill labels.
class _AdaptedRows {
  const _AdaptedRows({required this.rows, required this.hints});

  factory _AdaptedRows.from(List<InstanceVm> vms, AppLocalizations messages) {
    final rows = <AgentListRowData>[];
    final hints = <String, _RowHint>{};
    for (final vm in vms) {
      rows.add(_vmToRow(vm, messages));
      hints[vm.id] = _RowHint(
        type: vm.type,
        status: vm.status,
        soulId: vm.soulGroupId(),
      );
    }
    return _AdaptedRows(rows: rows, hints: hints);
  }

  final List<AgentListRowData> rows;
  final Map<String, _RowHint> hints;
}

class _RowHint {
  const _RowHint({
    required this.type,
    required this.status,
    required this.soulId,
  });
  final InstanceType type;
  final AgentLifecycle status;
  final String soulId;
}

AgentListRowData _vmToRow(InstanceVm vm, AppLocalizations messages) {
  final title = vm.type == InstanceType.evolution && vm.sessionNumber != null
      ? messages.agentEvolutionSessionTitle(vm.sessionNumber!)
      : vm.displayName;
  final subtitle = vm.type == InstanceType.evolution
      ? null
      : (vm.templateName != null && vm.templateName != vm.displayName
            ? vm.templateName
            : null);
  final soulSeed = vm.soulId ?? vm.templateId ?? vm.id;
  final leading = AgentListAvatarLeading(
    label: vm.soulName ?? '?',
    hue: hueForSeed(soulSeed),
  );
  return AgentListRowData(
    id: vm.id,
    title: title,
    subtitle: subtitle,
    leading: leading,
    pills: [
      AgentListPill(label: instanceTypeLabel(messages, vm.type)),
      AgentListPill(
        label: agentLifecycleLabel(messages, vm.status),
        tone: _statusTone(vm.status),
      ),
    ],
    metaRight: _formatTime(vm.updatedAt),
    onTap: () => beamToNamed('/settings/agents/instances/${vm.id}'),
    sortAt: vm.updatedAt,
    searchKey: vm.searchKey,
  );
}

AgentListPillTone _statusTone(AgentLifecycle status) {
  return switch (status) {
    AgentLifecycle.active => AgentListPillTone.interactive,
    AgentLifecycle.dormant => AgentListPillTone.muted,
    AgentLifecycle.destroyed => AgentListPillTone.error,
    AgentLifecycle.created => AgentListPillTone.info,
  };
}

String _formatTime(DateTime dt) {
  final hour = dt.hour.toString().padLeft(2, '0');
  final minute = dt.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

// ── Axes ────────────────────────────────────────────────────────────────────

List<AgentListFilterAxis> _buildFilterAxes(
  _AdaptedRows adapted,
  AppLocalizations messages,
) {
  final typeCounts = <InstanceType, int>{
    for (final t in InstanceType.values) t: 0,
  };
  final statusCounts = <AgentLifecycle, int>{
    for (final s in AgentLifecycle.values) s: 0,
  };
  final soulCounts = <String, int>{};
  final soulLabel = <String, String>{};
  final soulHue = <String, int>{};
  for (final row in adapted.rows) {
    final hint = adapted.hints[row.id]!;
    typeCounts[hint.type] = (typeCounts[hint.type] ?? 0) + 1;
    statusCounts[hint.status] = (statusCounts[hint.status] ?? 0) + 1;
    soulCounts[hint.soulId] = (soulCounts[hint.soulId] ?? 0) + 1;
    if (!soulLabel.containsKey(hint.soulId)) {
      final leading = row.leading;
      soulLabel[hint.soulId] = leading is AgentListAvatarLeading
          ? leading.label
          : messages.agentInstancesUnassignedSoul;
      soulHue[hint.soulId] = leading is AgentListAvatarLeading
          ? leading.hue
          : 0;
    }
  }

  final soulOptions =
      soulLabel.entries
          .map(
            (e) => AgentListFilterOption(
              id: e.key,
              label: e.value,
              count: soulCounts[e.key] ?? 0,
              swatchHue: soulHue[e.key],
            ),
          )
          .toList()
        ..sort(
          (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
        );

  return [
    AgentListFilterAxis(
      id: _typeAxisId,
      sectionLabel: messages.agentInstancesFilterSectionType,
      chipTone: AgentListPillTone.warning,
      options: [
        for (final t in InstanceType.values)
          AgentListFilterOption(
            id: t.name,
            label: instanceTypeLabel(messages, t),
            count: typeCounts[t] ?? 0,
          ),
      ],
    ),
    AgentListFilterAxis(
      id: _statusAxisId,
      sectionLabel: messages.agentInstancesFilterSectionStatus,
      chipTone: AgentListPillTone.interactive,
      options: [
        for (final s in const [
          AgentLifecycle.created,
          AgentLifecycle.active,
          AgentLifecycle.dormant,
          AgentLifecycle.destroyed,
        ])
          AgentListFilterOption(
            id: s.name,
            label: agentLifecycleLabel(messages, s),
            count: statusCounts[s] ?? 0,
          ),
      ],
    ),
    if (soulOptions.isNotEmpty)
      AgentListFilterAxis(
        id: _soulAxisId,
        sectionLabel: messages.agentInstancesFilterSectionSoul,
        options: soulOptions,
      ),
  ];
}

List<AgentListGroupAxis> _buildGroupAxes(
  AppLocalizations messages,
  AsyncValue<_AdaptedRows> adapted,
) {
  // Capture the hints map — group builders need it, but only the data
  // branch has hints. Inside the closures we look up hints by row id.
  Map<String, _RowHint> hintsOf() => adapted.maybeWhen(
    data: (a) => a.hints,
    orElse: () => const <String, _RowHint>{},
  );

  return [
    AgentListGroupAxis(
      id: _groupBySoul,
      label: messages.agentInstancesGroupBySoul,
      buildGroups: (rows) => _groupBySoulFn(rows, hintsOf(), messages),
    ),
    AgentListGroupAxis(
      id: _groupByType,
      label: messages.agentInstancesGroupByType,
      buildGroups: (rows) => _groupByTypeFn(rows, hintsOf(), messages),
    ),
    AgentListGroupAxis(
      id: _groupByStatus,
      label: messages.agentInstancesGroupByStatus,
      buildGroups: (rows) => _groupByStatusFn(rows, hintsOf(), messages),
    ),
  ];
}

List<AgentListSortAxis> _buildSortAxes(AppLocalizations messages) {
  return [
    AgentListSortAxis(
      id: _sortRecent,
      label: messages.agentInstancesSortRecent,
      compare: (a, b) => b.sortAt.compareTo(a.sortAt),
    ),
    AgentListSortAxis(
      id: _sortOldest,
      label: messages.agentInstancesSortOldest,
      compare: (a, b) => a.sortAt.compareTo(b.sortAt),
    ),
    AgentListSortAxis(
      id: _sortName,
      label: messages.agentInstancesSortName,
      compare: (a, b) {
        final byName = a.title.toLowerCase().compareTo(b.title.toLowerCase());
        if (byName != 0) return byName;
        return a.id.compareTo(b.id);
      },
    ),
  ];
}

// ── Group builders ──────────────────────────────────────────────────────────

List<AgentListGroup> _groupBySoulFn(
  List<AgentListRowData> rows,
  Map<String, _RowHint> hints,
  AppLocalizations messages,
) {
  final buckets = <String, List<AgentListRowData>>{};
  final order = <String>[];
  final labelById = <String, String>{};
  final leadingById = <String, AgentListAvatarLeading?>{};
  for (final row in rows) {
    final hint = hints[row.id];
    final id = hint?.soulId ?? '__no_soul__';
    if (!buckets.containsKey(id)) {
      buckets[id] = [];
      order.add(id);
      final leading = row.leading;
      labelById[id] = leading is AgentListAvatarLeading
          ? leading.label
          : messages.agentInstancesUnassignedSoul;
      leadingById[id] = leading is AgentListAvatarLeading ? leading : null;
    }
    buckets[id]!.add(row);
  }
  final groups = order.map((id) {
    final items = buckets[id]!;
    return AgentListGroup(
      id: 'soul:$id',
      label: labelById[id]!,
      leading: leadingById[id],
      items: items,
      activeCount: _activeCountFor(items, hints),
    );
  }).toList()..sort((a, b) => b.items.length.compareTo(a.items.length));
  return groups;
}

List<AgentListGroup> _groupByTypeFn(
  List<AgentListRowData> rows,
  Map<String, _RowHint> hints,
  AppLocalizations messages,
) {
  final buckets = <InstanceType, List<AgentListRowData>>{};
  for (final row in rows) {
    final t = hints[row.id]?.type ?? InstanceType.taskAgent;
    buckets.putIfAbsent(t, () => []).add(row);
  }
  return buckets.entries
      .map(
        (e) => AgentListGroup(
          id: 'type:${e.key.name}',
          label: instanceTypeLabel(messages, e.key),
          items: e.value,
          activeCount: _activeCountFor(e.value, hints),
        ),
      )
      .toList()
    ..sort((a, b) => a.label.compareTo(b.label));
}

List<AgentListGroup> _groupByStatusFn(
  List<AgentListRowData> rows,
  Map<String, _RowHint> hints,
  AppLocalizations messages,
) {
  final buckets = <AgentLifecycle, List<AgentListRowData>>{};
  for (final row in rows) {
    final s = hints[row.id]?.status ?? AgentLifecycle.active;
    buckets.putIfAbsent(s, () => []).add(row);
  }
  return buckets.entries
      .map(
        (e) => AgentListGroup(
          id: 'status:${e.key.name}',
          label: agentLifecycleLabel(messages, e.key),
          items: e.value,
        ),
      )
      .toList()
    ..sort((a, b) => a.label.compareTo(b.label));
}

int? _activeCountFor(
  List<AgentListRowData> rows,
  Map<String, _RowHint> hints,
) {
  final n = rows.where((r) {
    return hints[r.id]?.status == AgentLifecycle.active;
  }).length;
  return n == 0 ? null : n;
}

// ── Axis matcher ────────────────────────────────────────────────────────────

bool _matchRow(
  AsyncValue<_AdaptedRows> adapted,
  AgentListRowData row,
  String axisId,
  Set<String> selected,
) {
  final hints = adapted.maybeWhen(
    data: (a) => a.hints,
    orElse: () => const <String, _RowHint>{},
  );
  final hint = hints[row.id];
  if (hint == null) return true;
  return switch (axisId) {
    _typeAxisId => selected.contains(hint.type.name),
    _statusAxisId => selected.contains(hint.status.name),
    _soulAxisId => selected.contains(hint.soulId),
    _ => true,
  };
}
