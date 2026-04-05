import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/model/seeded_directives.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:uuid/uuid.dart';

/// Service for managing soul documents — reusable personality blueprints that
/// can be assigned to agent templates.
///
/// Follows the same entity → version → head pattern as
/// [AgentTemplateService].
class SoulDocumentService {
  SoulDocumentService({
    required this.repository,
    required this.syncService,
  });

  final AgentRepository repository;
  final AgentSyncService syncService;

  static const _uuid = Uuid();
  static const _logTag = 'SoulDocumentService';

  /// Create a new soul document with its initial version and head pointer.
  ///
  /// Returns the created [SoulDocumentEntity].
  Future<SoulDocumentEntity> createSoul({
    required String displayName,
    required String voiceDirective,
    required String authoredBy,
    String toneBounds = '',
    String coachingStyle = '',
    String antiSycophancyPolicy = '',
    String? soulId,
  }) async {
    final id = soulId ?? _uuid.v4();
    final versionId = _uuid.v4();
    final headId = _uuid.v4();
    final now = clock.now();

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

    await syncService.runInTransaction(() async {
      await syncService.upsertEntity(soul);
      await syncService.upsertEntity(version);
      await syncService.upsertEntity(head);
    });

    developer.log(
      'Created soul $id (name: $displayName)',
      name: _logTag,
    );

    return soul;
  }

  /// Create a new version of a soul document's personality directives.
  ///
  /// Archives all existing versions, creates the new active version, and
  /// updates the head pointer (reusing the existing head ID).
  Future<SoulDocumentVersionEntity> createVersion({
    required String soulId,
    required String voiceDirective,
    required String authoredBy,
    String toneBounds = '',
    String coachingStyle = '',
    String antiSycophancyPolicy = '',
    String? sourceSessionId,
  }) async {
    final now = clock.now();
    final newVersionId = _uuid.v4();

    return syncService.runInTransaction(() async {
      final soul = await getSoul(soulId);
      if (soul == null) {
        throw StateError('Soul document $soulId not found');
      }

      // Archive ALL non-archived versions.
      final currentHead = await repository.getSoulDocumentHead(soulId);
      final allVersions = await getVersionHistory(soulId, limit: -1);
      for (final version in allVersions) {
        if (version.status != SoulDocumentVersionStatus.archived) {
          final archived = version.copyWith(
            status: SoulDocumentVersionStatus.archived,
          );
          await syncService.upsertEntity(archived);
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

      // Update head pointer (reuse existing head ID if present).
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
        'Created version $nextVersion for soul $soulId',
        name: _logTag,
      );

      return newVersion;
    });
  }

  /// Fetch a soul document by its ID.
  Future<SoulDocumentEntity?> getSoul(String soulId) async {
    return repository.getSoulDocument(soulId);
  }

  /// List all non-deleted soul documents.
  Future<List<SoulDocumentEntity>> getAllSouls() async {
    return repository.getAllSoulDocuments();
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

      // Validate target version exists and belongs to this soul.
      final versionEntity = await repository.getEntity(versionId);
      final validVersion = versionEntity?.mapOrNull(
        soulDocumentVersion: (v) => v.agentId == soulId ? v : null,
      );
      if (validVersion == null) {
        throw StateError(
          'No version $versionId found for soul $soulId',
        );
      }

      // Archive all versions.
      final allVersions = await getVersionHistory(soulId, limit: -1);
      for (final version in allVersions) {
        if (version.status != SoulDocumentVersionStatus.archived) {
          await syncService.upsertEntity(
            version.copyWith(status: SoulDocumentVersionStatus.archived),
          );
        }
      }

      // Reactivate target version.
      await syncService.upsertEntity(
        validVersion.copyWith(status: SoulDocumentVersionStatus.active),
      );

      // Update head pointer.
      final updatedHead = head.copyWith(
        versionId: versionId,
        updatedAt: now,
      );
      await syncService.upsertEntity(updatedHead);
    });

