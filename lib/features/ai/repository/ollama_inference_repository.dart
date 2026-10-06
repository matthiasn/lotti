import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:lotti/classes/ai/ai_call_impact.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/features/ai/model/gemini_tool_call.dart';
import 'package:lotti/features/ai/repository/inference_repository_interface.dart';
import 'package:lotti/features/ai/repository/ollama_api_client.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/util/content_extraction_helper.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:openai_dart/openai_dart.dart';

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
  OllamaInferenceRepository({
    required this._domainLogger,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  /// Records chat requests here and in the [OllamaApiClient].
  final DomainLogger _domainLogger;
  late final OllamaApiClient _api = OllamaApiClient(
    httpClient: _httpClient,
    domainLogger: _domainLogger,
  );

  /// Generate text using Ollama's API
  ///
  /// This method handles the specific requirements for Ollama text generation:
  /// - Validates input parameters
  /// - Uses /api/chat endpoint when tools are provided (for function calling support)
  /// - Uses /api/generate endpoint for regular text generation
  /// - Handles Ollama-specific response format
  /// - Provides comprehensive error handling
  @override
  Stream<CreateChatCompletionStreamResponse> generateText({
    required String prompt,
    required String model,
    required double temperature,
    required String? systemMessage,
    required AiConfigInferenceProvider provider,
    int? maxCompletionTokens,
    List<ChatCompletionTool>? tools,
    ChatCompletionToolChoiceOption? toolChoice, // Ignored for Ollama
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
  Stream<CreateChatCompletionStreamResponse> generateTextWithMessages({
    required List<ChatCompletionMessage> messages,
    required String model,
    required double temperature,
    required AiConfigInferenceProvider provider,
    int? maxCompletionTokens,
    List<ChatCompletionTool>? tools,
    ChatCompletionToolChoiceOption? toolChoice, // Ignored for Ollama
    Map<String, String>? thoughtSignatures, // Ignored for Ollama
    ThoughtSignatureCollector? signatureCollector, // Ignored for Ollama
    int? turnIndex, // Ignored for Ollama
    InferenceImpactCollector? impactCollector, // Ignored for Ollama (no impact)
  }) {
    // Convert ChatCompletionMessage objects to Ollama format
    final ollamaMessages = messages.map((msg) {
      final content = msg.content;
      // The remaining non-null shape is a developer message's content union,
      // which is json_serializable throughout, so encoding it cannot fail.
      final contentStr = switch (content) {
        ChatCompletionUserMessageContent() =>
          ContentExtractionHelper.extractTextFromUserContent(content),
        String() => content,
        null => null,
        _ => jsonEncode(content),
      };

      // For tool responses, Ollama expects a different format
      if (msg.role == ChatCompletionMessageRole.tool) {
        return <String, dynamic>{
          'role': 'tool',
          'content': contentStr ?? '',
        };
      }

      return <String, dynamic>{
        'role': msg.role.name,
        'content': contentStr ?? '',
      };
    }).toList();

    // Convert tools to Ollama format if provided
    final ollamaTools = tools != null && tools.isNotEmpty
        ? tools
              .map(
                (tool) => {
                  'type': 'function',
                  'function': {
                    'name': tool.function.name,
                    'description': tool.function.description,
                    'parameters': tool.function.parameters ?? {},
                  },
                },
              )
              .toList()
        : null;

    final toolsLog = ollamaTools != null && tools != null
        ? ' with ${ollamaTools.length} tools: ${tools.map((t) => t.function.name).join(', ')}'
        : '';
    // Each message by role and size only, on one line rather than one each.
    final messagesLog = ollamaMessages
        .map((msg) => '${msg['role']}:${(msg['content'] as String).length}')
        .join(', ');
    _domainLogger.log(
      LogDomain.ai,
      'Preparing Ollama chat request for model: $model$toolsLog with '
      '${messages.length} messages (role:chars $messagesLog)',
      subDomain: 'OllamaInferenceRepository',
    );

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
  Stream<CreateChatCompletionStreamResponse> generateWithImages({
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
}
