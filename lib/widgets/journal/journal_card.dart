import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:getwidget/components/list_tile/gf_list_tile.dart';
import 'package:lotti/blocs/audio/player_cubit.dart';
import 'package:lotti/blocs/audio/player_state.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/journal/card_image_widget.dart';
import 'package:lotti/widgets/journal/duration_widget.dart';
import 'package:lotti/widgets/journal/entry_details/health_summary.dart';
import 'package:lotti/widgets/journal/entry_details/measurement_summary.dart';
import 'package:lotti/widgets/journal/entry_details/survey_summary.dart';
import 'package:lotti/widgets/journal/entry_details/workout_summary.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';
import 'package:lotti/widgets/journal/helpers.dart';
import 'package:lotti/widgets/journal/tags_view_widget.dart';
import 'package:lotti/widgets/journal/text_viewer_widget.dart';
import 'package:lotti/widgets/tasks/linked_duration.dart';
import 'package:lotti/widgets/tasks/task_status.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

const double iconSize = 18;

class JournalCardTitle extends StatelessWidget {
  const JournalCardTitle({super.key, required this.item});

  final JournalEntity item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
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
                      padding: const EdgeInsets.only(left: 4),
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
                      padding: const EdgeInsets.only(left: 4),
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
          IgnorePointer(
            child: item.map(
              quantitative: (QuantitativeEntry qe) =>
                  HealthSummary(qe, showChart: false),
              journalAudio: (JournalAudio journalAudio) =>
                  journalAudio.entryText?.plainText != null
                      ? TextViewerWidget(entryText: journalAudio.entryText)
                      : EntryTextWidget(formatAudio(journalAudio)),
              journalEntry: (JournalEntry journalEntry) => TextViewerWidget(
                entryText: journalEntry.entryText,
              ),
              journalImage: (JournalImage journalImage) => TextViewerWidget(
                entryText: journalImage.entryText,
              ),
              survey: SurveySummary.new,
              measurement: MeasurementSummary.new,
              task: (Task task) {
                final data = task.data;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          data.status.maybeMap(
                            done: (_) => MdiIcons.checkboxMarkedOutline,
                            orElse: () => MdiIcons.checkboxBlankOutline,
                          ),
                          size: 32,
                          color: AppColors.entryTextColor,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            data.title,
                            style: TextStyle(
                              fontFamily: 'Oswald',
                              color: AppColors.entryTextColor,
                              fontWeight: FontWeight.normal,
                              fontSize: 24,
                            ),
                          ),
                        ),
                      ],
                    ),
                    LinkedDuration(task: task),
                    TextViewerWidget(entryText: task.entryText),
                  ],
                );
              },
              workout: WorkoutSummary.new,
              habitCompletion: (_) => const SizedBox.shrink(),
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

class JournalCard extends StatelessWidget {
  const JournalCard({
    super.key,
    required this.item,
  });

  final JournalEntity item;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AudioPlayerCubit, AudioPlayerState>(
      builder: (BuildContext context, AudioPlayerState state) {
        return Card(
          color: AppColors.entryCardColor,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListTile(
            leading: item.maybeMap(
              journalAudio: (_) => const LeadingIcon(Icons.mic),
              journalEntry: (_) => const LeadingIcon(Icons.article),
              quantitative: (_) => const LeadingIcon(MdiIcons.heart),
              orElse: () => null,
            ),
            title: JournalCardTitle(item: item),
            onTap: () {
              item.mapOrNull(
                journalAudio: (JournalAudio audioNote) {
                  context.read<AudioPlayerCubit>().setAudioNote(audioNote);
                },
              );

              pushNamedRoute('/journal/${item.meta.id}');
            },
          ),
        );
      },
    );
  }
}

class LeadingIcon extends StatelessWidget {
  const LeadingIcon(
    this.iconData, {
    super.key,
  });

  final IconData iconData;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(8)),
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
  const JournalImageCard({
    super.key,
    required this.item,
  });

  final JournalImage item;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AudioPlayerCubit, AudioPlayerState>(
      builder: (BuildContext context, AudioPlayerState state) {
        return Card(
          color: AppColors.entryCardColor,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: GFListTile(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.only(right: 8),
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
                item.mapOrNull(
                  journalAudio: (JournalAudio audioNote) {
                    context.read<AudioPlayerCubit>().setAudioNote(audioNote);
                  },
                );
                pushNamedRoute('/journal/${item.meta.id}');
              },
            ),
          ),
        );
      },
    );
  }
}
