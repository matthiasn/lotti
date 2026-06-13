import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tasks/ui/model/task_list_detail_models.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_palette.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_shared_widgets.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

class AiSummaryCard extends StatelessWidget {
  const AiSummaryCard({required this.summary, super.key});

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

class DescriptionCard extends StatelessWidget {
  const DescriptionCard({required this.description, super.key});

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

class TimeTrackerCard extends StatelessWidget {
  const TimeTrackerCard({required this.record, super.key});

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

class ChecklistCard extends StatelessWidget {
  const ChecklistCard({required this.record, super.key});

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

class AudioCard extends StatelessWidget {
  const AudioCard({required this.entries, super.key});

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
