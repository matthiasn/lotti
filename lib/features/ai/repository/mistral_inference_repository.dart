import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:meta/meta.dart';
import 'package:openai_dart/openai_dart.dart';

/// Repository for handling Mistral-specific inference operations
///
/// This repository handles text generation using the Mistral API.
/// It parses streaming responses manually to handle Mistral's response format
/// differences, particularly for tool calls where the content field may be
/// returned as an array instead of a string.
class MistralInferenceRepository {
  MistralInferenceRepository({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  /// Safely log exception to LoggingService if available
  void _logException(
    Object exception, {
    required String subDomain,
    StackTrace? stackTrace,
  }) {
    if (getIt.isRegistered<DomainLogger>()) {
      getIt<DomainLogger>().error(
        LogDomain.ai,
        exception,
        stackTrace: stackTrace,
        subDomain: subDomain,
      );
    }
  }

  /// Default timeout for [listModels]. Exposed so test doubles can mirror the
  /// production default instead of hardcoding a magic duration.
  @visibleForTesting
  static const modelListTimeout = Duration(seconds: 15);

  /// Fetches the live Mistral model catalog and maps each row's capability
  /// metadata into the app's [KnownModel] shape.
  ///
  /// Mistral's `/v1/models` listing carries a `capabilities` object
  /// (`completion_chat`, `vision`, `function_calling`, `ocr`, …) plus
  /// `name`, `description`, and `max_context_length`. Modalities are inferred
  /// from those flags plus conservative id heuristics for the Voxtral (audio)
  /// and OCR families, since Mistral's `type` field describes training lineage
  /// (`base`, `fine-tuned`) rather than a modality.
  Future<List<KnownModel>> listModels({
    required String baseUrl,
    required String apiKey,
    Duration timeout = modelListTimeout,
  }) async {
    final normalizedBaseUrl = baseUrl.trim();
    final normalizedApiKey = apiKey.trim();
    if (normalizedBaseUrl.isEmpty) {
      throw MistralInferenceException('Base URL cannot be empty');
    }
    if (normalizedApiKey.isEmpty) {
      throw MistralInferenceException('API key cannot be empty');
    }

    final uri = _buildEndpointUri(normalizedBaseUrl, 'models');
    // Log only host + path — never the full URI, which (from a user-configured
    // base URL) can carry credentials in userinfo or tokens in the query.
    developer.log(
      'Fetching Mistral model catalog from ${_redactedEndpoint(uri)}',
      name: 'MistralInferenceRepository',
    );

    try {
      final response = await _httpClient
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $normalizedApiKey',
            },
          )
          .timeout(timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw MistralInferenceException(
          _extractErrorMessage(response.body, response.statusCode),
          statusCode: response.statusCode,
        );
      }

      final decoded = jsonDecode(response.body);
      final data = switch (decoded) {
        {'data': final List<dynamic> data} => data,
        final List<dynamic> data => data,
        _ => throw MistralInferenceException(
          'Mistral model list response must be a JSON object with data[] '
          'or a JSON array',
        ),
      };

      final models = <KnownModel>[];
      for (final item in data) {
        if (item is! Map<String, dynamic>) {
          throw MistralInferenceException(
            'Mistral model entry must be a JSON object',
          );
        }
        final known = _knownModelFromPayload(item);
        // Drop rows that map onto no app-supported flow (e.g. embeddings,
        // classification, moderation) so they can't be installed as chat
        // models and then fail at inference time.
        if (_isInstallableRow(item, known)) {
          models.add(known);
        }
      }
      return models;
    } on MistralInferenceException {
      rethrow;
    } on TimeoutException catch (e) {
      throw MistralInferenceException(
        'Mistral model list request timed out',
        originalError: e,
      );
    } on FormatException catch (e) {
      throw MistralInferenceException(
        'Mistral model list response was not valid JSON',
        originalError: e,
      );
    } on Exception catch (e) {
      throw MistralInferenceException(
        'Failed to fetch Mistral models: $e',
        originalError: e,
      );
    }
  }

