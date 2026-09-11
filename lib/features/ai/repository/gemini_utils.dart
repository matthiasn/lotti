import 'dart:convert';
import 'dart:developer' as developer;

import 'package:lotti/features/ai/model/inference.dart';
import 'package:lotti/features/ai/repository/gemini_thinking_config.dart';
import 'package:lotti/features/ai/util/image_processing_utils.dart';

/// Utilities for building Gemini HTTP requests and decoding stream framing.
///
/// Central responsibilities:
/// - Construct streaming and non-streaming URIs while preserving scheme/host/port.
/// - Build authenticated request headers without putting credentials in URIs.
/// - Produce endpoint descriptions that are safe for diagnostics.
/// - Build request bodies including system instructions, thinking config and tools.
/// - Strip SSE `data:` prefixes and JSON array framing from mixed-format streams.
class GeminiUtils {
  const GeminiUtils._();

  /// Builds the streaming `:streamGenerateContent` URI from a provider base URL.
  ///
  /// - Normalizes model IDs to `models/<id>`.
  /// - Ignores any existing path in `baseUrl` but preserves scheme/host/port.
  /// - Omits authentication from the URI; callers use [buildRequestHeaders].
  static Uri buildStreamGenerateContentUri({
    required String baseUrl,
    required String model,
  }) => _buildGeminiUri(
    baseUrl: baseUrl,
    model: model,
    endpoint: 'streamGenerateContent',
  );

  /// Builds the non-streaming `:generateContent` URI (used for fallback).
  static Uri buildGenerateContentUri({
    required String baseUrl,
    required String model,
  }) => _buildGeminiUri(
    baseUrl: baseUrl,
    model: model,
    endpoint: 'generateContent',
  );

  /// Builds headers shared by native Gemini generation requests.
  ///
  /// Authentication deliberately uses `x-goog-api-key` instead of a query
  /// parameter so URLs echoed by HTTP clients, proxies, or error logs cannot
  /// expose the credential.
  static Map<String, String> buildRequestHeaders({
    required String apiKey,
    required String accept,
  }) => {
    'Content-Type': 'application/json',
    'Accept': accept,
    'x-goog-api-key': apiKey,
  };

  /// Returns a safe diagnostic representation containing host and path only.
  ///
  /// User information and query parameters are excluded because either can
  /// contain credentials even when current request builders do not add them.
  static String redactedEndpoint(Uri uri) {
    final host = uri.host.isEmpty ? '<local>' : uri.host;
    return '$host${uri.path}';
  }

  /// Builds the native `/v1beta/models` catalog URI from a provider base URL.
  ///
  /// - Ignores any existing path in [baseUrl] but preserves scheme/host/port,
  ///   so the OpenAI-compatible default base URL
  ///   (`.../v1beta/openai`) still resolves to the richer native listing.
  /// - The API key is intentionally **not** put in the query string — the
  ///   catalog fetch authenticates with the `x-goog-api-key` header instead, so
  ///   the key can't leak through proxy/access logs or an exception that echoes
  ///   the URL. Only the optional `pageSize`/`pageToken` pagination cursors are
  ///   added to the query.
  /// - When [baseUrl] omits a host (e.g. a scheme-less value), the returned URI
  ///   has an empty host; callers should validate before requesting.
  static Uri buildListModelsUri({
    required String baseUrl,
    int? pageSize,
    String? pageToken,
  }) {
    final parsed = Uri.parse(baseUrl);
    final root = Uri(
      scheme: parsed.scheme.isNotEmpty ? parsed.scheme : 'https',
      host: parsed.host,
      port: parsed.hasPort ? parsed.port : null,
    );
    final query = <String, String>{
      if (pageSize != null) 'pageSize': '$pageSize',
      if (pageToken != null && pageToken.isNotEmpty) 'pageToken': pageToken,
    };
    return root.replace(
      path: '/v1beta/models',
      queryParameters: query.isEmpty ? null : query,
    );
  }

  /// Internal helper to build Gemini API URIs with the specified endpoint.
  static Uri _buildGeminiUri({
    required String baseUrl,
    required String model,
    required String endpoint,
  }) {
    final parsed = Uri.parse(baseUrl);
    final root = Uri(
      scheme: parsed.scheme.isNotEmpty ? parsed.scheme : 'https',
      host: parsed.host,
      port: parsed.hasPort ? parsed.port : null,
    );

    final trimmed = model.trim().endsWith('/')
        ? model.trim().substring(0, model.trim().length - 1)
        : model.trim();
    final modelPath = trimmed.startsWith('models/')
        ? trimmed
        : 'models/$trimmed';
    final path = '/v1beta/$modelPath:$endpoint';
    return root.replace(path: path);
  }

