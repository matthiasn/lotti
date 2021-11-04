import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:wisely/classes/journal_db_entities.dart';

import '../theme.dart';

NumberFormat nf = NumberFormat("###.0#", "en_US");
DateFormat df = DateFormat('yyyy-MM-dd HH:mm:ss');

String formatType(String s) => s.replaceAll('HealthDataType.', '');
String formatUnit(String s) => s.replaceAll('HealthDataUnit.', '');
String formatAudio(JournalDbAudio audioNote) =>
    'Audio Note: ${audioNote.duration.toString().split('.')[0]}';

class JournalListItem extends StatelessWidget {
  final JournalDbEntity item;
  const JournalListItem({Key? key, required this.item}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: SizedBox(
        width: double.infinity,
        child: TextButton(
          child: Padding(
            padding: const EdgeInsets.only(
                left: 16.0, right: 16.0, top: 8.0, bottom: 8.0),
            child: Center(
              child: Column(
                children: [
                  InfoText(text: df.format(item.dateFrom)),
                  item.data.maybeMap(
                    cumulativeQuantity: (q) => InfoText(
                      text: 'End: ${df.format(q.dateTo)}'
                          '\n${formatType(q.dataType)}: '
                          '${nf.format(q.value)} ${formatUnit(q.unit)}',
                    ),
                    discreteQuantity: (q) => InfoText(
                      text: 'End: ${df.format(q.dateTo)}'
                          '\n${formatType(q.dataType)}: '
                          '${nf.format(q.value)} ${formatUnit(q.unit)}',
                    ),
                    journalDbAudio: (JournalDbAudio audioNote) =>
                        InfoText(text: formatAudio(audioNote)),
                    journalDbImage: (JournalDbImage journalDbImage) =>
                        InfoText(text: journalDbImage.imageFile),
                    orElse: () => Row(
                      children: const [],
                    ),
                  ),
                ],
              ),
            ),
          ),
          style: TextButton.styleFrom(
            primary: AppColors.inactiveAudioControl,
            onSurface: Colors.yellow,
            side: BorderSide(color: AppColors.inactiveAudioControl, width: 0.5),
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(8))),
          ),
          onPressed: () {
            showModalBottomSheet<void>(
              context: context,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              clipBehavior: Clip.antiAliasWithSaveLayer,
              builder: (BuildContext context) {
                return Container(
                  height: 312,
                  color: AppColors.bodyBgColor,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        ElevatedButton(
                          child: const Text('Close'),
                          onPressed: () => Navigator.pop(context),
                        )
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class InfoText extends StatelessWidget {
  final String text;
  const InfoText({
    Key? key,
    required this.text,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
          fontFamily: 'ShareTechMono',
          fontSize: 16.0,
        ));
  }
}
