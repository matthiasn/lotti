import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:wisely/classes/journal_entities.dart';
import 'package:wisely/theme.dart';
import 'package:wisely/utils/image_utils.dart';
import 'package:wisely/widgets/audio_player.dart';
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
          item.maybeMap(
            journalAudio: (JournalAudio audio) {
              return const AudioPlayerWidget();
            },
            journalImage: (JournalImage image) {
              File file = File(getFullImagePathWithDocDir(image, docDir));
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
            journalEntry: (JournalEntry journalEntry) {
              var editorJson = json.decode(journalEntry.entryText.quill!);

              quill.QuillController _controller = quill.QuillController.basic();

              _controller = quill.QuillController(
                  document: quill.Document.fromJson(editorJson),
                  selection: const TextSelection.collapsed(offset: 0));

              return EditorWidget(
                controller: _controller,
                height: 240,
                readOnly: true,
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
          Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
            child: InfoText(df.format(item.meta.dateFrom)),
          ),
          ElevatedButton(
            child: const Text('Close'),
            onPressed: () => Navigator.pop(context),
          )
        ],
      ),
    );
  }
}
