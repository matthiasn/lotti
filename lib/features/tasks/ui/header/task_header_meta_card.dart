import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/agents/ui/agent_detail_page.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/tasks/ui/header/task_category_wrapper.dart';
import 'package:lotti/features/tasks/ui/header/task_creation_date_widget.dart';
import 'package:lotti/features/tasks/ui/header/task_due_date_wrapper.dart';
import 'package:lotti/features/tasks/ui/header/task_language_wrapper.dart';
import 'package:lotti/features/tasks/ui/header/task_priority_wrapper.dart';
import 'package:lotti/features/tasks/ui/header/task_status_wrapper.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/consts.dart';

class TaskHeaderMetaCard extends StatelessWidget {
  const TaskHeaderMetaCard({
    required this.taskId,
    super.key,
  });

  final String taskId;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Row 1: Primary Status (High Visibility Chips)
        _TaskMetadataRow(taskId: taskId),
        const SizedBox(height: AppTheme.spacingMedium),
        // Row 2: Dates (Subtle Action Chips)
        Row(
          spacing: AppTheme.spacingSmall,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TaskCreationDateWidget(taskId: taskId),
            TaskDueDateWrapper(taskId: taskId),
          ],
        ),
      ],
    );
  }
}

class _TaskMetadataRow extends StatelessWidget {
  const _TaskMetadataRow({
    required this.taskId,
  });

  final String taskId;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: AppTheme.cardSpacing,
            runSpacing: AppTheme.cardSpacing / 2,
            children: [
              TaskPriorityWrapper(
                taskId: taskId,
                showLabel: false,
              ),
              TaskStatusWrapper(
                taskId: taskId,
                showLabel: false,
              ),
              TaskCategoryWrapper(taskId: taskId),
              TaskLanguageWrapper(taskId: taskId),
            ],
          ),
        ),
        _TaskAgentChip(taskId: taskId),
      ],
    );
  }
}

/// Chip that either creates a task agent or navigates to the existing agent's
/// detail page, depending on whether an agent already exists for this task.
///
/// Shows a countdown timer when the agent is in its throttle cooldown window
/// and a "Run Now" button to bypass the throttle.
///
/// Only visible when the `enableAgents` config flag is on.
class _TaskAgentChip extends ConsumerStatefulWidget {
  const _TaskAgentChip({required this.taskId});

  final String taskId;

  @override
  ConsumerState<_TaskAgentChip> createState() => _TaskAgentChipState();
}

