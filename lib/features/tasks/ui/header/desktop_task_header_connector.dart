import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/categories/ui/widgets/category_selection_modal_content.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/labels/state/labels_list_controller.dart';
import 'package:lotti/features/labels/ui/widgets/label_selection_modal_utils.dart';
import 'package:lotti/features/projects/repository/project_repository.dart';
import 'package:lotti/features/projects/state/project_providers.dart';
import 'package:lotti/features/projects/ui/widgets/project_selection_modal_content.dart';
import 'package:lotti/features/tasks/state/task_progress_controller.dart';
import 'package:lotti/features/tasks/ui/header/desktop_task_header.dart';
import 'package:lotti/features/tasks/ui/header/estimated_time_widget.dart';
import 'package:lotti/features/tasks/ui/header/task_due_date_widget.dart';
import 'package:lotti/features/tasks/ui/header/task_status_modal_content.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_palette.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_shared_widgets.dart';
import 'package:lotti/features/tasks/util/due_date_utils.dart';
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

    final entryState = ref.watch(entryControllerProvider(id: taskId)).value;
    final task = entryState?.entry;
    if (task is! Task) {
      return const SizedBox.shrink();
    }

    final projectAsync = ref.watch(projectForTaskProvider(taskId));
    final project = projectAsync.asData?.value;

    final data = _buildData(context, task, project);
    final controller = ref.read(entryControllerProvider(id: taskId).notifier);

    return DesktopTaskHeader(
      data: data,
      estimateSlot: _TaskEstimateChip(taskId: task.meta.id),
      onTitleSaved: (newTitle) {
        controller.save(title: newTitle);
      },
      onPriorityTap: () => _showPriorityPicker(context, ref, task),
      onStatusTap: () => _showStatusPicker(context, ref, task),
      onProjectTap: () => _showProjectPicker(
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
              DateFormat.yMMMd().format(due),
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
    final controller = ref.read(entryControllerProvider(id: taskId).notifier);
    final selected = await ModalUtils.showSinglePageModal<String>(
      context: context,
      title: context.messages.taskStatusLabel,
      builder: (_) => TaskStatusModalContent(task: task),
    );
    if (selected != null) {
      await controller.updateTaskStatus(selected);
    }
  }

  Future<void> _showPriorityPicker(
    BuildContext context,
    WidgetRef ref,
    Task task,
  ) async {
    final controller = ref.read(entryControllerProvider(id: taskId).notifier);
    final current = task.data.priority;
    final selected = await ModalUtils.showSinglePageModal<String>(
      context: context,
      title: context.messages.tasksPriorityPickerTitle,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final p in TaskPriority.values)
            ListTile(
              leading: SizedBox(
                width: 56,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TaskShowcasePriorityGlyph(priority: p),
                    SizedBox(width: ctx.designTokens.spacing.step2),
                    Text(
                      p.short,
                      style: ctx.designTokens.typography.styles.body.bodySmall
                          .copyWith(
                            color: TaskShowcasePalette.highText(ctx),
                          ),
                    ),
                  ],
                ),
              ),
              title: Text(_priorityDescription(ctx, p)),
              trailing: current == p ? const Icon(Icons.check) : null,
              onTap: () => Navigator.of(ctx).pop(p.short),
            ),
        ],
      ),
    );
    if (selected != null) {
      await controller.updateTaskPriority(selected);
    }
  }

  String _priorityDescription(BuildContext context, TaskPriority p) {
    final m = context.messages;
    switch (p) {
      case TaskPriority.p0Urgent:
        return m.tasksPriorityP0Description;
      case TaskPriority.p1High:
        return m.tasksPriorityP1Description;
      case TaskPriority.p2Medium:
        return m.tasksPriorityP2Description;
      case TaskPriority.p3Low:
        return m.tasksPriorityP3Description;
    }
  }

  Future<void> _showCategoryPicker(
    BuildContext context,
    WidgetRef ref,
    Task task,
  ) async {
    final controller = ref.read(entryControllerProvider(id: taskId).notifier);
    await ModalUtils.showSinglePageModal<void>(
      context: context,
      title: context.messages.habitCategoryLabel,
      builder: (_) => CategorySelectionModalContent(
        onCategorySelected: (category) {
          controller.updateCategoryId(category?.id);
          Navigator.of(context).pop();
        },
        initialCategoryId: task.meta.categoryId,
      ),
    );
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
    final controller = ref.read(entryControllerProvider(id: taskId).notifier);
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

/// Estimate chip surfaced in the header. Matches the visual treatment of
/// the other outlined caption chips in the metadata line (`radii.xs`,
/// step2/step1 padding, 12px clock icon, caption text). Shows the live
/// tracked / estimated duration and switches to the error color when the
/// tracked time exceeds the estimate. Tapping opens the shared
/// `showEstimatePicker` and persists via `EntryController.save(estimate: …)`.
class _TaskEstimateChip extends ConsumerWidget {
  const _TaskEstimateChip({required this.taskId});

  final String taskId;

  String _format(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(id: taskId);
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

    final tokens = context.designTokens;

    if (!hasEstimate) {
      return _EstimateChipShell(
        color: TaskShowcasePalette.lowText(context),
        onTap: onTap,
        child: Text(
          context.messages.taskNoEstimateLabel,
          style: tokens.typography.styles.others.caption.copyWith(
            color: TaskShowcasePalette.lowText(context),
            fontStyle: FontStyle.italic,
            height: 1,
          ),
        ),
      );
    }

    final progressState = ref
        .watch(taskProgressControllerProvider(id: taskId))
        .value;
    final isOvertime =
        progressState != null &&
        progressState.progress > progressState.estimate;
    final color = isOvertime
        ? TaskShowcasePalette.error(context)
        : TaskShowcasePalette.lowText(context);
    final progress = progressState?.progress ?? Duration.zero;
    final progressValue = estimate.inSeconds > 0
        ? math.min(progress.inSeconds / estimate.inSeconds, 1)
        : 0;
    return _EstimateChipShell(
      color: color,
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${_format(progress)} / ${_format(estimate)}',
            style: tokens.typography.styles.others.caption.copyWith(
              color: color,
              height: 1,
            ),
          ),
          // Progress bar only when we actually have a progress state — keeps
          // the chip from showing a misleading empty bar before the task
          // progress controller has produced a value.
          if (progressState != null) ...[
            SizedBox(width: tokens.spacing.step2),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                width: 36,
                height: 6,
                child: LinearProgressIndicator(
                  value: progressValue.toDouble(),
                  backgroundColor: color.withValues(alpha: 0.2),
                  color: isOvertime
                      ? color.withValues(alpha: 0.8)
                      : TaskShowcasePalette.success(context),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Outlined caption-chip shell matching the other metadata chips: 12px
/// leading clock icon + caption text in [color], `radii.xs`,
/// `step2 / step1` padding, transparent fill, decorative-level01 border.
class _EstimateChipShell extends StatelessWidget {
  const _EstimateChipShell({
    required this.child,
    required this.color,
    required this.onTap,
  });

  final Widget child;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final content = Container(
      constraints: const BoxConstraints(minHeight: 20),
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step2,
        vertical: tokens.spacing.step1,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(tokens.radii.xs),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 12, color: color),
          SizedBox(width: tokens.spacing.step1),
          child,
        ],
      ),
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(tokens.radii.xs),
        onTap: onTap,
        child: content,
      ),
    );
  }
}
