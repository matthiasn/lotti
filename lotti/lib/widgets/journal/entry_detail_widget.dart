import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' hide Text;
import 'package:lotti/blocs/journal/persistence_cubit.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/widgets/audio/audio_player.dart';
import 'package:lotti/widgets/journal/editor_tools.dart';
import 'package:lotti/widgets/journal/editor_widget.dart';
import 'package:lotti/widgets/journal/entry_detail_header.dart';
import 'package:lotti/widgets/journal/entry_image_widget.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';
import 'package:lotti/widgets/journal/tags_widget.dart';
import 'package:lotti/widgets/misc/map_widget.dart';
import 'package:lotti/widgets/misc/survey_summary.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/src/provider.dart';

class EntryDetailWidget extends StatefulWidget {
  final JournalEntity item;
  final bool readOnly;
  const EntryDetailWidget({
    Key? key,
    required this.item,
    this.readOnly = false,
  }) : super(key: key);

  @override
  State<EntryDetailWidget> createState() => _EntryDetailWidgetState();
}

class _EntryDetailWidgetState extends State<EntryDetailWidget> {
  final FocusNode _focusNode = FocusNode();
  bool showDetails = false;

  Directory? docDir;
  bool mapVisible = false;
  double editorHeight = (Platform.isIOS || Platform.isAndroid) ? 280 : 400;
  double imageTextEditorHeight =
      (Platform.isIOS || Platform.isAndroid) ? 160 : 400;

  @override
  void initState() {
    super.initState();

    getApplicationDocumentsDirectory().then((value) {
      setState(() {
        docDir = value;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        EntryDetailHeader(item: widget.item),
        Visibility(
          visible: mapVisible,
          child: MapWidget(
            geolocation: widget.item.geolocation,
          ),
        ),
        TagsWidget(item: widget.item),
        widget.item.maybeMap(
          journalAudio: (JournalAudio audio) {
            QuillController _controller =
                makeController(serializedQuill: audio.entryText?.quill);

            void saveText() {
              EntryText entryText = entryTextFromController(_controller);
              HapticFeedback.heavyImpact();

              context
                  .read<PersistenceCubit>()
                  .updateJournalEntityText(widget.item.meta.id, entryText);
            }

            return Column(
              children: [
                const AudioPlayerWidget(),
                EditorWidget(
                  controller: _controller,
                  focusNode: _focusNode,
                  height: editorHeight,
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
                  .updateJournalEntityText(widget.item.meta.id, entryText);
            }

            return Column(
              children: [
                Container(
                  width: MediaQuery.of(context).size.width,
                  color: Colors.black,
                  child: EntryImageWidget(
                    focusNode: _focusNode,
                    journalImage: image,
                    height: 200,
                  ),
                ),
                EditorWidget(
                  controller: _controller,
                  focusNode: _focusNode,
                  readOnly: widget.readOnly,
                  height: imageTextEditorHeight,
                  saveFn: saveText,
                ),
              ],
            );
          },
          journalEntry: (JournalEntry journalEntry) {
            QuillController _controller =
                makeController(serializedQuill: journalEntry.entryText.quill);

            void saveText() {
              context.read<PersistenceCubit>().updateJournalEntityText(
                  widget.item.meta.id, entryTextFromController(_controller));
            }

            return EditorWidget(
              controller: _controller,
              focusNode: _focusNode,
              readOnly: widget.readOnly,
              saveFn: saveText,
            );
          },
          measurement: (MeasurementEntry entry) {
            QuillController _controller =
                makeController(serializedQuill: entry.entryText?.quill);

            void saveText() {
              context.read<PersistenceCubit>().updateJournalEntityText(
                  widget.item.meta.id, entryTextFromController(_controller));
            }

            return EditorWidget(
              controller: _controller,
              focusNode: _focusNode,
              readOnly: widget.readOnly,
              saveFn: saveText,
            );
          },
          survey: (SurveyEntry surveyEntry) => SurveySummaryWidget(surveyEntry),
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
    );
  }
}
