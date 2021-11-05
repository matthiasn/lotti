import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/src/provider.dart';
import 'package:wisely/blocs/audio/player_cubit.dart';
import 'package:wisely/classes/journal_db_entities.dart';
import 'package:wisely/utils/image_utils.dart';

import '../theme.dart';
import 'audio_player.dart';
import 'map_widget.dart';

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
          onPressed: () async {
            item.data.mapOrNull(journalDbAudio: (JournalDbAudio audioNote) {
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
                return Container(
                  color: AppColors.bodyBgColor,
                  child: ListView(
                    shrinkWrap: true,
                    children: <Widget>[
                      MapWidget(
                        geolocation: item.geolocation,
                      ),
                      item.data.maybeMap(
                        journalDbAudio: (JournalDbAudio audio) {
                          return const AudioPlayerWidget();
                        },
                        journalDbImage: (JournalDbImage image) {
                          File file =
                              File(getFullImagePathWithDocDir(image, docDir));
                          debugPrint('Image $image ${file.path}');
                          return Container(
                            color: Colors.black,
                            child: Image.file(
                              file,
                              cacheHeight: 1200,
                              width: double.infinity,
                              height: 400,
                              fit: BoxFit.scaleDown,
                            ),
                          );
                        },
                        cumulativeQuantity: (q) => Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: InfoText(
                            text: 'End: ${df.format(q.dateTo)}'
                                '\n${formatType(q.dataType)}: '
                                '${nf.format(q.value)} ${formatUnit(q.unit)}',
                          ),
                        ),
                        discreteQuantity: (q) => Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: InfoText(
                            text: 'End: ${df.format(q.dateTo)}'
                                '\n${formatType(q.dataType)}: '
                                '${nf.format(q.value)} ${formatUnit(q.unit)}',
                          ),
                        ),
                        orElse: () => Container(),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 4.0, horizontal: 16.0),
                        child: InfoText(text: df.format(item.dateFrom)),
                      ),
                      ElevatedButton(
                        child: const Text('Close'),
                        onPressed: () => Navigator.pop(context),
                      )
                    ],
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
