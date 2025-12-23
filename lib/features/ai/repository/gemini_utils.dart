import 'dart:convert';
import 'dart:developer' as developer;

import 'package:lotti/features/ai/repository/gemini_thinking_config.dart';
import 'package:openai_dart/openai_dart.dart';

/// Utilities for building Gemini HTTP requests and decoding stream framing.
///
/// Central responsibilities:
/// - Construct streaming and non-streaming URIs while preserving scheme/host/port.
/// - Build request bodies including system instructions, thinking config and tools.
/// - Strip SSE `data:` prefixes and JSON array framing from mixed-format streams.
class GeminiUtils {
  const GeminiUtils._();

  /// Builds the streaming `:streamGenerateContent` URI from a provider base URL.
  ///
  /// - Normalizes model IDs to `models/<id>`.
  /// - Ignores any existing path in `baseUrl` but preserves scheme/host/port.
  /// - Appends `?key=<apiKey>` as required by Gemini.
  static Uri buildStreamGenerateContentUri({
    required String baseUrl,
    required String model,
    required String apiKey,
  }) =>
      _buildGeminiUri(
        baseUrl: baseUrl,
        model: model,
        apiKey: apiKey,
        endpoint: 'streamGenerateContent',
      );

  /// Builds the non-streaming `:generateContent` URI (used for fallback).
  static Uri buildGenerateContentUri({
    required String baseUrl,
    required String model,
    required String apiKey,
  }) =>
      _buildGeminiUri(
        baseUrl: baseUrl,
        model: model,
        apiKey: apiKey,
        endpoint: 'generateContent',
      );

