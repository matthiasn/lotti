import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/service/soul_template_ops.dart'
    show SoulTemplateOps;
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();
const _logTag = 'SoulDocumentService';

void _requireNonBlank(String fieldName, String value) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, fieldName, 'must not be blank');
  }
}

/// Soul-document head and version lifecycle.
///
/// Owns the soul document entity (create/update/read/delete), its version
/// chain (create version, update-and-version, rollback, history), and the
/// active-version/head reads. [SoulTemplateOps] depends on this class for
/// [getActiveSoulVersion] when resolving template assignments.
class SoulVersionOps {
  SoulVersionOps({
    required this.repository,
    required this.syncService,
  });

  final AgentRepository repository;
  final AgentSyncService syncService;

  /// Create a new soul document with its initial version and head pointer.
  ///
  /// Throws [StateError] if a soul with the given [soulId] already exists.
  /// Throws [ArgumentError] if required text fields are blank.
  Future<SoulDocumentEntity> createSoul({
    required String displayName,
    required String voiceDirective,
    required String authoredBy,
    String toneBounds = '',
    String coachingStyle = '',
    String antiSycophancyPolicy = '',
    String? soulId,
  }) async {
    _requireNonBlank('displayName', displayName);
    _requireNonBlank('voiceDirective', voiceDirective);
    _requireNonBlank('authoredBy', authoredBy);

    final id = soulId ?? _uuid.v4();
    final versionId = _uuid.v4();
    final headId = _uuid.v4();
    final now = clock.now();

    return syncService.runInTransaction(() async {
      final existing = await getSoul(id);
      if (existing != null) {
        throw StateError('Soul document $id already exists');
      }

      final soul =
          AgentDomainEntity.soulDocument(
                id: id,
                agentId: id,
                displayName: displayName,
                createdAt: now,
                updatedAt: now,
                vectorClock: null,
              )
              as SoulDocumentEntity;

      final version = AgentDomainEntity.soulDocumentVersion(
        id: versionId,
        agentId: id,
        version: 1,
        status: SoulDocumentVersionStatus.active,
        authoredBy: authoredBy,
        createdAt: now,
        vectorClock: null,
        voiceDirective: voiceDirective,
        toneBounds: toneBounds,
        coachingStyle: coachingStyle,
        antiSycophancyPolicy: antiSycophancyPolicy,
      );

      final head = AgentDomainEntity.soulDocumentHead(
        id: headId,
        agentId: id,
        versionId: versionId,
        updatedAt: now,
        vectorClock: null,
      );

      await syncService.upsertEntity(soul);
      await syncService.upsertEntity(version);
      await syncService.upsertEntity(head);

      developer.log(
        'Created soul ${DomainLogger.sanitizeId(id)}',
        name: _logTag,
      );

      return soul;
    });
  }

  /// Fetch a soul document by its ID.
  Future<SoulDocumentEntity?> getSoul(String soulId) async {
    return repository.getSoulDocument(soulId);
  }

  /// Update mutable fields on a soul document (currently just display name).
  ///
  /// Rejects blank display names and skips the write when nothing changed.
  Future<SoulDocumentEntity> updateSoul({
    required String soulId,
    String? displayName,
  }) async {
    final trimmed = displayName?.trim();
    if (trimmed != null && trimmed.isEmpty) {
      throw ArgumentError('displayName must not be blank');
    }

    final now = clock.now();

    return syncService.runInTransaction(() async {
      final soul = await getSoul(soulId);
      if (soul == null) {
        throw StateError('Soul document $soulId not found');
      }

      final newName = trimmed ?? soul.displayName;
      if (newName == soul.displayName) return soul;

      final updated = soul.copyWith(
        displayName: newName,
        updatedAt: now,
      );
      await syncService.upsertEntity(updated);
      return updated;
    });
  }

  /// List all non-deleted soul documents.
  Future<List<SoulDocumentEntity>> getAllSouls() async {
    return repository.getAllSoulDocuments();
  }

  /// Create a new version of a soul document's personality directives.
  ///
  /// Archives **all** non-archived versions (not just the head-pointed one) to
  /// ensure consistency after sync races or partial corruption, then creates
  /// the new active version and updates the head pointer.
  ///
  /// Throws [ArgumentError] if required text fields are blank.
  Future<SoulDocumentVersionEntity> createVersion({
    required String soulId,
    required String voiceDirective,
    required String authoredBy,
    String toneBounds = '',
    String coachingStyle = '',
    String antiSycophancyPolicy = '',
    String? sourceSessionId,
  }) async {
    _requireNonBlank('voiceDirective', voiceDirective);
    _requireNonBlank('authoredBy', authoredBy);

    final now = clock.now();
    final newVersionId = _uuid.v4();

    return syncService.runInTransaction(() async {
      final soul = await getSoul(soulId);
      if (soul == null) {
        throw StateError('Soul document $soulId not found');
      }

      final currentHead = await repository.getSoulDocumentHead(soulId);

      // Archive ALL non-archived versions to ensure no stale active statuses
      // survive sync races or partial corruption. Mirrors the template
      // service's approach in AgentTemplateService.createVersion().
      final allVersions = await getVersionHistory(soulId, limit: -1);
      for (final version in allVersions) {
        if (version.status != SoulDocumentVersionStatus.archived) {
          await syncService.upsertEntity(
            version.copyWith(status: SoulDocumentVersionStatus.archived),
          );
        }
      }

      final nextVersion = await repository.getNextSoulDocumentVersionNumber(
        soulId,
      );

      final newVersion =
          AgentDomainEntity.soulDocumentVersion(
                id: newVersionId,
                agentId: soulId,
                version: nextVersion,
                status: SoulDocumentVersionStatus.active,
                authoredBy: authoredBy,
                createdAt: now,
                vectorClock: null,
                voiceDirective: voiceDirective,
                toneBounds: toneBounds,
                coachingStyle: coachingStyle,
                antiSycophancyPolicy: antiSycophancyPolicy,
                sourceSessionId: sourceSessionId,
                diffFromVersionId: currentHead?.versionId,
              )
              as SoulDocumentVersionEntity;
      await syncService.upsertEntity(newVersion);

      final headId = currentHead?.id ?? _uuid.v4();
      final updatedHead = AgentDomainEntity.soulDocumentHead(
        id: headId,
        agentId: soulId,
        versionId: newVersionId,
        updatedAt: now,
        vectorClock: null,
      );
      await syncService.upsertEntity(updatedHead);

      developer.log(
        'Created version $nextVersion for soul '
        '${DomainLogger.sanitizeId(soulId)}',
        name: _logTag,
      );

      return newVersion;
    });
  }

