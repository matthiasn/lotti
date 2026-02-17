import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/realtime_transcription_event.dart';
import 'package:lotti/features/ai/repository/mistral_realtime_transcription_repository.dart';
import 'package:lotti/features/ai/repository/transcription_exception.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// A fake WebSocket channel for testing that uses stream controllers
/// to simulate server messages.
class _FakeWebSocketChannel extends StreamChannelMixin<dynamic>
    implements WebSocketChannel {
  _FakeWebSocketChannel() : _readyCompleter = Completer<void>() {
    _readyCompleter.complete();
  }

  final Completer<void> _readyCompleter;
  final _incomingController = StreamController<dynamic>.broadcast();
  final _outgoingMessages = <String>[];
  bool _isClosed = false;

  @override
  Future<void> get ready => _readyCompleter.future;

  @override
  Stream<dynamic> get stream => _incomingController.stream;

  @override
  WebSocketSink get sink => _FakeWebSocketSink(this);

  @override
  int? get closeCode => _isClosed ? 1000 : null;

  @override
  String? get closeReason => null;

  @override
  String? get protocol => null;

  /// Simulate a server-sent message.
  void simulateServerMessage(Map<String, dynamic> json) {
    if (!_incomingController.isClosed) {
      _incomingController.add(jsonEncode(json));
    }
  }

  /// Simulate a server error.
  void simulateError(Object error) {
    if (!_incomingController.isClosed) {
      _incomingController.addError(error);
    }
  }

  /// Simulate sending a raw (non-JSON) message from the server.
  void simulateRawMessage(String raw) {
    if (!_incomingController.isClosed) {
      _incomingController.add(raw);
    }
  }

  /// Simulate server closing the connection.
  Future<void> simulateClose() async {
    _isClosed = true;
    await _incomingController.close();
  }

  /// Messages sent by the client.
  List<String> get sentMessages => List.unmodifiable(_outgoingMessages);

  void _addOutgoing(dynamic message) {
    if (message is String) {
      _outgoingMessages.add(message);
    }
  }

  Future<void> _close() async {
    _isClosed = true;
    await _incomingController.close();
  }
}

class _FakeWebSocketSink implements WebSocketSink {
  _FakeWebSocketSink(this._channel);

  final _FakeWebSocketChannel _channel;
  final _doneCompleter = Completer<void>();

  @override
  void add(dynamic data) {
    _channel._addOutgoing(data);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<dynamic> addStream(Stream<dynamic> stream) => stream.forEach(add);

  @override
  Future<dynamic> close([int? closeCode, String? closeReason]) async {
    await _channel._close();
    if (!_doneCompleter.isCompleted) {
      _doneCompleter.complete();
    }
  }

  @override
  Future<dynamic> get done => _doneCompleter.future;
}

/// A fake WebSocket channel whose [ready] throws a non-TranscriptionException.
class _FailingReadyChannel extends StreamChannelMixin<dynamic>
    implements WebSocketChannel {
  @override
  Future<void> get ready =>
      Future.error(Exception('Connection refused: ECONNREFUSED'));

  @override
  Stream<dynamic> get stream => const Stream.empty();

  @override
  WebSocketSink get sink => _NullSink();

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  @override
  String? get protocol => null;
}

class _NullSink implements WebSocketSink {
  @override
  void add(dynamic data) {}

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<dynamic> addStream(Stream<dynamic> stream) async {}

  @override
  Future<dynamic> close([int? closeCode, String? closeReason]) async {}

