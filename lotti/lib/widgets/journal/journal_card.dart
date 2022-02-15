import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:getwidget/components/list_tile/gf_list_tile.dart';
import 'package:lotti/blocs/audio/player_cubit.dart';
import 'package:lotti/blocs/audio/player_state.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/utils/task_utils.dart';
import 'package:lotti/widgets/journal/card_image_widget.dart';
import 'package:lotti/widgets/journal/entry_detail_route.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';
import 'package:lotti/widgets/journal/linked_duration.dart';
import 'package:lotti/widgets/journal/tags_view_widget.dart';
import 'package:lotti/widgets/journal/text_viewer_widget.dart';
import 'package:lotti/widgets/misc/survey_summary.dart';
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
          item.maybeMap(
            quantitative: (QuantitativeEntry qe) => qe.data.maybeMap(
              cumulativeQuantityData: (qd) => EntryText(
                'End: ${df.format(qd.dateTo)}'
                '\n${formatType(qd.dataType)}: '
                '${nf.format(qd.value)} ${formatUnit(qd.unit)}',
              ),
              discreteQuantityData: (qd) => EntryText(
                'End: ${df.format(item.meta.dateTo)}'
                '\n${formatType(qd.dataType)}: '
                '${nf.format(qd.value)} ${formatUnit(qd.unit)}',
              ),
              orElse: () => Container(),
            ),
            journalAudio: (JournalAudio journalAudio) =>
                journalAudio.entryText?.plainText != null
                    ? TextViewerWidget(entryText: journalAudio.entryText)
                    : EntryText(formatAudio(journalAudio)),
            journalEntry: (JournalEntry journalEntry) => TextViewerWidget(
              entryText: journalEntry.entryText,
            ),
            journalImage: (JournalImage journalImage) => Expanded(
              child: TextViewerWidget(entryText: journalImage.entryText),
            ),
            survey: (SurveyEntry surveyEntry) =>
                SurveySummaryWidget(surveyEntry),
            measurement: (MeasurementEntry measurementEntry) {
              MeasurementData data = measurementEntry.data;
              return Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (measurementEntry.entryText?.plainText != null)
                    TextViewerWidget(entryText: measurementEntry.entryText),
                  EntryText(
                    '${data.dataType.displayName}: '
                    '${nf.format(data.value)}',
                    padding: EdgeInsets.zero,
                  ),
                ],
              );
            },
            task: (Task task) {
              TaskData data = task.data;
              return Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          data.title,
                          style: TextStyle(
                            fontFamily: 'Oswald',
                            color: AppColors.entryTextColor,
                            fontWeight: FontWeight.normal,
                            fontSize: 24.0,
                          ),
                        ),
                      ),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 12,
                          ),
                          color: taskColor(data.status),
                          child: Text(
                            data.status.map(
                              open: (_) => 'OPEN',
                              started: (_) => 'STARTED',
                              inProgress: (_) => 'IN PROGRESS',
                              blocked: (_) => 'BLOCKED',
                              onHold: (_) => 'ON HOLD',
                              done: (_) => 'DONE',
                              rejected: (_) => 'REJECTED',
                            ),
                            style: TextStyle(
                              fontFamily: 'Oswald',
                              color: AppColors.bodyBgColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12.0,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  LinkedDuration(
                    task: task,
                    width: MediaQuery.of(context).size.width - 200,
                  ),
                  TextViewerWidget(entryText: task.entryText),
                ],
              );
            },
            orElse: () => Row(
              children: const [],
            ),
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

class EntryText extends StatelessWidget {
  final String text;
  final int maxLines;
  final EdgeInsets padding;
  const EntryText(
    this.text, {
    Key? key,
    this.maxLines = 5,
    this.padding = const EdgeInsets.only(top: 4.0),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(text,
          maxLines: maxLines,
          style: TextStyle(
            fontFamily: 'ShareTechMono',
            color: AppColors.entryTextColor,
            fontWeight: FontWeight.w300,
            fontSize: 14.0,
          )),
    );
  }
}

class JournalCard extends StatelessWidget {
  final JournalEntity item;
  final int index;

  const JournalCard({
    Key? key,
    required this.item,
    required this.index,
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
        child: ListTile(
          leading: ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(8.0)),
            child: Container(
              width: 50,
              height: 50,
              color: AppColors.entryBgColor,
              child: item.maybeMap(
                task: (_) => const Icon(
                  Icons.check_box_outline_blank,
                  size: 32,
                ),
                journalAudio: (_) => const Icon(
                  Icons.mic,
                  size: 32,
                ),
                journalEntry: (_) => const Icon(
                  Icons.article,
                  size: 32,
                ),
                survey: (_) => const Icon(
                  MdiIcons.clipboardOutline,
                  size: 32,
                ),
                quantitative: (_) => const Icon(
                  MdiIcons.heart,
                  size: 32,
                ),
                measurement: (_) => const Icon(
                  MdiIcons.tapeMeasure,
                  size: 32,
                ),
                orElse: () => Container(),
              ),
            ),
          ),
          title: JournalCardTitle(item: item),
          enabled: true,
          onTap: () {
            item.mapOrNull(journalAudio: (JournalAudio audioNote) {
              context.read<AudioPlayerCubit>().setAudioNote(audioNote);
            });

            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (BuildContext context) {
                  return EntryDetailRoute(item: item);
                },
              ),
            );
          },
        ),
      );
    });
  }
}

class JournalImageCard extends StatelessWidget {
  final JournalImage item;
  final int index;

  const JournalImageCard({
    Key? key,
    required this.item,
    required this.index,
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

              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (BuildContext context) {
                    return EntryDetailRoute(item: item);
                  },
                ),
              );
            },
          ),
        ),
      );
    });
  }
}