  /// Builds a Gemini request body including thinking config and function tools.
  ///
  /// - Always includes the `prompt` as a single user message.
  /// - Adds `systemInstruction` when provided.
  /// - Serializes [GeminiThinkingConfig] into `generationConfig.thinkingConfig`.
  /// - Maps OpenAI-style [LottiTool] to Gemini `functionDeclarations`.
  /// - Maps OpenAI-style forced [LottiToolChoice] values to
  ///   Gemini's native `toolConfig.functionCallingConfig`.
  static Map<String, dynamic> buildRequestBody({
    required String prompt,
    required double temperature,
    required GeminiThinkingConfig thinkingConfig,
    String? systemMessage,
    String? modelId,
    int? maxTokens,
    List<LottiTool>? tools,
    LottiToolChoice? toolChoice,
  }) {
    final contents = <Map<String, dynamic>>[
      {
        'role': 'user',
        'parts': [
          {'text': prompt},
        ],
      },
    ];

    final generationConfig = <String, dynamic>{
      'temperature': temperature,
      'maxOutputTokens': ?maxTokens,
      'thinkingConfig': thinkingConfig.toJson(modelId: modelId),
    };

    final request = <String, dynamic>{
      'contents': contents,
      'generationConfig': generationConfig,
      if (tools != null && tools.isNotEmpty)
        'tools': [
          {
            'functionDeclarations': _buildFunctionDeclarations(tools),
          },
        ],
      'toolConfig': ?_buildToolConfig(toolChoice),
    };

    if (systemMessage != null && systemMessage.trim().isNotEmpty) {
      request['systemInstruction'] = {
        'role': 'system',
        'parts': [
          {'text': systemMessage},
        ],
      };
    }

    return request;
  }

  /// Builds a Gemini request body for multi-turn conversations with full history.
  ///
  /// This method supports:
  /// - Full conversation history with user, assistant, and tool messages
  /// - Thought signatures in function calls (required for Gemini 3 multi-turn)
  /// - System instructions
  /// - Thinking configuration
  /// - Function tool declarations
  ///
  /// Parameters:
  /// - [messages]: Full conversation history as OpenAI-style messages
  /// - [temperature]: Sampling temperature
  /// - [thinkingConfig]: Thinking budget and policy
  /// - [thoughtSignatures]: Map of tool call IDs to signatures (for replay)
  /// - [systemMessage]: Optional system instruction
  /// - [maxTokens]: Optional output token limit
  /// - [tools]: Optional function declarations
  /// - [toolChoice]: Optional forced/disabled/automatic function-calling mode
  static Map<String, dynamic> buildMultiTurnRequestBody({
    required List<LottiMessage> messages,
    required double temperature,
    required GeminiThinkingConfig thinkingConfig,
    Map<String, String>? thoughtSignatures,
    String? systemMessage,
    String? modelId,
    int? maxTokens,
    List<LottiTool>? tools,
    LottiToolChoice? toolChoice,
  }) {
    // Build mapping of toolCallId -> functionName from assistant messages
    // This is needed because tool responses only have the ID, not the name
    final toolCallIdToName = <String, String>{
      for (final msg in messages.whereType<LottiAssistantMessage>())
        if (msg.toolCalls != null)
          for (final tc in msg.toolCalls!) tc.id: tc.name,
    };

    final contents = <Map<String, dynamic>>[];

    for (final message in messages) {
      final converted = _convertMessageToGeminiContent(
        message,
        thoughtSignatures: thoughtSignatures,
        toolCallIdToName: toolCallIdToName,
      );
      if (converted != null) {
        contents.add(converted);
      }
    }

    final generationConfig = <String, dynamic>{
      'temperature': temperature,
      'maxOutputTokens': ?maxTokens,
      'thinkingConfig': thinkingConfig.toJson(modelId: modelId),
    };

    final request = <String, dynamic>{
      'contents': contents,
      'generationConfig': generationConfig,
      if (tools != null && tools.isNotEmpty)
        'tools': [
          {
            'functionDeclarations': _buildFunctionDeclarations(tools),
          },
        ],
      'toolConfig': ?_buildToolConfig(toolChoice),
    };

    if (systemMessage != null && systemMessage.trim().isNotEmpty) {
      request['systemInstruction'] = {
        'role': 'system',
        'parts': [
          {'text': systemMessage},
        ],
      };
    }

    return request;
  }

