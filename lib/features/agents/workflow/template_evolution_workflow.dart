import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/template_performance_metrics.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/agents/util/inference_provider_resolver.dart';
import 'package:lotti/features/agents/workflow/evolution_context_builder.dart';
import 'package:lotti/features/agents/workflow/evolution_strategy.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_wrapper.dart';
import 'package:meta/meta.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:uuid/uuid.dart';

/// Structured feedback from the user about a template's performance.
class EvolutionFeedback {
  const EvolutionFeedback({
    this.enjoyed = '',
    this.didntWork = '',
    this.specificChanges = '',
  });

  final String enjoyed;
  final String didntWork;
  final String specificChanges;

  bool get isEmpty =>
      enjoyed.trim().isEmpty &&
      didntWork.trim().isEmpty &&
      specificChanges.trim().isEmpty;
}

/// A proposal for updated directives, ready for user approval.
class EvolutionProposal {
  const EvolutionProposal({
    required this.proposedDirectives,
    required this.originalDirectives,
  });

  final String proposedDirectives;
  final String originalDirectives;
}

/// Tracks in-memory state for an active evolution session.
class ActiveEvolutionSession {
  ActiveEvolutionSession({
    required this.sessionId,
    required this.templateId,
    required this.conversationId,
    required this.strategy,
    required this.modelId,
  });

  final String sessionId;
  final String templateId;
  final String conversationId;
  final EvolutionStrategy strategy;
  final String modelId;
}

/// Workflow that uses an LLM to propose improved template directives based on
/// performance metrics and user feedback.
///
/// Supports two modes:
/// - **Legacy single-turn**: [proposeEvolution] creates a one-shot conversation.
/// - **Multi-turn session**: [startSession] / [sendMessage] / [approveProposal]
///   enable a 1-on-1 dialogue with the evolution agent, with tool-based
///   proposals and notes.
class TemplateEvolutionWorkflow {
  TemplateEvolutionWorkflow({
    required this.conversationRepository,
    required this.aiConfigRepository,
    required this.cloudInferenceRepository,
    this.templateService,
    this.syncService,
    this.contextBuilder,
  });

  final ConversationRepository conversationRepository;
  final AiConfigRepository aiConfigRepository;
  final CloudInferenceRepository cloudInferenceRepository;

  /// Required for multi-turn sessions. Optional to preserve backwards compat.
  final AgentTemplateService? templateService;
  final AgentSyncService? syncService;
  final EvolutionContextBuilder? contextBuilder;

  static const _uuid = Uuid();
  static const _logTag = 'TemplateEvolutionWorkflow';

  /// Active sessions keyed by session entity ID.
  @visibleForTesting
  final activeSessions = <String, ActiveEvolutionSession>{};

  /// Propose evolved directives for a template.
  ///
  /// Creates a single-turn conversation with a meta-prompt instructing the LLM
  /// to rewrite the template's directives based on metrics and feedback.
  ///
  /// Returns `null` if the provider cannot be resolved or the LLM fails.
  Future<EvolutionProposal?> proposeEvolution({
    required AgentTemplateEntity template,
    required AgentTemplateVersionEntity currentVersion,
    required TemplatePerformanceMetrics metrics,
    required EvolutionFeedback feedback,
  }) async {
    final provider = await resolveInferenceProvider(
      modelId: template.modelId,
      aiConfigRepository: aiConfigRepository,
      logTag: 'TemplateEvolutionWorkflow',
    );
    if (provider == null) {
      developer.log(
        'Cannot resolve provider for model ${template.modelId}',
        name: 'TemplateEvolutionWorkflow',
      );
      return null;
    }

    final systemPrompt = _buildMetaPrompt();
    final userMessage = _buildUserMessage(
      template: template,
      currentVersion: currentVersion,
      metrics: metrics,
      feedback: feedback,
    );

    String? conversationId;
    try {
      conversationId = conversationRepository.createConversation(
        systemMessage: systemPrompt,
        maxTurns: 1,
      );

      final inferenceRepo = CloudInferenceWrapper(
        cloudRepository: cloudInferenceRepository,
      );

      await conversationRepository.sendMessage(
        conversationId: conversationId,
        message: userMessage,
        model: template.modelId,
        provider: provider,
        inferenceRepo: inferenceRepo,
      );

      final manager = conversationRepository.getConversation(conversationId);
      if (manager == null) return null;

      // Extract the last assistant content.
      String? proposedDirectives;
      for (final message in manager.messages.reversed) {
        if (message
            case ChatCompletionAssistantMessage(content: final content?)) {
          if (content.isNotEmpty) {
            proposedDirectives = content;
            break;
          }
        }
      }

      if (proposedDirectives == null || proposedDirectives.isEmpty) {
        return null;
      }

      // Strip markdown fences if the LLM wrapped the output.
      proposedDirectives = stripMarkdownFences(proposedDirectives).trim();
      if (proposedDirectives.isEmpty) return null;

      return EvolutionProposal(
        proposedDirectives: proposedDirectives,
        originalDirectives: currentVersion.directives,
      );
    } catch (e, s) {
      developer.log(
        'Evolution proposal failed',
        name: 'TemplateEvolutionWorkflow',
        error: e,
        stackTrace: s,
      );
      return null;
    } finally {
      if (conversationId != null) {
        conversationRepository.deleteConversation(conversationId);
      }
    }
  }

