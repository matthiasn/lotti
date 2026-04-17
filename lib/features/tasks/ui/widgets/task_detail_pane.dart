import 'package:flutter/material.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/design_system/components/navigation/design_system_showcase_mobile_detail_header.dart';
import 'package:lotti/features/design_system/components/scrollbars/design_system_scrollbar.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tasks/ui/model/task_list_detail_models.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_palette.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_shared_widgets.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/color.dart';

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
        _AiSummaryCard(summary: record.aiSummary),
        SizedBox(height: tokens.spacing.step4),
        _DescriptionCard(description: record.description),
        SizedBox(height: tokens.spacing.step4),
        _TimeTrackerCard(record: record),
        SizedBox(height: tokens.spacing.step4),
        _ChecklistCard(record: record),
        SizedBox(height: tokens.spacing.step4),
        _AudioCard(entries: record.audioEntries),
      ],
    );
  }
}

class _AiSummaryCard extends StatelessWidget {
  const _AiSummaryCard({required this.summary});

  final String summary;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF0E2534),
        borderRadius: BorderRadius.circular(tokens.radii.l),
        border: Border.all(
          color: TaskShowcasePalette.accent(context).withValues(alpha: 0.4),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.step5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.messages.aiTaskSummaryTitle,
                    style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: tokens.spacing.step3,
                      vertical: tokens.spacing.step2,
                    ),
                    child: Text(
                      context.messages.taskShowcaseReadMore,
                      style: tokens.typography.styles.subtitle.subtitle2
                          .copyWith(
                            color: Colors.white,
                          ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: tokens.spacing.step4),
            Text(
              summary,
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: Colors.white.withValues(alpha: 0.92),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DescriptionCard extends StatelessWidget {
  const _DescriptionCard({required this.description});

  final String description;

  @override
  Widget build(BuildContext context) {
    return TaskShowcaseCard(
      title: context.messages.taskShowcaseTaskDescription,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.expand_less_rounded,
            color: TaskShowcasePalette.mediumText(context),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.more_vert_rounded,
            color: TaskShowcasePalette.mediumText(context),
          ),
        ],
      ),
      child: Text(
        description,
        style: context.designTokens.typography.styles.body.bodyMedium.copyWith(
          color: TaskShowcasePalette.highText(context),
          height: 1.5,
        ),
      ),
    );
  }
}

class _TimeTrackerCard extends StatelessWidget {
  const _TimeTrackerCard({required this.record});

  final TaskRecord record;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return TaskShowcaseCard(
      title: context.messages.taskShowcaseTimeTracker,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer_outlined,
            size: 18,
            color: TaskShowcasePalette.success(context),
          ),
          SizedBox(width: tokens.spacing.step1),
          Text(
            record.trackedDurationLabel,
            style: tokens.typography.styles.subtitle.subtitle2.copyWith(
              color: TaskShowcasePalette.success(context),
            ),
          ),
          SizedBox(width: tokens.spacing.step2),
          Icon(
            Icons.expand_less_rounded,
            color: TaskShowcasePalette.mediumText(context),
          ),
        ],
      ),
      child: Column(
        children: [
          for (
            var index = 0;
            index < record.trackerEntries.length;
            index++
          ) ...[
            _TimeEntryTile(entry: record.trackerEntries[index]),
            if (index < record.trackerEntries.length - 1)
              Divider(color: TaskShowcasePalette.border(context)),
          ],
        ],
      ),
    );
  }
}

class _TimeEntryTile extends StatelessWidget {
  const _TimeEntryTile({required this.entry});

