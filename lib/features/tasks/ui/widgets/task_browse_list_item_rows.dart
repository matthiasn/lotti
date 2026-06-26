import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/design_system/components/lists/grouped_card_row_surface.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/tasks/state/task_live_data_provider.dart';
import 'package:lotti/features/tasks/state/task_one_liner_provider.dart';
import 'package:lotti/features/tasks/state/task_progress_controller.dart';
import 'package:lotti/features/tasks/ui/cover_art_thumbnail.dart';
import 'package:lotti/features/tasks/ui/due_date_text.dart';
import 'package:lotti/features/tasks/ui/model/task_browse_models.dart';
import 'package:lotti/features/tasks/ui/model/task_browse_row_interactions.dart';
import 'package:lotti/features/tasks/ui/time_recording_icon.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_palette.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_shared_widgets.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/utils/color.dart';

/// Tappable grouped-card surface that wraps a task row's [child] content.
/// Applies selection/hover fills, top/bottom overlap so adjacent rows in a
/// section merge visually, and renders a divider below the row unless it is
/// the last in its section. Drives the shared `hoveredTaskIdNotifier`.
class TaskBrowseRowShell extends StatelessWidget {
  const TaskBrowseRowShell({
    required this.entry,
    required this.rowPadding,
    required this.borderRadius,
    required this.decoration,
    required this.previousTaskIdInSection,
    required this.nextTaskIdInSection,
    required this.selectedTaskId,
    required this.hoveredTaskId,
    required this.hoveredTaskIdNotifier,
    required this.onTap,
    required this.child,
    super.key,
  });

  final TaskBrowseEntry entry;
  final EdgeInsets rowPadding;
  final BorderRadius borderRadius;
  final BoxDecoration decoration;
  final String? previousTaskIdInSection;
  final String? nextTaskIdInSection;
  final String? selectedTaskId;
  final String? hoveredTaskId;
  final ValueNotifier<String?>? hoveredTaskIdNotifier;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final interaction = buildTaskBrowseRowInteraction(
      taskId: entry.task.meta.id,
      previousTaskIdInSection: previousTaskIdInSection,
      nextTaskIdInSection: nextTaskIdInSection,
      selectedTaskId: selectedTaskId,
      hoveredTaskId: hoveredTaskId,
    );
    final selected = entry.task.meta.id == selectedTaskId;

    return DecoratedBox(
      decoration: decoration,
      child: GroupedCardRowSurface(
        rowKey: ValueKey('task-browse-row-${entry.task.meta.id}'),
        backgroundKey: ValueKey(
          'task-browse-row-background-${entry.task.meta.id}',
        ),
        selected: selected,
        hoverColor: TaskShowcasePalette.hoverFill(context),
        selectedColor: TaskShowcasePalette.selectedRow(context),
        padding: EdgeInsets.zero,
        topOverlap: interaction.topOverlap,
        bottomOverlap: interaction.bottomOverlap,
        backgroundBorderRadius: borderRadius,
        onHoverChanged: hoveredTaskIdNotifier == null
            ? null
            : (hovered) {
                if (hovered) {
                  hoveredTaskIdNotifier!.value = entry.task.meta.id;
                } else if (hoveredTaskIdNotifier!.value == entry.task.meta.id) {
                  hoveredTaskIdNotifier!.value = null;
                }
              },
        onTap: onTap,
        child: Column(
          children: [
            Padding(
              padding: rowPadding,
              child: child,
            ),
            if (!entry.isLastInSection)
              interaction.showDividerBelow
                  ? Divider(
                      key: ValueKey(
                        'task-browse-divider-${entry.task.meta.id}',
                      ),
                      height: 1,
                      thickness: 1,
                      color: TaskShowcasePalette.border(context),
                    )
                  : SizedBox(
                      key: ValueKey(
                        'task-browse-divider-slot-${entry.task.meta.id}',
                      ),
                      height: 1,
                    ),
          ],
        ),
      ),
    );
  }
}

/// The inner layout of a task row: optional cover art, title, AI one-liner
/// subtitle, a metadata wrap (priority, tracked duration, category chip), the
/// trailing status pill, and a footer of created-date/due-date/vector-distance
/// chips. Watches `taskLiveDataProvider` and `taskOneLinerProvider` (using
/// `.value` to keep stale data during reloads) so the row updates in place.
class TaskRowContent extends ConsumerWidget {
  const TaskRowContent({
    required this.task,
    required this.sortOption,
    required this.showCreationDate,
    required this.showDueDate,
    required this.showCoverArt,
    required this.showStatus,
    this.vectorDistance,
    this.categoryNameOverride,
    this.categoryIconOverride,
    this.categoryColorHexOverride,
    this.trackedDurationLabelOverride,
    super.key,
  });

