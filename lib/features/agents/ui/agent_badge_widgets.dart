import 'package:flutter/material.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

/// A small pill badge with a label and color.
///
/// Used across agent UI for status, kind, and lifecycle indicators.
class AgentBadge extends StatelessWidget {
  const AgentBadge({required this.label, required this.color, super.key});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingSmall,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.spacingXSmall),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: context.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Badge displaying the lifecycle state of an agent.
class AgentLifecycleBadge extends StatelessWidget {
  const AgentLifecycleBadge({required this.lifecycle, super.key});

  final AgentLifecycle lifecycle;

  @override
  Widget build(BuildContext context) {
    final (label, color) = _lifecycleStyle(context, lifecycle);
    return AgentBadge(label: label, color: color);
  }

  static (String, Color) _lifecycleStyle(
    BuildContext context,
    AgentLifecycle lifecycle,
  ) {
    final scheme = context.colorScheme;
    final l10n = context.messages;
    return switch (lifecycle) {
      AgentLifecycle.created => (l10n.agentLifecycleCreated, scheme.tertiary),
      AgentLifecycle.active => (l10n.agentLifecycleActive, scheme.primary),
      AgentLifecycle.dormant => (l10n.agentLifecyclePaused, scheme.outline),
      AgentLifecycle.destroyed => (l10n.agentLifecycleDestroyed, scheme.error),
    };
  }
}
