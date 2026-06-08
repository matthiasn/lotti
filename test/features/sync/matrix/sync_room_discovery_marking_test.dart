import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/sync_room_discovery.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import 'sync_room_discovery_test_helpers.dart';

void main() {
  late MockDomainLogger loggingService;
  late SyncRoomDiscoveryService service;

  setUp(() {
    loggingService = MockDomainLogger();

    when(
      () => loggingService.log(
        any<LogDomain>(),
        any<String>(),
        subDomain: any<String?>(named: 'subDomain'),
      ),
    ).thenReturn(null);
    when(
      () => loggingService.error(
        any<LogDomain>(),
        any<Object>(),
        stackTrace: any<StackTrace>(named: 'stackTrace'),
        subDomain: any<String?>(named: 'subDomain'),
      ),
    ).thenAnswer((_) async {});

    service = SyncRoomDiscoveryService(loggingService: loggingService);
  });

  group('hasExistingSyncRooms', () {
    test('returns false when no sync rooms exist', () async {
      final client = MockMatrixClient();
      when(() => client.rooms).thenReturn([]);

      final result = await service.hasExistingSyncRooms(client);

      expect(result, isFalse);
    });

    test('returns true when sync rooms exist', () async {
      final client = MockMatrixClient();
      final room = createMockRoom(
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
      final client = MockMatrixClient();

      when(() => room.id).thenReturn('!room:server');
      when(() => room.client).thenReturn(client);
      when(
        () => client.setRoomStateWithKey(
          any<String>(),
          any<String>(),
          any<String>(),
          any<Map<String, dynamic>>(),
        ),
      ).thenAnswer((_) async => 'event_id');

      await service.markRoomAsLottiSync(room);

      verify(
        () => client.setRoomStateWithKey(
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
        ),
      ).called(1);

      verify(
        () => loggingService.log(
          LogDomain.sync,
          any<String>(that: contains('Marked room')),
          subDomain: 'markRoom',
        ),
      ).called(1);
    });

    test('logs exception when marking fails', () async {
      final room = MockRoom();
      final client = MockMatrixClient();

      when(() => room.id).thenReturn('!room:server');
      when(() => room.client).thenReturn(client);
      when(
        () => client.setRoomStateWithKey(
          any<String>(),
          any<String>(),
          any<String>(),
          any<Map<String, dynamic>>(),
        ),
      ).thenThrow(Exception('Failed to set state'));

      await service.markRoomAsLottiSync(room);

      verify(
        () => loggingService.error(
          LogDomain.sync,
          any<Object>(),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
          subDomain: 'markRoom',
        ),
      ).called(1);
    });
  });

  group('sync content detection', () {
    test('detects room with syncMessageType msgtype', () async {
      final client = MockMatrixClient();
      final room = createMockRoomWithEvents(
        id: '!msgtype:server',
        encrypted: true,
        joinRules: JoinRules.invite,
        events: [
          createMockEvent(
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
      final client = MockMatrixClient();
      final syncPayload = {'runtimeType': 'journalEntity', 'id': 'test-id'};
      final base64Payload = base64.encode(
        utf8.encode(json.encode(syncPayload)),
      );

      final room = createMockRoomWithEvents(
        id: '!base64:server',
        encrypted: true,
        joinRules: JoinRules.invite,
        events: [
          createMockEvent(
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
      final client = MockMatrixClient();
      final room = createMockRoomWithEvents(
        id: '!regular:server',
        encrypted: true,
        joinRules: JoinRules.invite,
        events: [
          createMockEvent(
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
      final client = MockMatrixClient();
      final room = MockRoom();
      final summary = MockRoomSummary();

      when(() => room.id).thenReturn('!error:server');
      when(() => room.encrypted).thenReturn(true);
      when(() => room.joinRules).thenReturn(JoinRules.invite);
      when(() => room.getState(lottiSyncRoomStateType)).thenReturn(null);
      when(
        () => room.getTimeline(limit: any(named: 'limit')),
      ).thenThrow(Exception('Timeline error'));
      when(() => room.name).thenReturn('Error Room');
      when(() => room.summary).thenReturn(summary);
      when(() => summary.mJoinedMemberCount).thenReturn(1);
      when(() => room.getState('m.room.create')).thenReturn(null);

      when(() => client.rooms).thenReturn([room]);

      final results = await service.discoverSyncRooms(client);

      // Should not crash, just log and skip
      expect(results, isEmpty);
      verify(
        () => loggingService.log(
          LogDomain.sync,
          any<String>(that: contains('Error checking room')),
          subDomain: 'hasLottiSyncContent',
        ),
      ).called(1);
    });
  });

  group('room metadata extraction', () {
    test('extracts room name when present', () async {
      final client = MockMatrixClient();
      final room = createMockRoom(
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
      final client = MockMatrixClient();
      final room = createMockRoom(
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
      final client = MockMatrixClient();
      final room = createMockRoom(
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
      final client = MockMatrixClient();
      final room = createMockRoom(
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
      final client = MockMatrixClient();
      final createdAt = DateTime(2025, 6, 15, 10, 30);
      final room = createMockRoom(
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
      final client = MockMatrixClient();
      final room = createMockRoom(
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
      final client = MockMatrixClient();
      final room = createMockRoom(
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
