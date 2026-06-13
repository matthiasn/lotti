import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Core CRUD and versioning operations for agent templates.
///
/// Owns the template entity → version → head lifecycle: create, update,
/// version, rollback, soft-delete, and the various read/lookup helpers. The
/// metrics and seeding collaborators delegate into this class for the shared
/// reads (e.g. [getTemplate], [getVersionHistory], [getAgentsForTemplate]).
class AgentTemplateCrud {
  AgentTemplateCrud({
    required this.repository,
    required this.syncService,
  });

  final AgentRepository repository;
  final AgentSyncService syncService;

  /// Create a new template with its initial version and head pointer.
  ///
  /// Returns the created [AgentTemplateEntity].
  Future<AgentTemplateEntity> createTemplate({
    required String displayName,
    required AgentTemplateKind kind,
    required String modelId,
    required String directives,
    required String authoredBy,
    String generalDirective = '',
    String reportDirective = '',
    Set<String> categoryIds = const {},
    String? templateId,
    String? profileId,
  }) async {
    final tplId = templateId ?? _uuid.v4();
    final versionId = _uuid.v4();
    final headId = _uuid.v4();
    final now = clock.now();

    final template =
        AgentDomainEntity.agentTemplate(
              id: tplId,
              agentId: tplId,
              displayName: displayName,
              kind: kind,
              modelId: modelId,
              profileId: profileId,
              categoryIds: categoryIds,
              createdAt: now,
              updatedAt: now,
              vectorClock: null,
            )
            as AgentTemplateEntity;

    final version = AgentDomainEntity.agentTemplateVersion(
      id: versionId,
      agentId: tplId,
      version: 1,
      status: AgentTemplateVersionStatus.active,
      directives: directives,
      generalDirective: generalDirective,
      reportDirective: reportDirective,
      authoredBy: authoredBy,
      createdAt: now,
      vectorClock: null,
      modelId: modelId,
      profileId: profileId,
    );

    final head = AgentDomainEntity.agentTemplateHead(
      id: headId,
      agentId: tplId,
      versionId: versionId,
      updatedAt: now,
      vectorClock: null,
    );

    await syncService.runInTransaction(() async {
      await syncService.upsertEntity(template);
      await syncService.upsertEntity(version);
      await syncService.upsertEntity(head);
    });

    developer.log(
      'Created template ${DomainLogger.sanitizeId(tplId)}',
      name: 'AgentTemplateService',
    );

    return template;
  }

  /// Update template-level fields (display name, model ID).
  ///
  /// When [modelId] changes, a new template version is created so the model
  /// is historically tracked per-version.
  Future<AgentTemplateEntity> updateTemplate({
    required String templateId,
    String? displayName,
    String? modelId,
    String? profileId,
    bool clearProfileId = false,
  }) async {
    final now = clock.now();

    return syncService.runInTransaction(() async {
      final template = await getTemplate(templateId);
      if (template == null) {
        throw StateError('Template $templateId not found');
      }

      final modelChanged = modelId != null && modelId != template.modelId;
      final effectiveProfileId = clearProfileId
          ? null
          : (profileId ?? template.profileId);
      final profileChanged = effectiveProfileId != template.profileId;

      final updated = template.copyWith(
        displayName: displayName ?? template.displayName,
        modelId: modelId ?? template.modelId,
        profileId: effectiveProfileId,
        updatedAt: now,
      );
      await syncService.upsertEntity(updated);

      // When the model or profile changes, create a new version so the change
      // is recorded in the version history.
      if (modelChanged || profileChanged) {
        final activeVersion = await repository.getActiveTemplateVersion(
          templateId,
        );
        if (activeVersion != null) {
          await createVersion(
            templateId: templateId,
            directives: activeVersion.directives,
            generalDirective: activeVersion.generalDirective,
            reportDirective: activeVersion.reportDirective,
            authoredBy: 'system:config_change',
          );
        }
      }

      developer.log(
        'Updated template ${DomainLogger.sanitizeId(templateId)}',
        name: 'AgentTemplateService',
      );

      return updated;
    });
  }

