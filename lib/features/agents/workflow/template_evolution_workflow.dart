import 'dart:convert';
import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:genui/genui.dart';
import 'package:lotti/features/agents/genui/evolution_catalog.dart';
import 'package:lotti/features/agents/genui/genui_bridge.dart';
import 'package:lotti/features/agents/genui/genui_event_handler.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/classified_feedback.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/agents/service/feedback_extraction_service.dart';
import 'package:lotti/features/agents/service/soul_document_service.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/agents/util/inference_provider_resolver.dart';
import 'package:lotti/features/agents/workflow/evolution_context_builder.dart';
import 'package:lotti/features/agents/workflow/evolution_strategy.dart';
import 'package:lotti/features/agents/workflow/soul_evolution_context_builder.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_wrapper.dart';
import 'package:lotti/features/ai/util/content_extraction_helper.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:meta/meta.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:uuid/uuid.dart';

part 'soul_evolution_workflow.dart';
part 'template_evolution_session.dart';
part 'template_evolution_helpers.dart';

// Library-private helpers shared by the workflow and its extension parts.
const _uuid = Uuid();
const _logTag = 'TemplateEvolutionWorkflow';

/// Tracks in-memory state for an active evolution session.
class ActiveEvolutionSession {
  ActiveEvolutionSession({
    required this.sessionId,
    required this.templateId,
    required this.conversationId,
    required this.strategy,
    required this.modelId,
    this.geminiThinkingMode,
    this.processor,
    this.genUiBridge,
    this.eventHandler,
  });

  final String sessionId;
  final String templateId;
  final String conversationId;
  final EvolutionStrategy strategy;
  final String modelId;
  final GeminiThinkingMode? geminiThinkingMode;

  /// GenUI message processor for rendering dynamic surfaces.
  final SurfaceController? processor;

  /// Bridge between OpenAI tool calls and GenUI surface creation.
  final GenUiBridge? genUiBridge;

  /// Routes GenUI surface events to evolution chat logic.
  final GenUiEventHandler? eventHandler;

  /// Cached version from a previous approval attempt, keyed by the directives
  /// text. Reused on retry only if the proposal hasn't changed.
  String? _approvedDirectives;
  AgentTemplateVersionEntity? _approvedVersion;

  /// Returns the cached version if [directives] matches, otherwise `null`.
  AgentTemplateVersionEntity? getCachedVersion(String directives) =>
      directives == _approvedDirectives ? _approvedVersion : null;

  /// Caches a successfully created version for idempotent retry.
  void cacheVersion(
    AgentTemplateVersionEntity version,
    String directives,
  ) {
    _approvedDirectives = directives;
    _approvedVersion = version;
  }

  /// Clears any cached approval state (e.g., after rejection).
  void clearApprovalCache() {
    _approvedDirectives = null;
    _approvedVersion = null;
  }
}

/// Workflow that uses an LLM to propose improved template directives based on
/// performance metrics and user feedback.
///
/// Uses multi-turn sessions: [startSession] / [sendMessage] / [approveProposal]
/// enable a 1-on-1 dialogue with the evolution agent, with tool-based
/// proposals and notes.
class TemplateEvolutionWorkflow {
  TemplateEvolutionWorkflow({
    required this.conversationRepository,
    required this.aiConfigRepository,
    required this.cloudInferenceRepository,
    this.templateService,
    this.syncService,
    this.soulDocumentService,
    this.feedbackService,
    this.contextBuilder,
    this.updateNotifications,
    this.onSessionCompleted,
  });

  final ConversationRepository conversationRepository;
  final AiConfigRepository aiConfigRepository;
  final CloudInferenceRepository cloudInferenceRepository;

  /// Required for multi-turn sessions.
  final AgentTemplateService? templateService;
  final AgentSyncService? syncService;
  final SoulDocumentService? soulDocumentService;
  final FeedbackExtractionService? feedbackService;
  final EvolutionContextBuilder? contextBuilder;

  /// When provided, fires after local DB writes so UI providers refresh.
  final UpdateNotifications? updateNotifications;

  /// Optional callback invoked after [approveProposal] completes successfully.
  ///
  /// Receives the template ID and session ID so callers (e.g., the improver
  /// workflow) can schedule the next ritual and update state.
  final void Function(String templateId, String sessionId)? onSessionCompleted;

  /// Active sessions keyed by session entity ID.
  @visibleForTesting
  final activeSessions = <String, ActiveEvolutionSession>{};

