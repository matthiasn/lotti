// ignore_for_file: one_member_abstracts

import 'dart:convert';
import 'dart:io';

import 'package:enum_to_string/enum_to_string.dart';
import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/journal_update_result.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/settings/constants/theming_settings_keys.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:matrix/matrix.dart';
import 'package:path/path.dart' as path;

/// Abstraction for loading journal entities when processing sync messages.
abstract class SyncJournalEntityLoader {
  Future<JournalEntity> load({
    required String jsonPath,
    VectorClock? incomingVectorClock,
  });
}

/// Loads journal entities from the documents directory on disk.
///
/// This is a simple file-based loader that reads JSON files directly from disk.
/// Attachments are downloaded eagerly by `AttachmentIngestor` during sync,
/// so the files should already be present when this loader is called.
/// If a file is missing, the sync event processing will fail and retry
/// on the next catch-up cycle.
class FileSyncJournalEntityLoader implements SyncJournalEntityLoader {
  const FileSyncJournalEntityLoader();

  @override
  Future<JournalEntity> load({
    required String jsonPath,
    VectorClock? incomingVectorClock,
  }) async {
    final candidateFile = resolveJsonCandidateFile(jsonPath);
    final docPath = path.normalize(getDocumentsDirectory().path);
    final jsonRelative = path.relative(candidateFile.path, from: docPath);
    return readEntityFromJson(jsonRelative);
  }
}

/// Decodes timeline events from Matrix and persists them locally.
class SyncEventProcessor {
  SyncEventProcessor({
    required LoggingService loggingService,
    required UpdateNotifications updateNotifications,
    required AiConfigRepository aiConfigRepository,
    required SettingsDb settingsDb,
    SyncJournalEntityLoader? journalEntityLoader,
  })  : _loggingService = loggingService,
        _updateNotifications = updateNotifications,
        _aiConfigRepository = aiConfigRepository,
        _settingsDb = settingsDb,
        _journalEntityLoader =
            journalEntityLoader ?? const FileSyncJournalEntityLoader();

  final LoggingService _loggingService;
  final UpdateNotifications _updateNotifications;
  final AiConfigRepository _aiConfigRepository;
  final SettingsDb _settingsDb;
  final SyncJournalEntityLoader _journalEntityLoader;
  void Function(SyncApplyDiagnostics diag)? applyObserver;

