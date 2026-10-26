import 'dart:async';
import 'dart:isolate';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/vector_clock.dart';
import 'package:lotti/features/sync/isolate/sync_isolate_host_client.dart';
import 'package:lotti/features/sync/isolate/sync_isolate_protocol.dart';

import '../../../test_data/test_data.dart';

/// The worker's side of the request channel: what it sends the host, and how
/// the host's replies, timeouts and the shutdown reach the waiting stores.
void main() {
  late ReceivePort hostPort;
  late StreamIterator<Object?> sent;
  late SyncIsolateHostClient client;

  setUp(() {
    hostPort = ReceivePort();
    sent = StreamIterator(hostPort);
    client = SyncIsolateHostClient(hostPort.sendPort);
  });

  tearDown(() async {
    await sent.cancel();
    hostPort.close();
  });

  Future<SyncIsolateHostRequest> nextRequest() async {
    await sent.moveNext();
    return sent.current! as SyncIsolateHostRequest;
  }

  test(
    'numbers each query, and the reply with that number completes it',
    () async {
      final first = client.ask<String?>(const SyncIsolateHostSettingsGet('a'));
      final second = client.ask<String?>(const SyncIsolateHostSettingsGet('b'));
      final requestA = await nextRequest();
      final requestB = await nextRequest();

      expect(requestA.requestId, isNot(requestB.requestId));
      expect((requestA.query as SyncIsolateHostSettingsGet).key, 'a');
      expect((requestB.query as SyncIsolateHostSettingsGet).key, 'b');

      // Answered out of order: each reply finds its own caller.
      client
        ..onReply(SyncIsolateHostReply.success(requestB.requestId, 'B'))
        ..onReply(SyncIsolateHostReply.success(requestA.requestId, 'A'));

      expect(await first, 'A');
      expect(await second, 'B');
    },
  );

  test('a failure reply throws the failure to the caller', () async {
    final asked = client.ask<bool>(const SyncIsolateHostConfigFlag('x'));
    final request = await nextRequest();

    client.onReply(
      SyncIsolateHostReply.failure(
        request.requestId,
        const SyncIsolateFailure(SyncIsolateErrorCode.failed, 'no database'),
      ),
    );

    await expectLater(
      asked,
      throwsA(
        isA<SyncIsolateFailure>().having(
          (f) => f.message,
          'message',
          'no database',
        ),
      ),
    );
  });

  test('a reply to nothing is dropped', () {
    expect(
      () => client.onReply(const SyncIsolateHostReply.success(99, 'late')),
      returnsNormally,
    );
  });

  test('an unanswered query times out and a late reply is then ignored', () {
    fakeAsync((async) {
      final timed = SyncIsolateHostClient(
        hostPort.sendPort,
        timeout: const Duration(seconds: 5),
      );
      Object? error;
      timed.ask<String?>(const SyncIsolateHostVectorClockHost()).catchError((
        Object e,
      ) {
        error = e;
        return null;
      });
      async.elapse(const Duration(seconds: 6));

      expect(
        error,
        isA<SyncIsolateFailure>().having(
          (f) => f.code,
          'code',
          SyncIsolateErrorCode.timeout,
        ),
      );
      expect(
        () => timed.onReply(const SyncIsolateHostReply.success(0, 'late')),
        returnsNormally,
      );
    });
  });

  test('dispose fails every waiting query as notRunning', () async {
    final asked = client.ask<String?>(const SyncIsolateHostSettingsGet('a'));
    await nextRequest();

    client.dispose();

    await expectLater(
      asked,
      throwsA(
        isA<SyncIsolateFailure>().having(
          (f) => f.code,
          'code',
          SyncIsolateErrorCode.notRunning,
        ),
      ),
    );
  });

  group('the stores over the client', () {
    /// Answers the next request with [result] and returns the query it
    /// carried, so a test checks both what was asked and what came back.
    Future<SyncIsolateHostQuery> answer(Object? result) async {
      final request = await nextRequest();
      client.onReply(SyncIsolateHostReply.success(request.requestId, result));
      return request.query;
    }

    test('HostKeyValueStore reads, writes and removes settings keys', () async {
      final store = HostKeyValueStore(client);

      final read = store.itemByKey('room');
      expect(await answer('!r:x'), isA<SyncIsolateHostSettingsGet>());
      expect(await read, '!r:x');

      final written = store.saveSettingsItem('room', '!s:x');
      final setQuery = await answer(1) as SyncIsolateHostSettingsSet;
      expect((setQuery.key, setQuery.value), ('room', '!s:x'));
      expect(await written, 1);

      final removed = store.removeSettingsItem('room');
      final removeQuery = await answer(null) as SyncIsolateHostSettingsRemove;
      expect(removeQuery.key, 'room');
      await removed;
    });

    test('HostPayloadSource asks for journal rows, a conflict version and a '
        'flag', () async {
      final source = HostPayloadSource(client);
      final entity = testTextEntry;
      const clock = VectorClock({'a': 1});

      final rows = source.journalEntityMapForIdsIncludingDeleted(['x', 'y']);
      final idsQuery =
          await answer(<String, JournalEntity>{'x': entity})
              as SyncIsolateHostJournalEntities;
      expect(idsQuery.ids, ['x', 'y']);
      expect((await rows)['x'], same(entity));

      final conflict = source.openConflictVersion('x', clock);
      final conflictQuery =
          await answer(entity) as SyncIsolateHostOpenConflictVersion;
      expect(conflictQuery.id, 'x');
      expect(conflictQuery.vectorClock, clock);
      expect(await conflict, same(entity));

      final flag = source.getConfigFlag('resend');
      final flagQuery = await answer(true) as SyncIsolateHostConfigFlag;
      expect(flagQuery.flagName, 'resend');
      expect(await flag, isTrue);
    });

    test('HostIdSource asks for the vector-clock host', () async {
      final host = HostIdSource(client).getHost();

      expect(await answer('host-1'), isA<SyncIsolateHostVectorClockHost>());
      expect(await host, 'host-1');
    });
  });
}
