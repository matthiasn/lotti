import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/categories/ui/widgets/category_picker_sheet.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_shared.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/labels/state/labels_list_controller.dart';
import 'package:lotti/features/labels/ui/widgets/label_selection_modal_utils.dart';
import 'package:lotti/features/projects/repository/project_repository.dart';
import 'package:lotti/features/projects/state/project_providers.dart';
import 'package:lotti/features/projects/ui/widgets/project_selection_modal_content.dart';
import 'package:lotti/features/tasks/state/task_blockers_controller.dart';
import 'package:lotti/features/tasks/state/task_progress_controller.dart';
import 'package:lotti/features/tasks/ui/header/desktop_task_header.dart';
import 'package:lotti/features/tasks/ui/header/estimated_time_widget.dart';
import 'package:lotti/features/tasks/ui/header/task_consumption_chip.dart';
import 'package:lotti/features/tasks/ui/header/task_due_date_widget.dart';
import 'package:lotti/features/tasks/ui/header/task_priority_modal_content.dart';
import 'package:lotti/features/tasks/ui/header/task_status_modal_content.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/blocking_task_picker_modal.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/linked_task_row.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_palette.dart';
import 'package:lotti/features/tasks/util/due_date_utils.dart';
import 'package:lotti/features/tasks/util/task_navigation.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

/// Connects [DesktopTaskHeader] to the Riverpod task state and opens the
/// existing modal pickers (status, priority, category, project, due date,
/// labels, ellipsis actions).
///
/// The presentational widget stays framework-free; all repository /
/// `EntryController` interaction is concentrated here so widgetbook and tests
/// can target the inner `DesktopTaskHeader` directly.
class DesktopTaskHeaderConnector extends ConsumerWidget {
  const DesktopTaskHeaderConnector({
    required this.taskId,
    super.key,
  });

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Rebuild when label definitions change (names, colours, visibility).
    ref.watch(labelsStreamProvider);

    final entryState = ref.watch(entryControllerProvider(taskId)).value;
    final task = entryState?.entry;
    if (task is! Task) {
      return const SizedBox.shrink();
    }

    final projectAsync = ref.watch(projectForTaskProvider(taskId));
    final project = projectAsync.asData?.value;

    final data = _buildData(context, task, project);
    final controller = ref.read(entryControllerProvider(taskId).notifier);