  String _buildMetaPrompt() {
    return '''
You are a prompt engineering specialist. Your task is to rewrite 
agent template directives based on performance data and user feedback.

RULES:
- Output ONLY the rewritten directives text. No explanations, no preamble.
- Preserve the agent's core identity and purpose.
- Incorporate user feedback to improve weak areas.
- Keep the same general length and structure unless changes are needed.
- Use clear, actionable language.
- Do not wrap your output in markdown code fences.''';
  }

  String _buildUserMessage({
    required AgentTemplateEntity template,
    required AgentTemplateVersionEntity currentVersion,
    required TemplatePerformanceMetrics metrics,
    required EvolutionFeedback feedback,
  }) {
    final buffer = StringBuffer()
      ..writeln('## Template: ${template.displayName}')
      ..writeln()
      ..writeln('### Current Directives')
      ..writeln(currentVersion.directives)
      ..writeln()
      ..writeln('### Performance Metrics')
      ..writeln('- Total wakes: ${metrics.totalWakes}')
      ..writeln(
        '- Success rate: ${(metrics.successRate * 100).toStringAsFixed(1)}%',
      )
      ..writeln('- Failures: ${metrics.failureCount}')
      ..writeln(
        '- Average duration: '
        '${metrics.averageDuration == null ? "N/A" : "${metrics.averageDuration!.inSeconds}s"}',
      )
      ..writeln('- Active instances: ${metrics.activeInstanceCount}')
      ..writeln()
      ..writeln('### User Feedback');

    if (feedback.enjoyed.trim().isNotEmpty) {
      buffer.writeln('**What worked well:** ${feedback.enjoyed}');
    }
    if (feedback.didntWork.trim().isNotEmpty) {
      buffer.writeln("**What didn't work:** ${feedback.didntWork}");
    }
    if (feedback.specificChanges.trim().isNotEmpty) {
      buffer.writeln('**Requested changes:** ${feedback.specificChanges}');
    }

    buffer
      ..writeln()
      ..writeln(
        'Rewrite the directives above, incorporating the feedback and '
        'optimizing for better performance. Output ONLY the new directives.',
      );

    return buffer.toString();
  }

  // ── Multi-turn session API ─────────────────────────────────────────────────

