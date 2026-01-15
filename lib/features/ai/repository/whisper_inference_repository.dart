import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/services/whisper_server_manager.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:openai_dart/openai_dart.dart';

/// Mode for whisper transcription backend
enum WhisperBackendMode {
  /// whisper.cpp server (native binary, multipart upload)
  whisperCpp,

  /// Python whisper_api_server.py (JSON with base64)
  pythonServer,
}

/// Repository for handling Whisper-specific inference operations
///
/// This repository handles audio transcription using a locally running
/// Whisper instance. Supports both:
/// - whisper.cpp server (native, faster, used in Flatpak)
/// - Python whisper_api_server.py (development, legacy)
class WhisperInferenceRepository {
  WhisperInferenceRepository({
    http.Client? httpClient,
    WhisperServerManager? serverManager,
    WhisperBackendMode? backendMode,
  })  : _httpClient = httpClient ?? http.Client(),
        _serverManager = serverManager,
        _backendMode = backendMode ?? WhisperBackendMode.whisperCpp;

  final http.Client _httpClient;
  final WhisperServerManager? _serverManager;
  final WhisperBackendMode _backendMode;

  /// Transcribes audio using a locally running Whisper instance
  ///
  /// This method sends audio data to a local Whisper server for transcription.
  ///
  /// Args:
  ///   model: The Whisper model to use (e.g., 'whisper-1')
  ///   audioBase64: Base64 encoded audio data
  ///   baseUrl: The base URL of the local Whisper server
  ///   prompt: Optional text prompt for context (not used by Whisper)
  ///   maxCompletionTokens: Optional token limit (not used by Whisper)
  ///   timeout: Optional timeout override (defaults to whisperTranscriptionTimeoutSeconds)
  ///
  /// Returns:
  ///   Stream of chat completion responses containing the transcribed text
  ///
  /// Throws:
  ///   ArgumentError if required parameters are empty
  ///   WhisperTranscriptionException if transcription fails
  Stream<CreateChatCompletionStreamResponse> transcribeAudio({
    required String model,
    required String audioBase64,
    required String baseUrl,
    String? prompt,
    int? maxCompletionTokens,
    Duration? timeout,
  }) {
    // Validate required inputs consistently
    if (model.isEmpty) {
      throw ArgumentError('Model name cannot be empty');
    }
    if (baseUrl.isEmpty) {
      throw ArgumentError('Base URL cannot be empty');
    }

    // Use provided timeout or default
    final requestTimeout =
        timeout ?? const Duration(seconds: whisperTranscriptionTimeoutSeconds);

    // Define timeout error message once to avoid duplication
    final timeoutMinutes = requestTimeout.inMinutes;
    final timeoutErrorMessage = 'Transcription request timed out after '
        '${timeoutMinutes == 1 ? '1 minute' : '$timeoutMinutes minutes'}. '
        'This can happen with very long audio files or slow processing. '
        'Please try with a shorter recording or check your Whisper server performance.';

    // Create a stream that performs the async transcription operation
    return Stream.fromFuture(
      () async {
        try {
          developer.log(
            'Sending audio transcription request - '
            'backend: $_backendMode, baseUrl: $baseUrl, model: $model, '
            'audioLength: ${audioBase64.length}, timeout: $timeoutMinutes min',
            name: 'WhisperInferenceRepository',
          );

          final text = switch (_backendMode) {
            WhisperBackendMode.whisperCpp => await _transcribeWithWhisperCpp(
                audioBase64: audioBase64,
                baseUrl: baseUrl,
                timeout: requestTimeout,
                timeoutErrorMessage: timeoutErrorMessage,
              ),
            WhisperBackendMode.pythonServer =>
              await _transcribeWithPythonServer(
                model: model,
                audioBase64: audioBase64,
                baseUrl: baseUrl,
                timeout: requestTimeout,
                timeoutErrorMessage: timeoutErrorMessage,
              ),
          };

          developer.log(
            'Successfully transcribed audio - transcriptionLength: ${text.length}',
            name: 'WhisperInferenceRepository',
          );

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
        } on WhisperTranscriptionException {
          rethrow;
        } on TimeoutException catch (e) {
          developer.log(
            'Transcription request timed out',
            name: 'WhisperInferenceRepository',
            error: e,
          );
          throw WhisperTranscriptionException(
            timeoutErrorMessage,
            statusCode: httpStatusRequestTimeout,
            originalError: e,
          );
        } on FormatException catch (e) {
          developer.log(
            'Failed to parse response from Whisper server',
            name: 'WhisperInferenceRepository',
            error: e,
          );
          throw WhisperTranscriptionException(
            'Invalid response format from transcription service',
            originalError: e,
          );
        } catch (e) {
          developer.log(
            'Unexpected error during audio transcription',
            name: 'WhisperInferenceRepository',
            error: e,
          );
          throw WhisperTranscriptionException(
            'Failed to transcribe audio: $e',
            originalError: e,
          );
        }
      }(),
    ).asBroadcastStream();
  }

