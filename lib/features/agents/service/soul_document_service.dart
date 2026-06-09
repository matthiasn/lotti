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
import 'package:lotti/services/domain_logging.dart';
import 'package:uuid/uuid.dart';

part 'soul_document_service_versions.dart';
part 'soul_document_service_templates.dart';

const _uuid = Uuid();
const _logTag = 'SoulDocumentService';

void _requireNonBlank(String fieldName, String value) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, fieldName, 'must not be blank');
  }
}

/// Holds the injected dependencies shared by [SoulDocumentService] and its
/// method-group mixins (see the sibling part files).
abstract class _SoulDocumentServiceBase {
  _SoulDocumentServiceBase({
    required this.repository,
    required this.syncService,
  });

  final AgentRepository repository;
  final AgentSyncService syncService;

  // Cross-group method contracts so the version/template mixins (in the sibling
  // part files) can call into implementations that live on the concrete service.
  Future<SoulDocumentEntity?> getSoul(String soulId);
  Future<SoulDocumentVersionEntity?> getActiveSoulVersion(String soulId);
}

/// Service for managing soul documents — reusable personality blueprints that
/// can be assigned to agent templates.
///
/// Follows the same entity → version → head pattern as
/// [AgentTemplateService].
class SoulDocumentService extends _SoulDocumentServiceBase
    with _SoulVersionOps, _SoulTemplateOps {
  SoulDocumentService({
    required super.repository,
    required super.syncService,
  });

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
  @override
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

  /// Soft-delete a soul document and all its versions, head, and links.
  ///
  /// Checks that no templates are currently using this soul. If any template
  /// still has an active assignment, throws [StateError].
  Future<void> deleteSoul(String soulId) async {
    final templateIds = await getTemplatesUsingSoul(soulId);
    if (templateIds.isNotEmpty) {
      throw StateError(
        'Cannot delete soul $soulId: '
        '${templateIds.length} template(s) still assigned',
      );
    }

    final now = clock.now();

    final deleted = await syncService.runInTransaction(() async {
      final soul = await getSoul(soulId);
      if (soul == null) return false;

      final versions = await getVersionHistory(soulId, limit: -1);
      for (final version in versions) {
        await syncService.upsertEntity(
          version.copyWith(deletedAt: now),
        );
      }

      final head = await repository.getSoulDocumentHead(soulId);
      if (head != null) {
        await syncService.upsertEntity(head.copyWith(deletedAt: now));
      }

      await syncService.upsertEntity(soul.copyWith(deletedAt: now));
      return true;
    });

    if (deleted) {
      developer.log(
        'Deleted soul ${DomainLogger.sanitizeId(soulId)}',
        name: _logTag,
      );
    }
  }

  // ── seeding ───────────────────────────────────────────────────────────────

  /// Seeded soul configurations, keyed by ID.
  static const List<
    ({
      String antiSycophancy,
      String coaching,
      String id,
      String name,
      String tone,
      String voice,
    })
  >
  _seedConfigs = [
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
