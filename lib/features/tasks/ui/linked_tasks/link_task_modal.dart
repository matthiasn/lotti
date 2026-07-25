import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/link_created_feedback.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/relationship_type_selector.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/task_search_picker_body.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

/// Modal for searching and selecting a task to link to the current task, with
/// a relationship-type + direction picker (defaults to a plain "Link", today's
/// behavior, unchanged when untouched).
///
/// Shows a relationship picker plus a search field and list of candidate
/// tasks. Excludes the current task, and any task that already holds the
/// relationship currently selected — but not tasks linked by some *other*
/// relationship, which remain valid candidates.
class LinkTaskModal extends ConsumerStatefulWidget {
  const LinkTaskModal({
    required this.currentTaskId,
    required this.existingRelations,
    super.key,
  });

  /// The ID of the current task (to exclude from results).
  final String currentTaskId;

  /// Relationships the current task already holds, so the candidate list can
  /// exclude only the ones that would duplicate the selected relation.
  final Set<ExistingRelation> existingRelations;

  /// Shows the modal and returns the selected task, or null if cancelled.
  static Future<Task?> show({
    required BuildContext context,
    required String currentTaskId,
    required Set<ExistingRelation> existingRelations,
  }) {
    return ModalUtils.showSinglePageModal<Task>(
      context: context,
      title: context.messages.linkExistingTaskTitle,
      padding: EdgeInsets.zero,
      builder: (_) => LinkTaskModal(
        currentTaskId: currentTaskId,
        existingRelations: existingRelations,
      ),
    );
  }

  @override
  ConsumerState<LinkTaskModal> createState() => _LinkTaskModalState();
}

class _LinkTaskModalState extends ConsumerState<LinkTaskModal> {
  DirectedRelation _relation = const DirectedRelation(EntryLinkType.basic);

  Future<void> _selectTask(Task task) async {
    final swap = _relation.inverse;
    final fromId = swap ? task.meta.id : widget.currentTaskId;
    final toId = swap ? widget.currentTaskId : task.meta.id;
    // Captured before the pop below: the modal's own context is gone by the
    // time the confirmation needs a messenger.
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(journalRepositoryProvider);

    final created = await getIt<PersistenceLogic>().createLink(
      fromId: fromId,
      toId: toId,
      linkType: _relation.type,
    );

    if (!created) {
      if (mounted) {
        // Only a blocking link can fail the cycle guard. Reporting a cycle for
        // a "Relates to" or "Duplicates" pick named a cause that cannot apply
        // and a remedy — choose a different task — that would not help.
        showLinkFailureMessage(
          messenger: messenger,
          message: _relation.type == EntryLinkType.blocks
              ? context.messages.linkBlocksCycleErrorMessage
              : context.messages.linkCreateFailedMessage,
        );
      }
      return;
    }

    await HapticFeedback.mediumImpact();

    if (mounted) {
      showLinkCreatedFeedback(
        context: context,
        messenger: messenger,
        repository: repository,
        relation: _relation,
        fromId: fromId,
        toId: toId,
        linkedTaskTitle: task.data.title,
      );
      Navigator.of(context).pop(task);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    // The relation panel expands inline rather than over its host, so it adds
    // its full height to this sheet. Bounded at the measure the picker already
    // uses, the open panel takes its space from the result list instead of
    // pushing the sheet to the full height of the screen. It does not stop the
    // sheet resizing altogether — only an overlay-rendered panel would, which
    // is a change to the shared dropdown rather than to this modal.
    final maxHeight = math
        .min(MediaQuery.sizeOf(context).height * 0.9, 640)
        .toDouble();

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.spacing.step5,
              tokens.spacing.step5,
              tokens.spacing.step5,
              // Matches the container inset: the gap between the two fields
              // was tighter than the gap around them.
              tokens.spacing.step5,
            ),
            child: RelationshipTypeSelector(
              selected: _relation,
              onChanged: (relation) => setState(() => _relation = relation),
            ),
          ),
          Flexible(
            child: TaskSearchPickerBody(
              topInset: false,
              excludeIds: {
                widget.currentTaskId,
                // Only the tasks that already hold *this* relation — a pair may
                // legitimately hold several different ones.
                for (final existing in widget.existingRelations)
                  if (existing.relation == _relation) existing.taskId,
              },
              onTaskSelected: _selectTask,
            ),
          ),
        ],
      ),
    );
  }
}
