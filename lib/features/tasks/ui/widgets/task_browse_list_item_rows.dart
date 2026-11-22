import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/journal_page_state.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/classes/task_search_hit.dart';
import 'package:lotti/features/categories/ui/widgets/category_color_icon.dart';
import 'package:lotti/features/design_system/components/lists/grouped_card_row_surface.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/ui/widgets/time_recording_icon.dart';
import 'package:lotti/features/keyboard/domain/app_command.dart';
import 'package:lotti/features/keyboard/domain/app_command_handler.dart';
import 'package:lotti/features/keyboard/ui/app_command_scope.dart';
import 'package:lotti/features/keyboard/ui/list_detail_focus_traversal.dart';
import 'package:lotti/features/tasks/state/task_live_data_provider.dart';
import 'package:lotti/features/tasks/state/task_one_liner_provider.dart';
import 'package:lotti/features/tasks/ui/cover_art_thumbnail.dart';
import 'package:lotti/features/tasks/ui/due_date_text.dart';
import 'package:lotti/features/tasks/ui/model/task_browse_models.dart';
import 'package:lotti/features/tasks/ui/model/task_browse_row_interactions.dart';
import 'package:lotti/features/tasks/ui/widgets/task_search_snippet.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_palette.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_shared_widgets.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/task_progress_controller.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/utils/color.dart';
import 'package:material_ui/material_ui.dart';

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

    final row = DecoratedBox(
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
              if (interaction.showDividerBelow)
                Divider(
                  key: ValueKey(
                    'task-browse-divider-${entry.task.meta.id}',
                  ),
                  height: 1,
                  thickness: 1,
                  color: TaskShowcasePalette.border(context),
                )
              else
                SizedBox(
                  key: ValueKey(
                    'task-browse-divider-slot-${entry.task.meta.id}',
                  ),
                  height: 1,
                ),
          ],
        ),
      ),
    );
    final detailFocusController = ListDetailFocusTraversal.maybeOf(context);
    if (detailFocusController == null) return row;

    return AppCommandScope(
      handlers: {
        AppCommandId.expand: AppCommandHandler(
          invoke: (_) {
            onTap();
            detailFocusController.focusDetails();
          },
        ),
      },
      child: row,
    );
  }
}

/// The inner layout of a task row, in three tiers so the title leads: optional
/// cover art, the title, the agent's one-liner on one line, then one quiet meta
/// line (status, priority word, created and due dates, search distance, the
/// category swatch and name, and tracked time once there is any). Watches `taskLiveDataProvider` and `taskOneLinerProvider` (using
/// `.value` to keep stale data during reloads) so the row updates in place.
class TaskRowContent extends ConsumerWidget {
  const TaskRowContent({
    required this.task,
    required this.sortOption,
    required this.showCreationDate,
    required this.showDueDate,
    required this.showCoverArt,
    required this.showStatus,
    this.groupedBySort = true,
    this.searchHit,
    this.vectorDistance,
    this.categoryNameOverride,
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

  /// Whether the row sits in a section of [sortOption] (a priority, a date),
  /// which then states what the row's own chip would. False in search
  /// results, whose one section states nothing, so every chip shows.
  final bool groupedBySort;

  /// Where a search found the task, shown under its title.
  final TaskSearchHit? searchHit;
  final double? vectorDistance;
  final String? categoryNameOverride;
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
        categoryNameOverride == null || categoryColorHexOverride == null
        ? getIt<EntitiesCacheService>().getCategoryById(
            liveTask.meta.categoryId,
          )
        : null;
    final categoryName =
        categoryNameOverride ??
        category?.name ??
        context.messages.tasksQuickFilterUnassignedLabel;
    // On large text the thumbnail steps aside so the title keeps its measure.
    final largeText =
        MediaQuery.textScalerOf(context).scale(1) >= TextScales.large;
    final coverArtId = showCoverArt && !largeText
        ? liveTask.data.coverArtId
        : null;
    // One quiet meta line under the title: every fact at the caption tier, so
    // the title is the one thing that leads the row. Tracked time comes last
    // because it renders nothing until time has been tracked.
    final metadata = <Widget>[
      if (showStatus) TaskShowcaseStatusLabel(status: liveTask.data.status),
      if (!groupedBySort || sortOption != TaskSortOption.byPriority)
        _PriorityMeta(priority: liveTask.data.priority),
      ..._dateAndSearchMeta(context, liveTask),
      _CategoryMeta(
        label: categoryName,
        color: colorFromCssHex(
          categoryColorHexOverride ??
              category?.color ??
              defaultCategoryColorHex,
        ),
      ),
      _TrackedDurationMeta(
        taskId: liveTask.meta.id,
        labelOverride: trackedDurationLabelOverride,
      ),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (coverArtId != null) ...[
          Padding(
            padding: EdgeInsetsDirectional.only(end: tokens.spacing.step4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(tokens.radii.s),
              child: CoverArtThumbnail(
                imageId: coverArtId,
                size: ControlSizes.mediaThumbnail,
                cropX: liveTask.data.coverArtCropX,
              ),
            ),
          ),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TaskBrowseTitle(title: liveTask.data.title, maxLines: 2),
              if (oneLiner != null && oneLiner.isNotEmpty) ...[
                SizedBox(height: tokens.spacing.step1),
                Text(
                  oneLiner,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.typography.styles.others.caption.copyWith(
                    color: tokens.colors.aiCard.accent,
                  ),
                ),
              ],
              if (searchHit case final hit?) ...[
                SizedBox(height: tokens.spacing.step2),
                TaskSearchSnippet(hit: hit),
              ],
              SizedBox(height: tokens.spacing.step3),
              Wrap(
                spacing: tokens.spacing.step4,
                runSpacing: tokens.spacing.step2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: metadata,
              ),
            ],
          ),
        ),
        TimeRecordingIcon(taskId: liveTask.meta.id),
      ],
    );
  }

  /// Created date, due date and search distance, as meta-line items.
  List<Widget> _dateAndSearchMeta(BuildContext context, Task liveTask) {
    final localizations = MaterialLocalizations.of(context);
    final widgets = <Widget>[];

    if (showCreationDate &&
        (!groupedBySort || sortOption != TaskSortOption.byDate)) {
      widgets.add(
        _MetaText(
          icon: LottiIcons.today,
          label: localizations.formatMediumDate(liveTask.meta.dateFrom),
        ),
      );
    }

    // Grouped by due date, the section header already states each row's due
    // date (or its absence), so the footer stays quiet there.
    final showDueFooter =
        showDueDate &&
        (!groupedBySort || sortOption != TaskSortOption.byDueDate) &&
        liveTask.data.status is! TaskDone &&
        liveTask.data.status is! TaskRejected;
    if (showDueFooter) {
      final due = liveTask.data.due;
      widgets.add(
        due != null
            ? DueDateText(dueDate: due)
            // An open task with no due date says so, in the quiet meta-chip
            // grey: a missing deadline is information too, but it must never
            // compete with the orange and red of a deadline due or passed.
            : _MetaText(
                icon: LottiIcons.calendar,
                label: context.messages.taskNoDueDateLabel,
              ),
      );
    }

    if (vectorDistance case final distance?) {
      widgets.add(
        _MetaText(icon: LottiIcons.hub, label: distance.toStringAsFixed(2)),
      );
    }

    return widgets;
  }
}