  /// Kept for API compatibility but no longer used since we removed
  /// SmartJournalEntityLoader. Setting this is a no-op.
  void Function()? cachePurgeListener;

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
        subDomain: 'SyncEventProcessor',
      );

      final diag = await _handleMessage(
        event: event,
        syncMessage: syncMessage,
        journalDb: journalDb,
        loader: _journalEntityLoader,
      );
      if (diag != null) {
        applyObserver?.call(diag);
      }
    } catch (error, stackTrace) {
      _loggingService.captureException(
        error,
        domain: 'MATRIX_SERVICE',
        subDomain: 'SyncEventProcessor',
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<SyncApplyDiagnostics?> _handleMessage({
    required Event event,
    required SyncMessage syncMessage,
    required JournalDb journalDb,
    required SyncJournalEntityLoader loader,
  }) async {
    switch (syncMessage) {
      case SyncJournalEntity(
          jsonPath: final jsonPath,
          entryLinks: final entryLinks,
        ):
        try {
          final journalEntity = await loader.load(
            jsonPath: jsonPath,
            incomingVectorClock: syncMessage.vectorClock,
          );
          var predictedStatus = VclockStatus.b_gt_a;
          if (applyObserver != null) {
            try {
              final existing =
                  await journalDb.journalEntityById(journalEntity.meta.id);
              final vcA = existing?.meta.vectorClock;
              final vcB0 = journalEntity.meta.vectorClock;
              if (vcA != null && vcB0 != null) {
                predictedStatus = VectorClock.compare(vcA, vcB0);
              }
            } catch (e, st) {
              _loggingService.captureException(
                e,
                domain: 'MATRIX_SERVICE',
                subDomain: 'apply.predictVectorClock',
                stackTrace: st,
              );
              predictedStatus = VclockStatus.b_gt_a;
            }
          }
          final vcB = journalEntity.meta.vectorClock;
          final updateResult =
              await journalDb.updateJournalEntity(journalEntity);
          final rows = updateResult.rowsWritten ?? 0;

          // Process embedded entry links AFTER successful journal entity persistence
          var processedLinksCount = 0;
          if (updateResult.applied &&
              entryLinks != null &&
              entryLinks.isNotEmpty) {
            final affectedIds = <String>{};
            for (final link in entryLinks) {
              try {
                final linkRows = await journalDb.upsertEntryLink(link);
                if (linkRows > 0) {
                  processedLinksCount++;
                  _loggingService.captureEvent(
                    'apply entryLink.embedded from=${link.fromId} to=${link.toId} rows=$linkRows',
                    domain: 'MATRIX_SERVICE',
                    subDomain: 'apply.entryLink.embedded',
                  );
                }
                affectedIds.addAll({link.fromId, link.toId});
              } catch (e, st) {
                _loggingService.captureException(
                  e,
                  domain: 'MATRIX_SERVICE',
                  subDomain: 'apply.entryLink.embedded',
                  stackTrace: st,
                );
              }
            }
            if (affectedIds.isNotEmpty) {
              _updateNotifications.notify(affectedIds, fromSync: true);
            }
          }

          final diag = SyncApplyDiagnostics(
            eventId: event.eventId,
            payloadType: 'journalEntity',
            entityId: journalEntity.meta.id,
            vectorClock: vcB?.toJson(),
            conflictStatus: predictedStatus.toString(),
            applied: updateResult.applied,
            skipReason: updateResult.skipReason,
          );
          _loggingService.captureEvent(
            'apply journalEntity eventId=${event.eventId} id=${journalEntity.meta.id} rowsWritten=$rows applied=${updateResult.applied} skip=${updateResult.skipReason?.label ?? 'none'} status=${diag.conflictStatus} embeddedLinks=$processedLinksCount/${entryLinks?.length ?? 0}',
            domain: 'MATRIX_SERVICE',
            subDomain: 'apply',
          );
          _updateNotifications.notify(
            journalEntity.affectedIds,
            fromSync: true,
          );
          return diag;
        } on FileSystemException catch (error, stackTrace) {
          _loggingService.captureException(
            error,
            domain: 'MATRIX_SERVICE',
            subDomain: 'SyncEventProcessor.missingAttachment',
            stackTrace: stackTrace,
          );
          // Returning null keeps the event in the retry queue until the file is available.
          return null;
        }
      case SyncEntryLink(entryLink: final entryLink):
        final rows = await journalDb.upsertEntryLink(entryLink);
        try {
          if (rows > 0) {
            _loggingService.captureEvent(
              'apply entryLink from=${entryLink.fromId} to=${entryLink.toId} rows=$rows',
              domain: 'MATRIX_SERVICE',
              subDomain: 'apply.entryLink',
            );
          }
        } catch (_) {
          // best-effort logging only
        }
        // Surface DB-apply diagnostics to the pipeline when available.
        if (applyObserver != null) {
          try {
            final diag = SyncApplyDiagnostics(
              eventId: event.eventId,
              payloadType: 'entryLink',
              entityId: '${entryLink.fromId}->${entryLink.toId}',
              vectorClock: null,
              conflictStatus: rows == 0 ? 'entryLink.noop' : 'applied',
              applied: rows > 0,
              skipReason:
                  rows > 0 ? null : JournalUpdateSkipReason.olderOrEqual,
            );
            applyObserver!.call(diag);
          } catch (_) {
            // best-effort only
          }
        }
        _updateNotifications.notify(
          {entryLink.fromId, entryLink.toId},
          fromSync: true,
        );
        return null;
      case SyncEntityDefinition(entityDefinition: final entityDefinition):
        await journalDb.upsertEntityDefinition(entityDefinition);
        return null;
      case SyncTagEntity(tagEntity: final tagEntity):
        await journalDb.upsertTagEntity(tagEntity);
        return null;
      case SyncAiConfig(aiConfig: final aiConfig):
        await _aiConfigRepository.saveConfig(
          aiConfig,
          fromSync: true,
        );
        return null;
      case SyncAiConfigDelete(id: final id):
        await _aiConfigRepository.deleteConfig(
          id,
          fromSync: true,
        );
        return null;
      case SyncThemingSelection(
          lightThemeName: final lightThemeName,
          darkThemeName: final darkThemeName,
          themeMode: final themeMode,
          updatedAt: final updatedAt,
        ):
        try {
          // Check if incoming update is newer than local
          final localUpdatedAtStr =
              await _settingsDb.itemByKey(themePrefsUpdatedAtKey);
          final localUpdatedAt =
              localUpdatedAtStr != null ? int.tryParse(localUpdatedAtStr) : 0;

          if (updatedAt < (localUpdatedAt ?? 0)) {
            _loggingService.captureEvent(
              'themingSync.ignored.stale incoming=$updatedAt local=$localUpdatedAt',
              domain: 'THEMING_SYNC',
              subDomain: 'apply',
            );
            return null;
          }

          // Normalize themeMode value
          final normalizedMode = EnumToString.fromString(
                ThemeMode.values,
                themeMode,
              ) ??
              ThemeMode.system;

          // Apply all three settings
          await _settingsDb.saveSettingsItem(
            lightSchemeNameKey,
            lightThemeName,
          );
          await _settingsDb.saveSettingsItem(
            darkSchemeNameKey,
            darkThemeName,
          );
          await _settingsDb.saveSettingsItem(
            themeModeKey,
            EnumToString.convertToString(normalizedMode),
          );
          await _settingsDb.saveSettingsItem(
            themePrefsUpdatedAtKey,
            updatedAt.toString(),
          );

          _loggingService.captureEvent(
            'apply themingSelection light=$lightThemeName dark=$darkThemeName mode=$themeMode',
            domain: 'THEMING_SYNC',
            subDomain: 'apply',
          );
        } catch (e, st) {
          _loggingService.captureException(
            e,
            domain: 'THEMING_SYNC',
            subDomain: 'apply',
            stackTrace: st,
          );
        }
        return null;
    }
  }
}

class SyncApplyDiagnostics {
  SyncApplyDiagnostics({
    required this.eventId,
    required this.payloadType,
    required this.entityId,
    required this.vectorClock,
    required this.conflictStatus,
    required this.applied,
    this.skipReason,
  });

  final String eventId;
  final String payloadType;
  final String entityId;
  final Object? vectorClock;
  final String conflictStatus;
  final bool applied;
  final JournalUpdateSkipReason? skipReason;
}
