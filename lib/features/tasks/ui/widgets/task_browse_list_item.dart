import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/tasks/ui/model/task_browse_models.dart';
import 'package:lotti/features/tasks/ui/widgets/task_browse_list_item_rows.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_palette.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

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
    final borderSide = BorderSide(color: TaskShowcasePalette.border(context));
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
              padding: EdgeInsets.only(
                top: tokens.spacing.step4,
                bottom: tokens.spacing.step4,
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
                      ),
                    ),
                ],
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
