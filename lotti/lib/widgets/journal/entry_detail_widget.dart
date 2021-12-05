import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_quill/flutter_quill.dart' hide Text;
import 'package:lotti/blocs/journal/persistence_cubit.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:lotti/widgets/audio/audio_player.dart';
import 'package:lotti/widgets/journal/editor_tools.dart';
import 'package:lotti/widgets/journal/editor_widget.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';
import 'package:lotti/widgets/misc/map_widget.dart';
import 'package:lotti/widgets/misc/survey_summary.dart';
import 'package:provider/src/provider.dart';

class EntryDetailWidget extends StatelessWidget {
  const EntryDetailWidget({
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
        shrinkWrap: false,
        children: <Widget>[
          item.maybeMap(
            journalAudio: (JournalAudio audio) {
              QuillController _controller =
                  makeController(serializedQuill: audio.entryText?.quill);

              void saveText() {
                EntryText entryText = entryTextFromController(_controller);
                debugPrint(entryText.toString());

                context
                    .read<PersistenceCubit>()
                    .updateJournalEntity(item, entryText);
              }

              return Column(
                children: [
                  EditorWidget(
                    controller: _controller,
                    height: 240,
                    saveFn: saveText,
                  ),
                  const AudioPlayerWidget(),
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
                    .updateJournalEntity(item, entryText);
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
                    //height: 240,
                    saveFn: saveText,
                  ),
                ],
              );
            },
            journalEntry: (JournalEntry journalEntry) {
              QuillController _controller =
                  makeController(serializedQuill: journalEntry.entryText.quill);

              void saveText() {
                context.read<PersistenceCubit>().updateJournalEntity(
                    item, entryTextFromController(_controller));
              }

              return EditorWidget(
                controller: _controller,
                //height: 240,
                saveFn: saveText,
              );
            },
            survey: (SurveyEntry surveyEntry) =>
                SurveySummaryWidget(surveyEntry),
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
        ],
      ),
    );
  }
}
