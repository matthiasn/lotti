import 'dart:async';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/isolate/sync_isolate_protocol.dart';
import 'package:lotti/features/sync/isolate/sync_isolate_worker.dart';

/// Drives [syncIsolateEntry] in the test isolate, standing in for the host:
/// the worker's messages land on the host port in the order it sent them.
void main() {
  late ReceivePort host;
  late StreamIterator<Object?> inbox;
  late SendPort commands;

  setUp(() async {
    host = ReceivePort();
    inbox = StreamIterator(host);
    syncIsolateEntry(host.sendPort);
    await inbox.moveNext();
    commands = (inbox.current! as SyncIsolateReady).commands;
  });

  tearDown(() async {
    await inbox.cancel();
    host.close();
  });

  Future<Object?> next() async {
    await inbox.moveNext();
    return inbox.current;
  }

  test('announces itself in the log right after the handshake', () async {
    final line = await next();

    expect(line, isA<SyncIsolateLog>());
    expect((line! as SyncIsolateLog).message, 'sync isolate started');
  });

  test(
    'ignores a message that is not a request instead of answering it',
    () async {
      await next(); // startup log line
      commands
        ..send('not a request')
        ..send(
          const SyncIsolateRequest(requestId: 7, command: SyncIsolatePing()),
        );

      final reply = (await next())! as SyncIsolateReply;

      // The junk produced no reply and no count: the first answer is the
      // ping's, and it is the first command handled.
      expect(reply.requestId, 7);
      expect((reply.result! as SyncIsolateHealth).handled, 1);
    },
  );

  test('answers shutdown and then stops taking commands', () async {
    await next(); // startup log line
    commands
      ..send(
        const SyncIsolateRequest(requestId: 1, command: SyncIsolateShutdown()),
      )
      ..send(
        const SyncIsolateRequest(requestId: 2, command: SyncIsolatePing()),
      );

    final reply = (await next())! as SyncIsolateReply;
    expect(reply.requestId, 1);
    expect(reply.failure, isNull);

    // The ping went to a closed port: nothing more ever arrives. Closing the
    // host port ends the inbox, which proves no second reply was queued.
    host.close();
    expect(await inbox.moveNext(), isFalse);
  });
}
