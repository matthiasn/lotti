import 'dart:async';
import 'dart:convert';

import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// A fake WebSocket channel for testing that uses stream controllers
/// to simulate server messages.
class FakeWebSocketChannel extends StreamChannelMixin<dynamic>
    implements WebSocketChannel {
  FakeWebSocketChannel() : _readyCompleter = Completer<void>() {
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

  final FakeWebSocketChannel _channel;
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
class FailingReadyWebSocketChannel extends StreamChannelMixin<dynamic>
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
