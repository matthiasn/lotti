import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/matrix/sync_room_discovery.dart';
import 'package:lotti/features/sync/state/room_discovery_provider.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:mocktail/mocktail.dart';

class MockMatrixService extends Mock implements MatrixService {}

void main() {
  late MockMatrixService mockMatrixService;
  late ProviderContainer container;

  setUp(() {
    mockMatrixService = MockMatrixService();
    container = ProviderContainer(
      overrides: [
        matrixServiceProvider.overrideWithValue(mockMatrixService),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('RoomDiscoveryState', () {
    test('RoomDiscoveryInitial is initial state', () {
      const state = RoomDiscoveryInitial();
      expect(state, isA<RoomDiscoveryState>());
    });

    test('RoomDiscoveryLoading represents loading state', () {
      const state = RoomDiscoveryLoading();
      expect(state, isA<RoomDiscoveryState>());
    });

    test('RoomDiscoverySuccess with single room', () {
      const state = RoomDiscoverySuccess([
        SyncRoomCandidate(
          roomId: '!room:server',
          roomName: 'Test Room',
          createdAt: null,
          memberCount: 2,
          hasStateMarker: true,
          hasLottiContent: true,
        ),
      ]);

      expect(state.hasSingleRoom, isTrue);
      expect(state.hasMultipleRooms, isFalse);
      expect(state.isEmpty, isFalse);
    });

    test('RoomDiscoverySuccess with multiple rooms', () {
      const state = RoomDiscoverySuccess([
        SyncRoomCandidate(
          roomId: '!room1:server',
          roomName: 'Room 1',
          createdAt: null,
          memberCount: 2,
          hasStateMarker: true,
          hasLottiContent: true,
        ),
        SyncRoomCandidate(
          roomId: '!room2:server',
          roomName: 'Room 2',
          createdAt: null,
          memberCount: 3,
          hasStateMarker: false,
          hasLottiContent: true,
        ),
      ]);

      expect(state.hasSingleRoom, isFalse);
      expect(state.hasMultipleRooms, isTrue);
      expect(state.isEmpty, isFalse);
    });

    test('RoomDiscoverySuccess with empty list', () {
      const state = RoomDiscoverySuccess([]);

      expect(state.hasSingleRoom, isFalse);
      expect(state.hasMultipleRooms, isFalse);
      expect(state.isEmpty, isTrue);
    });

    test('RoomDiscoveryError contains error', () {
      final error = Exception('Test error');
      final state = RoomDiscoveryError(error);

      expect(state.error, equals(error));
    });
  });

  group('RoomDiscoveryController', () {
    test('initial state is RoomDiscoveryInitial', () {
      final state = container.read(roomDiscoveryControllerProvider);
      expect(state, isA<RoomDiscoveryInitial>());
    });

    test('discoverRooms transitions to loading then success', () async {
      final candidates = [
        const SyncRoomCandidate(
          roomId: '!room:server',
          roomName: 'Test Room',
          createdAt: null,
          memberCount: 2,
          hasStateMarker: true,
          hasLottiContent: true,
        ),
      ];

      when(() => mockMatrixService.discoverExistingSyncRooms())
          .thenAnswer((_) async => candidates);

      final notifier = container.read(roomDiscoveryControllerProvider.notifier);

      // Capture state transitions
      final states = <RoomDiscoveryState>[];
      container.listen(
        roomDiscoveryControllerProvider,
        (_, state) => states.add(state),
        fireImmediately: true,
      );

      await notifier.discoverRooms();

      // Should have transitioned through loading to success
      expect(states.length, greaterThanOrEqualTo(2));
      expect(states.any((s) => s is RoomDiscoveryLoading), isTrue);

      final finalState = container.read(roomDiscoveryControllerProvider);
      expect(finalState, isA<RoomDiscoverySuccess>());
      expect((finalState as RoomDiscoverySuccess).rooms, equals(candidates));
    });

    test('discoverRooms transitions to error on failure', () async {
      final error = Exception('Discovery failed');

      when(() => mockMatrixService.discoverExistingSyncRooms())
          .thenThrow(error);

      final notifier = container.read(roomDiscoveryControllerProvider.notifier);

      await notifier.discoverRooms();

      final state = container.read(roomDiscoveryControllerProvider);
      expect(state, isA<RoomDiscoveryError>());
      expect((state as RoomDiscoveryError).error, equals(error));
    });

    test('joinRoom returns true on success', () async {
      const candidate = SyncRoomCandidate(
        roomId: '!room:server',
        roomName: 'Test Room',
        createdAt: null,
        memberCount: 2,
        hasStateMarker: true,
        hasLottiContent: true,
      );

      when(() => mockMatrixService.joinRoom('!room:server'))
          .thenAnswer((_) async => '!room:server');

      final notifier = container.read(roomDiscoveryControllerProvider.notifier);

      final result = await notifier.joinRoom(candidate);

      expect(result, isTrue);
      verify(() => mockMatrixService.joinRoom('!room:server')).called(1);
    });

    test('joinRoom returns false and sets error on failure', () async {
      const candidate = SyncRoomCandidate(
        roomId: '!room:server',
        roomName: 'Test Room',
        createdAt: null,
        memberCount: 2,
        hasStateMarker: true,
        hasLottiContent: true,
      );

      final error = Exception('Join failed');
      when(() => mockMatrixService.joinRoom('!room:server')).thenThrow(error);

      final notifier = container.read(roomDiscoveryControllerProvider.notifier);

      final result = await notifier.joinRoom(candidate);

      expect(result, isFalse);

      final state = container.read(roomDiscoveryControllerProvider);
      expect(state, isA<RoomDiscoveryError>());
    });

    test('reset returns to initial state', () async {
      final candidates = [
        const SyncRoomCandidate(
          roomId: '!room:server',
          roomName: 'Test Room',
          createdAt: null,
          memberCount: 2,
          hasStateMarker: true,
          hasLottiContent: true,
        ),
      ];

      when(() => mockMatrixService.discoverExistingSyncRooms())
          .thenAnswer((_) async => candidates);

      final notifier = container.read(roomDiscoveryControllerProvider.notifier);

      await notifier.discoverRooms();
      expect(
        container.read(roomDiscoveryControllerProvider),
        isA<RoomDiscoverySuccess>(),
      );

      notifier.reset();

      expect(
        container.read(roomDiscoveryControllerProvider),
        isA<RoomDiscoveryInitial>(),
      );
    });
  });
}