  /// Create a new version of an existing template.
  ///
  /// Archives the current active version, creates the new version as active,
  /// and updates the head pointer.
  Future<AgentTemplateVersionEntity> createVersion({
    required String templateId,
    required String directives,
    required String authoredBy,
    String generalDirective = '',
    String reportDirective = '',
  }) async {
    final now = clock.now();
    final newVersionId = _uuid.v4();

    return syncService.runInTransaction(() async {
      // Validate that the template exists.
      final template = await getTemplate(templateId);
      if (template == null) {
        throw StateError('Template $templateId not found');
      }

      // Archive ALL non-head versions to ensure no stale active statuses.
      final currentHead = await repository.getTemplateHead(templateId);
      final allVersions = await getVersionHistory(templateId, limit: -1);
      for (final version in allVersions) {
        if (version.status != AgentTemplateVersionStatus.archived) {
          final archived = version.copyWith(
            status: AgentTemplateVersionStatus.archived,
          );
          await syncService.upsertEntity(archived);
        }
      }

      // Determine next version number.
      final nextVersion = await repository.getNextTemplateVersionNumber(
        templateId,
      );

      // Create the new version, recording the template's configured model ID
      // and profile ID.
      final newVersion =
          AgentDomainEntity.agentTemplateVersion(
                id: newVersionId,
                agentId: templateId,
                version: nextVersion,
                status: AgentTemplateVersionStatus.active,
                directives: directives,
                generalDirective: generalDirective,
                reportDirective: reportDirective,
                authoredBy: authoredBy,
                createdAt: now,
                vectorClock: null,
                modelId: template.modelId,
                profileId: template.profileId,
              )
              as AgentTemplateVersionEntity;
      await syncService.upsertEntity(newVersion);

      // Update head pointer (reuse existing head ID if present).
      final headId = currentHead?.id ?? _uuid.v4();
      final updatedHead = AgentDomainEntity.agentTemplateHead(
        id: headId,
        agentId: templateId,
        versionId: newVersionId,
        updatedAt: now,
        vectorClock: null,
      );
      await syncService.upsertEntity(updatedHead);

      developer.log(
        'Created version $nextVersion for template '
        '${DomainLogger.sanitizeId(templateId)}',
        name: 'AgentTemplateService',
      );

      return newVersion;
    });
  }

  /// Fetch a single template by its [templateId].
  Future<AgentTemplateEntity?> getTemplate(String templateId) async {
    final entity = await repository.getEntity(templateId);
    return entity?.mapOrNull(agentTemplate: (e) => e);
  }

  /// List all non-deleted templates.
  Future<List<AgentTemplateEntity>> listTemplates() async {
    return repository.getAllTemplates();
  }

  /// Fetch the active version for a template.
  Future<AgentTemplateVersionEntity?> getActiveVersion(
    String templateId,
  ) async {
    return repository.getActiveTemplateVersion(templateId);
  }

  /// Resolve the template assigned to an agent via a templateAssignment link.
  Future<AgentTemplateEntity?> getTemplateForAgent(String agentId) async {
    final links = await repository.getLinksTo(
      agentId,
      type: AgentLinkTypes.templateAssignment,
    );
    if (links.isEmpty) return null;
    return getTemplate(links.selectPrimary().fromId);
  }

  /// Resolve assigned templates for multiple agents in bulk.
  ///
  /// Hydrates list views with two SQL round trips (assignment links, then
  /// template entities) instead of the per-agent `getTemplateForAgent` chain.
  Future<Map<String, AgentTemplateEntity>> getTemplatesForAgents(
    Iterable<String> agentIds,
  ) async {
    final idList = agentIds.toSet().toList(growable: false);
    if (idList.isEmpty) return {};

    final linksByAgentId = await repository.getLinksToMultiple(
      idList,
      type: AgentLinkTypes.templateAssignment,
    );

    final templateIdByAgentId = <String, String>{};
    for (final entry in linksByAgentId.entries) {
      final links = entry.value;
      if (links.isEmpty) continue;
      templateIdByAgentId[entry.key] = links.selectPrimary().fromId;
    }
    if (templateIdByAgentId.isEmpty) return {};

    final entitiesById = await repository.getEntitiesByIds(
      templateIdByAgentId.values,
    );
    return {
      for (final entry in templateIdByAgentId.entries)
        if (entitiesById[entry.value] case final AgentTemplateEntity template)
          entry.key: template,
    };
  }

  /// Reverse lookup: find all agent instances assigned to a template.
  ///
  /// Returns the full [AgentIdentityEntity] for each linked agent, which
  /// enables lifecycle-aware checks (e.g., filtering out destroyed agents).
  Future<List<AgentIdentityEntity>> getAgentsForTemplate(
    String templateId,
  ) async {
    final links = await repository.getLinksFrom(
      templateId,
      type: AgentLinkTypes.templateAssignment,
    );
    final agents = <AgentIdentityEntity>[];
    for (final link in links) {
      final entity = await repository.getEntity(link.toId);
      if (entity is AgentIdentityEntity) {
        agents.add(entity);
      }
    }
    return agents;
  }

