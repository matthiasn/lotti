import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_quill/flutter_quill.dart' hide Text;
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/persistence_logic.dart';
import 'package:lotti/main.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/audio/audio_player.dart';
import 'package:lotti/widgets/journal/editor_tools.dart';
import 'package:lotti/widgets/journal/editor_widget.dart';
import 'package:lotti/widgets/journal/entry_detail_footer.dart';
import 'package:lotti/widgets/journal/entry_detail_linked.dart';
import 'package:lotti/widgets/journal/entry_detail_linked_from.dart';
import 'package:lotti/widgets/journal/entry_image_widget.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';
import 'package:lotti/widgets/journal/linked_duration.dart';
import 'package:lotti/widgets/journal/tags_widget.dart';
import 'package:lotti/widgets/misc/survey_summary.dart';
import 'package:lotti/widgets/pages/add/new_task_page.dart';
import 'package:path_provider/path_provider.dart';

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

  final PersistenceLogic persistenceLogic = getIt<PersistenceLogic>();

  Directory? docDir;
  double editorHeight = (Platform.isIOS || Platform.isAndroid) ? 160 : 240;
  double imageTextEditorHeight =
      (Platform.isIOS || Platform.isAndroid) ? 160 : 240;

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
    EntryText? entryText = widget.item.map(
      journalEntry: (item) => item.entryText,
      journalImage: (item) => item.entryText,
      journalAudio: (item) => item.entryText,
      task: (item) => item.entryText,
      quantitative: (_) => null,
      measurement: (item) => item.entryText,
      habitCompletion: (item) => item.entryText,
      survey: (_) => null,
    );

    QuillController _controller =
        makeController(serializedQuill: entryText?.quill);

    void saveText() {
      EntryText entryText = entryTextFromController(_controller);
      HapticFeedback.heavyImpact();

      persistenceLogic.updateJournalEntityText(widget.item.meta.id, entryText);
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        LinkedFromEntriesWidget(item: widget.item),
        Container(
          margin: const EdgeInsets.symmetric(
            horizontal: 12.0,
            vertical: 4.0,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8.0),
            child: Container(
              color: AppColors.headerBgColor,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, left: 8, right: 8),
                    child: TagsWidget(item: widget.item),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: EntryInfoRow(entityId: widget.item.meta.id),
                  ),
                  widget.item.map(
                    journalAudio: (JournalAudio audio) {
                      return Column(
                        children: [
                          const AudioPlayerWidget(),
                          EditorWidget(
                            controller: _controller,
                            focusNode: _focusNode,
                            saveFn: saveText,
                          ),
                        ],
                      );
                    },
                    journalImage: (JournalImage image) {
                      return Column(
                        children: [
                          Container(
                            width: MediaQuery.of(context).size.width,
                            color: Colors.black,
                            child: EntryImageWidget(
                              focusNode: _focusNode,
                              journalImage: image,
                            ),
                          ),
                          EditorWidget(
                            controller: _controller,
                            focusNode: _focusNode,
                            readOnly: widget.readOnly,
                            saveFn: saveText,
                          ),
                        ],
                      );
                    },
                    journalEntry: (JournalEntry journalEntry) {
                      return EditorWidget(
                        controller: _controller,
                        focusNode: _focusNode,
                        readOnly: widget.readOnly,
                        saveFn: saveText,
                      );
                    },
                    measurement: (MeasurementEntry entry) {
                      return EditorWidget(
                        controller: _controller,
                        focusNode: _focusNode,
                        readOnly: widget.readOnly,
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
                    task: (Task task) {
                      final formKey = GlobalKey<FormBuilderState>();

                      void saveText() {
                        formKey.currentState?.save();
                        final formData = formKey.currentState?.value;
                        if (formData == null) {
                          return;
                        }
                        final DateTime due = formData['due'];
                        final String title = formData['title'];
                        final DateTime dt = formData['estimate'];
                        final String status = formData['status'];

                        final Duration estimate = Duration(
                          hours: dt.hour,
                          minutes: dt.minute,
                        );

                        TaskData updatedData = task.data.copyWith(
                          title: title,
                          estimate: estimate,
                          due: due,
                          status: taskStatusFromString(status),
                        );

                        persistenceLogic.updateTask(
                          entryText: entryTextFromController(_controller),
                          journalEntityId: task.meta.id,
                          taskData: updatedData,
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 16.0),
                            child: LinkedDuration(
                              task: task,
                              width: MediaQuery.of(context).size.width - 200,
                            ),
                          ),
                          TaskForm(
                            controller: _controller,
                            focusNode: _focusNode,
                            saveFn: saveText,
                            formKey: formKey,
                            data: task.data,
                          ),
                        ],
                      );
                    },
                    habitCompletion: (HabitCompletionEntry value) {
                      return const SizedBox.shrink();
                    },
                  ),
                  EntryDetailFooter(
                    item: widget.item,
                    saveFn: saveText,
                  ),
                ],
              ),
            ),
          ),
        ),
        LinkedEntriesWidget(item: widget.item),
      ],
    );
  }
}
