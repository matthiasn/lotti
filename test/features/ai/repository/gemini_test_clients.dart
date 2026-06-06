import 'dart:convert';

import 'package:http/http.dart' as http;

/// Fake HTTP clients for the Gemini repository tests: a fixed-stream
/// client plus URL-routing variants for multi-call scenarios. Shared so
/// sibling SSE-style suites can reuse them instead of redefining.
class FakeStreamClient extends http.BaseClient {
  FakeStreamClient(this._statusCode, this._lines);

  final int _statusCode;
  final List<String> _lines;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final data = _lines.map((l) => utf8.encode('$l\n') as List<int>);
    final stream = Stream<List<int>>.fromIterable(data);
    return http.StreamedResponse(
      stream,
      _statusCode,
      headers: {
        'content-type': 'application/json',
      },
    );
  }
}

class RoutingFakeClient extends http.BaseClient {
  RoutingFakeClient({
    required this.streamLines,
    required this.fallbackBody,
  });

  final List<String> streamLines;
  final String fallbackBody;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;
    if (path.endsWith(':streamGenerateContent')) {
      final data = streamLines.map((l) => utf8.encode('$l\n') as List<int>);
      final stream = Stream<List<int>>.fromIterable(data);
      return http.StreamedResponse(
        stream,
        200,
        headers: {
          'content-type': 'application/json',
        },
      );
    } else if (path.endsWith(':generateContent')) {
      final bytes = utf8.encode(fallbackBody);
      final stream = Stream<List<int>>.fromIterable([bytes]);
      return http.StreamedResponse(
        stream,
        200,
        headers: {
          'content-type': 'application/json',
        },
      );
    }
    // Default empty 404
    return http.StreamedResponse(const Stream.empty(), 404);
  }
}

class RoutingErrorClient extends http.BaseClient {
  RoutingErrorClient({
    required this.streamLines,
  });

  final List<String> streamLines;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;
    if (path.endsWith(':streamGenerateContent')) {
      final data = streamLines.map((l) => utf8.encode('$l\n') as List<int>);
      final stream = Stream<List<int>>.fromIterable(data);
      return http.StreamedResponse(
        stream,
        200,
        headers: {
          'content-type': 'application/json',
        },
      );
    } else if (path.endsWith(':generateContent')) {
      final bytes = utf8.encode('{"error":"boom"}');
      final stream = Stream<List<int>>.fromIterable([bytes]);
      return http.StreamedResponse(
        stream,
        500,
        headers: {
          'content-type': 'application/json',
        },
      );
    }
    return http.StreamedResponse(const Stream.empty(), 404);
  }
}

class RoutingCountingClient extends http.BaseClient {
  RoutingCountingClient({
    required this.streamLines,
    required this.fallbackBody,
  });

  final List<String> streamLines;
  final String fallbackBody;

  int streamCalls = 0;
  int fallbackCalls = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;
    if (path.endsWith(':streamGenerateContent')) {
      streamCalls++;
      final data = streamLines.map((l) => utf8.encode('$l\n') as List<int>);
      final stream = Stream<List<int>>.fromIterable(data);
      return http.StreamedResponse(
        stream,
        200,
        headers: {
          'content-type': 'application/json',
        },
      );
    } else if (path.endsWith(':generateContent')) {
      fallbackCalls++;
      final bytes = utf8.encode(fallbackBody);
      final stream = Stream<List<int>>.fromIterable([bytes]);
      return http.StreamedResponse(
        stream,
        200,
        headers: {
          'content-type': 'application/json',
        },
      );
    }
    return http.StreamedResponse(const Stream.empty(), 404);
  }
}
