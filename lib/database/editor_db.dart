import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:lotti/database/common.dart';
import 'package:lotti/utils/file_utils.dart';

part 'editor_db.g.dart';

/// Database filename for editor drafts
const editorDbFileName = 'editor_drafts_db.sqlite';

/// Draft status constants
const String _draftStatusDraft = 'DRAFT';
const String _draftStatusSaved = 'SAVED';
const String _draftStatusArchived = 'ARCHIVED';

@DriftDatabase(include: {'editor_db.drift'})
class EditorDb extends _$EditorDb {
  EditorDb({
    this.inMemoryDatabase = false,
    Future<Directory> Function()? documentsDirectoryProvider,
    Future<Directory> Function()? tempDirectoryProvider,
  }) : super(
          openDbConnection(
            editorDbFileName,
            inMemoryDatabase: inMemoryDatabase,
            documentsDirectoryProvider: documentsDirectoryProvider,
            tempDirectoryProvider: tempDirectoryProvider,
          ),
        );

  final bool inMemoryDatabase;

  @override
  int get schemaVersion => 1;

  /// Inserts a new draft state for an entry.
  ///
  /// Archives any existing drafts for the same [entryId] and creates a new
  /// draft with the provided content. Each draft is uniquely identified and
  /// timestamped.
  ///
  /// Parameters:
  /// - [entryId]: The ID of the entry this draft belongs to
  /// - [lastSaved]: Timestamp when this draft was last saved
  /// - [draftDeltaJson]: The draft content in Delta JSON format
  ///
  /// Returns the row ID of the newly inserted draft.
  ///
  /// Example:
  /// ```dart
  /// final id = await db.insertDraftState(
  ///   entryId: 'entry-123',
  ///   lastSaved: DateTime.now(),
  ///   draftDeltaJson: '{"ops":[{"insert":"Hello"}]}',
  /// );
  /// ```
  Future<int> insertDraftState({
    required String entryId,
    required DateTime lastSaved,
    required String draftDeltaJson,
  }) async {
    await (update(editorDrafts)
          ..where(
            (EditorDrafts draft) =>
                draft.entryId.equals(entryId) &
                draft.status.equals(_draftStatusDraft),
          ))
        .write(
            const EditorDraftsCompanion(status: Value(_draftStatusArchived)));

    final draftState = EditorDraftState(
      id: uuid.v1(),
      status: _draftStatusDraft,
      entryId: entryId,
      createdAt: DateTime.now(),
      lastSaved: lastSaved,
      delta: draftDeltaJson,
    );
    return into(editorDrafts).insert(draftState);
  }

  /// Marks a draft as saved.
  ///
  /// Updates the status of a draft from DRAFT to SAVED for the specified entry.
  /// Only affects drafts with status DRAFT.
  ///
  /// Parameters:
  /// - [entryId]: The ID of the entry whose draft should be marked as saved
  /// - [lastSaved]: The timestamp used to identify the draft
  ///
  /// Returns the number of rows updated (typically 0 or 1).
  ///
  /// Example:
  /// ```dart
  /// final updated = await db.setDraftSaved(
  ///   entryId: 'entry-123',
  ///   lastSaved: timestamp,
  /// );
  /// ```
  Future<int> setDraftSaved({
    required String entryId,
    required DateTime lastSaved,
  }) async {
    return (update(editorDrafts)
          ..where(
            (EditorDrafts draft) =>
                draft.entryId.equals(entryId) &
                draft.status.equals(_draftStatusDraft),
          ))
        .write(const EditorDraftsCompanion(status: Value(_draftStatusSaved)));
  }

  /// Retrieves the latest draft for an entry.
  ///
  /// Fetches the most recent draft (by creation time) for the specified entry
  /// that matches the given timestamp. Only returns drafts with status DRAFT.
  ///
  /// Parameters:
  /// - [entryId]: The ID of the entry to fetch the draft for (returns null if null)
  /// - [lastSaved]: The timestamp to match against the draft's lastSaved field
  ///
  /// Returns the latest matching [EditorDraftState] or null if not found.
  ///
  /// Example:
  /// ```dart
  /// final draft = await db.getLatestDraft(
  ///   'entry-123',
  ///   lastSaved: timestamp,
  /// );
  /// if (draft != null) {
  ///   print('Found draft: ${draft.delta}');
  /// }
  /// ```
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