  @override
  Future<dynamic> get done => Completer<void>().future;
}

void main() {
  group('MistralRealtimeTranscriptionRepository', () {
    group('isRealtimeModel', () {
      test('returns true for voxtral-mini-transcribe-realtime-2602', () {
        expect(
          MistralRealtimeTranscriptionRepository.isRealtimeModel(
            'voxtral-mini-transcribe-realtime-2602',
          ),
          isTrue,
        );
      });

      test('returns true for any model containing transcribe-realtime', () {
        expect(
          MistralRealtimeTranscriptionRepository.isRealtimeModel(
            'some-model-transcribe-realtime-v3',
          ),
          isTrue,
        );
      });

      test('returns false for batch transcription model', () {
        expect(
          MistralRealtimeTranscriptionRepository.isRealtimeModel(
            'voxtral-mini-transcribe-v2-2602',
          ),
          isFalse,
        );
      });

      test('returns false for regular mistral model', () {
        expect(
          MistralRealtimeTranscriptionRepository.isRealtimeModel(
            'mistral-small-2501',
          ),
          isFalse,
        );
      });

      test('returns false for model with just realtime (no transcribe)', () {
        expect(
          MistralRealtimeTranscriptionRepository.isRealtimeModel(
            'some-realtime-model',
          ),
          isFalse,
        );
      });
    });

    group('deriveWebSocketUrl', () {
      test('derives from base URL with /v1 suffix', () {
        final url = MistralRealtimeTranscriptionRepository.deriveWebSocketUrl(
          'https://api.mistral.ai/v1',
        );
        expect(
          url.toString(),
          'wss://api.mistral.ai/v1/audio/transcriptions/realtime',
        );
      });

      test('derives from base URL without /v1 suffix', () {
        final url = MistralRealtimeTranscriptionRepository.deriveWebSocketUrl(
          'https://api.mistral.ai',
        );
        expect(
          url.toString(),
          'wss://api.mistral.ai/v1/audio/transcriptions/realtime',
        );
      });

      test('derives from base URL with trailing /v1/', () {
        final url = MistralRealtimeTranscriptionRepository.deriveWebSocketUrl(
          'https://api.mistral.ai/v1/',
        );
        expect(
          url.toString(),
          'wss://api.mistral.ai/v1/audio/transcriptions/realtime',
        );
      });

      test('uses ws scheme for http base URL', () {
        final url = MistralRealtimeTranscriptionRepository.deriveWebSocketUrl(
          'http://localhost:8080/v1',
        );
        expect(
          url.toString(),
          'ws://localhost:8080/v1/audio/transcriptions/realtime',
        );
      });

      test('handles custom proxy URL', () {
        final url = MistralRealtimeTranscriptionRepository.deriveWebSocketUrl(
          'https://my-proxy.example.com',
        );
        expect(
          url.toString(),
          'wss://my-proxy.example.com/v1/audio/transcriptions/realtime',
        );
      });
    });

    group('connect', () {
      late _FakeWebSocketChannel fakeChannel;
      late MistralRealtimeTranscriptionRepository repo;

      setUp(() {
        fakeChannel = _FakeWebSocketChannel();
        repo = MistralRealtimeTranscriptionRepository(
          channelFactory: (uri, headers) => fakeChannel,
        );
      });

      tearDown(() {
        repo.dispose();
      });

      test('connects and waits for session.created', () async {
        final connectFuture = repo.connect(
          apiKey: 'test-key',
          baseUrl: 'https://api.mistral.ai/v1',
        );

        // Simulate server sending session.created
        await Future<void>.delayed(Duration.zero);
        fakeChannel.simulateServerMessage({'type': 'session.created'});

        await connectFuture;
        expect(repo.isConnected, isTrue);
      });

      test('throws when disposed', () async {
        repo.dispose();
        expect(
          () => repo.connect(
            apiKey: 'test-key',
            baseUrl: 'https://api.mistral.ai/v1',
          ),
          throwsA(isA<TranscriptionException>()),
        );
      });

      test('throws when already connected', () async {
        final connectFuture = repo.connect(
          apiKey: 'test-key',
          baseUrl: 'https://api.mistral.ai/v1',
        );
        await Future<void>.delayed(Duration.zero);
        fakeChannel.simulateServerMessage({'type': 'session.created'});
        await connectFuture;

        expect(
          () => repo.connect(
            apiKey: 'test-key',
            baseUrl: 'https://api.mistral.ai/v1',
          ),
          throwsA(isA<TranscriptionException>()),
        );
      });
    });

    group('sendAudioChunk', () {
      late _FakeWebSocketChannel fakeChannel;
      late MistralRealtimeTranscriptionRepository repo;

      setUp(() async {
        fakeChannel = _FakeWebSocketChannel();
        repo = MistralRealtimeTranscriptionRepository(
          channelFactory: (uri, headers) => fakeChannel,
        );

        final connectFuture = repo.connect(
          apiKey: 'test-key',
          baseUrl: 'https://api.mistral.ai/v1',
        );
        await Future<void>.delayed(Duration.zero);
        fakeChannel.simulateServerMessage({'type': 'session.created'});
        await connectFuture;
      });

      tearDown(() {
        repo.dispose();
      });

      test('sends base64-encoded PCM as input_audio.append', () {
        final pcm = Uint8List.fromList([1, 2, 3, 4]);
        repo.sendAudioChunk(pcm);

        expect(fakeChannel.sentMessages, hasLength(1));
        final sent =
            jsonDecode(fakeChannel.sentMessages.first) as Map<String, dynamic>;
        expect(sent['type'], 'input_audio.append');
        expect(sent['audio'], base64Encode(pcm));
      });

      test('does nothing when not connected', () {
        final disconnectedRepo = MistralRealtimeTranscriptionRepository()
          ..sendAudioChunk(Uint8List.fromList([1, 2]))
          // No error thrown, no message sent
          ..dispose();
        // Verify no exception from the above
        expect(disconnectedRepo.isConnected, isFalse);
      });
    });

    group('endAudio', () {
      late _FakeWebSocketChannel fakeChannel;
      late MistralRealtimeTranscriptionRepository repo;

      setUp(() async {
        fakeChannel = _FakeWebSocketChannel();
        repo = MistralRealtimeTranscriptionRepository(
          channelFactory: (uri, headers) => fakeChannel,
        );

        final connectFuture = repo.connect(
          apiKey: 'test-key',
          baseUrl: 'https://api.mistral.ai/v1',
        );
        await Future<void>.delayed(Duration.zero);
        fakeChannel.simulateServerMessage({'type': 'session.created'});
        await connectFuture;
      });

      tearDown(() {
        repo.dispose();
      });

      test('sends input_audio.end message', () async {
        await repo.endAudio();

        expect(fakeChannel.sentMessages, hasLength(1));
        final sent =
            jsonDecode(fakeChannel.sentMessages.first) as Map<String, dynamic>;
        expect(sent['type'], 'input_audio.end');
      });
    });

    group('transcription streams', () {
      late _FakeWebSocketChannel fakeChannel;
      late MistralRealtimeTranscriptionRepository repo;

      setUp(() async {
        fakeChannel = _FakeWebSocketChannel();
        repo = MistralRealtimeTranscriptionRepository(
          channelFactory: (uri, headers) => fakeChannel,
        );

        final connectFuture = repo.connect(
          apiKey: 'test-key',
          baseUrl: 'https://api.mistral.ai/v1',
        );
        await Future<void>.delayed(Duration.zero);
        fakeChannel.simulateServerMessage({'type': 'session.created'});
        await connectFuture;
      });

      tearDown(() {
        repo.dispose();
      });

      test('emits transcription deltas', () async {
        final deltas = <String>[];
        repo.transcriptionDeltas.listen(deltas.add);

        fakeChannel
          ..simulateServerMessage({
            'type': 'transcription.text.delta',
            'text': 'Hello ',
          })
          ..simulateServerMessage({
            'type': 'transcription.text.delta',
            'text': 'world',
          });

        await Future<void>.delayed(Duration.zero);
        expect(deltas, ['Hello ', 'world']);
      });

      test('emits detected language', () async {
        final languages = <String>[];
        repo.detectedLanguage.listen(languages.add);

        fakeChannel.simulateServerMessage({
          'type': 'transcription.language',
          'language': 'en',
        });

        await Future<void>.delayed(Duration.zero);
        expect(languages, ['en']);
      });

      test('emits transcription done with text and usage', () async {
        final doneEvents = <RealtimeTranscriptionDone>[];
        repo.transcriptionDone.listen(doneEvents.add);

        fakeChannel.simulateServerMessage({
          'type': 'transcription.done',
          'text': 'Hello world',
          'usage': {'audio_seconds': 5.0, 'input_tokens': 100},
        });

        await Future<void>.delayed(Duration.zero);
        expect(doneEvents, hasLength(1));
        expect(doneEvents.first.text, 'Hello world');
        expect(doneEvents.first.usage, isNotNull);
        expect(doneEvents.first.usage!['audio_seconds'], 5.0);
      });

      test('emits errors from error events', () async {
        final errors = <RealtimeTranscriptionError>[];
        repo.errors.listen(errors.add);

        fakeChannel.simulateServerMessage({
          'type': 'error',
          'error': {
            'message': 'Something went wrong',
            'code': 'internal_error',
            'type': 'server_error',
          },
        });

        await Future<void>.delayed(Duration.zero);
        expect(errors, hasLength(1));
        expect(errors.first.message, 'Something went wrong');
        expect(errors.first.code, 'internal_error');
        expect(errors.first.type, 'server_error');
      });

      test('ignores empty deltas', () async {
        final deltas = <String>[];
        repo.transcriptionDeltas.listen(deltas.add);

        fakeChannel.simulateServerMessage({
          'type': 'transcription.text.delta',
          'text': '',
        });

        await Future<void>.delayed(Duration.zero);
        expect(deltas, isEmpty);
      });
    });

    group('disconnect', () {
      late _FakeWebSocketChannel fakeChannel;
      late MistralRealtimeTranscriptionRepository repo;

      setUp(() async {
        fakeChannel = _FakeWebSocketChannel();
        repo = MistralRealtimeTranscriptionRepository(
          channelFactory: (uri, headers) => fakeChannel,
        );

        final connectFuture = repo.connect(
          apiKey: 'test-key',
          baseUrl: 'https://api.mistral.ai/v1',
        );
        await Future<void>.delayed(Duration.zero);
        fakeChannel.simulateServerMessage({'type': 'session.created'});
        await connectFuture;
      });

      tearDown(() {
        repo.dispose();
      });

      test('sets isConnected to false', () async {
        expect(repo.isConnected, isTrue);
        await repo.disconnect();
        expect(repo.isConnected, isFalse);
      });
    });

    group('connect with model parameter', () {
      test('includes model in URL query parameters', () async {
        Uri? capturedUri;
        final fakeChannel = _FakeWebSocketChannel();
        final repo = MistralRealtimeTranscriptionRepository(
          channelFactory: (uri, headers) {
            capturedUri = uri;
            return fakeChannel;
          },
        );
        addTearDown(repo.dispose);

        final connectFuture = repo.connect(
          apiKey: 'test-key',
          baseUrl: 'https://api.mistral.ai/v1',
          model: 'voxtral-mini-transcribe-realtime-2602',
        );

        await Future<void>.delayed(Duration.zero);
        fakeChannel.simulateServerMessage({'type': 'session.created'});
        await connectFuture;

        expect(capturedUri, isNotNull);
        expect(
          capturedUri!.queryParameters['model'],
          'voxtral-mini-transcribe-realtime-2602',
        );
      });
    });

    group('connect error handling', () {
      test('times out when session.created is not received', () {
        fakeAsync((async) {
          final fakeChannel = _FakeWebSocketChannel();
          final repo = MistralRealtimeTranscriptionRepository(
            channelFactory: (_, __) => fakeChannel,
          );

          TranscriptionException? caught;
          repo
              .connect(
            apiKey: 'test-key',
            baseUrl: 'https://api.mistral.ai/v1',
          )
              .catchError((Object e) {
            caught = e as TranscriptionException;
          });
          async
            ..flushMicrotasks()

            // Advance past the 10-second timeout
            ..elapse(const Duration(seconds: 11))
            ..flushMicrotasks();

          expect(caught, isNotNull);
          expect(caught!.message, contains('Timed out'));

          repo.dispose();
        });
      });

      test('wraps non-TranscriptionException from channel.ready', () async {
        final repo = MistralRealtimeTranscriptionRepository(
          channelFactory: (_, __) => _FailingReadyChannel(),
        );
        addTearDown(repo.dispose);

        await expectLater(
          () => repo.connect(
            apiKey: 'test-key',
            baseUrl: 'https://api.mistral.ai/v1',
          ),
          throwsA(
            isA<TranscriptionException>().having(
              (e) => e.message,
              'message',
              contains('Failed to connect'),
            ),
          ),
        );
      });
    });

    group('endAudio when not connected', () {
      test('does nothing when not connected', () async {
        final repo = MistralRealtimeTranscriptionRepository();
        addTearDown(repo.dispose);

        // Should not throw
        await repo.endAudio();
        expect(repo.isConnected, isFalse);
      });
    });

    group('message parsing edge cases', () {
      late _FakeWebSocketChannel fakeChannel;
      late MistralRealtimeTranscriptionRepository repo;

      setUp(() async {
        fakeChannel = _FakeWebSocketChannel();
        repo = MistralRealtimeTranscriptionRepository(
          channelFactory: (uri, headers) => fakeChannel,
        );

        final connectFuture = repo.connect(
          apiKey: 'test-key',
          baseUrl: 'https://api.mistral.ai/v1',
        );
        await Future<void>.delayed(Duration.zero);
        fakeChannel.simulateServerMessage({'type': 'session.created'});
        await connectFuture;
      });

      tearDown(() {
        repo.dispose();
      });

      test('handles malformed JSON without crashing', () async {
        final errors = <RealtimeTranscriptionError>[];
        repo.errors.listen(errors.add);

        // Send raw non-JSON message
        fakeChannel.simulateRawMessage('this is not json');

        await Future<void>.delayed(Duration.zero);
        // Should not crash; error is logged internally, not emitted to stream
        expect(errors, isEmpty);
      });

      test('handles unknown message type without crashing', () async {
        final deltas = <String>[];
        final errors = <RealtimeTranscriptionError>[];
        repo.transcriptionDeltas.listen(deltas.add);
        repo.errors.listen(errors.add);

        fakeChannel.simulateServerMessage({
          'type': 'unknown.message.type',
          'data': 'something',
        });

        await Future<void>.delayed(Duration.zero);
        expect(deltas, isEmpty);
        expect(errors, isEmpty);
      });

      test('uses fallback for null text in delta', () async {
        final deltas = <String>[];
        repo.transcriptionDeltas.listen(deltas.add);

        // text key is null — should fall back to '' and be ignored (empty)
        fakeChannel.simulateServerMessage({
          'type': 'transcription.text.delta',
          'text': null,
        });

        await Future<void>.delayed(Duration.zero);
        expect(deltas, isEmpty);
      });

      test('uses fallback for null language', () async {
        final languages = <String>[];
        repo.detectedLanguage.listen(languages.add);

        fakeChannel.simulateServerMessage({
          'type': 'transcription.language',
          'language': null,
        });

        await Future<void>.delayed(Duration.zero);
        expect(languages, isEmpty);
      });

      test('uses fallback for null text in done event', () async {
        final doneEvents = <RealtimeTranscriptionDone>[];
        repo.transcriptionDone.listen(doneEvents.add);

        fakeChannel.simulateServerMessage({
          'type': 'transcription.done',
          // no text key at all
          'usage': {'audio_seconds': 1.0},
        });

        await Future<void>.delayed(Duration.zero);
        expect(doneEvents, hasLength(1));
        expect(doneEvents.first.text, '');
      });

      test('error event without nested error key uses data as fallback',
          () async {
        final errors = <RealtimeTranscriptionError>[];
        repo.errors.listen(errors.add);

        // Error event with flat structure (no nested 'error' map)
        fakeChannel.simulateServerMessage({
          'type': 'error',
          'message': 'Rate limit exceeded',
          'code': 'rate_limit',
          'type_field': 'api_error',
        });

        await Future<void>.delayed(Duration.zero);
        expect(errors, hasLength(1));
        expect(errors.first.message, 'Rate limit exceeded');
      });

      test('done event without usage field', () async {
        final doneEvents = <RealtimeTranscriptionDone>[];
        repo.transcriptionDone.listen(doneEvents.add);

        fakeChannel.simulateServerMessage({
          'type': 'transcription.done',
          'text': 'Hello',
        });

        await Future<void>.delayed(Duration.zero);
        expect(doneEvents, hasLength(1));
        expect(doneEvents.first.text, 'Hello');
        expect(doneEvents.first.usage, isNull);
      });

      test('ignores empty language string', () async {
        final languages = <String>[];
        repo.detectedLanguage.listen(languages.add);

        fakeChannel.simulateServerMessage({
          'type': 'transcription.language',
          'language': '',
        });

        await Future<void>.delayed(Duration.zero);
        expect(languages, isEmpty);
      });
    });

    group('stream error handling', () {
      late _FakeWebSocketChannel fakeChannel;
      late MistralRealtimeTranscriptionRepository repo;

      setUp(() async {
        fakeChannel = _FakeWebSocketChannel();
        repo = MistralRealtimeTranscriptionRepository(
          channelFactory: (uri, headers) => fakeChannel,
        );

        final connectFuture = repo.connect(
          apiKey: 'test-key',
          baseUrl: 'https://api.mistral.ai/v1',
        );
        await Future<void>.delayed(Duration.zero);
        fakeChannel.simulateServerMessage({'type': 'session.created'});
        await connectFuture;
      });

      tearDown(() {
        repo.dispose();
      });

      test('emits error and sets isConnected to false on stream error',
          () async {
        final errors = <RealtimeTranscriptionError>[];
        repo.errors.listen(errors.add);

        fakeChannel.simulateError(Exception('Connection lost'));

        await Future<void>.delayed(Duration.zero);
        expect(repo.isConnected, isFalse);
        expect(errors, hasLength(1));
        expect(errors.first.type, 'stream_error');
      });

      test('sets isConnected to false when stream closes', () async {
        await fakeChannel.simulateClose();

        await Future<void>.delayed(Duration.zero);
        expect(repo.isConnected, isFalse);
      });
    });
  });
}
