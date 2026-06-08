import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
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
      final client = MockMatrixClient();
      when(() => client.rooms).thenReturn([]);

      final results = await service.discoverSyncRooms(client);

      expect(results, isEmpty);
      verify(
        () => loggingService.log(
          LogDomain.sync,
          any<String>(that: contains('Discovered 0')),
          subDomain: 'discover',
        ),
      ).called(1);
    });

    test('filters out unencrypted rooms', () async {
      final client = MockMatrixClient();
      final room = createMockRoom(
        id: '!unencrypted:server',
        encrypted: false,
        joinRules: JoinRules.invite,
      );

      when(() => client.rooms).thenReturn([room]);

      final results = await service.discoverSyncRooms(client);

      expect(results, isEmpty);
    });

    test('filters out public rooms', () async {
      final client = MockMatrixClient();
      final room = createMockRoom(
        id: '!public:server',
        encrypted: true,
        joinRules: JoinRules.public,
      );

      when(() => client.rooms).thenReturn([room]);

      final results = await service.discoverSyncRooms(client);

      expect(results, isEmpty);
    });

    test('filters out rooms without Lotti markers or content', () async {
      final client = MockMatrixClient();
      final room = createMockRoom(
        id: '!regular:server',
        encrypted: true,
        joinRules: JoinRules.invite,
      );

      when(() => client.rooms).thenReturn([room]);

      final results = await service.discoverSyncRooms(client);

      expect(results, isEmpty);
    });

    glados.Glados(
      glados.any.roomDiscoveryScenario,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'generated room discovery filters candidates and preserves sort order',
      (scenario) async {
        final client = MockMatrixClient();
        final casesByRoomId = <String, GeneratedRoomDiscoveryCase>{};
        final rooms = <Room>[];

        for (var i = 0; i < scenario.rooms.length; i++) {
          final roomCase = scenario.rooms[i];
          final roomId = scenario.roomIdAt(i);
          casesByRoomId[roomId] = roomCase;
          rooms.add(
            createMockRoom(
              id: roomId,
              name: roomCase.nameAt(i),
              encrypted: roomCase.encrypted,
              joinRules: roomCase.joinRules,
              hasLottiStateMarker: roomCase.hasStateMarker,
              hasLottiContent: roomCase.hasLottiContent,
              createdAt: roomCase.createdAtAt(i),
              memberCount: roomCase.memberCount,
            ),
          );
        }
        when(() => client.rooms).thenReturn(rooms);

        final results = await service.discoverSyncRooms(client);

        expect(
          results.map((candidate) => candidate.roomId).toSet(),
          scenario.expectedRoomIds,
          reason: '$scenario',
        );
        for (final candidate in results) {
          final roomCase = casesByRoomId[candidate.roomId]!;
          expect(candidate.confidence, roomCase.confidence);
          expect(candidate.hasStateMarker, roomCase.hasStateMarker);
          expect(candidate.hasLottiContent, roomCase.hasLottiContent);
          expect(candidate.memberCount, roomCase.expectedMemberCount);
          expect(
            candidate.roomName,
            roomCase.hasName ? startsWith('Generated room') : isNull,
          );
        }
        for (var i = 1; i < results.length; i++) {
          final previous = results[i - 1];
          final current = results[i];
          expect(
            previous.confidence,
            greaterThanOrEqualTo(current.confidence),
            reason: '$scenario',
          );
          if (previous.confidence == current.confidence) {
            final previousCreated = previous.createdAt;
            final currentCreated = current.createdAt;
            if (previousCreated == null) {
              expect(currentCreated, isNull, reason: '$scenario');
            } else if (currentCreated != null) {
              expect(
                previousCreated.isBefore(currentCreated),
                isFalse,
                reason: '$scenario',
              );
            }
          }
        }
      },
      tags: 'glados',
    );

    test('includes rooms with Lotti state marker', () async {
      final client = MockMatrixClient();
      final room = createMockRoom(
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
      final client = MockMatrixClient();
      final room = createMockRoom(
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
      final client = MockMatrixClient();
      final roomBoth = createMockRoom(
        id: '!both:server',
        name: 'Both Markers',
        encrypted: true,
        joinRules: JoinRules.invite,
        hasLottiStateMarker: true,
        hasLottiContent: true,
      );
      final roomStateOnly = createMockRoom(
        id: '!state:server',
        name: 'State Only',
        encrypted: true,
        joinRules: JoinRules.invite,
        hasLottiStateMarker: true,
      );
      final roomContentOnly = createMockRoom(
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
      final client = MockMatrixClient();
      final olderRoom = createMockRoom(
        id: '!older:server',
        name: 'Older Room',
        encrypted: true,
        joinRules: JoinRules.invite,
        hasLottiStateMarker: true,
        createdAt: DateTime(2024),
      );
      final newerRoom = createMockRoom(
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
      final client = MockMatrixClient();
      final roomWithDate = createMockRoom(
        id: '!dated:server',
        encrypted: true,
        joinRules: JoinRules.invite,
        hasLottiStateMarker: true,
        createdAt: DateTime(2025),
      );
      final roomNoDate = createMockRoom(
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
}
