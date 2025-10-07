// ignore_for_file: one_member_abstracts

import 'dart:convert';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:matrix/matrix.dart';

/// Abstraction for loading journal entities and related attachments when
/// processing sync messages.
abstract class SyncJournalEntityLoader {
  Future<JournalEntity> load(String jsonPath);
}

/// Loads journal entities from the documents directory on disk.
class FileSyncJournalEntityLoader implements SyncJournalEntityLoader {
  const FileSyncJournalEntityLoader();

  @override
  Future<JournalEntity> load(String jsonPath) async {
    final docDir = getDocumentsDirectory();
    final fullPath = '${docDir.path}$jsonPath';
    return readEntityFromJson(fullPath);
  }
}

/// Decodes timeline events from Matrix and persists them locally.
class SyncEventProcessor {
  SyncEventProcessor({
    required LoggingService loggingService,
    required UpdateNotifications updateNotifications,
    required AiConfigRepository aiConfigRepository,
    SyncJournalEntityLoader? journalEntityLoader,
  })  : _loggingService = loggingService,
        _updateNotifications = updateNotifications,
        _aiConfigRepository = aiConfigRepository,
        _journalEntityLoader =
            journalEntityLoader ?? const FileSyncJournalEntityLoader();

  final LoggingService _loggingService;
  final UpdateNotifications _updateNotifications;
  final AiConfigRepository _aiConfigRepository;
  final SyncJournalEntityLoader _journalEntityLoader;

  Future<void> process({
    required Event event,
    required JournalDb journalDb,
  }) async {
    try {
      final raw = event.text;
      final decoded = utf8.decode(base64.decode(raw));
      final messageJson = json.decode(decoded) as Map<String, dynamic>;
      final syncMessage = SyncMessage.fromJson(messageJson);

      _loggingService.captureEvent(
        'processing ${event.originServerTs} ${event.eventId}',
        domain: 'MATRIX_SERVICE',
        subDomain: 'processMessage',
      );

      await _handleMessage(
        syncMessage: syncMessage,
        journalDb: journalDb,
        loader: _journalEntityLoader,
      );
    } catch (error, stackTrace) {
      _loggingService.captureException(
        error,
        domain: 'MATRIX_SERVICE',
        subDomain: 'processMessage',
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _handleMessage({
    required SyncMessage syncMessage,
    required JournalDb journalDb,
    required SyncJournalEntityLoader loader,
  }) async {
    switch (syncMessage) {
      case SyncJournalEntity(jsonPath: final jsonPath):
        final journalEntity = await loader.load(jsonPath);
        await journalDb.updateJournalEntity(journalEntity);
        _updateNotifications.notify(
          journalEntity.affectedIds,
          fromSync: true,
        );
      case SyncEntryLink(entryLink: final entryLink):
        await journalDb.upsertEntryLink(entryLink);
        _updateNotifications.notify(
          {entryLink.fromId, entryLink.toId},
          fromSync: true,
        );
      case SyncEntityDefinition(entityDefinition: final entityDefinition):
        await journalDb.upsertEntityDefinition(entityDefinition);
      case SyncTagEntity(tagEntity: final tagEntity):
        await journalDb.upsertTagEntity(tagEntity);
      case SyncAiConfig(aiConfig: final aiConfig):
        await _aiConfigRepository.saveConfig(
          aiConfig,
          fromSync: true,
        );
      case SyncAiConfigDelete(id: final id):
        await _aiConfigRepository.deleteConfig(
          id,
          fromSync: true,
        );
    }
  }
}
