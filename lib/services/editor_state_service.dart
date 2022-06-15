import 'dart:async';

import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/editor_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/widgets/journal/editor/editor_tools.dart';

class EditorStateService {
  EditorStateService() {
    init();
  }

  final JournalDb _journalDb = getIt<JournalDb>();
  final PersistenceLogic _persistenceLogic = getIt<PersistenceLogic>();
  final EditorDb _editorDb = getIt<EditorDb>();
  final editorStateById = <String, String>{};
  final selectionById = <String, TextSelection>{};
  final unsavedStreamById = <String, StreamController<bool>>{};

  Future<void> init() async {
    final drafts = await _editorDb.allDrafts().get();

    for (final draft in drafts) {
      final entity = await _journalDb.entityById(draft.entryId);

      if (entity?.updatedAt == draft.lastSaved) {
        editorStateById[draft.entryId] = draft.delta;
      }
    }
  }

  Stream<bool> getUnsavedStream(String? id, DateTime lastSaved) {
    final unsavedStreamController = StreamController<bool>();

    if (id != null) {
      final existing = unsavedStreamById[id];

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
    final delta = deltaFromController(controller);
    final json = quillJsonFromDelta(delta);
    editorStateById[id] = json;
    selectionById.remove(id);

    final unsavedStreamController = unsavedStreamById[id];
    if (unsavedStreamController != null) {
      unsavedStreamController.add(true);
    }

    void persistDraftState() {
      final latest = editorStateById[id];

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

  Future<void> saveState({
    required String id,
    required DateTime lastSaved,
    required QuillController controller,
  }) async {
    saveSelection(id, controller.selection);
    EasyDebounce.cancel('persistDraftState-$id');
    final entryText = entryTextFromController(controller);
    await _persistenceLogic.updateJournalEntityText(id, entryText);
    await _editorDb.setDraftSaved(entryId: id, lastSaved: lastSaved);

    final unsavedStreamController = unsavedStreamById[id];
    editorStateById.remove(id);

    if (unsavedStreamController != null) {
      unsavedStreamController.add(false);
    }

    await HapticFeedback.heavyImpact();
  }

  Future<void> saveTask({
    required String id,
    required QuillController controller,
    required TaskData taskData,
  }) async {
    saveSelection(id, controller.selection);
    EasyDebounce.cancel('persistDraftState-$id');

    await _persistenceLogic.updateTask(
      entryText: entryTextFromController(controller),
      journalEntityId: id,
      taskData: taskData,
    );

    final unsavedStreamController = unsavedStreamById[id];
    editorStateById.remove(id);

    if (unsavedStreamController != null) {
      unsavedStreamController.add(false);
    }

    await HapticFeedback.heavyImpact();
  }
}
