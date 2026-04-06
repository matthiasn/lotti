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
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/agents/service/soul_document_service.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/agents/util/inference_provider_resolver.dart';
import 'package:lotti/features/agents/workflow/evolution_context_builder.dart';
import 'package:lotti/features/agents/workflow/evolution_strategy.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_wrapper.dart';
import 'package:lotti/features/ai/util/content_extraction_helper.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:meta/meta.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:uuid/uuid.dart';

/// Tracks in-memory state for an active evolution session.
class ActiveEvolutionSession {
  ActiveEvolutionSession({
    required this.sessionId,
    required this.templateId,
    required this.conversationId,
    required this.strategy,
    required this.modelId,
    this.processor,
    this.genUiBridge,
    this.eventHandler,
  });

  final String sessionId;
  final String templateId;
  final String conversationId;
  final EvolutionStrategy strategy;
  final String modelId;

  /// GenUI message processor for rendering dynamic surfaces.
  final A2uiMessageProcessor? processor;

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
  final EvolutionContextBuilder? contextBuilder;

  /// When provided, fires after local DB writes so UI providers refresh.
  final UpdateNotifications? updateNotifications;

  /// Optional callback invoked after [approveProposal] completes successfully.
  ///
  /// Receives the template ID and session ID so callers (e.g., the improver
  /// workflow) can schedule the next ritual and update state.
  final void Function(String templateId, String sessionId)? onSessionCompleted;

  static const _uuid = Uuid();
  static const _logTag = 'TemplateEvolutionWorkflow';

  /// Active sessions keyed by session entity ID.
  @visibleForTesting
  final activeSessions = <String, ActiveEvolutionSession>{};

