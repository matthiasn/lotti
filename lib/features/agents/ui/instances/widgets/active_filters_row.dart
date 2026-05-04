import 'package:flutter/material.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/ui/instances/instance_filter_state.dart';
import 'package:lotti/features/agents/ui/instances/instance_view_model.dart';
import 'package:lotti/features/agents/ui/instances/widgets/instances_toolbar.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations.dart';
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
            _Chip(
              label: _typeLabel(messages, t),
              tone: _ChipTone.warning,
              onRemove: () => onChanged(state.toggleType(t)),
            ),
          for (final s in state.statuses)
            _Chip(
              label: _statusLabel(messages, s),
              tone: _ChipTone.interactive,
              onRemove: () => onChanged(state.toggleStatus(s)),
            ),
          for (final id in state.soulIds)
            _Chip(
              label: soulLabelById[id] ?? id,
              tone: _ChipTone.neutral,
              onRemove: () => onChanged(state.toggleSoul(id)),
            ),
          if (state.search.isNotEmpty)
            _Chip(
              label: '“${state.search}”',
              tone: _ChipTone.neutral,
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
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
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

enum _ChipTone { neutral, warning, interactive }

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.onRemove,
    required this.tone,
  });

  final String label;
  final VoidCallback onRemove;
  final _ChipTone tone;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final colors = tokens.colors;
    final (fg, bg, border) = switch (tone) {
      _ChipTone.neutral => (
        colors.text.highEmphasis,
        colors.surface.enabled,
        colors.decorative.level01,
      ),
      _ChipTone.warning => (
        colors.alert.warning.defaultColor,
        colors.alert.warning.defaultColor.withValues(alpha: 0.10),
        colors.alert.warning.defaultColor.withValues(alpha: 0.25),
      ),
      _ChipTone.interactive => (
        colors.interactive.enabled,
        colors.interactive.enabled.withValues(alpha: 0.10),
        colors.interactive.enabled.withValues(alpha: 0.25),
      ),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          tokens.spacing.step3,
          tokens.spacing.step1,
          tokens.spacing.step2,
          tokens.spacing.step1,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
            const SizedBox(width: 4),
            InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(999),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(Icons.close, size: 12, color: fg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _typeLabel(AppLocalizations messages, InstanceType t) {
  return switch (t) {
    InstanceType.taskAgent => messages.agentTemplateKindTaskAgent,
    InstanceType.projectAgent => messages.agentTemplateKindProjectAgent,
    InstanceType.templateImprover => messages.agentTemplateKindImprover,
    InstanceType.evolution => messages.agentInstancesKindEvolution,
  };
}

String _statusLabel(AppLocalizations messages, AgentLifecycle s) {
  return switch (s) {
    AgentLifecycle.active => messages.agentLifecycleActive,
    AgentLifecycle.dormant => messages.agentLifecyclePaused,
    AgentLifecycle.destroyed => messages.agentLifecycleDestroyed,
    AgentLifecycle.created => messages.agentLifecycleCreated,
  };
}
