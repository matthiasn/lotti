import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/journal/create/create_entry.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/task_search_picker_body.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/widgets/modal/confirmation_modal.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:material_ui/material_ui.dart';

/// What a person's page does with tasks (plan v2 phase 2 item 3 —
/// `RelationshipLink` both ways): pick one to link, or create one when the
/// search finds none, and unlink one — the jobs the person page's Tasks card
/// used to do, now reached from the bar's create menu and from a task's row
/// on the timeline (design panel 2026-10-15).
///
/// A task created here inherits the person's category and `private` flag.
class PersonTaskActions {
  const PersonTaskActions({
    required this.relationshipId,
    required this.linkedTaskIds,
    this.categoryId,
  });

  final String relationshipId;

  /// The tasks already linked, which the picker does not offer again.
  final Set<String> linkedTaskIds;

  /// The person's category, inherited by a task created from their picker so
  /// it lands in the same life area the person does.
  final String? categoryId;

  /// Links [taskId] to this person.
  ///
  /// Answers false for a write that changed no row *and* for one that threw:
  /// both mean the link the user asked for does not exist, and the caller —
  /// which knows whether there is still a page to say so on — decides how to
  /// report it. A throw is reported to [logger].
  Future<bool> _linkTask(
    RelationshipRepository repository,
    DomainLogger logger,
    String taskId,
  ) async {
    try {
      return await repository.linkTask(
        relationshipId: relationshipId,
        taskId: taskId,
      );
    } catch (error, stackTrace) {
      logger.error(
        LogDomain.general,
        error,
        stackTrace: stackTrace,
        subDomain: 'PersonTaskActions',
        message: 'Failed to link task to relationship',
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
  /// the one path [pickTask] already owns, error toast and all. The one
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
    final logger = ref.read(domainLoggerProvider);

    Task? created;
    try {
      created = await createTask(
        domainLogger: logger,
        title: title,
        categoryId: categoryId,
        inheritContextFrom: relationshipId,
      );
    } catch (error, stackTrace) {
      logger.error(
        LogDomain.general,
        error,
        stackTrace: stackTrace,
        subDomain: 'PersonTaskActions',
        message: 'Failed to create a task for the relationship',
      );
    }
    // Nothing was written. The picker stays open on the query that failed,
    // which says more than a toast would: a snack bar raised from here is
    // hosted by the page's messenger and renders *behind* the modal route it
    // would be explaining.
    if (created == null) return null;

    // The same follow-up every other create flow performs, so a task created
    // here is not the one left without its category's agent.
    unawaited(
      autoAssignCategoryAgentWith(agentService, created, domainLogger: logger),
    );

    if (modalContext.mounted) return created;

    // Dismissed while the write was in flight. The task exists and the user
    // asked for it to be linked, so handing back null here would leave it
    // created, unlinked and unannounced — visible only as a stray row in the
    // task list. Link it on the dependencies captured before the gap.
    final linked = await _linkTask(repository, logger, created.meta.id);
    if (!linked && pageContext.mounted) {
      pageContext.showToast(
        tone: DesignSystemToastTone.error,
        title: pageContext.messages.relationshipErrorLinkTaskFailed,
      );
    }
    return null;
  }

  /// Opens the task picker: link an existing task, or create one titled
  /// after the search when none matches.
  Future<void> pickTask(BuildContext context, WidgetRef ref) async {
    final repository = ref.read(relationshipRepositoryProvider);
    final logger = ref.read(domainLoggerProvider);

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
              excludeIds: {relationshipId, ...linkedTaskIds},
              onCreateTask: (title) => _createTask(
                pageContext: context,
                modalContext: modalContext,
                ref: ref,
                title: title,
              ),
              onTaskSelected: (task) async {
                final linked = await _linkTask(
                  repository,
                  logger,
                  task.meta.id,
                );
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

  /// Unlinks [task] from the person after asking, leaving the task itself.
  Future<void> unlinkTask(
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

    final logger = ref.read(domainLoggerProvider);
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
      logger.error(
        LogDomain.general,
        error,
        stackTrace: stackTrace,
        subDomain: 'PersonTaskActions',
        message: 'Failed to unlink task from relationship',
      );
      if (context.mounted) {
        context.showToast(
          tone: DesignSystemToastTone.error,
          title: context.messages.unlinkTaskFailedMessage,
        );
      }
    }
  }
}
