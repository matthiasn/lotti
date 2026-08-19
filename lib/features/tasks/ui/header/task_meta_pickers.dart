import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/categories/ui/widgets/category_picker_sheet.dart'
    as category_picker;
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_shared.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/labels/ui/widgets/label_selection_modal_utils.dart';
import 'package:lotti/features/projects/repository/project_repository.dart';
import 'package:lotti/features/projects/ui/widgets/project_selection_modal_content.dart';
import 'package:lotti/features/tasks/state/task_blockers_controller.dart';
import 'package:lotti/features/tasks/ui/header/estimated_time_widget.dart'
    as estimate_picker;
import 'package:lotti/features/tasks/ui/header/task_due_date_widget.dart'
    as due_date_picker;
import 'package:lotti/features/tasks/ui/header/task_priority_modal_content.dart';
import 'package:lotti/features/tasks/ui/header/task_status_modal_content.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/blocking_task_picker_modal.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

/// The task metadata pickers, shared between the header (breadcrumb taps) and
/// the metadata fly-out.
///
/// Each method opens the existing modal picker for one attribute and persists
/// the selection through `EntryController`. Concentrated here so the fly-out
/// and the header connector cannot drift apart in how an attribute is edited.
class TaskMetaPickers {
  const TaskMetaPickers._();

  /// Opens the status picker; when the task just became `BLOCKED` and carries
  /// no blocker link yet, follows up with the blocking-task picker so the
  /// user can name what it waits on.
  static Future<void> showStatusPicker(
    BuildContext context,
    WidgetRef ref,
    Task task,
  ) async {
    final taskId = task.meta.id;
    final controller = ref.read(entryControllerProvider(taskId).notifier);
    final previousStatus = task.data.status.toDbString;
    final selected = await ModalUtils.showSinglePageModal<String>(
      context: context,
      // Strip the trailing colon so the picker title matches the other
      // pickers (e.g. "Select priority", "Labels"), which carry no colon.
      title: stripTrailingColon(context.messages.taskStatusLabel),
      padding: EdgeInsets.zero,
      builder: (_) => TaskStatusModalContent(task: task),
    );
    if (selected == null) return;

    await controller.updateTaskStatus(selected);

    final becameBlocked = selected == 'BLOCKED' && selected != previousStatus;
    if (!becameBlocked || !context.mounted) return;

    final blockers = await ref.read(
      taskBlockersControllerProvider(taskId).future,
    );
    // isBlocked (not just openBlockers) so an unresolved-only blocker link
    // also counts as "already named" — don't re-prompt over it.
    if (blockers.isBlocked) return;
    if (!context.mounted) return;

    await BlockingTaskPickerModal.show(context: context, blockedTaskId: taskId);
  }

  static Future<void> showPriorityPicker(
    BuildContext context,
    WidgetRef ref,
    Task task,
  ) async {
    final controller = ref.read(
      entryControllerProvider(task.meta.id).notifier,
    );
    final current = task.data.priority;
    final selected = await ModalUtils.showSinglePageModal<String>(
      context: context,
      title: context.messages.tasksPriorityPickerTitle,
      padding: EdgeInsets.zero,
      builder: (modalContext) => TaskPriorityModalContent(
        currentPriority: current,
        onSelected: (priority) =>
            Navigator.of(modalContext).pop(priority.short),
      ),
    );
    if (selected != null) {
      await controller.updateTaskPriority(selected);
    }
  }

  static Future<void> showCategoryPicker(
    BuildContext context,
    WidgetRef ref,
    Task task,
  ) async {
    final controller = ref.read(
      entryControllerProvider(task.meta.id).notifier,
    );
    final result = await category_picker.showCategoryPicker(
      context: context,
      title: context.messages.habitCategoryLabel,
      currentCategoryId: task.meta.categoryId,
    );
    if (result == null) return;
    await controller.updateCategoryId(result.categoryOrNull?.id);
  }

  static Future<void> showProjectPicker(
    BuildContext context,
    WidgetRef ref, {
    required String taskId,
    required String categoryId,
    ProjectEntry? current,
  }) async {
    final repository = ref.read(projectRepositoryProvider);
    await ModalUtils.showSinglePageModal<void>(
      context: context,
      title: context.messages.projectPickerLabel,
      padding: EdgeInsets.zero,
      builder: (_) => ProjectSelectionModalContent(
        categoryId: categoryId,
        currentProjectId: current?.meta.id,
        onProjectSelected: (selected) async {
          if (selected == null) {
            await repository.unlinkTaskFromProject(taskId);
          } else {
            await repository.linkTaskToProject(
              projectId: selected.meta.id,
              taskId: taskId,
            );
          }
        },
      ),
    );
  }

  static Future<void> showDueDatePicker(
    BuildContext context,
    WidgetRef ref,
    Task task,
  ) async {
    final controller = ref.read(
      entryControllerProvider(task.meta.id).notifier,
    );
    await due_date_picker.showDueDatePicker(
      context: context,
      initialDate: task.data.due,
      onDueDateChanged: (newDate) async {
        if (newDate == null) {
          await controller.save(clearDueDate: true);
        } else {
          await controller.save(dueDate: newDate);
        }
      },
    );
  }

  static Future<void> showEstimatePickerForTask(
    BuildContext context,
    WidgetRef ref,
    Task task,
  ) async {
    final controller = ref.read(
      entryControllerProvider(task.meta.id).notifier,
    );
    await estimate_picker.showEstimatePicker(
      context: context,
      initialDuration: task.data.estimate ?? Duration.zero,
      onEstimateChanged: (newDuration) async {
        await controller.save(estimate: newDuration);
      },
    );
  }

  static Future<void> openLabelSelector(
    BuildContext context,
    Task task,
  ) async {
    await LabelSelectionModalUtils.openLabelSelector(
      context: context,
      entryId: task.meta.id,
      initialLabelIds: task.meta.labelIds ?? const <String>[],
      categoryId: task.meta.categoryId,
    );
  }
}
