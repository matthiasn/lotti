import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:lotti/blocs/audio/player_cubit.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/journal/entry_modal_widget.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';
import 'package:lotti/widgets/misc/survey_summary.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

class JournalListItem extends StatelessWidget {
  final JournalEntity item;

  const JournalListItem({Key? key, required this.item}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(8.0)),
        child: Container(
          color: AppColors.entryBgColor,
          width: double.infinity,
          child: TextButton(
            child: Padding(
              padding: const EdgeInsets.only(
                  left: 16.0, right: 16.0, top: 8.0, bottom: 8.0),
              child: Center(
                child: Column(
                  children: [
                    InfoText(df.format(item.meta.dateFrom)),
                    item.maybeMap(
                      quantitative: (QuantitativeEntry qe) => qe.data.maybeMap(
                        cumulativeQuantityData: (qd) => InfoText(
                          'End: ${df.format(qd.dateTo)}'
                          '\n${formatType(qd.dataType)}: '
                          '${nf.format(qd.value)} ${formatUnit(qd.unit)}',
                        ),
                        discreteQuantityData: (qd) => InfoText(
                          'End: ${df.format(item.meta.dateTo)}'
                          '\n${formatType(qd.dataType)}: '
                          '${nf.format(qd.value)} ${formatUnit(qd.unit)}',
                        ),
                        orElse: () => Container(),
                      ),
                      journalAudio: (JournalAudio audioNote) =>
                          InfoText(formatAudio(audioNote)),
                      journalEntry: (JournalEntry journalEntry) =>
                          InfoText(journalEntry.entryText.plainText),
                      journalImage: (JournalImage journalImage) =>
                          InfoText(journalImage.data.imageFile),
                      survey: (SurveyEntry surveyEntry) =>
                          SurveySummaryWidget(surveyEntry),
                      orElse: () => Row(
                        children: const [],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            style: TextButton.styleFrom(
              primary: AppColors.listItemText,
              onSurface: Colors.yellow,
            ),
            onPressed: () async {
              item.mapOrNull(journalAudio: (JournalAudio audioNote) {
                context.read<AudioPlayerCubit>().setAudioNote(audioNote);
              });
              Directory docDir = await getApplicationDocumentsDirectory();

              showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                clipBehavior: Clip.antiAliasWithSaveLayer,
                builder: (BuildContext context) {
                  return EntryModalWidget(item: item, docDir: docDir);
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class JournalListItem2 extends StatelessWidget {
  final JournalEntity item;

  const JournalListItem2({Key? key, required this.item}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(8.0)),
        child: Padding(
          padding: const EdgeInsets.only(
              left: 16.0, right: 16.0, top: 8.0, bottom: 8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                df.format(item.meta.dateFrom),
                style: TextStyle(
                  color: AppColors.entryBgColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w300,
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
                journalAudio: (JournalAudio audioNote) =>
                    EntryText(formatAudio(audioNote)),
                journalEntry: (JournalEntry journalEntry) =>
                    EntryText(journalEntry.entryText.plainText),
                journalImage: (JournalImage journalImage) =>
                    EntryText(journalImage.data.imageFile),
                survey: (SurveyEntry surveyEntry) =>
                    SurveySummaryWidget(surveyEntry),
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
          style: const TextStyle(
            fontFamily: 'Oswald',
            fontWeight: FontWeight.w200,
            fontSize: 16.0,
          )),
    );
  }
}
