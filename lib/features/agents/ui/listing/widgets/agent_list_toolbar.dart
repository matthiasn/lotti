import 'package:flutter/material.dart';
import 'package:lotti/features/agents/ui/listing/agent_list_data.dart';
import 'package:lotti/features/agents/ui/listing/agent_list_filter_state.dart';
import 'package:lotti/features/agents/ui/listing/widgets/agent_list_toolbar_search.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Toolbar row: Filters / Group by / Sort buttons, search input, count.
///
/// Generic over the page's filter axes — Instances, Templates, Souls,
/// and Pending Wakes all build their own list of [AgentListFilterAxis] /
/// [AgentListGroupAxis] / [AgentListSortAxis] and feed them to this
/// shared toolbar.
class AgentListToolbar extends StatelessWidget {
  const AgentListToolbar({
    required this.state,
    required this.onChanged,
    required this.totalBeforeFilter,
    required this.totalAfterFilter,
    required this.filterAxes,
    required this.groupAxes,
    required this.sortAxes,
    required this.searchPlaceholder,
    super.key,
  });

  final AgentListFilterState state;
  final ValueChanged<AgentListFilterState> onChanged;
  final int totalBeforeFilter;
  final int totalAfterFilter;
  final List<AgentListFilterAxis> filterAxes;
  final List<AgentListGroupAxis> groupAxes;
  final List<AgentListSortAxis> sortAxes;
  final String searchPlaceholder;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;

    final countText = Text(
      totalAfterFilter == totalBeforeFilter
          ? messages.agentInstancesResultCountAll(totalBeforeFilter)
          : messages.agentInstancesResultCountFiltered(
              totalAfterFilter,
              totalBeforeFilter,
            ),
      style: monoMetaStyle(tokens, tokens.colors),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.step6,
        tokens.spacing.step4,
        tokens.spacing.step6,
        tokens.spacing.step3,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Wide enough to keep everything on one line: filter / group /
          // sort buttons (~260) + search (max 280) + count (~110) + gaps.
          final wide = constraints.maxWidth >= 700;
          final filtersBtn = filterAxes.isEmpty
              ? null
              : _FiltersButton(
                  state: state,
                  onChanged: onChanged,
                  axes: filterAxes,
                );
          final groupBtn = groupAxes.length < 2
              ? null
              : _GroupByButton(
                  state: state,
                  onChanged: onChanged,
                  axes: groupAxes,
                );
          final sortBtn = sortAxes.length < 2
              ? null
              : _SortButton(
                  state: state,
                  onChanged: onChanged,
                  axes: sortAxes,
                );
          final search = ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: SearchField(
              value: state.search,
              onChanged: (v) => onChanged(state.copyWith(search: v)),
              placeholder: searchPlaceholder,
            ),
          );

          if (wide) {
            return Row(
              children: [
                if (filtersBtn != null) ...[
                  filtersBtn,
                  SizedBox(width: tokens.spacing.step2),
                ],
                if (groupBtn != null) ...[
                  groupBtn,
                  SizedBox(width: tokens.spacing.step2),
                ],
                if (sortBtn != null) ...[
                  sortBtn,
                  SizedBox(width: tokens.spacing.step2),
                ],
                SizedBox(width: tokens.spacing.step3),
                Flexible(child: search),
                const Spacer(),
                countText,
              ],
            );
          }

          // Compact: buttons + count wrap across lines, search takes a
          // full line below so it always has enough width to be usable.
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: tokens.spacing.step2,
                runSpacing: tokens.spacing.step2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ?filtersBtn,
                  ?groupBtn,
                  ?sortBtn,
                  countText,
                ],
              ),
              SizedBox(height: tokens.spacing.step3),
              SizedBox(
                width: double.infinity,
                child: SearchField(
                  value: state.search,
                  onChanged: (v) => onChanged(state.copyWith(search: v)),
                  placeholder: searchPlaceholder,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Buttons ─────────────────────────────────────────────────────────────────

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.onTap,
    required this.child,
    this.trailing,
    this.emphasised = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Widget child;
  final Widget? trailing;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final colors = tokens.colors;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(tokens.radii.s),
      child: InkWell(
        borderRadius: BorderRadius.circular(tokens.radii.s),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.step4,
            vertical: tokens.spacing.step2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 13,
                color: emphasised
                    ? colors.text.highEmphasis
                    : colors.text.mediumEmphasis,
              ),
              SizedBox(width: tokens.spacing.step3),
              DefaultTextStyle.merge(
                style: tokens.typography.styles.others.caption.copyWith(
                  color: emphasised
                      ? colors.text.highEmphasis
                      : colors.text.mediumEmphasis,
                ),
                child: child,
              ),
              if (trailing != null) ...[
                SizedBox(width: tokens.spacing.step3),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FiltersButton extends StatelessWidget {
  const _FiltersButton({
    required this.state,
    required this.onChanged,
    required this.axes,
  });

  final AgentListFilterState state;
  final ValueChanged<AgentListFilterState> onChanged;
  final List<AgentListFilterAxis> axes;

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    final activeCount = state.activeFilterCount;
    return _ToolbarButton(
      icon: Icons.tune,
      emphasised: activeCount > 0,
      onTap: () => showFiltersPopover(
        context: context,
        state: state,
        onChanged: onChanged,
        axes: axes,
      ),
      trailing: activeCount > 0 ? _CountBadge(count: activeCount) : null,
      child: Text(messages.agentInstancesToolbarFilters),
    );
  }
}

class _GroupByButton extends StatelessWidget {
  const _GroupByButton({
    required this.state,
    required this.onChanged,
    required this.axes,
  });

  final AgentListFilterState state;
  final ValueChanged<AgentListFilterState> onChanged;
  final List<AgentListGroupAxis> axes;

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    final tokens = context.designTokens;
    final current = axes.firstWhere(
      (a) => a.id == state.groupAxisId,
      orElse: () => axes.first,
    );
    return _ToolbarButton(
      icon: Icons.layers_outlined,
      onTap: () async {
        final next = await showSingleSelectPopover<String>(
          context: context,
          current: current.id,
          options: [for (final a in axes) (a.id, a.label)],
          width: 150,
        );
        if (next != null) onChanged(state.copyWith(groupAxisId: next));
      },
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '${messages.agentInstancesToolbarGroupBy} '),
            TextSpan(
              text: current.label,
              style: TextStyle(color: tokens.colors.interactive.enabled),
            ),
          ],
        ),
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  const _SortButton({
    required this.state,
    required this.onChanged,
    required this.axes,
  });

  final AgentListFilterState state;
  final ValueChanged<AgentListFilterState> onChanged;
  final List<AgentListSortAxis> axes;

  @override
  Widget build(BuildContext context) {
    final current = axes.firstWhere(
      (a) => a.id == state.sortAxisId,
      orElse: () => axes.first,
    );
    return _ToolbarButton(
      icon: Icons.sort,
      onTap: () async {
        final next = await showSingleSelectPopover<String>(
          context: context,
          current: current.id,
          options: [for (final a in axes) (a.id, a.label)],
          width: 150,
        );
        if (next != null) onChanged(state.copyWith(sortAxisId: next));
      },
      child: Text(current.label),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Container(
      constraints: const BoxConstraints(minWidth: 16),
      height: 16,
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step2),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tokens.colors.interactive.enabled,
        borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
      ),
      child: Text(
        '$count',
        style: tokens.typography.styles.others.caption.copyWith(
          fontFamily: 'Inconsolata',
          fontWeight: tokens.typography.weight.bold,
          color: tokens.colors.text.onInteractiveAlert,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