  /// Start a new multi-turn evolution session for [templateId].
  ///
  /// Gathers all context (metrics, reports, observations, notes, versions),
  /// creates an [EvolutionSessionEntity], starts the conversation, and sends
  /// the initial context message to the LLM. Returns the assistant's opening
  /// response, or `null` if setup fails.
  ///
  /// When [contextOverride] is provided, skips internal context building and
  /// uses the given [EvolutionContext] directly. This allows callers (e.g.,
  /// the improver ritual workflow) to inject enriched context.
  Future<String?> startSession({
    required String templateId,
    EvolutionContext? contextOverride,
    int? sessionNumberOverride,
  }) async {
    final svc = templateService;
    final sync = syncService;
    final ctxBuilder = contextBuilder ?? EvolutionContextBuilder();
    if (svc == null || sync == null) {
      developer.log(
        'templateService and syncService are required for sessions',
        name: _logTag,
      );
      return null;
    }

    // Only one active session per template at a time.
    if (getActiveSessionForTemplate(templateId) != null) {
      developer.log(
        'Session already active for template $templateId',
        name: _logTag,
      );
      return null;
    }

    // Fetch template and active version.
    final template = await svc.getTemplate(templateId);
    if (template == null) {
      developer.log('Template $templateId not found', name: _logTag);
      return null;
    }

    final currentVersion = await svc.getActiveVersion(templateId);
    if (currentVersion == null) {
      developer.log(
        'No active version for template $templateId',
        name: _logTag,
      );
      return null;
    }

    // Resolve the inference provider.
    final provider = await resolveInferenceProvider(
      modelId: template.modelId,
      aiConfigRepository: aiConfigRepository,
      logTag: _logTag,
    );
    if (provider == null) {
      developer.log(
        'Cannot resolve provider for model ${template.modelId}',
        name: _logTag,
      );
      return null;
    }

    // Everything below is wrapped in try-catch so that exceptions from data
    // fetches, context building, or the LLM call all return `null` instead of
    // propagating to the UI caller.
    final sessionId = _uuid.v4();
    try {
      // Abandon any stale active sessions for this template before starting
      // a new one (e.g., sessions left active from a crash or disconnect).
      await _abandonStaleActiveSessions(
        templateId: templateId,
        currentSessionId: sessionId,
      );

      final EvolutionContext ctx;
      final int sessionNumber;
      // Track the resolved soul version across paths so we can reuse it for
      // the strategy without a redundant database call.
      SoulDocumentVersionEntity? resolvedSoulVersion;

      if (contextOverride != null && sessionNumberOverride != null) {
        // Fast path: use caller-provided context and session number.
        ctx = contextOverride;
        sessionNumber = sessionNumberOverride;
      } else if (contextOverride != null) {
        // Optimized path: context is provided but session number is not.
        // Fetch only sessions instead of full gatherEvolutionData.
        final sessions = await svc.getEvolutionSessions(templateId);
        sessionNumber =
            sessions.fold(
              0,
              (max, s) => s.sessionNumber > max ? s.sessionNumber : max,
            ) +
            1;
        ctx = contextOverride;
      } else {
        // Full path: gather all data to build context and session number.
        final data = await svc.gatherEvolutionData(templateId);
        sessionNumber = sessionNumberOverride ?? data.nextSessionNumber;

        // Resolve soul context for this template, if assigned.
        final soulSvc = soulDocumentService;
        SoulDocumentVersionEntity? currentSoulVersion;
        var recentSoulVersions = <SoulDocumentVersionEntity>[];
        var otherTemplatesUsingSoul = <String>[];
        if (soulSvc != null) {
          currentSoulVersion = await soulSvc.resolveActiveSoulForTemplate(
            templateId,
          );
          resolvedSoulVersion = currentSoulVersion;
          if (currentSoulVersion != null) {
            final soulId = currentSoulVersion.agentId;
            recentSoulVersions = await soulSvc.getVersionHistory(soulId);
            final templateIds = await soulSvc.getTemplatesUsingSoul(soulId);
            // Exclude the current template from the cross-impact list.
            final otherIds = templateIds
                .where((id) => id != templateId)
                .toList();
            // Resolve display names for cross-template notice.
            final otherTemplates = await Future.wait(
              otherIds.map(svc.getTemplate),
            );
            otherTemplatesUsingSoul = otherTemplates
                .whereType<AgentTemplateEntity>()
                .map((t) => t.displayName)
                .toList();
          }
        }

        ctx = ctxBuilder.build(
          template: template,
          currentVersion: currentVersion,
          recentVersions: data.recentVersions,
          instanceReports: data.instanceReports,
          instanceObservations: data.instanceObservations,
          pastNotes: data.pastNotes,
          metrics: data.metrics,
          changesSinceLastSession: data.changesSinceLastSession,
          observationPayloads: data.observationPayloads,
          currentSoulVersion: currentSoulVersion,
          recentSoulVersions: recentSoulVersions,
          otherTemplatesUsingSoul: otherTemplatesUsingSoul,
        );
      }

      // Create the session entity, conversation, and send initial message.
      final now = clock.now();
      final session =
          AgentDomainEntity.evolutionSession(
                id: sessionId,
                agentId: templateId,
                templateId: templateId,
                sessionNumber: sessionNumber,
                status: EvolutionSessionStatus.active,
                createdAt: now,
                updatedAt: now,
                vectorClock: null,
              )
              as EvolutionSessionEntity;
      await sync.upsertEntity(session);

      // Set up GenUI infrastructure.
      final catalog = buildEvolutionCatalog();
      final processor = A2uiMessageProcessor(catalogs: [catalog]);
      final bridge = GenUiBridge(processor: processor);
      final eventHandler = GenUiEventHandler(processor: processor)..listen();

      // Resolve the active soul version for strategy's before/after comparison.
      // Reuse the version already resolved in the full path; only fetch fresh
      // when coming from the fast/optimized paths.
      final strategySoulVersion =
          resolvedSoulVersion ??
          await soulDocumentService?.resolveActiveSoulForTemplate(templateId);

      final strategy = EvolutionStrategy(
        genUiBridge: bridge,
        currentGeneralDirective: currentVersion.generalDirective,
        currentReportDirective: currentVersion.reportDirective,
        currentVoiceDirective: strategySoulVersion?.voiceDirective ?? '',
        currentToneBounds: strategySoulVersion?.toneBounds ?? '',
        currentCoachingStyle: strategySoulVersion?.coachingStyle ?? '',
        currentAntiSycophancyPolicy:
            strategySoulVersion?.antiSycophancyPolicy ?? '',
      );
      final conversationId = conversationRepository.createConversation(
        systemMessage: ctx.systemPrompt,
      );

      activeSessions[sessionId] = ActiveEvolutionSession(
        sessionId: sessionId,
        templateId: templateId,
        conversationId: conversationId,
        strategy: strategy,
        modelId: template.modelId,
        processor: processor,
        genUiBridge: bridge,
        eventHandler: eventHandler,
      );

      await conversationRepository.sendMessage(
        conversationId: conversationId,
        message: ctx.initialUserMessage,
        model: template.modelId,
        provider: provider,
        inferenceRepo: CloudInferenceWrapper(
          cloudRepository: cloudInferenceRepository,
        ),
        tools: _buildToolDefinitions(bridge: bridge),
        strategy: strategy,
      );

      _notifyUpdate(templateId);

      return _extractLastAssistantContent(conversationId);
    } catch (e, s) {
      developer.log(
        'Failed to start session',
        name: _logTag,
        error: e,
        stackTrace: s,
      );
      await abandonSession(sessionId: sessionId);
      return null;
    }
  }

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
      developer.log('No active session $sessionId', name: _logTag);
      return null;
    }

    final provider = await resolveInferenceProvider(
      modelId: active.modelId,
      aiConfigRepository: aiConfigRepository,
      logTag: _logTag,
    );
    if (provider == null) return null;

    try {
      await conversationRepository.sendMessage(
        conversationId: active.conversationId,
        message: userMessage,
        model: active.modelId,
        provider: provider,
        inferenceRepo: CloudInferenceWrapper(
          cloudRepository: cloudInferenceRepository,
        ),
        tools: _buildToolDefinitions(bridge: active.genUiBridge),
        strategy: active.strategy,
      );

      return _extractLastAssistantContent(active.conversationId);
    } catch (e, s) {
      developer.log(
        'sendMessage failed for session $sessionId',
        name: _logTag,
        error: e,
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
      developer.log('No proposal to approve for $sessionId', name: _logTag);
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
          '${active.templateId}',
          name: _logTag,
          error: e,
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
          'onSessionCompleted failed for $sessionId',
          name: _logTag,
          error: e,
          stackTrace: s,
        );
      }

      developer.log(
        'Approved proposal for session $sessionId → version ${newVersion.id}',
        name: _logTag,
      );

      return newVersion;
    } catch (e, s) {
      developer.log(
        'approveProposal failed for $sessionId',
        name: _logTag,
        error: e,
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
        'Rejected proposal for session $sessionId',
        name: _logTag,
      );
    }
  }

  /// Approve the current soul proposal, creating a new soul document version.
  ///
  /// Returns the created [SoulDocumentVersionEntity], or `null` if there is
  /// no active soul proposal or the soul service is unavailable.
  ///
  /// Does NOT complete the session — skill and soul proposals are independent.
  Future<SoulDocumentVersionEntity?> approveSoulProposal({
    required String sessionId,
  }) async {
    final active = activeSessions[sessionId];
    final soulSvc = soulDocumentService;
    if (active == null || soulSvc == null) return null;

    final proposal = active.strategy.latestSoulProposal;
    if (proposal == null) return null;

    // Resolve the soul assigned to this template.
    final currentSoulVersion = await soulSvc.resolveActiveSoulForTemplate(
      active.templateId,
    );
    if (currentSoulVersion == null) {
      developer.log(
        'No soul assigned to template ${active.templateId} — '
        'cannot approve soul proposal',
        name: _logTag,
      );
      return null;
    }

    final soulId = currentSoulVersion.agentId;
    final newVersion = await soulSvc.createVersion(
      soulId: soulId,
      voiceDirective: proposal.voiceDirective.trim().isNotEmpty
          ? proposal.voiceDirective
          : currentSoulVersion.voiceDirective,
      toneBounds: proposal.toneBounds.trim().isNotEmpty
          ? proposal.toneBounds
          : currentSoulVersion.toneBounds,
      coachingStyle: proposal.coachingStyle.trim().isNotEmpty
          ? proposal.coachingStyle
          : currentSoulVersion.coachingStyle,
      antiSycophancyPolicy: proposal.antiSycophancyPolicy.trim().isNotEmpty
          ? proposal.antiSycophancyPolicy
          : currentSoulVersion.antiSycophancyPolicy,
      authoredBy: AgentAuthors.evolutionAgent,
      sourceSessionId: sessionId,
    );

    active.strategy
      ..clearSoulProposal()
      // Refresh the strategy's baseline so any subsequent soul proposals in
      // this session show diffs against the newly approved values.
      ..currentVoiceDirective = newVersion.voiceDirective
      ..currentToneBounds = newVersion.toneBounds
      ..currentCoachingStyle = newVersion.coachingStyle
      ..currentAntiSycophancyPolicy = newVersion.antiSycophancyPolicy;

    developer.log(
      'Approved soul proposal for session $sessionId → '
      'soul version v${newVersion.version}',
      name: _logTag,
    );

    return newVersion;
  }

  /// Reject the current soul proposal, clearing it from the strategy.
  void rejectSoulProposal({required String sessionId}) {
    final active = activeSessions[sessionId];
    if (active == null) return;

    final hadProposal = active.strategy.latestSoulProposal != null;
    active.strategy.clearSoulProposal();

    if (hadProposal) {
      developer.log(
        'Rejected soul proposal for session $sessionId',
        name: _logTag,
      );
    }
  }

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
              error: e,
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

  // ── Multi-turn helpers ──────────────────────────────────────────────────────

  /// Marks any active evolution sessions for [templateId] as abandoned,
  /// excluding [currentSessionId]. This prevents stale sessions from
  /// lingering when a newer session starts or completes.
  Future<void> _abandonStaleActiveSessions({
    required String templateId,
    required String currentSessionId,
  }) async {
    final svc = templateService;
    final sync = syncService;
    if (svc == null || sync == null) return;

    final sessions = await svc.getEvolutionSessions(templateId);
    final now = clock.now();
    for (final session in sessions) {
      if (session.status == EvolutionSessionStatus.active &&
          session.id != currentSessionId) {
        await sync.upsertEntity(
          session.copyWith(
            status: EvolutionSessionStatus.abandoned,
            completedAt: now,
            updatedAt: now,
          ),
        );
        developer.log(
          'Auto-abandoned stale session ${session.id} '
          '(#${session.sessionNumber}) for template $templateId',
          name: _logTag,
        );
      }
    }
  }

  /// Persists pending notes one by one, draining each from the strategy
  /// *before* writing to guard against post-commit sync failures that would
  /// otherwise cause duplicate notes on retry. Notes are advisory, so losing
  /// one on a true pre-commit DB failure is acceptable; duplicating notes is
  /// not.
  Future<void> _persistNotes({
    required EvolutionStrategy strategy,
    required String templateId,
    required String sessionId,
    required AgentSyncService sync,
  }) async {
    final now = clock.now();
    for (
      var note = strategy.removeFirstNote();
      note != null;
      note = strategy.removeFirstNote()
    ) {
      final entity = AgentDomainEntity.evolutionNote(
        id: _uuid.v4(),
        agentId: templateId,
        sessionId: sessionId,
        kind: note.kind,
        content: note.content,
        createdAt: now,
        vectorClock: null,
      );
      await sync.upsertEntity(entity);
    }
  }

  /// Creates a template version, handling post-commit sync failures
  /// idempotently. If `createVersion` throws after the DB transaction has
  /// committed (e.g., outbox enqueue failure), the version exists in the DB
  /// but the caller never received it. This method detects that case by
  /// querying for the active version and checking its directives.
  Future<AgentTemplateVersionEntity> _createVersionIdempotent({
    required AgentTemplateService svc,
    required String templateId,
    required String generalDirective,
    required String reportDirective,
  }) async {
    try {
      return await svc.createVersion(
        templateId: templateId,
        directives: '$generalDirective\n\n$reportDirective'.trim(),
        generalDirective: generalDirective,
        reportDirective: reportDirective,
        authoredBy: AgentAuthors.evolutionAgent,
      );
    } catch (e) {
      // Check if the version was actually created despite the error
      // (post-commit sync failure).
      final activeVersion = await svc.getActiveVersion(templateId);
      if (activeVersion != null &&
          activeVersion.generalDirective == generalDirective &&
          activeVersion.reportDirective == reportDirective &&
          activeVersion.authoredBy == AgentAuthors.evolutionAgent) {
        developer.log(
          'createVersion threw but version was persisted, recovering',
          name: _logTag,
        );
        return activeVersion;
      }
      rethrow;
    }
  }

  Future<EvolutionSessionEntity?> _getSessionEntity(String sessionId) async {
    final svc = templateService;
    if (svc == null) return null;
    final entity = await svc.repository.getEntity(sessionId);
    return entity?.mapOrNull(evolutionSession: (s) => s);
  }

  String? _extractLastAssistantContent(String conversationId) {
    final manager = conversationRepository.getConversation(conversationId);
    if (manager == null) return null;

    for (final message in manager.messages.reversed) {
      if (message case ChatCompletionAssistantMessage(
        content: final content?,
      )) {
        if (content.isNotEmpty) return content;
      }
    }
    return null;
  }

  EvolutionSessionRecapEntity? _buildSessionRecapEntity({
    required ActiveEvolutionSession active,
    required PendingProposal proposal,
    required Map<String, int> categoryRatings,
  }) {
    final manager = conversationRepository.getConversation(
      active.conversationId,
    );
    final transcript = _snapshotTranscript(manager?.messages ?? const []);
    final structuredRecap = active.strategy.latestRecap;
    final recapMarkdown = structuredRecap?.content.trim() ?? '';
    final recapTldr = structuredRecap?.tldr.trim() ?? proposal.rationale.trim();
    final approvedChangeSummary = proposal.rationale.trim();

    if (recapMarkdown.isEmpty &&
        recapTldr.isEmpty &&
        approvedChangeSummary.isEmpty &&
        transcript.isEmpty) {
      return null;
    }

    return AgentDomainEntity.evolutionSessionRecap(
          id: evolutionSessionRecapId(active.sessionId),
          agentId: active.templateId,
          sessionId: active.sessionId,
          createdAt: clock.now(),
          vectorClock: null,
          tldr: recapTldr,
          recapMarkdown: recapMarkdown,
          categoryRatings: Map.unmodifiable(categoryRatings),
          transcript: transcript,
          approvedChangeSummary: approvedChangeSummary.isEmpty
              ? null
              : approvedChangeSummary,
        )
        as EvolutionSessionRecapEntity;
  }

  List<Map<String, String>> _snapshotTranscript(
    List<ChatCompletionMessage> messages,
  ) {
    final transcript = <Map<String, String>>[];
    for (final message in messages) {
      switch (message) {
        case ChatCompletionUserMessage(:final content):
          final text = ContentExtractionHelper.extractTextFromUserContent(
            content,
          ).trim();
          if (text.isNotEmpty) {
            transcript.add({'role': 'user', 'text': text});
          }
        case ChatCompletionAssistantMessage(content: final content?)
            when content.trim().isNotEmpty:
          transcript.add({'role': 'assistant', 'text': content.trim()});
        default:
          break;
      }
    }
    return transcript;
  }

  double? _averageCategoryRating(Map<String, int> ratings) {
    final values = ratings.values.where((rating) => rating > 0).toList();
    if (values.isEmpty) {
      return null;
    }
    final total = values.fold<int>(0, (sum, rating) => sum + rating);
    return total / values.length;
  }

  void _cleanupSession(String sessionId) {
    final active = activeSessions.remove(sessionId);
    if (active != null) {
      active.eventHandler?.dispose();
      active.processor?.dispose();
      conversationRepository.deleteConversation(active.conversationId);
    }
  }

  /// Fire an update notification so UI providers watching this template
  /// refresh. Includes [agentNotification] so global providers (e.g.
  /// `allEvolutionSessionsProvider`) also invalidate.
  /// No-op when [updateNotifications] is not set.
  void _notifyUpdate(String templateId) {
    updateNotifications?.notifyUiOnly({templateId, agentNotification});
  }

  /// Converts [AgentToolRegistry.evolutionAgentTools] to OpenAI-compatible
  /// [ChatCompletionTool] objects, including the GenUI render_surface tool.
  List<ChatCompletionTool> _buildToolDefinitions({GenUiBridge? bridge}) {
    final tools = AgentToolRegistry.evolutionAgentTools.map((def) {
      return ChatCompletionTool(
        type: ChatCompletionToolType.function,
        function: FunctionObject(
          name: def.name,
          description: def.description,
          parameters: def.parameters,
        ),
      );
    }).toList();

    if (bridge != null) {
      tools.add(bridge.toolDefinition);
    }

    return tools;
  }
}
