part of 'ollama_inference_repository.dart';

/// Chat-completion streaming internals for [OllamaInferenceRepository]:
/// request building, the streamed /api/chat call, and request validation.
/// Split from the main file for size; all members are library-private.
extension OllamaChatStreaming on OllamaInferenceRepository {
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
  Stream<CreateChatCompletionStreamResponse> _streamChatRequest({
    required Map<String, dynamic> requestBody,
    required Duration timeout,
    required String retryContext,
    required String timeoutErrorMessage,
    required AiConfigInferenceProvider provider,
    String? model,
  }) async* {
    // Enable thinking mode for supported models
    if (model != null &&
        OllamaInferenceRepository.shouldEnableThinking(model)) {
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
        baseDelay: OllamaInferenceRepository.retryBaseDelay,
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
              // We'll emit this as a single chunk containing all tool calls
              final toolNow = DateTime.now();
              yield CreateChatCompletionStreamResponse(
                id: '$ollamaResponseIdPrefix${toolNow.microsecondsSinceEpoch}',
                choices: [
                  ChatCompletionStreamResponseChoice(
                    delta: ChatCompletionStreamResponseDelta.fromJson({
                      'tool_calls': toolCallsList,
                    }),
                    index: 0,
                  ),
                ],
                object: 'chat.completion.chunk',
                created: toolNow.millisecondsSinceEpoch ~/ 1000,
              );
            } else if (message['content'] != null) {
              // Regular content response
              final frag = message['content'] as String;
              final contentNow = DateTime.now();
              yield CreateChatCompletionStreamResponse(
                id: '$ollamaResponseIdPrefix${contentNow.microsecondsSinceEpoch}',
                choices: [
                  ChatCompletionStreamResponseChoice(
                    delta: ChatCompletionStreamResponseDelta(
                      content: frag,
                    ),
                    index: 0,
                  ),
                ],
                object: 'chat.completion.chunk',
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
              yield CreateChatCompletionStreamResponse(
                id: '$ollamaResponseIdPrefix${usageNow.microsecondsSinceEpoch}',
                choices: const [],
                object: 'chat.completion.chunk',
                created: usageNow.millisecondsSinceEpoch ~/ 1000,
                usage: CompletionUsage(
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
}
