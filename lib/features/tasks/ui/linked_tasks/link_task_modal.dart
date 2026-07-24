import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/relationship_type_selector.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/task_search_picker_body.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/themes/theme.dart';
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
  }) async {
    return ModalUtils.showBottomSheet<Task>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => LinkTaskModal(
        currentTaskId: currentTaskId,
        existingLinkedIds: existingLinkedIds,
      ),
    );
  }

  @override
  ConsumerState<LinkTaskModal> createState() => _LinkTaskModalState();
}

class _LinkTaskModalState extends ConsumerState<LinkTaskModal> {
  EntryLinkType _selectedType = EntryLinkType.basic;
  bool _inverse = false;

  Future<void> _selectTask(Task task) async {
    final swap = _selectedType != EntryLinkType.basic && _inverse;
    final created = await getIt<PersistenceLogic>().createLink(
      fromId: swap ? task.meta.id : widget.currentTaskId,
      toId: swap ? widget.currentTaskId : task.meta.id,
      linkType: _selectedType,
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
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle bar
            Center(
              child: Container(
                key: const Key('link_task_modal_handle'),
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: context.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                context.messages.linkExistingTask,
                style: context.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: RelationshipTypeSelector(
                selectedType: _selectedType,
                inverse: _inverse,
                onTypeChanged: (type) => setState(() {
                  _selectedType = type;
                  _inverse = false;
                }),
                onInverseChanged: (value) => setState(() => _inverse = value),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TaskSearchPickerBody(
                excludeIds: {
                  widget.currentTaskId,
                  ...widget.existingLinkedIds,
                },
                onTaskSelected: _selectTask,
                scrollController: scrollController,
              ),
            ),
          ],
        );
      },
    );
  }
}
