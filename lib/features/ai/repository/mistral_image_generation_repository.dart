import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/repository/gemini_inference_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';

/// Repository for generating images via Mistral's Agents/Conversations API.
///
/// Mistral provides image generation through a built-in tool powered by
/// Black Forest Labs FLUX1.1 pro Ultra. The workflow requires three steps:
/// 1. Create an Agent with the `image_generation` tool enabled
/// 2. Start a Conversation with the agent to generate the image
/// 3. Download the generated image file via the Files API
///
/// This ensures all data stays within Mistral's EU infrastructure (Paris),
/// supporting data sovereignty requirements.
///
/// See also: [GeneratedImage] for the return type.
class MistralImageGenerationRepository {
  MistralImageGenerationRepository({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  /// The model used by the agent for prompt interpretation.
  /// The actual image generation is always done by FLUX1.1 pro Ultra.
  static const defaultAgentModel = 'mistral-medium-latest';

  /// Timeout for agent creation (lightweight operation).
  static const agentCreationTimeout = Duration(seconds: 30);

  /// Timeout for image generation conversation (can take time).
  static const conversationTimeout = Duration(seconds: 180);

  /// Timeout for downloading the generated image file.
  static const fileDownloadTimeout = Duration(seconds: 60);

  /// Fallback MIME type when the server doesn't provide Content-Type.
  static const _defaultMimeType = 'image/png';

  /// Generates an image using Mistral's Agents API with the image_generation
  /// tool.
  ///
  /// Parameters:
  /// - [prompt]: The text prompt describing the image to generate.
  /// - [baseUrl]: The Mistral API base URL (e.g., 'https://api.mistral.ai/v1').
  /// - [apiKey]: The Mistral API key for authentication.
  /// - [model]: The model for prompt interpretation (defaults to
  ///   `defaultAgentModel`).
  /// - [systemMessage]: Optional instructions for the agent.
  ///
  /// Returns a [GeneratedImage] containing the PNG image bytes and MIME type.
  /// Throws [MistralImageGenerationException] on failure.
  Future<GeneratedImage> generateImage({
    required String prompt,
    required String baseUrl,
    required String apiKey,
    String? model,
    String? systemMessage,
  }) async {
    if (prompt.isEmpty) {
      throw ArgumentError.value(prompt, 'prompt', 'must not be empty');
    }
    if (baseUrl.isEmpty) {
      throw ArgumentError.value(baseUrl, 'baseUrl', 'must not be empty');
    }
    if (apiKey.isEmpty) {
      throw ArgumentError.value(apiKey, 'apiKey', 'must not be empty');
    }

    final effectiveModel = model ?? defaultAgentModel;
    String? agentId;

    try {
      // Step 1: Create an ephemeral agent with the image_generation tool
      agentId = await _createAgent(
        model: effectiveModel,
        baseUrl: baseUrl,
        apiKey: apiKey,
        instructions: systemMessage,
      );

      developer.log(
        'Created Mistral agent: $agentId',
        name: 'MistralImageGeneration',
      );

      // Step 2: Start a conversation to generate the image
      final fileId = await _startConversation(
        agentId: agentId,
        prompt: prompt,
        baseUrl: baseUrl,
        apiKey: apiKey,
      );

      developer.log(
        'Image generated, file ID: $fileId',
        name: 'MistralImageGeneration',
      );

      // Step 3: Download the generated image
      final download = await _downloadFile(
        fileId: fileId,
        baseUrl: baseUrl,
        apiKey: apiKey,
      );

      developer.log(
        'Downloaded image: ${download.bytes.length} bytes, '
        'mimeType: ${download.mimeType}',
        name: 'MistralImageGeneration',
      );

      return GeneratedImage(
        bytes: download.bytes,
        mimeType: download.mimeType,
      );
    } on MistralImageGenerationException {
      rethrow;
    } catch (e, stackTrace) {
      developer.log(
        'Mistral image generation failed: $e',
        name: 'MistralImageGeneration',
        error: e,
        stackTrace: stackTrace,
      );
      _logException(e, subDomain: 'generateImage', stackTrace: stackTrace);
      throw MistralImageGenerationException(
        'Image generation failed: $e',
        originalError: e,
      );
    } finally {
      // Best-effort cleanup: delete the ephemeral agent
      if (agentId != null) {
        await _deleteAgent(agentId: agentId, baseUrl: baseUrl, apiKey: apiKey);
      }
    }
  }

  /// Creates a Mistral Agent with the `image_generation` tool.
  ///
  /// Returns the created agent's ID.
  Future<String> _createAgent({
    required String model,
    required String baseUrl,
    required String apiKey,
    String? instructions,
  }) async {
    final uri = _buildUri(baseUrl, 'agents');
    final body = <String, dynamic>{
      'model': model,
      'name': 'lotti_cover_art_${DateTime.now().millisecondsSinceEpoch}',
      'tools': [
        {'type': 'image_generation'},
      ],
      if (instructions != null && instructions.isNotEmpty)
        'instructions': instructions,
    };

    final response = await _postJson(uri, body, apiKey, agentCreationTimeout);
    final decoded = _decodeJsonResponse(response, 'agent creation');

    final agentId = decoded['id'] as String?;
    if (agentId == null || agentId.isEmpty) {
      throw MistralImageGenerationException(
        'Agent creation response missing "id" field',
      );
    }

    return agentId;
  }

  /// Starts a conversation with the agent to generate an image.
  ///
  /// Parses the response entries for a `tool_file` content chunk and returns
  /// the `file_id` of the generated image.
  Future<String> _startConversation({
    required String agentId,
    required String prompt,
    required String baseUrl,
    required String apiKey,
  }) async {
    final uri = _buildUri(baseUrl, 'conversations');
    final body = <String, dynamic>{
      'agent_id': agentId,
      'inputs': prompt,
      'stream': false,
    };

    final response = await _postJson(uri, body, apiKey, conversationTimeout);
    final decoded = _decodeJsonResponse(response, 'conversation');

    return _extractFileId(decoded);
  }

  /// Downloads a file from the Mistral Files API.
  ///
  /// Returns the raw bytes and the Content-Type reported by the server.
  Future<({List<int> bytes, String mimeType})> _downloadFile({
    required String fileId,
    required String baseUrl,
    required String apiKey,
  }) async {
    final uri = _buildUri(baseUrl, 'files/$fileId/content');

    final response = await _httpClient
        .get(uri, headers: _authHeaders(apiKey))
        .timeout(fileDownloadTimeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MistralImageGenerationException(
        'File download failed (HTTP ${response.statusCode}): '
        '${response.body}',
        statusCode: response.statusCode,
      );
    }

    if (response.bodyBytes.isEmpty) {
      throw MistralImageGenerationException(
        'Downloaded file is empty for file ID: $fileId',
      );
    }

    final mimeType = response.headers['content-type'] ?? _defaultMimeType;

    return (bytes: response.bodyBytes, mimeType: mimeType);
  }

  /// Deletes an agent (best-effort cleanup, errors are logged but not thrown).
  Future<void> _deleteAgent({
    required String agentId,
    required String baseUrl,
    required String apiKey,
  }) async {
    try {
      final uri = _buildUri(baseUrl, 'agents/$agentId');
      await _httpClient
          .delete(uri, headers: _authHeaders(apiKey))
          .timeout(agentCreationTimeout);

      developer.log(
        'Deleted agent: $agentId',
        name: 'MistralImageGeneration',
      );
    } catch (e) {
      developer.log(
        'Failed to delete agent $agentId (non-critical): $e',
        name: 'MistralImageGeneration',
      );
    }
  }

  /// Extracts the file_id from a conversation response.
  ///
  /// The response contains `outputs` (or `entries`) with content chunks.
  /// We look for a chunk with `type: "tool_file"` and extract its `file_id`.
  String _extractFileId(Map<String, dynamic> response) {
    // The conversation response has an 'outputs' field containing entries
    final outputs = response['outputs'] as List<dynamic>?;
    if (outputs != null) {
      for (final output in outputs) {
        final fileId = _findFileIdInEntry(output);
        if (fileId != null) return fileId;
      }
    }

    // Also check 'entries' as an alternative response format
    final entries = response['entries'] as List<dynamic>?;
    if (entries != null) {
      for (final entry in entries) {
        final fileId = _findFileIdInEntry(entry);
        if (fileId != null) return fileId;
      }
    }

    throw MistralImageGenerationException(
      'No generated image file found in conversation response. '
      'Response keys: ${response.keys.join(', ')}',
    );
  }

  /// Searches an entry/output object for a tool_file chunk with a file_id.
  String? _findFileIdInEntry(dynamic entry) {
    if (entry is! Map<String, dynamic>) return null;

    // Check content chunks directly
    final content = entry['content'] as List<dynamic>?;
    if (content != null) {
      for (final chunk in content) {
        if (chunk is Map<String, dynamic>) {
          if (chunk['type'] == 'tool_file') {
            final fileId = chunk['file_id'] as String?;
            if (fileId != null && fileId.isNotEmpty) return fileId;
          }
        }
      }
    }

    // Check nested message content
    final message = entry['message'] as Map<String, dynamic>?;
    if (message != null) {
      final messageContent = message['content'] as List<dynamic>?;
      if (messageContent != null) {
        for (final chunk in messageContent) {
          if (chunk is Map<String, dynamic>) {
            if (chunk['type'] == 'tool_file') {
              final fileId = chunk['file_id'] as String?;
              if (fileId != null && fileId.isNotEmpty) return fileId;
            }
          }
        }
      }
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // HTTP helpers
  // ---------------------------------------------------------------------------

  Uri _buildUri(String baseUrl, String path) {
    final base = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    return Uri.parse('$base$path');
  }

  Map<String, String> _authHeaders(String apiKey) => {
        'Authorization': 'Bearer $apiKey',
        'Accept': 'application/json',
      };

  Future<http.Response> _postJson(
    Uri uri,
    Map<String, dynamic> body,
    String apiKey,
    Duration timeout,
  ) async {
    final response = await _httpClient
        .post(
          uri,
          headers: {
            ..._authHeaders(apiKey),
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(timeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errorMessage = _parseErrorMessage(response.body);
      throw MistralImageGenerationException(
        'HTTP ${response.statusCode}: $errorMessage',
        statusCode: response.statusCode,
      );
    }

    return response;
  }

  Map<String, dynamic> _decodeJsonResponse(
    http.Response response,
    String context,
  ) {
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException catch (e) {
      throw MistralImageGenerationException(
        'Invalid JSON in $context response: ${e.message}',
        originalError: e,
      );
    }
  }

  String _parseErrorMessage(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      return json['message'] as String? ??
          json['detail'] as String? ??
          json['error'] as String? ??
          body;
    } catch (_) {
      return body;
    }
  }

  void _logException(
    Object exception, {
    required String subDomain,
    StackTrace? stackTrace,
  }) {
    if (getIt.isRegistered<LoggingService>()) {
      getIt<LoggingService>().captureException(
        exception,
        domain: 'MISTRAL_IMAGE',
        subDomain: subDomain,
        stackTrace: stackTrace,
      );
    }
  }
}

/// Exception thrown when Mistral image generation operations fail.
class MistralImageGenerationException implements Exception {
  MistralImageGenerationException(
    this.message, {
    this.statusCode,
    this.originalError,
  });

  final String message;
  final int? statusCode;
  final Object? originalError;

  @override
  String toString() => 'MistralImageGenerationException: $message';
}
