import 'dart:async';
import 'dart:isolate';

import 'package:lotti/features/sync/actor/sync_actor.dart';

/// UI-side host that manages the sync actor isolate.
///
/// Provides [send] to dispatch commands and [events] to receive
/// asynchronous events from the actor.
class SyncActorHost {
  SyncActorHost._({
    required Isolate isolate,
    required SendPort commandPort,
    required ReceivePort eventPort,
    required StreamController<Map<String, Object?>> eventController,
  })  : _isolate = isolate,
        _commandPort = commandPort,
        _eventPort = eventPort,
        _eventController = eventController;

  final Isolate _isolate;
  final SendPort _commandPort;
  final ReceivePort _eventPort;
  final StreamController<Map<String, Object?>> _eventController;
  bool _disposed = false;

  /// Spawns a new sync actor isolate and returns the host.
  ///
  /// An optional [entrypoint] can be provided for testing with a
  /// lightweight actor implementation.
  static Future<SyncActorHost> spawn({
    void Function(SendPort)? entrypoint,
  }) async {
    final readyPort = ReceivePort();

    final isolate = await Isolate.spawn(
      entrypoint ?? syncActorEntrypoint,
      readyPort.sendPort,
    );

    final commandPort = await readyPort.first as SendPort;
    readyPort.close();

    final eventPort = ReceivePort();
    final eventController = StreamController<Map<String, Object?>>.broadcast();

    eventPort.listen((dynamic raw) {
      if (raw is Map) {
        eventController.add(raw.cast<String, Object?>());
      }
    });

    return SyncActorHost._(
      isolate: isolate,
      commandPort: commandPort,
      eventPort: eventPort,
      eventController: eventController,
    );
  }

  /// The [SendPort] for the event receive port.
  ///
  /// Pass this to the actor via the `init` command's `eventPort` field
  /// so the actor can emit events back to the host.
  SendPort get eventSendPort => _eventPort.sendPort;

  /// Broadcast stream of event maps from the actor.
  Stream<Map<String, Object?>> get events => _eventController.stream;

  /// Sends a command to the actor and returns the response.
  ///
  /// Throws [TimeoutException] if the actor does not respond within
  /// [timeout].
  Future<Map<String, Object?>> send(
    String command, {
    Map<String, Object?>? payload,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (_disposed) {
      return <String, Object?>{
        'ok': false,
        'error': 'Host is disposed',
        'errorCode': 'HOST_DISPOSED',
      };
    }

    final replyPort = ReceivePort();

    _commandPort.send(<String, Object?>{
      'command': command,
      ...?payload,
      'replyTo': replyPort.sendPort,
    });

    try {
      final response = await replyPort.first.timeout(timeout);
      if (response is Map) {
        return response.cast<String, Object?>();
      }
      return <String, Object?>{
        'ok': false,
        'error': 'Invalid response type: ${response.runtimeType}',
      };
    } on TimeoutException {
      return <String, Object?>{
        'ok': false,
        'error': 'Command "$command" timed out after $timeout',
        'errorCode': 'TIMEOUT',
      };
    } finally {
      replyPort.close();
    }
  }

  /// Gracefully stops the actor and cleans up resources.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    // Best-effort stop command
    try {
      await send('stop', timeout: const Duration(seconds: 5));
    } catch (_) {
      // Ignore — we'll kill the isolate anyway.
    }

    _isolate.kill(priority: Isolate.immediate);
    _eventPort.close();
    await _eventController.close();
  }
}
