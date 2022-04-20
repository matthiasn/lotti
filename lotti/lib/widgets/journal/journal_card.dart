import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:getwidget/components/list_tile/gf_list_tile.dart';
import 'package:lotti/blocs/audio/player_cubit.dart';
import 'package:lotti/blocs/audio/player_state.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/routes/router.gr.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/journal/card_image_widget.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';
import 'package:lotti/widgets/journal/helpers.dart';
import 'package:lotti/widgets/journal/measurement_summary.dart';
import 'package:lotti/widgets/journal/tags_view_widget.dart';
import 'package:lotti/widgets/journal/text_viewer_widget.dart';
import 'package:lotti/widgets/misc/survey_summary.dart';
import 'package:lotti/widgets/tasks/linked_duration.dart';
import 'package:lotti/widgets/tasks/task_status.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import 'duration_widget.dart';

const double iconSize = 18.0;

class JournalCardTitle extends StatelessWidget {
  final JournalEntity item;
  const JournalCardTitle({Key? key, required this.item}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                df.format(item.meta.dateFrom),
                style: TextStyle(
                  color: AppColors.entryTextColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w300,
                  fontFamily: 'Oswald',
                ),
              ),
              if (item is Task) TaskStatusWidget(item as Task),
              Row(
                children: [
                  Visibility(
                    visible: fromNullableBool(item.meta.private),
                    child: Icon(
                      MdiIcons.security,
                      color: AppColors.error,
                      size: iconSize,
                    ),
                  ),
                  Visibility(
                    visible: fromNullableBool(item.meta.starred),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4.0),
                      child: Icon(
                        MdiIcons.star,
                        color: AppColors.starredGold,
                        size: iconSize,
                      ),
                    ),
                  ),
                  Visibility(
                    visible: item.meta.flag == EntryFlag.import,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4.0),
                      child: Icon(
                        MdiIcons.flag,
                        color: AppColors.error,
                        size: iconSize,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          TagsViewWidget(item: item),
          item.map(
            quantitative: (QuantitativeEntry qe) => qe.data.maybeMap(
              cumulativeQuantityData: (qd) => EntryTextWidget(
                'End: ${df.format(qd.dateTo)}'
                '\n${formatType(qd.dataType)}: '
                '${nf.format(qd.value)} ${formatUnit(qd.unit)}',
              ),
              discreteQuantityData: (qd) => EntryTextWidget(
                'End: ${df.format(item.meta.dateTo)}'
                '\n${formatType(qd.dataType)}: '
                '${nf.format(qd.value)} ${formatUnit(qd.unit)}',
              ),
              orElse: () => Container(),
            ),
            journalAudio: (JournalAudio journalAudio) =>
                journalAudio.entryText?.plainText != null
                    ? TextViewerWidget(entryText: journalAudio.entryText)
                    : EntryTextWidget(formatAudio(journalAudio)),
            journalEntry: (JournalEntry journalEntry) => TextViewerWidget(
              entryText: journalEntry.entryText,
            ),
            journalImage: (JournalImage journalImage) => Expanded(
              child: TextViewerWidget(entryText: journalImage.entryText),
            ),
            survey: (SurveyEntry surveyEntry) =>
                SurveySummaryWidget(surveyEntry),
            measurement: (MeasurementEntry measurementEntry) =>
                MeasurementSummary(measurementEntry),
            task: (Task task) {
              TaskData data = task.data;
              return Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Icon(
                        data.status.maybeMap(
                            done: (_) => MdiIcons.checkboxMarkedOutline,
                            orElse: () => MdiIcons.checkboxBlankOutline),
                        size: 32,
                        color: AppColors.entryTextColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        data.title,
                        style: TextStyle(
                          fontFamily: 'Oswald',
                          color: AppColors.entryTextColor,
                          fontWeight: FontWeight.normal,
                          fontSize: 24.0,
                        ),
                      ),
                    ],
                  ),
                  LinkedDuration(task: task),
                  TextViewerWidget(entryText: task.entryText),
                ],
              );
            },
            workout: (WorkoutEntry workout) =>
                EntryTextWidget(workout.data.toString()),
            habitCompletion: (_) => const SizedBox.shrink(),
          ),
          DurationWidget(
            item: item,
            style: TextStyle(
              color: AppColors.entryTextColor,
              fontSize: 14,
              fontWeight: FontWeight.w300,
              fontFamily: 'Oswald',
            ),
          ),
        ],
      ),
    );
  }
}

class JournalCard extends StatelessWidget {
  final JournalEntity item;

  const JournalCard({Key? key, required this.item}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AudioPlayerCubit, AudioPlayerState>(
        builder: (BuildContext context, AudioPlayerState state) {
      return Card(
        color: AppColors.headerBgColor,
        elevation: 8.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: ListTile(
          leading: item.maybeMap(
            journalAudio: (_) => const LeadingIcon(Icons.mic),
            journalEntry: (_) => const LeadingIcon(Icons.article),
            quantitative: (_) => const LeadingIcon(MdiIcons.heart),
            measurement: (_) => const LeadingIcon(MdiIcons.tapeMeasure),
            orElse: () => null,
          ),
          title: JournalCardTitle(item: item),
          enabled: true,
          onTap: () {
            item.mapOrNull(journalAudio: (JournalAudio audioNote) {
              context.read<AudioPlayerCubit>().setAudioNote(audioNote);
            });

            context.router.push(EntryDetailRoute(itemId: item.meta.id));
          },
        ),
      );
    });
  }
}

class LeadingIcon extends StatelessWidget {
  final IconData iconData;
  const LeadingIcon(
    this.iconData, {
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(8.0)),
      child: Container(
        width: 50,
        height: 50,
        color: AppColors.entryBgColor,
        child: Icon(
          iconData,
          size: 32,
        ),
      ),
    );
  }
}

class JournalImageCard extends StatelessWidget {
  final JournalImage item;

  const JournalImageCard({
    Key? key,
    required this.item,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AudioPlayerCubit, AudioPlayerState>(
        builder: (BuildContext context, AudioPlayerState state) {
      return Card(
        color: AppColors.headerBgColor,
        elevation: 8.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8.0),
          child: GFListTile(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.only(right: 8.0),
            avatar: LimitedBox(
              maxWidth: (MediaQuery.of(context).size.width / 2) - 40,
              child: CardImageWidget(
                journalImage: item,
                height: 160,
                fit: BoxFit.cover,
              ),
            ),
            title: SizedBox(
              height: 160,
              child: JournalCardTitle(item: item),
            ),
            onTap: () {
              item.mapOrNull(journalAudio: (JournalAudio audioNote) {
                context.read<AudioPlayerCubit>().setAudioNote(audioNote);
              });
              String entryId = item.meta.id;
              context.router.push(EntryDetailRoute(itemId: entryId));
            },
          ),
        ),
      );
    });
  }
}
