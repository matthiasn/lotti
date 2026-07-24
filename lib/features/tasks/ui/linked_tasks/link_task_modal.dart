import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
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
/// Shows a search field and list of available tasks. Excludes:
/// - The current task itself
/// - Tasks already linked (both incoming and outgoing)
class LinkTaskModal extends ConsumerStatefulWidget {
  const LinkTaskModal({
    required this.currentTaskId,
    required this.existingLinkedIds,
    super.key,
  });

  /// The ID of the current task (to exclude from results).
  final String currentTaskId;

  /// IDs of tasks already linked (to exclude from results).
  final Set<String> existingLinkedIds;

  /// Shows the modal and returns the selected task, or null if cancelled.
  static Future<Task?> show({
    required BuildContext context,
    required String currentTaskId,
    required Set<String> existingLinkedIds,
  }) {
    return ModalUtils.showSinglePageModal<Task>(
      context: context,
      title: context.messages.linkExistingTask,
      padding: EdgeInsets.zero,
      builder: (_) => LinkTaskModal(
        currentTaskId: currentTaskId,
        existingLinkedIds: existingLinkedIds,
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
    final created = await getIt<PersistenceLogic>().createLink(
      fromId: swap ? task.meta.id : widget.currentTaskId,
      toId: swap ? widget.currentTaskId : task.meta.id,
      linkType: _relation.type,
    );

    if (!created) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.messages.linkBlocksCycleErrorMessage)),
        );
      }
      return;
    }

    await HapticFeedback.mediumImpact();

    if (mounted) {
      Navigator.of(context).pop(task);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            tokens.spacing.step5,
            tokens.spacing.step5,
            tokens.spacing.step5,
            tokens.spacing.step4,
          ),
          child: RelationshipTypeSelector(
            selected: _relation,
            onChanged: (relation) => setState(() => _relation = relation),
          ),
        ),
        TaskSearchPickerBody(
          topInset: false,
          excludeIds: {
            widget.currentTaskId,
            ...widget.existingLinkedIds,
          },
          onTaskSelected: _selectTask,
        ),
      ],
    );
  }
}
