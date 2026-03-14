import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/last_read.dart';
import 'package:lotti/features/sync/matrix/pipeline/matrix_stream_consumer.dart';
import 'package:lotti/features/sync/matrix/read_marker_service.dart';
import 'package:lotti/features/sync/matrix/sent_event_registry.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import 'matrix_stream_consumer_test_support.dart';

void _stubLogger(MockLoggingService logger) {
  when(
    () => logger.captureEvent(
      any<Object>(),
      domain: any<String>(named: 'domain'),
      subDomain: any<String>(named: 'subDomain'),
    ),
  ).thenReturn(null);
  when(
    () => logger.captureException(
      any<Object>(),
      domain: any<String>(named: 'domain'),
      subDomain: any<String>(named: 'subDomain'),
      stackTrace: any<StackTrace?>(named: 'stackTrace'),
    ),
  ).thenAnswer((_) async {});
}

void _stubProcessor(
  MockSyncEventProcessor processor,
  MockJournalDb journalDb,
) {
  when(() => processor.cachePurgeListener = any()).thenReturn(null);
  when(() => processor.descriptorPendingListener = any()).thenReturn(null);
  when(() => processor.startupTimestamp = any()).thenReturn(null);
  when(
    () => processor.process(
      event: any<Event>(named: 'event'),
      journalDb: journalDb,
    ),
  ).thenAnswer((_) async {});
}

void _stubReadMarker(MockSyncReadMarkerService readMarker) {
  when(
    () => readMarker.updateReadMarker(
      client: any<Client>(named: 'client'),
      room: any<Room>(named: 'room'),
      eventId: any<String>(named: 'eventId'),
    ),
  ).thenAnswer((_) async {});
}

void _stubSettings(MockSettingsDb settingsDb) {
  when(
    () => settingsDb.itemByKey(lastReadMatrixEventId),
  ).thenAnswer((_) async => null);
  when(
    () => settingsDb.itemByKey(lastReadMatrixEventTs),
  ).thenAnswer((_) async => null);
  when(
    () => settingsDb.saveSettingsItem(any(), any()),
  ).thenAnswer((_) async => 1);
}

MatrixStreamConsumer _buildConsumer({
  required MockMatrixSessionManager session,
  required MockSyncRoomManager roomManager,
  required MockLoggingService logger,
  required MockJournalDb journalDb,
  required MockSettingsDb settingsDb,
  required MockSyncEventProcessor processor,
  required MockSyncReadMarkerService readMarker,
}) {
  return MatrixStreamConsumer(
    skipSyncWait: true,
    sessionManager: session,
    roomManager: roomManager,
    loggingService: logger,
    journalDb: journalDb,
    settingsDb: settingsDb,
    eventProcessor: processor,
    readMarkerService: readMarker,
    sentEventRegistry: SentEventRegistry(),
  );
}

MockEvent _buildSyncPayloadEvent({
  required String eventId,
  required String roomId,
  int timestampMs = 1,
}) {
  final event = MockEvent();
  when(() => event.eventId).thenReturn(eventId);
  when(
    () => event.originServerTs,
  ).thenReturn(DateTime.fromMillisecondsSinceEpoch(timestampMs));
  when(() => event.senderId).thenReturn('@other:server');
  when(() => event.attachmentMimetype).thenReturn('');
  when(
    () => event.content,
  ).thenReturn(<String, dynamic>{'msgtype': syncMessageType});
  when(() => event.roomId).thenReturn(roomId);
  return event;
}

