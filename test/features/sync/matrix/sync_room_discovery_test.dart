import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/sync_room_discovery.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

class MockLoggingService extends Mock implements LoggingService {}

class MockClient extends Mock implements Client {}

class MockRoom extends Mock implements Room {}

class MockTimeline extends Mock implements Timeline {}

class MockEvent extends Mock implements Event {}

class MockRoomSummary extends Mock implements RoomSummary {}

class MockStrippedStateEvent extends Mock implements StrippedStateEvent {}

void main() {
  late MockLoggingService loggingService;
  late SyncRoomDiscoveryService service;

  setUp(() {
    loggingService = MockLoggingService();

    when(() => loggingService.captureEvent(
          any<String>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String?>(named: 'subDomain'),
        )).thenReturn(null);
    when(() => loggingService.captureException(
          any<dynamic>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String?>(named: 'subDomain'),
          stackTrace: any<dynamic>(named: 'stackTrace'),
        )).thenReturn(null);

    service = SyncRoomDiscoveryService(loggingService: loggingService);
  });

  group('SyncRoomCandidate', () {
    test('confidence is 10 for state marker only', () {
      const candidate = SyncRoomCandidate(
        roomId: '!room:server',
        roomName: 'Test Room',
        createdAt: null,
        memberCount: 2,
        hasStateMarker: true,
        hasLottiContent: false,
      );

      expect(candidate.confidence, 10);
    });

    test('confidence is 5 for content only', () {
      const candidate = SyncRoomCandidate(
        roomId: '!room:server',
        roomName: 'Test Room',
        createdAt: null,
        memberCount: 2,
        hasStateMarker: false,
        hasLottiContent: true,
      );

      expect(candidate.confidence, 5);
    });

    test('confidence is 15 for both markers', () {
      const candidate = SyncRoomCandidate(
        roomId: '!room:server',
        roomName: 'Test Room',
        createdAt: null,
        memberCount: 2,
        hasStateMarker: true,
        hasLottiContent: true,
      );

      expect(candidate.confidence, 15);
    });

    test('toString includes key fields', () {
      const candidate = SyncRoomCandidate(
        roomId: '!room:server',
        roomName: 'My Sync Room',
        createdAt: null,
        memberCount: 2,
        hasStateMarker: true,
        hasLottiContent: false,
      );

      final str = candidate.toString();
      expect(str, contains('!room:server'));
      expect(str, contains('My Sync Room'));
      expect(str, contains('10')); // confidence
    });
  });

  group('discoverSyncRooms', () {
    test('returns empty list when client has no rooms', () async {
      final client = MockClient();
      when(() => client.rooms).thenReturn([]);

      final results = await service.discoverSyncRooms(client);

      expect(results, isEmpty);
      verify(() => loggingService.captureEvent(
            contains('Discovered 0'),
            domain: 'SYNC_ROOM_DISCOVERY',
            subDomain: 'discover',
          )).called(1);
    });

    test('filters out unencrypted rooms', () async {
      final client = MockClient();
      final room = _createMockRoom(
        id: '!unencrypted:server',
        encrypted: false,
        joinRules: JoinRules.invite,
      );

      when(() => client.rooms).thenReturn([room]);

      final results = await service.discoverSyncRooms(client);

      expect(results, isEmpty);
    });

    test('filters out public rooms', () async {
      final client = MockClient();
      final room = _createMockRoom(
        id: '!public:server',
        encrypted: true,
        joinRules: JoinRules.public,
      );

      when(() => client.rooms).thenReturn([room]);

      final results = await service.discoverSyncRooms(client);

      expect(results, isEmpty);
    });

    test('filters out rooms without Lotti markers or content', () async {
      final client = MockClient();
      final room = _createMockRoom(
        id: '!regular:server',
        encrypted: true,
        joinRules: JoinRules.invite,
      );

      when(() => client.rooms).thenReturn([room]);

      final results = await service.discoverSyncRooms(client);

      expect(results, isEmpty);
    });

    test('includes rooms with Lotti state marker', () async {
      final client = MockClient();
      final room = _createMockRoom(
        id: '!marked:server',
        name: 'Marked Room',
        encrypted: true,
        joinRules: JoinRules.invite,
        hasLottiStateMarker: true,
      );

      when(() => client.rooms).thenReturn([room]);

      final results = await service.discoverSyncRooms(client);

      expect(results, hasLength(1));
      expect(results.first.roomId, '!marked:server');
      expect(results.first.hasStateMarker, isTrue);
      expect(results.first.hasLottiContent, isFalse);
    });

    test('includes rooms with Lotti sync content', () async {
      final client = MockClient();
      final room = _createMockRoom(
        id: '!content:server',
        name: 'Content Room',
        encrypted: true,
        joinRules: JoinRules.invite,
        hasLottiContent: true,
      );

      when(() => client.rooms).thenReturn([room]);

      final results = await service.discoverSyncRooms(client);

      expect(results, hasLength(1));
      expect(results.first.roomId, '!content:server');
      expect(results.first.hasStateMarker, isFalse);
      expect(results.first.hasLottiContent, isTrue);
    });

    test('sorts results by confidence descending', () async {
      final client = MockClient();
      final roomBoth = _createMockRoom(
        id: '!both:server',
        name: 'Both Markers',
        encrypted: true,
        joinRules: JoinRules.invite,
        hasLottiStateMarker: true,
        hasLottiContent: true,
      );
      final roomStateOnly = _createMockRoom(
        id: '!state:server',
        name: 'State Only',
        encrypted: true,
        joinRules: JoinRules.invite,
        hasLottiStateMarker: true,
      );
      final roomContentOnly = _createMockRoom(
        id: '!content:server',
        name: 'Content Only',
        encrypted: true,
        joinRules: JoinRules.invite,
        hasLottiContent: true,
      );

      when(() => client.rooms).thenReturn([
        roomContentOnly, // confidence 5 - should be last
        roomStateOnly, // confidence 10 - should be middle
        roomBoth, // confidence 15 - should be first
      ]);

      final results = await service.discoverSyncRooms(client);

      expect(results, hasLength(3));
      expect(results[0].roomId, '!both:server');
      expect(results[0].confidence, 15);
      expect(results[1].roomId, '!state:server');
      expect(results[1].confidence, 10);
      expect(results[2].roomId, '!content:server');
      expect(results[2].confidence, 5);
    });

    test('sorts by creation date when confidence is equal', () async {
      final client = MockClient();
      final olderRoom = _createMockRoom(
        id: '!older:server',
        name: 'Older Room',
        encrypted: true,
        joinRules: JoinRules.invite,
        hasLottiStateMarker: true,
        createdAt: DateTime(2024),
      );
      final newerRoom = _createMockRoom(
        id: '!newer:server',
        name: 'Newer Room',
        encrypted: true,
        joinRules: JoinRules.invite,
        hasLottiStateMarker: true,
        createdAt: DateTime(2025),
      );

      when(() => client.rooms).thenReturn([olderRoom, newerRoom]);

      final results = await service.discoverSyncRooms(client);

      expect(results, hasLength(2));
      // Newer should come first when confidence is equal
      expect(results[0].roomId, '!newer:server');
      expect(results[1].roomId, '!older:server');
    });

    test('handles rooms with null creation date', () async {
      final client = MockClient();
      final roomWithDate = _createMockRoom(
        id: '!dated:server',
        encrypted: true,
        joinRules: JoinRules.invite,
        hasLottiStateMarker: true,
        createdAt: DateTime(2025),
      );
      final roomNoDate = _createMockRoom(
        id: '!undated:server',
        encrypted: true,
        joinRules: JoinRules.invite,
        hasLottiStateMarker: true,
      );

      when(() => client.rooms).thenReturn([roomNoDate, roomWithDate]);

      final results = await service.discoverSyncRooms(client);

      expect(results, hasLength(2));
      // Room with date should come before room without date
      expect(results[0].roomId, '!dated:server');
      expect(results[1].roomId, '!undated:server');
    });
  });

  group('hasExistingSyncRooms', () {
    test('returns false when no sync rooms exist', () async {
      final client = MockClient();
      when(() => client.rooms).thenReturn([]);

      final result = await service.hasExistingSyncRooms(client);

      expect(result, isFalse);
    });

    test('returns true when sync rooms exist', () async {
      final client = MockClient();
      final room = _createMockRoom(
        id: '!sync:server',
        encrypted: true,
        joinRules: JoinRules.invite,
        hasLottiStateMarker: true,
      );

      when(() => client.rooms).thenReturn([room]);

      final result = await service.hasExistingSyncRooms(client);

      expect(result, isTrue);
    });
  });

  group('markRoomAsLottiSync', () {
    test('sets room state with correct type and content', () async {
      final room = MockRoom();
      final client = MockClient();

      when(() => room.id).thenReturn('!room:server');
      when(() => room.client).thenReturn(client);
      when(() => client.setRoomStateWithKey(
            any<String>(),
            any<String>(),
            any<String>(),
            any<Map<String, dynamic>>(),
          )).thenAnswer((_) async => 'event_id');

      await service.markRoomAsLottiSync(room);

      verify(() => client.setRoomStateWithKey(
            '!room:server',
            lottiSyncRoomStateType,
            '',
            any<Map<String, dynamic>>(
              that: predicate<Map<String, dynamic>>((content) {
                return content['version'] == 1 &&
                    content['created_by'] == 'lotti' &&
                    content['marked_at'] is String;
              }),
            ),
          )).called(1);

      verify(() => loggingService.captureEvent(
            contains('Marked room'),
            domain: 'SYNC_ROOM_DISCOVERY',
            subDomain: 'markRoom',
          )).called(1);
    });

    test('logs exception when marking fails', () async {
      final room = MockRoom();
      final client = MockClient();

      when(() => room.id).thenReturn('!room:server');
      when(() => room.client).thenReturn(client);
      when(() => client.setRoomStateWithKey(
            any<String>(),
            any<String>(),
            any<String>(),
            any<Map<String, dynamic>>(),
          )).thenThrow(Exception('Failed to set state'));

      await service.markRoomAsLottiSync(room);

      verify(() => loggingService.captureException(
            any<dynamic>(),
            domain: 'SYNC_ROOM_DISCOVERY',
            subDomain: 'markRoom',
            stackTrace: any<dynamic>(named: 'stackTrace'),
          )).called(1);
    });
  });

  group('sync content detection', () {
    test('detects room with syncMessageType msgtype', () async {
      final client = MockClient();
      final room = _createMockRoomWithEvents(
        id: '!msgtype:server',
        encrypted: true,
        joinRules: JoinRules.invite,
        events: [
          _createMockEvent(
            content: {'msgtype': syncMessageType, 'body': 'test'},
          ),
        ],
      );

      when(() => client.rooms).thenReturn([room]);

      final results = await service.discoverSyncRooms(client);

      expect(results, hasLength(1));
      expect(results.first.hasLottiContent, isTrue);
    });

    test('detects room with base64 encoded sync payload', () async {
      final client = MockClient();
      final syncPayload = {'runtimeType': 'journalEntity', 'id': 'test-id'};
      final base64Payload =
          base64.encode(utf8.encode(json.encode(syncPayload)));

      final room = _createMockRoomWithEvents(
        id: '!base64:server',
        encrypted: true,
        joinRules: JoinRules.invite,
        events: [
          _createMockEvent(
            content: {'msgtype': 'm.text', 'body': base64Payload},
            text: base64Payload,
          ),
        ],
      );

      when(() => client.rooms).thenReturn([room]);

      final results = await service.discoverSyncRooms(client);

      expect(results, hasLength(1));
      expect(results.first.hasLottiContent, isTrue);
    });

    test('does not detect room with non-sync messages', () async {
      final client = MockClient();
      final room = _createMockRoomWithEvents(
        id: '!regular:server',
        encrypted: true,
        joinRules: JoinRules.invite,
        events: [
          _createMockEvent(
            content: {'msgtype': 'm.text', 'body': 'Hello world'},
            text: 'Hello world',
          ),
        ],
      );

      when(() => client.rooms).thenReturn([room]);

      final results = await service.discoverSyncRooms(client);

      expect(results, isEmpty);
    });

    test('handles getTimeline errors gracefully', () async {
      final client = MockClient();
      final room = MockRoom();
      final summary = MockRoomSummary();

      when(() => room.id).thenReturn('!error:server');
      when(() => room.encrypted).thenReturn(true);
      when(() => room.joinRules).thenReturn(JoinRules.invite);
      when(() => room.getState(lottiSyncRoomStateType)).thenReturn(null);
      when(() => room.getTimeline(limit: any(named: 'limit')))
          .thenThrow(Exception('Timeline error'));
      when(() => room.name).thenReturn('Error Room');
      when(() => room.summary).thenReturn(summary);
      when(() => summary.mJoinedMemberCount).thenReturn(1);
      when(() => room.getState('m.room.create')).thenReturn(null);

      when(() => client.rooms).thenReturn([room]);

      final results = await service.discoverSyncRooms(client);

      // Should not crash, just log and skip
      expect(results, isEmpty);
      verify(() => loggingService.captureEvent(
            contains('Error checking room'),
            domain: 'SYNC_ROOM_DISCOVERY',
            subDomain: 'hasLottiSyncContent',
          )).called(1);
    });
  });

  group('room metadata extraction', () {
    test('extracts room name when present', () async {
      final client = MockClient();
      final room = _createMockRoom(
        id: '!named:server',
        name: 'My Sync Room',
        encrypted: true,
        joinRules: JoinRules.invite,
        hasLottiStateMarker: true,
      );

      when(() => client.rooms).thenReturn([room]);

      final results = await service.discoverSyncRooms(client);

      expect(results.first.roomName, 'My Sync Room');
    });

    test('returns null name when room name is empty', () async {
      final client = MockClient();
      final room = _createMockRoom(
        id: '!unnamed:server',
        encrypted: true,
        joinRules: JoinRules.invite,
        hasLottiStateMarker: true,
      );

      when(() => client.rooms).thenReturn([room]);

      final results = await service.discoverSyncRooms(client);

      expect(results.first.roomName, isNull);
    });

    test('extracts member count from summary', () async {
      final client = MockClient();
      final room = _createMockRoom(
        id: '!members:server',
        encrypted: true,
        joinRules: JoinRules.invite,
        hasLottiStateMarker: true,
        memberCount: 5,
      );

      when(() => client.rooms).thenReturn([room]);

      final results = await service.discoverSyncRooms(client);

      expect(results.first.memberCount, 5);
    });

    test('defaults member count to 1 when null', () async {
      final client = MockClient();
      final room = _createMockRoom(
        id: '!nomembers:server',
        encrypted: true,
        joinRules: JoinRules.invite,
        hasLottiStateMarker: true,
        memberCount: null,
      );

      when(() => client.rooms).thenReturn([room]);

      final results = await service.discoverSyncRooms(client);

      expect(results.first.memberCount, 1);
    });

    test('extracts creation time from room create event when Event', () async {
      final client = MockClient();
      final createdAt = DateTime(2025, 6, 15, 10, 30);
      final room = _createMockRoom(
        id: '!created:server',
        encrypted: true,
        joinRules: JoinRules.invite,
        hasLottiStateMarker: true,
        createdAt: createdAt,
      );

      when(() => client.rooms).thenReturn([room]);

      final results = await service.discoverSyncRooms(client);

      expect(results.first.createdAt, createdAt);
    });

    test('returns null createdAt when state is not Event type', () async {
      final client = MockClient();
      final room = _createMockRoom(
        id: '!nocreate:server',
        encrypted: true,
        joinRules: JoinRules.invite,
        hasLottiStateMarker: true,
        useStrippedStateEvent: true,
      );

      when(() => client.rooms).thenReturn([room]);

      final results = await service.discoverSyncRooms(client);

      expect(results.first.createdAt, isNull);
    });

    test('handles missing create event gracefully', () async {
      final client = MockClient();
      final room = _createMockRoom(
        id: '!nocreate:server',
        encrypted: true,
        joinRules: JoinRules.invite,
        hasLottiStateMarker: true,
      );

      when(() => client.rooms).thenReturn([room]);

      final results = await service.discoverSyncRooms(client);

      expect(results.first.createdAt, isNull);
    });
  });
}

