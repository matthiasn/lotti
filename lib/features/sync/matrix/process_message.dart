import 'dart:convert';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
// import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/logging_service.dart';
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
  final message = event.text;
  final updateNotifications = getIt<UpdateNotifications>();

  try {
    final decoded = utf8.decode(base64.decode(message));

    final syncMessage = SyncMessage.fromJson(
      json.decode(decoded) as Map<String, dynamic>,
    );

    getIt<LoggingService>().captureEvent(
      'processing ${event.originServerTs} ${event.eventId}',
      domain: 'MATRIX_SERVICE',
      subDomain: 'processMessage',
    );

    switch (syncMessage) {
      case SyncJournalEntity(jsonPath: final jsonPath):
        final docDir = getDocumentsDirectory();
        final fullPath = '${docDir.path}$jsonPath';
        final journalEntity = await readEntityFromJson(fullPath);
        await journalDb.updateJournalEntity(journalEntity);
        updateNotifications.notify(
          journalEntity.affectedIds,
          fromSync: true,
        );
      case SyncEntryLink(entryLink: final entryLink):
        await journalDb.upsertEntryLink(entryLink);
        updateNotifications.notify(
          {entryLink.fromId, entryLink.toId},
          fromSync: true,
        );

      case SyncEntityDefinition(entityDefinition: final entityDefinition):
        await journalDb.upsertEntityDefinition(entityDefinition);

      case SyncTagEntity(tagEntity: final tagEntity):
        await journalDb.upsertTagEntity(tagEntity);

      case SyncAiConfig(aiConfig: final aiConfig):
        await getIt<AiConfigRepository>().saveConfig(
          aiConfig,
          fromSync: true,
        );

      case SyncAiConfigDelete(id: final id):
        await getIt<AiConfigRepository>().deleteConfig(
          id,
          fromSync: true,
        );
    }
  } catch (e, stackTrace) {
    getIt<LoggingService>().captureException(
      e,
      domain: 'MATRIX_SERVICE',
      subDomain: 'processMessage',
      stackTrace: stackTrace,
    );
  }
}
