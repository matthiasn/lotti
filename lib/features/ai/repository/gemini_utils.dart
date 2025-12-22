import 'package:lotti/features/ai/repository/gemini_thinking_config.dart';
import 'package:openai_dart/openai_dart.dart';

/// Utilities for building Gemini HTTP requests and decoding stream framing.
///
/// Central responsibilities:
/// - Detect flash models to control thought visibility policy.
/// - Construct streaming and non-streaming URIs while preserving scheme/host/port.
/// - Build request bodies including system instructions, thinking config and tools.
/// - Strip SSE `data:` prefixes and JSON array framing from mixed-format streams.
class GeminiUtils {
  const GeminiUtils._();

  /// Returns true if the model ID denotes a Gemini "flash" variant.
  ///
  /// Flash models should never surface `<thinking>` blocks in the UI.
  static bool isFlashModel(String modelId) {
    final m = modelId.toLowerCase();
    return m.contains('flash');
  }

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
                .map((t) => {
                      'name': t.function.name,
                      if (t.function.description != null)
                        'description': t.function.description,
                      if (t.function.parameters != null)
                        'parameters': t.function.parameters,
                    })
                .toList(),
          }
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