  /// Transcribes audio using whisper.cpp server (multipart form upload)
  Future<String> _transcribeWithWhisperCpp({
    required String audioBase64,
    required String baseUrl,
    required Duration timeout,
    required String timeoutErrorMessage,
  }) async {
    // Ensure server is running if we have a manager
    final serverManager = _serverManager;
    if (serverManager != null) {
      final result = await serverManager.ensureRunning();
      if (!result.success) {
        throw WhisperTranscriptionException(
          'Failed to start Whisper server: ${result.message}',
        );
      }
    }

    // Decode base64 to bytes
    final audioBytes = base64Decode(audioBase64);

    // Create multipart request
    final uri = Uri.parse(baseUrl).resolve('/inference');
    final request = http.MultipartRequest('POST', uri);

    // Add audio file
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        audioBytes,
        filename: 'audio.wav',
      ),
    );

    // Add optional parameters
    request.fields['temperature'] = '0.0';
    request.fields['response_format'] = 'json';

    // Send request
    final streamedResponse = await request.send().timeout(
      timeout,
      onTimeout: () {
        throw WhisperTranscriptionException(
          timeoutErrorMessage,
          statusCode: httpStatusRequestTimeout,
        );
      },
    );

    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      developer.log(
        'whisper.cpp transcription failed: HTTP ${response.statusCode}',
        name: 'WhisperInferenceRepository',
        error: response.body,
      );
      throw WhisperTranscriptionException(
        'Failed to transcribe audio (HTTP ${response.statusCode}). '
        'Please check your audio file and try again.',
        statusCode: response.statusCode,
      );
    }

    final result = jsonDecode(response.body) as Map<String, dynamic>;

    // whisper.cpp returns {"text": "..."} format
    if (!result.containsKey('text')) {
      developer.log(
        'Invalid response from whisper.cpp: missing text field',
        name: 'WhisperInferenceRepository',
        error: result,
      );
      throw WhisperTranscriptionException(
        'Invalid response from transcription service: missing text field',
      );
    }

    return result['text'] as String;
  }

  /// Transcribes audio using Python whisper_api_server.py (JSON with base64)
  Future<String> _transcribeWithPythonServer({
    required String model,
    required String audioBase64,
    required String baseUrl,
    required Duration timeout,
    required String timeoutErrorMessage,
  }) async {
    final response = await _httpClient
        .post(
      Uri.parse(baseUrl).resolve('/v1/audio/transcriptions'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': model,
        'audio': audioBase64,
      }),
    )
        .timeout(
      timeout,
      onTimeout: () {
        throw WhisperTranscriptionException(
          timeoutErrorMessage,
          statusCode: httpStatusRequestTimeout,
        );
      },
    );

    if (response.statusCode != 200) {
      developer.log(
        'Python server transcription failed: HTTP ${response.statusCode}',
        name: 'WhisperInferenceRepository',
        error: response.body,
      );
      throw WhisperTranscriptionException(
        'Failed to transcribe audio (HTTP ${response.statusCode}). '
        'Please check your audio file and try again.',
        statusCode: response.statusCode,
      );
    }

    final result = jsonDecode(response.body) as Map<String, dynamic>;

    if (!result.containsKey('text')) {
      developer.log(
        'Invalid response from Python server: missing text field',
        name: 'WhisperInferenceRepository',
        error: result,
      );
      throw WhisperTranscriptionException(
        'Invalid response from transcription service: missing text field',
      );
    }

    return result['text'] as String;
  }
}

/// Exception thrown when Whisper transcription fails
class WhisperTranscriptionException implements Exception {
  WhisperTranscriptionException(
    this.message, {
    this.statusCode,
    this.originalError,
  });

  final String message;
  final int? statusCode;
  final Object? originalError;

  @override
  String toString() => 'WhisperTranscriptionException: $message';
}