    developer.log(
      'Rolled back soul $soulId to version $versionId',
      name: _logTag,
    );
  }

  /// Assign a soul document to a template.
  ///
  /// If the template already has a soul assignment, the existing link is
  /// soft-deleted and replaced.
  Future<void> assignSoulToTemplate(
    String templateId,
    String soulId,
  ) async {
    final now = clock.now();

    await syncService.runInTransaction(() async {
      // Soft-delete any existing soul assignment for this template.
      final existingLinks = await repository.getLinksFrom(
        templateId,
        type: AgentLinkTypes.soulAssignment,
      );
      for (final link in existingLinks) {
        final deleted = link.map(
          basic: (l) => l.copyWith(deletedAt: now, updatedAt: now),
          agentState: (l) => l.copyWith(deletedAt: now, updatedAt: now),
          messagePrev: (l) => l.copyWith(deletedAt: now, updatedAt: now),
          messagePayload: (l) => l.copyWith(deletedAt: now, updatedAt: now),
          toolEffect: (l) => l.copyWith(deletedAt: now, updatedAt: now),
          agentTask: (l) => l.copyWith(deletedAt: now, updatedAt: now),
          templateAssignment: (l) => l.copyWith(deletedAt: now, updatedAt: now),
          improverTarget: (l) => l.copyWith(deletedAt: now, updatedAt: now),
          agentProject: (l) => l.copyWith(deletedAt: now, updatedAt: now),
          soulAssignment: (l) => l.copyWith(deletedAt: now, updatedAt: now),
        );
        await syncService.upsertLink(deleted);
      }

      // Create new assignment link.
      final link = AgentLink.soulAssignment(
        id: _uuid.v4(),
        fromId: templateId,
        toId: soulId,
        createdAt: now,
        updatedAt: now,
        vectorClock: null,
      );
      await syncService.upsertLink(link);
    });

    developer.log(
      'Assigned soul $soulId to template $templateId',
      name: _logTag,
    );
  }

  /// Remove the soul assignment from a template.
  Future<void> unassignSoul(String templateId) async {
    final now = clock.now();

    final links = await repository.getLinksFrom(
      templateId,
      type: AgentLinkTypes.soulAssignment,
    );
    for (final link in links) {
      final deleted = link.map(
        basic: (l) => l.copyWith(deletedAt: now, updatedAt: now),
        agentState: (l) => l.copyWith(deletedAt: now, updatedAt: now),
        messagePrev: (l) => l.copyWith(deletedAt: now, updatedAt: now),
        messagePayload: (l) => l.copyWith(deletedAt: now, updatedAt: now),
        toolEffect: (l) => l.copyWith(deletedAt: now, updatedAt: now),
        agentTask: (l) => l.copyWith(deletedAt: now, updatedAt: now),
        templateAssignment: (l) => l.copyWith(deletedAt: now, updatedAt: now),
        improverTarget: (l) => l.copyWith(deletedAt: now, updatedAt: now),
        agentProject: (l) => l.copyWith(deletedAt: now, updatedAt: now),
        soulAssignment: (l) => l.copyWith(deletedAt: now, updatedAt: now),
      );
      await syncService.upsertLink(deleted);
    }

    developer.log(
      'Unassigned soul from template $templateId',
      name: _logTag,
    );
  }

  /// Resolve the active soul version for a template by following the
  /// assignment link → soul → head → version chain.
  ///
  /// Returns `null` if no soul is assigned or the chain is broken.
  Future<SoulDocumentVersionEntity?> resolveActiveSoulForTemplate(
    String templateId,
  ) async {
    final links = await repository.getLinksFrom(
      templateId,
      type: AgentLinkTypes.soulAssignment,
    );
    if (links.isEmpty) return null;

    final soulId = links.first.toId;
    return getActiveSoulVersion(soulId);
  }

  /// Reverse lookup: find all templates that use a given soul document.
  ///
  /// Returns the template IDs (not full entities) for efficiency.
  Future<List<String>> getTemplatesUsingSoul(String soulId) async {
    final links = await repository.getLinksTo(
      soulId,
      type: AgentLinkTypes.soulAssignment,
    );
    return links.map((l) => l.fromId).toList();
  }

  // ── seeding ───────────────────────────────────────────────────────────────

  /// Seed the default soul documents and assign them to seeded templates.
  ///
  /// Idempotent — checks existence before creating. Safe to call on every
  /// app startup.
  Future<void> seedDefaults() async {
    final souls = await Future.wait([
      getSoul(lauraSoulId),
      getSoul(tomSoulId),
      getSoul(maxSoulId),
      getSoul(irisSoulId),
      getSoul(sageSoulId),
      getSoul(kitSoulId),
    ]);

    final [laura, tom, max, iris, sage, kit] = souls;

    if (laura != null &&
        tom != null &&
        max != null &&
        iris != null &&
        sage != null &&
        kit != null) {
      developer.log('Default souls already seeded, skipping', name: _logTag);
      return;
    }

    if (laura == null) {
      await createSoul(
        soulId: lauraSoulId,
        displayName: 'Laura',
        voiceDirective: lauraSoulVoiceDirective,
        toneBounds: lauraSoulToneBounds,
        coachingStyle: lauraSoulCoachingStyle,
        antiSycophancyPolicy: lauraSoulAntiSycophancyPolicy,
        authoredBy: 'system',
      );
    }

    if (tom == null) {
      await createSoul(
        soulId: tomSoulId,
        displayName: 'Tom',
        voiceDirective: tomSoulVoiceDirective,
        toneBounds: tomSoulToneBounds,
        coachingStyle: tomSoulCoachingStyle,
        antiSycophancyPolicy: tomSoulAntiSycophancyPolicy,
        authoredBy: 'system',
      );
    }

    if (max == null) {
      await createSoul(
        soulId: maxSoulId,
        displayName: 'Max',
        voiceDirective: maxSoulVoiceDirective,
        toneBounds: maxSoulToneBounds,
        coachingStyle: maxSoulCoachingStyle,
        antiSycophancyPolicy: maxSoulAntiSycophancyPolicy,
        authoredBy: 'system',
      );
    }

    if (iris == null) {
      await createSoul(
        soulId: irisSoulId,
        displayName: 'Iris',
        voiceDirective: irisSoulVoiceDirective,
        toneBounds: irisSoulToneBounds,
        coachingStyle: irisSoulCoachingStyle,
        antiSycophancyPolicy: irisSoulAntiSycophancyPolicy,
        authoredBy: 'system',
      );
    }

    if (sage == null) {
      await createSoul(
        soulId: sageSoulId,
        displayName: 'Sage',
        voiceDirective: sageSoulVoiceDirective,
        toneBounds: sageSoulToneBounds,
        coachingStyle: sageSoulCoachingStyle,
        antiSycophancyPolicy: sageSoulAntiSycophancyPolicy,
        authoredBy: 'system',
      );
    }

    if (kit == null) {
      await createSoul(
        soulId: kitSoulId,
        displayName: 'Kit',
        voiceDirective: kitSoulVoiceDirective,
        toneBounds: kitSoulToneBounds,
        coachingStyle: kitSoulCoachingStyle,
        antiSycophancyPolicy: kitSoulAntiSycophancyPolicy,
        authoredBy: 'system',
      );
    }

    // Assign default souls to seeded templates (idempotent — replaces if
    // already assigned).
    await assignSoulToTemplate(lauraTemplateId, lauraSoulId);
    await assignSoulToTemplate(tomTemplateId, tomSoulId);
    await assignSoulToTemplate(projectTemplateId, lauraSoulId);

    developer.log('Seeded default souls and assignments', name: _logTag);
  }
}
