import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/inference_repository_interface.dart';
import 'package:openai_dart/openai_dart.dart';

/// Repository for Gemma-specific inference operations
///
/// This class handles all Gemma-related functionality including:
/// - Audio transcription with context support
/// - Text generation
/// - Model management (installation, checking, warm-up)
/// - Streaming responses
class GemmaInferenceRepository implements InferenceRepositoryInterface {
  GemmaInferenceRepository({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  /// Generate text using Gemma's chat API
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
    return _generateTextWithChat(
      prompt: prompt,
      model: model,
      temperature: temperature,
      systemMessage: systemMessage,
      provider: provider,
      maxCompletionTokens: maxCompletionTokens,
    );
  }

  /// Generate text with full conversation history
  @override
  Stream<CreateChatCompletionStreamResponse> generateTextWithMessages({
    required List<ChatCompletionMessage> messages,
    required String model,
    required double temperature,
    required AiConfigInferenceProvider provider,
    int? maxCompletionTokens,
    List<ChatCompletionTool>? tools,
  }) {
    // Convert messages to Gemma format
    final gemmaMessages = messages.map((msg) {
      final content = msg.content;
      String? contentStr;

      if (content is ChatCompletionUserMessageContent) {
        contentStr = content.toString();
      } else if (content is String) {
        contentStr = content;
      } else if (content != null) {
        contentStr = jsonEncode(content);
      }

      return <String, dynamic>{
        'role': msg.role.name,
        'content': contentStr ?? '',
      };
    }).toList();

    final requestBody = {
      'model': model,
      'messages': gemmaMessages,
      'stream': true,
      'temperature': temperature,
      if (maxCompletionTokens != null) 'max_tokens': maxCompletionTokens,
    };

    return _streamChatRequest(
      requestBody: requestBody,
      provider: provider,
      model: model,
    );
  }

  /// Transcribe audio with optional context using Gemma
  @override
  Stream<CreateChatCompletionStreamResponse> transcribeAudio({
    required String audioBase64,
    required String model,
    required double temperature,
    required AiConfigInferenceProvider provider,
    String? contextPrompt,
    String? language,
    int? maxCompletionTokens,
  }) {
    developer.log(
      'Preparing Gemma audio transcription request',
      name: 'GemmaInferenceRepository',
    );

    final requestBody = {
      'audio': audioBase64,
      'model': model,
      'prompt': contextPrompt,
      'temperature': temperature,
      'language': language,
      'stream': false,  // Changed to non-streaming for better context handling
      'response_format': 'json',
      if (maxCompletionTokens != null) 'max_tokens': maxCompletionTokens,
    };

    // Use non-streaming request for transcription
    return _nonStreamTranscriptionRequest(
      requestBody: requestBody,
      provider: provider,
      model: model,
    );
  }

  /// Generate text using Gemma's chat API
  Stream<CreateChatCompletionStreamResponse> _generateTextWithChat({
    required String prompt,
    required String model,
    required double temperature,
    required AiConfigInferenceProvider provider,
    String? systemMessage,
    int? maxCompletionTokens,
  }) {
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
      'stream': true,
      'temperature': temperature,
      if (maxCompletionTokens != null) 'max_tokens': maxCompletionTokens,
    };

    return _streamChatRequest(
      requestBody: requestBody,
      provider: provider,
      model: model,
    );
  }

