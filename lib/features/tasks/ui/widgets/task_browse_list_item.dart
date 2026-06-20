import 'package:flutter/material.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/tasks/ui/model/task_browse_models.dart';
import 'package:lotti/features/tasks/ui/widgets/task_browse_list_item_rows.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_palette.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// A single row in the browseable task list. Renders an optional section
/// header (with task count) for the first entry of a section, then the task
/// card via [TaskBrowseRowShell] + [TaskRowContent], applying grouped-card
/// borders and radii based on the entry's first/last-in-section flags. When a
/// `hoveredTaskIdNotifier` is supplied the card tracks hover state.
class TaskBrowseListItem extends StatelessWidget {
  const TaskBrowseListItem({
    required this.entry,
    required this.sortOption,
    required this.showCreationDate,
    required this.showDueDate,
    required this.showCoverArt,
    required this.onTap,
    this.vectorDistance,
    this.categoryNameOverride,
    this.categoryIconOverride,
    this.categoryColorHexOverride,
    this.trackedDurationLabelOverride,
    this.sectionHeaderTitleOverride,
    this.previousTaskIdInSection,
    this.nextTaskIdInSection,
    this.selectedTaskId,
    this.hoveredTaskIdNotifier,
    this.showStatus = true,
    this.showCategoryChip = true,
    super.key,
  });

  final TaskBrowseEntry entry;
  final TaskSortOption sortOption;
  final bool showCreationDate;
  final bool showDueDate;
  final bool showCoverArt;
  final double? vectorDistance;
  final String? categoryNameOverride;
  final IconData? categoryIconOverride;
  final String? categoryColorHexOverride;
  final String? trackedDurationLabelOverride;
  final String? sectionHeaderTitleOverride;
  final String? previousTaskIdInSection;
  final String? nextTaskIdInSection;
  final String? selectedTaskId;
  final ValueNotifier<String?>? hoveredTaskIdNotifier;
  final VoidCallback onTap;

  /// When false, the trailing status pill is omitted from the card. The
  /// caller should set this when the active status filter has narrowed the
  /// list down to a single status — repeating it on every row is noise.
  final bool showStatus;

  /// When false, the per-row category chip is omitted. The caller sets this
  /// when the list is already scoped to a single category — the chip would
  /// otherwise repeat the same value on every row, adding noise, not signal.
  final bool showCategoryChip;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final rowPadding = EdgeInsets.symmetric(
      horizontal: tokens.spacing.step4,
      vertical: tokens.spacing.step4,
    );
    final borderRadius = BorderRadius.vertical(
      top: entry.isFirstInSection
          ? Radius.circular(tokens.radii.sectionCards)
          : Radius.zero,
      bottom: entry.isLastInSection
          ? Radius.circular(tokens.radii.sectionCards)
          : Radius.zero,
    );
    // The priority colour is carried boldly by the filled header band below;
    // the container keeps a neutral, slightly-stronger hairline that lifts the
    // card off the dark page (figure-ground) without spending priority colour
    // a second, fainter time on the edge.
    final sectionPriority = entry.sectionKey.priority;
    final priorityColor = sectionPriority?.colorForBrightness(
      Theme.of(context).brightness,
    );
    // Graduate the band fill by rank so the urgent band genuinely dominates:
    // a uniform alpha let the intrinsically-brighter orange out-shout the
    // darker red. Stronger for P0, fading to a whisper for P3.
    final bandAlpha = switch (sectionPriority) {
      TaskPriority.p0Urgent => 0.28,
      TaskPriority.p1High => 0.14,
      TaskPriority.p2Medium => 0.10,
      TaskPriority.p3Low => 0.08,
      null => 0.0,
    };
    final borderSide = BorderSide(
      color: TaskShowcasePalette.containerBorder(context),
    );
    final decoration = BoxDecoration(
      color: TaskShowcasePalette.surface(context),
      borderRadius: borderRadius,
      border: Border(
        top: entry.isFirstInSection ? borderSide : BorderSide.none,
        left: borderSide,
        right: borderSide,
        bottom: entry.isLastInSection ? borderSide : BorderSide.none,
      ),
    );

