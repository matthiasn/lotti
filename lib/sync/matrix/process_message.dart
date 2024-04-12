import 'dart:convert';

import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_links.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/sync_message.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:matrix/matrix.dart';

Future<void> processMatrixMessage(
  Event event, {
  JournalDb? overriddenJournalDb,
}) async {
  final journalDb = overriddenJournalDb ?? getIt<JournalDb>();
  final loggingDb = getIt<LoggingDb>();
  final message = event.text;

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
      },
      entryLink: (EntryLink entryLink, SyncEntryStatus _) {
        journalDb.upsertEntryLink(entryLink);
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