  /// Start a new multi-turn evolution session for [templateId].
  ///
  /// Gathers all context (metrics, reports, observations, notes, versions),
  /// creates an [EvolutionSessionEntity], starts the conversation, and sends
  /// the initial context message to the LLM. Returns the assistant's opening
  /// response, or `null` if setup fails.
  Future<String?> startSession({required String templateId}) async {
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

    // Gather evolution context data.
    final metrics = await svc.computeMetrics(templateId);
    final recentVersions = await svc.getVersionHistory(templateId, limit: 5);
    final reports = await svc.getRecentInstanceReports(templateId);
    final observations = await svc.getRecentInstanceObservations(templateId);
    final notes = await svc.getRecentEvolutionNotes(templateId);
    final sessions = await svc.getEvolutionSessions(templateId);

    // Determine delta since last session.
    final lastSessionDate =
        sessions.isNotEmpty ? sessions.first.createdAt : null;
    final changesSince =
        await svc.countChangesSince(templateId, lastSessionDate);

    // Build the LLM context.
    final ctx = ctxBuilder.build(
      template: template,
      currentVersion: currentVersion,
      recentVersions: recentVersions,
      instanceReports: reports,
      instanceObservations: observations,
      pastNotes: notes,
      metrics: metrics,
      changesSinceLastSession: changesSince,
    );

    // Determine session number.
    final sessionNumber = sessions.isNotEmpty
        ? sessions.map((s) => s.sessionNumber).reduce((a, b) => a > b ? a : b) +
            1
        : 1;

    // Create the session entity, conversation, and send initial message.
    // The entire setup is wrapped in try-catch so partial failures are cleaned
    // up via abandonSession.
    final sessionId = _uuid.v4();
    try {
      final now = clock.now();
      final session = AgentDomainEntity.evolutionSession(
        id: sessionId,
        agentId: templateId,
        templateId: templateId,
        sessionNumber: sessionNumber,
        status: EvolutionSessionStatus.active,
        createdAt: now,
        updatedAt: now,
        vectorClock: null,
      ) as EvolutionSessionEntity;
      await sync.upsertEntity(session);

      final strategy = EvolutionStrategy();
      final conversationId = conversationRepository.createConversation(
        systemMessage: ctx.systemPrompt,
      );

      activeSessions[sessionId] = ActiveEvolutionSession(
        sessionId: sessionId,
        templateId: templateId,
        conversationId: conversationId,
        strategy: strategy,
        modelId: template.modelId,
      );

      await conversationRepository.sendMessage(
        conversationId: conversationId,
        message: ctx.initialUserMessage,
        model: template.modelId,
        provider: provider,
        inferenceRepo: CloudInferenceWrapper(
          cloudRepository: cloudInferenceRepository,
        ),
        tools: _buildToolDefinitions(),
        strategy: strategy,
      );

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
        tools: _buildToolDefinitions(),
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

  /// Approve the current proposal: create a new template version, persist
  /// pending notes, and complete the session.
  ///
  /// Returns the created [AgentTemplateVersionEntity], or `null` on failure.
  Future<AgentTemplateVersionEntity?> approveProposal({
    required String sessionId,
    double? userRating,
    String? feedbackSummary,
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
      // Create the new template version.
      final newVersion = await svc.createVersion(
        templateId: active.templateId,
        directives: proposal.directives,
        authoredBy: 'evolution_agent',
      );

      // Persist pending notes.
      await _persistNotes(
        strategy: active.strategy,
        templateId: active.templateId,
        sessionId: sessionId,
        sync: sync,
      );

      // Complete the session entity.
      final now = clock.now();
      final sessionEntity = await _getSessionEntity(sessionId);
      if (sessionEntity != null) {
        await sync.upsertEntity(
          sessionEntity.copyWith(
            status: EvolutionSessionStatus.completed,
            proposedVersionId: newVersion.id,
            feedbackSummary: feedbackSummary,
            userRating: userRating,
            completedAt: now,
            updatedAt: now,
          ),
        );
      }

      // Clean up.
      _cleanupSession(sessionId);

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

    if (hadProposal) {
      developer.log(
        'Rejected proposal for session $sessionId',
        name: _logTag,
      );
    }
  }

  /// Abandon an active session, persisting any pending notes and marking the
  /// session as abandoned.
  Future<void> abandonSession({required String sessionId}) async {
    final active = activeSessions[sessionId];
    final sync = syncService;

    if (active != null && sync != null) {
      // Persist any notes accumulated during the session.
      await _persistNotes(
        strategy: active.strategy,
        templateId: active.templateId,
        sessionId: sessionId,
        sync: sync,
      );

      // Mark session as abandoned.
      final now = clock.now();
      final sessionEntity = await _getSessionEntity(sessionId);
      if (sessionEntity != null) {
        await sync.upsertEntity(
          sessionEntity.copyWith(
            status: EvolutionSessionStatus.abandoned,
            completedAt: now,
            updatedAt: now,
          ),
        );
      }
    }

    _cleanupSession(sessionId);
  }

  /// Get the active session for a template, if any.
  ActiveEvolutionSession? getActiveSessionForTemplate(String templateId) {
    for (final session in activeSessions.values) {
      if (session.templateId == templateId) return session;
    }
    return null;
  }

  // ── Multi-turn helpers ──────────────────────────────────────────────────────

  Future<void> _persistNotes({
    required EvolutionStrategy strategy,
    required String templateId,
    required String sessionId,
    required AgentSyncService sync,
  }) async {
    final now = clock.now();
    for (final note in strategy.pendingNotes) {
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
      if (message
          case ChatCompletionAssistantMessage(content: final content?)) {
        if (content.isNotEmpty) return content;
      }
    }
    return null;
  }

  void _cleanupSession(String sessionId) {
    final active = activeSessions.remove(sessionId);
    if (active != null) {
      conversationRepository.deleteConversation(active.conversationId);
    }
  }

  /// Converts [AgentToolRegistry.evolutionAgentTools] to OpenAI-compatible
  /// [ChatCompletionTool] objects.
  List<ChatCompletionTool> _buildToolDefinitions() {
    return AgentToolRegistry.evolutionAgentTools.map((def) {
      return ChatCompletionTool(
        type: ChatCompletionToolType.function,
        function: FunctionObject(
          name: def.name,
          description: def.description,
          parameters: def.parameters,
        ),
      );
    }).toList();
  }

  // ── Legacy single-turn helpers ──────────────────────────────────────────────

  /// Strips leading/trailing markdown code fences (``` or ```text) from the
  /// LLM output if present.
  @visibleForTesting
  static String stripMarkdownFences(String text) {
    var trimmed = text.trim();
    // Match opening fence: ```<optional language>
    final openPattern = RegExp(r'^```\w*\s*\n?');
    final closePattern = RegExp(r'\n?```\s*$');

    if (openPattern.hasMatch(trimmed) && closePattern.hasMatch(trimmed)) {
      trimmed = trimmed
          .replaceFirst(openPattern, '')
          .replaceFirst(closePattern, '')
          .trim();
    }
    return trimmed;
  }
}
