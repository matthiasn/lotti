import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

/// Action buttons for controlling an agent's lifecycle.
///
/// Provides pause/resume toggle, manual re-analysis trigger, and destroy
/// (with confirmation dialog).
class AgentControls extends ConsumerStatefulWidget {
  const AgentControls({
    required this.agentId,
    required this.lifecycle,
    super.key,
  });

  final String agentId;
  final AgentLifecycle lifecycle;

  @override
  ConsumerState<AgentControls> createState() => _AgentControlsState();
}

class _AgentControlsState extends ConsumerState<AgentControls> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final isActive = widget.lifecycle == AgentLifecycle.active;
    final isDormant = widget.lifecycle == AgentLifecycle.dormant;
    final isDestroyed = widget.lifecycle == AgentLifecycle.destroyed;

    if (isDestroyed) {
      return Padding(
        padding: const EdgeInsets.all(AppTheme.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.messages.agentControlsDestroyedMessage,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.outline,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: AppTheme.spacingSmall),
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () => _confirmAction(
                        context: context,
                        title: context.messages.agentControlsDeleteDialogTitle,
                        content:
                            context.messages.agentControlsDeleteDialogContent,
                        confirmLabel:
                            context.messages.agentControlsDeleteButton,
                        onConfirmed: () async {
                          await ref
                              .read(agentServiceProvider)
                              .deleteAgent(widget.agentId);
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                      ),
              icon: Icon(
                Icons.delete_forever_rounded,
                color: context.colorScheme.error,
              ),
              label: Text(
                context.messages.agentControlsDeleteButton,
                style: TextStyle(color: context.colorScheme.error),
              ),
            ),
          ],
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
              onPressed: _busy ? null : () => _runAction(_pauseAgent),
              icon: const Icon(Icons.pause_rounded),
              label: Text(context.messages.agentControlsPauseButton),
            ),
          if (isDormant)
            FilledButton.tonalIcon(
              onPressed: _busy ? null : () => _runAction(_resumeAgent),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(context.messages.agentControlsResumeButton),
            ),
          if (isActive || isDormant)
            OutlinedButton.icon(
              onPressed: _busy ? null : _triggerReanalysis,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(context.messages.agentControlsReanalyzeButton),
            ),
          if (isActive || isDormant)
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () => _confirmAction(
                        context: context,
                        title: context.messages.agentControlsDestroyDialogTitle,
                        content:
                            context.messages.agentControlsDestroyDialogContent,
                        confirmLabel:
                            context.messages.agentControlsDestroyButton,
                        onConfirmed: () async {
                          await ref
                              .read(agentServiceProvider)
                              .destroyAgent(widget.agentId);
                          ref.invalidate(agentIdentityProvider(widget.agentId));
                        },
                      ),
              icon: Icon(
                Icons.delete_forever_rounded,
                color: context.colorScheme.error,
              ),
              label: Text(
                context.messages.agentControlsDestroyButton,
                style: TextStyle(color: context.colorScheme.error),
              ),
            ),
        ],
      ),
    );
  }

  /// Runs an async action with busy-state guard and error handling.
  Future<void> _runAction(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e, s) {
      developer.log(
        'AgentControls action failed',
        name: 'AgentControls',
        error: e,
        stackTrace: s,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.messages.agentControlsActionError(e.toString()),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pauseAgent() async {
    await ref.read(agentServiceProvider).pauseAgent(widget.agentId);
    ref.invalidate(agentIdentityProvider(widget.agentId));
  }

  Future<void> _resumeAgent() async {
    await ref.read(agentServiceProvider).resumeAgent(widget.agentId);
    await ref
        .read(taskAgentServiceProvider)
        .restoreSubscriptionsForAgent(widget.agentId);
    ref.invalidate(agentIdentityProvider(widget.agentId));
  }

  Future<void> _triggerReanalysis() async {
    await _runAction(() async {
      ref.read(taskAgentServiceProvider).triggerReanalysis(widget.agentId);
    });
  }

  /// Shows a confirmation dialog, then runs [onConfirmed] with busy-state
  /// guard and error handling.
  Future<void> _confirmAction({
    required BuildContext context,
    required String title,
    required String content,
    required String confirmLabel,
    required Future<void> Function() onConfirmed,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final l10n = dialogContext.messages;
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cancelButton),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: dialogContext.colorScheme.error,
              ),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );

    if (confirmed ?? false) {
      await _runAction(onConfirmed);
    }
  }
}
