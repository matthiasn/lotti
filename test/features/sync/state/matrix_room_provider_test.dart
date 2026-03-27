import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/state/matrix_room_provider.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  late MockMatrixService mockMatrixService;

  setUp(() {
    mockMatrixService = MockMatrixService();
  });

  group('MatrixRoomController', () {
    test('build returns current room from matrix service', () async {
      when(
        () => mockMatrixService.getRoom(),
      ).thenAnswer((_) async => '!room:server');

      final container = ProviderContainer(
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
        ],
      );
      addTearDown(container.dispose);

      final room = await container.read(matrixRoomControllerProvider.future);

      expect(room, '!room:server');
      verify(() => mockMatrixService.getRoom()).called(1);
    });

    test('build returns null when no room is set', () async {
      when(() => mockMatrixService.getRoom()).thenAnswer((_) async => null);

      final container = ProviderContainer(
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
        ],
      );
      addTearDown(container.dispose);

      final room = await container.read(matrixRoomControllerProvider.future);

      expect(room, isNull);
    });

    test('createRoom delegates to matrix service', () async {
      when(() => mockMatrixService.getRoom()).thenAnswer((_) async => null);
      when(
        () => mockMatrixService.createRoom(),
      ).thenAnswer((_) async => '!new:room');

      final container = ProviderContainer(
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
        ],
      );
      addTearDown(container.dispose);

      await container.read(matrixRoomControllerProvider.future);
      final controller = container.read(
        matrixRoomControllerProvider.notifier,
      );

      await controller.createRoom();

      verify(() => mockMatrixService.createRoom()).called(1);
    });

    test('inviteToRoom delegates to matrix service', () async {
      when(
        () => mockMatrixService.getRoom(),
      ).thenAnswer((_) async => '!room:s');
      when(
        () => mockMatrixService.inviteToSyncRoom(userId: any(named: 'userId')),
      ).thenAnswer((_) async {});

      final container = ProviderContainer(
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
        ],
      );
      addTearDown(container.dispose);

      await container.read(matrixRoomControllerProvider.future);
      final controller = container.read(
        matrixRoomControllerProvider.notifier,
      );

      await controller.inviteToRoom('@user:server');

      verify(
        () => mockMatrixService.inviteToSyncRoom(userId: '@user:server'),
      ).called(1);
    });

    test('inviteToRoom deduplicates concurrent invites', () async {
      when(
        () => mockMatrixService.getRoom(),
      ).thenAnswer((_) async => '!room:s');

      // Simulate a slow invite
      when(
        () => mockMatrixService.inviteToSyncRoom(userId: any(named: 'userId')),
      ).thenAnswer(
        (_) async => Future<void>.delayed(const Duration(milliseconds: 50)),
      );

      final container = ProviderContainer(
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
        ],
      );
      addTearDown(container.dispose);

      await container.read(matrixRoomControllerProvider.future);
      final controller = container.read(
        matrixRoomControllerProvider.notifier,
      );

      // Fire two invites concurrently
      final f1 = controller.inviteToRoom('@user:server');
      final f2 = controller.inviteToRoom('@user:server');
      await Future.wait([f1, f2]);

      // Only one should have gone through
      verify(
        () => mockMatrixService.inviteToSyncRoom(userId: '@user:server'),
      ).called(1);
    });

    test('joinRoom saves and joins room', () async {
      when(() => mockMatrixService.getRoom()).thenAnswer((_) async => null);
      when(
        () => mockMatrixService.saveRoom(any()),
      ).thenAnswer((_) async {});
      when(
        () => mockMatrixService.joinRoom(any()),
      ).thenAnswer((_) async => '!room:s');

      final container = ProviderContainer(
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
        ],
      );
      addTearDown(container.dispose);

      await container.read(matrixRoomControllerProvider.future);
      final controller = container.read(
        matrixRoomControllerProvider.notifier,
      );

      await controller.joinRoom('!room:server');

      verify(() => mockMatrixService.saveRoom('!room:server')).called(1);
      verify(() => mockMatrixService.joinRoom('!room:server')).called(1);
    });

    test('leaveRoom delegates to matrix service', () async {
      when(
        () => mockMatrixService.getRoom(),
      ).thenAnswer((_) async => '!room:s');
      when(() => mockMatrixService.leaveRoom()).thenAnswer((_) async {});

      final container = ProviderContainer(
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
        ],
      );
      addTearDown(container.dispose);

      await container.read(matrixRoomControllerProvider.future);
      final controller = container.read(
        matrixRoomControllerProvider.notifier,
      );

      await controller.leaveRoom();

      verify(() => mockMatrixService.leaveRoom()).called(1);
    });
  });
}
