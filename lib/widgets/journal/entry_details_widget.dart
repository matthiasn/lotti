import 'dart:io';

import 'package:auto_route/annotations.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_quill/flutter_quill.dart' hide Text;
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/theme/theme.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/audio/audio_player.dart';
import 'package:lotti/widgets/journal/editor/editor_tools.dart';
import 'package:lotti/widgets/journal/editor/editor_widget.dart';
import 'package:lotti/widgets/journal/entry_details/entry_detail_footer.dart';
import 'package:lotti/widgets/journal/entry_details/entry_detail_header.dart';
import 'package:lotti/widgets/journal/entry_details/health_summary.dart';
import 'package:lotti/widgets/journal/entry_details/measurement_summary.dart';
import 'package:lotti/widgets/journal/entry_details/survey_summary.dart';
import 'package:lotti/widgets/journal/entry_details/workout_summary.dart';
import 'package:lotti/widgets/journal/entry_image_widget.dart';
import 'package:lotti/widgets/journal/journal_card.dart';
import 'package:lotti/widgets/journal/tags_widget.dart';
import 'package:lotti/widgets/tasks/task_form.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tuple/tuple.dart';

class EntryDetailWidget extends StatefulWidget {
  const EntryDetailWidget({
    super.key,
    @PathParam() required this.itemId,
    required this.popOnDelete,
    this.showTaskDetails = false,
  });

  final String itemId;
  final bool popOnDelete;
  final bool showTaskDetails;

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
        final item = snapshot.data;
        if (item == null || item.meta.deletedAt != null) {
          return const SizedBox.shrink();
        }

        final isTask = item is Task;
        final isAudio = item is JournalAudio;

        if ((isTask || isAudio) && !widget.showTaskDetails) {
          return JournalCard(item: item);
        }

        final controller = makeController(
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
            borderRadius: BorderRadius.circular(8),
            child: ColoredBox(
              color: getIt<ThemeService>().colors.entryCardColor,
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
                  item.map(
                    journalAudio: (JournalAudio audio) {
                      return const AudioPlayerWidget();
                    },
                    workout: WorkoutSummary.new,
                    survey: SurveySummary.new,
                    quantitative: HealthSummary.new,
                    measurement: MeasurementSummary.new,
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
                        final title = formData['title'] as String;
                        final dt = formData['estimate'] as DateTime;
                        final status = formData['status'] as String;

                        final estimate = Duration(
                          hours: dt.hour,
                          minutes: dt.minute,
                        );

                        HapticFeedback.heavyImpact();

                        final updatedData = task.data.copyWith(
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
                    habitCompletion: (_) => const SizedBox.shrink(),
                    journalEntry: (_) => const SizedBox.shrink(),
                    journalImage: (_) => const SizedBox.shrink(),
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