  /// List templates whose category IDs contain [categoryId].
  Future<List<AgentTemplateEntity>> listTemplatesForCategory(
    String categoryId,
  ) async {
    final all = await repository.getAllTemplates();
    return all.where((t) => t.categoryIds.contains(categoryId)).toList();
  }

  /// Soft-delete a template.
  ///
  /// Fails if the template has active (non-destroyed) agent instances.
  /// Destroyed agents preserve their links for audit but do not block deletion.
  Future<void> deleteTemplate(String templateId) async {
    final agents = await getAgentsForTemplate(templateId);
    final activeAgents = agents
        .where((a) => a.lifecycle != AgentLifecycle.destroyed)
        .toList();

    if (activeAgents.isNotEmpty) {
      throw TemplateInUseException(
        templateId: templateId,
        activeCount: activeAgents.length,
      );
    }

    final now = clock.now();

    await syncService.runInTransaction(() async {
      final template = await getTemplate(templateId);
      if (template == null) return;

      // Soft-delete the template itself.
      await syncService.upsertEntity(
        template.copyWith(deletedAt: now, updatedAt: now),
      );

      // Soft-delete the head pointer so it no longer appears in queries.
      final head = await repository.getTemplateHead(templateId);
      if (head != null) {
        await syncService.upsertEntity(
          head.copyWith(deletedAt: now, updatedAt: now),
        );
      }

      // Soft-delete all versions for this template.
      final versions = await repository.getEntitiesByAgentId(
        templateId,
        type: AgentEntityTypes.agentTemplateVersion,
      );
      for (final entity in versions) {
        final version = entity.mapOrNull(agentTemplateVersion: (v) => v);
        if (version != null) {
          await syncService.upsertEntity(
            version.copyWith(deletedAt: now),
          );
        }
      }
    });

    developer.log(
      'Soft-deleted template ${DomainLogger.sanitizeId(templateId)}',
      name: 'AgentTemplateService',
    );
  }

  /// Move the head pointer to an existing version.
  ///
  /// Validates that the target version exists and belongs to this template
  /// before updating the head pointer.
  Future<void> rollbackToVersion({
    required String templateId,
    required String versionId,
  }) async {
    final now = clock.now();

    await syncService.runInTransaction(() async {
      final head = await repository.getTemplateHead(templateId);
      if (head == null) {
        throw StateError('No head found for template $templateId');
      }

      // Validate that the target version exists and belongs to this template.
      final versionEntity = await repository.getEntity(versionId);
      final validVersion = versionEntity?.mapOrNull(
        agentTemplateVersion: (v) => v.agentId == templateId ? v : null,
      );
      if (validVersion == null) {
        throw StateError(
          'No version $versionId found for template $templateId',
        );
      }

      // Archive ALL versions to ensure no stale active statuses.
      final allVersions = await getVersionHistory(templateId, limit: -1);
      for (final version in allVersions) {
        if (version.status != AgentTemplateVersionStatus.archived) {
          await syncService.upsertEntity(
            version.copyWith(
              status: AgentTemplateVersionStatus.archived,
            ),
          );
        }
      }

      // Reactivate the target version.
      await syncService.upsertEntity(
        validVersion.copyWith(
          status: AgentTemplateVersionStatus.active,
        ),
      );

      // Update the head pointer.
      final updatedHead = head.copyWith(
        versionId: versionId,
        updatedAt: now,
      );
      await syncService.upsertEntity(updatedHead);
    });

    developer.log(
      'Rolled back template ${DomainLogger.sanitizeId(templateId)} '
      'to version ${DomainLogger.sanitizeId(versionId)}',
      name: 'AgentTemplateService',
    );
  }

  /// Fetch versions for a template, sorted newest-first.
  ///
  /// Returns up to [limit] versions (default 100).
  Future<List<AgentTemplateVersionEntity>> getVersionHistory(
    String templateId, {
    int limit = 100,
  }) async {
    final entities = await repository.getEntitiesByAgentId(
      templateId,
      type: AgentEntityTypes.agentTemplateVersion,
      limit: limit,
    );
    final versions = entities.whereType<AgentTemplateVersionEntity>().toList()
      ..sort((a, b) => b.version.compareTo(a.version));
    return versions;
  }
}
