import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/repository/completion_usage_parser.dart';
import 'package:lotti/features/ai/repository/transcription_exception.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/util/temporary_mp3_encoder.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:uuid/uuid.dart';

typedef AudioToTemporaryMp3Encoder = Future<File> Function(Uint8List bytes);
typedef TemporaryAudioFileReader = Future<Uint8List> Function(File file);
typedef TemporaryAudioFileDeleter = void Function(File file);

/// Maximum end-to-end duration for temporary MP3 preparation and inference.
///
/// Voxtral accepts long recordings, so conversion and the buffered response
/// share a deadline that is deliberately longer than a normal chat request.
const temporaryMp3ChatAudioTimeout = Duration(minutes: 15);

/// Provider-specific JSON representation of a base64-encoded MP3 input.
enum ChatAudioPayloadDialect {
  /// OpenAI-compatible audio block used by Melious.
  openAi,

  /// Mistral's native audio block, where `input_audio` is the base64 string.
  mistral,
}

/// Diagnostics and payload behavior for one chat-audio provider.
final class TemporaryMp3ChatAudioProvider {
  const TemporaryMp3ChatAudioProvider({
    required this.repositoryName,
    required this.displayName,
    required this.requestIdPrefix,
    required this.payloadDialect,
    this.includeRequestIdInBody = false,
  });

  /// Stable provider name attached to [TranscriptionException] diagnostics.
  final String repositoryName;

  /// Human-readable provider name used in error messages.
  final String displayName;

  /// Prefix for the locally generated request correlation ID.
  final String requestIdPrefix;

  /// JSON shape required for the audio content part.
  final ChatAudioPayloadDialect payloadDialect;

  /// Whether the provider accepts Lotti's correlation ID in the JSON body.
  final bool includeRequestIdInBody;
}

/// Sends archived audio through a provider's buffered chat-audio endpoint.
///
/// The archive bytes remain unchanged. A temporary MP3 is created solely for
/// this request and deleted after success or failure. Provider repositories
/// supply only their JSON dialect and diagnostic identity, keeping conversion,
/// timeout accounting, response parsing, and cleanup identical.
Stream<CreateChatCompletionStreamResponse> transcribeTemporaryMp3ChatAudio({
  required http.Client httpClient,
  required TemporaryMp3ChatAudioProvider provider,
  required String model,
  required String audioBase64,
  required String baseUrl,
  required String apiKey,
  required String prompt,
  int? maxCompletionTokens,
  Duration timeout = temporaryMp3ChatAudioTimeout,
  AudioToTemporaryMp3Encoder audioToTemporaryMp3Encoder =
      encodeAudioBytesToTemporaryMp3,
  TemporaryAudioFileReader temporaryFileReader = _readTemporaryFile,
  TemporaryAudioFileDeleter temporaryFileDeleter = _deleteTemporaryFile,
  Clock? clockSource,
}) {
  final abortTrigger = Completer<void>();
  var canceled = false;
  late final StreamController<CreateChatCompletionStreamResponse> controller;

  Future<void> transcribe() async {
    try {
      final chunk = await _transcribeTemporaryMp3ChatAudio(
        httpClient: httpClient,
        provider: provider,
        model: model,
        audioBase64: audioBase64,
        baseUrl: baseUrl,
        apiKey: apiKey,
        prompt: prompt,
        maxCompletionTokens: maxCompletionTokens,
        timeout: timeout,
        audioToTemporaryMp3Encoder: audioToTemporaryMp3Encoder,
        temporaryFileReader: temporaryFileReader,
        temporaryFileDeleter: temporaryFileDeleter,
        clockSource: clockSource,
        abortTrigger: abortTrigger,
      );
      if (!canceled) controller.add(chunk);
    } catch (error, stackTrace) {
      if (!canceled) controller.addError(error, stackTrace);
    } finally {
      if (!canceled) await controller.close();
    }
  }

  controller = StreamController<CreateChatCompletionStreamResponse>(
    onListen: () => unawaited(transcribe()),
    onCancel: () {
      canceled = true;
      if (!abortTrigger.isCompleted) abortTrigger.complete();
    },
  );
  return controller.stream;
}

