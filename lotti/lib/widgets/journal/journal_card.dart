import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:lotti/blocs/audio/player_cubit.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/journal/entry_detail_widget.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';
import 'package:lotti/widgets/misc/survey_summary.dart';
import 'package:provider/src/provider.dart';

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
    return Card(
      child: ListTile(
        leading: const FlutterLogo(),
        //title: Text('Item ${index + 1}'),
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
      body: EntryDetailWidget(
        item: item,
        docDir: Directory('docDir'),
      ),
    );
  }
}
