import 'dart:io';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
// ignore_for_file: unnecessary_lambdas, cascade_invocations, unawaited_futures
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/pipeline_v2/matrix_stream_consumer.dart';
import 'package:lotti/features/sync/matrix/read_marker_service.dart';
import 'package:lotti/features/sync/matrix/session_manager.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';
import 'package:matrix/src/utils/cached_stream_controller.dart';
import 'package:mocktail/mocktail.dart';

class MockMatrixSessionManager extends Mock implements MatrixSessionManager {}

class MockSyncRoomManager extends Mock implements SyncRoomManager {}

class MockLoggingService extends Mock implements LoggingService {}

class MockJournalDb extends Mock implements JournalDb {}

class MockSettingsDb extends Mock implements SettingsDb {}

class MockSyncEventProcessor extends Mock implements SyncEventProcessor {}

class MockSyncReadMarkerService extends Mock implements SyncReadMarkerService {}

class MockClient extends Mock implements Client {}

class MockRoom extends Mock implements Room {}

class MockTimeline extends Mock implements Timeline {}

class MockEvent extends Mock implements Event {}

class _FakeClient extends Fake implements Client {}

class _FakeRoom extends Fake implements Room {}

class _FakeTimeline extends Fake implements Timeline {}

class _FakeEvent extends Fake implements Event {}