    return DesktopTaskHeader(
      data: data,
      estimateSlot: _TaskEstimateChip(taskId: task.meta.id),
      consumptionSlot: TaskConsumptionChip(taskId: task.meta.id),
      blockedBySlot: _TaskBlockedByChip(taskId: task.meta.id),
      onTitleSaved: (newTitle) {
        controller.save(title: newTitle);
      },
      onPriorityTap: () => _showPriorityPicker(context, ref, task),
      onStatusTap: () => _showStatusPicker(context, ref, task),
      // Without a category we can't open a project picker — the connector
      // would early-return inside `_showProjectPicker`. Pass `null` so the
      // crumb segment renders without an InkWell instead of looking
      // tappable but doing nothing.
      onProjectTap: task.meta.categoryId == null
          ? null
          : () => _showProjectPicker(
              context,
              ref,
              taskId,
              project,
              task.meta.categoryId,
            ),
      onCategoryTap: () => _showCategoryPicker(context, ref, task),
      onDueDateTap: () => _showDueDatePicker(context, ref, task),
      onLabelTap: (_) => _openLabelSelector(context, ref, task),
      onAddLabelTap: () => _openLabelSelector(context, ref, task),
    );
  }

  DesktopTaskHeaderData _buildData(
    BuildContext context,
    Task task,
    ProjectEntry? project,
  ) {
    final cache = getIt<EntitiesCacheService>();
    final categoryId = task.meta.categoryId;
    final categoryDef = cache.getCategoryById(categoryId);
    final category = categoryDef == null
        ? null
        : DesktopTaskHeaderCategory(
            label: categoryDef.name,
            color: colorFromCssHex(
              categoryDef.color,
              substitute: Theme.of(context).colorScheme.primary,
            ),
            icon: categoryDef.icon?.iconData,
          );

    final due = task.data.due;
    final dueDate = due == null
        ? null
        : DesktopTaskHeaderDueDate(
            label: context.messages.taskDueDateWithDate(
              DateFormat.yMMMd(
                Localizations.localeOf(context).toLanguageTag(),
              ).format(due),
            ),
            urgency: _dueUrgency(task.data),
          );

    final showPrivate = cache.showPrivateEntries;
    final labels = <LabelDefinition>[];
    for (final id in task.meta.labelIds ?? const <String>[]) {
      final def = cache.getLabelById(id);
      if (def == null) continue;
      if (!showPrivate && (def.private ?? false)) continue;
      labels.add(def);
    }
    labels.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );

    return DesktopTaskHeaderData(
      title: task.data.title,
      priority: task.data.priority,
      status: task.data.status,
      project: project == null
          ? null
          : DesktopTaskHeaderProject(
              label: project.data.title,
              icon: Icons.folder_outlined,
            ),
      category: category,
      dueDate: dueDate,
      labels: labels,
    );
  }

  DesktopTaskHeaderDueUrgency _dueUrgency(TaskData data) {
    if (data.due == null) return DesktopTaskHeaderDueUrgency.normal;
    // Completed / rejected tasks are no longer "urgent" — they're done.
    if (data.status is TaskDone || data.status is TaskRejected) {
      return DesktopTaskHeaderDueUrgency.normal;
    }
    final status = getDueDateStatus(
      dueDate: data.due,
      referenceDate: clock.now(),
    );
    switch (status.urgency) {
      case DueDateUrgency.overdue:
        return DesktopTaskHeaderDueUrgency.overdue;
      case DueDateUrgency.dueToday:
        return DesktopTaskHeaderDueUrgency.today;
      case DueDateUrgency.normal:
        return DesktopTaskHeaderDueUrgency.normal;
    }
  }

  Future<void> _showStatusPicker(
    BuildContext context,
    WidgetRef ref,
    Task task,
  ) async {
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

  Future<void> _showPriorityPicker(
    BuildContext context,
    WidgetRef ref,
    Task task,
  ) async {
    final controller = ref.read(entryControllerProvider(taskId).notifier);
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

  Future<void> _showCategoryPicker(
    BuildContext context,
    WidgetRef ref,
    Task task,
  ) async {
    final controller = ref.read(entryControllerProvider(taskId).notifier);
    final result = await showCategoryPicker(
      context: context,
      title: context.messages.habitCategoryLabel,
      currentCategoryId: task.meta.categoryId,
    );
    if (result == null) return;
    await controller.updateCategoryId(result.categoryOrNull?.id);
  }

  Future<void> _showProjectPicker(
    BuildContext context,
    WidgetRef ref,
    String taskId,
    ProjectEntry? current,
    String? categoryId,
  ) async {
    if (categoryId == null) return;
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

  Future<void> _showDueDatePicker(
    BuildContext context,
    WidgetRef ref,
    Task task,
  ) async {
    final controller = ref.read(entryControllerProvider(taskId).notifier);
    await showDueDatePicker(
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

  Future<void> _openLabelSelector(
    BuildContext context,
    WidgetRef ref,
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

/// Estimate pill surfaced in the meta row. Renders as a `DsPill.muted` ghost
/// chip when no estimate is set and as a `DsPill.filled` (or `DsPill.tinted`
/// in the error color when overtime) showing live `tracked / estimated` plus
/// a small progress bar when an estimate is set. Tapping opens the shared
/// `showEstimatePicker` and persists via `EntryController.save(estimate: …)`.
class _TaskEstimateChip extends ConsumerWidget {
  const _TaskEstimateChip({required this.taskId});

  final String taskId;

  /// Formats a duration as plain units ("1h 30m", "45m", "2h") rather than a
  /// zero-padded "HH:MM" clock — users read "00:00 / 01:00" as a time-of-day
  /// range; "0m of 1h" reads unambiguously as tracked-of-estimated duration.
  String _format(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0 && minutes > 0) return '${hours}h ${minutes}m';
    if (hours > 0) return '${hours}h';
    return '${minutes}m';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(taskId);
    final entryState = ref.watch(provider).value;
    final task = entryState?.entry;
    if (task is! Task) {
      return const SizedBox.shrink();
    }
    final notifier = ref.read(provider.notifier);
    final estimate = task.data.estimate;
    final hasEstimate = estimate != null && estimate != Duration.zero;

    Future<void> onTap() async {
      await showEstimatePicker(
        context: context,
        initialDuration: estimate ?? Duration.zero,
        onEstimateChanged: (newDuration) async {
          await notifier.save(estimate: newDuration);
        },
      );
    }

    if (!hasEstimate) {
      return DsPill(
        variant: DsPillVariant.muted,
        label: context.messages.taskNoEstimateLabel,
        leading: Icon(
          Icons.timer_outlined,
          size: 12,
          color: TaskShowcasePalette.lowText(context),
        ),
        onTap: onTap,
      );
    }

    final progressState = ref
        .watch(taskProgressControllerProvider(taskId))
        .value;
    final isOvertime =
        progressState != null &&
        progressState.progress > progressState.estimate;
    final progress = progressState?.progress ?? Duration.zero;
    final progressValue = estimate.inSeconds > 0
        ? math.min(progress.inSeconds / estimate.inSeconds, 1)
        : 0;
    final iconColor = isOvertime
        ? TaskShowcasePalette.error(context)
        : TaskShowcasePalette.mediumText(context);
    final barTrack = isOvertime
        ? TaskShowcasePalette.error(context).withValues(alpha: 0.2)
        : TaskShowcasePalette.lowText(context).withValues(alpha: 0.2);
    final barFill = isOvertime
        ? TaskShowcasePalette.error(context)
        : TaskShowcasePalette.success(context);
    final progressBar = progressState == null
        ? null
        : ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              width: 36,
              height: 6,
              child: LinearProgressIndicator(
                value: progressValue.toDouble(),
                backgroundColor: barTrack,
                color: barFill,
              ),
            ),
          );

    final trackedStr = _format(progress);
    final estimateStr = _format(estimate);
    // "X of Y" reads as tracked-of-estimated (part of a whole) instead of the
    // ambiguous "X / Y" where users couldn't tell which number was which.
    final progressLabel = context.messages.taskEstimateProgressLabel(
      trackedStr,
      estimateStr,
    );
    // The tooltip spells it out fully on hover and for assistive tech, so the
    // two numbers are never a guessing game.
    final tooltip = context.messages.taskEstimateTooltip(
      trackedStr,
      estimateStr,
    );
    final pill = isOvertime
        ? DsPill(
            variant: DsPillVariant.tinted,
            color: TaskShowcasePalette.error(context),
            label: progressLabel,
            leading: Icon(Icons.timer_outlined, size: 12, color: iconColor),
            trailing: progressBar,
            onTap: onTap,
          )
        : DsPill(
            variant: DsPillVariant.filled,
            // Quiet border gives low-vision users a clear chip boundary.
            bordered: true,
            label: progressLabel,
            // A set estimate carries real data, so it reads at the same
            // medium-emphasis contrast as the due-date chip rather than the dim
            // low-emphasis grey reserved for empty placeholders (which made an
            // active estimate look disabled).
            labelColor: TaskShowcasePalette.mediumText(context),
            leading: Icon(Icons.timer_outlined, size: 12, color: iconColor),
            trailing: progressBar,
            onTap: onTap,
          );
    return Tooltip(message: tooltip, child: pill);
  }
}

/// "Blocked by" chip in the header's status cluster — a derived, read-time
/// fact (ADR 0042 §4) independent of the task's own [TaskStatus]: a task can
/// carry a live `blocks` link while its stored status is still `open`, and
/// that's exactly the state this chip must surface. Renders nothing when the
/// task isn't blocked.
class _TaskBlockedByChip extends ConsumerWidget {
  const _TaskBlockedByChip({required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(taskBlockersControllerProvider(taskId)).value;
    if (result == null || !result.isBlocked) {
      return const SizedBox.shrink();
    }

    final accent = TaskShowcasePalette.error(context);
    final blockers = result.openBlockers;

    if (blockers.isEmpty) {
      // Blocked purely by a link whose blocker id didn't resolve to any
      // entity (conservative default, ADR 0042 §4) — nothing to name or
      // navigate to, so render a bare label with no tap affordance.
      return DsPill(
        variant: DsPillVariant.tinted,
        color: accent,
        leading: Icon(Icons.block, size: 12, color: accent),
        label: context.messages.taskStatusBlocked,
      );
    }

    final single = blockers.length == 1;

    return Tooltip(
      message: context.messages.taskBlockedByChipTooltip(
        blockers.length,
        single ? blockers.first.data.title : '',
      ),
      child: DsPill(
        variant: DsPillVariant.tinted,
        color: accent,
        leading: Icon(Icons.block, size: 12, color: accent),
        label: context.messages.taskBlockedByChipLabel(
          blockers.length,
          single ? blockers.first.data.title : '',
        ),
        onTap: () => single
            ? openLinkedTaskDetail(context: context, taskId: blockers.first.id)
            : _showBlockersSheet(context, blockers),
      ),
    );
  }

  Future<void> _showBlockersSheet(
    BuildContext context,
    List<Task> blockers,
  ) async {
    await ModalUtils.showSinglePageModal<void>(
      context: context,
      title: context.messages.linkedTasksBlockedBySectionTitle,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [
          for (final blocker in blockers)
            LinkedTaskRow(
              taskId: taskId,
              data: LinkedTaskRowData(
                task: blocker,
                direction: LinkDirection.incoming,
              ),
              manageMode: false,
            ),
        ],
      ),
    );
  }
}
