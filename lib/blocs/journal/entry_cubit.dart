import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:lotti/blocs/journal/entry_state.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/widgets/journal/editor/editor_tools.dart';
import 'package:tuple/tuple.dart';

class EntryCubit extends Cubit<EntryState> {
  EntryCubit({
    required this.entryId,
    required this.entry,
  }) : super(
          EntryState(
            entryId: entryId,
            dirty: false,
            entry: null,
          ),
        ) {
    debugPrint('EntryCubit $entryId');

    if (entry is Task) {
      formKey = GlobalKey<FormBuilderState>();
    }

    controller = makeController(
      serializedQuill:
          _editorStateService.getDelta(entryId) ?? entry.entryText?.quill,
      selection: _editorStateService.getSelection(entryId),
    );

    controller.changes.listen((Tuple3<Delta, Delta, ChangeSource> event) {
      _editorStateService.saveTempState(
        id: entryId,
        controller: controller,
        lastSaved: entry.meta.updatedAt,
      );
    });
  }

  String entryId;
  JournalEntity entry;

  late final QuillController controller;
  late final GlobalKey<FormBuilderState>? formKey;
  final EditorStateService _editorStateService = getIt<EditorStateService>();

  Future<void> save() async {
    debugPrint('EntryCubit saving $entryId');

    await _editorStateService.saveState(
      id: entryId,
      lastSaved: entry.meta.updatedAt,
      controller: controller,
    );

    if (entry is Task) {
      await saveTask();
    }
  }

  Future<void> saveTask() async {
    if (entry is Task) {
      final task = entry as Task;

      formKey?.currentState?.save();
      final formData = formKey?.currentState?.value;
      if (formData == null) {
        await _editorStateService.saveTask(
          id: entryId,
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

      await HapticFeedback.heavyImpact();

      final updatedData = task.data.copyWith(
        title: title,
        estimate: estimate,
        // due: due,
        status: taskStatusFromString(status),
      );

      await _editorStateService.saveTask(
        id: entryId,
        controller: controller,
        taskData: updatedData,
      );
    }
  }

  @override
  Future<void> close() async {
    debugPrint('EntryCubit closing $entryId');
    await save();
    await super.close();
  }
}
