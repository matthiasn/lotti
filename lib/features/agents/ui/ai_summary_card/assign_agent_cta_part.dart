import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/event_agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/agents/ui/agent_creation_modal.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:material_ui/material_ui.dart';

/// CTA shown where an agent's card would be when no agent is attached yet —
/// on a task's details page ([AssignAgentCta.new]) and on an event's
/// ([AssignAgentCta.event]). Tapping it opens the template-and-profile picker
/// and creates the agent on confirmation; the flow is [_assignAgent] below.
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
/// Events use the same row so an event created before its category had a
/// default event agent — or in a category without one — can still be given an
/// agent, the same way a task can.
class AssignAgentCta extends ConsumerWidget {
  /// The offer on a task's page: creates a task agent for [subjectId].
  const AssignAgentCta({required String taskId, super.key})
    : subjectId = taskId,
      kind = AgentTemplateKind.taskAgent;

  /// The offer on an event's page: creates an event agent for [subjectId].
  const AssignAgentCta.event({required String eventId, super.key})
    : subjectId = eventId,
      kind = AgentTemplateKind.eventAgent;

  /// The task or event the agent is created for.
  final String subjectId;

  /// Which kind of agent the row offers — [AgentTemplateKind.taskAgent] or
  /// [AgentTemplateKind.eventAgent].
  final AgentTemplateKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final radius = BorderRadius.circular(tokens.radii.l);
    final isEvent = kind == AgentTemplateKind.eventAgent;
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
          onTap: () => isEvent
              ? showAssignEventAgentPicker(context, ref, subjectId)
              : showAssignTaskAgentPicker(context, ref, subjectId),
          title: context.messages.taskAgentCreateChipLabel,
          titleMaxLines: 2,
          subtitle: isEvent
              ? context.messages.eventAgentAssignHint
              : context.messages.taskAgentAssignHint,
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

/// Opens the assign-agent picker for [taskId] and creates a task agent on
/// confirmation. Public so the task page's first-run block can offer the same
/// action inline without duplicating the flow.
Future<void> showAssignTaskAgentPicker(
  BuildContext context,
  WidgetRef ref,
  String taskId,
) => _assignAgent(
  context,
  ref,
  subjectId: taskId,
  kind: AgentTemplateKind.taskAgent,
  isSubject: (entity) => entity is Task,
  create: (result, allowedCategoryIds) => ref
      .read(taskAgentServiceProvider)
      .createTaskAgent(
        taskId: taskId,
        templateId: result.templateId,
        profileId: result.profileId,
        setupOrigin: AgentInferenceSetupOrigin.user,
        allowedCategoryIds: allowedCategoryIds,
      ),
  onCreated: () => ref.invalidate(taskAgentProvider(taskId)),
);

/// Opens the assign-agent picker for [eventId] and creates an event agent on
/// confirmation.
///
/// The agent is created behind the same content gate the category default
/// uses: its creation wake runs at once when the event already has a photo or
/// note, and waits for the first one when it has neither.
Future<void> showAssignEventAgentPicker(
  BuildContext context,
  WidgetRef ref,
  String eventId,
) => _assignAgent(
  context,
  ref,
  subjectId: eventId,
  kind: AgentTemplateKind.eventAgent,
  isSubject: (entity) => entity is JournalEvent,
  create: (result, allowedCategoryIds) => ref
      .read(eventAgentServiceProvider)
      .createEventAgent(
        eventId: eventId,
        templateId: result.templateId,
        profileId: result.profileId,
        allowedCategoryIds: allowedCategoryIds,
      ),
  onCreated: () => ref.invalidate(eventAgentProvider(eventId)),
);

/// Resolves [subjectId]'s category, lists the [kind] templates that can be
/// assigned (see [assignableAgentTemplates]), shows the picker, and runs
/// [create] on confirmation, then [onCreated] so the card rebuilds with the
/// freshly attached agent.
///
/// Returns without doing anything when the entry does not satisfy
/// [isSubject]. Surfaces a warning toast when no templates are available, and
/// an error toast on any underlying service exception.
Future<void> _assignAgent(
  BuildContext context,
  WidgetRef ref, {
  required String subjectId,
  required AgentTemplateKind kind,
  required bool Function(JournalEntity? entity) isSubject,
  required Future<Object?> Function(
    AgentCreationResult result,
    Set<String> allowedCategoryIds,
  )
  create,
  required VoidCallback onCreated,
}) async {
  final entity = await ref.read(journalDbProvider).journalEntityById(subjectId);
  if (entity == null || !isSubject(entity)) return;

  final categoryId = entity.meta.categoryId;
  final allowedCategoryIds = categoryId != null ? {categoryId} : <String>{};

  final logger = ref.read(domainLoggerProvider);
  try {
    final templates = await assignableAgentTemplates(
      ref.read(agentTemplateServiceProvider),
      kind: kind,
      categoryId: categoryId,
    );

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

    await create(result, allowedCategoryIds);
    if (context.mounted) onCreated();
  } catch (e, s) {
    logger.error(
      LogDomain.agentWorkflow,
      e,
      stackTrace: s,
      subDomain: 'AssignAgentCta',
      message: 'Failed to create ${kind.name}',
    );
    if (context.mounted) {
      context.showToast(
        tone: DesignSystemToastTone.error,
        title: context.messages.taskAgentCreateError(e.toString()),
      );
    }
  }
}

/// The [kind] templates offered when assigning an agent by hand: those scoped
/// to [categoryId] when there are any, otherwise every [kind] template.
///
/// The kind filter applies before the fallback, so a category whose scoped
/// templates are all of another kind still offers the global ones rather than
/// an empty picker.
@visibleForTesting
Future<List<AgentTemplateEntity>> assignableAgentTemplates(
  AgentTemplateService templateService, {
  required AgentTemplateKind kind,
  required String? categoryId,
}) async {
  List<AgentTemplateEntity> ofKind(List<AgentTemplateEntity> templates) =>
      templates.where((t) => t.kind == kind).toList();

  if (categoryId != null) {
    final scoped = ofKind(
      await templateService.listTemplatesForCategory(categoryId),
    );
    if (scoped.isNotEmpty) return scoped;
  }
  return ofKind(await templateService.listTemplates());
}