    return Padding(
      padding: EdgeInsets.only(
        bottom: entry.isLastInSection ? tokens.spacing.step3 : 0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (entry.showSectionHeader)
            Padding(
              // Asymmetric: a generous gap ABOVE the header separates it from
              // the previous priority group, while a tight gap below binds the
              // header to the first card it labels. This makes the three
              // priority bands chunk pre-attentively instead of reading as one
              // continuous stream.
              padding: EdgeInsets.only(
                top: tokens.spacing.step6,
                bottom: tokens.spacing.step3,
              ),
              child: Container(
                // A filled priority-tinted band makes the colour *land*: the
                // urgent (red) band visibly outweighs the high/medium groups
                // regardless of how many cards each holds. Horizontal padding
                // matches the card content inset so the header text shares the
                // cards' left edge. Date-sorted sections get no band.
                decoration: priorityColor != null
                    ? BoxDecoration(
                        color: priorityColor.withValues(alpha: bandAlpha),
                        borderRadius: BorderRadius.circular(tokens.radii.s),
                      )
                    : null,
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.spacing.step4,
                  vertical: tokens.spacing.step2,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SectionHeaderTitle(
                        sectionKey: entry.sectionKey,
                        titleOverride: sectionHeaderTitleOverride,
                      ),
                    ),
                    if (entry.sectionCount case final count?)
                      Text(
                        context.messages.taskShowcaseTaskCount(count),
                        style: tokens.typography.styles.others.caption.copyWith(
                          color: TaskShowcasePalette.mediumText(context),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          if (hoveredTaskIdNotifier case final notifier?)
            ValueListenableBuilder<String?>(
              valueListenable: notifier,
              child: TaskRowContent(
                task: entry.task,
                sortOption: sortOption,
                showCreationDate: showCreationDate,
                showDueDate: showDueDate,
                showCoverArt: showCoverArt,
                showStatus: showStatus,
                showCategoryChip: showCategoryChip,
                vectorDistance: vectorDistance,
                categoryNameOverride: categoryNameOverride,
                categoryIconOverride: categoryIconOverride,
                categoryColorHexOverride: categoryColorHexOverride,
                trackedDurationLabelOverride: trackedDurationLabelOverride,
              ),
              builder: (context, hoveredTaskId, child) {
                return TaskBrowseRowShell(
                  entry: entry,
                  rowPadding: rowPadding,
                  borderRadius: borderRadius,
                  decoration: decoration,
                  previousTaskIdInSection: previousTaskIdInSection,
                  nextTaskIdInSection: nextTaskIdInSection,
                  selectedTaskId: selectedTaskId,
                  hoveredTaskId: hoveredTaskId,
                  hoveredTaskIdNotifier: notifier,
                  onTap: onTap,
                  child: child!,
                );
              },
            )
          else
            TaskBrowseRowShell(
              entry: entry,
              rowPadding: rowPadding,
              borderRadius: borderRadius,
              decoration: decoration,
              previousTaskIdInSection: previousTaskIdInSection,
              nextTaskIdInSection: nextTaskIdInSection,
              selectedTaskId: selectedTaskId,
              hoveredTaskId: null,
              hoveredTaskIdNotifier: null,
              onTap: onTap,
              child: TaskRowContent(
                task: entry.task,
                sortOption: sortOption,
                showCreationDate: showCreationDate,
                showDueDate: showDueDate,
                showCoverArt: showCoverArt,
                showStatus: showStatus,
                showCategoryChip: showCategoryChip,
                vectorDistance: vectorDistance,
                categoryNameOverride: categoryNameOverride,
                categoryIconOverride: categoryIconOverride,
                categoryColorHexOverride: categoryColorHexOverride,
                trackedDurationLabelOverride: trackedDurationLabelOverride,
              ),
            ),
        ],
      ),
    );
  }
}

/// The "+N more" affordance that closes a collapsed (capped) priority group.
/// It mirrors the grouped container's last-row surface — side and bottom
/// borders with a rounded bottom — so it reads as the final row of the group,
/// and toggles the section open via [onTap].
class TaskBrowseShowMoreRow extends StatelessWidget {
  const TaskBrowseShowMoreRow({
    required this.hiddenCount,
    required this.onTap,
    super.key,
  });

  final int hiddenCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final borderSide = BorderSide(
      color: TaskShowcasePalette.containerBorder(context),
    );
    final borderRadius = BorderRadius.vertical(
      bottom: Radius.circular(tokens.radii.sectionCards),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: tokens.spacing.step3),
      child: SizedBox(
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: TaskShowcasePalette.surface(context),
            borderRadius: borderRadius,
            border: Border(
              left: borderSide,
              right: borderSide,
              bottom: borderSide,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: borderRadius,
              onTap: onTap,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.spacing.step4,
                  vertical: tokens.spacing.step3,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.expand_more_rounded,
                      size: 18,
                      color: TaskShowcasePalette.mediumText(context),
                    ),
                    SizedBox(width: tokens.spacing.step2),
                    Text(
                      context.messages.taskShowcaseShowMore(hiddenCount),
                      style: tokens.typography.styles.others.caption.copyWith(
                        color: TaskShowcasePalette.mediumText(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
