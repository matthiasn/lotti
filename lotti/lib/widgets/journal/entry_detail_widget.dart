import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_quill/flutter_quill.dart' hide Text;
import 'package:lotti/blocs/journal/persistence_cubit.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
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
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: EntryInfoRow(entityId: widget.item.meta.id),
                  ),
                  widget.item.map(
                    journalAudio: (JournalAudio audio) {
                      QuillController _controller = makeController(
                          serializedQuill: audio.entryText?.quill);
                      void saveText() {
                        EntryText entryText =
                            entryTextFromController(_controller);
                        HapticFeedback.heavyImpact();

                        context
                            .read<PersistenceCubit>()
                            .updateJournalEntityText(
                                widget.item.meta.id, entryText);
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
                      QuillController _controller = makeController(
                          serializedQuill: image.entryText?.quill);

                      void saveText() {
                        EntryText entryText =
                            entryTextFromController(_controller);

                        context
                            .read<PersistenceCubit>()
                            .updateJournalEntityText(
                                widget.item.meta.id, entryText);
                      }

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
                            height: imageTextEditorHeight,
                            saveFn: saveText,
                          ),
                        ],
                      );
                    },
                    journalEntry: (JournalEntry journalEntry) {
                      QuillController _controller = makeController(
                          serializedQuill: journalEntry.entryText.quill);

                      void saveText() {
                        context
                            .read<PersistenceCubit>()
                            .updateJournalEntityText(widget.item.meta.id,
                                entryTextFromController(_controller));
                      }

                      return EditorWidget(
                        controller: _controller,
                        focusNode: _focusNode,
                        readOnly: widget.readOnly,
                        saveFn: saveText,
                      );
                    },
                    measurement: (MeasurementEntry entry) {
                      QuillController _controller = makeController(
                          serializedQuill: entry.entryText?.quill);

                      void saveText() {
                        context
                            .read<PersistenceCubit>()
                            .updateJournalEntityText(widget.item.meta.id,
                                entryTextFromController(_controller));
                      }

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
                      QuillController controller = makeController(
                          serializedQuill: task.entryText?.quill);

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

                        Task updated = task.copyWith(
                          data: updatedData,
                          entryText: entryTextFromController(controller),
                        );

                        context
                            .read<PersistenceCubit>()
                            .updateJournalEntity(updated, updated.meta);
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          LinkedDuration(
                            task: task,
                            width: MediaQuery.of(context).size.width - 80,
                          ),
                          TaskForm(
                            controller: controller,
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
                    loggedTime: (LoggedTime value) {
                      return const SizedBox.shrink();
                    },
                  ),
                  EntryDetailFooter(item: widget.item),
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
