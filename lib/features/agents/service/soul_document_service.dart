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

  static void _requireNonBlank(String fieldName, String value) {
    if (value.trim().isEmpty) {
      throw ArgumentError.value(value, fieldName, 'must not be blank');
    }
  }

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
        'Created soul $id (name: $displayName)',
        name: _logTag,
      );

      return soul;
    });
  }

  /// Create a new version of a soul document's personality directives.
  ///
  /// Archives the current active version, creates the new active version, and
  /// updates the head pointer (reusing the existing head ID).
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

      // Archive the current active version by resolving directly from head,
      // avoiding a redundant head read via getActiveSoulVersion.
      if (currentHead != null) {
        final currentVersion = await repository.getEntity(
          currentHead.versionId,
        );
        final activeVersion = currentVersion?.mapOrNull(
          soulDocumentVersion: (v) => v,
        );
        if (activeVersion != null &&
            activeVersion.status != SoulDocumentVersionStatus.archived) {
          await syncService.upsertEntity(
            activeVersion.copyWith(status: SoulDocumentVersionStatus.archived),
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
      'Rolled back soul $soulId to version $versionId',
      name: _logTag,
    );
  }

  /// Assign a soul document to a template.
  ///
  /// No-op if the template is already assigned to [soulId]. Otherwise,
  /// soft-deletes any existing assignment and creates a new link.
  Future<void> assignSoulToTemplate(
    String templateId,
    String soulId,
  ) async {
    final now = clock.now();

    await syncService.runInTransaction(() async {
      final existingLinks = await repository.getLinksFrom(
        templateId,
        type: AgentLinkTypes.soulAssignment,
      );

      if (existingLinks.any((l) => l.toId == soulId)) {
        return;
      }

      for (final link in existingLinks) {
        await syncService.upsertLink(link.softDeleted(now));
      }

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

    await syncService.runInTransaction(() async {
      final links = await repository.getLinksFrom(
        templateId,
        type: AgentLinkTypes.soulAssignment,
      );
      for (final link in links) {
        await syncService.upsertLink(link.softDeleted(now));
      }
    });

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

  /// Seeded soul configurations, keyed by ID.
  static const List<({String antiSycophancy, String coaching, String id, String name, String tone, String voice})> _seedConfigs = [
    (
      id: lauraSoulId,
      name: 'Laura',
      voice: lauraSoulVoiceDirective,
      tone: lauraSoulToneBounds,
      coaching: lauraSoulCoachingStyle,
      antiSycophancy: lauraSoulAntiSycophancyPolicy,
    ),
    (
      id: tomSoulId,
      name: 'Tom',
      voice: tomSoulVoiceDirective,
      tone: tomSoulToneBounds,
      coaching: tomSoulCoachingStyle,
      antiSycophancy: tomSoulAntiSycophancyPolicy,
    ),
    (
      id: maxSoulId,
      name: 'Max',
      voice: maxSoulVoiceDirective,
      tone: maxSoulToneBounds,
      coaching: maxSoulCoachingStyle,
      antiSycophancy: maxSoulAntiSycophancyPolicy,
    ),
    (
      id: irisSoulId,
      name: 'Iris',
      voice: irisSoulVoiceDirective,
      tone: irisSoulToneBounds,
      coaching: irisSoulCoachingStyle,
      antiSycophancy: irisSoulAntiSycophancyPolicy,
    ),
    (
      id: sageSoulId,
      name: 'Sage',
      voice: sageSoulVoiceDirective,
      tone: sageSoulToneBounds,
      coaching: sageSoulCoachingStyle,
      antiSycophancy: sageSoulAntiSycophancyPolicy,
    ),
    (
      id: kitSoulId,
      name: 'Kit',
      voice: kitSoulVoiceDirective,
      tone: kitSoulToneBounds,
      coaching: kitSoulCoachingStyle,
      antiSycophancy: kitSoulAntiSycophancyPolicy,
    ),
  ];

  /// Default soul-to-template assignments.
  static const List<({String soulId, String templateId})> _seedAssignments = [
    (templateId: lauraTemplateId, soulId: lauraSoulId),
    (templateId: tomTemplateId, soulId: tomSoulId),
    (templateId: projectTemplateId, soulId: lauraSoulId),
  ];

  /// Seed the default soul documents and assign them to seeded templates.
  ///
  /// Idempotent — checks existence before creating. Safe to call on every
  /// app startup.
  Future<void> seedDefaults() async {
    final existing = await Future.wait(
      _seedConfigs.map((c) => getSoul(c.id)),
    );

    // Seed missing soul documents.
    for (var i = 0; i < _seedConfigs.length; i++) {
      if (existing[i] == null) {
        final c = _seedConfigs[i];
        await createSoul(
          soulId: c.id,
          displayName: c.name,
          voiceDirective: c.voice,
          toneBounds: c.tone,
          coachingStyle: c.coaching,
          antiSycophancyPolicy: c.antiSycophancy,
          authoredBy: AgentAuthors.system,
        );
      }
    }

    // Always run assignments — assignSoulToTemplate is idempotent (no-op when
    // already assigned), so this repairs stale or missing links on existing
    // installs without creating churn.
    for (final a in _seedAssignments) {
      await assignSoulToTemplate(a.templateId, a.soulId);
    }

    developer.log('Seeded default souls and assignments', name: _logTag);
  }
}