class _TaskAgentChipState extends ConsumerState<_TaskAgentChip> {
  Timer? _countdownTimer;
  int _countdownSeconds = 0;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown(int seconds) {
    _countdownTimer?.cancel();
    _countdownSeconds = seconds;
    if (seconds <= 0) return;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _countdownSeconds--;
        if (_countdownSeconds <= 0) {
          _countdownTimer?.cancel();
          _countdownTimer = null;
        }
      });
    });
  }

  void _stopCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _countdownSeconds = 0;
  }

  @override
  Widget build(BuildContext context) {
    final enableAgents =
        ref.watch(configFlagProvider(enableAgentsFlag)).value ?? false;

    if (!enableAgents) {
      return const SizedBox.shrink();
    }

    final taskAgentAsync = ref.watch(taskAgentProvider(widget.taskId));

    return taskAgentAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (agentEntity) {
        if (agentEntity != null) {
          final identity = agentEntity.mapOrNull(agent: (e) => e);
          if (identity == null) return const SizedBox.shrink();
          return _buildAgentChip(context, identity);
        }

        // No agent yet — show create button.
        return ActionChip(
          avatar: Icon(
            Icons.add,
            size: 16,
            color: context.colorScheme.onSurfaceVariant,
          ),
          label: Text(context.messages.taskAgentCreateChipLabel),
          onPressed: () => _createTaskAgent(context, ref),
        );
      },
    );
  }

  Widget _buildAgentChip(BuildContext context, AgentIdentityEntity identity) {
    final agentId = identity.agentId;
    final isRunning = ref.watch(agentIsRunningProvider(agentId)).value ?? false;
    final agentStateAsync = ref.watch(agentStateProvider(agentId));
    final lastWakeAt = agentStateAsync.value?.mapOrNull(
      agentState: (s) => s.lastWakeAt,
    );

    // Compute countdown from lastWakeAt.
    final remainingSeconds = _computeRemainingSeconds(lastWakeAt);

    // Restart countdown timer when lastWakeAt changes.
    ref.listen(agentStateProvider(agentId), (prev, next) {
      final newLastWake = next.value?.mapOrNull(
        agentState: (s) => s.lastWakeAt,
      );
      final newRemaining = _computeRemainingSeconds(newLastWake);
      if (newRemaining > 0) {
        _startCountdown(newRemaining);
      } else {
        _stopCountdown();
      }
    });

    // Seed the timer on first build if a countdown is active.
    if (isRunning) {
      _stopCountdown();
    } else if (_countdownTimer == null && remainingSeconds > 0) {
      // Use addPostFrameCallback to avoid calling setState during build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startCountdown(remainingSeconds);
      });
    }

    final showCountdown = !isRunning && _countdownSeconds > 0;
    final countdownText =
        showCountdown ? _formatCountdown(_countdownSeconds) : null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isRunning)
          IconButton(
            icon: Icon(
              Icons.play_arrow_rounded,
              size: 20,
              color: context.colorScheme.primary,
            ),
            tooltip: context.messages.taskAgentRunNowTooltip,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () {
              ref.read(taskAgentServiceProvider).triggerReanalysis(agentId);
            },
          ),
        ActionChip(
          avatar: isRunning
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: context.colorScheme.primary,
                  ),
                )
              : Icon(
                  Icons.smart_toy_outlined,
                  size: 16,
                  color: context.colorScheme.primary,
                ),
          label: Text(
            countdownText != null
                ? '${context.messages.taskAgentChipLabel} $countdownText'
                : context.messages.taskAgentChipLabel,
            style: countdownText != null
                ? const TextStyle(
                    fontFeatures: [FontFeature.tabularFigures()],
                  )
                : null,
          ),
          tooltip: isRunning
              ? context.messages.agentRunningIndicator
              : showCountdown
                  ? context.messages
                      .taskAgentCountdownTooltip(countdownText ?? '')
                  : null,
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => AgentDetailPage(agentId: agentId),
              ),
            );
          },
        ),
      ],
    );
  }

  int _computeRemainingSeconds(DateTime? lastWakeAt) {
    if (lastWakeAt == null) return 0;
    final deadline = lastWakeAt.add(WakeOrchestrator.throttleWindow);
    final remaining = deadline.difference(DateTime.now());
    return remaining.inSeconds
        .clamp(0, WakeOrchestrator.throttleWindow.inSeconds);
  }

  Future<void> _createTaskAgent(BuildContext context, WidgetRef ref) async {
    final entryState =
        ref.read(entryControllerProvider(id: widget.taskId)).value?.entry;
    if (entryState == null || entryState is! Task) return;

    final categoryId = entryState.meta.categoryId;
    final allowedCategoryIds = categoryId != null ? {categoryId} : <String>{};

    try {
      final service = ref.read(taskAgentServiceProvider);
      final templateService = ref.read(agentTemplateServiceProvider);

      // Try category-specific templates first, then all templates.
      var templates = categoryId != null
          ? await templateService.listTemplatesForCategory(categoryId)
          : <AgentTemplateEntity>[];
      if (templates.isEmpty) {
        templates = await templateService.listTemplates();
      }

      if (templates.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.messages.agentTemplateNoTemplates),
          ),
        );
        return;
      }

      // Single template → auto-assign. Multiple → show selection sheet.
      AgentTemplateEntity? selectedTemplate;
      if (templates.length == 1) {
        selectedTemplate = templates.first;
      } else {
        if (!context.mounted) return;
        selectedTemplate =
            await _showTemplateSelectionSheet(context, templates);
      }

      if (selectedTemplate == null) return;

      await service.createTaskAgent(
        taskId: widget.taskId,
        templateId: selectedTemplate.id,
        allowedCategoryIds: allowedCategoryIds,
      );
      // Invalidate the provider so the UI rebuilds with the new agent.
      if (context.mounted) {
        ref.invalidate(taskAgentProvider(widget.taskId));
      }
    } catch (e, s) {
      developer.log(
        'Failed to create task agent',
        name: '_TaskAgentChip',
        error: e,
        stackTrace: s,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.messages.taskAgentCreateError(e.toString()),
            ),
          ),
        );
      }
    }
  }

  Future<AgentTemplateEntity?> _showTemplateSelectionSheet(
    BuildContext context,
    List<AgentTemplateEntity> templates,
  ) async {
    return showModalBottomSheet<AgentTemplateEntity>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    sheetContext.messages.agentTemplateSelectTitle,
                    style: Theme.of(sheetContext).textTheme.titleMedium,
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: templates
                        .map(
                          (template) => ListTile(
                            leading: Icon(
                              Icons.smart_toy_outlined,
                              color: Theme.of(sheetContext).colorScheme.primary,
                            ),
                            title: Text(template.displayName),
                            subtitle: Text(template.modelId),
                            onTap: () =>
                                Navigator.of(sheetContext).pop(template),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Formats a countdown as `m:ss` for display.
String _formatCountdown(int totalSeconds) {
  final m = totalSeconds ~/ 60;
  final s = totalSeconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}
