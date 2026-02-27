import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/template_performance_metrics.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:uuid/uuid.dart';

/// Thrown when a template cannot be deleted because active agents reference it.
class TemplateInUseException implements Exception {
  const TemplateInUseException({
    required this.templateId,
    required this.activeCount,
  });

  final String templateId;
  final int activeCount;

  @override
  String toString() =>
      'TemplateInUseException: cannot delete template $templateId — '
      '$activeCount active instance(s)';
}

/// Well-known template IDs for seeded defaults.
const lauraTemplateId = 'template-laura-001';
const tomTemplateId = 'template-tom-001';

/// High-level service for agent template management.
///
/// Provides operations for creating, versioning, listing, and managing
/// agent templates — reusable blueprints that define an agent's directives,
/// model, and category bindings.
class AgentTemplateService {
  AgentTemplateService({
    required this.repository,
    required this.syncService,
  });

  final AgentRepository repository;
  final AgentSyncService syncService;

  static const _uuid = Uuid();

  /// Create a new template with its initial version and head pointer.
  ///
  /// Returns the created [AgentTemplateEntity].
  Future<AgentTemplateEntity> createTemplate({
    required String displayName,
    required AgentTemplateKind kind,
    required String modelId,
    required String directives,
    required String authoredBy,
    Set<String> categoryIds = const {},
    String? templateId,
  }) async {
    final tplId = templateId ?? _uuid.v4();
    final versionId = _uuid.v4();
    final headId = _uuid.v4();
    final now = clock.now();

    final template = AgentDomainEntity.agentTemplate(
      id: tplId,
      agentId: tplId,
      displayName: displayName,
      kind: kind,
      modelId: modelId,
      categoryIds: categoryIds,
      createdAt: now,
      updatedAt: now,
      vectorClock: null,
    ) as AgentTemplateEntity;

    final version = AgentDomainEntity.agentTemplateVersion(
      id: versionId,
      agentId: tplId,
      version: 1,
      status: AgentTemplateVersionStatus.active,
      directives: directives,
      authoredBy: authoredBy,
      createdAt: now,
      vectorClock: null,
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
      'Created template $tplId (name: $displayName)',
      name: 'AgentTemplateService',
    );

    return template;
  }