void main() {
  setUpAll(registerMatrixStreamConsumerFallbacks);

  test('initialize is idempotent and restores startup markers once', () async {
    final session = MockMatrixSessionManager();
    final roomManager = MockSyncRoomManager();
    final logger = MockLoggingService();
    final journalDb = MockJournalDb();
    final settingsDb = MockSettingsDb();
    final processor = MockSyncEventProcessor();
    final readMarker = MockSyncReadMarkerService();
    final client = MockClient();

    _stubLogger(logger);
    _stubProcessor(processor, journalDb);
    _stubReadMarker(readMarker);
    _stubSettings(settingsDb);

    when(() => session.client).thenReturn(client);
    when(() => client.userID).thenReturn('@me:server');
    when(
      () => session.timelineEvents,
    ).thenAnswer((_) => const Stream<Event>.empty());
    when(() => roomManager.initialize()).thenAnswer((_) async {});
    when(() => roomManager.currentRoom).thenReturn(null);
    when(() => roomManager.currentRoomId).thenReturn(null);
    when(
      () => settingsDb.itemByKey(lastReadMatrixEventId),
    ).thenAnswer((_) async => r'$server-event');
    when(
      () => settingsDb.itemByKey(lastReadMatrixEventTs),
    ).thenAnswer((_) async => '1234');

    final consumer = _buildConsumer(
      session: session,
      roomManager: roomManager,
      logger: logger,
      journalDb: journalDb,
      settingsDb: settingsDb,
      processor: processor,
      readMarker: readMarker,
    );

    await consumer.initialize();
    await consumer.initialize();
    await consumer.dispose();

    verify(() => roomManager.initialize()).called(1);
    verify(() => processor.startupTimestamp = 1234).called(1);
    verify(
      () => logger.captureEvent(
        contains(r'startup.marker id=$server-event ts=1234'),
        domain: syncLoggingDomain,
        subDomain: 'startup.marker',
      ),
    ).called(1);
  });

  test(
    'start hydrates a missing room and processes catch-up history',
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
      final catchupTimeline = MockTimeline();
      final liveTimeline = MockTimeline();
      final event = _buildSyncPayloadEvent(
        eventId: r'$history-1',
        roomId: '!room:server',
      );
      Room? currentRoom;

      _stubLogger(logger);
      _stubProcessor(processor, journalDb);
      _stubReadMarker(readMarker);
      _stubSettings(settingsDb);

      when(() => session.client).thenReturn(client);
      when(() => client.userID).thenReturn('@me:server');
      when(
        () => session.timelineEvents,
      ).thenAnswer((_) => const Stream<Event>.empty());
      when(() => roomManager.initialize()).thenAnswer((_) async {});
      when(() => roomManager.currentRoom).thenAnswer((_) => currentRoom);
      when(() => roomManager.currentRoomId).thenReturn('!room:server');
      when(
        () => roomManager.hydrateRoomSnapshot(client: client),
      ).thenAnswer((_) async {
        currentRoom = room;
      });
      when(() => catchupTimeline.events).thenReturn(<Event>[event]);
      when(() => catchupTimeline.cancelSubscriptions()).thenReturn(null);
      when(
        () => room.getTimeline(limit: any<int>(named: 'limit')),
      ).thenAnswer((_) async => catchupTimeline);
      when(() => liveTimeline.events).thenReturn(<Event>[]);
      when(() => liveTimeline.cancelSubscriptions()).thenReturn(null);
      when(
        () => room.getTimeline(
          onNewEvent: any(named: 'onNewEvent'),
          onInsert: any(named: 'onInsert'),
          onChange: any(named: 'onChange'),
          onRemove: any(named: 'onRemove'),
          onUpdate: any(named: 'onUpdate'),
        ),
      ).thenAnswer((_) async => liveTimeline);

      final consumer = _buildConsumer(
        session: session,
        roomManager: roomManager,
        logger: logger,
        journalDb: journalDb,
        settingsDb: settingsDb,
        processor: processor,
        readMarker: readMarker,
      );

      await consumer.initialize();
      await consumer.start();
      await consumer.dispose();

      verify(() => roomManager.hydrateRoomSnapshot(client: client)).called(1);
      verify(
        () => processor.process(event: event, journalDb: journalDb),
      ).called(1);
    },
  );

  test('start handles live timeline attach failure gracefully', () async {
    final session = MockMatrixSessionManager();
    final roomManager = MockSyncRoomManager();
    final logger = MockLoggingService();
    final journalDb = MockJournalDb();
    final settingsDb = MockSettingsDb();
    final processor = MockSyncEventProcessor();
    final readMarker = MockSyncReadMarkerService();
    final client = MockClient();
    final room = MockRoom();
    final catchupTimeline = MockTimeline();

    _stubLogger(logger);
    _stubProcessor(processor, journalDb);
    _stubReadMarker(readMarker);
    _stubSettings(settingsDb);

    when(() => session.client).thenReturn(client);
    when(() => client.userID).thenReturn('@me:server');
    when(
      () => session.timelineEvents,
    ).thenAnswer((_) => const Stream<Event>.empty());
    when(() => roomManager.initialize()).thenAnswer((_) async {});
    when(() => roomManager.currentRoom).thenReturn(room);
    when(() => roomManager.currentRoomId).thenReturn('!room:server');
    when(() => catchupTimeline.events).thenReturn(<Event>[]);
    when(() => catchupTimeline.cancelSubscriptions()).thenReturn(null);
    when(
      () => room.getTimeline(limit: any<int>(named: 'limit')),
    ).thenAnswer((_) async => catchupTimeline);
    when(
      () => room.getTimeline(
        onNewEvent: any(named: 'onNewEvent'),
        onInsert: any(named: 'onInsert'),
        onChange: any(named: 'onChange'),
        onRemove: any(named: 'onRemove'),
        onUpdate: any(named: 'onUpdate'),
      ),
    ).thenThrow(StateError('attach failed'));

    final consumer = _buildConsumer(
      session: session,
      roomManager: roomManager,
      logger: logger,
      journalDb: journalDb,
      settingsDb: settingsDb,
      processor: processor,
      readMarker: readMarker,
    );

    await consumer.initialize();
    await consumer.start();
    await consumer.dispose();

    verify(
      () => logger.captureException(
        any<Object>(),
        domain: syncLoggingDomain,
        subDomain: 'attach.liveTimeline',
        stackTrace: any<StackTrace?>(named: 'stackTrace'),
      ),
    ).called(1);
    verify(
      () => logger.captureEvent(
        contains('MatrixStreamConsumer started'),
        domain: syncLoggingDomain,
        subDomain: 'start',
      ),
    ).called(1);
  });

  test('dispose cancels the attached live timeline subscription', () async {
    final session = MockMatrixSessionManager();
    final roomManager = MockSyncRoomManager();
    final logger = MockLoggingService();
    final journalDb = MockJournalDb();
    final settingsDb = MockSettingsDb();
    final processor = MockSyncEventProcessor();
    final readMarker = MockSyncReadMarkerService();
    final client = MockClient();
    final room = MockRoom();
    final catchupTimeline = MockTimeline();
    final liveTimeline = MockTimeline();

    _stubLogger(logger);
    _stubProcessor(processor, journalDb);
    _stubReadMarker(readMarker);
    _stubSettings(settingsDb);

    when(() => session.client).thenReturn(client);
    when(() => client.userID).thenReturn('@me:server');
    when(
      () => session.timelineEvents,
    ).thenAnswer((_) => const Stream<Event>.empty());
    when(() => roomManager.initialize()).thenAnswer((_) async {});
    when(() => roomManager.currentRoom).thenReturn(room);
    when(() => roomManager.currentRoomId).thenReturn('!room:server');
    when(() => catchupTimeline.events).thenReturn(<Event>[]);
    when(() => catchupTimeline.cancelSubscriptions()).thenReturn(null);
    when(
      () => room.getTimeline(limit: any<int>(named: 'limit')),
    ).thenAnswer((_) async => catchupTimeline);
    when(() => liveTimeline.events).thenReturn(<Event>[]);
    when(() => liveTimeline.cancelSubscriptions()).thenReturn(null);
    when(
      () => room.getTimeline(
        onNewEvent: any(named: 'onNewEvent'),
        onInsert: any(named: 'onInsert'),
        onChange: any(named: 'onChange'),
        onRemove: any(named: 'onRemove'),
        onUpdate: any(named: 'onUpdate'),
      ),
    ).thenAnswer((_) async => liveTimeline);

    final consumer = _buildConsumer(
      session: session,
      roomManager: roomManager,
      logger: logger,
      journalDb: journalDb,
      settingsDb: settingsDb,
      processor: processor,
      readMarker: readMarker,
    );

    await consumer.initialize();
    await consumer.start();
    clearInteractions(liveTimeline);

    await consumer.dispose();

    verify(() => liveTimeline.cancelSubscriptions()).called(1);
    verify(
      () => logger.captureEvent(
        contains('MatrixStreamConsumer disposed'),
        domain: syncLoggingDomain,
        subDomain: 'dispose',
      ),
    ).called(1);
  });
}
