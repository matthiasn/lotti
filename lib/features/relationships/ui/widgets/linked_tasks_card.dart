import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_inline_action.dart';
import 'package:lotti/features/design_system/components/cards/design_system_section_card.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/state/relationship_proposal_providers.dart';
import 'package:lotti/features/relationships/ui/widgets/person_page_cards.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/linked_task_row.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/task_search_picker_body.dart';
import 'package:lotti/features/tasks/ui/utils.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/create/create_entry.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/modal/confirmation_modal.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:material_ui/material_ui.dart';

/// Tasks linked to this person (plan v2 phase 2 item 3 — `RelationshipLink`
/// both ways), as one section card: a count beside the title, *Link task*
/// in the header, one row per task with the task's status glyph and an
/// unlink action, and the empty hint otherwise.
///
/// The picker also creates the task when none exists yet, and a task created
/// here inherits the person's category and `private` flag.
class LinkedTasksCard extends ConsumerWidget {
  const LinkedTasksCard({
    required this.relationshipId,
    required this.tasks,
    this.categoryId,
    super.key,
  });

  final String relationshipId;
  final List<Task> tasks;

  /// The person's category, inherited by a task created from their picker so
  /// it lands in the same life area the person does.
  final String? categoryId;

  /// Links [taskId] to this person.
  ///
  /// Answers false for a write that changed no row *and* for one that threw:
  /// both mean the link the user asked for does not exist, and the caller —
  /// which knows whether there is still a page to say so on — decides how to
  /// report it.
  Future<bool> _linkTask(
    RelationshipRepository repository,
    String taskId,
  ) async {
    try {
      return await repository.linkTask(
        relationshipId: relationshipId,
        taskId: taskId,
      );
    } catch (error, stackTrace) {
      developer.log(
        'Failed to link task to relationship',
        name: 'LinkedTasksCard',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Creates a task titled after the picker's query, for the person whose
  /// page this is.
  ///
  /// Answering "there is no such task yet" without leaving the page: the
  /// picker offers this on a search that matches nothing, and feeds whatever
  /// comes back through its own pick callback — so creating and linking stay
  /// the one path [_pickTask] already owns, error toast and all. The one
  /// case that path cannot serve is a picker dismissed mid-write, handled
  /// below.
  ///
  /// No `linkedId`: that writes a plain link, and this card writes its own
  /// relationship-typed edge a moment later. `inheritContextFrom` carries the
  /// one thing that must travel — a private person's task is private too —
  /// without leaving a second edge to unpick.
  Future<Task?> _createTask({
    required BuildContext pageContext,
    required BuildContext modalContext,
    required WidgetRef ref,
    required String title,
  }) async {
    // Read before the await: persistence can outlive the sheet, and a
    // post-gap read on a disposed ref would strand a task already written.
    final agentService = ref.read(taskAgentServiceProvider);
    final repository = ref.read(relationshipRepositoryProvider);

    Task? created;
    try {
      created = await createTask(
        title: title,
        categoryId: categoryId,
        inheritContextFrom: relationshipId,
      );
    } catch (error, stackTrace) {
      developer.log(
        'Failed to create a task for the relationship',
        name: 'LinkedTasksCard',
        error: error,
        stackTrace: stackTrace,
      );
    }
    // Nothing was written. The picker stays open on the query that failed,
    // which says more than a toast would: a snack bar raised from here is
    // hosted by the page's messenger and renders *behind* the modal route it
    // would be explaining.
    if (created == null) return null;

    // The same follow-up every other create flow performs, so a task created
    // here is not the one left without its category's agent.
    unawaited(autoAssignCategoryAgentWith(agentService, created));

    if (modalContext.mounted) return created;

    // Dismissed while the write was in flight. The task exists and the user
    // asked for it to be linked, so handing back null here would leave it
    // created, unlinked and unannounced — visible only as a stray row in the
    // task list. Link it on the dependencies captured before the gap.
    final linked = await _linkTask(repository, created.meta.id);
    if (!linked && pageContext.mounted) {
      pageContext.showToast(
        tone: DesignSystemToastTone.error,
        title: pageContext.messages.relationshipErrorLinkTaskFailed,
      );
    }
    return null;
  }

  Future<void> _pickTask(BuildContext context, WidgetRef ref) async {
    final repository = ref.read(relationshipRepositoryProvider);
    final linkedIds = {for (final task in tasks) task.meta.id};

    await ModalUtils.showSinglePageModal<void>(
      context: context,
      title: context.messages.relationshipLinkTaskButton,
      padding: EdgeInsets.zero,
      builder: (modalContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: TaskSearchPickerBody(
              excludeIds: {relationshipId, ...linkedIds},
              onCreateTask: (title) => _createTask(
                pageContext: context,
                modalContext: modalContext,
                ref: ref,
                title: title,
              ),
              onTaskSelected: (task) async {
                final linked = await _linkTask(repository, task.meta.id);
                if (!modalContext.mounted) return;
                Navigator.of(modalContext).pop();
                // `createLink` answers false when the upsert changed no row,
                // so a silent close would read as a link that worked.
                if (!linked && context.mounted) {
                  context.showToast(
                    tone: DesignSystemToastTone.error,
                    title: context.messages.relationshipErrorLinkTaskFailed,
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _unlinkTask(
    BuildContext context,
    WidgetRef ref,
    Task task,
  ) async {
    final confirmed = await showConfirmationModal(
      context: context,
      message: context.messages.unlinkTaskConfirmNamed(
        task.data.title.isEmpty
            ? context.messages.taskUntitled
            : task.data.title,
      ),
      confirmLabel: context.messages.unlinkTaskTitle,
    );
    if (!confirmed || !context.mounted) return;

    try {
      final removed = await ref
          .read(relationshipRepositoryProvider)
          .unlinkTask(relationshipId: relationshipId, taskId: task.meta.id);
      if (!removed && context.mounted) {
        context.showToast(
          tone: DesignSystemToastTone.error,
          title: context.messages.unlinkTaskFailedMessage,
        );
      }
    } catch (error, stackTrace) {
      developer.log(
        'Failed to unlink task from relationship',
        name: 'LinkedTasksCard',
        error: error,
        stackTrace: stackTrace,
      );
      if (context.mounted) {
        context.showToast(
          tone: DesignSystemToastTone.error,
          title: context.messages.unlinkTaskFailedMessage,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final highlightedTasks = ref.watch(relationshipTaskHighlightProvider);
    final tokens = context.designTokens;
    final messages = context.messages;

    return DesignSystemSectionCard(
      key: const ValueKey('person-tasks-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PersonCardHeader(
            title: messages.relationshipLinkedTasksLabel,
            caption: tasks.isEmpty
                ? null
                : DsPill(
                    variant: DsPillVariant.filled,
                    shape: DsPillShape.tag,
                    labelColor: tokens.colors.text.mediumEmphasis,
                    label: messages.relationshipTasksLinkedCount(tasks.length),
                  ),
            trailing: DesignSystemInlineAction(
              key: const ValueKey('person-link-task'),
              label: messages.relationshipLinkTaskButton,
              semanticsLabel: messages.relationshipLinkTaskButton,
              leadingIcon: LottiIcons.link,
              onTap: () => _pickTask(context, ref),
            ),
          ),
          SizedBox(height: tokens.spacing.step3),
          if (tasks.isEmpty)
            Text(
              messages.relationshipNoLinkedTasks,
              style: tokens.typography.styles.body.bodyMedium.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
            )
          else
            for (final task in tasks)
              DesignSystemListItem(
                key: ValueKey('person-task-${task.meta.id}'),
                activated: highlightedTasks.contains(task.id),
                size: DesignSystemListItemSize.small,
                title: task.data.title.isEmpty
                    ? messages.taskUntitled
                    : task.data.title,
                subtitle: taskLabelFromStatusString(
                  task.data.status.toDbString,
                  context,
                ),
                subtitleEmphasis: tokens.colors.text.lowEmphasis,
                leading: StatusGlyph(
                  status: task.data.status,
                  tooltip: taskLabelFromStatusString(
                    task.data.status.toDbString,
                    context,
                  ),
                ),
                trailingExtra: IconButton(
                  tooltip: messages.unlinkTaskTitle,
                  onPressed: () => _unlinkTask(context, ref, task),
                  icon: Icon(
                    LottiIcons.linkOff,
                    size: IconSizes.m,
                    color: tokens.colors.text.lowEmphasis,
                  ),
                ),
                onTap: () => beamToNamed('/tasks/${task.meta.id}'),
              ),
        ],
      ),
    );
  }
}