  /// Internal helper to build Gemini API URIs with the specified endpoint.
  static Uri _buildGeminiUri({
    required String baseUrl,
    required String model,
    required String apiKey,
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
    final modelPath =
        trimmed.startsWith('models/') ? trimmed : 'models/$trimmed';
    final path = '/v1beta/$modelPath:$endpoint';
    return root.replace(
      path: path,
      queryParameters: <String, String>{'key': apiKey},
    );
  }

  /// Builds a Gemini request body including thinking config and function tools.
  ///
  /// - Always includes the `prompt` as a single user message.
  /// - Adds `systemInstruction` when provided.
  /// - Serializes [GeminiThinkingConfig] into `generationConfig.thinkingConfig`.
  /// - Maps OpenAI-style [ChatCompletionTool] to Gemini `functionDeclarations`.
  static Map<String, dynamic> buildRequestBody({
    required String prompt,
    required double temperature,
    required GeminiThinkingConfig thinkingConfig,
    String? systemMessage,
    int? maxTokens,
    List<ChatCompletionTool>? tools,
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
      if (maxTokens != null) 'maxOutputTokens': maxTokens,
      'thinkingConfig': thinkingConfig.toJson(),
    };

    final request = <String, dynamic>{
      'contents': contents,
      'generationConfig': generationConfig,
      if (tools != null && tools.isNotEmpty)
        'tools': [
          {
            'functionDeclarations': tools
                .map(
                  (t) => {
                    'name': t.function.name,
                    if (t.function.description != null)
                      'description': t.function.description,
                    if (t.function.parameters != null)
                      'parameters': t.function.parameters,
                  },
                )
                .toList(),
          },
        ],
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
  static Map<String, dynamic> buildMultiTurnRequestBody({
    required List<ChatCompletionMessage> messages,
    required double temperature,
    required GeminiThinkingConfig thinkingConfig,
    Map<String, String>? thoughtSignatures,
    String? systemMessage,
    int? maxTokens,
    List<ChatCompletionTool>? tools,
  }) {
    // Build mapping of toolCallId -> functionName from assistant messages
    // This is needed because tool responses only have the ID, not the name
    final toolCallIdToName = <String, String>{
      for (final msg in messages.whereType<ChatCompletionAssistantMessage>())
        if (msg.toolCalls != null)
          for (final tc in msg.toolCalls!) tc.id: tc.function.name,
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
      if (maxTokens != null) 'maxOutputTokens': maxTokens,
      'thinkingConfig': thinkingConfig.toJson(),
    };

    final request = <String, dynamic>{
      'contents': contents,
      'generationConfig': generationConfig,
      if (tools != null && tools.isNotEmpty)
        'tools': [
          {
            'functionDeclarations': tools
                .map(
                  (t) => {
                    'name': t.function.name,
                    if (t.function.description != null)
                      'description': t.function.description,
                    if (t.function.parameters != null)
                      'parameters': t.function.parameters,
                  },
                )
                .toList(),
          },
        ],
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
    ChatCompletionMessage message, {
    Map<String, String>? thoughtSignatures,
    Map<String, String>? toolCallIdToName,
  }) {
    return message.map(
      system: (_) => null, // System messages handled separately
      user: (user) {
        final content = user.content;
        return {
          'role': 'user',
          'parts': [
            {
              'text': content.map(
                string: (s) => s.value,
                parts: (p) {
                  // Extract text from content parts using toJson()
                  final textParts = <String>[];
                  for (final part in p.value) {
                    final partMap = part.toJson();
                    if (partMap['type'] == 'text') {
                      final text = partMap['text'];
                      if (text is String && text.isNotEmpty) {
                        textParts.add(text);
                      }
                    }
                    // For images, audio, files - add placeholder
                    else if (partMap['type'] == 'image_url') {
                      textParts.add('[image]');
                    } else if (partMap['type'] == 'input_audio') {
                      textParts.add('[audio]');
                    } else if (partMap['type'] == 'file') {
                      textParts.add('[file]');
                    }
                  }
                  return textParts.join();
                },
              ),
            },
          ],
        };
      },
      assistant: (assistant) {
        final parts = <Map<String, dynamic>>[];

        // Add text content if present
        if (assistant.content != null && assistant.content!.isNotEmpty) {
          parts.add({'text': assistant.content});
        }

        // Add function calls with signatures if present
        if (assistant.toolCalls != null) {
          for (final toolCall in assistant.toolCalls!) {
            // Defensive JSON parsing for tool call arguments
            dynamic args;
            try {
              args = jsonDecode(toolCall.function.arguments);
            } on FormatException catch (e) {
              developer.log(
                'Failed to parse tool call arguments as JSON: ${e.message}. '
                'Using empty object. Raw: ${toolCall.function.arguments}',
                name: 'GeminiUtils',
              );
              args = <String, dynamic>{};
            }

            // Build function call part - signature is at part level as sibling
            final functionCallPart = <String, dynamic>{
              'functionCall': {'name': toolCall.function.name, 'args': args},
            };

            // Include thought signature at part level (sibling of functionCall)
            // Per Gemini docs, signature must NOT be nested inside functionCall
            final signature = thoughtSignatures?[toolCall.id];
            if (signature != null) {
              functionCallPart['thoughtSignature'] = signature;
            }

            parts.add(functionCallPart);
          }
        }

        if (parts.isEmpty) return null;

        return {'role': 'model', 'parts': parts};
      },
      tool: (tool) {
        // Look up the function name from the mapping, fall back to toolCallId
        // if not found (shouldn't happen in well-formed conversations)
        final functionName =
            toolCallIdToName?[tool.toolCallId] ?? tool.toolCallId;
        return {
          'role': 'function',
          'parts': [
            {
              'functionResponse': {
                'name': functionName,
                'response': {'result': tool.content},
              },
            },
          ],
        };
      },
      function: (func) {
        // Legacy function message format - convert to tool format
        return {
          'role': 'function',
          'parts': [
            {
              'functionResponse': {
                'name': func.name,
                'response': {'result': func.content ?? ''},
              },
            },
          ],
        };
      },
      developer: (_) => null, // Not supported by Gemini
    );
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