  KnownModel _knownModelFromPayload(Map<String, dynamic> model) {
    final providerModelId = model['id'];
    if (providerModelId is! String || providerModelId.trim().isEmpty) {
      throw MistralInferenceException(
        'Mistral model entry is missing a string id',
      );
    }

    final knownModel = _knownMistralModels[providerModelId];
    final capabilities =
        _asMap(model['capabilities']) ?? const <String, dynamic>{};

    // A curated entry with no live capability metadata to refine is returned
    // verbatim so hand-tuned names and descriptions survive.
    if (knownModel != null && capabilities.isEmpty) {
      return knownModel;
    }

    final inputModalities = <Modality>[...?knownModel?.inputModalities];
    final outputModalities = <Modality>[...?knownModel?.outputModalities];

    _applyCapabilityModalities(
      providerModelId: providerModelId,
      capabilities: capabilities,
      inputModalities: inputModalities,
      outputModalities: outputModalities,
    );

    final supportsFunctionCalling =
        knownModel?.supportsFunctionCalling == true ||
        _truthy(capabilities['function_calling']);
    final isReasoningModel =
        knownModel?.isReasoningModel == true ||
        _truthy(capabilities['reasoning']) ||
        _looksLikeReasoningModel(providerModelId);

    // Preserve curated display metadata (and the curated completion-token
    // limit, which flows downstream via toAiConfigModel) when refining a known
    // model with live capabilities. Purely live rows use a humanized id — for
    // base models Mistral's own `name` just mirrors the id — and the concise
    // derived description.
    return KnownModel(
      providerModelId: providerModelId,
      name: knownModel?.name ?? _displayNameForModel(providerModelId),
      inputModalities: inputModalities,
      outputModalities: outputModalities,
      isReasoningModel: isReasoningModel,
      supportsFunctionCalling: supportsFunctionCalling,
      maxCompletionTokens: knownModel?.maxCompletionTokens,
      description:
          knownModel?.description ??
          _descriptionFor(model: model, capabilities: capabilities),
    );
  }

  /// Whether a catalog row maps onto a flow the app can actually run. A row
  /// that explicitly disables chat (`completion_chat: false`) and exposes no
  /// other supported modality (vision/OCR image input, audio transcription, or
  /// image output) is an embedding/classification/moderation model and is not
  /// installable. Curated rows and rows that don't declare the flag are kept.
  static bool _isInstallableRow(Map<String, dynamic> model, KnownModel known) {
    if (_knownMistralModels.containsKey(known.providerModelId)) return true;
    final capabilities = _asMap(model['capabilities']);
    final chatExplicitlyDisabled =
        capabilities != null &&
        capabilities.containsKey('completion_chat') &&
        !_truthy(capabilities['completion_chat']);
    if (!chatExplicitlyDisabled) return true;
    return known.inputModalities.contains(Modality.image) ||
        known.inputModalities.contains(Modality.audio) ||
        known.outputModalities.contains(Modality.image);
  }

  void _applyCapabilityModalities({
    required String providerModelId,
    required Map<String, dynamic> capabilities,
    required List<Modality> inputModalities,
    required List<Modality> outputModalities,
  }) {
    // Voxtral / transcription models take audio in and emit text; they never
    // behave like chat or vision models.
    if (_looksLikeTranscriptionModel(providerModelId) ||
        _truthy(capabilities['audio']) ||
        _truthy(capabilities['audio_transcription'])) {
      _addUnique(inputModalities, Modality.audio);
      _addUnique(outputModalities, Modality.text);
      return;
    }

    // Everything else is a text chat surface by default.
    _addUnique(inputModalities, Modality.text);
    _addUnique(outputModalities, Modality.text);

    // Vision and OCR models additionally accept image input.
    if (_truthy(capabilities['vision']) ||
        _truthy(capabilities['ocr']) ||
        _truthy(capabilities['document_ocr']) ||
        _looksLikeOcrModel(providerModelId)) {
      _addUnique(inputModalities, Modality.image);
    }
  }

