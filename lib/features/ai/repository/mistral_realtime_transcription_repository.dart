import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:lotti/features/ai/model/realtime_transcription_event.dart';
import 'package:lotti/features/ai/repository/transcription_exception.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// WebSocket client for Mistral's Voxtral real-time transcription API.
///
/// Connects to `wss://api.mistral.ai/v1/audio/transcriptions/realtime`
/// (derived from the provider's base URL) and streams PCM audio chunks
/// for live transcription with ~2 second latency.
///
/// This class is standalone — it does not extend `TranscriptionRepository`
/// since the base class is designed for HTTP request-response, not WebSocket
/// streams.
class MistralRealtimeTranscriptionRepository {
  /// Creates a repository with an optional [channelFactory] for testing.
  ///
  /// In production, [IOWebSocketChannel.connect] is used to support the
  /// `Authorization` header. Tests inject a factory that returns a fake
  /// channel.
  MistralRealtimeTranscriptionRepository({
    WebSocketChannel Function(Uri uri)? channelFactory,
  }) : _channelFactory = channelFactory;

  static const _providerName = 'Mistral Realtime';
  static const _logName = 'MistralRealtimeTranscription';

  final WebSocketChannel Function(Uri uri)? _channelFactory;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _channelSubscription;

  final _deltaController = StreamController<String>.broadcast();
  final _languageController = StreamController<String>.broadcast();
  final _doneController =
      StreamController<RealtimeTranscriptionDone>.broadcast();
  final _errorController =
      StreamController<RealtimeTranscriptionError>.broadcast();

  bool _isConnected = false;
  bool _disposed = false;
  Completer<void>? _sessionCreatedCompleter;

  /// Whether the WebSocket is currently connected and ready.
  bool get isConnected => _isConnected;

  /// Checks if a model ID is a Mistral real-time transcription model.
  ///
  /// Matches model IDs containing `transcribe-realtime` (e.g.,
  /// `voxtral-mini-transcribe-realtime-2602`). More specific than just
  /// `realtime` to avoid false positives on unrelated model IDs.
  static bool isRealtimeModel(String model) {
    return model.contains('transcribe-realtime');
  }

  /// Derives the WebSocket URL from a provider's base URL.
  ///
  /// Rules:
  /// 1. Strip trailing `/v1` or `/v1/` to normalize
  /// 2. Replace scheme: `https` → `wss`, `http` → `ws`
  /// 3. Append `/v1/audio/transcriptions/realtime`
  static Uri deriveWebSocketUrl(String baseUrl) {
    var normalized = baseUrl;
    if (normalized.endsWith('/v1/')) {
      normalized = normalized.substring(0, normalized.length - 4);
    } else if (normalized.endsWith('/v1')) {
      normalized = normalized.substring(0, normalized.length - 3);
    }

    final uri = Uri.parse(normalized);
    final wsScheme = uri.scheme == 'http' ? 'ws' : 'wss';

    return uri.replace(
      scheme: wsScheme,
      path: '${uri.path}/v1/audio/transcriptions/realtime',
    );
  }

  /// Connects to the Mistral real-time transcription WebSocket.
  ///
  /// [apiKey] is sent as a Bearer token in the Authorization header.
  /// [baseUrl] is the provider's base URL (e.g., `https://api.mistral.ai/v1`).
  /// [model] optionally specifies the model ID as a query parameter.
  ///
  /// Waits for the `session.created` handshake event before returning.
  /// Throws [TranscriptionException] on connection failure.
  Future<void> connect({
    required String apiKey,
    required String baseUrl,
    String? model,
  }) async {
    if (_disposed) {
      throw TranscriptionException(
        'Repository has been disposed',
        provider: _providerName,
      );
    }
    if (_isConnected) {
      throw TranscriptionException(
        'Already connected',
        provider: _providerName,
      );
    }

    var wsUrl = deriveWebSocketUrl(baseUrl);
    if (model != null) {
      wsUrl = wsUrl.replace(
        queryParameters: {...wsUrl.queryParameters, 'model': model},
      );
    }

    final headers = {'Authorization': 'Bearer $apiKey'};

    developer.log(
      'Connecting to $wsUrl',
      name: _logName,
    );

    try {
      final WebSocketChannel channel;
      if (_channelFactory != null) {
        channel = _channelFactory!(wsUrl);
      } else {
        channel = IOWebSocketChannel.connect(
          wsUrl,
          headers: headers,
        );
      }

      _channel = channel;

      // Wait for the WebSocket connection to be established
      await channel.ready;

      // Use a Completer to track the session.created handshake.
      // The main message listener handles all messages including the
      // handshake — we just need to know when it arrives.
      final sessionCreated = Completer<void>();
      _sessionCreatedCompleter = sessionCreated;

      // Single listener on the stream — dispatches all message types
      _channelSubscription = channel.stream.listen(
        _handleMessage,
        onError: _handleStreamError,
        onDone: _handleStreamDone,
      );

      // Timeout after 10 seconds waiting for session.created
      await sessionCreated.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          _sessionCreatedCompleter = null;
          throw TranscriptionException(
            'Timed out waiting for session.created handshake',
            provider: _providerName,
          );
        },
      );

