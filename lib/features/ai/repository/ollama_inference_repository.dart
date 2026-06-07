import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/model/ai_chat_message.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/gemini_tool_call.dart';
import 'package:lotti/features/ai/repository/inference_repository_interface.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/util/content_extraction_helper.dart';

part 'ollama_image_analysis.dart';
part 'ollama_model_management.dart';

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

  /// Base delay used for exponential backoff between retry attempts.
  ///
  /// Tests may override this to `Duration.zero` to avoid consuming real time
  /// while keeping retry logic intact. Production code should use the default.
  static Duration retryBaseDelay = const Duration(seconds: 2);

  /// Model prefix for Gemma 4 family (supports thinking mode).
  static const String _gemma4Prefix = 'gemma4';

  /// Returns true if the model supports Ollama's thinking mode.
  ///
  /// When enabled, Ollama returns chain-of-thought reasoning in a separate
  /// `thinking` field. We wrap this in `<think>` tags so the downstream
  /// response parser can extract it (same format as Gemini/OpenAI thinking).
  static bool shouldEnableThinking(String model) {
    return model.startsWith(_gemma4Prefix);
  }

  /// Creates a single-choice stream chunk with the given [content].
  ///
  /// Uses [DateTime.now().microsecondsSinceEpoch] for the id so chunks
  /// emitted within the same millisecond still receive distinct ids.
  static AiStreamChunk _contentChunk(String content) {
    final now = DateTime.now();
    return AiStreamChunk(
      id: '$ollamaResponseIdPrefix${now.microsecondsSinceEpoch}',
      choices: [
        AiStreamChoice(index: 0, delta: AiStreamDelta(content: content)),
      ],
      created: now.millisecondsSinceEpoch ~/ 1000,
    );
  }

  /// Generate text using Ollama's API
  ///
  /// This method handles the specific requirements for Ollama text generation:
  /// - Validates input parameters
  /// - Uses /api/chat endpoint when tools are provided (for function calling support)
  /// - Uses /api/generate endpoint for regular text generation
  /// - Handles Ollama-specific response format
  /// - Provides comprehensive error handling
  @override
  Stream<AiStreamChunk> generateText({
    required String prompt,
    required String model,
    required double temperature,
    required String? systemMessage,
    required AiConfigInferenceProvider provider,
    int? maxCompletionTokens,
    List<AiTool>? tools,
    AiToolChoice? toolChoice, // Ignored for Ollama
  }) {
    // Validate inputs
    _validateOllamaRequest(
      prompt: prompt,
      model: model,
      temperature: temperature,
      maxCompletionTokens: maxCompletionTokens,
    );

    // Always use chat endpoint for consistency
    return _generateTextWithChat(
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
  Stream<AiStreamChunk> generateTextWithMessages({
    required List<AiChatMessage> messages,
    required String model,
    required double temperature,
    required AiConfigInferenceProvider provider,
    int? maxCompletionTokens,
    List<AiTool>? tools,
    AiToolChoice? toolChoice, // Ignored for Ollama
    Map<String, String>? thoughtSignatures, // Ignored for Ollama
    ThoughtSignatureCollector? signatureCollector, // Ignored for Ollama
    int? turnIndex, // Ignored for Ollama
  }) {
    // Resolve tool_call id → function name from prior assistant turns so that
    // AiToolResultMessage entries can supply the `tool_name` Ollama expects.
    // Ollama has no `tool_call_id` field — results are matched to calls
    // positionally via the function name. See
    // https://docs.ollama.com/capabilities/tool-calling
    final toolCallIdToName = <String, String>{
      for (final m in messages.whereType<AiAssistantMessage>())
        if (m.toolCalls != null)
          for (final tc in m.toolCalls!) tc.id: tc.name,
    };

    final ollamaMessages = messages.map((msg) {
      if (msg case AiToolResultMessage(:final toolCallId, :final content)) {
        // Ollama has no `tool_call_id`; results are matched to calls by
        // function name. Bailing out loudly here is the right call —
        // sending the raw `toolCallId` as `tool_name` (or an empty string)
        // would silently corrupt the history and break follow-up turns.
        final toolName = toolCallIdToName[toolCallId];
        if (toolName == null) {
          throw StateError(
            'Missing preceding assistant tool call for Ollama tool result: '
            '$toolCallId',
          );
        }
        return <String, dynamic>{
          'role': 'tool',
          'tool_name': toolName,
          'content': content,
        };
      }

      return switch (msg) {
        AiSystemMessage(:final content) => <String, dynamic>{
          'role': 'system',
          'content': content,
        },
        AiUserMessage(:final content) => <String, dynamic>{
          'role': 'user',
          'content': ContentExtractionHelper.extractTextFromUserContent(
            content,
          ),
        },
        AiAssistantMessage(:final content, :final toolCalls) =>
          <String, dynamic>{
            'role': 'assistant',
            'content': content ?? '',
            if (toolCalls != null && toolCalls.isNotEmpty)
              'tool_calls': toolCalls
                  .map(
                    (tc) => {
                      'type': 'function',
                      'function': {'name': tc.name, 'arguments': tc.arguments},
                    },
                  )
                  .toList(),
          },
        // AiToolResultMessage handled by the `if case` guard above.
        // coverage:ignore-start
        AiToolResultMessage() => throw StateError('unreachable'),
        // coverage:ignore-end
      };
    }).toList();

    final ollamaTools = tools != null && tools.isNotEmpty
        ? tools
              .map(
                (tool) => {
                  'type': 'function',
                  'function': {
                    'name': tool.name,
                    'description': tool.description,
                    'parameters': tool.parameters,
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

    return _streamChatRequest(
      requestBody: requestBody,
      timeout: const Duration(seconds: ollamaDefaultTimeoutSeconds),
      retryContext: 'Ollama chat with full conversation',
      timeoutErrorMessage:
          'Request timed out after $ollamaDefaultTimeoutSeconds seconds. This can happen when the model is loading for the first time or is very large. Please try again - subsequent requests should be faster.',
      provider: provider,
      model: model,
    );
  }

  /// Generate text using Ollama's unified chat API
  ///
  /// This method uses the /api/chat endpoint for all text generation,
  /// with optional tool support for models that have function calling capabilities.
  Stream<AiStreamChunk> _generateTextWithChat({
    required String prompt,
    required String model,
    required double temperature,
    required AiConfigInferenceProvider provider,
    List<AiTool>? tools,
    String? systemMessage,
    int? maxCompletionTokens,
  }) {
    final ollamaTools = tools != null && tools.isNotEmpty
        ? tools
              .map(
                (tool) => {
                  'type': 'function',
                  'function': {
                    'name': tool.name,
                    'description': tool.description,
                    'parameters': tool.parameters,
                  },
                },
              )
              .toList()
        : null;

    final toolsLog = ollamaTools != null && tools != null
        ? ' with ${ollamaTools.length} tools: ${tools.map((t) => t.name).join(', ')}'
        : '';
    developer.log(
      'Preparing Ollama chat request for model: $model$toolsLog',
      name: 'OllamaInferenceRepository',
    );

    // Build messages array
    final messages = <Map<String, dynamic>>[];
    if (systemMessage != null) {
      messages.add({
        'role': 'system',
        'content': systemMessage,
      });
    }
    messages.add({
      'role': 'user',
      'content': prompt,
    });

    final requestBody = {
      'model': model,
      'messages': messages,
      'stream': true, // Use streaming for chat endpoint
      'tools': ollamaTools,
      'options': {
        'temperature': temperature,
        'num_predict': ?maxCompletionTokens,
      },
    };

    return _streamChatRequest(
      requestBody: requestBody,
      timeout: const Duration(seconds: ollamaDefaultTimeoutSeconds),
      retryContext: 'Ollama chat with tools',
      timeoutErrorMessage:
          'Request timed out after $ollamaDefaultTimeoutSeconds seconds. This can happen when the model is loading for the first time or is very large. Please try again - subsequent requests should be faster.',
      provider: provider,
      model: model,
    );
  }

  /// Stream Ollama chat API responses (supports function calling)
  Stream<AiStreamChunk> _streamChatRequest({
    required Map<String, dynamic> requestBody,
    required Duration timeout,
    required String retryContext,
    required String timeoutErrorMessage,
    required AiConfigInferenceProvider provider,
    String? model,
  }) async* {
    // Enable thinking mode for supported models
    if (model != null && shouldEnableThinking(model)) {
      requestBody['think'] = true;
    }

    try {
      final request = await _retryWithExponentialBackoff(
        operation: () => _httpClient
            .send(
              http.Request('POST', Uri.parse('${provider.baseUrl}/api/chat'))
                ..headers['Content-Type'] = ollamaContentType
                ..body = jsonEncode(requestBody),
            )
            .timeout(timeout),
        maxRetries: 3,
        baseDelay: retryBaseDelay,
        context: retryContext,
        timeoutErrorMessage: timeoutErrorMessage,
        networkErrorMessage:
            'Network error during $retryContext. Please check your connection and that the Ollama server is running.',
      );

      if (request.statusCode != httpStatusOk) {
        final responseBody = await request.stream.bytesToString();
        if (request.statusCode == httpStatusNotFound &&
            responseBody.contains('not found') &&
            responseBody.contains('model')) {
          throw ModelNotInstalledException(model ?? 'unknown');
        }
        developer.log(
          'Ollama chat API error: Status ${request.statusCode}, Body: $responseBody',
          name: 'OllamaInferenceRepository',
        );
        developer.log(
          'Request body was: ${jsonEncode(requestBody)}',
          name: 'OllamaInferenceRepository',
        );
        throw Exception(
          'Ollama chat API request failed with status ${request.statusCode}: $responseBody',
        );
      }

      // Running counter for tool calls that have no explicit index.
      var toolCallCounter = 0;

      // Maps raw Ollama indices to dense 0-based indices. Downstream code
      // treats the index as an array position, so sparse values (e.g. 5, 7)
      // would break merging.
      final indexRemap = <int, int>{};

      // Maps tool-call IDs to their assigned dense index so that
      // continuation chunks (which may omit `index`) merge correctly.
      final idToIndex = <String, int>{};

      // Tracks whether we are inside a thinking block so we can wrap
      // Ollama's `thinking` field content in `<think>...</think>` tags,
      // matching the format used by Gemini and OpenAI reasoning models.
      var inThinking = false;

      // Process streaming response
      await for (final chunk
          in request.stream
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        if (chunk.isEmpty) continue;

        try {
          final json = jsonDecode(chunk) as Map<String, dynamic>;

          // Cast message once to avoid dynamic calls
          final message = json['message'] as Map<String, dynamic>?;

          // Check if this is a tool call response
          if (message != null) {
            // Capture thinking content wrapped in <think> tags for
            // consistent downstream parsing across all providers.
            // Use a defensive toString() so unexpected non-string payloads
            // (e.g. null inside a nested object) do not crash the stream.
            //
            // We do NOT `continue` after emitting thinking: a single chunk
            // can carry `thinking` together with `content`, `tool_calls`,
            // or `done: true`. Falling through lets the same chunk close
            // the thinking block, yield content/tool_calls, and trigger
            // usage extraction below.
            if (message['thinking'] != null) {
              final thinking = message['thinking']?.toString() ?? '';
              if (thinking.isNotEmpty) {
                final prefix = inThinking ? '' : '<think>';
                inThinking = true;
                yield _contentChunk('$prefix$thinking');
              }
            }

            // Close the thinking block only when we are about to yield
            // real content or tool calls. Intermediate metadata-only
            // chunks (no thinking, content, or tool_calls) must not flip
            // `inThinking` off, otherwise a subsequent thinking chunk
            // would reopen the block and produce malformed nesting.
            final hasOutput =
                message['tool_calls'] != null || message['content'] != null;
            if (inThinking && hasOutput) {
              inThinking = false;
              yield _contentChunk('</think>');
            }

            if (message['tool_calls'] != null) {
              final toolCalls = message['tool_calls'] as List<dynamic>;

              // Convert Ollama tool calls to OpenAI format
              // We need to create a response that mimics OpenAI's streaming format
              // Since Ollama returns complete tool calls, we'll convert them to the expected format
              final toolCallsList = <dynamic>[];
              for (var i = 0; i < toolCalls.length; i++) {
                final toolCall = toolCalls[i] as Map<String, dynamic>;
                final functionCall =
                    toolCall['function'] as Map<String, dynamic>;

                // Create a dynamic object that matches the expected structure
                // Check if arguments are already a string (JSON-encoded) or need encoding
                final arguments = functionCall['arguments'];
                final argumentsStr = arguments is String
                    ? arguments
                    : jsonEncode(arguments);

                developer.log(
                  'Tool call: ${functionCall['name']} '
                  '(args type: ${arguments.runtimeType}, '
                  '${argumentsStr.length} chars)',
                  name: 'OllamaInferenceRepository',
                );

                // Resolve a stable dense index for this tool call.
                //
                // Priority:
                // 1. If we've seen this id before, reuse its dense index
                //    (handles continuation chunks that omit index).
                // 2. Explicit index from Ollama (tool-call or function level),
                //    remapped to dense 0-based.
                // 3. Running counter for calls with neither id nor index.
                final toolId = toolCall['id'] as String?;
                final explicitIndex =
                    (toolCall['index'] as int?) ??
                    (functionCall['index'] as int?);

                int denseIndex;
                if (toolId != null && idToIndex.containsKey(toolId)) {
                  denseIndex = idToIndex[toolId]!;
                } else if (explicitIndex != null) {
                  denseIndex = indexRemap.putIfAbsent(
                    explicitIndex,
                    () => indexRemap.length,
                  );
                } else {
                  denseIndex = indexRemap.putIfAbsent(
                    toolCallCounter,
                    () => indexRemap.length,
                  );
                  toolCallCounter++;
                }

                if (toolId != null) {
                  idToIndex[toolId] = denseIndex;
                }
                toolCallsList.add({
                  'index': denseIndex,
                  if (toolCall['id'] != null) 'id': toolCall['id'],
                  'type': 'function',
                  'function': {
                    'name': functionCall['name'],
                    'arguments': argumentsStr,
                  },
                });
              }

              // Create the response with tool calls
              // We'll emit this as a single chunk containing all tool calls.
              final toolNow = DateTime.now();
              final toolCallChunks = toolCallsList.map((tc) {
                final map = tc as Map<String, dynamic>;
                final fn = map['function'] as Map<String, dynamic>;
                return AiToolCallChunk(
                  index: map['index'] as int?,
                  id: map['id'] as String?,
                  name: fn['name'] as String?,
                  arguments: fn['arguments'] as String?,
                );
              }).toList();
              yield AiStreamChunk(
                id: '$ollamaResponseIdPrefix${toolNow.microsecondsSinceEpoch}',
                choices: [
                  AiStreamChoice(
                    index: 0,
                    delta: AiStreamDelta(toolCalls: toolCallChunks),
                  ),
                ],
                created: toolNow.millisecondsSinceEpoch ~/ 1000,
              );
            } else if (message['content'] != null) {
              // Regular content response
              final frag = message['content'] as String;
              final contentNow = DateTime.now();
              yield AiStreamChunk(
                id: '$ollamaResponseIdPrefix${contentNow.microsecondsSinceEpoch}',
                choices: [
                  AiStreamChoice(
                    index: 0,
                    delta: AiStreamDelta(content: frag),
                  ),
                ],
                created: contentNow.millisecondsSinceEpoch ~/ 1000,
              );
            }
          }

          // Check if done — extract usage from the final chunk.
          // Safety: close any unclosed thinking block before finishing.
          if (json['done'] == true && inThinking) {
            inThinking = false;
            yield _contentChunk('</think>');
          }
          if (json['done'] == true) {
            developer.log(
              'Ollama done response: $chunk',
              name: 'OllamaInferenceRepository',
            );
            // Ollama reports token counts in the final response:
            // prompt_eval_count → input tokens, eval_count → output tokens.
            final promptEval = json['prompt_eval_count'];
            final evalCount = json['eval_count'];
            if (promptEval is int || evalCount is int) {
              final prompt = promptEval is int ? promptEval : 0;
              final completion = evalCount is int ? evalCount : 0;
              final usageNow = DateTime.now();
              yield AiStreamChunk(
                id: '$ollamaResponseIdPrefix${usageNow.microsecondsSinceEpoch}',
                choices: const [],
                created: usageNow.millisecondsSinceEpoch ~/ 1000,
                usage: AiUsage(
                  promptTokens: prompt,
                  completionTokens: completion,
                  totalTokens: prompt + completion,
                ),
              );
            }
            break;
          }
        } catch (e) {
          developer.log(
            'Error parsing Ollama chat response chunk: $chunk',
            error: e,
            name: 'OllamaInferenceRepository',
          );
        }
      }
    } catch (e) {
      if (e is ModelNotInstalledException) {
        rethrow;
      }
      if (e.toString().contains('not found') &&
          e.toString().contains('model')) {
        throw ModelNotInstalledException(model ?? 'unknown');
      }
      rethrow;
    }
  }

  /// Shared helper method for making Ollama API requests with /api/generate endpoint
  ///
  /// This method handles the common logic for making requests to Ollama's API:
  /// - Making HTTP requests with retry logic
  /// - Handling response parsing and validation
  /// - Creating standardized stream responses
  /// - Error handling and timeout management

  /// Helper for retrying an async operation with exponential backoff on TimeoutException and SocketException
  Future<T> _retryWithExponentialBackoff<T>({
    required Future<T> Function() operation,
    required int maxRetries,
    required Duration baseDelay,
    required String context,
    required String timeoutErrorMessage,
    required String networkErrorMessage,
  }) async {
    var attempt = 0;
    while (true) {
      attempt++;
      try {
        return await operation();
      } on Exception catch (e) {
        if (e is TimeoutException || e is SocketException) {
          if (attempt >= maxRetries) {
            if (e is TimeoutException) {
              throw Exception(timeoutErrorMessage);
            } else {
              throw Exception(networkErrorMessage);
            }
          }
          final reason = e is TimeoutException ? 'Timeout' : 'Network error';
          developer.log(
            ' [33m$reason during $context, retrying (attempt $attempt)... [0m',
            name: 'OllamaInferenceRepository',
          );
          await Future<void>.delayed(baseDelay * (1 << (attempt - 1)));
          continue;
        }
        // For all other errors, do not retry. Rethrow to preserve the original error.
        rethrow;
      }
    }
  }

  /// Validate Ollama request parameters
  void _validateOllamaRequest({
    required String prompt,
    required String model,
    required double temperature,
    int? maxCompletionTokens,
  }) {
    if (prompt.isEmpty) {
      throw Exception('Prompt cannot be empty');
    }
    if (model.isEmpty) {
      throw Exception('Model cannot be empty');
    }
    if (temperature < ollamaMinTemperature ||
        temperature > ollamaMaxTemperature) {
      throw Exception(
        'Temperature must be between $ollamaMinTemperature and $ollamaMaxTemperature',
      );
    }
    if (maxCompletionTokens != null && maxCompletionTokens <= 0) {
      throw Exception('maxCompletionTokens must be positive');
    }
  }

  /// Image analysis. Thin delegator to
  /// [OllamaImageAnalysis.generateWithImagesImpl] so the method remains a
  /// mockable class member.
  Stream<AiStreamChunk> generateWithImages({
    required String prompt,
    required String model,
    required double temperature,
    required List<String> images,
    required AiConfigInferenceProvider provider,
    int? maxCompletionTokens,
    String? systemMessage,
  }) => generateWithImagesImpl(
    prompt: prompt,
    model: model,
    temperature: temperature,
    images: images,
    provider: provider,
    maxCompletionTokens: maxCompletionTokens,
    systemMessage: systemMessage,
  );

  /// Model installation. Thin delegator to
  /// [OllamaModelManagement.installModelImpl] (mockable class member).
  Stream<OllamaPullProgress> installModel(String modelName, String baseUrl) =>
      installModelImpl(modelName, baseUrl);

  /// Model warm-up. Thin delegator to
  /// [OllamaModelManagement.warmUpModelImpl] (mockable class member).
  Future<void> warmUpModel(String modelName, String baseUrl) =>
      warmUpModelImpl(modelName, baseUrl);
}

/// Exception thrown when a model is not installed
class ModelNotInstalledException implements Exception {
  const ModelNotInstalledException(this.modelName);

  final String modelName;

  @override
  String toString() =>
      'Model "$modelName" is not installed. Please install it first.';
}

/// Progress information for model installation
class OllamaPullProgress {
  const OllamaPullProgress({
    required this.status,
    required this.progress,
  });

  final String status; // e.g., "pulling manifest", "downloading", "success"
  final double progress; // Progress as a fraction (0.0 to 1.0)
}
