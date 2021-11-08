import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:wisely/blocs/audio/player_cubit.dart';
import 'package:wisely/classes/journal_entities.dart';
import 'package:wisely/utils/image_utils.dart';

import '../theme.dart';
import 'audio_player.dart';
import 'map_widget.dart';

NumberFormat nf = NumberFormat("###.0#", "en_US");
DateFormat df = DateFormat('yyyy-MM-dd HH:mm:ss');

String formatType(String s) => s.replaceAll('HealthDataType.', '');
String formatUnit(String s) => s.replaceAll('HealthDataUnit.', '');
String formatAudio(JournalAudio journalAudio) =>
    'Audio Note: ${journalAudio.data.duration.toString().split('.')[0]}';

class JournalListItem extends StatelessWidget {
  final JournalEntity item;

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
                  InfoText(text: df.format(item.meta.dateFrom)),
                  item.maybeMap(
                    quantitative: (QuantitativeEntry qe) => qe.data.maybeMap(
                      cumulativeQuantityData: (qd) => InfoText(
                        text: 'End: ${df.format(qd.dateTo)}'
                            '\n${formatType(qd.dataType)}: '
                            '${nf.format(qd.value)} ${formatUnit(qd.unit)}',
                      ),
                      discreteQuantityData: (qd) => InfoText(
                        text: 'End: ${df.format(item.meta.dateTo)}'
                            '\n${formatType(qd.dataType)}: '
                            '${nf.format(qd.value)} ${formatUnit(qd.unit)}',
                      ),
                      orElse: () => Container(),
                    ),
                    journalAudio: (JournalAudio audioNote) =>
                        InfoText(text: formatAudio(audioNote)),
                    journalImage: (JournalImage journalImage) =>
                        InfoText(text: journalImage.data.imageFile),
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
                return Container(
                  color: AppColors.bodyBgColor,
                  child: ListView(
                    shrinkWrap: true,
                    children: <Widget>[
                      item.maybeMap(
                        journalAudio: (audio) => MapWidget(
                          geolocation: audio.geolocation,
                        ),
                        journalImage: (image) => MapWidget(
                          geolocation: image.geolocation,
                        ),
                        orElse: () => Container(),
                      ),
                      item.maybeMap(
                        journalAudio: (JournalAudio audio) {
                          return const AudioPlayerWidget();
                        },
                        journalImage: (JournalImage image) {
                          File file =
                              File(getFullImagePathWithDocDir(image, docDir));
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
                        quantitative: (qe) => qe.data.map(
                          cumulativeQuantityData: (qd) => Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: InfoText(
                              text: 'End: ${df.format(qe.meta.dateTo)}'
                                  '\n${formatType(qd.dataType)}: '
                                  '${nf.format(qd.value)} ${formatUnit(qd.unit)}',
                            ),
                          ),
                          discreteQuantityData: (qd) => Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: InfoText(
                              text: 'End: ${df.format(qe.meta.dateTo)}'
                                  '\n${formatType(qd.dataType)}: '
                                  '${nf.format(qd.value)} ${formatUnit(qd.unit)}',
                            ),
                          ),
                        ),
                        orElse: () => Container(),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 4.0, horizontal: 16.0),
                        child: InfoText(text: df.format(item.meta.dateFrom)),
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
