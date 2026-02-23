import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/template_performance_metrics.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:uuid/uuid.dart';

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

  /// Reverse lookup: find all agents assigned to a template.
  Future<List<String>> getAgentsForTemplate(String templateId) async {
    final links =
        await repository.getLinksFrom(templateId, type: 'template_assignment');
    return links.map((l) => l.toId).toList();
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
  /// Fails if the template has active agent instances.
  Future<void> deleteTemplate(String templateId) async {
    final agents = await getAgentsForTemplate(templateId);
    if (agents.isNotEmpty) {
      throw Exception(
        'Cannot delete template $templateId: '
        '${agents.length} active instance(s)',
      );
    }

    final now = clock.now();

    await syncService.runInTransaction(() async {
      final template = await getTemplate(templateId);
      if (template == null) return;

      final deleted = template.copyWith(
        deletedAt: now,
        updatedAt: now,
      );
      await syncService.upsertEntity(deleted);
    });

    developer.log(
      'Soft-deleted template $templateId',
      name: 'AgentTemplateService',
    );
  }

  /// Move the head pointer to an existing version.
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

  /// Fetch all versions for a template, sorted newest-first.
  Future<List<AgentTemplateVersionEntity>> getVersionHistory(
    String templateId,
  ) async {
    final entities = await repository.getEntitiesByAgentId(
      templateId,
      type: 'agentTemplateVersion',
      limit: 100,
    );
    final versions = entities.whereType<AgentTemplateVersionEntity>().toList()
      ..sort((a, b) => b.version.compareTo(a.version));
    return versions;
  }

  /// Compute aggregated performance metrics for a template.
  ///
  /// Fetches wake-run log entries tagged with this template and agent
  /// instances using it, then aggregates into [TemplatePerformanceMetrics].
  Future<TemplatePerformanceMetrics> computeMetrics(
    String templateId,
  ) async {
    final runs = await repository.getWakeRunsForTemplate(templateId);
    final agents = await getAgentsForTemplate(templateId);

    final totalWakes = runs.length;
    final successCount = runs.where((r) => r.status == 'completed').length;
    final failureCount = runs.where((r) => r.status == 'failed').length;
    final successRate = totalWakes > 0 ? successCount / totalWakes : 0.0;

    Duration? averageDuration;
    final completedRuns = runs.where(
      (r) => r.startedAt != null && r.completedAt != null,
    );
    if (completedRuns.isNotEmpty) {
      final totalMs = completedRuns.fold<int>(
        0,
        (sum, r) =>
            sum + r.completedAt!.difference(r.startedAt!).inMilliseconds,
      );
      averageDuration = Duration(milliseconds: totalMs ~/ completedRuns.length);
    }

    final firstWakeAt =
        runs.isNotEmpty ? runs.last.createdAt : null; // oldest = last (DESC)
    final lastWakeAt =
        runs.isNotEmpty ? runs.first.createdAt : null; // newest = first (DESC)

    return TemplatePerformanceMetrics(
      templateId: templateId,
      totalWakes: totalWakes,
      successCount: successCount,
      failureCount: failureCount,
      successRate: successRate,
      averageDuration: averageDuration,
      firstWakeAt: firstWakeAt,
      lastWakeAt: lastWakeAt,
      activeInstanceCount: agents.length,
    );
  }

  /// Idempotent seed of default templates (Laura and Tom).
  ///
  /// Skips creation if templates with the well-known IDs already exist.
  Future<void> seedDefaults() async {
    final existing = await getTemplate(lauraTemplateId);
    if (existing != null) {
      developer.log(
        'Default templates already seeded, skipping',
        name: 'AgentTemplateService',
      );
      return;
    }

    await createTemplate(
      templateId: lauraTemplateId,
      displayName: 'Laura',
      kind: AgentTemplateKind.taskAgent,
      modelId: 'models/gemini-3.1-pro-preview',
      directives: 'You are Laura, an encouraging task coach. '
          'You celebrate progress, acknowledge effort, and keep momentum high. '
          'When a task stalls, you gently nudge with small next steps rather '
          'than overwhelming lists. You notice when deadlines are at risk and '
          'suggest realistic re-plans instead of just flagging the problem. '
          'Your reports open with what has been accomplished, then highlight '
          'the single most important next action. Keep your tone warm, '
          'supportive, and concise.',
      authoredBy: 'system',
    );

    await createTemplate(
      templateId: tomTemplateId,
      displayName: 'Tom',
      kind: AgentTemplateKind.taskAgent,
      modelId: 'models/gemini-3.1-pro-preview',
      directives: 'You are Tom, a sharp analytical task agent. '
          'You look for patterns, dependencies, and risks that are easy to '
          'overlook. When reviewing a task, you identify blockers, flag '
          'unrealistic estimates with evidence, and surface hidden '
          'connections between checklist items. You are direct and '
          'matter-of-fact — no filler. Your reports lead with risks and '
          'dependencies, then list open questions that need answers before '
          'the task can move forward. Prioritize clarity over diplomacy.',
      authoredBy: 'system',
    );

    developer.log(
      'Seeded default templates (Laura, Tom)',
      name: 'AgentTemplateService',
    );
  }
}