  /// Atomically update the soul display name and create a new version.
  ///
  /// Both writes happen in one transaction so neither is committed alone.
  Future<SoulDocumentVersionEntity> updateSoulAndCreateVersion({
    required String soulId,
    required String displayName,
    required String voiceDirective,
    required String authoredBy,
    String toneBounds = '',
    String coachingStyle = '',
    String antiSycophancyPolicy = '',
  }) async {
    final trimmedName = displayName.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('displayName must not be blank');
    }
    _requireNonBlank('voiceDirective', voiceDirective);
    _requireNonBlank('authoredBy', authoredBy);

    final now = clock.now();
    final newVersionId = _uuid.v4();

    return syncService.runInTransaction(() async {
      final soul = await getSoul(soulId);
      if (soul == null) {
        throw StateError('Soul document $soulId not found');
      }

      // Update display name if changed.
      if (trimmedName != soul.displayName) {
        final updated = soul.copyWith(
          displayName: trimmedName,
          updatedAt: now,
        );
        await syncService.upsertEntity(updated);
      }

      // Archive all non-archived versions.
      final currentHead = await repository.getSoulDocumentHead(soulId);
      final allVersions = await getVersionHistory(soulId, limit: -1);
      for (final version in allVersions) {
        if (version.status != SoulDocumentVersionStatus.archived) {
          await syncService.upsertEntity(
            version.copyWith(status: SoulDocumentVersionStatus.archived),
          );
        }
      }

      final nextVersion = await repository.getNextSoulDocumentVersionNumber(
        soulId,
      );

      final newVersion =
          AgentDomainEntity.soulDocumentVersion(
                id: newVersionId,
                agentId: soulId,
                version: nextVersion,
                status: SoulDocumentVersionStatus.active,
                authoredBy: authoredBy,
                createdAt: now,
                vectorClock: null,
                voiceDirective: voiceDirective,
                toneBounds: toneBounds,
                coachingStyle: coachingStyle,
                antiSycophancyPolicy: antiSycophancyPolicy,
                diffFromVersionId: currentHead?.versionId,
              )
              as SoulDocumentVersionEntity;
      await syncService.upsertEntity(newVersion);

      final headId = currentHead?.id ?? _uuid.v4();
      final updatedHead = AgentDomainEntity.soulDocumentHead(
        id: headId,
        agentId: soulId,
        versionId: newVersionId,
        updatedAt: now,
        vectorClock: null,
      );
      await syncService.upsertEntity(updatedHead);

      developer.log(
        'Updated soul ${DomainLogger.sanitizeId(soulId)} and created '
        'version $nextVersion',
        name: _logTag,
      );

      return newVersion;
    });
  }

  /// Fetch the active version for a soul document.
  Future<SoulDocumentVersionEntity?> getActiveSoulVersion(
    String soulId,
  ) async {
    return repository.getActiveSoulDocumentVersion(soulId);
  }

  /// Fetch version history for a soul document, newest first.
  Future<List<SoulDocumentVersionEntity>> getVersionHistory(
    String soulId, {
    int limit = 5,
  }) async {
    return repository.getSoulDocumentVersions(soulId, limit: limit);
  }

  /// Roll back a soul document to a previous version.
  ///
  /// Archives all versions, reactivates the target, and moves the head
  /// pointer. Does not delete any versions.
  Future<void> rollbackToVersion({
    required String soulId,
    required String versionId,
  }) async {
    final now = clock.now();

    await syncService.runInTransaction(() async {
      final head = await repository.getSoulDocumentHead(soulId);
      if (head == null) {
        throw StateError('No head found for soul $soulId');
      }

      final versionEntity = await repository.getEntity(versionId);
      final validVersion = versionEntity?.mapOrNull(
        soulDocumentVersion: (v) => v.agentId == soulId ? v : null,
      );
      if (validVersion == null) {
        throw StateError(
          'No version $versionId found for soul $soulId',
        );
      }

      final allVersions = await getVersionHistory(soulId, limit: -1);
      for (final version in allVersions) {
        if (version.status != SoulDocumentVersionStatus.archived) {
          await syncService.upsertEntity(
            version.copyWith(status: SoulDocumentVersionStatus.archived),
          );
        }
      }

      await syncService.upsertEntity(
        validVersion.copyWith(status: SoulDocumentVersionStatus.active),
      );

      final updatedHead = head.copyWith(
        versionId: versionId,
        updatedAt: now,
      );
      await syncService.upsertEntity(updatedHead);
    });

    developer.log(
      'Rolled back soul ${DomainLogger.sanitizeId(soulId)} to version '
      '${DomainLogger.sanitizeId(versionId)}',
      name: _logTag,
    );
  }
}
