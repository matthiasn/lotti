import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/tasks/state/task_link_groups_controller.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/task_search_picker_body.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

/// Optional prompt shown right after a task's status is set to Blocked, to
/// name what's blocking it. Unlike `LinkTaskModal`, the relationship here is
/// fixed to `blocks` with a fixed direction (the picked task is always the
/// blocker) — no relationship-type selector.
///
/// Skippable with zero required interaction: the status write already
/// completed independently before this modal opens (see
/// `DesktopTaskHeaderConnector._showStatusPicker`), so dismissing this modal
/// or tapping Skip persists nothing further.
class BlockingTaskPickerModal extends ConsumerWidget {
  const BlockingTaskPickerModal({required this.blockedTaskId, super.key});

  /// The task that just became Blocked — the new link's `toId`.
  final String blockedTaskId;

  /// Shows the modal. Returns the selected blocker task, or null if the user
  /// skipped/dismissed it.
  static Future<Task?> show({
    required BuildContext context,
    required String blockedTaskId,
  }) {
    return ModalUtils.showBottomSheet<Task>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) =>
          BlockingTaskPickerModal(blockedTaskId: blockedTaskId),
    );
  }

  Future<void> _selectBlocker(BuildContext context, Task blocker) async {
    final created = await getIt<PersistenceLogic>().createLink(
      fromId: blocker.meta.id,
      toId: blockedTaskId,
      linkType: EntryLinkType.blocks,
    );

    if (!created) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.messages.linkBlocksCycleErrorMessage)),
        );
      }
      return;
    }

    await HapticFeedback.mediumImpact();

    if (context.mounted) {
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

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Center(
              child: Container(
                key: const Key('blocking_task_picker_modal_handle'),
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: context.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.messages.taskBlockerPickerTitle,
                      style: context.textTheme.titleMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(context.messages.taskBlockerPickerSkipButton),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TaskSearchPickerBody(
                excludeIds: {blockedTaskId, ...existingBlockerIds},
                onTaskSelected: (task) => _selectBlocker(context, task),
                scrollController: scrollController,
              ),
            ),
          ],
        );
      },
    );
  }
}
