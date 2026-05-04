import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/ui/listing/agent_list_data.dart';
import 'package:lotti/features/agents/ui/listing/agent_list_filter_state.dart';
import 'package:lotti/features/agents/ui/listing/widgets/active_filters_row.dart';
import 'package:lotti/features/agents/ui/listing/widgets/agent_list_group_section.dart';
import 'package:lotti/features/agents/ui/listing/widgets/agent_list_toolbar.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Shared right-column shell used by every agent listing page (Instances,
/// Templates, Souls, Pending Wakes).
///
/// Each tab supplies the data + axes; the shell owns the filter UI state
/// (search, selections, group axis, sort axis, per-group collapse) and
/// renders the toolbar + chip row + grouped list with the matching
/// `background.level01` surface.
class AgentListingShell extends StatefulWidget {
  const AgentListingShell({
    required this.rowsAsync,
    required this.filterAxes,
    required this.groupAxes,
    required this.sortAxes,
    required this.searchPlaceholder,
    required this.emptyMessage,
    required this.axisMatcher,
    super.key,
  });

  final AsyncValue<List<AgentListRowData>> rowsAsync;
  final List<AgentListFilterAxis> filterAxes;
  final List<AgentListGroupAxis> groupAxes;
  final List<AgentListSortAxis> sortAxes;
  final String searchPlaceholder;
  final String emptyMessage;

  /// Page-supplied predicate that maps an axis selection set onto a row.
  /// Lives here (not on the row) so the shell stays domain-agnostic.
  final AgentListAxisMatcher axisMatcher;

  @override
  State<AgentListingShell> createState() => _AgentListingShellState();
}

class _AgentListingShellState extends State<AgentListingShell> {
  late AgentListFilterState _filters;
  final Map<String, bool> _collapsed = {};

  @override
  void initState() {
    super.initState();
    _filters = AgentListFilterState(
      groupAxisId: widget.groupAxes.isEmpty ? '' : widget.groupAxes.first.id,
      sortAxisId: widget.sortAxes.isEmpty ? '' : widget.sortAxes.first.id,
    );
  }

  @override
  void didUpdateWidget(covariant AgentListingShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the page swaps its axes (rare; e.g. dynamic config), reseat the
    // selected ids so the dropdowns don't point at a dead option.
    final groupOk = widget.groupAxes.any((a) => a.id == _filters.groupAxisId);
    final sortOk = widget.sortAxes.any((a) => a.id == _filters.sortAxisId);
    if (!groupOk || !sortOk) {
      _filters = _filters.copyWith(
        groupAxisId: groupOk
            ? _filters.groupAxisId
            : (widget.groupAxes.isEmpty ? '' : widget.groupAxes.first.id),
        sortAxisId: sortOk
            ? _filters.sortAxisId
            : (widget.sortAxes.isEmpty ? '' : widget.sortAxes.first.id),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;

    return ColoredBox(
      color: tokens.colors.background.level01,
      child: widget.rowsAsync.when(
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
        data: (rows) => _buildBody(context, rows),
      ),
    );
  }

  Widget _buildBody(BuildContext context, List<AgentListRowData> rows) {
    final result = buildGroupedAgentList(
      all: rows,
      state: _filters,
      filterAxes: widget.filterAxes,
      groupAxes: widget.groupAxes,
      sortAxes: widget.sortAxes,
      axisMatcher: widget.axisMatcher,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AgentListToolbar(
          state: _filters,
          onChanged: _setFilters,
          totalBeforeFilter: result.totalBeforeFilter,
          totalAfterFilter: result.totalAfterFilter,
          filterAxes: widget.filterAxes,
          groupAxes: widget.groupAxes,
          sortAxes: widget.sortAxes,
          searchPlaceholder: widget.searchPlaceholder,
        ),
        if (_filters.isAnyFilterActive)
          ActiveFiltersRow(
            state: _filters,
            axes: widget.filterAxes,
            onChanged: _setFilters,
          ),
        Expanded(
          child: result.groups.isEmpty
              ? _EmptyState(
                  message: widget.emptyMessage,
                  onClear: _filters.isAnyFilterActive
                      ? () => _setFilters(_filters.clearAll())
                      : null,
                )
              : _buildGroupedList(context, result),
        ),
      ],
    );
  }

  Widget _buildGroupedList(
    BuildContext context,
    AgentListPipelineResult result,
  ) {
    final tokens = context.designTokens;
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
              AgentListGroupHeader(
                group: group,
                expanded: expanded,
                // _collapsed[id] == true means "collapsed"; storing the
                // *current* visible state flips it on the next build.
                onToggle: () => setState(() {
                  _collapsed[group.id] = expanded;
                }),
              ),
              if (expanded) AgentListGroupBody(group: group),
            ],
          ),
        );
      },
    );
  }

  void _setFilters(AgentListFilterState next) {
    setState(() {
      // Drop collapse-state when the group axis changes — old group ids
      // (e.g. `soul:laura`) won't recur and would otherwise leak.
      if (next.groupAxisId != _filters.groupAxisId) {
        _collapsed.clear();
      }
      _filters = next;
    });
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message, this.onClear});

  final String message;
  final VoidCallback? onClear;

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
              message,
              style: TextStyle(color: tokens.colors.text.lowEmphasis),
            ),
            if (onClear != null) ...[
              SizedBox(height: tokens.spacing.step3),
              TextButton(
                onPressed: onClear,
                child: Text(messages.agentInstancesFilterClearAll),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
