import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/gemini_tool_call.dart';
import 'package:lotti/features/ai/repository/inference_repository_interface.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/util/content_extraction_helper.dart';
import 'package:openai_dart/openai_dart.dart';

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

  // Toggle for verbose streaming logs useful during debugging. Disabled by
  // default to avoid console noise in production.
  static const bool kVerboseStreamLogging = false;

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
  Stream<CreateChatCompletionStreamResponse> generateTextWithMessages({
    required List<ChatCompletionMessage> messages,
    required String model,
    required double temperature,
    required AiConfigInferenceProvider provider,
    int? maxCompletionTokens,
    List<ChatCompletionTool>? tools,
    Map<String, String>? thoughtSignatures, // Ignored for Ollama
    ThoughtSignatureCollector? signatureCollector, // Ignored for Ollama
    int? turnIndex, // Ignored for Ollama
  }) {
    // Convert ChatCompletionMessage objects to Ollama format
    final ollamaMessages = messages.map((msg) {
      final content = msg.content;
      String? contentStr;

      if (content is ChatCompletionUserMessageContent) {
        // Extract text from ChatCompletionUserMessageContent
        contentStr =
            ContentExtractionHelper.extractTextFromUserContent(content);
      } else if (content is String) {
        contentStr = content;
      } else if (content != null) {
        // For other types, try to get JSON representation
        try {
          contentStr = jsonEncode(content);
        } catch (_) {
          contentStr = content.toString();
        }
      }

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
            .map((tool) => {
                  'type': 'function',
                  'function': {
                    'name': tool.function.name,
                    'description': tool.function.description,
                    'parameters': tool.function.parameters ?? {},
                  },
                })
            .toList()
        : null;

    final toolsLog = ollamaTools != null && tools != null
        ? ' with ${ollamaTools.length} tools: ${tools.map((t) => t.function.name).join(', ')}'
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
        if (maxCompletionTokens != null) 'num_predict': maxCompletionTokens,
      }
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

  /// Generate image analysis using Ollama's chat API
  ///
  /// This method handles the specific requirements for Ollama image analysis:
  /// - Validates input parameters
  /// - Uses the unified /api/chat endpoint with image support
  /// - Handles Ollama-specific response format
  /// - Provides comprehensive error handling
  Stream<CreateChatCompletionStreamResponse> generateWithImages({
    required String prompt,
    required String model,
    required double temperature,
    required List<String> images,
    required AiConfigInferenceProvider provider,
    int? maxCompletionTokens,
  }) {
    // Validate inputs
    _validateOllamaRequest(
      prompt: prompt,
      model: model,
      temperature: temperature,
      maxCompletionTokens: maxCompletionTokens,
    );
    if (images.isEmpty) {
      throw Exception('At least one image is required');
    }

    // Warm up the model if this is an image analysis request
    if (images.isNotEmpty) {
      warmUpModel(model, provider.baseUrl);
    }

    // Build messages with images for chat endpoint
    final messages = [
      {
        'role': 'user',
        'content': prompt,
        'images': images,
      }
    ];

    final requestBody = {
      'model': model,
      'messages': messages,
      'stream': true, // Use streaming for consistency
      'options': {
        'temperature': temperature,
        if (maxCompletionTokens != null) 'num_predict': maxCompletionTokens,
      }
    };

    final timeout = Duration(
        seconds: images.isNotEmpty
            ? ollamaImageAnalysisTimeoutSeconds
            : ollamaDefaultTimeoutSeconds);

    return _streamChatRequest(
      requestBody: requestBody,
      timeout: timeout,
      retryContext: 'Ollama image analysis',
      timeoutErrorMessage:
          'Request timed out after ${timeout.inSeconds} seconds. This can happen when the model is loading for the first time or is very large. Please try again - subsequent requests should be faster.',
      provider: provider,
      model: model,
    );
  }

  /// Generate text using Ollama's unified chat API
  ///
  /// This method uses the /api/chat endpoint for all text generation,
  /// with optional tool support for models that have function calling capabilities.
  Stream<CreateChatCompletionStreamResponse> _generateTextWithChat({
    required String prompt,
    required String model,
    required double temperature,
    required AiConfigInferenceProvider provider,
    List<ChatCompletionTool>? tools,
    String? systemMessage,
    int? maxCompletionTokens,
  }) {
    // Convert tools to Ollama format if provided
    final ollamaTools = tools != null && tools.isNotEmpty
        ? tools
            .map((tool) => {
                  'type': 'function',
                  'function': {
                    'name': tool.function.name,
                    'description': tool.function.description,
                    'parameters': tool.function.parameters ?? {},
                  },
                })
            .toList()
        : null;

    final toolsLog = ollamaTools != null && tools != null
        ? ' with ${ollamaTools.length} tools: ${tools.map((t) => t.function.name).join(', ')}'
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
        if (maxCompletionTokens != null) 'num_predict': maxCompletionTokens,
      }
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
  Stream<CreateChatCompletionStreamResponse> _streamChatRequest({
    required Map<String, dynamic> requestBody,
    required Duration timeout,
    required String retryContext,
    required String timeoutErrorMessage,
    required AiConfigInferenceProvider provider,
    String? model,
  }) async* {
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
            'Ollama chat API request failed with status ${request.statusCode}: $responseBody');
      }

      // Process streaming response
      await for (final chunk in request.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (chunk.isEmpty) continue;

        try {
          final json = jsonDecode(chunk) as Map<String, dynamic>;

          // Cast message once to avoid dynamic calls
          final message = json['message'] as Map<String, dynamic>?;
          if (kVerboseStreamLogging) {
            developer.log(
              'Ollama response: ${chunk.substring(0, chunk.length > 500 ? 500 : chunk.length)}',
              name: 'OllamaInferenceRepository',
            );
          }

          // Check if this is a tool call response
          if (message != null) {
            // Skip thinking content - we only care about actual content or tool calls
            if (message['thinking'] != null) {
              continue;
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
                final argumentsStr =
                    arguments is String ? arguments : jsonEncode(arguments);

                toolCallsList.add({
                  'index': i,
                  'id': toolCall['id'] ??
                      'tool-${DateTime.now().millisecondsSinceEpoch}-$i',
                  'type': 'function',
                  'function': {
                    'name': functionCall['name'],
                    'arguments': argumentsStr,
                  },
                });
              }

              // Create the response with tool calls
              // We'll emit this as a single chunk containing all tool calls
              yield CreateChatCompletionStreamResponse(
                id: '$ollamaResponseIdPrefix${DateTime.now().millisecondsSinceEpoch}',
                choices: [
                  ChatCompletionStreamResponseChoice(
                    delta: ChatCompletionStreamResponseDelta.fromJson({
                      'tool_calls': toolCallsList,
                    }),
                    index: 0,
                  ),
                ],
                object: 'chat.completion.chunk',
                created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              );
            } else if (message['content'] != null) {
              // Regular content response
              final frag = message['content'] as String;
              yield CreateChatCompletionStreamResponse(
                id: '$ollamaResponseIdPrefix${DateTime.now().millisecondsSinceEpoch}',
                choices: [
                  ChatCompletionStreamResponseChoice(
                    delta: ChatCompletionStreamResponseDelta(
                      content: frag,
                    ),
                    index: 0,
                  ),
                ],
                object: 'chat.completion.chunk',
                created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              );
            }
          }

          // Check if done
          if (json['done'] == true) {
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
              name: 'OllamaInferenceRepository');
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
          'Temperature must be between $ollamaMinTemperature and $ollamaMaxTemperature');
    }
    if (maxCompletionTokens != null && maxCompletionTokens <= 0) {
      throw Exception('maxCompletionTokens must be positive');
    }
  }

  /// Install a model in Ollama with progress tracking
  Stream<OllamaPullProgress> installModel(
      String modelName, String baseUrl) async* {
    const installTimeout = Duration(minutes: 10); // 10 minutes for large models

    final request = http.Request(
      'POST',
      Uri.parse('$baseUrl/api/pull'),
    );
    request.headers['Content-Type'] = ollamaContentType;
    request.body = jsonEncode({'name': modelName});

    // Use a timeout for the entire send operation
    final streamedResponse = await _retryWithExponentialBackoff(
      operation: () async {
        return _httpClient.send(request).timeout(installTimeout);
      },
      maxRetries: 3,
      baseDelay: retryBaseDelay,
      context: 'model installation',
      timeoutErrorMessage:
          'Model installation timed out after ${installTimeout.inMinutes} minutes. This may be due to a slow connection or a large model. Please check your internet connection and try again.',
      networkErrorMessage:
          'Network error during model installation. Please check your connection and that the Ollama server is running.',
    );

    if (streamedResponse.statusCode != httpStatusOk) {
      developer.log(
        'Model installation failed: HTTP ${streamedResponse.statusCode}',
        name: 'OllamaInferenceRepository',
      );
      throw Exception(
          'Failed to start model installation. (HTTP ${streamedResponse.statusCode}) Please check your Ollama installation and try again.');
    }

    await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
      final lines = chunk.split('\n').where((line) => line.trim().isNotEmpty);

      for (final line in lines) {
        Map<String, dynamic> data;
        try {
          data = jsonDecode(line) as Map<String, dynamic>;
        } catch (e) {
          // Skip malformed JSON lines
          continue;
        }

        if (data.containsKey('error')) {
          final errorMessage = data['error'] as String;
          developer.log(
            'Model installation error: $errorMessage',
            name: 'OllamaInferenceRepository',
          );
          // Provide more specific error messages
          if (errorMessage.contains('not found')) {
            throw Exception('Model installation failed: Model not found.');
          } else if (errorMessage.contains('disk full')) {
            throw Exception(
                'Model installation failed: Disk is full. Please free up space and try again.');
          } else if (errorMessage.contains('connection refused')) {
            throw Exception(
                'Model installation failed: Connection refused. Is the Ollama server running?');
          } else {
            throw Exception(
                'Model installation failed. Please check your Ollama installation and try again.');
          }
        }

        final status = data['status'] is String ? data['status'] as String : '';
        final total = data['total'] is int ? data['total'] as int : 0;
        final completed =
            data['completed'] is int ? data['completed'] as int : 0;

        yield OllamaPullProgress(
          status: status,
          progress: total > 0 ? (completed / total) : 0.0,
        );
      }
    }
  }

  /// Warm up a model by sending a simple request to load it into memory
  Future<void> warmUpModel(String modelName, String baseUrl) async {
    try {
      developer.log(
        'Warming up model: $modelName',
        name: 'OllamaInferenceRepository',
      );

      final response = await _httpClient
          .post(
            Uri.parse('$baseUrl$ollamaChatEndpoint'),
            headers: {
              'Content-Type': ollamaContentType,
            },
            body: jsonEncode({
              'model': modelName,
              'messages': [
                {'role': 'user', 'content': 'Hello'}
              ],
              'stream': false,
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode != httpStatusOk) {
        developer.log(
          'Warning: Model warm-up failed: HTTP ${response.statusCode}',
          name: 'OllamaInferenceRepository',
        );
        return; // Don't throw, just log warning
      }

      developer.log(
        'Model warmed up successfully: $modelName',
        name: 'OllamaInferenceRepository',
      );
    } catch (e, stackTrace) {
      developer.log(
        'Warning: Model warm-up failed',
        error: e,
        stackTrace: stackTrace,
        name: 'OllamaInferenceRepository',
      );
      // Don't throw, just log warning
    }
  }
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
