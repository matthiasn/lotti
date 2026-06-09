part of 'template_evolution_workflow.dart';

/// Session bootstrap for [TemplateEvolutionWorkflow]: gathers context and
/// opens a multi-turn evolution session. Split from the main file for size.
extension TemplateEvolutionSession on TemplateEvolutionWorkflow {
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
        'Session already active for template '
        '${DomainLogger.sanitizeId(templateId)}',
        name: _logTag,
      );
      return null;
    }

    // Fetch template and active version.
    final template = await svc.getTemplate(templateId);
    if (template == null) {
      developer.log(
        'Template ${DomainLogger.sanitizeId(templateId)} not found',
        name: _logTag,
      );
      return null;
    }

    final currentVersion = await svc.getActiveVersion(templateId);
    if (currentVersion == null) {
      developer.log(
        'No active version for template '
        '${DomainLogger.sanitizeId(templateId)}',
        name: _logTag,
      );
      return null;
    }

    // Resolve the inference provider.
    final inferenceSlot = await resolveInferenceProviderWithModel(
      modelId: template.modelId,
      aiConfigRepository: this.aiConfigRepository,
      logTag: _logTag,
    );
    if (inferenceSlot == null) {
      developer.log(
        'Cannot resolve provider for template model '
        '(modelIdLength=${template.modelId.length})',
        name: _logTag,
      );
      return null;
    }
    final provider = inferenceSlot.provider;
    final geminiThinkingMode = inferenceSlot.model.geminiThinkingMode;

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
        // Wrapped in try/catch so soul service failures don't prevent the
        // session from starting — soul enrichment is best-effort.
        final soulSvc = soulDocumentService;
        SoulDocumentVersionEntity? currentSoulVersion;
        var recentSoulVersions = <SoulDocumentVersionEntity>[];
        var otherTemplatesUsingSoul = <String>[];
        if (soulSvc != null) {
          try {
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
          } catch (e, s) {
            developer.log(
              'Soul enrichment failed for template '
              '${DomainLogger.sanitizeId(templateId)}',
              name: _logTag,
              error: e.runtimeType,
              stackTrace: s,
            );
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
      final processor = SurfaceController(catalogs: [catalog]);
      final bridge = GenUiBridge(processor: processor);
      final eventHandler = GenUiEventHandler(processor: processor)..listen();

      // Resolve the active soul version for strategy's before/after comparison.
      // Reuse the version already resolved in the full path; only fetch fresh
      // when coming from the fast/optimized paths.
      var strategySoulVersion = resolvedSoulVersion;
      if (strategySoulVersion == null && soulDocumentService != null) {
        try {
          strategySoulVersion = await soulDocumentService!
              .resolveActiveSoulForTemplate(
                templateId,
              );
        } catch (e, s) {
          developer.log(
            'Soul resolution for strategy failed for template '
            '${DomainLogger.sanitizeId(templateId)}',
            name: _logTag,
            error: e.runtimeType,
            stackTrace: s,
          );
        }
      }

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
        geminiThinkingMode: geminiThinkingMode,
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
          cloudRepository: this.cloudInferenceRepository,
          geminiThinkingMode: geminiThinkingMode,
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
        error: e.runtimeType,
        stackTrace: s,
      );
      await abandonSession(sessionId: sessionId);
      return null;
    }
  }
}
