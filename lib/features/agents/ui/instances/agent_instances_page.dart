import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  // Cached derived data — recomputed only when the underlying `vms` list
  // reference or the unassigned-soul label changes (so search keystrokes,
  // hover, and group-toggle don't re-iterate the rows).
  List<InstanceVm>? _cachedVms;
  String? _cachedUnassignedLabel;
  FilterCounts? _cachedCounts;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final asyncVms = ref.watch(agentInstanceVmsProvider);

    // Background level-02 keeps the page in line with the rest of the
    // settings surface (the parent Scaffold paints level-01).
    return ColoredBox(
      color: tokens.colors.background.level02,
      child: asyncVms.when(
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
      ),
    );
  }

  FilterCounts _countsFor(List<InstanceVm> vms, String unassignedLabel) {
    if (identical(_cachedVms, vms) &&
        _cachedUnassignedLabel == unassignedLabel &&
        _cachedCounts != null) {
      return _cachedCounts!;
    }
    final counts = FilterCounts.from(vms, unassignedLabel);
    _cachedVms = vms;
    _cachedUnassignedLabel = unassignedLabel;
    _cachedCounts = counts;
    return counts;
  }

  Widget _buildBody(BuildContext context, List<InstanceVm> vms) {
    final messages = context.messages;
    final counts = _countsFor(vms, messages.agentInstancesUnassignedSoul);
    final result = buildGroupedInstances(
      all: vms,
      state: _filters,
      unassignedSoulLabel: messages.agentInstancesUnassignedSoul,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InstancesToolbar(
          state: _filters,
          onChanged: _setFilters,
          totalBeforeFilter: result.totalBeforeFilter,
          totalAfterFilter: result.totalAfterFilter,
          counts: counts,
        ),
        if (_filters.isAnyFilterActive)
          ActiveFiltersRow(
            state: _filters,
            onChanged: _setFilters,
            soulOptions: counts.soulOptions,
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
    setState(() {
      // Drop collapse-state when the group axis changes — old group ids
      // (e.g. `soul:laura`) won't recur and would otherwise leak.
      if (next.groupKey != _filters.groupKey) {
        _collapsed.clear();
      }
      _filters = next;
    });
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
