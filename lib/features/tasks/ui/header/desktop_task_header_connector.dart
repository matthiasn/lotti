import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/categories/ui/widgets/category_selection_modal_content.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/header/extended_header_modal.dart';
import 'package:lotti/features/labels/state/labels_list_controller.dart';
import 'package:lotti/features/labels/ui/widgets/label_selection_modal_utils.dart';
import 'package:lotti/features/projects/repository/project_repository.dart';
import 'package:lotti/features/projects/state/project_providers.dart';
import 'package:lotti/features/projects/ui/widgets/project_selection_modal_content.dart';
import 'package:lotti/features/tasks/ui/header/desktop_task_header.dart';
import 'package:lotti/features/tasks/ui/header/task_due_date_widget.dart';
import 'package:lotti/features/tasks/ui/header/task_status_modal_content.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_palette.dart';
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
      onEllipsisTap: () => _openEllipsisMenu(context, task.meta.id),
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
            isUrgent: _isDueUrgent(task.data),
          );

    final showPrivate = cache.showPrivateEntries;
    final labels = <DesktopTaskHeaderLabel>[];
    for (final id in task.meta.labelIds ?? const <String>[]) {
      final def = cache.getLabelById(id);
      if (def == null) continue;
      if (!showPrivate && (def.private ?? false)) continue;
      labels.add(_mapLabel(context, def));
    }
    labels.sort(
      (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
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

  DesktopTaskHeaderLabel _mapLabel(BuildContext context, LabelDefinition def) {
    final color = colorFromCssHex(
      def.color,
      substitute: TaskShowcasePalette.mediumText(context),
    );
    return DesktopTaskHeaderLabel(
      id: def.id,
      label: def.name,
      color: color,
    );
  }

  bool _isDueUrgent(TaskData data) {
    final due = data.due;
    if (due == null) return false;
    if (data.status is TaskDone || data.status is TaskRejected) return false;
    return due.isBefore(DateTime.now());
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
              leading: SizedBox.square(
                dimension: 20,
                child: _PriorityLeading(priority: p),
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

  Future<void> _openEllipsisMenu(BuildContext context, String entryId) async {
    await ExtendedHeaderModal.show(
      context: context,
      entryId: entryId,
      linkedFromId: null,
      link: null,
      inLinkedEntries: false,
    );
  }
}

class _PriorityLeading extends StatelessWidget {
  const _PriorityLeading({required this.priority});

  final TaskPriority priority;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        priority.short,
        style: Theme.of(context).textTheme.labelMedium,
      ),
    );
  }
}
