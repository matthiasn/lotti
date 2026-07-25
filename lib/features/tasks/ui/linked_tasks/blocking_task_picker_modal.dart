import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/tasks/state/task_link_groups_controller.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/link_created_feedback.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/relationship_type_selector.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/task_relationship_sections.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/task_search_picker_body.dart';
import 'package:lotti/features/tasks/ui/utils.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_palette.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

/// Optional prompt shown right after a task's status is set to Blocked, to
/// name what's blocking it. Unlike `LinkTaskModal`, the relationship here is
/// fixed to `blocks` with a fixed direction (the picked task is always the
/// blocker) — no relationship-type selector.
///
/// Skippable with zero required interaction: the status write already
/// completed independently before this modal opens (see
/// `DesktopTaskHeaderConnector._showStatusPicker`), so dismissing this modal
/// via the standard close button persists nothing further.
class BlockingTaskPickerModal extends ConsumerWidget {
  const BlockingTaskPickerModal({required this.blockedTaskId, super.key});

  /// The task that just became Blocked — the new link's `toId`.
  final String blockedTaskId;

  /// Shows the modal. Returns the selected blocker task, or null if the user
  /// dismissed it.
  static Future<Task?> show({
    required BuildContext context,
    required String blockedTaskId,
  }) {
    return ModalUtils.showSinglePageModal<Task>(
      context: context,
      title: context.messages.taskBlockerPickerTitle,
      padding: EdgeInsets.zero,
      builder: (_) => BlockingTaskPickerModal(blockedTaskId: blockedTaskId),
    );
  }

  Future<void> _selectBlocker(
    BuildContext context,
    WidgetRef ref,
    Task blocker,
  ) async {
    // Captured before the pop below, which disposes this modal's context.
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(journalRepositoryProvider);

    final created = await getIt<PersistenceLogic>().createLink(
      fromId: blocker.meta.id,
      toId: blockedTaskId,
      linkType: EntryLinkType.blocks,
    );

    if (!created) {
      if (context.mounted) {
        showLinkFailureMessage(
          messenger: messenger,
          message: context.messages.linkBlocksCycleErrorMessage,
        );
      }
      return;
    }

    await HapticFeedback.mediumImpact();

    if (context.mounted) {
      showLinkCreatedFeedback(
        context: context,
        messenger: messenger,
        repository: repository,
        // The picked task blocks the anchor, so from the anchor's side this
        // is the inverse phrasing — the same words the card will show.
        relation: const DirectedRelation(
          EntryLinkType.blocks,
          inverse: true,
        ),
        fromId: blocker.meta.id,
        toId: blockedTaskId,
        linkedTaskTitle: blocker.data.title,
      );
      Navigator.of(context).pop(blocker);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final existingBlockerIds =
        ref
            .watch(taskLinkGroupsControllerProvider(blockedTaskId))
            .value
            ?.typed
            .where(
              (entry) =>
                  entry.kind == TaskLinkKind.blocks &&
                  entry.direction == TaskLinkDirection.incoming,
            )
            .map((entry) => entry.task.meta.id)
            .toSet() ??
        const <String>{};

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The blocked semantic gets its mark in the body, not the title bar.
        // In the bar it competed with the title for a width the close button
        // dictates, and clipped "What's blocking this?" mid-word on phone —
        // in English, before any longer locale. Here it also names the
        // relation the pick will write, in the same words the card reads back.
        LinkedTaskSectionHeader(
          title: context.messages.linkPhraseBlocksInverse,
          accent: TaskShowcasePalette.warning(context),
          tightTop: true,
          // The picker's rows reserve a wider leading rail than the card's, so
          // without this the header sits 25pt left of the rows it labels — the
          // one visibly broken rail in the flow.
          leadingRailWidth: context.designTokens.spacing.step8,
        ),
        Flexible(
          child: TaskSearchPickerBody(
            // A finished task cannot block anything, so this picker keeps the
            // open-only filter the shared body no longer applies by default.
            taskStatuses: openTaskStatuses,
            excludeIds: {blockedTaskId, ...existingBlockerIds},
            onTaskSelected: (task) => _selectBlocker(context, ref, task),
          ),
        ),
      ],
    );
  }
}
