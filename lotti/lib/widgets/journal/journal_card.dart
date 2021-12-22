import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/audio/player_cubit.dart';
import 'package:lotti/blocs/audio/player_state.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/measurables.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/journal/entry_detail_widget.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';
import 'package:lotti/widgets/misc/survey_summary.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class JournalCardTitle extends StatelessWidget {
  final JournalEntity item;
  const JournalCardTitle({Key? key, required this.item}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(8.0)),
        child: Padding(
          padding: const EdgeInsets.only(
              left: 8.0, right: 16.0, top: 8.0, bottom: 8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                df.format(item.meta.dateFrom),
                style: TextStyle(
                  color: AppColors.entryTextColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Oswald',
                ),
              ),
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
                journalAudio: (JournalAudio journalAudio) => EntryText(
                    journalAudio.entryText?.plainText != null
                        ? journalAudio.entryText!.plainText
                        : formatAudio(journalAudio)),
                journalEntry: (JournalEntry journalEntry) =>
                    EntryText(journalEntry.entryText.plainText),
                journalImage: (JournalImage journalImage) => EntryText(
                    journalImage.entryText?.plainText != null
                        ? journalImage.entryText!.plainText
                        : journalImage.data.imageFile),
                survey: (SurveyEntry surveyEntry) =>
                    SurveySummaryWidget(surveyEntry),
                measurement: (MeasurementEntry measurementEntry) {
                  MeasurementData data = measurementEntry.data;
                  return EntryText(
                      '${data.dataType.displayName}: ${nf.format(data.value)}'
                      '\n${measurementEntry.entryText?.plainText ?? ''}');
                },
                orElse: () => Row(
                  children: const [],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EntryText extends StatelessWidget {
  final String text;
  final int maxLines;
  const EntryText(
    this.text, {
    Key? key,
    this.maxLines = 5,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Text(text,
          maxLines: maxLines,
          style: TextStyle(
            fontFamily: 'Lato',
            color: AppColors.entryTextColor,
            fontWeight: FontWeight.w300,
            fontSize: 16.0,
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
                journalImage: (JournalImage journalImage) {
                  return EntryImageWidget(
                    journalImage: journalImage,
                    height: 50,
                    fit: BoxFit.cover,
                  );
                },
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
                  return DetailRoute(
                    item: item,
                    index: index,
                  );
                },
              ),
            );
          },
        ),
      );
    });
  }
}

class DetailRoute extends StatelessWidget {
  const DetailRoute({
    Key? key,
    required this.item,
    required this.index,
  }) : super(key: key);

  final int index;
  final JournalEntity item;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bodyBgColor,
      appBar: AppBar(
        title: Text(
          df.format(item.meta.dateFrom),
          style: TextStyle(
            color: AppColors.entryBgColor,
            fontFamily: 'Oswald',
          ),
        ),
        backgroundColor: AppColors.headerBgColor,
      ),
      body: Container(
        color: AppColors.bodyBgColor,
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: EntryDetailWidget(
            item: item,
          ),
        ),
      ),
    );
  }
}