  /// Update template-level fields (display name, model ID).
  ///
  /// This updates the template entity itself, not its versioned directives.
  /// Use [createVersion] to update directives.
  Future<AgentTemplateEntity> updateTemplate({
    required String templateId,
    String? displayName,
    String? modelId,
  }) async {
    final now = clock.now();

    return syncService.runInTransaction(() async {
      final template = await getTemplate(templateId);
      if (template == null) {
        throw StateError('Template $templateId not found');
      }

      final updated = template.copyWith(
        displayName: displayName ?? template.displayName,
        modelId: modelId ?? template.modelId,
        updatedAt: now,
      );
      await syncService.upsertEntity(updated);

      developer.log(
        'Updated template $templateId '
        '(name: ${updated.displayName}, model: ${updated.modelId})',
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
  }) async {
    final now = clock.now();
    final newVersionId = _uuid.v4();

    return syncService.runInTransaction(() async {
      // Validate that the template exists.
      final template = await getTemplate(templateId);
      if (template == null) {
        throw StateError('Template $templateId not found');
      }

      // Archive the current active version.
      final currentHead = await repository.getTemplateHead(templateId);
      if (currentHead != null) {
        final currentVersion =
            await repository.getEntity(currentHead.versionId);
        final archived = currentVersion?.mapOrNull(
          agentTemplateVersion: (v) => v.copyWith(
            status: AgentTemplateVersionStatus.archived,
          ),
        );
        if (archived != null) {
          await syncService.upsertEntity(archived);
        }
      }

      // Determine next version number.
      final nextVersion =
          await repository.getNextTemplateVersionNumber(templateId);

      // Create the new version.
      final newVersion = AgentDomainEntity.agentTemplateVersion(
        id: newVersionId,
        agentId: templateId,
        version: nextVersion,
        status: AgentTemplateVersionStatus.active,
        directives: directives,
        authoredBy: authoredBy,
        createdAt: now,
        vectorClock: null,
      ) as AgentTemplateVersionEntity;
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
        'Created version $nextVersion for template $templateId',
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
    final links =
        await repository.getLinksTo(agentId, type: 'template_assignment');
    if (links.isEmpty) return null;
    return getTemplate(links.first.fromId);
  }

  /// Reverse lookup: find all agent instances assigned to a template.
  ///
  /// Returns the full [AgentIdentityEntity] for each linked agent, which
  /// enables lifecycle-aware checks (e.g., filtering out destroyed agents).
  Future<List<AgentIdentityEntity>> getAgentsForTemplate(
    String templateId,
  ) async {
    final links =
        await repository.getLinksFrom(templateId, type: 'template_assignment');
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
    final activeAgents =
        agents.where((a) => a.lifecycle != AgentLifecycle.destroyed).toList();

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
        type: 'agentTemplateVersion',
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
      'Soft-deleted template $templateId',
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

      // Archive the currently active version.
      final currentVersionEntity = await repository.getEntity(head.versionId);
      if (currentVersionEntity is AgentTemplateVersionEntity) {
        await syncService.upsertEntity(
          currentVersionEntity.copyWith(
            status: AgentTemplateVersionStatus.archived,
          ),
        );
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
      'Rolled back template $templateId to version $versionId',
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
      type: 'agentTemplateVersion',
      limit: limit,
    );
    final versions = entities.whereType<AgentTemplateVersionEntity>().toList()
      ..sort((a, b) => b.version.compareTo(a.version));
    return versions;
  }

  /// Compute recent performance metrics for a template.
  ///
  /// Fetches up to [limit] most recent wake-run log entries tagged with this
  /// template and agent instances using it, then aggregates into
  /// [TemplatePerformanceMetrics]. Metrics reflect the recent window, not
  /// necessarily the template's entire history.
  Future<TemplatePerformanceMetrics> computeMetrics(
    String templateId, {
    int limit = 500,
  }) async {
    final runs = await repository.getWakeRunsForTemplate(
      templateId,
      limit: limit,
    );
    final agents = await getAgentsForTemplate(templateId);

    final totalWakes = runs.length;
    var successCount = 0;
    var failureCount = 0;
    var durationSumMs = 0;
    var durationCount = 0;
    // Query returns rows ordered by created_at DESC, so first = latest,
    // last = earliest.
    final lastWakeAt = runs.isNotEmpty ? runs.first.createdAt : null;
    final firstWakeAt = runs.isNotEmpty ? runs.last.createdAt : null;

    for (final r in runs) {
      if (r.status == WakeRunStatus.completed.name) successCount++;
      if (r.status == WakeRunStatus.failed.name) failureCount++;
      if (r.startedAt != null && r.completedAt != null) {
        final diffMs = r.completedAt!.difference(r.startedAt!).inMilliseconds;
        if (diffMs > 0) {
          durationSumMs += diffMs;
          durationCount++;
        }
      }
    }

    final terminalCount = successCount + failureCount;
    final successRate = terminalCount > 0 ? successCount / terminalCount : 0.0;
    final averageDuration = durationCount > 0
        ? Duration(milliseconds: durationSumMs ~/ durationCount)
        : null;

    return TemplatePerformanceMetrics(
      templateId: templateId,
      totalWakes: totalWakes,
      successCount: successCount,
      failureCount: failureCount,
      successRate: successRate,
      averageDuration: averageDuration,
      firstWakeAt: firstWakeAt,
      lastWakeAt: lastWakeAt,
      activeInstanceCount:
          agents.where((a) => a.lifecycle == AgentLifecycle.active).length,
    );
  }

  // ── Evolution data fetching ─────────────────────────────────────────────

  /// Fetch the N most recent reports from all instances of this template.
  Future<List<AgentReportEntity>> getRecentInstanceReports(
    String templateId, {
    int limit = 10,
  }) {
    return repository.getRecentReportsByTemplate(templateId, limit: limit);
  }

  /// Fetch the N most recent observation messages from all instances of this
  /// template.
  Future<List<AgentMessageEntity>> getRecentInstanceObservations(
    String templateId, {
    int limit = 10,
  }) {
    return repository.getRecentObservationsByTemplate(templateId, limit: limit);
  }

  /// Fetch evolution notes for a template, newest-first.
  Future<List<EvolutionNoteEntity>> getRecentEvolutionNotes(
    String templateId, {
    int limit = 50,
  }) {
    return repository.getEvolutionNotes(templateId, limit: limit);
  }

  /// Fetch evolution sessions for a template, newest-first.
  Future<List<EvolutionSessionEntity>> getEvolutionSessions(
    String templateId, {
    int limit = 10,
  }) {
    return repository.getEvolutionSessions(templateId, limit: limit);
  }

  /// Count entities changed since [since] for all instances of [templateId].
  Future<int> countChangesSince(String templateId, DateTime? since) {
    return repository.countChangedSinceForTemplate(templateId, since);
  }

  /// Idempotent seed of default templates (Laura and Tom).
  ///
  /// Checks each default template independently, seeding only those that are
  /// missing. This handles partial-seed scenarios (e.g., Laura exists but Tom
  /// does not).
  Future<void> seedDefaults() async {
    final laura = await getTemplate(lauraTemplateId);
    final tom = await getTemplate(tomTemplateId);

    if (laura != null && tom != null) {
      developer.log(
        'Default templates already seeded, skipping',
        name: 'AgentTemplateService',
      );
      return;
    }

    if (laura == null) {
      await createTemplate(
        templateId: lauraTemplateId,
        displayName: 'Laura',
        kind: AgentTemplateKind.taskAgent,
        modelId: 'models/gemini-3.1-pro-preview',
        directives: 'You are Laura, a diligent task management agent. '
            'You help users organize, prioritize, and complete their tasks '
            'efficiently. You write clear, actionable reports.',
        authoredBy: 'system',
      );
    }

    if (tom == null) {
      await createTemplate(
        templateId: tomTemplateId,
        displayName: 'Tom',
        kind: AgentTemplateKind.taskAgent,
        modelId: 'models/gemini-3.1-pro-preview',
        directives: 'You are Tom, a creative and analytical task agent. '
            'You help users think through problems, break down complex tasks, '
            'and find innovative solutions. You write insightful reports.',
        authoredBy: 'system',
      );
    }

    developer.log(
      'Seeded default templates (Laura, Tom)',
      name: 'AgentTemplateService',
    );
  }
}
