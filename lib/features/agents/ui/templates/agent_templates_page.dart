import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/ui/agent_palette.dart';
import 'package:lotti/features/agents/ui/listing/agent_list_data.dart';
import 'package:lotti/features/agents/ui/listing/agent_listing_shell.dart';
import 'package:lotti/features/agents/ui/templates/template_view_model.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';

const String _kindAxisId = 'kind';
const String _groupByKind = 'kind';
const String _groupNone = 'all';
const String _sortName = 'name';
const String _sortRecent = 'recent';
const String _sortOldest = 'oldest';

/// Settings → Agents → Templates page. Adapts the domain VMs into the
/// shared [AgentListingShell].
class AgentTemplatesPage extends ConsumerWidget {
  const AgentTemplatesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = context.messages;
    final asyncVms = ref.watch(agentTemplateRowVmsProvider);

    final adapted = asyncVms.whenData(
      (vms) => _AdaptedRows.from(vms, messages),
    );

    final filterAxes = adapted.maybeWhen(
      data: (a) => _buildFilterAxes(a, messages),
      orElse: () => const <AgentListFilterAxis>[],
    );
    final hints = adapted.maybeWhen(
      data: (a) => a.hints,
      orElse: () => const <String, AgentTemplateKind>{},
    );

    return AgentListingShell(
      rowsAsync: adapted.whenData((a) => a.rows),
      filterAxes: filterAxes,
      groupAxes: _buildGroupAxes(messages, hints),
      sortAxes: _buildSortAxes(messages),
      searchPlaceholder: messages.agentTemplatesSearchPlaceholder,
      emptyMessage: messages.agentTemplatesEmptyFiltered,
      axisMatcher: (axisId, selected, row) =>
          _matchRow(hints, row, axisId, selected),
    );
  }
}

/// Adapter output: row list + per-id hint with the typed kind so the
/// matcher / group axes don't have to decode localized labels.
class _AdaptedRows {
  const _AdaptedRows({required this.rows, required this.hints});

  factory _AdaptedRows.from(List<TemplateVm> vms, AppLocalizations messages) {
    final rows = <AgentListRowData>[];
    final hints = <String, AgentTemplateKind>{};
    for (final vm in vms) {
      rows.add(_vmToRow(vm, messages));
      hints[vm.id] = vm.kind;
    }
    return _AdaptedRows(rows: rows, hints: hints);
  }

  final List<AgentListRowData> rows;
  final Map<String, AgentTemplateKind> hints;
}

AgentListRowData _vmToRow(TemplateVm vm, AppLocalizations messages) {
  return AgentListRowData(
    id: vm.id,
    title: vm.displayName,
    subtitle: vm.modelId,
    leading: AgentListIconLeading(
      icon: Icons.smart_toy_outlined,
      // Pending-review templates get a coloured icon so the dot's intent
      // (something needs your attention) survives the move from the
      // legacy positioned-overlay decoration.
      color: vm.hasPendingReview ? AgentPalette.purple : null,
    ),
    pills: [AgentListPill(label: agentTemplateKindLabel(messages, vm.kind))],
    metaRight: vm.activeVersion != null ? 'v${vm.activeVersion}' : null,
    onTap: () => beamToNamed('/settings/agents/templates/${vm.id}'),
    sortAt: vm.updatedAt,
    searchKey: '${vm.displayName} ${vm.modelId} ${vm.id}'.toLowerCase(),
  );
}

// ── Axes ────────────────────────────────────────────────────────────────────

List<AgentListFilterAxis> _buildFilterAxes(
  _AdaptedRows adapted,
  AppLocalizations messages,
) {
  final counts = <AgentTemplateKind, int>{
    for (final k in AgentTemplateKind.values) k: 0,
  };
  for (final id in adapted.hints.keys) {
    final kind = adapted.hints[id]!;
    counts[kind] = (counts[kind] ?? 0) + 1;
  }
  // Don't show the Kind filter if every template has the same kind.
  final present = counts.entries.where((e) => e.value > 0).toList();
  if (present.length < 2) return const [];
  return [
    AgentListFilterAxis(
      id: _kindAxisId,
      sectionLabel: messages.agentTemplatesFilterSectionKind,
      chipTone: AgentListPillTone.warning,
      options: [
        for (final k in AgentTemplateKind.values)
          AgentListFilterOption(
            id: k.name,
            label: agentTemplateKindLabel(messages, k),
            count: counts[k] ?? 0,
          ),
      ],
    ),
  ];
}

List<AgentListGroupAxis> _buildGroupAxes(
  AppLocalizations messages,
  Map<String, AgentTemplateKind> hints,
) {
  return [
    AgentListGroupAxis(
      id: _groupNone,
      label: messages.agentTemplatesGroupNone,
      buildGroups: (rows) => rows.isEmpty
          ? const []
          : [
              AgentListGroup(
                id: 'all',
                label: messages.agentTemplatesGroupNone,
                items: rows,
              ),
            ],
    ),
    AgentListGroupAxis(
      id: _groupByKind,
      label: messages.agentTemplatesGroupByKind,
      buildGroups: (rows) => _groupByKindFn(rows, hints, messages),
    ),
  ];
}

List<AgentListSortAxis> _buildSortAxes(AppLocalizations messages) {
  return [
    AgentListSortAxis(
      id: _sortName,
      label: messages.agentInstancesSortName,
      compare: (a, b) {
        final byName = a.title.toLowerCase().compareTo(b.title.toLowerCase());
        if (byName != 0) return byName;
        return a.id.compareTo(b.id);
      },
    ),
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
  ];
}

// ── Group builders ──────────────────────────────────────────────────────────

List<AgentListGroup> _groupByKindFn(
  List<AgentListRowData> rows,
  Map<String, AgentTemplateKind> hints,
  AppLocalizations messages,
) {
  final buckets = <AgentTemplateKind, List<AgentListRowData>>{};
  for (final row in rows) {
    final kind = hints[row.id] ?? AgentTemplateKind.taskAgent;
    buckets.putIfAbsent(kind, () => []).add(row);
  }
  return buckets.entries
      .map(
        (e) => AgentListGroup(
          id: 'kind:${e.key.name}',
          label: agentTemplateKindLabel(messages, e.key),
          items: e.value,
        ),
      )
      .toList()
    ..sort((a, b) => a.label.compareTo(b.label));
}

// ── Axis matcher ────────────────────────────────────────────────────────────

bool _matchRow(
  Map<String, AgentTemplateKind> hints,
  AgentListRowData row,
  String axisId,
  Set<String> selected,
) {
  final kind = hints[row.id];
  if (kind == null) return true;
  return switch (axisId) {
    _kindAxisId => selected.contains(kind.name),
    _ => true,
  };
}
