import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_rating/flutter_rating.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/journal_card_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/events/event_status.dart';
import 'package:lotti/widgets/journal/card_image_widget.dart';
import 'package:lotti/widgets/journal/entry_details/habit_summary.dart';
import 'package:lotti/widgets/journal/entry_details/health_summary.dart';
import 'package:lotti/widgets/journal/entry_details/measurement_summary.dart';
import 'package:lotti/widgets/journal/entry_details/survey_summary.dart';
import 'package:lotti/widgets/journal/entry_details/workout_summary.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';
import 'package:lotti/widgets/journal/tags/tags_view_widget.dart';
import 'package:lotti/widgets/journal/text_viewer_widget.dart';
import 'package:lotti/widgets/settings/categories/categories_type_card.dart';
import 'package:lotti/widgets/tasks/linked_duration.dart';
import 'package:lotti/widgets/tasks/task_status.dart';
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
      padding: const EdgeInsets.only(
        top: 8,
        bottom: 8,
        left: 8,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                item is JournalEvent
                    ? dfShort.format(item.meta.dateFrom)
                    : dfShorter.format(item.meta.dateFrom),
                style: monospaceTextStyle,
              ),
              if (item is Task) TaskStatusWidget(item as Task),
              Row(
                children: [
                  Visibility(
                    visible: fromNullableBool(item.meta.private),
                    child: Icon(
                      MdiIcons.security,
                      color: Theme.of(context).colorScheme.error,
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
                          color: Theme.of(context).colorScheme.error,
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
              measurement: (measurementEntry) => MeasurementSummary(
                measurementEntry,
                showChart: false,
              ),
              task: (Task task) {
                final data = task.data;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.title,
                      style: const TextStyle(
                        fontSize: fontSizeLarge,
                      ),
                    ),
                    if (showLinkedDuration) LinkedDuration(task: task),
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
              workout: (workout) => WorkoutSummary(
                workout,
                showChart: false,
              ),
              habitCompletion: HabitSummary.new,
              checklistItem: (ChecklistItem value) => Text(value.data.title),
            ),
          ),
        ],
      ),
    );
  }
}

class JournalCard extends ConsumerStatefulWidget {
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
  ConsumerState<JournalCard> createState() => _JournalCardState();
}

class _JournalCardState extends ConsumerState<JournalCard> {
  @override
  Widget build(BuildContext context) {
    final provider = journalCardControllerProvider(id: widget.item.meta.id);
    final entryState = ref.watch(provider).value;
    final updatedItem = entryState ?? widget.item;

    if (updatedItem.meta.deletedAt != null) {
      return const SizedBox.shrink();
    }
    void onTap() {
      if (getIt<NavService>().tasksTabActive()) {
        beamToNamed('/tasks/${updatedItem.meta.id}');
      } else {
        beamToNamed('/journal/${updatedItem.meta.id}');
      }
    }

    final errorColor = Theme.of(context).colorScheme.error;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Card(
        child: ListTile(
          leading: updatedItem.maybeMap(
            journalAudio: (item) {
              final transcripts = item.data.transcripts;
              return LeadingIcon(
                Icons.mic_rounded,
                color: transcripts != null && transcripts.isNotEmpty
                    ? Theme.of(context).colorScheme.outline
                    : errorColor.withOpacity(0.4),
              );
            },
            quantitative: (_) => LeadingIcon(MdiIcons.heart),
            measurement: (_) => LeadingIcon(MdiIcons.numeric),
            habitCompletion: (habitCompletion) =>
                HabitCompletionColorIcon(habitCompletion.data.habitId),
            orElse: () => null,
          ),
          title: JournalCardTitle(
            item: updatedItem,
            maxHeight: widget.maxHeight,
            showLinkedDuration: widget.showLinkedDuration,
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
      color: color ?? Theme.of(context).colorScheme.outline,
    );
  }
}

class JournalImageCard extends ConsumerWidget {
  const JournalImageCard({
    required this.item,
    super.key,
  });

  final JournalImage item;

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    void onTap() => beamToNamed('/journal/${item.meta.id}');
    final provider = journalCardControllerProvider(id: item.meta.id);
    final entryState = ref.watch(provider).value;

    final updatedItem = entryState ?? item;
    if (updatedItem.meta.deletedAt != null) {
      return const SizedBox.shrink();
    }

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.only(right: 16),
        onTap: onTap,
        minLeadingWidth: 0,
        minVerticalPadding: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            LimitedBox(
              maxWidth: max(MediaQuery.of(context).size.width / 2, 300) - 40,
              maxHeight: 160,
              child: CardImageWidget(
                journalImage: updatedItem as JournalImage,
                height: 160,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: SizedBox(
                height: 160,
                child: JournalCardTitle(
                  item: updatedItem,
                  maxHeight: 200,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TaskListCard extends StatelessWidget {
  const TaskListCard({
    required this.task,
    super.key,
  });

  final Task task;

  @override
  Widget build(BuildContext context) {
    void onTap() => beamToNamed('/tasks/${task.meta.id}');

    return Card(
      child: ListTile(
        onTap: onTap,
        trailing: TaskStatusWidget(task),
        title: Text(
          task.data.title,
          style: const TextStyle(
            fontSize: fontSizeMediumLarge,
          ),
        ),
      ),
    );
  }
}

class EntryWrapperWidget extends StatelessWidget {
  const EntryWrapperWidget({
    required this.item,
    required this.taskAsListView,
    super.key,
  });

  final JournalEntity item;
  final bool taskAsListView;

  @override
  Widget build(BuildContext context) {
    return item.maybeMap(
      journalImage: (JournalImage image) => JournalImageCard(item: image),
      task: (Task task) {
        if (taskAsListView) {
          return TaskListCard(task: task);
        } else {
          return JournalCard(item: task);
        }
      },
      orElse: () => JournalCard(item: item),
    );
  }
}
