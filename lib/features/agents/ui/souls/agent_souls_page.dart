import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/ui/listing/agent_list_data.dart';
import 'package:lotti/features/agents/ui/listing/agent_list_filter_state.dart';
import 'package:lotti/features/agents/ui/listing/agent_listing_shell.dart';
import 'package:lotti/features/agents/ui/souls/soul_view_model.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';

const String _groupNone = 'all';
const String _sortName = 'name';
const String _sortRecent = 'recent';
const String _sortOldest = 'oldest';

/// Settings → Agents → Souls page. Adapts the domain VMs into the shared
/// [AgentListingShell]. Souls have no filterable typed axes today, so
/// only search + sort are exposed.
class AgentSoulsPage extends ConsumerWidget {
  const AgentSoulsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = context.messages;
    final asyncVms = ref.watch(agentSoulRowVmsProvider);

    final rowsAsync = asyncVms.whenData(
      (vms) => [for (final vm in vms) _vmToRow(vm, messages)],
    );

    return AgentListingShell(
      rowsAsync: rowsAsync,
      filterAxes: const [],
      groupAxes: _buildGroupAxes(messages),
      sortAxes: _buildSortAxes(messages),
      searchPlaceholder: messages.agentSoulsSearchPlaceholder,
      emptyMessage: messages.agentSoulsEmptyFiltered,
      axisMatcher: _noAxisMatch,
    );
  }
}

bool _noAxisMatch(
  String axisId,
  Set<String> selected,
  AgentListRowData row,
) => true;

AgentListRowData _vmToRow(SoulVm vm, AppLocalizations messages) {
  return AgentListRowData(
    id: vm.id,
    title: vm.displayName,
    leading: AgentListAvatarLeading(
      label: vm.displayName,
      hue: hueForSeed(vm.id),
    ),
    metaRight: vm.activeVersion != null ? 'v${vm.activeVersion}' : null,
    onTap: () => beamToNamed('/settings/agents/souls/${vm.id}'),
    sortAt: vm.updatedAt,
    searchKey: '${vm.displayName} ${vm.id}'.toLowerCase(),
  );
}

// ── Axes ────────────────────────────────────────────────────────────────────

List<AgentListGroupAxis> _buildGroupAxes(AppLocalizations messages) {
  return [
    AgentListGroupAxis(
      id: _groupNone,
      label: messages.agentTemplatesGroupNone,
      buildGroups: (rows) => rows.isEmpty
          ? const []
          : [AgentListGroup(id: 'all', label: 'All', items: rows)],
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
