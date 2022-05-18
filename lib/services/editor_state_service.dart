import 'dart:async';

import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/editor_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/widgets/journal/editor/editor_tools.dart';

class EditorStateService {
  final PersistenceLogic _persistenceLogic = getIt<PersistenceLogic>();
  final EditorDb _editorDb = getIt<EditorDb>();

  final editorStateById = <String, String>{};
  final selectionById = <String, TextSelection>{};
  final unsavedStreamById = <String, StreamController<bool>>{};

  EditorStateService();

  Stream<bool> getUnsavedStream(String? id) {
    StreamController<bool> unsavedStreamController = StreamController<bool>();

    if (id != null) {
      StreamController<bool>? existing = unsavedStreamById[id];

      if (existing != null) {
        existing.close();
      }

      unsavedStreamById[id] = unsavedStreamController;
    }

    unsavedStreamController.add(editorStateById[id] != null);

    return unsavedStreamController.stream;
  }

  String? getDelta(String? id) {
    return editorStateById[id];
  }

  TextSelection? getSelection(String? id) {
    return selectionById[id];
  }

  void saveSelection(String id, TextSelection selection) {
    debugPrint(selection.toString());
    selectionById[id] = selection;
  }

  void saveTempState(String id, QuillController controller) {
    Delta delta = deltaFromController(controller);
    String json = quillJsonFromDelta(delta);
    editorStateById[id] = json;

    StreamController<bool>? unsavedStreamController = unsavedStreamById[id];
    if (unsavedStreamController != null) {
      unsavedStreamController.add(true);
    }

    EasyDebounce.debounce(
      'tempSaveDelta-$id',
      const Duration(seconds: 10),
      () {
        debugPrint('saveTempState debounced $id ${editorStateById[id]}');
        _editorDb.insertDraftState(
          entryId: id,
          draftDeltaJson: json,
        );
      },
    );
  }

  void saveState(String id, QuillController controller) async {
    EasyDebounce.cancel('tempSaveDelta-$id');
    EntryText entryText = entryTextFromController(controller);
    await _persistenceLogic.updateJournalEntityText(id, entryText);

    StreamController<bool>? unsavedStreamController = unsavedStreamById[id];
    editorStateById.remove(id);

    if (unsavedStreamController != null) {
      unsavedStreamController.add(false);
    }

    HapticFeedback.heavyImpact();
  }

  void saveTask({
    required String id,
    required QuillController controller,
    required TaskData taskData,
  }) async {
    EasyDebounce.cancel('tempSaveDelta-$id');

    _persistenceLogic.updateTask(
      entryText: entryTextFromController(controller),
      journalEntityId: id,
      taskData: taskData,
    );

    StreamController<bool>? unsavedStreamController = unsavedStreamById[id];
    editorStateById.remove(id);

    if (unsavedStreamController != null) {
      unsavedStreamController.add(false);
    }

    HapticFeedback.heavyImpact();
  }
}
