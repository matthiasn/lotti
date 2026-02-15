import 'dart:async';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/actor/sync_actor_host.dart';

/// Lightweight test-only actor entrypoint that responds to commands
/// without any Matrix SDK dependencies.
void _testActorEntrypoint(SendPort readyPort) {
  final commandPort = ReceivePort();
  readyPort.send(commandPort.sendPort);

  SendPort? eventPort;
  var stopped = false;

  commandPort.listen((dynamic raw) {
    if (raw is! Map || stopped) return;

    final command = raw.cast<String, Object?>();
    final cmd = command['command'] as String?;
    final replyTo = command['replyTo'] as SendPort?;
    final requestId = command['requestId'] as String?;

    switch (cmd) {
      case 'ping':
        replyTo?.send(<String, Object?>{
          'ok': true,
          if (requestId != null) 'requestId': requestId,
        });
      case 'setEventPort':
        eventPort = command['eventPort'] as SendPort?;
        replyTo?.send(<String, Object?>{'ok': true});
      case 'emitTestEvent':
        eventPort?.send(<String, Object?>{
          'event': 'testEvent',
          'data': command['data'],
        });
        replyTo?.send(<String, Object?>{'ok': true});
      case 'slow':
        // Deliberately slow command — never replies.
        // Used to test timeout behavior.
        break;
      case 'stop':
        stopped = true;
        replyTo?.send(<String, Object?>{'ok': true});
        commandPort.close();
      default:
        replyTo?.send(<String, Object?>{
          'ok': false,
          'error': 'Unknown command: $cmd',
        });
    }
  });
}

void _testActorInvalidResponseEntrypoint(SendPort readyPort) {
  final commandPort = ReceivePort();
  readyPort.send(commandPort.sendPort);

  commandPort.listen((dynamic raw) {
    if (raw is! Map) return;

    final command = raw.cast<String, Object?>();
    final cmd = command['command'] as String?;
    final replyTo = command['replyTo'] as SendPort?;

    switch (cmd) {
      case 'ping':
        replyTo?.send('not-a-map');
      case 'emitRawEvent':
        final eventPort = command['eventPort'] as SendPort?;
        eventPort?.send(123);
        replyTo?.send(<String, Object?>{'ok': true});
      default:
        replyTo?.send(<String, Object?>{'ok': false, 'error': 'bad'});
    }
  });
}

void main() {
  group('SyncActorHost', () {
    late SyncActorHost host;

    tearDown(() async {
      await host.dispose();
    });

    test('spawn and ping', () async {
      host = await SyncActorHost.spawn(entrypoint: _testActorEntrypoint);

      final response = await host.send('ping');
      expect(response['ok'], isTrue);
    });

    test('multiple sequential commands', () async {
      host = await SyncActorHost.spawn(entrypoint: _testActorEntrypoint);

      final ping1 = await host.send('ping');
      expect(ping1['ok'], isTrue);

      final ping2 = await host.send('ping');
      expect(ping2['ok'], isTrue);

      final ping3 = await host.send('ping');
      expect(ping3['ok'], isTrue);
    });

    test('command timeout returns error', () async {
      host = await SyncActorHost.spawn(entrypoint: _testActorEntrypoint);

      final response = await host.send(
        'slow',
        timeout: const Duration(milliseconds: 100),
      );

      expect(response['ok'], isFalse);
      expect(response['errorCode'], 'TIMEOUT');
    });

    test('returns type error for non-map response', () async {
      host = await SyncActorHost.spawn(
        entrypoint: _testActorInvalidResponseEntrypoint,
      );

      final response = await host.send('ping');

      expect(response['ok'], isFalse);
      expect(response['error'], contains('Invalid response type'));
    });

    test('event stream delivers events', () async {
      host = await SyncActorHost.spawn(entrypoint: _testActorEntrypoint);

      // Set up event port on the test actor
      final setPortResponse = await host.send(
        'setEventPort',
        payload: {'eventPort': host.eventSendPort},
      );
      expect(setPortResponse['ok'], isTrue);

      // Listen for events
      final eventCompleter = Completer<Map<String, Object?>>();
      final sub = host.events.listen((event) {
        if (!eventCompleter.isCompleted) {
          eventCompleter.complete(event);
        }
      });

      // Trigger a test event
      await host.send('emitTestEvent', payload: {'data': 'hello'});

      final event =
          await eventCompleter.future.timeout(const Duration(seconds: 2));
      expect(event['event'], 'testEvent');
      expect(event['data'], 'hello');

      await sub.cancel();
    });

    test('ignores non-map events from actor', () async {
      host = await SyncActorHost.spawn(
        entrypoint: _testActorInvalidResponseEntrypoint,
      );
      final eventPortResponse = await host.send(
        'emitRawEvent',
        payload: {'eventPort': host.eventSendPort},
      );
      expect(eventPortResponse['ok'], isTrue);

      final events = <Map<String, Object?>>[];
      final sub = host.events.listen(events.add);

      await host
          .send('emitRawEvent', payload: {'eventPort': host.eventSendPort});
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(events, isEmpty);
      await sub.cancel();
    });

    test('send after dispose returns error', () async {
      host = await SyncActorHost.spawn(entrypoint: _testActorEntrypoint);
      await host.dispose();

      final response = await host.send('ping');
      expect(response['ok'], isFalse);
      expect(response['errorCode'], 'HOST_DISPOSED');
    });

    test('double dispose is safe', () async {
      host = await SyncActorHost.spawn(entrypoint: _testActorEntrypoint);
      await host.dispose();
      // Should not throw
      await host.dispose();
    });

    test('unknown command returns error from actor', () async {
      host = await SyncActorHost.spawn(entrypoint: _testActorEntrypoint);

      final response = await host.send('nonExistent');
      expect(response['ok'], isFalse);
      expect(response['error'], contains('Unknown command'));
    });
  });
}