  /// Builds a Gemini request body for image generation with optional reference images.
  ///
  /// The Gemini image generation API (Nano Banana Pro) requires specific
  /// response modalities and generation config to output images.
  ///
  /// Reference images provide visual context to guide the generated output.
  /// Each image is included as an inline_data part before the text prompt.
  ///
  /// Parameters:
  /// - [prompt]: The text prompt describing the image to generate.
  /// - [systemMessage]: Optional system instruction for guiding generation.
  /// - [referenceImages]: Optional list of processed reference images for visual context.
  static Map<String, dynamic> buildImageGenerationRequestBody({
    required String prompt,
    String? systemMessage,
    List<ProcessedReferenceImage>? referenceImages,
  }) {
    final parts = <Map<String, dynamic>>[];

    // Add reference images first (visual context)
    if (referenceImages != null) {
      for (final refImage in referenceImages) {
        parts.add({
          'inline_data': {
            'mime_type': refImage.mimeType,
            'data': refImage.base64Data,
          },
        });
      }
    }

    // Add text prompt after images
    parts.add({'text': prompt});

    final contents = <Map<String, dynamic>>[
      {
        'role': 'user',
        'parts': parts,
      },
    ];

    final generationConfig = <String, dynamic>{
      // Request image output
      'responseModalities': ['IMAGE', 'TEXT'],
      // Image configuration for cover art
      'imageConfig': {
        // Use 16:9 aspect ratio for cover art (widescreen format)
        'aspectRatio': '16:9',
        // Use 2K resolution for Full HD quality (1920x1080 for 16:9)
        'imageSize': '2K',
      },
    };

    final request = <String, dynamic>{
      'contents': contents,
      'generationConfig': generationConfig,
    };

    if (systemMessage != null && systemMessage.trim().isNotEmpty) {
      request['systemInstruction'] = {
        'role': 'system',
        'parts': [
          {'text': systemMessage},
        ],
      };
    }

    return request;
  }

  /// Converts an OpenAI-style message to Gemini content format.
  ///
  /// Returns null for system messages (handled separately as systemInstruction).
  ///
  /// [toolCallIdToName] maps tool call IDs to function names, used for
  /// converting tool response messages (which only have ID, not name).
  static Map<String, dynamic>? _convertMessageToGeminiContent(
    LottiMessage message, {
    Map<String, String>? thoughtSignatures,
    Map<String, String>? toolCallIdToName,
  }) {
    return switch (message) {
      // System messages are sent as `systemInstruction`, and Gemini has no
      // developer role at all.
      LottiSystemMessage() || LottiDeveloperMessage() => null,
      LottiUserMessage(:final content) => {
        'role': 'user',
        'parts': [
          {
            'text': switch (content) {
              LottiUserText(:final text) => text,
              // Gemini's native API takes text only on this path; non-text
              // parts are reduced to a placeholder so the turn still reads
              // coherently.
              LottiUserParts(:final parts) =>
                parts
                    .map(
                      (part) => switch (part) {
                        LottiTextPart(:final text) => text,
                        LottiImagePart() => '[image]',
                        LottiAudioPart() => '[audio]',
                      },
                    )
                    .join(),
            },
          },
        ],
      },
      LottiAssistantMessage(:final content, :final toolCalls) =>
        _assistantContentToGemini(
          content: content,
          toolCalls: toolCalls,
          thoughtSignatures: thoughtSignatures,
        ),
      LottiToolMessage(:final toolCallId, :final content) => {
        'role': 'function',
        'parts': [
          {
            'functionResponse': {
              // Fall back to the id when the name is unknown, which should
              // not happen in a well-formed conversation.
              'name': toolCallIdToName?[toolCallId] ?? toolCallId,
              'response': {'result': content},
            },
          },
        ],
      },
    };
  }

  /// Builds the Gemini `model` turn for an assistant message, pairing each
  /// function call with its thought signature.
  ///
  /// Returns null when the turn carried neither text nor tool calls, so the
  /// caller drops it rather than sending an empty part list.
  static Map<String, dynamic>? _assistantContentToGemini({
    required String? content,
    required List<LottiToolCall>? toolCalls,
    required Map<String, String>? thoughtSignatures,
  }) {
    final parts = <Map<String, dynamic>>[];

    if (content != null && content.isNotEmpty) {
      parts.add({'text': content});
    }

    for (final toolCall in toolCalls ?? const <LottiToolCall>[]) {
      // Defensive JSON parsing for tool call arguments
      dynamic args;
      try {
        args = jsonDecode(toolCall.arguments);
      } on FormatException catch (e) {
        developer.log(
          'Failed to parse tool call arguments as JSON: ${e.message}. '
          'Using empty object. Raw: ${toolCall.arguments}',
          name: 'GeminiUtils',
        );
        args = <String, dynamic>{};
      }

      // Signature sits at part level as a sibling of functionCall; per the
      // Gemini docs it must NOT be nested inside it.
      final functionCallPart = <String, dynamic>{
        'functionCall': {'name': toolCall.name, 'args': args},
      };
      final signature = thoughtSignatures?[toolCall.id];
      if (signature != null) {
        functionCallPart['thoughtSignature'] = signature;
      }
      parts.add(functionCallPart);
    }

    if (parts.isEmpty) return null;

    return {'role': 'model', 'parts': parts};
  }