      _sessionCreatedCompleter = null;
      _isConnected = true;

      developer.log(
        'Connected and session created',
        name: _logName,
      );
    } catch (e) {
      // Clean up partially-established connection to avoid leaked resources.
      // Use unawaited to avoid blocking the rethrow — the caller should not
      // have to wait for WebSocket teardown before handling the error.
      final sub = _channelSubscription;
      final ch = _channel;
      _channelSubscription = null;
      _channel = null;
      if (sub != null) unawaited(sub.cancel());
      if (ch != null) unawaited(ch.sink.close());

      if (e is TranscriptionException) rethrow;
      throw TranscriptionException(
        'Failed to connect: $e',
        provider: _providerName,
        originalError: e,
      );
    }
  }

  /// Sends a PCM audio chunk to the WebSocket.
  ///
  /// [pcmBytes] must be PCM 16-bit signed LE, 16kHz, mono.
  /// The bytes are base64-encoded and sent as an `input_audio.append` message.
  void sendAudioChunk(Uint8List pcmBytes) {
    if (!_isConnected || _channel == null) return;

    final base64Audio = base64Encode(pcmBytes);
    final message = jsonEncode({
      'type': 'input_audio.append',
      'audio': base64Audio,
    });
    _channel!.sink.add(message);
  }

  /// Signals the end of audio input to the server.
  ///
  /// After calling this, the server will finalize the transcription and
  /// emit a `transcription.done` event.
  Future<void> endAudio() async {
    if (!_isConnected || _channel == null) return;

    final message = jsonEncode({'type': 'input_audio.end'});
    _channel!.sink.add(message);
  }

  /// Closes the WebSocket connection.
  Future<void> disconnect() async {
    _isConnected = false;
    await _channelSubscription?.cancel();
    _channelSubscription = null;
    await _channel?.sink.close();
    _channel = null;
  }

  /// Emits incremental text from `transcription.text.delta` events.
  Stream<String> get transcriptionDeltas => _deltaController.stream;

  /// Emits detected language from `transcription.language` events.
  Stream<String> get detectedLanguage => _languageController.stream;

  /// Emits the final result from `transcription.done` events.
  Stream<RealtimeTranscriptionDone> get transcriptionDone =>
      _doneController.stream;

  /// Emits errors from `error` events.
  Stream<RealtimeTranscriptionError> get errors => _errorController.stream;

  /// Cleans up all resources. After calling this, the repository cannot
  /// be reused.
  void dispose() {
    _disposed = true;
    _isConnected = false;
    unawaited(_channelSubscription?.cancel());
    _channelSubscription = null;
    unawaited(_channel?.sink.close());
    _channel = null;
    unawaited(_deltaController.close());
    unawaited(_languageController.close());
    unawaited(_doneController.close());
    unawaited(_errorController.close());
  }

  void _handleMessage(dynamic rawMessage) {
    try {
      final data = jsonDecode(rawMessage as String) as Map<String, dynamic>;
      final type = data['type'] as String?;

      switch (type) {
        case 'transcription.text.delta':
          final delta = data['text'] as String? ?? '';
          if (delta.isNotEmpty) {
            _deltaController.add(delta);
          }

        case 'transcription.language':
          final language = data['language'] as String? ?? '';
          if (language.isNotEmpty) {
            _languageController.add(language);
          }

        case 'transcription.done':
          final text = data['text'] as String? ?? '';
          final usage = data['usage'] as Map<String, dynamic>?;
          _doneController.add(
            RealtimeTranscriptionDone(text: text, usage: usage),
          );

        case 'error':
          final error = data['error'] as Map<String, dynamic>? ?? data;
          _errorController.add(
            RealtimeTranscriptionError(
              message: error['message'] as String? ?? 'Unknown error',
              code: error['code'] as String?,
              type: error['type'] as String?,
            ),
          );

        case 'session.created':
          developer.log('Session created event received', name: _logName);
          if (_sessionCreatedCompleter != null &&
              !_sessionCreatedCompleter!.isCompleted) {
            _sessionCreatedCompleter!.complete();
          }

        default:
          developer.log(
            'Unknown message type: $type',
            name: _logName,
          );
      }
    } catch (e) {
      developer.log(
        'Failed to parse WebSocket message: $e',
        name: _logName,
        error: e,
      );
    }
  }

  void _handleStreamError(Object error) {
    developer.log(
      'WebSocket stream error: $error',
      name: _logName,
      error: error,
    );

    _errorController.add(
      RealtimeTranscriptionError(
        message: 'WebSocket error: $error',
        type: 'stream_error',
      ),
    );

    _isConnected = false;
  }

  void _handleStreamDone() {
    developer.log(
      'WebSocket stream closed',
      name: _logName,
    );

    _isConnected = false;
  }
}
