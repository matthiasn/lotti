import 'package:flutter/material.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/design_system/components/navigation/design_system_showcase_mobile_detail_header.dart';
import 'package:lotti/features/design_system/components/scrollbars/design_system_scrollbar.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tasks/ui/model/task_list_detail_models.dart';
import 'package:lotti/features/tasks/ui/widgets/task_detail_cards.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_palette.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_shared_widgets.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/color.dart';

/// Desktop task-detail pane: a scrollable [TaskShowcaseDetailContent] with a
/// pinned desktop action bar overlaid at the bottom. `showLeadingBorder` draws
/// the divider between the list pane and this detail pane.
class TaskDetailPane extends StatelessWidget {
  const TaskDetailPane({
    required this.record,
    this.showLeadingBorder = true,
    super.key,
  });

  final TaskRecord record;
  final bool showLeadingBorder;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.designTokens.colors.background.level01,
        border: Border(
          left: showLeadingBorder
              ? BorderSide(color: TaskShowcasePalette.border(context))
              : BorderSide.none,
        ),
      ),
      child: Stack(
        children: [
          DesignSystemScrollbar(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 140),
              child: TaskShowcaseDetailContent(record: record),
            ),
          ),
          const TaskShowcaseDesktopActionBar(),
        ],
      ),
    );
  }
}

/// The full task-detail body: hero banner, header (title, priority, category,
/// labels, status), the jump-to-section pills, and the stacked detail cards.
/// Adapts between a wide two-column layout and a `compact` single-column
/// mobile layout (with a back header) based on `compact` and available width.
class TaskShowcaseDetailContent extends StatelessWidget {
  const TaskShowcaseDetailContent({
    required this.record,
    this.compact = false,
    this.onBack,
    super.key,
  });

  final TaskRecord record;
  final bool compact;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return LayoutBuilder(
      builder: (context, constraints) {
        final sectionPills = _sectionPills(context);
        final useCompactDetailLayout = compact || constraints.maxWidth < 720;
        final useCompactHeader = compact || constraints.maxWidth < 520;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (compact) ...[
              Padding(
                padding: EdgeInsets.fromLTRB(
                  tokens.spacing.step4,
                  tokens.spacing.step3,
                  tokens.spacing.step4,
                  0,
                ),
                child: DesignSystemShowcaseMobileDetailHeader(
                  foregroundColor: TaskShowcasePalette.highText(context),
                  onBack: onBack,
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TaskShowcaseHeroBanner(height: 176),
              ),
            ] else
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: TaskShowcaseHeroBanner(height: 176),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 16 : 24,
                20,
                compact ? 16 : 24,
                compact ? 24 : 32,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TaskDetailHeader(
                    record: record,
                    compact: useCompactHeader,
                  ),
                  SizedBox(height: useCompactDetailLayout ? 16 : 24),
                  if (useCompactDetailLayout) ...[
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (
                            var index = 0;
                            index < sectionPills.length;
                            index++
                          ) ...[
                            sectionPills[index],
                            if (index < sectionPills.length - 1)
                              SizedBox(width: tokens.spacing.step2),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(height: tokens.spacing.step4),
                    _TaskDetailCardsColumn(record: record),
                  ] else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 136,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.messages.taskShowcaseJumpToSection,
                                style: tokens.typography.styles.others.caption
                                    .copyWith(
                                      color: TaskShowcasePalette.mediumText(
                                        context,
                                      ),
                                    ),
                              ),
                              SizedBox(height: tokens.spacing.step3),
                              for (
                                var index = 0;
                                index < sectionPills.length;
                                index++
                              ) ...[
                                sectionPills[index],
                                if (index < sectionPills.length - 1)
                                  SizedBox(height: tokens.spacing.step2),
                              ],
                            ],
                          ),
                        ),
                        SizedBox(width: tokens.spacing.step5),
                        Expanded(
                          child: _TaskDetailCardsColumn(record: record),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _sectionPills(BuildContext context) {
    final items = [
      (
        context.messages.addActionAddTimer,
        Icons.timer_outlined,
        true,
      ),
      (
        context.messages.taskShowcaseTodo,
        Icons.check_box_outlined,
        false,
      ),
      (
        context.messages.taskShowcaseAudio,
        Icons.mic_none_rounded,
        false,
      ),
      (
        context.messages.images,
        Icons.photo_outlined,
        false,
      ),
      (
        context.messages.taskShowcaseLinked,
        Icons.subdirectory_arrow_right_rounded,
        false,
      ),
    ];

    return items
        .map(
          (item) => TaskShowcaseSectionPill(
            icon: item.$2,
            label: item.$1,
            active: item.$3,
          ),
        )
        .toList();
  }
}

class _TaskDetailHeader extends StatelessWidget {
  const _TaskDetailHeader({
    required this.record,
    required this.compact,
  });