void main() {
  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
    // Fallbacks for typed `any<T>` matchers used in mocks
    registerFallbackValue(_FakeClient());
    registerFallbackValue(_FakeRoom());
    registerFallbackValue(_FakeTimeline());
    registerFallbackValue(_FakeEvent());
  });

  group('MatrixStreamConsumer catch-up', () {
    test('processes strictly after lastProcessed and advances marker',
        () async {
      fakeAsync((async) async {
        final session = MockMatrixSessionManager();
        final roomManager = MockSyncRoomManager();
        final logger = MockLoggingService();
        final journalDb = MockJournalDb();
        final settingsDb = MockSettingsDb();
        final processor = MockSyncEventProcessor();
        final readMarker = MockSyncReadMarkerService();
        final client = MockClient();
        final room = MockRoom();
        final timeline = MockTimeline();
        final tempDir = await Directory.systemTemp.createTemp('msc_v2');
        final onTimelineController = CachedStreamController<Event>();

        addTearDown(() => tempDir.deleteSync(recursive: true));
        addTearDown(onTimelineController.close);

        when(() => logger.captureEvent(any<String>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'))).thenReturn(null);
        when(() => logger.captureException(any<Object>(),
                domain: any<String>(named: 'domain'),
                subDomain: any<String>(named: 'subDomain'),
                stackTrace: any<StackTrace?>(named: 'stackTrace')))
            .thenReturn(null);

        when(() => session.client).thenReturn(client);
        when(() => client.userID).thenReturn('@me:server');
        when(() => client.onTimelineEvent).thenReturn(onTimelineController);
        when(() => roomManager.initialize()).thenAnswer((_) async {});
        when(() => roomManager.currentRoom).thenReturn(room);
        when(() => roomManager.currentRoomId).thenReturn('!room:server');
        when(() => settingsDb.itemByKey(lastReadMatrixEventId))
            .thenAnswer((_) async => 'existing');

        // Events: existing(ts1), newA(ts2), newB(ts3) in unsorted order
        final existing = MockEvent();
        when(() => existing.eventId).thenReturn('existing');
        when(() => existing.originServerTs)
            .thenReturn(DateTime.fromMillisecondsSinceEpoch(1));
        when(() => existing.senderId).thenReturn('@other:server');
        when(() => existing.attachmentMimetype).thenReturn('');
        when(() => existing.content).thenReturn(<String, dynamic>{});

        final newA = MockEvent();
        when(() => newA.eventId).thenReturn('newA');
        when(() => newA.originServerTs)
            .thenReturn(DateTime.fromMillisecondsSinceEpoch(2));
        when(() => newA.senderId).thenReturn('@other:server');
        when(() => newA.attachmentMimetype).thenReturn('');
        when(() => newA.content)
            .thenReturn(<String, dynamic>{'msgtype': syncMessageType});

        final newB = MockEvent();
        when(() => newB.eventId).thenReturn('newB');
        when(() => newB.originServerTs)
            .thenReturn(DateTime.fromMillisecondsSinceEpoch(3));
        when(() => newB.senderId).thenReturn('@other:server');
        when(() => newB.attachmentMimetype).thenReturn('');
        when(() => newB.content)
            .thenReturn(<String, dynamic>{'msgtype': syncMessageType});

        when(() => timeline.events).thenReturn(<Event>[newB, existing, newA]);
        when(() => timeline.cancelSubscriptions()).thenReturn(null);
        when(() => room.getTimeline(limit: any(named: 'limit')))
            .thenAnswer((_) async => timeline);

        when(() => processor.process(
            event: any<Event>(named: 'event'),
            journalDb: journalDb)).thenAnswer((_) async {});
        when(() => readMarker.updateReadMarker(
              client: any<Client>(named: 'client'),
              room: any<Room>(named: 'room'),
              eventId: any<String>(named: 'eventId'),
            )).thenAnswer((_) async {});

        final consumer = MatrixStreamConsumer(
          sessionManager: session,
          roomManager: roomManager,
          loggingService: logger,
          journalDb: journalDb,
          settingsDb: settingsDb,
          eventProcessor: processor,
          readMarkerService: readMarker,
          documentsDirectory: tempDir,
        );

        await consumer.initialize();
        await consumer.start();

        // Advance debounce timer to flush read marker.
        async.elapse(const Duration(milliseconds: 700));
        async.flushMicrotasks();

        verify(() => processor.process(event: newA, journalDb: journalDb))
            .called(1);
        verify(() => processor.process(event: newB, journalDb: journalDb))
            .called(1);
        verify(
          () => readMarker.updateReadMarker(
            client: client,
            room: room,
            eventId: 'newB',
          ),
        ).called(1);
      });
    });

    test('prefetches attachments for remote file events during catch-up',
        () async {
      fakeAsync((async) async {
        final session = MockMatrixSessionManager();
        final roomManager = MockSyncRoomManager();
        final logger = MockLoggingService();
        final journalDb = MockJournalDb();
        final settingsDb = MockSettingsDb();
        final processor = MockSyncEventProcessor();
        final readMarker = MockSyncReadMarkerService();
        final client = MockClient();
        final room = MockRoom();
        final timeline = MockTimeline();
        final tempDir = await Directory.systemTemp.createTemp('msc_v2_files');
        final onTimelineController = CachedStreamController<Event>();

        addTearDown(() => tempDir.deleteSync(recursive: true));
        addTearDown(onTimelineController.close);

        when(() => logger.captureEvent(any<String>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'))).thenReturn(null);
        when(() => logger.captureException(any<Object>(),
                domain: any<String>(named: 'domain'),
                subDomain: any<String>(named: 'subDomain'),
                stackTrace: any<StackTrace?>(named: 'stackTrace')))
            .thenReturn(null);

        when(() => session.client).thenReturn(client);
        when(() => client.userID).thenReturn('@me:server');
        when(() => client.onTimelineEvent).thenReturn(onTimelineController);
        when(() => roomManager.initialize()).thenAnswer((_) async {});
        when(() => roomManager.currentRoom).thenReturn(room);
        when(() => roomManager.currentRoomId).thenReturn('!room:server');
        when(() => settingsDb.itemByKey(lastReadMatrixEventId))
            .thenAnswer((_) async => null);

        final fileEvent = MockEvent();
        when(() => fileEvent.eventId).thenReturn('file1');
        when(() => fileEvent.originServerTs)
            .thenReturn(DateTime.fromMillisecondsSinceEpoch(10));
        when(() => fileEvent.senderId).thenReturn('@other:server');
        when(() => fileEvent.attachmentMimetype).thenReturn('application/json');
        when(() => fileEvent.content)
            .thenReturn(<String, dynamic>{'relativePath': '/sub/test.json'});
        when(() => fileEvent.downloadAndDecryptAttachment()).thenAnswer(
          (_) async => MatrixFile(
            bytes: Uint8List.fromList('{"k":1}'.codeUnits),
            name: 'test.json',
          ),
        );

        when(() => timeline.events).thenReturn(<Event>[fileEvent]);
        when(() => timeline.cancelSubscriptions()).thenReturn(null);
        when(() => room.getTimeline(limit: any(named: 'limit')))
            .thenAnswer((_) async => timeline);

        when(() => processor.process(
            event: any<Event>(named: 'event'),
            journalDb: journalDb)).thenAnswer((_) async {});
        when(() => readMarker.updateReadMarker(
              client: any<Client>(named: 'client'),
              room: any<Room>(named: 'room'),
              eventId: any<String>(named: 'eventId'),
            )).thenAnswer((_) async {});

        final consumer = MatrixStreamConsumer(
          sessionManager: session,
          roomManager: roomManager,
          loggingService: logger,
          journalDb: journalDb,
          settingsDb: settingsDb,
          eventProcessor: processor,
          readMarkerService: readMarker,
          documentsDirectory: tempDir,
        );

        await consumer.initialize();
        await consumer.start();

        async.elapse(const Duration(milliseconds: 700));
        async.flushMicrotasks();

        // Attachment written
        final saved = File('${tempDir.path}/sub/test.json');
        expect(saved.existsSync(), isTrue);
      });
    });

    test('expands catch-up window to include backlog and does not skip events',
        () async {
      fakeAsync((async) async {
        final session = MockMatrixSessionManager();
        final roomManager = MockSyncRoomManager();
        final logger = MockLoggingService();
        final journalDb = MockJournalDb();
        final settingsDb = MockSettingsDb();
        final processor = MockSyncEventProcessor();
        final readMarker = MockSyncReadMarkerService();
        final client = MockClient();
        final room = MockRoom();
        final onTimelineController = CachedStreamController<Event>();

        addTearDown(onTimelineController.close);

        when(() => logger.captureEvent(any<String>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'))).thenReturn(null);
        when(() => logger.captureException(any<Object>(),
                domain: any<String>(named: 'domain'),
                subDomain: any<String>(named: 'subDomain'),
                stackTrace: any<StackTrace?>(named: 'stackTrace')))
            .thenReturn(null);

        when(() => session.client).thenReturn(client);
        when(() => client.userID).thenReturn('@me:server');
        when(() => client.onTimelineEvent).thenReturn(onTimelineController);
        when(() => roomManager.initialize()).thenAnswer((_) async {});
        when(() => roomManager.currentRoom).thenReturn(room);
        when(() => roomManager.currentRoomId).thenReturn('!room:server');

        // Simulate last processed far behind the latest (e499 of 1200 events)
        when(() => settingsDb.itemByKey(lastReadMatrixEventId))
            .thenAnswer((_) async => 'e499');

        // Build 1200 events with increasing timestamps
        List<Event> buildAll() {
          final list = <Event>[];
          for (var i = 0; i < 1200; i++) {
            final e = MockEvent();
            when(() => e.eventId).thenReturn('e$i');
            when(() => e.originServerTs)
                .thenReturn(DateTime.fromMillisecondsSinceEpoch(i));
            when(() => e.senderId).thenReturn('@other:server');
            when(() => e.attachmentMimetype).thenReturn('');
            when(() => e.content)
                .thenReturn(<String, dynamic>{'msgtype': syncMessageType});
            list.add(e);
          }
          return list;
        }

        final allEvents = buildAll();

        Future<Timeline> timelineForLimit(int limit) async {
          final tl = MockTimeline();
          final start = allEvents.length > limit ? allEvents.length - limit : 0;
          final sub = allEvents.sublist(start);
          when(() => tl.events).thenReturn(sub);
          when(() => tl.cancelSubscriptions()).thenReturn(null);
          return tl;
        }

        when(() => room.getTimeline(limit: any(named: 'limit'))).thenAnswer(
          (invocation) async {
            final limit = invocation.namedArguments[#limit] as int? ?? 200;
            return timelineForLimit(limit);
          },
        );

        when(() => processor.process(
            event: any<Event>(named: 'event'),
            journalDb: journalDb)).thenAnswer((_) async {});
        when(() => readMarker.updateReadMarker(
              client: any<Client>(named: 'client'),
              room: any<Room>(named: 'room'),
              eventId: any<String>(named: 'eventId'),
            )).thenAnswer((_) async {});

        final consumer = MatrixStreamConsumer(
          sessionManager: session,
          roomManager: roomManager,
          loggingService: logger,
          journalDb: journalDb,
          settingsDb: settingsDb,
          eventProcessor: processor,
          readMarkerService: readMarker,
          documentsDirectory: Directory.systemTemp,
          collectMetrics: true,
        );

        await consumer.initialize();
        await consumer.start();

        // Advance debounce timer to flush read marker.
        async.elapse(const Duration(milliseconds: 700));
        async.flushMicrotasks();

        // Expect 700 events processed: e500..e1199
        verify(() => processor.process(
              event: any<Event>(named: 'event'),
              journalDb: journalDb,
            )).called(700);
      });
    });
  });

  group('MatrixStreamConsumer live timeline + hydration', () {
    test('start hydrates room when missing and attaches live timeline',
        () async {
      final session = MockMatrixSessionManager();
      final roomManager = MockSyncRoomManager();
      final logger = MockLoggingService();
      final journalDb = MockJournalDb();
      final settingsDb = MockSettingsDb();
      final processor = MockSyncEventProcessor();
      final readMarker = MockSyncReadMarkerService();
      final client = MockClient();
      final room = MockRoom();
      final timeline = MockTimeline();
      final onTimelineController = CachedStreamController<Event>();

      when(() => logger.captureEvent(any<String>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'))).thenReturn(null);
      when(() => logger.captureException(any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<StackTrace?>(named: 'stackTrace'))).thenReturn(null);

      when(() => session.client).thenReturn(client);
      when(() => client.userID).thenReturn('@me:server');
      when(() => client.onTimelineEvent).thenReturn(onTimelineController);
      when(() => settingsDb.itemByKey(lastReadMatrixEventId))
          .thenAnswer((_) async => null);
      // First, room missing to force hydrate
      when(() => roomManager.initialize()).thenAnswer((_) async {});
      when(() => roomManager.currentRoom).thenReturn(null);
      when(() => roomManager.currentRoomId).thenReturn('!room:server');
      when(() => roomManager.hydrateRoomSnapshot(
          client: any<Client>(named: 'client'))).thenAnswer((_) async {
        // After hydration, room available
        when(() => roomManager.currentRoom).thenReturn(room);
      });

      // Simulate live timeline attach; call onNewEvent immediately, return timeline
      when(
        () => room.getTimeline(
          limit: any<int>(named: 'limit'),
          onNewEvent: any<void Function()>(named: 'onNewEvent'),
          onInsert: any<void Function(int)>(named: 'onInsert'),
          onChange: any<void Function(int)>(named: 'onChange'),
          onRemove: any<void Function(int)>(named: 'onRemove'),
          onUpdate: any<void Function()>(named: 'onUpdate'),
        ),
      ).thenAnswer((invocation) async {
        final onNew =
            invocation.namedArguments[#onNewEvent] as void Function()?;
        onNew?.call();
        return timeline;
      });

      // Provide one new event in the live timeline
      final newEvent = MockEvent();
      when(() => newEvent.eventId).thenReturn('e1');
      when(() => newEvent.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(2));
      when(() => newEvent.senderId).thenReturn('@other:server');
      when(() => newEvent.attachmentMimetype).thenReturn('');
      when(() => newEvent.content)
          .thenReturn(<String, dynamic>{'msgtype': syncMessageType});
      when(() => timeline.events).thenReturn(<Event>[newEvent]);

      when(() => processor.process(
          event: any<Event>(named: 'event'),
          journalDb: journalDb)).thenAnswer((_) async {});
      when(() => readMarker.updateReadMarker(
            client: any<Client>(named: 'client'),
            room: any<Room>(named: 'room'),
            eventId: any<String>(named: 'eventId'),
          )).thenAnswer((_) async {});

      final consumer = MatrixStreamConsumer(
        sessionManager: session,
        roomManager: roomManager,
        loggingService: logger,
        journalDb: journalDb,
        settingsDb: settingsDb,
        eventProcessor: processor,
        readMarkerService: readMarker,
        documentsDirectory: Directory.systemTemp,
        collectMetrics: true,
      );

      await consumer.initialize();
      await consumer.start();

      // Allow liveScan debounce to elapse
      await Future<void>.delayed(const Duration(milliseconds: 200));

      verify(() => roomManager.hydrateRoomSnapshot(client: client)).called(1);
      verify(() => processor.process(event: newEvent, journalDb: journalDb))
          .called(1);
      final metrics = consumer.metricsSnapshot();
      expect(metrics['processed'], greaterThanOrEqualTo(1));
    });
  });
}
