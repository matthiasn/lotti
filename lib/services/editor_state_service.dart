import 'dart:async';

import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/editor_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/utils/platform.dart';

class EditorStateService {
  EditorStateService() {
    init();
  }

  final JournalDb _journalDb = getIt<JournalDb>();
  final EditorDb _editorDb = getIt<EditorDb>();
  final editorStateById = <String, String>{};
  final selectionById = <String, TextSelection>{};
  final unsavedStreamById = <String, StreamController<bool>>{};

  Future<void> init() async {
    final drafts = await _editorDb.allDrafts().get();
    if (drafts.isEmpty) return;

    // One bulk fetch instead of N serial `entityById` round-trips. The
    // super-slow log showed a 10-deep cluster of `WHERE id = ? AND
    // deleted = ?` selects firing in series at startup; coalescing them
    // into one `id IN (...)` query collapses the wave and unblocks the
    // editor warm-up.
    final entryIds = {for (final d in drafts) d.entryId};
    // Unordered variant — we build a `Map<id, entity>` for direct
    // lookup, so the `ORDER BY date_from DESC` of the ordered drift
    // query is wasted work here.
    final entities = await _journalDb
        .journalEntitiesByIdsUnorderedAllPrivate(
          entryIds.toList(growable: false),
        )
        .get();
    final entityById = <String, JournalDbEntity>{
      for (final entity in entities) entity.id: entity,
    };

    for (final draft in drafts) {
      if (entityById[draft.entryId]?.updatedAt == draft.lastSaved) {
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

      _editorDb.getLatestDraft(id, lastSaved: lastSaved).then((
        EditorDraftState? value,
      ) {
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
    required String json,
  }) {
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
      Duration(seconds: isTestEnv ? 0 : 2),
      persistDraftState,
    );
  }

  Future<void> entryWasSaved({
    required String id,
    required DateTime lastSaved,
    required QuillController controller,
  }) async {
    saveSelection(id, controller.selection);
    EasyDebounce.cancel('persistDraftState-$id');
    await _editorDb.setDraftSaved(entryId: id, lastSaved: lastSaved);

    final unsavedStreamController = unsavedStreamById[id];
    editorStateById.remove(id);

    if (unsavedStreamController != null) {
      unsavedStreamController.add(false);
    }
  }

  /// Drops any unsaved draft for [id] without persisting it.
  ///
  /// The reverse of editing: cancels the pending debounced write, clears the
  /// in-memory delta and selection, marks the latest persisted draft as saved
  /// (so it is not restored on reopen), and emits `false` on the unsaved stream.
  /// Used by "discard changes" — the saved entry text becomes the source of
  /// truth again.
  Future<void> dropDraft({
    required String id,
    required DateTime lastSaved,
  }) async {
    EasyDebounce.cancel('persistDraftState-$id');
    editorStateById.remove(id);
    selectionById.remove(id);
    await _editorDb.setDraftSaved(entryId: id, lastSaved: lastSaved);
    unsavedStreamById[id]?.add(false);
  }

  bool entryIsUnsaved(String id) => editorStateById.containsKey(id);
}
