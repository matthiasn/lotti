import 'dart:async';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/model/ai_call_impact.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/gemini_tool_call.dart';
import 'package:lotti/features/ai/model/inference.dart';
import 'package:lotti/features/ai/repository/inference_repository_interface.dart';
import 'package:lotti/features/ai/repository/ollama_api_client.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/util/content_extraction_helper.dart';

export 'package:lotti/features/ai/repository/ollama_api_client.dart'
    show ModelNotInstalledException, OllamaPullProgress;

/// Repository for Ollama-specific inference operations
///
/// This class handles all Ollama-related functionality including:
/// - Text generation with /api/generate endpoint
/// - Chat completion with /api/chat endpoint (supports function calling)
/// - Image analysis
/// - Model management (installation, checking, warm-up)
class OllamaInferenceRepository implements InferenceRepositoryInterface {
  OllamaInferenceRepository({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;
  late final OllamaApiClient _api = OllamaApiClient(httpClient: _httpClient);

  /// Generate text using Ollama's API
  ///
  /// This method handles the specific requirements for Ollama text generation:
  /// - Validates input parameters
  /// - Uses /api/chat endpoint when tools are provided (for function calling support)
  /// - Uses /api/generate endpoint for regular text generation
  /// - Handles Ollama-specific response format
  /// - Provides comprehensive error handling
  @override
  Stream<LottiInferenceChunk> generateText({
    required String prompt,
    required String model,
    required double temperature,
    required String? systemMessage,
    required AiConfigInferenceProvider provider,
    int? maxCompletionTokens,
    List<LottiTool>? tools,
    LottiToolChoice? toolChoice, // Ignored for Ollama
  }) {
    // Validate inputs
    _api.validateRequest(
      prompt: prompt,
      model: model,
      temperature: temperature,
      maxCompletionTokens: maxCompletionTokens,
    );

    // Always use chat endpoint for consistency
    return _api.generateTextWithChat(
      prompt: prompt,
      model: model,
      temperature: temperature,
      systemMessage: systemMessage,
      provider: provider,
      maxCompletionTokens: maxCompletionTokens,
      tools: tools,
    );
  }

  /// Generate text using Ollama's chat API with full conversation history
  ///
  /// This method accepts the full conversation messages for proper context.
  /// Note: Ollama doesn't support thought signatures, so those parameters are ignored.
  @override
  Stream<LottiInferenceChunk> generateTextWithMessages({
    required List<LottiMessage> messages,
    required String model,
    required double temperature,
    required AiConfigInferenceProvider provider,
    int? maxCompletionTokens,
    List<LottiTool>? tools,
    LottiToolChoice? toolChoice, // Ignored for Ollama
    Map<String, String>? thoughtSignatures, // Ignored for Ollama
    ThoughtSignatureCollector? signatureCollector, // Ignored for Ollama
    int? turnIndex, // Ignored for Ollama
    InferenceImpactCollector? impactCollector, // Ignored for Ollama (no impact)
  }) {
    // Convert LottiMessage objects to Ollama format
    final ollamaMessages = messages.map((msg) {
      final contentStr = switch (msg) {
        LottiSystemMessage(:final content) => content,
        LottiDeveloperMessage(:final content) => content,
        LottiUserMessage(:final content) =>
          ContentExtractionHelper.extractTextFromUserContent(content),
        // A tool-call-only assistant turn has no text to send.
        LottiAssistantMessage(:final content) => content ?? '',
        LottiToolMessage(:final content) => content,
      };

      return <String, dynamic>{'role': msg.role.name, 'content': contentStr};
    }).toList();

    // Convert tools to Ollama format if provided
    final ollamaTools = tools != null && tools.isNotEmpty
        ? tools
              .map(
                (tool) => {
                  'type': 'function',
                  'function': {
                    'name': tool.name,
                    'description': tool.description,
                    'parameters': tool.parameters ?? {},
                  },
                },
              )
              .toList()
        : null;

    final toolsLog = ollamaTools != null && tools != null
        ? ' with ${ollamaTools.length} tools: ${tools.map((t) => t.name).join(', ')}'
        : '';
    developer.log(
      'Preparing Ollama chat request for model: $model$toolsLog with ${messages.length} messages',
      name: 'OllamaInferenceRepository',
    );

    // Log the messages for debugging
    for (var i = 0; i < ollamaMessages.length; i++) {
      final msg = ollamaMessages[i];
      developer.log(
        'Message $i: role=${msg['role']}, content=${(msg['content'] as String).length > 100 ? '${(msg['content'] as String).substring(0, 100)}...' : msg['content']}',
        name: 'OllamaInferenceRepository',
      );
    }

    final requestBody = {
      'model': model,
      'messages': ollamaMessages,
      'stream': true,
      'tools': ollamaTools,
      'options': {
        'temperature': temperature,
        'num_predict': ?maxCompletionTokens,
      },
    };

    return _api.streamChatRequest(
      requestBody: requestBody,
      timeout: const Duration(seconds: ollamaDefaultTimeoutSeconds),
      retryContext: 'Ollama chat with full conversation',
      timeoutErrorMessage:
          'Request timed out after $ollamaDefaultTimeoutSeconds seconds. This can happen when the model is loading for the first time or is very large. Please try again - subsequent requests should be faster.',
      provider: provider,
      model: model,
    );
  }

  /// Image analysis. Thin delegator to [OllamaApiClient.generateWithImages]
  /// so the method remains a mockable class member.
  Stream<LottiInferenceChunk> generateWithImages({
    required String prompt,
    required String model,
    required double temperature,
    required List<String> images,
    required AiConfigInferenceProvider provider,
    int? maxCompletionTokens,
    String? systemMessage,
  }) => _api.generateWithImages(
    prompt: prompt,
    model: model,
    temperature: temperature,
    images: images,
    provider: provider,
    maxCompletionTokens: maxCompletionTokens,
    systemMessage: systemMessage,
  );

  /// Model installation. Thin delegator to [OllamaApiClient.installModel]
  /// (mockable class member).
  Stream<OllamaPullProgress> installModel(String modelName, String baseUrl) =>
      _api.installModel(modelName, baseUrl);

  /// Model warm-up. Thin delegator to [OllamaApiClient.warmUpModel]
  /// (mockable class member).
}
