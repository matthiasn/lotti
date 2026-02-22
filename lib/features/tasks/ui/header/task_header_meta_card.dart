import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/agents/ui/agent_detail_page.dart';
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
/// Only visible when the `enableAgents` config flag is on.
class _TaskAgentChip extends ConsumerWidget {
  const _TaskAgentChip({required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enableAgents =
        ref.watch(configFlagProvider(enableAgentsFlag)).value ?? false;

    if (!enableAgents) {
      return const SizedBox.shrink();
    }

    final taskAgentAsync = ref.watch(taskAgentProvider(taskId));

    return taskAgentAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (agentEntity) {
        if (agentEntity != null) {
          // Agent exists — show navigation chip.
          final identity = agentEntity.mapOrNull(agent: (e) => e);
          if (identity == null) return const SizedBox.shrink();

          final isRunning =
              ref.watch(agentIsRunningProvider(identity.agentId)).value ??
                  false;

          return ActionChip(
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
            label: Text(context.messages.taskAgentChipLabel),
            tooltip: isRunning ? context.messages.agentRunningIndicator : null,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AgentDetailPage(agentId: identity.agentId),
                ),
              );
            },
          );
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

  Future<void> _createTaskAgent(BuildContext context, WidgetRef ref) async {
    final entryState =
        ref.read(entryControllerProvider(id: taskId)).value?.entry;
    if (entryState == null || entryState is! Task) return;

    final categoryId = entryState.meta.categoryId;
    final allowedCategoryIds = categoryId != null ? {categoryId} : <String>{};

    try {
      final service = ref.read(taskAgentServiceProvider);
      await service.createTaskAgent(
        taskId: taskId,
        allowedCategoryIds: allowedCategoryIds,
      );
      // Invalidate the provider so the UI rebuilds with the new agent.
      if (context.mounted) {
        ref.invalidate(taskAgentProvider(taskId));
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
}