/// Compact row content: the task title alone, one line. Used by the
/// tasks list's compact density mode, where every other card element (time,
/// category chip, status pill, cover art, one-liner) is deliberately dropped
/// so the list reads as a terse line-per-task index. Still watches
/// `taskLiveDataProvider` (via `.value` to keep stale data during reloads)
/// so a rename in the detail pane updates the row in place.
class TaskCompactRowContent extends ConsumerWidget {
  const TaskCompactRowContent({required this.task, super.key});

  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveTask =
        ref.watch(taskLiveDataProvider(task.meta.id)).value ?? task;
    // The Row + Expanded stretches the row to the card's full width and
    // left-aligns the title: a bare Text would let the shell's Column
    // center-align it — and shrink-wrap the last row of a section, which has
    // no full-width divider forcing the card wide.
    return Row(
      children: [
        Expanded(
          child: _TaskBrowseTitle(title: liveTask.data.title, maxLines: 1),
        ),
      ],
    );
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
      style: tokens.typography.styles.subtitle.subtitle1.copyWith(
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
        SizedBox(width: context.designTokens.spacing.step2),
        Flexible(
          child: Text(
            priority.localizedLabel(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textStyle,
          ),
        ),
      ],
    );
  }
}

/// A glyph and a caption in medium ink: one quiet item of the row's meta line.
class _MetaText extends StatelessWidget {
  const _MetaText({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final color = TaskShowcasePalette.mediumText(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: IconSizes.xs, color: color),
        SizedBox(width: tokens.spacing.step2),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tokens.typography.styles.others.caption.copyWith(
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

/// The task's category as its colour swatch and name: colour marks the
/// category without becoming the loudest fill on the row.
class _CategoryMeta extends StatelessWidget {
  const _CategoryMeta({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ColorIcon(color, size: IconSizes.xs),
        SizedBox(width: tokens.spacing.step2),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tokens.typography.styles.others.caption.copyWith(
              color: TaskShowcasePalette.mediumText(context),
            ),
          ),
        ),
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
    // "0h 0m" on every untouched task is noise, not information.
    if (progress == Duration.zero) return const SizedBox.shrink();
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
          LottiIcons.timelapse,
          size: 16,
          color: TaskShowcasePalette.lowText(context),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textStyle,
          ),
        ),
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
          Text(_sectionTitle(context, sectionKey), style: textStyle),
        ],
      );
    }

    return Text(_sectionTitle(context, sectionKey), style: textStyle);
  }
}

String _sectionTitle(BuildContext context, TaskBrowseSectionKey sectionKey) {
  final materialLocalizations = MaterialLocalizations.of(context);

  return switch (sectionKey.kind) {
    TaskBrowseSectionKind.results => context.messages.tasksSearchResultsSection,
    TaskBrowseSectionKind.relatedByMeaning =>
      context.messages.searchRelatedByMeaningSection,
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

String _prioritySectionTitle(BuildContext context, TaskPriority priority) =>
    '${priority.short} ${priority.localizedLabel(context)}';