  final TaskShowcaseTimeEntry entry;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.step3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.circle_outlined,
                      size: 14,
                      color: TaskShowcasePalette.mediumText(context),
                    ),
                    SizedBox(width: tokens.spacing.step1),
                    Expanded(
                      child: Text(
                        entry.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tokens.typography.styles.subtitle.subtitle2
                            .copyWith(
                              color: TaskShowcasePalette.highText(context),
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.timer_outlined,
                size: 14,
                color: TaskShowcasePalette.highText(context),
              ),
              SizedBox(width: tokens.spacing.step1),
              Text(
                entry.durationLabel,
                style: tokens.typography.styles.body.bodySmall.copyWith(
                  color: TaskShowcasePalette.highText(context),
                ),
              ),
              SizedBox(width: tokens.spacing.step1),
              Icon(
                Icons.more_vert_rounded,
                size: 16,
                color: TaskShowcasePalette.mediumText(context),
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.step1),
          Text(
            entry.subtitle,
            style: tokens.typography.styles.others.caption.copyWith(
              color: TaskShowcasePalette.lowText(context),
            ),
          ),
          SizedBox(height: tokens.spacing.step2),
          Text(
            entry.note,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: TaskShowcasePalette.mediumText(context),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChecklistCard extends StatelessWidget {
  const _ChecklistCard({required this.record});

  final TaskRecord record;

  @override
  Widget build(BuildContext context) {
    final completedCount = record.checklistItems
        .where((item) => item.done)
        .length;
    final totalCount = record.checklistItems.length;
    final tokens = context.designTokens;

    return TaskShowcaseCard(
      title: context.messages.taskShowcaseTodos,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.messages.taskShowcaseCompletedCount(
              completedCount,
              totalCount,
            ),
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: TaskShowcasePalette.mediumText(context),
            ),
          ),
          SizedBox(width: tokens.spacing.step2),
          Icon(
            Icons.expand_less_rounded,
            color: TaskShowcasePalette.mediumText(context),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TaskShowcaseSectionPill(
                icon: Icons.checklist_rounded,
                label: context.messages.taskStatusOpen,
                active: true,
              ),
              SizedBox(width: tokens.spacing.step2),
              TaskShowcaseSectionPill(
                icon: Icons.view_list_rounded,
                label: context.messages.taskStatusAll,
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.step4),
          for (
            var index = 0;
            index < record.checklistItems.length;
            index++
          ) ...[
            Row(
              children: [
                Icon(
                  record.checklistItems[index].done
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded,
                  color: record.checklistItems[index].done
                      ? TaskShowcasePalette.success(context)
                      : TaskShowcasePalette.mediumText(context),
                ),
                SizedBox(width: tokens.spacing.step2),
                Expanded(
                  child: Text(
                    record.checklistItems[index].title,
                    style: tokens.typography.styles.body.bodyMedium.copyWith(
                      color: TaskShowcasePalette.highText(context),
                    ),
                  ),
                ),
              ],
            ),
            if (index < record.checklistItems.length - 1)
              SizedBox(height: tokens.spacing.step3),
          ],
          SizedBox(height: tokens.spacing.step4),
          DecoratedBox(
            decoration: BoxDecoration(
              color: TaskShowcasePalette.page(context),
              borderRadius: BorderRadius.circular(tokens.radii.m),
              border: Border.all(color: TaskShowcasePalette.border(context)),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spacing.step3,
                vertical: tokens.spacing.step3,
              ),
              child: Text(
                context.messages.checklistAddItem,
                style: tokens.typography.styles.body.bodySmall.copyWith(
                  color: TaskShowcasePalette.lowText(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AudioCard extends StatelessWidget {
  const _AudioCard({required this.entries});

  final List<TaskShowcaseAudioEntry> entries;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return TaskShowcaseCard(
      title: context.messages.audioRecordings,
      trailing: Text(
        context.messages.taskShowcaseRecordingsCount(entries.length),
        style: tokens.typography.styles.body.bodySmall.copyWith(
          color: TaskShowcasePalette.info(context),
        ),
      ),
      child: Column(
        children: [
          for (var index = 0; index < entries.length; index++) ...[
            _AudioEntryTile(entry: entries[index]),
            if (index < entries.length - 1)
              Divider(color: TaskShowcasePalette.border(context)),
          ],
        ],
      ),
    );
  }
}

class _AudioEntryTile extends StatelessWidget {
  const _AudioEntryTile({required this.entry});

  final TaskShowcaseAudioEntry entry;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.step3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.title,
                  style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                    color: TaskShowcasePalette.highText(context),
                  ),
                ),
              ),
              Text(
                entry.durationLabel,
                style: tokens.typography.styles.others.caption.copyWith(
                  color: TaskShowcasePalette.lowText(context),
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.step1),
          Text(
            entry.subtitle,
            style: tokens.typography.styles.others.caption.copyWith(
              color: TaskShowcasePalette.lowText(context),
            ),
          ),
          SizedBox(height: tokens.spacing.step3),
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: TaskShowcasePalette.page(context),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.play_arrow_rounded,
                  size: 18,
                  color: TaskShowcasePalette.highText(context),
                ),
              ),
              SizedBox(width: tokens.spacing.step3),
              Expanded(
                child: TaskShowcaseWaveform(samples: entry.waveform),
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.step3),
          Text(
            entry.transcriptPreview,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: TaskShowcasePalette.mediumText(context),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