  /// Converts OpenAI-style [LottiTool] objects to Gemini
  /// `functionDeclarations`, stripping JSON Schema keywords that Gemini's
  /// native API does not support (e.g. `additionalProperties`).
  static List<Map<String, dynamic>> _buildFunctionDeclarations(
    List<LottiTool> tools,
  ) {
    return tools
        .map(
          (t) => {
            'name': t.name,
            if (t.description != null) 'description': t.description,
            if (t.parameters != null)
              'parameters': _stripAdditionalProperties(t.parameters!),
          },
        )
        .toList();
  }

  static Map<String, dynamic>? _buildToolConfig(
    LottiToolChoice? toolChoice,
  ) {
    if (toolChoice == null) return null;

    return switch (toolChoice) {
      LottiToolChoiceNone() => const {
        'functionCallingConfig': {'mode': 'NONE'},
      },
      LottiToolChoiceAuto() => const {
        'functionCallingConfig': {'mode': 'AUTO'},
      },
      LottiToolChoiceRequired() => const {
        'functionCallingConfig': {'mode': 'ANY'},
      },
      LottiToolChoiceSpecific(:final name) => {
        'functionCallingConfig': {
          'mode': 'ANY',
          'allowedFunctionNames': [name],
        },
      },
    };
  }

  /// Recursively strips `additionalProperties` from a JSON Schema map.
  ///
  /// Gemini's native API does not support the `additionalProperties` keyword
  /// in function parameter schemas and returns a 400 error when it is present.
  /// This method removes it at every nesting level (including inside `items`
  /// and `properties` sub-schemas) so that OpenAI-style tool definitions can
  /// be forwarded to Gemini without modification at the call site.
  static Map<String, dynamic> _stripAdditionalProperties(
    Map<String, dynamic> schema,
  ) {
    final result = <String, dynamic>{};
    for (final entry in schema.entries) {
      if (entry.key == 'additionalProperties') continue;

      final value = entry.value;
      if (value is Map<String, dynamic>) {
        result[entry.key] = _stripAdditionalProperties(value);
      } else if (value is List) {
        result[entry.key] = value.map((e) {
          if (e is Map<String, dynamic>) {
            return _stripAdditionalProperties(e);
          }
          return e;
        }).toList();
      } else {
        result[entry.key] = value;
      }
    }
    return result;
  }

  /// Strips leading SSE `data:` prefixes and JSON array framing tokens.
  ///
  /// Examples handled at the start of the string:
  /// - `data: { ... }`  -> `{ ... }`
  /// - `data:   [`      -> `[`
  /// - `[` or `]` or `,` (array framing) are removed until a JSON object starts
  static String stripLeadingFraming(String src) {
    var s = src;
    var progressed = true;
    while (progressed) {
      progressed = false;
      // Normalize leading whitespace each pass
      final trimmed = s.trimLeft();
      if (!identical(trimmed, s)) {
        s = trimmed;
        progressed = true;
      }

      // Remove/normalize leading SSE data: lines (only if newline present)
      if (s.startsWith('data:')) {
        final nl = s.indexOf('\n');
        if (nl == -1) {
          // Incomplete line: keep as-is until a newline arrives
          break;
        }
        // Extract payload after `data:` up to newline
        final payload = s.substring('data:'.length, nl).trimLeft();
        if (payload.isEmpty) {
          // No payload → drop the whole line
          s = s.substring(nl + 1);
        } else if (payload.startsWith('{') || payload.startsWith('[')) {
          // JSON payload on the same line → keep payload, drop the data: prefix
          s = payload + s.substring(nl + 1);
        } else {
          // Non-JSON payload (e.g., comments/heartbeats) → drop the whole line
          s = s.substring(nl + 1);
        }
        progressed = true;
        continue;
      }

      // Remove JSON array framing tokens
      if (s.isNotEmpty && (s[0] == '[' || s[0] == ']' || s[0] == ',')) {
        s = s.substring(1);
        progressed = true;
        continue;
      }
    }
    return s;
  }
}