  /// Send a user message in an active evolution session.
  ///
  /// Returns the assistant's response, or `null` if the session is not found
  /// or the LLM call fails.
  Future<String?> sendMessage({
    required String sessionId,
    required String userMessage,
  }) async {
    final active = activeSessions[sessionId];
    if (active == null) {
      developer.log(
        'No active session ${DomainLogger.sanitizeId(sessionId)}',
        name: _logTag,
      );
      return null;
    }

    final inferenceSlot = await resolveInferenceProviderWithModel(
      modelId: active.modelId,
      aiConfigRepository: aiConfigRepository,
      logTag: _logTag,
    );
    if (inferenceSlot == null) return null;
    final provider = inferenceSlot.provider;

    try {
      await conversationRepository.sendMessage(
        conversationId: active.conversationId,
        message: userMessage,
        model: active.modelId,
        provider: provider,
        inferenceRepo: CloudInferenceWrapper(
          cloudRepository: cloudInferenceRepository,
          geminiThinkingMode: active.geminiThinkingMode,
        ),
        tools: _buildToolDefinitions(bridge: active.genUiBridge),
        strategy: active.strategy,
      );

      return _extractLastAssistantContent(active.conversationId);
    } catch (e, s) {
      developer.log(
        'sendMessage failed for session '
        '${DomainLogger.sanitizeId(sessionId)}',
        name: _logTag,
        error: e.runtimeType,
        stackTrace: s,
      );
      return null;
    }
  }

  /// Get the current pending proposal for a session, if any.
  PendingProposal? getCurrentProposal({required String sessionId}) {
    return activeSessions[sessionId]?.strategy.latestProposal;
  }

  /// Get the latest structured ritual recap for a session, if one exists.
  PendingRitualRecap? getCurrentRecap({required String sessionId}) {
    return activeSessions[sessionId]?.strategy.latestRecap;
  }

  /// Approve the current proposal: create a new template version, persist
  /// pending notes, and complete the session.
  ///
  /// Returns the created [AgentTemplateVersionEntity], or `null` on failure.
  Future<AgentTemplateVersionEntity?> approveProposal({
    required String sessionId,
    double? userRating,
    String? feedbackSummary,
    Map<String, int> categoryRatings = const {},
  }) async {
    final active = activeSessions[sessionId];
    final svc = templateService;
    final sync = syncService;
    if (active == null || svc == null || sync == null) return null;

    final proposal = active.strategy.latestProposal;
    if (proposal == null) {
      developer.log(
        'No proposal to approve for ${DomainLogger.sanitizeId(sessionId)}',
        name: _logTag,
      );
      return null;
    }

    try {
      // Create the new template version (idempotent: reuse cached version if
      // the proposal directives haven't changed since the last attempt).
      final cacheKey = jsonEncode({
        'generalDirective': proposal.generalDirective,
        'reportDirective': proposal.reportDirective,
      });
      final newVersion =
          active.getCachedVersion(cacheKey) ??
          await _createVersionIdempotent(
            svc: svc,
            templateId: active.templateId,
            generalDirective: proposal.generalDirective,
            reportDirective: proposal.reportDirective,
          );
      active.cacheVersion(newVersion, cacheKey);

      // Persist any pending notes. _persistNotes drains the list as it goes,
      // so retries only persist notes that weren't written yet, and new notes
      // added after a failed attempt are included.
      await _persistNotes(
        strategy: active.strategy,
        templateId: active.templateId,
        sessionId: sessionId,
        sync: sync,
      );

      final recap = _buildSessionRecapEntity(
        active: active,
        proposal: proposal,
        categoryRatings: categoryRatings,
      );
      if (recap != null) {
        await sync.upsertEntity(recap);
      }

      // Complete the session entity.
      final now = clock.now();
      final sessionEntity = await _getSessionEntity(sessionId);
      if (sessionEntity != null) {
        final normalizedRating =
            userRating ?? _averageCategoryRating(categoryRatings);
        final recapTldr = recap?.tldr.trim();
        final normalizedSummary =
            feedbackSummary ??
            ((recapTldr != null && recapTldr.isNotEmpty)
                ? recapTldr
                : proposal.rationale);
        await sync.upsertEntity(
          sessionEntity.copyWith(
            status: EvolutionSessionStatus.completed,
            proposedVersionId: newVersion.id,
            feedbackSummary: normalizedSummary,
            userRating: normalizedRating,
            completedAt: now,
            updatedAt: now,
          ),
        );
      }

      // Clean up and notify UI.
      _cleanupSession(sessionId);

      // Abandon any other stale active sessions for this template.
      try {
        await _abandonStaleActiveSessions(
          templateId: active.templateId,
          currentSessionId: sessionId,
        );
      } catch (e, s) {
        developer.log(
          'Failed to auto-abandon stale sessions for template '
          '${DomainLogger.sanitizeId(active.templateId)}',
          name: _logTag,
          error: e.runtimeType,
          stackTrace: s,
        );
      }

      _notifyUpdate(active.templateId);

      // Invoke the post-approval callback (e.g., schedule next ritual).
      // Wrapped in try/catch so a callback failure does not convert a
      // successful approval into a null return.
      try {
        onSessionCompleted?.call(active.templateId, sessionId);
      } catch (e, s) {
        developer.log(
          'onSessionCompleted failed for '
          '${DomainLogger.sanitizeId(sessionId)}',
          name: _logTag,
          error: e.runtimeType,
          stackTrace: s,
        );
      }

      developer.log(
        'Approved proposal for session '
        '${DomainLogger.sanitizeId(sessionId)} → version '
        '${DomainLogger.sanitizeId(newVersion.id)}',
        name: _logTag,
      );

      return newVersion;
    } catch (e, s) {
      developer.log(
        'approveProposal failed for ${DomainLogger.sanitizeId(sessionId)}',
        name: _logTag,
        error: e.runtimeType,
        stackTrace: s,
      );
      return null;
    }
  }

