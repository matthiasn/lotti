import 'package:flutter/material.dart';
import 'package:flutter_rating/flutter_rating.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/categories/ui/widgets/category_color_icon.dart';
import 'package:lotti/features/habits/ui/widgets/habit_completion_color_icon.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/habit_summary.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/health_summary.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/measurement_summary.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/survey_summary.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/workout_summary.dart';
import 'package:lotti/features/journal/ui/widgets/tags/tags_view_widget.dart';
import 'package:lotti/features/journal/ui/widgets/text_viewer_widget.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/features/tasks/ui/linked_duration.dart';
import 'package:lotti/features/tasks/ui/task_status.dart';
import 'package:lotti/features/tasks/ui/time_recording_icon.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/widgets/events/event_status.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

const double iconSize = 18;

class JournalCardTitle extends StatelessWidget {
  const JournalCardTitle({
    required this.item,
    required this.maxHeight,
    super.key,
    this.showLinkedDuration = false,
  });

  final JournalEntity item;
  final double maxHeight;
  final bool showLinkedDuration;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 5, bottom: 5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item is JournalEvent
                        ? dfShort.format(item.meta.dateFrom)
                        : dfShorter.format(item.meta.dateFrom),
                    style: context.textTheme.bodyMedium?.copyWith(
                      fontFeatures: [const FontFeature.tabularFigures()],
                      color: context.colorScheme.outline,
                    ),
                  ),
                  if (item is! ChecklistItem &&
                      item is! Checklist &&
                      item is! HabitCompletionEntry &&
                      item is! MeasurementEntry &&
                      item is! WorkoutEntry &&
                      item is! QuantitativeEntry &&
                      item is! SurveyEntry) ...[
                    const SizedBox(width: 20),
                    CategoryColorIcon(item.meta.categoryId, size: 12),
                  ],
                ],
              ),
              if (item is Task) TaskStatusWidget(item as Task),
              Row(
                children: [
                  Visibility(
                    visible: fromNullableBool(item.meta.private),
                    child: Icon(
                      MdiIcons.security,
                      color: context.colorScheme.error,
                      size: iconSize,
                    ),
                  ),
                  if (item is! JournalEvent)
                    Visibility(
                      visible: fromNullableBool(item.meta.starred),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(
                          MdiIcons.star,
                          color: starredGold,
                          size: iconSize,
                        ),
                      ),
                    ),
                  if (item is! JournalEvent)
                    Visibility(
                      visible: item.meta.flag == EntryFlag.import,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(
                          MdiIcons.flag,
                          color: context.colorScheme.error,
                          size: iconSize,
                        ),
                      ),
                    ),
                ],
              ),
              if (item is JournalEvent) ...[
                const SizedBox(width: 10),
                EventStatusWidget(
                  (item as JournalEvent).data.status,
                ),
                const SizedBox(width: 10),
                StarRating(
                  rating: (item as JournalEvent).data.stars,
                  size: 18,
                  allowHalfRating: true,
                ),
              ],
            ],
          ),
          TagsViewWidget(item: item),
          IgnorePointer(
            child: item.map(
              quantitative: (QuantitativeEntry qe) => HealthSummary(
                qe,
                showChart: false,
              ),
              journalAudio: (JournalAudio journalAudio) => TextViewerWidget(
                entryText: journalAudio.entryText,
                maxHeight: maxHeight,
              ),
              journalEntry: (JournalEntry journalEntry) => TextViewerWidget(
                entryText: journalEntry.entryText,
                maxHeight: maxHeight,
              ),
              journalImage: (JournalImage journalImage) => TextViewerWidget(
                entryText: journalImage.entryText,
                maxHeight: maxHeight,
              ),
              survey: (surveyEntry) => SurveySummary(
                surveyEntry,
                showChart: false,
              ),
              measurement: MeasurementSummary.new,
              task: (Task task) {
                final data = task.data;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        TimeRecordingIcon(
                          taskId: item.id,
                          padding: const EdgeInsets.only(right: 10),
                        ),
                        Flexible(
                          child: Text(
                            data.title,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: fontSizeLarge,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (showLinkedDuration) LinkedDuration(taskId: task.id),
                    TextViewerWidget(
                      entryText: task.entryText,
                      maxHeight: maxHeight,
                    ),
                  ],
                );
              },
              event: (JournalEvent event) {
                final data = event.data;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.title,
                      style: const TextStyle(
                        fontSize: fontSizeLarge,
                      ),
                    ),
                    TextViewerWidget(
                      entryText: event.entryText,
                      maxHeight: maxHeight,
                    ),
                  ],
                );
              },
              aiResponse: (AiResponseEntry aiResponse) => Container(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: GptMarkdown(aiResponse.data.response),
              ),
              workout: (workout) => WorkoutSummary(
                workout,
                showChart: false,
              ),
              habitCompletion: HabitSummary.new,
              checklist: (Checklist value) => Text(value.data.title),
              checklistItem: (ChecklistItem value) => Text(value.data.title),
            ),
          ),
        ],
      ),
    );
  }
}

class JournalCard extends StatelessWidget {
  const JournalCard({
    required this.item,
    super.key,
    this.maxHeight = 120,
    this.showLinkedDuration = false,
  });

  final JournalEntity item;
  final double maxHeight;
  final bool showLinkedDuration;

  @override
  Widget build(BuildContext context) {
    if (item.meta.deletedAt != null) {
      return const SizedBox.shrink();
    }
    void onTap() {
      if (item is Task) {
        beamToNamed('/tasks/${item.meta.id}');
      } else {
        beamToNamed('/journal/${item.meta.id}');
      }
    }

    final errorColor = context.colorScheme.error;

    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
      child: Card(
        child: ListTile(
          leading: item.maybeMap(
            journalAudio: (item) {
              final transcripts = item.data.transcripts;
              return LeadingIcon(
                Icons.mic_rounded,
                color: transcripts != null && transcripts.isNotEmpty
                    ? context.colorScheme.outline
                    : errorColor.withAlpha(102),
              );
            },
            checklistItem: (item) {
              final categoryId = item.meta.categoryId;
              final category =
                  getIt<EntitiesCacheService>().getCategoryById(categoryId);
              return LeadingIcon(
                item.data.isChecked
                    ? MdiIcons.check
                    : MdiIcons.checkboxBlankOutline,
                color: category != null
                    ? colorFromCssHex(category.color)
                    : context.colorScheme.outline,
              );
            },
            checklist: (checklist) {
              final categoryId = checklist.meta.categoryId;
              final category =
                  getIt<EntitiesCacheService>().getCategoryById(categoryId);
              return LeadingIcon(
                MdiIcons.checkAll,
                color: category != null
                    ? colorFromCssHex(category.color)
                    : context.colorScheme.outline,
              );
            },
            quantitative: (_) => LeadingIcon(MdiIcons.heart),
            measurement: (_) => LeadingIcon(MdiIcons.numeric),
            habitCompletion: (habitCompletion) =>
                HabitCompletionColorIcon(habitCompletion.data.habitId),
            aiResponse: (_) => const Icon(Icons.assistant),
            orElse: () => null,
          ),
          title: JournalCardTitle(
            item: item,
            maxHeight: maxHeight,
            showLinkedDuration: showLinkedDuration,
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}

class LeadingIcon extends StatelessWidget {
  const LeadingIcon(
    this.iconData, {
    this.color,
    super.key,
  });

  final IconData iconData;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Icon(
      iconData,
      size: 32,
      color: color ?? context.colorScheme.outline,
    );
  }
}