  final Task task;
  final TaskSortOption sortOption;
  final bool showCreationDate;
  final bool showDueDate;
  final bool showCoverArt;
  final bool showStatus;
  final double? vectorDistance;
  final String? categoryNameOverride;
  final IconData? categoryIconOverride;
  final String? categoryColorHexOverride;
  final String? trackedDurationLabelOverride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;

    // Watch for live updates. When a task's title or other data changes in
    // the detail pane, this rebuilds the row in-place without needing a full
    // list refresh. Uses taskLiveDataProvider which is lightweight (just a DB
    // fetch + UpdateNotifications listener) unlike EntryController which
    // initialises focus nodes, hotkeys, editor state, etc.
    // Use .value to preserve stale data during loading states (e.g. when
    // invalidateSelf() triggers a re-fetch), avoiding a brief revert to the
    // paging-controller snapshot.
    final liveTask =
        ref.watch(taskLiveDataProvider(task.meta.id)).value ?? task;

    // Fetch AI-generated one-liner subtitle from the agent report.
    // Use .value to preserve stale data during loading/error states,
    // avoiding a brief disappearance and row reflow on invalidation.
    final oneLiner = ref.watch(taskOneLinerProvider(liveTask.meta.id)).value;

    final category =
        categoryNameOverride == null ||
            categoryIconOverride == null ||
            categoryColorHexOverride == null
        ? getIt<EntitiesCacheService>().getCategoryById(
            liveTask.meta.categoryId,
          )
        : null;
    final categoryName =
        categoryNameOverride ??
        category?.name ??
        context.messages.tasksQuickFilterUnassignedLabel;
    final categoryIcon =
        categoryIconOverride ??
        category?.icon?.iconData ??
        Icons.label_outline_rounded;
    final coverArtId = showCoverArt ? liveTask.data.coverArtId : null;
    final metadata = <Widget>[
      if (sortOption != TaskSortOption.byPriority)
        _PriorityMeta(priority: liveTask.data.priority),
      _TrackedDurationMeta(
        taskId: liveTask.meta.id,
        labelOverride: trackedDurationLabelOverride,
      ),
      TaskShowcaseCategoryChip(
        label: categoryName,
        icon: categoryIcon,
        colorHex:
            categoryColorHexOverride ??
            category?.color ??
            defaultCategoryColorHex,
      ),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (coverArtId != null) ...[
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(tokens.radii.s),
              child: CoverArtThumbnail(
                imageId: coverArtId,
                size: 72,
                cropX: liveTask.data.coverArtCropX,
              ),
            ),
          ),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TaskBrowseTitle(
                title: liveTask.data.title,
                maxLines: coverArtId == null ? 2 : 3,
              ),
              if (oneLiner != null && oneLiner.isNotEmpty) ...[
                SizedBox(height: tokens.spacing.step1),
                Text(
                  oneLiner,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.typography.styles.others.caption.copyWith(
                    color: TaskShowcasePalette.lowText(context),
                  ),
                ),
              ],
              SizedBox(height: tokens.spacing.step3),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: tokens.spacing.step3,
                      runSpacing: tokens.spacing.step3,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: metadata,
                    ),
                  ),
                  if (showStatus) ...[
                    SizedBox(width: tokens.spacing.step4),
                    TaskShowcaseStatusLabel(status: liveTask.data.status),
                  ],
                ],
              ),
              if (_footerChildren(context, liveTask).isNotEmpty) ...[
                SizedBox(height: tokens.spacing.step3),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _footerChildren(context, liveTask),
                ),
              ],
            ],
          ),
        ),
        TimeRecordingIcon(taskId: liveTask.meta.id),
      ],
    );
  }

  List<Widget> _footerChildren(BuildContext context, Task liveTask) {
    final localizations = MaterialLocalizations.of(context);
    final widgets = <Widget>[];

    if (showCreationDate && sortOption != TaskSortOption.byDate) {
      widgets.add(
        TaskShowcaseMetaChip(
          icon: Icons.calendar_today_outlined,
          label: localizations.formatMediumDate(liveTask.meta.dateFrom),
        ),
      );
    }

    final showDueFooter =
        showDueDate &&
        sortOption != TaskSortOption.byDueDate &&
        liveTask.data.due != null &&
        liveTask.data.status is! TaskDone &&
        liveTask.data.status is! TaskRejected;
    if (showDueFooter) {
      widgets.add(DueDateText(dueDate: liveTask.data.due!));
    }

    if (vectorDistance case final distance?) {
      widgets.add(
        TaskShowcaseMetaChip(
          icon: Icons.hub_outlined,
          label: distance.toStringAsFixed(2),
        ),
      );
    }

    return widgets;
  }
}

/// Title line for the task row. When the task has no title, renders a
/// localized `(untitled)` warning in the error color so the gap is obvious
/// in the list rather than silently collapsing to an empty row.
class _TaskBrowseTitle extends StatelessWidget {
  const _TaskBrowseTitle({required this.title, required this.maxLines});

