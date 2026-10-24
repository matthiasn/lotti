import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/logging_types.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/isolate/sync_isolate_protocol.dart';
import 'package:lotti/features/sync/isolate/sync_isolate_worker.dart';
import 'package:lotti/features/sync/queue/inbound_event_queue.dart';
import 'package:lotti/features/sync/queue/inbound_queue_settlement.dart';
import 'package:lotti/services/domain_logging.dart';

import '../../../mocks/mocks.dart';
import '../queue/test_utils.dart';

/// Drives [syncIsolateEntry] in the test isolate, standing in for the host:
/// the worker's messages land on the host port in the order it sent them.
void main() {
  late ReceivePort host;
  late StreamIterator<Object?> inbox;
  late SendPort commands;

  setUp(() async {
    host = ReceivePort();
    inbox = StreamIterator(host);
    unawaited(
      syncIsolateEntry(
        SyncIsolateBoot(
          host: host.sendPort,
          config: const SyncIsolateConfig(
            documentsPath: '',
            temporaryPath: '',
            inMemoryDatabase: true,
          ),
        ),
      ),
    );
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

  group('as the owner of a sync.sqlite the UI isolate also opens', () {
    const roomId = '!room:example.org';
    late Directory tempDir;
    late SyncDatabase db;
    late InboundQueue queue;
    late ReceivePort fileHost;
    late StreamIterator<Object?> fileInbox;
    late SendPort fileCommands;
    var requestId = 0;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('sync_isolate_worker');
      db = SyncDatabase(
        background: false,
        documentsDirectoryProvider: () async => tempDir,
        tempDirectoryProvider: () async => tempDir,
      );
      queue = InboundQueue(
        trust: AdmittingSyncEventTrust(),
        db: db,
        logging: MockDomainLogger(),
      );
      fileHost = ReceivePort();
      fileInbox = StreamIterator(fileHost);
      unawaited(
        syncIsolateEntry(
          SyncIsolateBoot(
            host: fileHost.sendPort,
            config: SyncIsolateConfig(
              documentsPath: tempDir.path,
              temporaryPath: tempDir.path,
            ),
          ),
        ),
      );
      await fileInbox.moveNext();
      fileCommands = (fileInbox.current! as SyncIsolateReady).commands;
      await fileInbox.moveNext(); // the startup log line
    });

    tearDown(() async {
      fileCommands.send(
        SyncIsolateRequest(
          requestId: ++requestId,
          command: const SyncIsolateShutdown(),
        ),
      );
      // Drain until the shutdown reply so the worker's database is closed
      // before the directory goes.
      while (await fileInbox.moveNext()) {
        final message = fileInbox.current;
        if (message is SyncIsolateReply && message.result == null) break;
      }
      await fileInbox.cancel();
      fileHost.close();
      await queue.dispose();
      await db.close();
      await tempDir.delete(recursive: true);
    });

    Future<Object?> nextFile() async {
      await fileInbox.moveNext();
      return fileInbox.current;
    }

    Future<SyncIsolateReply> ask(SyncIsolateCommand command) async {
      fileCommands.send(
        SyncIsolateRequest(requestId: ++requestId, command: command),
      );
      while (true) {
        final message = await nextFile();
        if (message is SyncIsolateReply) return message;
      }
    }

    test('leases what the UI isolate enqueued, reports the tables it wrote, '
        'and settles into the state both connections read', () async {
      await queue.enqueueLive(
        buildSyncEvent(eventId: r'$a', roomId: roomId, originTsMs: 1),
      );
      await queue.enqueueLive(
        buildSyncEvent(eventId: r'$b', roomId: roomId, originTsMs: 2),
      );

      fileCommands.send(
        SyncIsolateRequest(
          requestId: ++requestId,
          command: const SyncIsolateLeaseEntries(maxBatch: 10),
        ),
      );
      final changed = await nextFile();
      final leaseReply = (await nextFile())! as SyncIsolateReply;
      final leased = leaseReply.result! as List<InboundQueueEntry>;

      expect(changed, isA<SyncIsolateTablesChanged>());
      expect(leased.map((e) => e.eventId), [r'$a', r'$b']);
      expect(
        (await db.select(db.inboundEventQueue).get()).map((r) => r.status),
        everyElement(InboundQueueStatuses.leased),
      );

      fileCommands.send(
        SyncIsolateRequest(
          requestId: ++requestId,
          command: SyncIsolateSettleEntries([
            InboundEntryOutcome(leased[0], ApplyOutcome.applied),
            InboundEntryOutcome(leased[1], ApplyOutcome.retriable),
          ]),
        ),
      );
      // The settlement logs its commit and retry before it reports.
      final untilReply = <Object?>[];
      while (true) {
        final message = await nextFile();
        untilReply.add(message);
        if (message is SyncIsolateReply) break;
      }
      final settleReply = untilReply.last! as SyncIsolateReply;

      expect(
        untilReply.whereType<SyncIsolateTablesChanged>().single.tables,
        inboundQueueTables,
      );
      expect(settleReply.result, 1);
      final stats = await queue.stats();
      expect(stats.applied, 1);
      expect(stats.retrying, 1);
    });

    test('an empty lease writes nothing and reports nothing', () async {
      fileCommands.send(
        SyncIsolateRequest(
          requestId: ++requestId,
          command: const SyncIsolateLeaseEntries(maxBatch: 10),
        ),
      );

      // The very next message is the reply: no tables-changed preceded it.
      final first = await nextFile();
      expect(first, isA<SyncIsolateReply>());
      expect((first! as SyncIsolateReply).result, isEmpty);
    });

    test('a settlement the database refuses is answered as a failure, and '
        'the rows stay leased for the next attempt', () async {
      await queue.enqueueLive(
        buildSyncEvent(eventId: r'$a', roomId: roomId, originTsMs: 1),
      );
      final leased =
          (await ask(const SyncIsolateLeaseEntries(maxBatch: 1))).result!
              as List<InboundQueueEntry>;
      await db.customStatement('''
        CREATE TRIGGER refuse BEFORE UPDATE OF status ON inbound_event_queue
        WHEN NEW.status = 'applied'
        BEGIN SELECT RAISE(ABORT, 'refused'); END
      ''');

      final reply = await ask(
        SyncIsolateSettleEntries([
          InboundEntryOutcome(leased.single, ApplyOutcome.applied),
        ]),
      );

      expect(reply.failure?.code, SyncIsolateErrorCode.failed);
      expect(reply.failure?.message, contains('SyncIsolateSettleEntries'));
      final row = await db.select(db.inboundEventQueue).getSingle();
      expect(row.status, InboundQueueStatuses.leased);
    });

    test('its log lines carry their sub-domain to the host', () async {
      await queue.enqueueLive(
        buildSyncEvent(eventId: r'$a', roomId: roomId, originTsMs: 1),
      );
      final leased =
          (await ask(const SyncIsolateLeaseEntries(maxBatch: 1))).result!
              as List<InboundQueueEntry>;

      fileCommands.send(
        SyncIsolateRequest(
          requestId: ++requestId,
          command: SyncIsolateSettleEntries([
            InboundEntryOutcome(leased.single, ApplyOutcome.applied),
          ]),
        ),
      );
      final messages = <Object?>[];
      while (true) {
        final message = await nextFile();
        messages.add(message);
        if (message is SyncIsolateReply) break;
      }

      final commitLog = messages.whereType<SyncIsolateLog>().firstWhere(
        (l) => l.message.startsWith('queue.commit'),
      );
      expect(commitLog.subDomain, 'queue.commit');
    });
  });

  group('HostForwardingDomainLogger', () {
    late ReceivePort port;
    late StreamIterator<Object?> lines;
    late HostForwardingDomainLogger logger;

    setUp(() {
      port = ReceivePort();
      lines = StreamIterator(port);
      logger = HostForwardingDomainLogger(port.sendPort);
    });

    tearDown(() async {
      await lines.cancel();
      port.close();
    });

    Future<SyncIsolateLog> nextLine() async {
      await lines.moveNext();
      return lines.current! as SyncIsolateLog;
    }

    test('forwards every log line with its sub-domain and level, whether or '
        'not the domain is enabled here', () async {
      logger.log(
        LogDomain.sync,
        'hello',
        subDomain: 'queue',
        level: InsightLevel.warn,
      );

      final line = await nextLine();
      expect(line.message, 'hello');
      expect(line.subDomain, 'queue');
      expect(line.level, InsightLevel.warn);
      expect(logger.enabledDomains, isEmpty);
    });

    test('a sampled line is forwarded as a plain one', () async {
      logger.logSampled(
        LogDomain.sync,
        'often',
        sampleKey: 'k',
        subDomain: 'x',
      );

      final line = await nextLine();
      expect(line.message, 'often');
      expect(line.subDomain, 'x');
      expect(line.level, InsightLevel.info);
    });

    test('an error carries its message, the error and its trace at error '
        'level', () async {
      logger
        ..error(
          LogDomain.sync,
          StateError('boom'),
          stackTrace: StackTrace.fromString('#0 somewhere'),
          subDomain: 'settle',
          message: 'settlement failed',
        )
        ..error(LogDomain.sync, 'bare');

      final withTrace = await nextLine();
      final bare = await nextLine();
      expect(withTrace.level, InsightLevel.error);
      expect(withTrace.subDomain, 'settle');
      expect(
        withTrace.message,
        'settlement failed: Bad state: boom\n#0 somewhere',
      );
      expect(bare.message, 'error: bare');
      expect(bare.subDomain, isNull);
    });

    test(
      'diagnostics are forwarded as an error, without the diagnostics',
      () async {
        logger.errorWithDiagnostics(
          LogDomain.sync,
          'oops',
          diagnostics: 'a widget tree',
          subDomain: 'd',
          message: 'with diagnostics',
        );

        final line = await nextLine();
        expect(line.level, InsightLevel.error);
        expect(line.message, 'with diagnostics: oops');
        expect(line.message, isNot(contains('widget tree')));
      },
    );
  });
}