Future<CreateChatCompletionStreamResponse> _transcribeTemporaryMp3ChatAudio({
  required http.Client httpClient,
  required TemporaryMp3ChatAudioProvider provider,
  required String model,
  required String audioBase64,
  required String baseUrl,
  required String apiKey,
  required String prompt,
  required Duration timeout,
  required AudioToTemporaryMp3Encoder audioToTemporaryMp3Encoder,
  required TemporaryAudioFileReader temporaryFileReader,
  required TemporaryAudioFileDeleter temporaryFileDeleter,
  required Completer<void> abortTrigger,
  int? maxCompletionTokens,
  Clock? clockSource,
}) async {
  final normalizedModel = model.trim();
  final normalizedBaseUrl = baseUrl.trim();
  final normalizedApiKey = apiKey.trim();
  final requestClock = clockSource ?? clock;
  if (normalizedModel.isEmpty) {
    throw ArgumentError('Model name cannot be empty');
  }
  if (audioBase64.isEmpty) {
    throw ArgumentError('Audio data cannot be empty');
  }
  if (normalizedBaseUrl.isEmpty) {
    throw ArgumentError('Base URL cannot be empty');
  }
  if (normalizedApiKey.isEmpty) {
    throw ArgumentError('API key cannot be empty');
  }

  final Uint8List sourceBytes;
  try {
    sourceBytes = base64Decode(audioBase64);
  } on FormatException catch (error) {
    throw ArgumentError('Audio data must be valid base64: ${error.message}');
  }

  final requestId = '${provider.requestIdPrefix}${const Uuid().v4()}';
  File? temporaryMp3File;
  var timeoutStage = 'preparing the temporary MP3';

  try {
    final deadline = requestClock.now().add(timeout);

    Duration remainingTimeoutOrThrow() {
      final remaining = deadline.difference(requestClock.now());
      if (remaining <= Duration.zero) {
        throw TimeoutException(
          '${provider.displayName} chat-audio deadline exhausted',
        );
      }
      return remaining;
    }

    final conversionTimeout = remainingTimeoutOrThrow();
    temporaryMp3File = await audioToTemporaryMp3Encoder(
      sourceBytes,
    ).timeout(conversionTimeout);

    timeoutStage = 'reading the temporary MP3';
    final readTimeout = remainingTimeoutOrThrow();
    final mp3Bytes = await temporaryFileReader(
      temporaryMp3File,
    ).timeout(readTimeout);
    if (mp3Bytes.isEmpty) {
      throw const TemporaryMp3EncodingException(
        'Temporary MP3 encoder produced an empty file',
      );
    }

    final encodedMp3 = base64Encode(mp3Bytes);
    final body = <String, dynamic>{
      'model': normalizedModel,
      if (provider.includeRequestIdInBody) 'request_id': requestId,
      'messages': [
        {
          'role': 'user',
          'content': [
            _audioContentPart(provider.payloadDialect, encodedMp3),
            {'type': 'text', 'text': prompt},
          ],
        },
      ],
      'stream': false,
      'temperature': 0.0,
      'max_tokens': ?maxCompletionTokens,
    };

    timeoutStage = 'waiting for the Voxtral response';
    final requestTimeout = remainingTimeoutOrThrow();
    final request =
        http.AbortableRequest(
            'POST',
            _buildEndpointUri(normalizedBaseUrl, 'chat/completions'),
            abortTrigger: abortTrigger.future,
          )
          ..headers.addAll({
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $normalizedApiKey',
          })
          ..body = jsonEncode(body);
    late final http.Response response;
    try {
      response = await httpClient
          .send(request)
          .then(http.Response.fromStream)
          .timeout(
            requestTimeout,
            onTimeout: () {
              if (!abortTrigger.isCompleted) abortTrigger.complete();
              throw TimeoutException(
                '${provider.displayName} chat-audio HTTP request timed out',
              );
            },
          );
    } finally {
      if (!abortTrigger.isCompleted) abortTrigger.complete();
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TranscriptionException(
        'HTTP ${response.statusCode}: '
        '${_extractErrorMessage(response.body, response.statusCode, provider)} '
        '(request $requestId)',
        provider: provider.repositoryName,
        statusCode: response.statusCode,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw TranscriptionException(
        '${provider.displayName} returned an invalid chat-audio response '
        '(request $requestId)',
        provider: provider.repositoryName,
      );
    }

    final content = _responseContent(decoded);
    if (content.trim().isEmpty) {
      throw TranscriptionException(
        '${provider.displayName} returned no transcript for $normalizedModel '
        '(request $requestId)',
        provider: provider.repositoryName,
      );
    }

    final responseId = decoded['id'];
    final responseCreated = decoded['created'];
    final responseModel = decoded['model'];
    return CreateChatCompletionStreamResponse(
      id: responseId is String ? responseId : requestId,
      choices: [
        ChatCompletionStreamResponseChoice(
          delta: ChatCompletionStreamResponseDelta(content: content),
          index: 0,
          finishReason: ChatCompletionFinishReason.stop,
        ),
      ],
      object: 'chat.completion.chunk',
      created: responseCreated is int ? responseCreated : 0,
      model: responseModel is String ? responseModel : normalizedModel,
      usage: parseCompletionUsage(decoded['usage']),
    );
  } on TranscriptionException catch (error) {
    if (error.message.contains('(request ')) rethrow;
    final statusPrefix =
        error.statusCode != null &&
            !error.message.contains('HTTP ${error.statusCode}')
        ? 'HTTP ${error.statusCode}: '
        : '';
    throw TranscriptionException(
      '$statusPrefix${error.message} (request $requestId)',
      provider: error.provider ?? provider.repositoryName,
      statusCode: error.statusCode,
      originalError: error.originalError ?? error,
    );
  } on TimeoutException catch (error) {
    throw TranscriptionException(
      '${provider.displayName} chat-audio request timed out while '
      '$timeoutStage after ${timeout.inSeconds} seconds '
      '(request $requestId)',
      provider: provider.repositoryName,
      statusCode: httpStatusRequestTimeout,
      originalError: error,
    );
  } on FormatException catch (error) {
    throw TranscriptionException(
      '${provider.displayName} chat-audio response was not valid JSON '
      '(request $requestId)',
      provider: provider.repositoryName,
      originalError: error,
    );
  } on Exception catch (error) {
    throw TranscriptionException(
      '${provider.displayName} chat-audio request failed: $error '
      '(request $requestId)',
      provider: provider.repositoryName,
      originalError: error,
    );
  } finally {
    final file = temporaryMp3File;
    if (file != null) {
      try {
        if (file.existsSync()) temporaryFileDeleter(file);
      } on FileSystemException catch (error, stackTrace) {
        developer.log(
          'Failed to delete temporary Voxtral MP3 file',
          name: provider.repositoryName,
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
  }
}

Map<String, dynamic> _audioContentPart(
  ChatAudioPayloadDialect dialect,
  String encodedMp3,
) => switch (dialect) {
  ChatAudioPayloadDialect.openAi => {
    'type': 'input_audio',
    'input_audio': {'data': encodedMp3, 'format': 'mp3'},
  },
  ChatAudioPayloadDialect.mistral => {
    'type': 'input_audio',
    'input_audio': encodedMp3,
  },
};

String _responseContent(Map<String, dynamic> decoded) {
  final choices = decoded['choices'];
  final firstChoice = choices is List && choices.isNotEmpty
      ? choices.first
      : null;
  final message = firstChoice is Map<dynamic, dynamic>
      ? firstChoice['message']
      : null;
  final content = message is Map<dynamic, dynamic> ? message['content'] : null;
  if (content is String) return content;
  if (content is! List) return '';

  return content
      .whereType<Map<dynamic, dynamic>>()
      .map((part) => part['text'])
      .whereType<String>()
      .join();
}

Uri _buildEndpointUri(String baseUrl, String endpointPath) {
  final baseUri = Uri.parse(baseUrl);
  final basePath = baseUri.path.replaceAll(RegExp(r'/+$'), '');
  final normalizedEndpoint = endpointPath.replaceAll(RegExp('^/+'), '');
  return baseUri.replace(path: '$basePath/$normalizedEndpoint');
}

String _extractErrorMessage(
  String body,
  int statusCode,
  TemporaryMp3ChatAudioProvider provider,
) {
  final fallback = '${provider.displayName} API error (HTTP $statusCode)';
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
  return body.length > 240 ? '${body.substring(0, 240)}...' : body;
}

Future<Uint8List> _readTemporaryFile(File file) => file.readAsBytes();

void _deleteTemporaryFile(File file) => file.deleteSync();
