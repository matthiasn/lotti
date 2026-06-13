import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/repository/gemini_stream_sender.dart';

http.StreamedResponse _ok(String body) {
  final bytes = utf8.encode(body);
  return http.StreamedResponse(
    Stream<List<int>>.fromIterable([bytes]),
    200,
    headers: const {'content-type': 'application/json'},
  );
}

http.StreamedResponse _status(int code, {Map<String, String>? headers}) {
  return http.StreamedResponse(
    const Stream<List<int>>.empty(),
    code,
    headers: headers ?? const {},
  );
}

/// Client that returns a scripted sequence of responses / throwables, one per
/// [send] call. A `TimeoutException` throwable simulates a handshake timeout.
class _ScriptedClient extends http.BaseClient {
  _ScriptedClient(this._script);

  final List<Object> _script;
  int calls = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final step = _script[calls < _script.length ? calls : _script.length - 1];
    calls++;
    if (step is http.StreamedResponse) return step;
    if (step is Exception) throw step;
    throw StateError('unexpected script step: $step');
  }
}

http.Request _buildRequest() =>
    http.Request('POST', Uri.parse('https://example.com/x'));

void main() {
  group('GeminiStreamSender', () {
    test('returns the first non-retryable response without delay', () {
      fakeAsync((async) {
        final client = _ScriptedClient([_ok('{"ok":true}')]);
        final sender = GeminiStreamSender(httpClient: client);

        http.StreamedResponse? result;
        sender
            .send(buildRequest: _buildRequest, context: 'ctx')
            .then((r) => result = r);

        async.flushMicrotasks();

        expect(client.calls, 1);
        expect(result, isNotNull);
        expect(result!.statusCode, 200);
      });
    });

    test('retries on 429 then succeeds, honoring exponential backoff', () {
      fakeAsync((async) {
        final client = _ScriptedClient([_status(429), _ok('{}')]);
        final sender = GeminiStreamSender(httpClient: client);

        http.StreamedResponse? result;
        sender
            .send(buildRequest: _buildRequest, context: 'ctx')
            .then((r) => result = r);

        // First attempt: 429 -> schedules a 500ms base-delay backoff.
        async.flushMicrotasks();
        expect(client.calls, 1);
        expect(result, isNull);

        async
          ..elapse(const Duration(milliseconds: 500))
          ..flushMicrotasks();

        expect(client.calls, 2);
        expect(result!.statusCode, 200);
      });
    });

    test('retries on 503 the same way as 429', () {
      fakeAsync((async) {
        final client = _ScriptedClient([_status(503), _ok('{}')]);
        final sender = GeminiStreamSender(httpClient: client);

        http.StreamedResponse? result;
        sender
            .send(buildRequest: _buildRequest, context: 'ctx')
            .then((r) => result = r);

        async
          ..flushMicrotasks()
          ..elapse(const Duration(milliseconds: 500))
          ..flushMicrotasks();

        expect(client.calls, 2);
        expect(result!.statusCode, 200);
      });
    });

    test('honors a numeric Retry-After header over exponential backoff', () {
      fakeAsync((async) {
        final client = _ScriptedClient([
          _status(429, headers: {'retry-after': '7'}),
          _ok('{}'),
        ]);
        final sender = GeminiStreamSender(httpClient: client);

        http.StreamedResponse? result;
        sender
            .send(buildRequest: _buildRequest, context: 'ctx')
            .then((r) => result = r);

        // Base delay (500ms) must NOT release the retry; only 7s does.
        async
          ..flushMicrotasks()
          ..elapse(const Duration(milliseconds: 500))
          ..flushMicrotasks();
        expect(client.calls, 1, reason: 'retry must wait the full 7s');

        async
          ..elapse(const Duration(seconds: 7))
          ..flushMicrotasks();
        expect(client.calls, 2);
        expect(result!.statusCode, 200);
      });
    });

    test('falls back to exponential backoff for a non-numeric Retry-After', () {
      fakeAsync((async) {
        final client = _ScriptedClient([
          _status(429, headers: {'retry-after': 'soon'}),
          _ok('{}'),
        ]);
        final sender = GeminiStreamSender(httpClient: client);

        http.StreamedResponse? result;
        sender
            .send(buildRequest: _buildRequest, context: 'ctx')
            .then((r) => result = r);

        async
          ..flushMicrotasks()
          ..elapse(const Duration(milliseconds: 500))
          ..flushMicrotasks();

        expect(client.calls, 2);
        expect(result!.statusCode, 200);
      });
    });

    test('returns the last 429 response after exhausting retries', () {
      fakeAsync((async) {
        final client = _ScriptedClient(
          // 4 total attempts for default maxRetries=3, all 429.
          List<Object>.generate(4, (_) => _status(429)),
        );
        final sender = GeminiStreamSender(httpClient: client);

        http.StreamedResponse? result;
        sender
            .send(buildRequest: _buildRequest, context: 'ctx')
            .then((r) => result = r);

        // Delays: 500ms, 1s, 2s between the 4 attempts.
        async
          ..flushMicrotasks()
          ..elapse(const Duration(milliseconds: 500))
          ..flushMicrotasks()
          ..elapse(const Duration(seconds: 1))
          ..flushMicrotasks()
          ..elapse(const Duration(seconds: 2))
          ..flushMicrotasks();

        expect(client.calls, 4);
        expect(result, isNotNull);
        expect(result!.statusCode, 429);
      });
    });

    test('retries after a TimeoutException then succeeds', () {
      fakeAsync((async) {
        final client = _ScriptedClient([
          TimeoutException('handshake'),
          _ok('{}'),
        ]);
        final sender = GeminiStreamSender(httpClient: client);

        http.StreamedResponse? result;
        sender
            .send(buildRequest: _buildRequest, context: 'ctx')
            .then((r) => result = r);

        async
          ..flushMicrotasks()
          ..elapse(const Duration(milliseconds: 500))
          ..flushMicrotasks();

        expect(client.calls, 2);
        expect(result!.statusCode, 200);
      });
    });

    test('rethrows TimeoutException after exhausting retries', () {
      fakeAsync((async) {
        final client = _ScriptedClient(
          List<Object>.generate(4, (_) => TimeoutException('t')),
        );
        final sender = GeminiStreamSender(httpClient: client);

        Object? caught;
        sender.send(buildRequest: _buildRequest, context: 'ctx').catchError((
          Object e,
        ) {
          caught = e;
          return _status(599);
        });

        async
          ..flushMicrotasks()
          ..elapse(const Duration(milliseconds: 500))
          ..flushMicrotasks()
          ..elapse(const Duration(seconds: 1))
          ..flushMicrotasks()
          ..elapse(const Duration(seconds: 2))
          ..flushMicrotasks();

        expect(client.calls, 4);
        expect(caught, isA<TimeoutException>());
      });
    });

    test('builds a fresh request for every attempt', () {
      fakeAsync((async) {
        final client = _ScriptedClient([_status(429), _ok('{}')]);
        final sender = GeminiStreamSender(httpClient: client);

        var built = 0;
        sender.send(
          buildRequest: () {
            built++;
            return _buildRequest();
          },
          context: 'ctx',
        );

        async
          ..flushMicrotasks()
          ..elapse(const Duration(milliseconds: 500))
          ..flushMicrotasks();

        expect(built, 2, reason: 'one request built per attempt');
      });
    });

    test('respects a custom maxRetries of zero (no retries)', () {
      fakeAsync((async) {
        final client = _ScriptedClient([_status(429), _ok('{}')]);
        final sender = GeminiStreamSender(httpClient: client, maxRetries: 0);

        http.StreamedResponse? result;
        sender
            .send(buildRequest: _buildRequest, context: 'ctx')
            .then((r) => result = r);

        async.flushMicrotasks();

        expect(client.calls, 1, reason: 'no retry when maxRetries is 0');
        expect(result!.statusCode, 429);
      });
    });
  });
}
