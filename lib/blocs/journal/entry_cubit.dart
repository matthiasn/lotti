import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:lotti/blocs/journal/entry_state.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/journal/editor/editor_tools.dart';
import 'package:tuple/tuple.dart';

class EntryCubit extends Cubit<EntryState> {
  EntryCubit({
    required this.entryId,
    required this.entry,
  }) : super(
          EntryState.saved(
            entryId: entryId,
            entry: entry,
          ),
        ) {
    final lastSaved = entry.meta.updatedAt;
    debugPrint('EntryCubit $entryId $lastSaved');

    _editorStateService
        .getUnsavedStream(entryId, lastSaved)
        .listen((bool dirty) {
      debugPrint('EntryCubit $entryId getUnsavedStream $dirty');
      if (dirty) {
        emit(EntryState.dirty(entryId: entryId, entry: entry));
      } else {
        emit(EntryState.saved(entryId: entryId, entry: entry));
      }
    });

    if (entry is Task) {
      formKey = GlobalKey<FormBuilderState>();
    }

    controller = makeController(
      serializedQuill:
          _editorStateService.getDelta(entryId) ?? entry.entryText?.quill,
      selection: _editorStateService.getSelection(entryId),
    );

    controller.changes.listen((Tuple3<Delta, Delta, ChangeSource> event) {
      final delta = deltaFromController(controller);
      _editorStateService.saveTempState(
        id: entryId,
        json: quillJsonFromDelta(delta),
        lastSaved: entry.meta.updatedAt,
      );
      emit(
        EntryState.dirty(
          entry: entry,
          entryId: entryId,
        ),
      );
    });
  }

  String entryId;
  JournalEntity entry;

  late final QuillController controller;
  late final GlobalKey<FormBuilderState>? formKey;
  final FocusNode focusNode = FocusNode();
  final EditorStateService _editorStateService = getIt<EditorStateService>();
  final PersistenceLogic _persistenceLogic = getIt<PersistenceLogic>();

  Future<void> save() async {
    debugPrint('EntryCubit saving $entryId');

    if (entry is Task) {
      await saveTask();
    } else {
      await _persistenceLogic.updateJournalEntityText(
        entryId,
        entryTextFromController(controller),
      );

      await _editorStateService.entryWasSaved(
        id: entryId,
        lastSaved: entry.meta.updatedAt,
        controller: controller,
      );
      emit(
        EntryState.saved(
          entryId: entryId,
          entry: entry,
        ),
      );
    }
    await HapticFeedback.heavyImpact();
  }

  Future<void> saveTask() async {
    debugPrint('EntryCubit saving task $entryId');

    if (entry is Task) {
      final task = entry as Task;

      formKey?.currentState?.save();
      final formData = formKey?.currentState?.value;
      final title = formData!['title'] as String;
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
        status: taskStatusFromString(status),
      );

      await _persistenceLogic.updateTask(
        entryText: entryTextFromController(controller),
        journalEntityId: entryId,
        taskData: updatedData,
      );

      await _editorStateService.entryWasSaved(
        id: entryId,
        lastSaved: entry.meta.updatedAt,
        controller: controller,
      );
    }
  }

  @override
  Future<void> close() async {
    debugPrint('EntryCubit closing $entryId');
    if (!isTestEnv) {
      await save();
    }
    await super.close();
  }
}
