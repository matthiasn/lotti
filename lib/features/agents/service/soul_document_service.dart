import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/service/soul_template_ops.dart';
import 'package:lotti/features/agents/service/soul_version_ops.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';

/// Service for managing soul documents — reusable personality blueprints that
/// can be assigned to agent templates.
///
/// Follows the same entity → version → head pattern as the agent template
/// service. The service is a thin facade over two collaborators:
/// [SoulVersionOps] (soul-document head + version lifecycle) and
/// [SoulTemplateOps] (soul ↔ template assignments, soul deletion, and default
/// seeding). Template ops depends on version ops for active-version reads.
class SoulDocumentService {
  SoulDocumentService({
    required this.repository,
    required this.syncService,
  });

  final AgentRepository repository;
  final AgentSyncService syncService;

  late final SoulVersionOps _versionOps = SoulVersionOps(
    repository: repository,
    syncService: syncService,
  );

  late final SoulTemplateOps _templateOps = SoulTemplateOps(
    repository: repository,
    syncService: syncService,
    versionOps: _versionOps,
  );

  // ── Soul document + version lifecycle ─────────────────────────────────────

  /// Create a new soul document with its initial version and head pointer.
  Future<SoulDocumentEntity> createSoul({
    required String displayName,
    required String voiceDirective,
    required String authoredBy,
    String toneBounds = '',
    String coachingStyle = '',
    String antiSycophancyPolicy = '',
    String? soulId,
  }) => _versionOps.createSoul(
    displayName: displayName,
    voiceDirective: voiceDirective,
    authoredBy: authoredBy,
    toneBounds: toneBounds,
    coachingStyle: coachingStyle,
    antiSycophancyPolicy: antiSycophancyPolicy,
    soulId: soulId,
  );

  /// Fetch a soul document by its ID.
  Future<SoulDocumentEntity?> getSoul(String soulId) =>
      _versionOps.getSoul(soulId);

  /// Update mutable fields on a soul document (currently just display name).
  Future<SoulDocumentEntity> updateSoul({
    required String soulId,
    String? displayName,
  }) => _versionOps.updateSoul(soulId: soulId, displayName: displayName);

  /// List all non-deleted soul documents.
  Future<List<SoulDocumentEntity>> getAllSouls() => _versionOps.getAllSouls();

  /// Create a new version of a soul document's personality directives.
  Future<SoulDocumentVersionEntity> createVersion({
    required String soulId,
    required String voiceDirective,
    required String authoredBy,
    String toneBounds = '',
    String coachingStyle = '',
    String antiSycophancyPolicy = '',
    String? sourceSessionId,
  }) => _versionOps.createVersion(
    soulId: soulId,
    voiceDirective: voiceDirective,
    authoredBy: authoredBy,
    toneBounds: toneBounds,
    coachingStyle: coachingStyle,
    antiSycophancyPolicy: antiSycophancyPolicy,
    sourceSessionId: sourceSessionId,
  );

  /// Atomically update the soul display name and create a new version.
  Future<SoulDocumentVersionEntity> updateSoulAndCreateVersion({
    required String soulId,
    required String displayName,
    required String voiceDirective,
    required String authoredBy,
    String toneBounds = '',
    String coachingStyle = '',
    String antiSycophancyPolicy = '',
  }) => _versionOps.updateSoulAndCreateVersion(
    soulId: soulId,
    displayName: displayName,
    voiceDirective: voiceDirective,
    authoredBy: authoredBy,
    toneBounds: toneBounds,
    coachingStyle: coachingStyle,
    antiSycophancyPolicy: antiSycophancyPolicy,
  );

  /// Fetch the active version for a soul document.
  Future<SoulDocumentVersionEntity?> getActiveSoulVersion(String soulId) =>
      _versionOps.getActiveSoulVersion(soulId);

  /// Fetch version history for a soul document, newest first.
  Future<List<SoulDocumentVersionEntity>> getVersionHistory(
    String soulId, {
    int limit = 5,
  }) => _versionOps.getVersionHistory(soulId, limit: limit);

  /// Roll back a soul document to a previous version.
  Future<void> rollbackToVersion({
    required String soulId,
    required String versionId,
  }) => _versionOps.rollbackToVersion(soulId: soulId, versionId: versionId);

  // ── Soul ↔ template assignments, deletion, seeding ────────────────────────

  /// Assign a soul document to a template.
  Future<void> assignSoulToTemplate(String templateId, String soulId) =>
      _templateOps.assignSoulToTemplate(templateId, soulId);

  /// Remove the soul assignment from a template.
  Future<void> unassignSoul(String templateId) =>
      _templateOps.unassignSoul(templateId);

  /// Resolve the active soul version for a template.
  Future<SoulDocumentVersionEntity?> resolveActiveSoulForTemplate(
    String templateId,
  ) => _templateOps.resolveActiveSoulForTemplate(templateId);

  /// Resolve active soul versions for multiple templates in bulk.
  Future<Map<String, SoulDocumentVersionEntity>> resolveActiveSoulsForTemplates(
    Iterable<String> templateIds,
  ) => _templateOps.resolveActiveSoulsForTemplates(templateIds);

  /// Reverse lookup: find all templates that use a given soul document.
  Future<List<String>> getTemplatesUsingSoul(String soulId) =>
      _templateOps.getTemplatesUsingSoul(soulId);

  /// Soft-delete a soul document and all its versions, head, and links.
  Future<void> deleteSoul(String soulId) => _templateOps.deleteSoul(soulId);

  /// Seed the default soul documents and assign them to seeded templates.
  Future<void> seedDefaults() => _templateOps.seedDefaults();
}
