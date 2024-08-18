import 'dart:convert';

import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_links.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/sync_message.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:matrix/matrix.dart';

/// Process a sync message from the room that the client has joined.
/// Takes decrypted [Event] and tries to insert into the local database
/// if not already contained, or in conflict with an existing entry.
/// The conflicts are checked as part of the call to JournalDb.

Future<void> processMatrixMessage({
  required Event event,
  required MatrixService service,
  JournalDb? overriddenJournalDb,
}) async {
  final journalDb = overriddenJournalDb ?? getIt<JournalDb>();
  final loggingDb = getIt<LoggingDb>();
  final message = event.text;
  final updateNotifications = getIt<UpdateNotifications>();

  try {
    final decoded = utf8.decode(base64.decode(message));

    final syncMessage = SyncMessage.fromJson(
      json.decode(decoded) as Map<String, dynamic>,
    );

    loggingDb.captureEvent(
      'processing ${event.originServerTs} ${event.eventId}',
      domain: 'MATRIX_SERVICE',
      subDomain: 'processMessage',
    );

    await syncMessage.when(
      journalEntity: (
        JournalEntity journalEntity,
        SyncEntryStatus status,
      ) async {
        await saveJournalEntityJson(journalEntity);
        await journalDb.updateJournalEntity(journalEntity);
        updateNotifications.notify(journalEntity.affectedIds);
      },
      entryLink: (EntryLink entryLink, SyncEntryStatus _) {
        journalDb.upsertEntryLink(entryLink);
        updateNotifications.notify({entryLink.fromId, entryLink.toId});
      },
      entityDefinition: (
        EntityDefinition entityDefinition,
        SyncEntryStatus status,
      ) {
        journalDb.upsertEntityDefinition(entityDefinition);
      },
      tagEntity: (
        TagEntity tagEntity,
        SyncEntryStatus status,
      ) {
        journalDb.upsertTagEntity(tagEntity);
      },
    );
  } catch (e, stackTrace) {
    loggingDb.captureException(
      e,
      domain: 'MATRIX_SERVICE',
      subDomain: 'processMessage',
      stackTrace: stackTrace,
    );
  }
}