  final String title;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final trimmed = title.trim();
    final isEmpty = trimmed.isEmpty;
    return Text(
      isEmpty ? context.messages.taskUntitled : trimmed,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: tokens.typography.styles.subtitle.subtitle2.copyWith(
        color: isEmpty
            ? TaskShowcasePalette.error(context)
            : TaskShowcasePalette.highText(context),
        fontWeight: FontWeight.w600,
        fontStyle: isEmpty ? FontStyle.italic : FontStyle.normal,
      ),
    );
  }
}

class _PriorityMeta extends StatelessWidget {
  const _PriorityMeta({required this.priority});

  final TaskPriority priority;

  @override
  Widget build(BuildContext context) {
    final textStyle = context.designTokens.typography.styles.others.caption
        .copyWith(color: TaskShowcasePalette.mediumText(context));

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TaskShowcasePriorityGlyph(priority: priority),
        const SizedBox(width: 6),
        Text(priority.short, style: textStyle),
      ],
    );
  }
}

class _TrackedDurationMeta extends ConsumerWidget {
  const _TrackedDurationMeta({
    required this.taskId,
    this.labelOverride,
  });

  final String taskId;
  final String? labelOverride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (labelOverride case final label?) {
      return _TrackedDurationMetaContent(label: label);
    }

    final progressState = ref.watch(taskProgressControllerProvider(taskId));
    final progress = switch (progressState) {
      AsyncData(:final value) => value?.progress ?? Duration.zero,
      _ => Duration.zero,
    };
    final hours = progress.inHours;
    final minutes = progress.inMinutes.remainder(60);
    final label = context.messages
        .designSystemMyDailyDurationHoursMinutesCompact(
          hours,
          minutes,
        );

    return _TrackedDurationMetaContent(label: label);
  }
}

class _TrackedDurationMetaContent extends StatelessWidget {
  const _TrackedDurationMetaContent({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final textStyle = context.designTokens.typography.styles.others.caption
        .copyWith(color: TaskShowcasePalette.lowText(context));

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.timelapse_rounded,
          size: 16,
          color: TaskShowcasePalette.lowText(context),
        ),
        const SizedBox(width: 6),
        Text(label, style: textStyle),
      ],
    );
  }
}

/// Renders a task-list section header title. Uses `titleOverride` when given,
/// otherwise derives the label from the section key — for priority sections it
/// shows the priority glyph plus its name, for date/due-date sections a
/// localized date string.
class SectionHeaderTitle extends StatelessWidget {
  const SectionHeaderTitle({
    required this.sectionKey,
    this.titleOverride,
    super.key,
  });

  final TaskBrowseSectionKey sectionKey;
  final String? titleOverride;

  @override
  Widget build(BuildContext context) {
    final textStyle = context.designTokens.typography.styles.others.caption
        .copyWith(color: TaskShowcasePalette.highText(context));

    if (titleOverride case final title?) {
      return Text(title, style: textStyle);
    }

    if (sectionKey.kind == TaskBrowseSectionKind.priority) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TaskShowcasePriorityGlyph(priority: sectionKey.priority!),
          const SizedBox(width: 6),
          Text(
            _prioritySectionTitle(context, sectionKey.priority!),
            style: textStyle,
          ),
        ],
      );
    }

    return Text(_sectionTitle(context, sectionKey), style: textStyle);
  }
}

String _sectionTitle(BuildContext context, TaskBrowseSectionKey sectionKey) {
  final materialLocalizations = MaterialLocalizations.of(context);

  return switch (sectionKey.kind) {
    TaskBrowseSectionKind.createdDate => materialLocalizations.formatMediumDate(
      sectionKey.date!,
    ),
    TaskBrowseSectionKind.dueDate => context.messages.taskDueDateWithDate(
      materialLocalizations.formatMediumDate(sectionKey.date!),
    ),
    TaskBrowseSectionKind.dueToday => context.messages.taskDueToday,
    TaskBrowseSectionKind.dueTomorrow => context.messages.taskDueTomorrow,
    TaskBrowseSectionKind.dueYesterday => context.messages.taskDueYesterday,
    TaskBrowseSectionKind.noDueDate => context.messages.taskNoDueDateLabel,
    TaskBrowseSectionKind.priority => _prioritySectionTitle(
      context,
      sectionKey.priority!,
    ),
  };
}

String _prioritySectionTitle(BuildContext context, TaskPriority priority) {
  final label = switch (priority) {
    TaskPriority.p0Urgent => context.messages.tasksPriorityP0,
    TaskPriority.p1High => context.messages.tasksPriorityP1,
    TaskPriority.p2Medium => context.messages.tasksPriorityP2,
    TaskPriority.p3Low => context.messages.tasksPriorityP3,
  };

  return '${priority.short} $label';
}
