import 'dart:async';

import 'package:drift/drift.dart';
import 'package:lotti/database/common.dart';
import 'package:lotti/utils/file_utils.dart';

part 'editor_db.g.dart';

const editorDbFileName = 'editor_drafts_db.sqlite';

@DriftDatabase(include: {'editor_db.drift'})
class EditorDb extends _$EditorDb {
  EditorDb({this.inMemoryDatabase = false})
      : super(
          openDbConnection(
            editorDbFileName,
            inMemoryDatabase: inMemoryDatabase,
          ),
        );

  final bool inMemoryDatabase;

  @override
  int get schemaVersion => 1;

  Future<int> insertDraftState({
    required String entryId,
    required DateTime lastSaved,
    required String draftDeltaJson,
  }) async {
    await (update(editorDrafts)
          ..where(
            (EditorDrafts draft) =>
                draft.entryId.equals(entryId) & draft.status.equals('DRAFT'),
          ))
        .write(const EditorDraftsCompanion(status: Value('ARCHIVED')));

    final draftState = EditorDraftState(
      id: uuid.v1(),
      status: 'DRAFT',
      entryId: entryId,
      createdAt: DateTime.now(),
      lastSaved: lastSaved,
      delta: draftDeltaJson,
    );
    return into(editorDrafts).insert(draftState);
  }

  Future<int> setDraftSaved({
    required String entryId,
    required DateTime lastSaved,
  }) async {
    return (update(editorDrafts)
          ..where(
            (EditorDrafts draft) =>
                draft.entryId.equals(entryId) & draft.status.equals('DRAFT'),
          ))
        .write(const EditorDraftsCompanion(status: Value('SAVED')));
  }

  Future<EditorDraftState?> getLatestDraft(
    String? entryId, {
    required DateTime lastSaved,
  }) async {
    if (entryId == null) {
      return null;
    }

    final res = await latestDraft(entryId, lastSaved).get();

    if (res.isNotEmpty) {
      return res.first;
    } else {
      return null;
    }
  }
}
