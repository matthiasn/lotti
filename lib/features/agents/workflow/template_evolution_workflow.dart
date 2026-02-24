import 'dart:developer' as developer;

import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/template_performance_metrics.dart';
import 'package:lotti/features/agents/util/inference_provider_resolver.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_wrapper.dart';
import 'package:meta/meta.dart';
import 'package:openai_dart/openai_dart.dart';

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

/// Workflow that uses an LLM to propose improved template directives based on
/// performance metrics and user feedback.
class TemplateEvolutionWorkflow {
  TemplateEvolutionWorkflow({
    required this.conversationRepository,
    required this.aiConfigRepository,
    required this.cloudInferenceRepository,
  });

  final ConversationRepository conversationRepository;
  final AiConfigRepository aiConfigRepository;
  final CloudInferenceRepository cloudInferenceRepository;

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