  static void _addUnique(List<Modality> modalities, Modality modality) {
    if (!modalities.contains(modality)) {
      modalities.add(modality);
    }
  }

  static Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    return null;
  }

  String _descriptionFor({
    required Map<String, dynamic> model,
    required Map<String, dynamic> capabilities,
  }) {
    final parts = <String>[];

    final contextLength = _integerValue(model['max_context_length']);
    if (contextLength != null) {
      parts.add('Context: $contextLength tokens.');
    }

    // Capabilities that already render as capability chips (vision -> Image
    // recognition, audio -> Transcription, reasoning -> Thinking, image
    // generation) are intentionally omitted so a row never describes the same
    // capability twice. Only chip-less extras are listed here.
    final featureLabels = <String>[
      if (_truthy(capabilities['ocr']) || _truthy(capabilities['document_ocr']))
        'OCR',
      if (_truthy(capabilities['function_calling'])) 'tools',
      if (_truthy(capabilities['completion_fim'])) 'fill-in-the-middle',
      if (_truthy(capabilities['classification'])) 'classification',
      if (_truthy(capabilities['fine_tuning'])) 'fine-tuning',
    ];
    if (featureLabels.isNotEmpty) {
      parts.add('Features: ${featureLabels.join(', ')}.');
    }

    return parts.join(' ');
  }

  static int? _integerValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static bool _truthy(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) return value.toLowerCase() == 'true';
    return false;
  }

  static bool _looksLikeReasoningModel(String modelId) {
    final normalized = modelId.toLowerCase();
    return normalized.contains('magistral') ||
        normalized.contains('reasoning') ||
        normalized.contains('thinking');
  }

  static bool _looksLikeTranscriptionModel(String modelId) {
    final normalized = modelId.toLowerCase();
    return normalized.contains('voxtral') ||
        normalized.contains('whisper') ||
        normalized.contains('transcribe') ||
        normalized.contains('transcription');
  }

  static bool _looksLikeOcrModel(String modelId) {
    return modelId.toLowerCase().contains('ocr');
  }

  static String _displayNameForModel(String modelId) {
    final leaf = modelId.split('/').last;
    final words = leaf
        .replaceAll(RegExp(r'[_\-.]+'), ' ')
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map(_titleCaseModelWord);
    final displayName = words.join(' ');
    return displayName.isEmpty ? modelId : displayName;
  }

  static String _titleCaseModelWord(String word) {
    final upper = word.toUpperCase();
    const acronyms = {
      'AI',
      'API',
      'FIM',
      'OCR',
      'VL',
    };
    if (acronyms.contains(upper)) return upper;
    if (RegExp(r'^[a-z]?\d+[a-z]?$', caseSensitive: false).hasMatch(word)) {
      return upper;
    }
    return '${word[0].toUpperCase()}${word.substring(1)}';
  }

  /// A safe-to-log representation of [uri]: host + path only, with any
  /// userinfo (credentials) and query string (tokens) stripped.
  static String _redactedEndpoint(Uri uri) {
    final host = uri.host.isEmpty ? '<local>' : uri.host;
    return '$host${uri.path}';
  }

  static Uri _buildEndpointUri(String baseUrl, String endpointPath) {
    try {
      final baseUri = Uri.parse(baseUrl.trim());
      final basePath = baseUri.path.replaceAll(RegExp(r'/+$'), '');
      final normalizedEndpoint = endpointPath.replaceAll(RegExp('^/+'), '');

      return baseUri.replace(path: '$basePath/$normalizedEndpoint');
    } on FormatException catch (e) {
      // Never echo the raw base URL — it may carry userinfo/query secrets.
      throw MistralInferenceException(
        'Invalid Mistral base URL',
        originalError: e,
      );
    }
  }

  static String _extractErrorMessage(String body, int statusCode) {
    final fallback = 'Mistral API error (HTTP $statusCode)';
    if (body.isEmpty) return fallback;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is Map<String, dynamic>) {
          final message = error['message'];
          if (message is String && message.isNotEmpty) return message;
        }
        if (error is String && error.isNotEmpty) return error;
        final message = decoded['message'];
        if (message is String && message.isNotEmpty) return message;
      }
    } catch (_) {
      // Fall through to a clipped raw body.
    }
    return body.length > 160 ? '${body.substring(0, 160)}…' : body;
  }

  /// Generate text using the Mistral API with streaming support.
  ///
  /// This method handles Mistral's specific streaming format, including:
  /// - Content that may be returned as an array instead of a string
  /// - Tool calls in streaming responses
  ///
  /// Args:
  ///   prompt: The text prompt to send
  ///   model: The model identifier (e.g., 'mistral-small-2501')
  ///   baseUrl: The base URL for the API
  ///   apiKey: The API key for authentication
  ///   systemMessage: Optional system message for context
  ///   temperature: Sampling temperature
  ///   maxCompletionTokens: Maximum tokens for completion
  ///   tools: Optional list of tools for function calling
  ///   toolChoice: Optional tool-selection override (`auto`, required, none,
  ///     or a specific function).
  ///
  /// Returns:
  ///   Stream of chat completion responses
  Stream<CreateChatCompletionStreamResponse> generateText({
    required String prompt,
    required String model,
    required String baseUrl,
    required String apiKey,
    String? systemMessage,
    double? temperature,
    int? maxCompletionTokens,
    List<ChatCompletionTool>? tools,
    ChatCompletionToolChoiceOption? toolChoice,
  }) async* {
    yield* _generate(
      messages: [
        if (systemMessage != null) {'role': 'system', 'content': systemMessage},
        {'role': 'user', 'content': prompt},
      ],
      model: model,
      baseUrl: baseUrl,
      apiKey: apiKey,
      temperature: temperature,
      maxCompletionTokens: maxCompletionTokens,
      tools: tools,
      toolChoice: toolChoice,
    );
  }

  /// Generate text with full conversation history.
  ///
  /// This method supports multi-turn conversations with Mistral's API and
  /// the same tool-selection override as [generateText].
  Stream<CreateChatCompletionStreamResponse> generateTextWithMessages({
    required List<ChatCompletionMessage> messages,
    required String model,
    required String baseUrl,
    required String apiKey,
    double? temperature,
    int? maxCompletionTokens,
    List<ChatCompletionTool>? tools,
    ChatCompletionToolChoiceOption? toolChoice,
  }) async* {
    yield* _generate(
      messages: convertMessages(messages),
      model: model,
      baseUrl: baseUrl,
      apiKey: apiKey,
      temperature: temperature,
      maxCompletionTokens: maxCompletionTokens,
      tools: tools,
      toolChoice: toolChoice,
    );
  }

  /// Convert openai_dart messages to plain maps for manual serialization.
  @visibleForTesting
  List<Map<String, dynamic>> convertMessages(
    List<ChatCompletionMessage> messages,
  ) {
    return messages.map((message) {
      final role = message.role;
      switch (role) {
        case ChatCompletionMessageRole.system:
          return message.mapOrNull(
            system: (m) => {
              'role': 'system',
              'content': m.content,
            },
          )!;

        case ChatCompletionMessageRole.user:
          return message.mapOrNull(
            user: (m) {
              final content = m.content.mapOrNull(
                string: (c) => c.value,
                parts: (c) => c.value
                    .map(
                      (part) => part.mapOrNull(
                        text: (t) => {'type': 'text', 'text': t.text},
                        image: (i) => {
                          'type': 'image_url',
                          'image_url': {'url': i.imageUrl.url},
                        },
                        audio: (a) => {
                          'type': 'input_audio',
                          'input_audio': {
                            'data': a.inputAudio.data,
                            'format': a.inputAudio.format.name,
                          },
                        },
                      ),
                    )
                    .whereType<Map<String, dynamic>>()
                    .toList(),
              );
              return {
                'role': 'user',
                'content': content,
              };
            },
          )!;

        case ChatCompletionMessageRole.assistant:
          return message.mapOrNull(
            assistant: (m) {
              final map = <String, dynamic>{'role': 'assistant'};
              if (m.content != null) {
                map['content'] = m.content;
              }
              if (m.toolCalls != null && m.toolCalls!.isNotEmpty) {
                map['tool_calls'] = m.toolCalls!
                    .map(
                      (tc) => {
                        'id': tc.id,
                        'type': 'function',
                        'function': {
                          'name': tc.function.name,
                          'arguments': tc.function.arguments,
                        },
                      },
                    )
                    .toList();
              }
              return map;
            },
          )!;

        case ChatCompletionMessageRole.tool:
          return message.mapOrNull(
            tool: (m) => {
              'role': 'tool',
              'tool_call_id': m.toolCallId,
              'content': m.content,
            },
          )!;

        case ChatCompletionMessageRole.function:
          return message.mapOrNull(
            function: (m) => {
              'role': 'function',
              'name': m.name,
              'content': m.content,
            },
          )!;

        case ChatCompletionMessageRole.developer:
          return message.mapOrNull(
            developer: (m) => {
              'role': 'developer',
              'content': m.content,
            },
          )!;
      }
    }).toList();
  }

  /// Internal method to generate text with streaming.
  Stream<CreateChatCompletionStreamResponse> _generate({
    required List<Map<String, dynamic>> messages,
    required String model,
    required String baseUrl,
    required String apiKey,
    double? temperature,
    int? maxCompletionTokens,
    List<ChatCompletionTool>? tools,
    ChatCompletionToolChoiceOption? toolChoice,
  }) async* {
    final requestBody = <String, dynamic>{
      'model': model,
      'messages': messages,
      'stream': true,
      'temperature': ?temperature,
      'max_tokens': ?maxCompletionTokens,
    };

    // Add tools if provided
    if (tools != null && tools.isNotEmpty) {
      requestBody['tools'] = tools.map((tool) {
        return {
          'type': 'function',
          'function': {
            'name': tool.function.name,
            'description': tool.function.description,
            if (tool.function.parameters != null)
              'parameters': tool.function.parameters,
          },
        };
      }).toList();
      requestBody['tool_choice'] = _serializeToolChoice(toolChoice) ?? 'auto';
    }

    developer.log(
      'Sending streaming request to Mistral API - '
      'baseUrl: $baseUrl, model: $model, '
      'tools: ${tools?.length ?? 0}',
      name: 'MistralInferenceRepository',
    );

    try {
      // Single source of truth for endpoint URL construction (shared with
      // listModels) so base-URL normalization can't drift between the two.
      final uri = _buildEndpointUri(baseUrl, 'chat/completions');
      final request = http.Request('POST', uri);
      request.headers['Content-Type'] = 'application/json';
      request.headers['Accept'] = 'text/event-stream';
      request.headers['Authorization'] = 'Bearer $apiKey';
      request.body = jsonEncode(requestBody);

      final streamedResponse = await _httpClient.send(request);

      if (streamedResponse.statusCode != 200) {
        final body = await streamedResponse.stream.bytesToString();
        developer.log(
          'Mistral API error: HTTP ${streamedResponse.statusCode} - $body',
          name: 'MistralInferenceRepository',
        );
        throw MistralInferenceException(
          'Mistral API error (HTTP ${streamedResponse.statusCode})',
          statusCode: streamedResponse.statusCode,
        );
      }

      var chunksReceived = 0;
      var parseErrorCount = 0;
      const maxParseErrors = 5;
      var buffer = StringBuffer();

      await for (final chunk in streamedResponse.stream.transform(
        utf8.decoder,
      )) {
        // Append chunk to buffer and process complete lines
        buffer.write(chunk);
        final bufferContent = buffer.toString();

        // Find complete lines (SSE format: "data: {...}\n\n")
        final lines = bufferContent.split('\n');

        // Keep the last incomplete line in the buffer
        buffer = StringBuffer();
        if (!bufferContent.endsWith('\n')) {
          buffer.write(lines.removeLast());
        }

        for (final line in lines) {
          final trimmedLine = line.trim();
          if (trimmedLine.isEmpty) continue;

          if (trimmedLine.startsWith('data: ')) {
            final data = trimmedLine.substring(6).trim();

            // Check for stream end
            if (data == '[DONE]') {
              developer.log(
                'Streaming complete - received $chunksReceived chunks',
                name: 'MistralInferenceRepository',
              );
              return;
            }

            try {
              final json = jsonDecode(data) as Map<String, dynamic>;
              final response = _parseStreamResponse(json);
              if (response != null) {
                chunksReceived++;
                yield response;
              }
            } on FormatException catch (e) {
              parseErrorCount++;
              developer.log(
                'Failed to parse SSE chunk ($parseErrorCount/$maxParseErrors): $data',
                name: 'MistralInferenceRepository',
                error: e,
              );
              if (parseErrorCount >= maxParseErrors) {
                _logException(
                  e,
                  subDomain: 'parse_threshold_exceeded',
                );
                throw MistralInferenceException(
                  'Too many parse errors ($parseErrorCount) during streaming',
                  originalError: e,
                );
              }
              // Continue processing other chunks
            }
          }
        }
      }
    } on MistralInferenceException {
      rethrow;
    } catch (e, stackTrace) {
      developer.log(
        'Unexpected error during Mistral inference',
        name: 'MistralInferenceRepository',
        error: e,
      );
      _logException(e, subDomain: 'unexpected', stackTrace: stackTrace);
      throw MistralInferenceException(
        'Failed to generate text: $e',
        originalError: e,
      );
    }
  }

  Object? _serializeToolChoice(ChatCompletionToolChoiceOption? toolChoice) {
    if (toolChoice == null) return null;

    return toolChoice.map(
      mode: (choice) => switch (choice.value) {
        ChatCompletionToolChoiceMode.none => 'none',
        ChatCompletionToolChoiceMode.auto => 'auto',
        // Mistral forces a tool call with `any`; `required` (the OpenAI
        // spelling) is rejected with a 400 Bad Request.
        ChatCompletionToolChoiceMode.required => 'any',
      },
      tool: (choice) => {
        'type': 'function',
        'function': {'name': choice.value.function.name},
      },
    );
  }

  /// Parse a streaming response chunk from Mistral's API.
  ///
  /// This method handles Mistral's response format where content may be
  /// returned as an array instead of a string.
  CreateChatCompletionStreamResponse? _parseStreamResponse(
    Map<String, dynamic> json,
  ) {
    final choices = json['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      return null;
    }

    final parsedChoices = <ChatCompletionStreamResponseChoice>[];

    for (final choice in choices) {
      final choiceMap = choice as Map<String, dynamic>;
      final delta = choiceMap['delta'] as Map<String, dynamic>?;
      if (delta == null) continue;

      // Handle content that may be a string or an array
      final content = _extractContent(delta['content']);

      // Handle tool calls
      final toolCalls = _parseToolCalls(delta['tool_calls']);

      // Handle role
      final roleStr = delta['role'] as String?;
      ChatCompletionMessageRole? role;
      if (roleStr != null) {
        role = ChatCompletionMessageRole.values.firstWhere(
          (r) => r.name == roleStr,
          orElse: () => ChatCompletionMessageRole.assistant,
        );
      }

      // Handle finish reason - convert snake_case from API to camelCase enum
      final finishReasonStr = choiceMap['finish_reason'] as String?;
      ChatCompletionFinishReason? finishReason;
      if (finishReasonStr != null) {
        // Convert snake_case to camelCase for enum matching
        final camelCaseReason = _snakeToCamel(finishReasonStr);
        finishReason = ChatCompletionFinishReason.values.firstWhere(
          (r) => r.name == camelCaseReason,
          orElse: () => ChatCompletionFinishReason.stop,
        );
      }

      parsedChoices.add(
        ChatCompletionStreamResponseChoice(
          delta: ChatCompletionStreamResponseDelta(
            content: content,
            role: role,
            toolCalls: toolCalls,
          ),
          index: choiceMap['index'] as int? ?? 0,
          finishReason: finishReason,
        ),
      );
    }

    if (parsedChoices.isEmpty) {
      return null;
    }

    // Parse usage if present
    CompletionUsage? usage;
    final usageJson = json['usage'] as Map<String, dynamic>?;
    if (usageJson != null) {
      usage = CompletionUsage(
        completionTokens: usageJson['completion_tokens'] as int? ?? 0,
        promptTokens: usageJson['prompt_tokens'] as int? ?? 0,
        totalTokens: usageJson['total_tokens'] as int? ?? 0,
      );
    }

    return CreateChatCompletionStreamResponse(
      id:
          json['id'] as String? ??
          'mistral-${DateTime.now().millisecondsSinceEpoch}',
      choices: parsedChoices,
      object: 'chat.completion.chunk',
      created:
          json['created'] as int? ??
          DateTime.now().millisecondsSinceEpoch ~/ 1000,
      model: json['model'] as String?,
      usage: usage,
    );
  }

  /// Extract content from the delta, handling both string and array formats.
  ///
  /// Mistral may return content as:
  /// - A simple string: "Hello"
  /// - An array of content parts: [{"type": "text", "text": "Hello"}]
  String? _extractContent(dynamic content) {
    if (content == null) {
      return null;
    }

    if (content is String) {
      return content;
    }

    if (content is List) {
      // Extract text from content parts
      final textParts = <String>[];
      for (final part in content) {
        if (part is Map<String, dynamic>) {
          final type = part['type'] as String?;
          if (type == 'text') {
            final text = part['text'] as String?;
            if (text != null) {
              textParts.add(text);
            }
          }
        } else if (part is String) {
          textParts.add(part);
        }
      }
      return textParts.isEmpty ? null : textParts.join();
    }

    // Fallback: try to convert to string
    return content.toString();
  }

  /// Convert snake_case to camelCase (e.g., 'tool_calls' -> 'toolCalls')
  String _snakeToCamel(String input) {
    final parts = input.split('_');
    if (parts.length == 1) return input;

    return parts.first +
        parts.skip(1).map((part) {
          if (part.isEmpty) return part;
          return part[0].toUpperCase() + part.substring(1);
        }).join();
  }

  /// Parse tool calls from the delta.
  List<ChatCompletionStreamMessageToolCallChunk>? _parseToolCalls(
    dynamic toolCalls,
  ) {
    if (toolCalls == null) return null;

    if (toolCalls is! List) return null;

    final result = <ChatCompletionStreamMessageToolCallChunk>[];

    for (final tc in toolCalls) {
      if (tc is Map<String, dynamic>) {
        final function = tc['function'] as Map<String, dynamic>?;

        result.add(
          ChatCompletionStreamMessageToolCallChunk(
            id: tc['id'] as String?,
            index: tc['index'] as int?,
            function: function != null
                ? ChatCompletionStreamMessageFunctionCall(
                    name: function['name'] as String?,
                    arguments: function['arguments'] as String?,
                  )
                : null,
          ),
        );
      }
    }

    return result.isEmpty ? null : result;
  }

  /// Closes the underlying HTTP client and any keep-alive connections.
  void close() => _httpClient.close();
}

final Map<String, KnownModel> _knownMistralModels = {
  for (final model in mistralModels) model.providerModelId: model,
};

/// Exception thrown when Mistral operations fail.
class MistralInferenceException implements Exception {
  MistralInferenceException(
    this.message, {
    this.statusCode,
    this.originalError,
  });

  final String message;
  final int? statusCode;
  final Object? originalError;

  @override
  String toString() => 'MistralInferenceException: $message';
}