  final TaskRecord record;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final category = record.category;
    final categoryColor = category.color ?? defaultCategoryColorHex;
    final due = record.task.data.due;

    final metadata = Wrap(
      spacing: tokens.spacing.step2,
      runSpacing: tokens.spacing.step2,
      children: [
        TaskShowcaseCategoryChip(
          label: category.name,
          icon: category.icon?.iconData ?? Icons.label_outline,
          colorHex: categoryColor,
        ),
        if (due != null)
          TaskShowcaseMetaChip(
            icon: Icons.watch_later_outlined,
            label: context.messages.taskShowcaseDueDate(
              MaterialLocalizations.of(context).formatShortDate(due),
            ),
          ),
        for (final label in record.labels)
          TaskShowcaseLabelChip(
            label: label.label,
            color: label.color,
            outlined: true,
          ),
      ],
    );

    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: tokens.spacing.step2,
          runSpacing: tokens.spacing.step2,
          children: [
            Text(
              record.task.data.title,
              style:
                  (compact
                          ? tokens.typography.styles.heading.heading3
                          : tokens.typography.styles.heading.heading2)
                      .copyWith(color: TaskShowcasePalette.highText(context)),
            ),
            TaskShowcasePriorityGlyph(
              priority: record.task.data.priority,
              size: compact ? 18 : 20,
            ),
            Text(
              record.task.data.priority.short,
              style: tokens.typography.styles.heading.heading3.copyWith(
                color: record.task.data.priority.colorForBrightness(
                  Theme.of(context).brightness,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: tokens.spacing.step2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_open_rounded,
              size: 16,
              color: TaskShowcasePalette.mediumText(context),
            ),
            SizedBox(width: tokens.spacing.step1),
            Flexible(
              child: Text(
                record.projectTitle,
                overflow: TextOverflow.ellipsis,
                style: tokens.typography.styles.body.bodySmall.copyWith(
                  color: TaskShowcasePalette.mediumText(context),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: tokens.spacing.step3),
        metadata,
      ],
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleBlock,
          SizedBox(height: tokens.spacing.step4),
          Align(
            alignment: Alignment.centerRight,
            child: TaskShowcaseStatusLabel(
              status: record.task.data.status,
              expanded: true,
            ),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: titleBlock),
        SizedBox(width: tokens.spacing.step4),
        Column(
          children: [
            Icon(
              Icons.more_vert_rounded,
              color: TaskShowcasePalette.mediumText(context),
            ),
            SizedBox(height: tokens.spacing.step5),
            TaskShowcaseStatusLabel(
              status: record.task.data.status,
              expanded: true,
            ),
          ],
        ),
      ],
    );
  }
}

class _TaskDetailCardsColumn extends StatelessWidget {
  const _TaskDetailCardsColumn({required this.record});

  final TaskRecord record;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AiSummaryCard(summary: record.aiSummary),
        SizedBox(height: tokens.spacing.step4),
        DescriptionCard(description: record.description),
        SizedBox(height: tokens.spacing.step4),
        TimeTrackerCard(record: record),
        SizedBox(height: tokens.spacing.step4),
        ChecklistCard(record: record),
        SizedBox(height: tokens.spacing.step4),
        AudioCard(entries: record.audioEntries),
      ],
    );
  }
}
