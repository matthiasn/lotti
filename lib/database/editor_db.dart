import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'editor_db.g.dart';

@DriftDatabase(include: {'editor_db.drift'})
class EditorDb extends _$EditorDb {
  EditorDb() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  Future<int> insertDraftState({
    required String entryId,
    required DateTime lastSaved,
    required String draftDeltaJson,
  }) async {
    await (update(editorDrafts)
          ..where((EditorDrafts draft) =>
              draft.entryId.equals(entryId) & draft.status.equals('DRAFT')))
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
    return await (update(editorDrafts)
          ..where(
            (EditorDrafts draft) =>
                draft.entryId.equals(entryId) & draft.status.equals('DRAFT'),
          ))
        .write(const EditorDraftsCompanion(status: Value('SAVED')));
  }

  Future<EditorDraftState?> getLatestDraft(String? entryId) async {
    if (entryId == null) {
      return null;
    }

    List<EditorDraftState> res = await latestDraft(entryId).get();

    if (res.isNotEmpty) {
      return res.first;
    } else {
      return null;
    }
  }
}

Future<File> getEditorDbFile() async {
  final dbFolder = await getApplicationDocumentsDirectory();
  return File(p.join(dbFolder.path, 'editor_drafts_db.sqlite'));
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final file = await getEditorDbFile();
    return NativeDatabase(file);
  });
}
