part of 'template_evolution_workflow.dart';

/// Multi-turn helpers for [TemplateEvolutionWorkflow]: stale-session cleanup,
/// note persistence, version creation, recap building and tool definitions.
/// Split from the main file for size.
extension TemplateEvolutionHelpers on TemplateEvolutionWorkflow {
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
          'Auto-abandoned stale session '
          '${DomainLogger.sanitizeId(session.id)} '
          '(#${session.sessionNumber}) for template '
          '${DomainLogger.sanitizeId(templateId)}',
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

  /// Soul session tool definitions — excludes `propose_directives`.
  List<ChatCompletionTool> _buildSoulToolDefinitions({GenUiBridge? bridge}) {
    final tools = AgentToolRegistry.soulEvolutionAgentTools.map((def) {
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

  EvolutionSessionRecapEntity? _buildSoulSessionRecapEntity({
    required ActiveEvolutionSession active,
    required PendingSoulProposal proposal,
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
}
