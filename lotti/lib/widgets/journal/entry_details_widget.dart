import 'dart:io';

import 'package:auto_route/annotations.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_quill/flutter_quill.dart' hide Text;
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/audio/audio_player.dart';
import 'package:lotti/widgets/journal/editor_tools.dart';
import 'package:lotti/widgets/journal/editor_widget.dart';
import 'package:lotti/widgets/journal/entry_details/entry_detail_footer.dart';
import 'package:lotti/widgets/journal/entry_details/entry_detail_header.dart';
import 'package:lotti/widgets/journal/entry_image_widget.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';
import 'package:lotti/widgets/journal/helpers.dart';
import 'package:lotti/widgets/journal/journal_card.dart';
import 'package:lotti/widgets/journal/tags_widget.dart';
import 'package:lotti/widgets/misc/survey_summary.dart';
import 'package:lotti/widgets/tasks/task_form.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tuple/tuple.dart';

class EntryDetailWidget extends StatefulWidget {
  final String entryId;
  final bool readOnly;
  final bool popOnDelete;
  final bool showTaskDetails;

  const EntryDetailWidget({
    Key? key,
    @PathParam() required this.entryId,
    required this.popOnDelete,
    this.readOnly = false,
    this.showTaskDetails = false,
  }) : super(key: key);

  @override
  State<EntryDetailWidget> createState() => _EntryDetailWidgetState();
}

class _EntryDetailWidgetState extends State<EntryDetailWidget> {
  final JournalDb _db = getIt<JournalDb>();
  final FocusNode _focusNode = FocusNode();
  final EditorStateService _editorStateService = getIt<EditorStateService>();

  late final Stream<JournalEntity?> _stream =
      _db.watchEntityById(widget.entryId);

  bool showDetails = false;
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
    return StreamBuilder<JournalEntity?>(
      stream: _stream,
      builder: (
        BuildContext context,
        AsyncSnapshot<JournalEntity?> snapshot,
      ) {
        JournalEntity? item = snapshot.data;
        if (item == null || item.meta.deletedAt != null) {
          return const SizedBox.shrink();
        }

        if (item is Task && !widget.showTaskDetails) {
          return JournalCard(item: item);
        }

        EntryText? entryText = item.map(
          journalEntry: (item) => item.entryText,
          journalImage: (item) => item.entryText,
          journalAudio: (item) => item.entryText,
          task: (item) => item.entryText,
          quantitative: (_) => null,
          measurement: (item) => item.entryText,
          workout: (item) => item.entryText,
          habitCompletion: (item) => item.entryText,
          survey: (_) => null,
        );

        QuillController _controller = makeController(
          serializedQuill:
              _editorStateService.getDelta(item.meta.id) ?? entryText?.quill,
        );

        _controller.changes.listen((Tuple3<Delta, Delta, ChangeSource> event) {
          _editorStateService.saveTempState(item.meta.id, _controller);
        });

        void saveText() {
          _editorStateService.saveState(item.meta.id, _controller);
        }

        return Container(
          margin: const EdgeInsets.all(4),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8.0),
            child: Container(
              color: AppColors.headerBgColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EntryDetailHeader(
                    item: item,
                    saveFn: saveText,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: TagsListWidget(item: item),
                  ),
                  item.map(
                    journalAudio: (JournalAudio audio) {
                      return Column(
                        children: [
                          const AudioPlayerWidget(),
                          EditorWidget(
                            controller: _controller,
                            journalEntity: item,
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
                            journalEntity: item,
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
                        journalEntity: item,
                      );
                    },
                    measurement: (MeasurementEntry entry) {
                      return EditorWidget(
                        controller: _controller,
                        focusNode: _focusNode,
                        readOnly: widget.readOnly,
                        saveFn: saveText,
                        journalEntity: item,
                      );
                    },
                    workout: (WorkoutEntry workout) {
                      WorkoutData data = workout.data;
                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: EntryTextWidget(data.toString()),
                          ),
                          EditorWidget(
                            controller: _controller,
                            focusNode: _focusNode,
                            readOnly: widget.readOnly,
                            saveFn: saveText,
                            journalEntity: item,
                          ),
                        ],
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
                          _editorStateService.saveTask(
                            id: item.meta.id,
                            controller: _controller,
                            taskData: task.data,
                          );

                          return;
                        }
                        //final DateTime due = formData['due'];
                        final String title = formData['title'];
                        final DateTime dt = formData['estimate'];
                        final String status = formData['status'];

                        final Duration estimate = Duration(
                          hours: dt.hour,
                          minutes: dt.minute,
                        );

                        HapticFeedback.heavyImpact();

                        TaskData updatedData = task.data.copyWith(
                          title: title,
                          estimate: estimate,
                          // due: due,
                          status: taskStatusFromString(status),
                        );

                        _editorStateService.saveTask(
                          id: item.meta.id,
                          controller: _controller,
                          taskData: updatedData,
                        );
                      }

                      return TaskForm(
                        controller: _controller,
                        focusNode: _focusNode,
                        saveFn: saveText,
                        formKey: formKey,
                        data: task.data,
                        task: task,
                      );
                    },
                    habitCompletion: (HabitCompletionEntry value) {
                      return const SizedBox.shrink();
                    },
                  ),
                  EntryDetailFooter(
                    item: item,
                    saveFn: saveText,
                    popOnDelete: widget.popOnDelete,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