/// Creates a mock room with common defaults.
MockRoom _createMockRoom({
  required String id,
  required bool encrypted,
  required JoinRules joinRules,
  String name = '',
  bool hasLottiStateMarker = false,
  bool hasLottiContent = false,
  DateTime? createdAt,
  int? memberCount = 1,
  bool useStrippedStateEvent = false,
}) {
  final room = MockRoom();
  final summary = MockRoomSummary();
  final timeline = MockTimeline();

  when(() => room.id).thenReturn(id);
  when(() => room.name).thenReturn(name);
  when(() => room.encrypted).thenReturn(encrypted);
  when(() => room.joinRules).thenReturn(joinRules);
  when(() => room.summary).thenReturn(summary);
  when(() => summary.mJoinedMemberCount).thenReturn(memberCount);

  // State marker
  if (hasLottiStateMarker) {
    final stateEvent = MockStrippedStateEvent();
    when(() => room.getState(lottiSyncRoomStateType)).thenReturn(stateEvent);
  } else {
    when(() => room.getState(lottiSyncRoomStateType)).thenReturn(null);
  }

  // Creation time
  if (createdAt != null) {
    final createEvent = MockEvent();
    when(() => createEvent.originServerTs).thenReturn(createdAt);
    when(() => room.getState('m.room.create')).thenReturn(createEvent);
  } else if (useStrippedStateEvent) {
    final strippedEvent = MockStrippedStateEvent();
    when(() => room.getState('m.room.create')).thenReturn(strippedEvent);
  } else {
    when(() => room.getState('m.room.create')).thenReturn(null);
  }

  // Timeline with content
  if (hasLottiContent) {
    final syncEvent = _createMockEvent(
      content: {'msgtype': syncMessageType, 'body': 'test'},
    );
    when(() => timeline.events).thenReturn([syncEvent]);
  } else {
    when(() => timeline.events).thenReturn([]);
  }

  when(() => room.getTimeline(limit: any(named: 'limit')))
      .thenAnswer((_) async => timeline);

  return room;
}

/// Creates a mock room with specific events for content detection testing.
MockRoom _createMockRoomWithEvents({
  required String id,
  required bool encrypted,
  required JoinRules joinRules,
  required List<Event> events,
}) {
  final room = MockRoom();
  final summary = MockRoomSummary();
  final timeline = MockTimeline();

  when(() => room.id).thenReturn(id);
  when(() => room.name).thenReturn('');
  when(() => room.encrypted).thenReturn(encrypted);
  when(() => room.joinRules).thenReturn(joinRules);
  when(() => room.summary).thenReturn(summary);
  when(() => summary.mJoinedMemberCount).thenReturn(1);
  when(() => room.getState(lottiSyncRoomStateType)).thenReturn(null);
  when(() => room.getState('m.room.create')).thenReturn(null);
  when(() => timeline.events).thenReturn(events);
  when(() => room.getTimeline(limit: any(named: 'limit')))
      .thenAnswer((_) async => timeline);

  return room;
}

/// Creates a mock event with specified content.
MockEvent _createMockEvent({
  required Map<String, dynamic> content,
  String text = '',
}) {
  final event = MockEvent();
  when(() => event.content).thenReturn(content);
  when(() => event.text).thenReturn(text);
  return event;
}
