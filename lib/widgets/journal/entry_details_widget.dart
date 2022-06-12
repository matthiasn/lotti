import 'dart:io';

import 'package:auto_route/annotations.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_quill/flutter_quill.dart' hide Text;
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/audio/audio_player.dart';
import 'package:lotti/widgets/journal/editor/editor_tools.dart';
import 'package:lotti/widgets/journal/editor/editor_widget.dart';
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
  final String itemId;
  final bool popOnDelete;
  final bool showTaskDetails;

  const EntryDetailWidget({
    Key? key,
    @PathParam() required this.itemId,
    required this.popOnDelete,
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
      _db.watchEntityById(widget.itemId);

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

        bool isTask = item is Task;
        bool isAudio = item is JournalAudio;

        if ((isTask || isAudio) && !widget.showTaskDetails) {
          return JournalCard(item: item);
        }

        QuillController controller = makeController(
          serializedQuill: _editorStateService.getDelta(widget.itemId) ??
              item.entryText?.quill,
          selection: _editorStateService.getSelection(widget.itemId),
        );

        controller.changes.listen((Tuple3<Delta, Delta, ChangeSource> event) {
          _editorStateService.saveTempState(
            id: widget.itemId,
            controller: controller,
            lastSaved: item.meta.updatedAt,
          );
        });

        void saveText() {
          _editorStateService.saveState(
            id: widget.itemId,
            lastSaved: item.meta.updatedAt,
            controller: controller,
          );

          if (isMobile) {
            _focusNode.unfocus();
          }
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                spreadRadius: 3,
                blurRadius: 5,
                offset: const Offset(0, 3), // changes position of shadow
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8.0),
            child: Container(
              color: AppColors.entryCardColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  item.maybeMap(
                    journalImage: (image) {
                      return Container(
                        width: MediaQuery.of(context).size.width,
                        color: Colors.black,
                        child: EntryImageWidget(
                          focusNode: _focusNode,
                          journalImage: image,
                        ),
                      );
                    },
                    orElse: () => const SizedBox.shrink(),
                  ),
                  EntryDetailHeader(
                    itemId: widget.itemId,
                    saveFn: saveText,
                  ),
                  Padding(
                    padding: EdgeInsets.only(
                      left: 8,
                      right: 8,
                      bottom: isTask ? 0 : 8,
                    ),
                    child: TagsListWidget(widget.itemId),
                  ),
                  item.maybeMap(
                    task: (_) => const SizedBox.shrink(),
                    quantitative: (_) => const SizedBox.shrink(),
                    measurement: (_) => const SizedBox.shrink(),
                    workout: (_) => const SizedBox.shrink(),
                    survey: (_) => const SizedBox.shrink(),
                    orElse: () {
                      return EditorWidget(
                        controller: controller,
                        focusNode: _focusNode,
                        journalEntity: item,
                        saveFn: saveText,
                      );
                    },
                  ),
                  item.maybeMap(
                    journalAudio: (JournalAudio audio) {
                      return const AudioPlayerWidget();
                    },
                    workout: (WorkoutEntry workout) {
                      WorkoutData data = workout.data;
                      return Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: EntryTextWidget(data.toString()),
                      );
                    },
                    survey: (SurveyEntry surveyEntry) =>
                        SurveySummaryWidget(surveyEntry),
                    quantitative: (qe) => Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 16,
                      ),
                      child: InfoText(entryTextForQuant(qe)),
                    ),
                    task: (Task task) {
                      final formKey = GlobalKey<FormBuilderState>();

                      void saveText() {
                        formKey.currentState?.save();
                        final formData = formKey.currentState?.value;
                        if (formData == null) {
                          _editorStateService.saveTask(
                            id: widget.itemId,
                            controller: controller,
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
                          id: widget.itemId,
                          controller: controller,
                          taskData: updatedData,
                        );
                      }

                      return TaskForm(
                        controller: controller,
                        focusNode: _focusNode,
                        saveFn: saveText,
                        formKey: formKey,
                        data: task.data,
                        task: task,
                      );
                    },
                    orElse: () {
                      return const SizedBox.shrink();
                    },
                  ),
                  EntryDetailFooter(
                    itemId: widget.itemId,
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