  /// Reject the current proposal, clearing it from the strategy so the
  /// conversation can continue.
  void rejectProposal({required String sessionId}) {
    final active = activeSessions[sessionId];
    if (active == null) return;

    final hadProposal = active.strategy.latestProposal != null;
    active.strategy.clearProposal();
    active.clearApprovalCache();

    if (hadProposal) {
      developer.log(
        'Rejected proposal for session ${DomainLogger.sanitizeId(sessionId)}',
        name: _logTag,
      );
    }
  }

  /// Approves the pending soul proposal; see [SoulEvolutionWorkflow].
  Future<SoulDocumentVersionEntity?> approveSoulProposal({
    required String sessionId,
  }) => approveSoulProposalImpl(sessionId: sessionId);

  /// Rejects the pending soul proposal; see [SoulEvolutionWorkflow].
  void rejectSoulProposal({required String sessionId}) =>
      rejectSoulProposalImpl(sessionId: sessionId);

  /// Starts a standalone soul 1-on-1 session; see [SoulEvolutionWorkflow].
  Future<String?> startSoulSession({required String soulId}) =>
      startSoulSessionImpl(soulId: soulId);

  /// Completes the soul session; see [SoulEvolutionWorkflow].
  Future<SoulDocumentVersionEntity?> completeSoulSession({
    required String sessionId,
    Map<String, int> categoryRatings = const {},
  }) => completeSoulSessionImpl(
    sessionId: sessionId,
    categoryRatings: categoryRatings,
  );

  /// Abandon an active session, persisting any pending notes and marking the
  /// session as abandoned.
  ///
  /// Works even when the session is not in [activeSessions] (e.g., when
  /// [startSession] fails after the entity is persisted but before the
  /// in-memory map is populated).
  Future<void> abandonSession({required String sessionId}) async {
    final active = activeSessions[sessionId];
    final sync = syncService;
    var templateId = active?.templateId;

    try {
      if (sync != null) {
        // Best-effort: persist any notes accumulated during the session.
        // Notes are advisory — a failure here must not prevent cleanup.
        if (active != null) {
          try {
            await _persistNotes(
              strategy: active.strategy,
              templateId: active.templateId,
              sessionId: sessionId,
              sync: sync,
            );
          } catch (e, s) {
            developer.log(
              'Failed to persist notes during abandon',
              name: _logTag,
              error: e.runtimeType,
              stackTrace: s,
            );
          }
        }

        // Mark session as abandoned in the database.
        final sessionEntity = await _getSessionEntity(sessionId);
        if (sessionEntity != null &&
            sessionEntity.status == EvolutionSessionStatus.active) {
          templateId ??= sessionEntity.templateId;
          final now = clock.now();
          await sync.upsertEntity(
            sessionEntity.copyWith(
              status: EvolutionSessionStatus.abandoned,
              completedAt: now,
              updatedAt: now,
            ),
          );
        }
      }
    } finally {
      _cleanupSession(sessionId);

      if (templateId != null) {
        _notifyUpdate(templateId);
      }
    }
  }

  /// Get the active session by session ID.
  ActiveEvolutionSession? getSession(String sessionId) =>
      activeSessions[sessionId];

  /// Get the active session for a template, if any.
  ActiveEvolutionSession? getActiveSessionForTemplate(String templateId) {
    for (final session in activeSessions.values) {
      if (session.templateId == templateId) return session;
    }
    return null;
  }

  /// Get the active session for a soul, if any.
  ///
  /// Soul sessions use `templateId = soulId` in [ActiveEvolutionSession].
  ActiveEvolutionSession? getActiveSessionForSoul(String soulId) =>
      getActiveSessionForTemplate(soulId);

  // ── Standalone soul evolution ─────────────────────────────────────────────
}
