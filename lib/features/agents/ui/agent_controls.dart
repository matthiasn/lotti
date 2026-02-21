import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/themes/theme.dart';

/// Action buttons for controlling an agent's lifecycle.
///
/// Provides pause/resume toggle, manual re-analysis trigger, and destroy
/// (with confirmation dialog).
class AgentControls extends ConsumerWidget {
  const AgentControls({
    required this.agentId,
    required this.lifecycle,
    super.key,
  });

  final String agentId;
  final AgentLifecycle lifecycle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isActive = lifecycle == AgentLifecycle.active;
    final isDormant = lifecycle == AgentLifecycle.dormant;
    final isDestroyed = lifecycle == AgentLifecycle.destroyed;

    if (isDestroyed) {
      return Padding(
        padding: const EdgeInsets.all(AppTheme.cardPadding),
        child: Text(
          // TODO(l10n): localize destroyed message
          'This agent has been destroyed.',
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colorScheme.outline,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.cardPaddingHalf,
        vertical: AppTheme.spacingSmall,
      ),
      child: Wrap(
        spacing: AppTheme.spacingSmall,
        runSpacing: AppTheme.spacingSmall,
        children: [
          if (isActive)
            FilledButton.tonalIcon(
              onPressed: () => _pauseAgent(ref),
              icon: const Icon(Icons.pause_rounded),
              // TODO(l10n): localize button label
              label: const Text('Pause'),
            ),
          if (isDormant)
            FilledButton.tonalIcon(
              onPressed: () => _resumeAgent(ref),
              icon: const Icon(Icons.play_arrow_rounded),
              // TODO(l10n): localize button label
              label: const Text('Resume'),
            ),
          if (isActive || isDormant)
            OutlinedButton.icon(
              onPressed: () => _triggerReanalysis(ref),
              icon: const Icon(Icons.refresh_rounded),
              // TODO(l10n): localize button label
              label: const Text('Re-analyze'),
            ),
          if (isActive || isDormant)
            OutlinedButton.icon(
              onPressed: () => _confirmDestroy(context, ref),
              icon: Icon(
                Icons.delete_forever_rounded,
                color: context.colorScheme.error,
              ),
              // TODO(l10n): localize button label
              label: Text(
                'Destroy',
                style: TextStyle(color: context.colorScheme.error),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pauseAgent(WidgetRef ref) async {
    await ref.read(agentServiceProvider).pauseAgent(agentId);
    ref.invalidate(agentIdentityProvider(agentId));
  }

  Future<void> _resumeAgent(WidgetRef ref) async {
    await ref.read(agentServiceProvider).resumeAgent(agentId);
    ref.invalidate(agentIdentityProvider(agentId));
  }

  void _triggerReanalysis(WidgetRef ref) {
    ref.read(taskAgentServiceProvider).triggerReanalysis(agentId);
  }

  Future<void> _confirmDestroy(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        // TODO(l10n): localize dialog title
        title: const Text('Destroy Agent?'),
        // TODO(l10n): localize dialog content
        content: const Text(
          'This will permanently deactivate the agent. '
          'Its history will be preserved for audit.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            // TODO(l10n): localize cancel button
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: context.colorScheme.error,
            ),
            // TODO(l10n): localize confirm button
            child: const Text('Destroy'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      await ref.read(agentServiceProvider).destroyAgent(agentId);
      ref.invalidate(agentIdentityProvider(agentId));
    }
  }
}
