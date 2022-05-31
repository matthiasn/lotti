import 'dart:async';

import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/editor_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/widgets/journal/editor/editor_tools.dart';

class EditorStateService {
  final JournalDb _journalDb = getIt<JournalDb>();
  final PersistenceLogic _persistenceLogic = getIt<PersistenceLogic>();
  final EditorDb _editorDb = getIt<EditorDb>();

  final editorStateById = <String, String>{};
  final selectionById = <String, TextSelection>{};
  final unsavedStreamById = <String, StreamController<bool>>{};

  EditorStateService() {
    init();
  }

  Future<void> init() async {
    List<EditorDraftState> drafts = await _editorDb.allDrafts().get();

    for (EditorDraftState draft in drafts) {
      JournalDbEntity? entity = await _journalDb.entityById(draft.entryId);

      if (entity?.updatedAt == draft.lastSaved) {
        editorStateById[draft.entryId] = draft.delta;
      }
    }
  }

  Stream<bool> getUnsavedStream(String? id, DateTime lastSaved) {
    StreamController<bool> unsavedStreamController = StreamController<bool>();

    if (id != null) {
      StreamController<bool>? existing = unsavedStreamById[id];

      if (existing != null) {
        existing.close();
      }

      unsavedStreamById[id] = unsavedStreamController;

      _editorDb
          .getLatestDraft(id, lastSaved: lastSaved)
          .then((EditorDraftState? value) {
        if (value != null) {
          editorStateById[id] = value.delta;
          unsavedStreamController.add(editorStateById[id] != null);
        }
      });
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
    selectionById[id] = selection;
  }

  void saveTempState({
    required String id,
    required DateTime lastSaved,
    required QuillController controller,
  }) {
    Delta delta = deltaFromController(controller);
    String json = quillJsonFromDelta(delta);
    editorStateById[id] = json;
    selectionById.remove(id);

    StreamController<bool>? unsavedStreamController = unsavedStreamById[id];
    if (unsavedStreamController != null) {
      unsavedStreamController.add(true);
    }

    void persistDraftState() {
      String? latest = editorStateById[id];

      if (latest != null) {
        _editorDb.insertDraftState(
          entryId: id,
          lastSaved: lastSaved,
          draftDeltaJson: latest,
        );
      }
    }

    EasyDebounce.debounce(
      'persistDraftState-$id',
      const Duration(seconds: 2),
      persistDraftState,
    );
  }

  void saveState({
    required String id,
    required DateTime lastSaved,
    required QuillController controller,
  }) async {
    saveSelection(id, controller.selection);
    EasyDebounce.cancel('persistDraftState-$id');
    EntryText entryText = entryTextFromController(controller);
    await _persistenceLogic.updateJournalEntityText(id, entryText);
    await _editorDb.setDraftSaved(entryId: id, lastSaved: lastSaved);

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
    saveSelection(id, controller.selection);
    EasyDebounce.cancel('persistDraftState-$id');

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
