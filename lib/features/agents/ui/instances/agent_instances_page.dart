import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/ui/instances/instance_filter_state.dart';
import 'package:lotti/features/agents/ui/instances/instance_view_model.dart';
import 'package:lotti/features/agents/ui/instances/widgets/active_filters_row.dart';
import 'package:lotti/features/agents/ui/instances/widgets/instances_group_section.dart';
import 'package:lotti/features/agents/ui/instances/widgets/instances_toolbar.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';

/// Right-column body of Settings → Agents → Instances.
///
/// Owns the filter / sort / group / search state in a `setState`-driven
/// shell; the heavy lifting (filter pipeline, sticky-header rendering)
/// lives in the widgets under `widgets/`. The parent
/// `AgentSettingsPage` provides the `Agents` AppBar.
class AgentInstancesPage extends ConsumerStatefulWidget {
  const AgentInstancesPage({super.key});

  @override
  ConsumerState<AgentInstancesPage> createState() => _AgentInstancesPageState();
}

class _AgentInstancesPageState extends ConsumerState<AgentInstancesPage> {
  InstancesFilterState _filters = const InstancesFilterState();
  final Map<String, bool> _collapsed = {};

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final asyncVms = ref.watch(agentInstanceVmsProvider);

    return asyncVms.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(
        child: Padding(
          padding: EdgeInsets.all(tokens.spacing.step6),
          child: Text(
            messages.commonError,
            style: TextStyle(color: tokens.colors.alert.error.defaultColor),
          ),
        ),
      ),
      data: (vms) => _buildBody(context, vms),
    );
  }

  Widget _buildBody(BuildContext context, List<InstanceVm> vms) {
    final messages = context.messages;
    final result = buildGroupedInstances(
      all: vms,
      state: _filters,
      unassignedSoulLabel: messages.agentInstancesUnassignedSoul,
    );

    final typeCounts = <InstanceType, int>{
      for (final t in InstanceType.values)
        t: vms.where((v) => v.type == t).length,
    };
    final statusCounts = <AgentLifecycle, int>{
      for (final s in AgentLifecycle.values)
        s: vms.where((v) => v.status == s).length,
    };
    final soulOptions = _soulOptions(
      vms,
      messages.agentInstancesUnassignedSoul,
    );
    final soulCounts = <String, int>{
      for (final s in soulOptions)
        s.id: vms.where((v) => v.soulGroupId() == s.id).length,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InstancesToolbar(
          state: _filters,
          onChanged: _setFilters,
          totalBeforeFilter: result.totalBeforeFilter,
          totalAfterFilter: result.totalAfterFilter,
          typeCounts: typeCounts,
          statusCounts: statusCounts,
          soulOptions: soulOptions,
          soulCounts: soulCounts,
        ),
        if (_filters.isAnyFilterActive)
          ActiveFiltersRow(
            state: _filters,
            onChanged: _setFilters,
            soulOptions: soulOptions,
          ),
        Expanded(
          child: result.groups.isEmpty
              ? _EmptyState(onClear: () => _setFilters(_filters.clearAll()))
              : _buildGroupedList(context, result),
        ),
      ],
    );
  }

  Widget _buildGroupedList(
    BuildContext context,
    InstancesGroupedResult result,
  ) {
    final tokens = context.designTokens;
    final showSoul = _filters.groupKey != InstancesGroupKey.soul;
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step6),
      itemCount: result.groups.length,
      itemBuilder: (context, index) {
        final group = result.groups[index];
        final expanded = _collapsed[group.id] != true;
        return Padding(
          padding: EdgeInsets.only(bottom: tokens.spacing.step5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InstancesGroupHeader(
                group: group,
                groupKey: _filters.groupKey,
                expanded: expanded,
                // _collapsed[id] == true means "collapsed"; storing the
                // *current* visible state flips it on the next build.
                onToggle: () => setState(() {
                  _collapsed[group.id] = expanded;
                }),
              ),
              if (expanded)
                InstancesGroupBody(
                  group: group,
                  showSoul: showSoul,
                  onTapInstance: _openInstance,
                ),
            ],
          ),
        );
      },
    );
  }

  void _openInstance(String id) {
    beamToNamed('/settings/agents/instances/$id');
  }

  void _setFilters(InstancesFilterState next) {
    setState(() => _filters = next);
  }

  List<SoulOption> _soulOptions(List<InstanceVm> vms, String unassignedLabel) {
    final byId = <String, SoulOption>{};
    for (final vm in vms) {
      final id = vm.soulGroupId();
      if (byId.containsKey(id)) continue;
      byId[id] = SoulOption(
        id: id,
        label: vm.soulGroupLabel(unassignedLabel),
        hue: hueForSeed(id),
      );
    }
    final list = byId.values.toList()
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return list;
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.step6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search,
              size: 28,
              color: tokens.colors.text.lowEmphasis,
            ),
            SizedBox(height: tokens.spacing.step3),
            Text(
              messages.agentInstancesEmptyFiltered,
              style: TextStyle(color: tokens.colors.text.lowEmphasis),
            ),
            SizedBox(height: tokens.spacing.step3),
            TextButton(
              onPressed: onClear,
              child: Text(messages.agentInstancesFilterClearAll),
            ),
          ],
        ),
      ),
    );
  }
}