  /// Stream Gemma chat API responses
  Stream<CreateChatCompletionStreamResponse> _streamChatRequest({
    required Map<String, dynamic> requestBody,
    required AiConfigInferenceProvider provider,
    String? model,
  }) async* {
    try {
      final request = await _httpClient
          .send(
            http.Request(
              'POST',
              Uri.parse('${provider.baseUrl}/v1/chat/completions'),
            )
              ..headers['Content-Type'] = 'application/json'
              ..body = jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 120));

      if (request.statusCode != 200) {
        final responseBody = await request.stream.bytesToString();
        if (request.statusCode == 404 &&
            responseBody.contains('not downloaded')) {
          throw ModelNotInstalledException(model ?? 'gemma');
        }
        throw Exception(
            'Gemma API request failed with status ${request.statusCode}: $responseBody');
      }

      // Process streaming response
      await for (final chunk in request.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (chunk.isEmpty || !chunk.startsWith('data: ')) continue;

        final data = chunk.substring(6); // Remove 'data: ' prefix
        if (data == '[DONE]') break;

        try {
          final json = jsonDecode(data) as Map<String, dynamic>;

          // Convert Gemma response to OpenAI format
          if (json['choices'] != null) {
            yield CreateChatCompletionStreamResponse.fromJson(json);
          }
        } catch (e) {
          developer.log(
            'Error parsing Gemma response chunk: $chunk',
            error: e,
            name: 'GemmaInferenceRepository',
          );
        }
      }
    } catch (e) {
      if (e is ModelNotInstalledException) {
        rethrow;
      }
      throw Exception('Gemma inference error: $e');
    }
  }

  /// Non-streaming Gemma transcription request
  Stream<CreateChatCompletionStreamResponse> _nonStreamTranscriptionRequest({
    required Map<String, dynamic> requestBody,
    required AiConfigInferenceProvider provider,
    String? model,
  }) async* {
    try {
      developer.log(
        'Sending non-streaming transcription request to ${provider.baseUrl}/v1/audio/transcriptions',
        name: 'GemmaInferenceRepository',
      );
      
      final response = await _httpClient
          .post(
            Uri.parse('${provider.baseUrl}/v1/audio/transcriptions'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 600)); // Extended timeout for long audio processing

      developer.log(
        'Received response: status=${response.statusCode}, body length=${response.body.length}',
        name: 'GemmaInferenceRepository',
      );

      if (response.statusCode != 200) {
        if (response.statusCode == 404 &&
            response.body.contains('not downloaded')) {
          throw ModelNotInstalledException(model ?? 'gemma');
        }
        throw Exception(
            'Gemma transcription failed with status ${response.statusCode}: ${response.body}');
      }

      // Parse the non-streaming response
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      
      developer.log(
        'Parsed response: ${json.keys.join(", ")}',
        name: 'GemmaInferenceRepository',
      );
      
      // Convert to chat completion format for compatibility
      if (json['text'] != null) {
        yield CreateChatCompletionStreamResponse(
          id: 'gemma-${DateTime.now().millisecondsSinceEpoch}',
          choices: [
            ChatCompletionStreamResponseChoice(
              delta: ChatCompletionStreamResponseDelta(
                content: json['text'] as String,
              ),
              index: 0,
            ),
          ],
          object: 'chat.completion.chunk',
          created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        );
      }
    } catch (e) {
      if (e is ModelNotInstalledException) {
        rethrow;
      }
      throw Exception('Gemma transcription error: $e');
    }
  }


  /// Check if model is available
  Future<bool> isModelAvailable(String baseUrl) async {
    try {
      final response = await _httpClient
          .get(Uri.parse('$baseUrl/v1/models'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return false;
      }

      final result = jsonDecode(response.body) as Map<String, dynamic>;
      final models = result['data'] as List<dynamic>? ?? [];

      return models.isNotEmpty;
    } catch (e) {
      developer.log(
        'Error checking Gemma model availability',
        error: e,
        name: 'GemmaInferenceRepository',
      );
      return false;
    }
  }

  /// Install/download model
  Stream<GemmaPullProgress> installModel(
      String modelName, String baseUrl) async* {
    final request = http.Request(
      'POST',
      Uri.parse('$baseUrl/v1/models/pull'),
    );
    request.headers['Content-Type'] = 'application/json';
    request.body = jsonEncode({'model_name': modelName, 'stream': true});

    final streamedResponse =
        await _httpClient.send(request).timeout(const Duration(minutes: 30));

    if (streamedResponse.statusCode != 200) {
      throw Exception('Failed to start model download');
    }

    await for (final chunk in streamedResponse.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      if (chunk.isEmpty || !chunk.startsWith('data: ')) continue;

      final data = chunk.substring(6);
      if (data == '[DONE]') break;

      try {
        final json = jsonDecode(data) as Map<String, dynamic>;
        yield GemmaPullProgress(
          status: json['status'] as String? ?? '',
          total: json['total'] as int? ?? 0,
          completed: json['completed'] as int? ?? 0,
          progress: json['progress'] as double? ?? 0.0,
        );
      } catch (e) {
        developer.log('Error parsing download progress: $e',
            name: 'GemmaInferenceRepository');
      }
    }
  }

  /// Warm up model
  Future<void> warmUpModel(String baseUrl) async {
    try {
      await _httpClient.post(
        Uri.parse('$baseUrl/v1/models/load'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 60));
    } catch (e) {
      developer.log(
        'Warning: Model warm-up failed',
        error: e,
        name: 'GemmaInferenceRepository',
      );
    }
  }
}

/// Exception thrown when model is not installed
class ModelNotInstalledException implements Exception {
  const ModelNotInstalledException(this.modelName);

  final String modelName;

  @override
  String toString() =>
      'Gemma model "$modelName" is not downloaded. Please install it first.';
}

/// Progress information for model download
class GemmaPullProgress {
  const GemmaPullProgress({
    required this.status,
    required this.total,
    required this.completed,
    required this.progress,
  });

  final String status;
  final int total;
  final int completed;
  final double progress;

  String get progressPercentage => '${(progress * 100).toStringAsFixed(1)}%';

  String get downloadProgress {
    if (total == 0) return status;
    final totalMB = (total / (1024 * 1024)).toStringAsFixed(1);
    final completedMB = (completed / (1024 * 1024)).toStringAsFixed(1);
    return '$status: $completedMB MB / $totalMB MB ($progressPercentage)';
  }
}
