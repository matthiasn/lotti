import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/agents/service/feedback_extraction_service.dart';
import 'package:lotti/features/agents/service/improver_agent_service.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/workflow/ritual_context_builder.dart';
import 'package:lotti/features/agents/workflow/template_evolution_workflow.dart';
import 'package:lotti/features/agents/workflow/wake_result.dart';
import 'package:lotti/services/domain_logging.dart';

/// Orchestrates the improver agent ritual workflow.
///
/// When a scheduled wake fires for an improver agent, this workflow:
/// 1. Loads agent state and resolves the target template
/// 2. Extracts and classifies feedback since the last scan
/// 3. Checks the feedback threshold (skips if insufficient)
/// 4. Starts an interactive evolution session with enriched ritual context
/// 5. Updates the improver state watermarks
class ImproverAgentWorkflow {
  ImproverAgentWorkflow({
    required this.feedbackService,
    required this.evolutionWorkflow,
    required this.improverService,
    required this.repository,
    required this.templateService,
    required this.syncService,
    this.domainLogger,
  });

  final FeedbackExtractionService feedbackService;
  final TemplateEvolutionWorkflow evolutionWorkflow;
  final ImproverAgentService improverService;
  final AgentRepository repository;
  final AgentTemplateService templateService;
  final AgentSyncService syncService;
  final DomainLogger? domainLogger;

  static const _logTag = 'ImproverAgentWorkflow';

  /// Minimum feedback items required to trigger a ritual session.
  static const minFeedbackThreshold = 3;

  /// Execute the ritual workflow for an improver agent.
  Future<WakeResult> execute({
    required AgentIdentityEntity agentIdentity,
    required String runKey,
    required String threadId,
  }) async {
    final agentId = agentIdentity.agentId;

    // 1. Load agent state.
    final state = await repository.getAgentState(agentId);
    if (state == null) {
      return const WakeResult(
        success: false,
        error: 'No agent state found',
      );
    }

    // 2. Extract the target template ID from slots.
    final targetTemplateId = state.slots.activeTemplateId;
    if (targetTemplateId == null) {
      return const WakeResult(
        success: false,
        error: 'No activeTemplateId in agent slots',
      );
    }

    // 3. Verify the target template exists.
    final targetTemplate = await templateService.getTemplate(targetTemplateId);
    if (targetTemplate == null) {
      return WakeResult(
        success: false,
        error: 'Target template $targetTemplateId not found',
      );
    }

    // 4. Extract feedback since last scan.
    final feedbackSince =
        state.slots.lastFeedbackScanAt ?? state.slots.lastOneOnOneAt;
    final since = feedbackSince ?? agentIdentity.createdAt;
    final feedback = await feedbackService.extract(
      templateId: targetTemplateId,
      since: since,
    );

    developer.log(
      'Extracted ${feedback.items.length} feedback items for '
      'template $targetTemplateId (since $since)',
      name: _logTag,
    );

    // 5. Threshold gate — skip if insufficient feedback.
    if (feedback.items.length < minFeedbackThreshold) {
      developer.log(
        'Skipped ritual — insufficient feedback '
        '(${feedback.items.length} < $minFeedbackThreshold)',
        name: _logTag,
      );

      // Record a no-op observation.
      final now = clock.now();
      final updatedState = state.copyWith(
        slots: state.slots.copyWith(lastFeedbackScanAt: now),
        updatedAt: now,
      );
      await syncService.upsertEntity(updatedState);

      // Schedule next wake.
      await improverService.scheduleNextRitual(agentId);

      return const WakeResult(success: true);
    }

    // 6. Build ritual context and start evolution session.
    try {
      // Parallelize: active version and evolution data are independent.
      final (currentVersion, data) = await (
        templateService.getActiveVersion(targetTemplateId),
        templateService.gatherEvolutionData(targetTemplateId),
      ).wait;
      if (currentVersion == null) {
        return WakeResult(
          success: false,
          error: 'No active version for template $targetTemplateId',
        );
      }

      final contextBuilder = RitualContextBuilder();

      final ritualContext = contextBuilder.buildRitualContext(
        template: targetTemplate,
        currentVersion: currentVersion,
        recentVersions: data.recentVersions,
        instanceReports: data.instanceReports,
        instanceObservations: data.instanceObservations,
        pastNotes: data.pastNotes,
        metrics: data.metrics,
        changesSinceLastSession: data.changesSinceLastSession,
        classifiedFeedback: feedback,
        sessionNumber: data.nextSessionNumber,
        observationPayloads: data.observationPayloads,
      );

      // Start evolution session with the ritual context override.
      // Pass sessionNumber to avoid a redundant gatherEvolutionData call.
      final response = await evolutionWorkflow.startSession(
        templateId: targetTemplateId,
        contextOverride: ritualContext,
        sessionNumberOverride: data.nextSessionNumber,
      );

      if (response == null) {
        // Session failed to start — still schedule next wake.
        await improverService.scheduleNextRitual(agentId);
        return const WakeResult(
          success: false,
          error: 'Failed to start evolution session',
        );
      }

      // 7. Update improver state watermarks.
      final now = clock.now();
      final updatedState = state.copyWith(
        slots: state.slots.copyWith(lastFeedbackScanAt: now),
        wakeCounter: state.wakeCounter + 1,
        updatedAt: now,
      );
      await syncService.upsertEntity(updatedState);

      developer.log(
        'Started ritual session for template $targetTemplateId',
        name: _logTag,
      );

      return const WakeResult(success: true);
    } catch (e, s) {
      developer.log(
        'Ritual workflow failed',
        name: _logTag,
        error: e,
        stackTrace: s,
      );

      // Best effort: schedule next wake even on failure.
      try {
        await improverService.scheduleNextRitual(agentId);
      } catch (scheduleError) {
        developer.log(
          'Failed to schedule next ritual after error',
          name: _logTag,
          error: scheduleError,
        );
      }

      return WakeResult(
        success: false,
        error: 'Ritual workflow failed: $e',
      );
    }
  }
}
