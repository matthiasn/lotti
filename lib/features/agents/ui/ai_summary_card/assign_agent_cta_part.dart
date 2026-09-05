import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/agents/ui/agent_creation_modal.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// CTA shown on the task details page when no agent is yet attached to the
/// task. Tapping it opens the same template-picker modal that
/// `TaskAgentReportSection` used to surface; the actual flow is in
/// [_createTaskAgent] below.
///
/// Shaped as a bordered card row rather than the centred text button it used
/// to be. On a task with content the button was a small accent island the eye
/// skipped; on an *empty* task it was a lone tinted label floating in the
/// middle of a blank column, reading as leftover chrome rather than an offer.
/// The card borrows the linked-tasks card's grammar — leading glyph in the
/// feature's accent, worded title, quiet explanatory subtitle, trailing
/// chevron — so the empty task reads as a short stack of deliberate offers in
/// one language instead of a mix of cards and stray links.
///
/// The subtitle names the *other* way to get an agent: a category with a
/// default agent assigns one to every task it creates, so the user who does
/// not want to answer this question per task learns where to answer it once.
class AssignAgentCta extends ConsumerWidget {
  const AssignAgentCta({required this.taskId, super.key});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final radius = BorderRadius.circular(tokens.radii.l);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        borderRadius: radius,
        border: Border.all(color: tokens.colors.decorative.level01),
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: DesignSystemListItem(
          onTap: () => _createTaskAgent(context, ref, taskId),
          title: context.messages.taskAgentCreateChipLabel,
          titleMaxLines: 2,
          subtitle: context.messages.taskAgentAssignHint,
          subtitleMaxLines: 2,
          subtitleEmphasis: tokens.colors.text.lowEmphasis,
          size: DesignSystemListItemSize.small,
          leading: Icon(
            LottiIcons.aiSpark,
            size: tokens.spacing.step5,
            // The AI accent, not the generic interactive one: this row is the
            // entry point to the agent feature, and it is the only place on an
            // empty task where that palette appears.
            color: tokens.colors.aiCard.accent,
          ),
          trailingExtra: Icon(
            LottiIcons.chevronRight,
            size: tokens.spacing.step4,
            color: tokens.colors.text.lowEmphasis,
          ),
        ),
      ),
    );
  }
}

/// Opens the assign-agent picker for [taskId] and creates the agent on
/// confirmation. Public so the task page's first-run block can offer the same
/// action inline without duplicating the flow.
Future<void> showAssignTaskAgentPicker(
  BuildContext context,
  WidgetRef ref,
  String taskId,
) => _createTaskAgent(context, ref, taskId);

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
    entryControllerProvider(taskId).future,
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
      setupOrigin: AgentInferenceSetupOrigin.user,
      allowedCategoryIds: allowedCategoryIds,
    );
    if (context.mounted) {
      ref.invalidate(taskAgentProvider(taskId));
    }
  } catch (e, s) {
    developer.log(
      'Failed to create task agent',
      name: 'AiSummaryCard',
      error: e.runtimeType,
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
