import 'package:flutter/material.dart';
import 'package:lotti/features/agents/ui/instances/instance_filter_state.dart';
import 'package:lotti/features/agents/ui/instances/instance_view_model.dart';
import 'package:lotti/features/design_system/components/chips/active_filter_chip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Removable chip row shown below the toolbar when at least one filter
/// (type / status / soul / search) is active.
class ActiveFiltersRow extends StatelessWidget {
  const ActiveFiltersRow({
    required this.state,
    required this.onChanged,
    required this.soulOptions,
    super.key,
  });

  final InstancesFilterState state;
  final ValueChanged<InstancesFilterState> onChanged;
  final List<SoulOption> soulOptions;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final colors = tokens.colors;
    final soulLabelById = {for (final s in soulOptions) s.id: s.label};

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
          for (final t in state.types)
            ActiveFilterChip(
              label: instanceTypeLabel(messages, t),
              accentColor: colors.alert.warning.defaultColor,
              onRemove: () => onChanged(state.toggleType(t)),
            ),
          for (final s in state.statuses)
            ActiveFilterChip(
              label: agentLifecycleLabel(messages, s),
              accentColor: colors.interactive.enabled,
              onRemove: () => onChanged(state.toggleStatus(s)),
            ),
          for (final id in state.soulIds)
            ActiveFilterChip(
              label: soulLabelById[id] ?? id,
              accentColor: colors.decorative.level02,
              onRemove: () => onChanged(state.toggleSoul(id)),
            ),
          if (state.search.isNotEmpty)
            ActiveFilterChip(
              label: '“${state.search}”',
              accentColor: colors.decorative.level02,
              onRemove: () => onChanged(state.copyWith(search: '')),
            ),
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
}
