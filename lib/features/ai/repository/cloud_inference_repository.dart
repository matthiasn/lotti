import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'cloud_inference_repository.g.dart';

class CloudInferenceRepository {
  CloudInferenceRepository(this.ref, {http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final Ref ref;
  final http.Client _httpClient;

  /// Filters out Anthropic ping messages from the stream
  Stream<CreateChatCompletionStreamResponse> _filterAnthropicPings(
    Stream<CreateChatCompletionStreamResponse> stream,
  ) {
    // Use where to filter out errors instead of handleError
    final controller = StreamController<CreateChatCompletionStreamResponse>();

    stream.listen(
      controller.add,
      onError: (Object error, StackTrace stackTrace) {
        // Check if this is specifically an Anthropic ping message error
        final errorString = error.toString();

        // Anthropic ping messages cause a specific null subtype error when parsing choices
        final isAnthropicPingError = errorString.contains(
                "type 'Null' is not a subtype of type 'List<dynamic>'") &&
            errorString.contains('choices');

        if (isAnthropicPingError) {
          // Log but don't propagate the error
          developer.log(
            'Skipping Anthropic ping message',
            name: 'CloudInferenceRepository',
            error: error,
            stackTrace: stackTrace,
          );
          return;
        }
        // Propagate other errors
        controller.addError(error, stackTrace);
      },
      onDone: controller.close,
    );

    return controller.stream;
  }

  Stream<CreateChatCompletionStreamResponse> generate(
    String prompt, {
    required String model,
    required double temperature,
    required String baseUrl,
    required String apiKey,
    String? systemMessage,
    int? maxCompletionTokens,
    OpenAIClient? overrideClient,
    AiConfigInferenceProvider? provider,
    List<ChatCompletionTool>? tools,
  }) {
    developer.log(
      'CloudInferenceRepository.generate called with tools: ${tools?.length ?? 0}',
      name: 'CloudInferenceRepository',
    );

    // For Ollama, call the API directly
    if (provider != null &&
        provider.inferenceProviderType == InferenceProviderType.ollama) {
      return _generateTextWithOllama(
        prompt: prompt,
        model: model,
        temperature: temperature,
        systemMessage: systemMessage,
        maxCompletionTokens: maxCompletionTokens,
        provider: provider,
        tools: tools,
      );
    }

    final client = overrideClient ??
        OpenAIClient(
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

    if (tools != null && tools.isNotEmpty) {
      developer.log(
        'Passing ${tools.length} tools to OpenAI API: ${tools.map((t) => t.function.name).join(', ')}',
        name: 'CloudInferenceRepository',
      );
    }

    final res = client.createChatCompletionStream(
      request: CreateChatCompletionRequest(
        messages: [
          if (systemMessage != null)
            ChatCompletionMessage.system(content: systemMessage),
          ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.string(prompt),
          ),
        ],
        model: ChatCompletionModel.modelId(model),
        temperature: temperature,
        maxCompletionTokens: maxCompletionTokens,
        stream: true,
        tools: tools,
        toolChoice: tools != null
            ? const ChatCompletionToolChoiceOption.mode(
                ChatCompletionToolChoiceMode.auto,
              )
            : null,
      ),
    );

    return _filterAnthropicPings(res).asBroadcastStream();
  }

  Stream<CreateChatCompletionStreamResponse> generateWithImages(
    String prompt, {
    required String baseUrl,
    required String apiKey,
    required String model,
    required double temperature,
    required List<String> images,
    int? maxCompletionTokens,
    OpenAIClient? overrideClient,
    AiConfigInferenceProvider? provider,
    List<ChatCompletionTool>? tools,
  }) {
    final client = overrideClient ??
        OpenAIClient(
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

    // For Ollama, call the API directly
    if (provider?.inferenceProviderType == InferenceProviderType.ollama) {
      return _generateWithOllama(
        prompt: prompt,
        model: model,
        temperature: temperature,
        images: images,
        maxCompletionTokens: maxCompletionTokens,
        provider: provider!,
      );
    }

    // For other providers, use the standard OpenAI-compatible format
    if (tools != null && tools.isNotEmpty) {
      developer.log(
        'Passing ${tools.length} tools to image API: ${tools.map((t) => t.function.name).join(', ')}',
        name: 'CloudInferenceRepository',
      );
    }

    final res = client.createChatCompletionStream(
      request: CreateChatCompletionRequest(
        messages: [
          ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.parts(
              [
                ChatCompletionMessageContentPart.text(text: prompt),
                ...images.map(
                  (image) {
                    return ChatCompletionMessageContentPart.image(
                      imageUrl: ChatCompletionMessageImageUrl(
                        url: 'data:image/jpeg;base64,$image',
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
        model: ChatCompletionModel.modelId(model),
        temperature: temperature,
        maxTokens: maxCompletionTokens,
        stream: true,
        tools: tools,
        toolChoice: tools != null
            ? const ChatCompletionToolChoiceOption.mode(
                ChatCompletionToolChoiceMode.auto,
              )
            : null,
      ),
    );

    return res.asBroadcastStream();
  }

  /// Shared helper method for making Ollama API requests
  ///
  /// This method handles the common logic for making requests to Ollama's API:
  /// - Making HTTP requests with retry logic
  /// - Handling response parsing and validation
  /// - Creating standardized stream responses
  /// - Error handling and timeout management
  Stream<CreateChatCompletionStreamResponse> _streamOllamaGenerateRequest({
    required Map<String, dynamic> requestBody,
    required Duration timeout,
    required String retryContext,
    required String timeoutErrorMessage,
    required AiConfigInferenceProvider provider,
    String? model,
  }) {
    return Stream.fromFuture(
      () async {
        return _retryWithExponentialBackoff(
          operation: () async {
            final response = await _httpClient
                .post(
                  Uri.parse('${provider.baseUrl}$ollamaGenerateEndpoint'),
                  headers: {
                    'Content-Type': ollamaContentType,
                  },
                  body: jsonEncode(requestBody),
                )
                .timeout(timeout);

            if (response.statusCode != httpStatusOk) {
              final responseBody = response.body;
              // Check if this is a model not found error
              if (response.statusCode == httpStatusNotFound &&
                  responseBody.contains('not found') &&
                  responseBody.contains('model')) {
                throw ModelNotInstalledException(model ?? 'unknown');
              }
              developer.log(
                'Ollama API error: HTTP ${response.statusCode}',
                name: 'CloudInferenceRepository',
              );
              throw Exception(
                  'Ollama API request failed with status ${response.statusCode}. Please check your Ollama installation and try again.');
            }

            final result = jsonDecode(response.body) as Map<String, dynamic>;
            // Validate response structure
            if (!result.containsKey('response')) {
              throw Exception(
                  'Invalid response format: missing "response" field');
            }
            final ollamaResponse = result['response'] as String?;
            if (ollamaResponse == null) {
              throw Exception('Invalid response format: "response" is null');
            }
            final created = result['created_at'] as String?;
            final timestamp = created != null
                ? DateTime.parse(created).millisecondsSinceEpoch ~/ 1000
                : DateTime.now().millisecondsSinceEpoch ~/ 1000;
            // Create a mock stream response to match the expected format
            return CreateChatCompletionStreamResponse(
              id: '$ollamaResponseIdPrefix${DateTime.now().millisecondsSinceEpoch}',
              choices: [
                ChatCompletionStreamResponseChoice(
                  delta: ChatCompletionStreamResponseDelta(
                    content: ollamaResponse,
                  ),
                  index: 0,
                ),
              ],
              object: 'chat.completion.chunk',
              created: timestamp,
            );
          },
          maxRetries: 3,
          baseDelay: const Duration(seconds: 2),
          context: retryContext,
          timeoutErrorMessage: timeoutErrorMessage,
          networkErrorMessage:
              'Network error during Ollama generation. Please check your connection and that the Ollama server is running.',
        );
      }(),
    ).asBroadcastStream();
  }

  /// Generate image analysis using Ollama's API
  ///
  /// This method handles the specific requirements for Ollama image analysis:
  /// - Validates input parameters
  /// - Makes direct HTTP calls to Ollama's /api/generate endpoint
  /// - Handles Ollama-specific response format
  /// - Provides comprehensive error handling
  Stream<CreateChatCompletionStreamResponse> _generateWithOllama({
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

    final requestBody = {
      'model': model,
      'prompt': prompt,
      'images': images,
      'stream': false,
      'options': {
        'temperature': temperature,
        if (maxCompletionTokens != null) 'num_predict': maxCompletionTokens,
      }
    };

    final timeout = Duration(
        seconds: images.isNotEmpty
            ? ollamaImageAnalysisTimeoutSeconds
            : ollamaDefaultTimeoutSeconds);

    return _streamOllamaGenerateRequest(
      requestBody: requestBody,
      timeout: timeout,
      retryContext: 'Ollama generation',
      timeoutErrorMessage:
          'Request timed out after ${timeout.inSeconds} seconds. This can happen when the model is loading for the first time or is very large. Please try again - subsequent requests should be faster.',
      provider: provider,
      model: model,
    );
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

  /// Generate text using Ollama's API
  ///
  /// This method handles the specific requirements for Ollama text generation:
  /// - Validates input parameters
  /// - Makes direct HTTP calls to Ollama's /api/generate endpoint
  /// - Handles Ollama-specific response format
  /// - Provides comprehensive error handling
  /// - Note: Ollama doesn't support function calling tools, so the tools parameter is ignored
  Stream<CreateChatCompletionStreamResponse> _generateTextWithOllama({
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

    final requestBody = {
      'model': model,
      'prompt': systemMessage != null ? '$systemMessage\n\n$prompt' : prompt,
      'stream': false,
      'options': {
        'temperature': temperature,
        if (maxCompletionTokens != null) 'num_predict': maxCompletionTokens,
      }
    };

    return _streamOllamaGenerateRequest(
      requestBody: requestBody,
      timeout: const Duration(seconds: ollamaDefaultTimeoutSeconds),
      retryContext: 'Ollama text generation',
      timeoutErrorMessage:
          'Request timed out after $ollamaDefaultTimeoutSeconds seconds. This can happen when the model is loading for the first time or is very large. Please try again - subsequent requests should be faster.',
      provider: provider,
      model: model,
    );
  }

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
              name: 'CloudInferenceRepository');
          await Future<void>.delayed(baseDelay * (1 << (attempt - 1)));
          continue;
        }
        // For all other errors, do not retry. Rethrow to preserve the original error.
        rethrow;
      }
    }
  }

  /// Check if a model is installed in Ollama
  Future<bool> isModelInstalled(String modelName, String baseUrl) async {
    try {
      final response = await _httpClient
          .get(Uri.parse('$baseUrl/api/tags'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != httpStatusOk) {
        return false;
      }

      final result = jsonDecode(response.body) as Map<String, dynamic>;
      final models = result['models'] as List<dynamic>? ?? [];

      return models.any((model) {
        final modelMap = model as Map<String, dynamic>;
        return modelMap['name'] == modelName || modelMap['model'] == modelName;
      });
    } catch (e) {
      developer.log(
        'Error checking if model is installed',
        error: e,
        name: 'CloudInferenceRepository',
      );
      return false;
    }
  }

  /// Get model information including size
  Future<OllamaModelInfo?> getModelInfo(
      String modelName, String baseUrl) async {
    try {
      final response = await _httpClient
          .get(Uri.parse('$baseUrl/api/tags'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != httpStatusOk) {
        return null;
      }

      final result = jsonDecode(response.body) as Map<String, dynamic>;
      final models = result['models'] as List<dynamic>? ?? [];

      for (final model in models) {
        final modelMap = model as Map<String, dynamic>;
        if (modelMap['name'] == modelName || modelMap['model'] == modelName) {
          final details = modelMap['details'] as Map<String, dynamic>?;
          return OllamaModelInfo(
            name: modelMap['name'] as String,
            size: modelMap['size'] as int? ?? 0,
            parameterSize: details?['parameter_size'] as String? ?? 'Unknown',
            quantizationLevel:
                details?['quantization_level'] as String? ?? 'Unknown',
          );
        }
      }

      return null;
    } catch (e, stackTrace) {
      developer.log(
        'Error getting model info',
        error: e,
        stackTrace: stackTrace,
        name: 'CloudInferenceRepository',
      );
      return null;
    }
  }

  /// Install a model in Ollama with progress tracking
  Stream<OllamaPullProgress> installModel(
      String modelName, String baseUrl) async* {
    const maxRetries = 3;
    const installTimeout = Duration(minutes: 10); // 10 minutes for large models
    const baseDelay = Duration(seconds: 2);
    var attempt = 0;
    while (true) {
      attempt++;
      try {
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
          maxRetries: maxRetries,
          baseDelay: baseDelay,
          context: 'model installation',
          timeoutErrorMessage:
              'Model installation timed out after ${installTimeout.inMinutes} minutes. This may be due to a slow connection or a large model. Please check your internet connection and try again.',
          networkErrorMessage:
              'Network error during model installation. Please check your connection and that the Ollama server is running.',
        );

        if (streamedResponse.statusCode != httpStatusOk) {
          developer.log(
            'Model installation failed: HTTP ${streamedResponse.statusCode}',
            name: 'CloudInferenceRepository',
          );
          throw Exception(
              'Failed to start model installation. (HTTP ${streamedResponse.statusCode}) Please check your Ollama installation and try again.');
        }

        await for (final chunk
            in streamedResponse.stream.transform(utf8.decoder)) {
          final lines =
              chunk.split('\n').where((line) => line.trim().isNotEmpty);

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
                name: 'CloudInferenceRepository',
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

            final status =
                data['status'] is String ? data['status'] as String : '';
            final total = data['total'] is int ? data['total'] as int : 0;
            final completed =
                data['completed'] is int ? data['completed'] as int : 0;

            yield OllamaPullProgress(
              status: status,
              total: total,
              completed: completed,
              progress: total > 0 ? (completed / total) : 0.0,
            );
          }
        }
        // If we reach here, installation succeeded
        break;
      } on Exception catch (e) {
        if (e is TimeoutException || e is SocketException) {
          if (attempt >= maxRetries) {
            if (e is TimeoutException) {
              throw Exception(
                  'Model installation timed out after ${installTimeout.inMinutes} minutes. This may be due to a slow connection or a large model. Please check your internet connection and try again.');
            } else {
              throw Exception(
                  'Network error during model installation. Please check your connection and that the Ollama server is running.');
            }
          }
          final reason = e is TimeoutException ? 'Timeout' : 'Network error';
          developer.log(
              '$reason during model installation, retrying (attempt $attempt)...',
              name: 'CloudInferenceRepository');
          await Future<void>.delayed(baseDelay * (1 << (attempt - 1)));
          continue;
        }
        // For all other errors, do not retry. Rethrow to preserve the original error.
        rethrow;
      }
    }
  }

  /// Warm up a model by sending a simple request to load it into memory
  Future<void> warmUpModel(String modelName, String baseUrl) async {
    try {
      developer.log(
        'Warming up model: $modelName',
        name: 'CloudInferenceRepository',
      );

      final response = await _httpClient
          .post(
            Uri.parse('$baseUrl$ollamaGenerateEndpoint'),
            headers: {
              'Content-Type': ollamaContentType,
            },
            body: jsonEncode({
              'model': modelName,
              'prompt': 'Hello',
              'stream': false,
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode != httpStatusOk) {
        developer.log(
          'Warning: Model warm-up failed: HTTP ${response.statusCode}',
          name: 'CloudInferenceRepository',
        );
        return; // Don't throw, just log warning
      }

      developer.log(
        'Model warmed up successfully: $modelName',
        name: 'CloudInferenceRepository',
      );
    } catch (e, stackTrace) {
      developer.log(
        'Warning: Model warm-up failed',
        error: e,
        stackTrace: stackTrace,
        name: 'CloudInferenceRepository',
      );
      // Don't throw, just log warning
    }
  }

  /// Generates AI responses with audio input using different providers
  ///
  /// This method handles different inference providers:
  /// - FastWhisper: Uses local FastWhisper server for transcription
  /// - Whisper: Uses OpenAI's Whisper API via our Python proxy server
  /// - Other providers: Uses standard OpenAI-compatible format
  ///
  /// Args:
  ///   prompt: The text prompt to send with the audio
  ///   model: The model identifier to use
  ///   audioBase64: Base64 encoded audio data
  ///   baseUrl: The base URL for the API
  ///   apiKey: The API key for authentication
  ///   provider: The inference provider configuration
  ///   maxCompletionTokens: Maximum tokens for completion
  ///   overrideClient: Optional client override for testing
  ///
  /// Returns:
  ///   Stream of chat completion responses
  Stream<CreateChatCompletionStreamResponse> generateWithAudio(
    String prompt, {
    required String model,
    required String audioBase64,
    required String baseUrl,
    required String apiKey,
    required AiConfigInferenceProvider provider,
    int? maxCompletionTokens,
    OpenAIClient? overrideClient,
    List<ChatCompletionTool>? tools,
  }) {
    final client = overrideClient ??
        OpenAIClient(
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

    // For Whisper, we need to handle the audio transcription using our Python server
    if (provider.inferenceProviderType == InferenceProviderType.whisper) {
      // Whisper uses our Python server that calls OpenAI's API
      // Create a stream that performs the async operation
      return Stream.fromFuture(
        () async {
          try {
            final response = await _httpClient.post(
              Uri.parse('$baseUrl/v1/audio/transcriptions'),
              headers: {
                'Content-Type': 'application/json',
              },
              body: jsonEncode({
                'model': model,
                'audio': audioBase64,
              }),
            );

            if (response.statusCode != 200) {
              developer.log(
                  'Failed to transcribe audio: HTTP ${response.statusCode}',
                  name: 'CloudInferenceRepository');
              throw Exception(
                  'Failed to transcribe audio. Please check your audio file and try again.');
            }

            final result = jsonDecode(response.body) as Map<String, dynamic>;
            final text = result['text'] as String;

            // Create a mock stream response to match the expected format
            return CreateChatCompletionStreamResponse(
              id: 'whisper-${DateTime.now().millisecondsSinceEpoch}',
              choices: [
                ChatCompletionStreamResponseChoice(
                  delta: ChatCompletionStreamResponseDelta(
                    content: text,
                  ),
                  index: 0,
                ),
              ],
              object: 'chat.completion.chunk',
              created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            );
          } catch (e) {
            // Re-throw the exception to be handled by the stream
            rethrow;
          }
        }(),
      ).asBroadcastStream();
    }

    // For other providers, use the standard OpenAI-compatible format
    if (tools != null && tools.isNotEmpty) {
      developer.log(
        'Passing ${tools.length} tools to audio API: ${tools.map((t) => t.function.name).join(', ')}',
        name: 'CloudInferenceRepository',
      );
    }

    return client
        .createChatCompletionStream(
          request: CreateChatCompletionRequest(
            messages: [
              ChatCompletionMessage.user(
                content: ChatCompletionUserMessageContent.parts(
                  [
                    ChatCompletionMessageContentPart.text(text: prompt),
                    ChatCompletionMessageContentPart.audio(
                      inputAudio: ChatCompletionMessageInputAudio(
                        data: audioBase64,
                        format: ChatCompletionMessageInputAudioFormat.mp3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            model: ChatCompletionModel.modelId(model),
            maxCompletionTokens: maxCompletionTokens,
            stream: true,
            tools: tools,
            toolChoice: tools != null
                ? const ChatCompletionToolChoiceOption.mode(
                    ChatCompletionToolChoiceMode.auto,
                  )
                : null,
          ),
        )
        .asBroadcastStream();
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

/// Information about an Ollama model
class OllamaModelInfo {
  const OllamaModelInfo({
    required this.name,
    required this.size,
    required this.parameterSize,
    required this.quantizationLevel,
  });

  final String name;
  final int size; // Size in bytes
  final String parameterSize; // e.g., "4.3B"
  final String quantizationLevel; // e.g., "Q4_K_M"

  /// Get human-readable size
  String get humanReadableSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

/// Progress information for model installation
class OllamaPullProgress {
  const OllamaPullProgress({
    required this.status,
    required this.total,
    required this.completed,
    required this.progress,
  });

  final String status; // e.g., "pulling manifest", "downloading", "success"
  final int total; // Total bytes to download
  final int completed; // Bytes downloaded so far
  final double progress; // Progress as a fraction (0.0 to 1.0)

  /// Get human-readable progress percentage
  String get progressPercentage => '${(progress * 100).toStringAsFixed(1)}%';

  /// Get human-readable download progress
  String get downloadProgress {
    if (total == 0) return status;
    final totalMB = (total / (1024 * 1024)).toStringAsFixed(1);
    final completedMB = (completed / (1024 * 1024)).toStringAsFixed(1);
    return '$status: $completedMB MB / $totalMB MB ($progressPercentage)';
  }
}

@riverpod
CloudInferenceRepository cloudInferenceRepository(Ref ref) {
  return CloudInferenceRepository(ref);
}
