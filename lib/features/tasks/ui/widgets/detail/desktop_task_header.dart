import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/categories/ui/widgets/category_selection_modal_content.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/labels/ui/widgets/label_selection_modal_utils.dart';
import 'package:lotti/features/projects/repository/project_repository.dart';
import 'package:lotti/features/projects/state/project_providers.dart';
import 'package:lotti/features/projects/ui/widgets/project_selection_modal_content.dart';
import 'package:lotti/features/tasks/ui/header/task_due_date_widget.dart';
import 'package:lotti/features/tasks/ui/header/task_status_modal_content.dart';
import 'package:lotti/features/tasks/ui/title_text_field.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_palette.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_shared_widgets.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

/// Interactive desktop task header matching the Figma design.
///
/// Renders title (editable on tap), priority badge, project affiliation,
/// category/due-date/label chips, and status selector — all interactive
/// with showcase-style visuals matching the Figma design.
class DesktopTaskHeader extends ConsumerStatefulWidget {
  const DesktopTaskHeader({
    required this.taskId,
    super.key,
  });

  final String taskId;

  @override
  ConsumerState<DesktopTaskHeader> createState() => _DesktopTaskHeaderState();
}

class _DesktopTaskHeaderState extends ConsumerState<DesktopTaskHeader> {
  bool _isEditingTitle = false;
  final _titleFocusNode = FocusNode();

