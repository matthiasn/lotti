part of '../ai_summary_card.dart';

/// Compact CTA shown on the task details page when no agent is yet
/// attached to the task. Tapping it opens the same template-picker
/// modal that `TaskAgentReportSection` used to surface; the actual
/// flow is in [_createTaskAgent] below.
class _AssignAgentCta extends ConsumerWidget {
  const _AssignAgentCta({required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ai = context.designTokens.colors.aiCard;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Center(
        child: TextButton.icon(
          onPressed: () => _createTaskAgent(context, ref, taskId),
          icon: Icon(Icons.auto_awesome_rounded, size: 18, color: ai.accent),
          label: Text(context.messages.taskAgentCreateChipLabel),
          style: TextButton.styleFrom(foregroundColor: ai.accent),
        ),
      ),
    );
  }
}

/// Resolves the task's category, lists task-agent templates (preferring
/// category-scoped ones), shows the picker, and creates the agent on
/// confirmation. On success invalidates `taskAgentProvider` so the card
/// rebuilds with the freshly-attached agent. Surfaces a warning toast
/// when no templates are available, and an error toast on any
/// underlying service exception.
Future<void> _createTaskAgent(
  BuildContext context,
  WidgetRef ref,
  String taskId,
) async {
  final entryStateResult = await ref.read(
    entryControllerProvider(id: taskId).future,
  );
  final entryState = entryStateResult?.entry;
  if (entryState == null || entryState is! Task) return;

  final categoryId = entryState.meta.categoryId;
  final allowedCategoryIds = categoryId != null ? {categoryId} : <String>{};

  try {
    final service = ref.read(taskAgentServiceProvider);
    final templateService = ref.read(agentTemplateServiceProvider);

    var templates = categoryId != null
        ? await templateService.listTemplatesForCategory(categoryId)
        : <AgentTemplateEntity>[];
    if (templates.isEmpty) {
      templates = await templateService.listTemplates();
    }
    templates = templates
        .where((t) => t.kind == AgentTemplateKind.taskAgent)
        .toList();

    if (templates.isEmpty) {
      if (!context.mounted) return;
      context.showToast(
        tone: DesignSystemToastTone.warning,
        title: context.messages.agentTemplateNoTemplates,
      );
      return;
    }

    if (!context.mounted) return;

    final result = await AgentCreationModal.show(
      context: context,
      templates: templates,
    );

    if (result == null) return;

    await service.createTaskAgent(
      taskId: taskId,
      templateId: result.templateId,
      profileId: result.profileId,
      allowedCategoryIds: allowedCategoryIds,
    );
    if (context.mounted) {
      ref.invalidate(taskAgentProvider(taskId));
    }
  } catch (e, s) {
    developer.log(
      'Failed to create task agent',
      name: 'AiSummaryCard',
      error: e,
      stackTrace: s,
    );
    if (context.mounted) {
      context.showToast(
        tone: DesignSystemToastTone.error,
        title: context.messages.taskAgentCreateError(e.toString()),
      );
    }
  }
}
