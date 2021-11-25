import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_quill/flutter_quill.dart' hide Text;
import 'package:provider/src/provider.dart';
import 'package:wisely/blocs/journal/persistence_cubit.dart';
import 'package:wisely/classes/entry_text.dart';
import 'package:wisely/classes/journal_entities.dart';
import 'package:wisely/theme.dart';
import 'package:wisely/utils/image_utils.dart';
import 'package:wisely/widgets/audio_player.dart';
import 'package:wisely/widgets/buttons.dart';
import 'package:wisely/widgets/editor_tools.dart';
import 'package:wisely/widgets/editor_widget.dart';
import 'package:wisely/widgets/entry_tools.dart';
import 'package:wisely/widgets/map_widget.dart';

class EntryModalWidget extends StatelessWidget {
  const EntryModalWidget({
    Key? key,
    required this.item,
    required this.docDir,
  }) : super(key: key);

  final JournalEntity item;
  final Directory docDir;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.entryBgColor,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
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
            journalEntry: (entry) => MapWidget(
              geolocation: entry.geolocation,
            ),
            orElse: () => Container(),
          ),
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 4.0, horizontal: 16.0),
                  child: Text(
                    df.format(item.meta.dateFrom),
                    style: const TextStyle(
                      fontFamily: 'Oswald',
                      fontSize: 18.0,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ),
                Button(
                  'Close',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          item.maybeMap(
            journalAudio: (JournalAudio audio) {
              QuillController _controller =
                  makeController(serializedQuill: audio.entryText?.quill);

              void saveText() {
                EntryText entryText = entryTextFromController(_controller);
                debugPrint(entryText.toString());

                context
                    .read<PersistenceCubit>()
                    .updateAudioEntry(item, entryText);
              }

              return Column(
                children: [
                  const AudioPlayerWidget(),
                  EditorWidget(
                    controller: _controller,
                    height: 240,
                    saveFn: saveText,
                  ),
                ],
              );
            },
            journalImage: (JournalImage image) {
              QuillController _controller =
                  makeController(serializedQuill: image.entryText?.quill);

              void saveText() {
                EntryText entryText = entryTextFromController(_controller);

                context
                    .read<PersistenceCubit>()
                    .updateImageEntry(item, entryText);
              }

              File file = File(getFullImagePathWithDocDir(image, docDir));

              return Column(
                children: [
                  Container(
                    color: Colors.black,
                    child: Image.file(
                      file,
                      cacheHeight: 1200,
                      width: double.infinity,
                      height: 400,
                      fit: BoxFit.scaleDown,
                    ),
                  ),
                  EditorWidget(
                    controller: _controller,
                    height: 240,
                    saveFn: saveText,
                  ),
                ],
              );
            },
            journalEntry: (JournalEntry journalEntry) {
              QuillController _controller =
                  makeController(serializedQuill: journalEntry.entryText.quill);

              void saveText() {
                context.read<PersistenceCubit>().updateTextEntry(
                    item, entryTextFromController(_controller));
              }

              return EditorWidget(
                controller: _controller,
                height: 240,
                saveFn: saveText,
              );
            },
            quantitative: (qe) => qe.data.map(
              cumulativeQuantityData: (qd) => Padding(
                padding: const EdgeInsets.all(24.0),
                child: InfoText(
                  'End: ${df.format(qe.meta.dateTo)}'
                  '\n${formatType(qd.dataType)}: '
                  '${nf.format(qd.value)} ${formatUnit(qd.unit)}',
                ),
              ),
              discreteQuantityData: (qd) => Padding(
                padding: const EdgeInsets.all(24.0),
                child: InfoText(
                  'End: ${df.format(qe.meta.dateTo)}'
                  '\n${formatType(qd.dataType)}: '
                  '${nf.format(qd.value)} ${formatUnit(qd.unit)}',
                ),
              ),
            ),
            orElse: () => Container(),
          ),
        ],
      ),
    );
  }
}
