import 'package:flutter/material.dart';
import 'package:lotti/features/agents/ui/listing/agent_list_data.dart';
import 'package:lotti/features/agents/ui/listing/agent_list_filter_state.dart';
import 'package:lotti/features/design_system/components/chips/active_filter_chip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Removable chip row shown below the toolbar when at least one filter
/// (any axis selection or search) is active.
class ActiveFiltersRow extends StatelessWidget {
  const ActiveFiltersRow({
    required this.state,
    required this.axes,
    required this.onChanged,
    super.key,
  });

  final AgentListFilterState state;
  final List<AgentListFilterAxis> axes;
  final ValueChanged<AgentListFilterState> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final colors = tokens.colors;

    final chips = <Widget>[];
    for (final axis in axes) {
      final selected = state.selectionsFor(axis.id);
      if (selected.isEmpty) continue;
      final accent = _toneAccent(axis.chipTone, colors);
      for (final option in axis.options) {
        if (!selected.contains(option.id)) continue;
        chips.add(
          ActiveFilterChip(
            label: option.label,
            accentColor: accent,
            onRemove: () => onChanged(state.toggleOption(axis.id, option.id)),
          ),
        );
      }
    }
    if (state.search.isNotEmpty) {
      chips.add(
        ActiveFilterChip(
          label: '“${state.search}”',
          accentColor: colors.decorative.level02,
          onRemove: () => onChanged(state.copyWith(search: '')),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.step6,
        tokens.spacing.step2,
        tokens.spacing.step6,
        tokens.spacing.step3,
      ),
      child: Wrap(
        spacing: tokens.spacing.step2,
        runSpacing: tokens.spacing.step2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ...chips,
          InkWell(
            onTap: () => onChanged(state.clearAll()),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spacing.step3,
                vertical: tokens.spacing.step1,
              ),
              child: Text(
                messages.agentInstancesFilterClearAll,
                style: tokens.typography.styles.others.caption.copyWith(
                  fontWeight: tokens.typography.weight.semiBold,
                  color: colors.text.mediumEmphasis,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _toneAccent(AgentListPillTone tone, DsColors colors) {
    return switch (tone) {
      AgentListPillTone.interactive => colors.interactive.enabled,
      AgentListPillTone.warning => colors.alert.warning.defaultColor,
      AgentListPillTone.error => colors.alert.error.defaultColor,
      AgentListPillTone.info => colors.alert.info.defaultColor,
      AgentListPillTone.muted => colors.text.mediumEmphasis,
      AgentListPillTone.neutral => colors.decorative.level02,
    };
  }
}
