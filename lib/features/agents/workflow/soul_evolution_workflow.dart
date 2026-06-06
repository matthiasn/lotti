part of 'template_evolution_workflow.dart';

/// Standalone soul-session methods of [TemplateEvolutionWorkflow].
/// The class keeps thin delegators so mocktail mocks of the workflow
/// still intercept the public soul-session API.
extension SoulEvolutionWorkflow on TemplateEvolutionWorkflow {
  /// Approve the current soul proposal, creating a new soul document version.
  ///
  /// Returns the created [SoulDocumentVersionEntity], or `null` if there is
  /// no active soul proposal or the soul service is unavailable.
  ///
  /// Does NOT complete the session — skill and soul proposals are independent.
  Future<SoulDocumentVersionEntity?> approveSoulProposalImpl({
    required String sessionId,
  }) async {
    final active = activeSessions[sessionId];
    final soulSvc = soulDocumentService;
    if (active == null || soulSvc == null) return null;

    final proposal = active.strategy.latestSoulProposal;
    if (proposal == null) return null;

    try {
      // Resolve the soul assigned to this template.
      final currentSoulVersion = await soulSvc.resolveActiveSoulForTemplate(
        active.templateId,
      );
      if (currentSoulVersion == null) {
        developer.log(
          'No soul assigned to template '
          '${DomainLogger.sanitizeId(active.templateId)} — '
          'cannot approve soul proposal',
          name: TemplateEvolutionWorkflow._logTag,
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

      // Only mutate strategy state after createVersion succeeds, so the
      // proposal is preserved for retry on failure.
      active.strategy
        ..clearSoulProposal()
        ..currentVoiceDirective = newVersion.voiceDirective
        ..currentToneBounds = newVersion.toneBounds
        ..currentCoachingStyle = newVersion.coachingStyle
        ..currentAntiSycophancyPolicy = newVersion.antiSycophancyPolicy;

      developer.log(
        'Approved soul proposal for session '
        '${DomainLogger.sanitizeId(sessionId)} → '
        'soul version v${newVersion.version}',
        name: TemplateEvolutionWorkflow._logTag,
      );

      return newVersion;
    } catch (e, s) {
      developer.log(
        'approveSoulProposal failed for session '
        '${DomainLogger.sanitizeId(sessionId)}',
        name: TemplateEvolutionWorkflow._logTag,
        error: e.runtimeType,
        stackTrace: s,
      );
      return null;
    }
  }

  /// Reject the current soul proposal, clearing it from the strategy.
  void rejectSoulProposalImpl({required String sessionId}) {
    final active = activeSessions[sessionId];
    if (active == null) return;

    final hadProposal = active.strategy.latestSoulProposal != null;
    active.strategy.clearSoulProposal();

    if (hadProposal) {
      developer.log(
        'Rejected soul proposal for session '
        '${DomainLogger.sanitizeId(sessionId)}',
        name: TemplateEvolutionWorkflow._logTag,
      );
    }
  }

  /// Start a standalone soul evolution session for [soulId].
  ///
  /// Aggregates feedback from ALL templates sharing this soul, builds a
  /// personality-focused context, and starts the conversation. Returns the
  /// assistant's opening response, or `null` if setup fails.
  Future<String?> startSoulSessionImpl({required String soulId}) async {
    final soulSvc = soulDocumentService;
    final svc = templateService;
    final sync = syncService;
    final fbService = feedbackService;
    if (soulSvc == null || svc == null || sync == null) {
      developer.log(
        'soulDocumentService, templateService, and syncService are '
        'required for soul sessions',
        name: TemplateEvolutionWorkflow._logTag,
      );
      return null;
    }

    // Only one active session per soul at a time.
    if (getActiveSessionForSoul(soulId) != null) {
      developer.log(
        'Session already active for soul ${DomainLogger.sanitizeId(soulId)}',
        name: TemplateEvolutionWorkflow._logTag,
      );
      return null;
    }

    // Resolve soul document and active version.
    final soul = await soulSvc.getSoul(soulId);
    if (soul == null) {
      developer.log(
        'Soul ${DomainLogger.sanitizeId(soulId)} not found',
        name: TemplateEvolutionWorkflow._logTag,
      );
      return null;
    }

    final currentVersion = await soulSvc.getActiveSoulVersion(soulId);
    if (currentVersion == null) {
      developer.log(
        'No active version for soul ${DomainLogger.sanitizeId(soulId)}',
        name: TemplateEvolutionWorkflow._logTag,
      );
      return null;
    }

    // Use the first template's model for inference, or fall back.
    final templateIds = await soulSvc.getTemplatesUsingSoul(soulId);
    String? modelId;
    final affectedTemplates = <({String templateId, String displayName})>[];
    for (final templateId in templateIds) {
      final template = await svc.getTemplate(templateId);
      if (template != null) {
        modelId ??= template.modelId;
        affectedTemplates.add((
          templateId: templateId,
          displayName: template.displayName,
        ));
      }
    }

    if (modelId == null) {
      developer.log(
        'No templates using soul ${DomainLogger.sanitizeId(soulId)} — '
        'cannot determine model',
        name: TemplateEvolutionWorkflow._logTag,
      );
      return null;
    }

    final inferenceSlot = await resolveInferenceProviderWithModel(
      modelId: modelId,
      aiConfigRepository: this.aiConfigRepository,
      logTag: TemplateEvolutionWorkflow._logTag,
    );
    if (inferenceSlot == null) {
      developer.log(
        'Cannot resolve provider for soul-session model '
        '(modelIdLength=${modelId.length})',
        name: TemplateEvolutionWorkflow._logTag,
      );
      return null;
    }
    final provider = inferenceSlot.provider;
    final geminiThinkingMode = inferenceSlot.model.geminiThinkingMode;

    final sessionId = TemplateEvolutionWorkflow._uuid.v4();
    try {
      // Abandon stale sessions for this soul.
      await _abandonStaleActiveSessions(
        templateId: soulId,
        currentSessionId: sessionId,
      );

      // Gather soul version history.
      final recentVersions = await soulSvc.getVersionHistory(soulId);

      // Aggregate feedback across all templates.
      var feedbackByTemplate = <String, ClassifiedFeedback>{};
      if (fbService != null) {
        try {
          final now = clock.now();
          final since = now.subtract(const Duration(days: 7));
          feedbackByTemplate = await fbService.extractForSoul(
            soulId: soulId,
            since: since,
            until: now,
          );
        } catch (e, s) {
          developer.log(
            'Feedback aggregation failed for soul '
            '${DomainLogger.sanitizeId(soulId)}',
            name: TemplateEvolutionWorkflow._logTag,
            error: e.runtimeType,
            stackTrace: s,
          );
        }
      }

      // Gather past soul evolution notes.
      final pastNotes = await svc.getRecentEvolutionNotes(soulId);

      // Compute session number.
      final existingSessions = await svc.getEvolutionSessions(soulId);
      final sessionNumber =
          existingSessions.fold(
            0,
            (max, s) => s.sessionNumber > max ? s.sessionNumber : max,
          ) +
          1;

      // Build soul-focused context.
      final ctx = SoulEvolutionContextBuilder().build(
        soul: soul,
        currentVersion: currentVersion,
        recentVersions: recentVersions,
        affectedTemplates: affectedTemplates,
        feedbackByTemplate: feedbackByTemplate,
        pastNotes: pastNotes,
        sessionNumber: sessionNumber,
      );

      // Create session entity with agentId=soulId, templateId=soulId.
      final now = clock.now();
      final session =
          AgentDomainEntity.evolutionSession(
                id: sessionId,
                agentId: soulId,
                templateId: soulId,
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
      final processor = SurfaceController(catalogs: [catalog]);
      final bridge = GenUiBridge(processor: processor);
      final eventHandler = GenUiEventHandler(processor: processor)..listen();

      // Strategy with soul fields populated, no template directives.
      final strategy = EvolutionStrategy(
        genUiBridge: bridge,
        currentVoiceDirective: currentVersion.voiceDirective,
        currentToneBounds: currentVersion.toneBounds,
        currentCoachingStyle: currentVersion.coachingStyle,
        currentAntiSycophancyPolicy: currentVersion.antiSycophancyPolicy,
      );

      final conversationId = conversationRepository.createConversation(
        systemMessage: ctx.systemPrompt,
      );

      activeSessions[sessionId] = ActiveEvolutionSession(
        sessionId: sessionId,
        templateId: soulId,
        conversationId: conversationId,
        strategy: strategy,
        modelId: modelId,
        geminiThinkingMode: geminiThinkingMode,
        processor: processor,
        genUiBridge: bridge,
        eventHandler: eventHandler,
      );

      // Soul sessions only get soul tools (no propose_directives).
      await conversationRepository.sendMessage(
        conversationId: conversationId,
        message: ctx.initialUserMessage,
        model: modelId,
        provider: provider,
        inferenceRepo: CloudInferenceWrapper(
          cloudRepository: this.cloudInferenceRepository,
          geminiThinkingMode: geminiThinkingMode,
        ),
        tools: _buildSoulToolDefinitions(bridge: bridge),
        strategy: strategy,
      );

      _notifyUpdate(soulId);

      return _extractLastAssistantContent(conversationId);
    } catch (e, s) {
      developer.log(
        'Failed to start soul session',
        name: TemplateEvolutionWorkflow._logTag,
        error: e.runtimeType,
        stackTrace: s,
      );
      await abandonSession(sessionId: sessionId);
      return null;
    }
  }

  /// Complete a standalone soul session by approving the soul proposal.
  ///
  /// Creates a new [SoulDocumentVersionEntity], persists notes and recap,
  /// completes the session entity. Returns the new version, or `null`.
  Future<SoulDocumentVersionEntity?> completeSoulSessionImpl({
    required String sessionId,
    Map<String, int> categoryRatings = const {},
  }) async {
    final active = activeSessions[sessionId];
    final soulSvc = soulDocumentService;
    final sync = syncService;
    if (active == null || soulSvc == null || sync == null) return null;

    final proposal = active.strategy.latestSoulProposal;
    if (proposal == null) {
      developer.log(
        'No soul proposal to approve for '
        '${DomainLogger.sanitizeId(sessionId)}',
        name: TemplateEvolutionWorkflow._logTag,
      );
      return null;
    }

    try {
      final soulId =
          active.templateId; // templateId == soulId for soul sessions

      // Resolve current soul version to fill in unchanged fields.
      final currentVersion = await soulSvc.getActiveSoulVersion(soulId);
      if (currentVersion == null) {
        developer.log(
          'No active soul version for ${DomainLogger.sanitizeId(soulId)}',
          name: TemplateEvolutionWorkflow._logTag,
        );
        return null;
      }

      final newVersion = await soulSvc.createVersion(
        soulId: soulId,
        voiceDirective: proposal.voiceDirective.trim().isNotEmpty
            ? proposal.voiceDirective
            : currentVersion.voiceDirective,
        toneBounds: proposal.toneBounds.trim().isNotEmpty
            ? proposal.toneBounds
            : currentVersion.toneBounds,
        coachingStyle: proposal.coachingStyle.trim().isNotEmpty
            ? proposal.coachingStyle
            : currentVersion.coachingStyle,
        antiSycophancyPolicy: proposal.antiSycophancyPolicy.trim().isNotEmpty
            ? proposal.antiSycophancyPolicy
            : currentVersion.antiSycophancyPolicy,
        authoredBy: AgentAuthors.evolutionAgent,
        sourceSessionId: sessionId,
      );

      // Persist notes.
      await _persistNotes(
        strategy: active.strategy,
        templateId: soulId,
        sessionId: sessionId,
        sync: sync,
      );

      // Build and persist recap.
      final recap = _buildSoulSessionRecapEntity(
        active: active,
        proposal: proposal,
        categoryRatings: categoryRatings,
      );
      if (recap != null) {
        await sync.upsertEntity(recap);
      }

      // Complete session entity.
      final now = clock.now();
      final sessionEntity = await _getSessionEntity(sessionId);
      if (sessionEntity != null) {
        final normalizedRating = _averageCategoryRating(categoryRatings);
        final recapTldr = recap?.tldr.trim();
        final normalizedSummary = (recapTldr != null && recapTldr.isNotEmpty)
            ? recapTldr
            : proposal.rationale;
        await sync.upsertEntity(
          sessionEntity.copyWith(
            status: EvolutionSessionStatus.completed,
            proposedSoulVersionId: newVersion.id,
            feedbackSummary: normalizedSummary,
            userRating: normalizedRating,
            completedAt: now,
            updatedAt: now,
          ),
        );
      }

      // Clear strategy state.
      active.strategy
        ..clearSoulProposal()
        ..currentVoiceDirective = newVersion.voiceDirective
        ..currentToneBounds = newVersion.toneBounds
        ..currentCoachingStyle = newVersion.coachingStyle
        ..currentAntiSycophancyPolicy = newVersion.antiSycophancyPolicy;

      _cleanupSession(sessionId);
      _notifyUpdate(soulId);

      try {
        onSessionCompleted?.call(soulId, sessionId);
      } catch (e, s) {
        developer.log(
          'onSessionCompleted failed for soul session '
          '${DomainLogger.sanitizeId(sessionId)}',
          name: TemplateEvolutionWorkflow._logTag,
          error: e.runtimeType,
          stackTrace: s,
        );
      }

      developer.log(
        'Completed soul session ${DomainLogger.sanitizeId(sessionId)} → '
        'version v${newVersion.version}',
        name: TemplateEvolutionWorkflow._logTag,
      );

      return newVersion;
    } catch (e, s) {
      developer.log(
        'completeSoulSession failed for '
        '${DomainLogger.sanitizeId(sessionId)}',
        name: TemplateEvolutionWorkflow._logTag,
        error: e.runtimeType,
        stackTrace: s,
      );
      return null;
    }
  }
}