  @override
  void dispose() {
    _titleFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final provider = entryControllerProvider(id: widget.taskId);
    final entryState = ref.watch(provider).value;
    final entry = entryState?.entry;

    if (entry is! Task) return const SizedBox.shrink();

    final notifier = ref.read(provider.notifier);
    final task = entry;
    final cache = getIt<EntitiesCacheService>();
    final category = cache.getCategoryById(task.meta.categoryId);
    final projectAsync = ref.watch(projectForTaskProvider(widget.taskId));
    final projectTitle = projectAsync.value?.data.title ?? '';

    // Title: editable on tap
    final titleWidget = _isEditingTitle || task.data.title.isEmpty
        ? TitleTextField(
            initialValue: task.data.title,
            resetToInitialValue: true,
            onSave: (newTitle) async {
              await notifier.save(title: newTitle);
              setState(() => _isEditingTitle = false);
            },
            focusNode: _titleFocusNode,
            hintText: context.messages.taskNameHint,
            onTapOutside: (_) => setState(() => _isEditingTitle = false),
            onCancel: () => setState(() => _isEditingTitle = false),
          )
        : GestureDetector(
            onTap: () {
              setState(() => _isEditingTitle = true);
              _titleFocusNode.requestFocus();
            },
            child: Text(
              task.data.title,
              style: tokens.typography.styles.heading.heading2.copyWith(
                color: TaskShowcasePalette.highText(context),
              ),
            ),
          );

    // Priority: tappable to open picker
    final priorityWidget = GestureDetector(
      onTap: () => _showPriorityPicker(context, task),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TaskShowcasePriorityGlyph(priority: task.data.priority, size: 20),
          SizedBox(width: tokens.spacing.step2),
          Text(
            task.data.priority.short,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: task.data.priority.colorForBrightness(
                Theme.of(context).brightness,
              ),
            ),
          ),
        ],
      ),
    );

    // Due date chip: showcase style, tappable
    final due = task.data.due;
    final dueDateChip = GestureDetector(
      onTap: () => _showDueDatePicker(context, due),
      child: TaskShowcaseMetaChip(
        icon: Icons.watch_later_outlined,
        label: due != null
            ? context.messages.taskShowcaseDueDate(
                DateFormat.yMMMd().format(due),
              )
            : context.messages.taskNoDueDateLabel,
      ),
    );

    // Category chip: showcase style, tappable
    final categoryColor = category?.color ?? defaultCategoryColorHex;
    final categoryChip = GestureDetector(
      onTap: () => _showCategoryPicker(context, task),
      child: TaskShowcaseCategoryChip(
        label: category?.name ?? context.messages.taskCategoryUnassignedLabel,
        icon: category?.icon?.iconData ?? Icons.label_outline,
        colorHex: categoryColor,
      ),
    );

    // Labels: showcase style, tappable
    final labelChips = _buildLabelChips(task);

    // Status selector: showcase style, tappable
    final statusWidget = GestureDetector(
      onTap: () => _showStatusPicker(context, task),
      child: TaskShowcaseStatusLabel(
        status: task.data.status,
        expanded: true,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Row 1: Title + Priority badge ... Three-dot menu
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: tokens.spacing.step3,
                    runSpacing: tokens.spacing.step2,
                    children: [titleWidget, priorityWidget],
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: tokens.spacing.step1),
                    child: GestureDetector(
                      onTap: () => _showProjectPicker(context, task),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.folder_open_rounded,
                            size: 12,
                            color: TaskShowcasePalette.lowText(context),
                          ),
                          SizedBox(width: tokens.spacing.step2),
                          Flexible(
                            child: Text(
                              projectTitle.isNotEmpty
                                  ? projectTitle
                                  : context.messages.projectPickerUnassigned,
                              overflow: TextOverflow.ellipsis,
                              style: tokens.typography.styles.others.caption
                                  .copyWith(
                                    color: TaskShowcasePalette.lowText(context),
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: tokens.spacing.step3),
            Icon(
              Icons.more_vert_rounded,
              color: TaskShowcasePalette.mediumText(context),
            ),
          ],
        ),
        SizedBox(height: tokens.spacing.step3),
        // Row 2: Metadata chips + Status
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: tokens.spacing.step3,
                    runSpacing: tokens.spacing.step2,
                    children: [categoryChip, dueDateChip],
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: tokens.spacing.step2),
                    child: GestureDetector(
                      onTap: () => _showLabelPicker(context, task),
                      child: labelChips.isNotEmpty
                          ? Wrap(
                              spacing: tokens.spacing.step2,
                              runSpacing: tokens.spacing.step2,
                              children: labelChips,
                            )
                          : Text(
                              context.messages.tasksLabelsSheetTitle,
                              style: tokens.typography.styles.others.caption
                                  .copyWith(
                                    color: TaskShowcasePalette.lowText(context),
                                  ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            statusWidget,
          ],
        ),
      ],
    );
  }

  Future<void> _showPriorityPicker(BuildContext context, Task task) async {
    final notifier = ref.read(
      entryControllerProvider(id: widget.taskId).notifier,
    );
    final res = await ModalUtils.showSinglePageModal<String>(
      context: context,
      title: context.messages.tasksPriorityPickerTitle,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: TaskPriority.values
            .map(
              (p) => ListTile(
                leading: TaskShowcasePriorityGlyph(priority: p),
                title: Text(p.short),
                trailing: task.data.priority == p
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.of(ctx).pop(p.short),
              ),
            )
            .toList(),
      ),
    );
    if (res != null) {
      await notifier.updateTaskPriority(res);
    }
  }

  Future<void> _showStatusPicker(BuildContext context, Task task) async {
    final notifier = ref.read(
      entryControllerProvider(id: widget.taskId).notifier,
    );
    final res = await ModalUtils.showSinglePageModal<String>(
      context: context,
      title: context.messages.taskStatusLabel,
      builder: (_) => TaskStatusModalContent(task: task),
    );
    if (res != null) {
      await notifier.updateTaskStatus(res);
    }
  }

  Future<void> _showDueDatePicker(BuildContext context, DateTime? due) async {
    final notifier = ref.read(
      entryControllerProvider(id: widget.taskId).notifier,
    );
    await showDueDatePicker(
      context: context,
      initialDate: due,
      onDueDateChanged: (newDate) async {
        if (newDate == null) {
          await notifier.save(clearDueDate: true);
        } else {
          await notifier.save(dueDate: newDate);
        }
      },
    );
  }

  void _showCategoryPicker(BuildContext context, Task task) {
    final notifier = ref.read(
      entryControllerProvider(id: widget.taskId).notifier,
    );
    ModalUtils.showSinglePageModal<void>(
      context: context,
      title: context.messages.habitCategoryLabel,
      builder: (BuildContext _) {
        return CategorySelectionModalContent(
          onCategorySelected: (category) {
            notifier.updateCategoryId(category?.id);
            Navigator.pop(context);
          },
          initialCategoryId: task.meta.categoryId,
        );
      },
    );
  }

  void _showLabelPicker(BuildContext context, Task task) {
    LabelSelectionModalUtils.openLabelSelector(
      context: context,
      entryId: widget.taskId,
      initialLabelIds: task.meta.labelIds ?? [],
      categoryId: task.meta.categoryId,
    );
  }

  void _showProjectPicker(BuildContext context, Task task) {
    final categoryId = task.meta.categoryId;
    if (categoryId == null) return;

    final projectAsync = ref.read(projectForTaskProvider(widget.taskId));
    final project = projectAsync.value;

    ModalUtils.showSinglePageModal<void>(
      context: context,
      title: context.messages.projectPickerLabel,
      padding: EdgeInsets.zero,
      builder: (BuildContext _) {
        return ProjectSelectionModalContent(
          categoryId: categoryId,
          currentProjectId: project?.meta.id,
          onProjectSelected: (selectedProject) {
            final repository = ref.read(projectRepositoryProvider);
            if (selectedProject != null) {
              repository.linkTaskToProject(
                projectId: selectedProject.meta.id,
                taskId: widget.taskId,
              );
            } else {
              repository.unlinkTaskFromProject(widget.taskId);
            }
          },
        );
      },
    );
  }

  List<Widget> _buildLabelChips(Task task) {
    final cache = getIt<EntitiesCacheService>();
    final labelIds = task.meta.labelIds ?? <String>[];
    final showPrivate = cache.showPrivateEntries;

    return labelIds
        .map(cache.getLabelById)
        .where((label) => label != null)
        .where((label) => showPrivate || !(label!.private ?? false))
        .map(
          (label) => TaskShowcaseLabelChip(
            label: label!.name,
            color: colorFromCssHex(label.color),
            outlined: true,
          ),
        )
        .toList();
  }
}
