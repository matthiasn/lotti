import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/features/sync/state/matrix_room_provider.dart';
import 'package:lotti/features/sync/state/matrix_stats_provider.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:mocktail/mocktail.dart';

class MockMatrixService extends Mock implements MatrixService {}

void main() {
  late MockMatrixService mockMatrixService;

  setUp(() {
    mockMatrixService = MockMatrixService();
  });

  group('MatrixRoomController', () {
    test('build returns current room from matrix service', () async {
      when(() => mockMatrixService.getRoom())
          .thenAnswer((_) async => '!room:server');

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

    test('delegates room actions to matrix service', () async {
      when(() => mockMatrixService.getRoom()).thenAnswer((_) async => null);
      when(() => mockMatrixService.createRoom())
          .thenAnswer((_) async => '!new:room');
      when(
        () => mockMatrixService.inviteToSyncRoom(userId: any(named: 'userId')),
      ).thenAnswer((_) async {});
      when(() => mockMatrixService.saveRoom(any())).thenAnswer((_) async {});
      when(() => mockMatrixService.joinRoom(any()))
          .thenAnswer((_) async => '!joined:room');
      when(() => mockMatrixService.leaveRoom()).thenAnswer((_) async {});

      final container = ProviderContainer(
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
        ],
      );
      addTearDown(container.dispose);

      // Ensure provider is built
      await container.read(matrixRoomControllerProvider.future);
      final controller = container.read(matrixRoomControllerProvider.notifier);

      await controller.createRoom();
      verify(() => mockMatrixService.createRoom()).called(1);

      await controller.inviteToRoom('@user:server');
      verify(
        () => mockMatrixService.inviteToSyncRoom(userId: '@user:server'),
      ).called(1);

      await controller.joinRoom('!room:server');
      verify(() => mockMatrixService.saveRoom('!room:server')).called(1);
      verify(() => mockMatrixService.joinRoom('!room:server')).called(1);

      await controller.leaveRoom();
      verify(() => mockMatrixService.leaveRoom()).called(1);
    });
  });

  group('MatrixStats providers', () {
    late StreamController<MatrixStats> matrixStatsStreamController;

    setUp(() {
      matrixStatsStreamController = StreamController<MatrixStats>.broadcast();
      when(() => mockMatrixService.messageCountsController)
          .thenReturn(matrixStatsStreamController);
    });

    tearDown(() async {
      await matrixStatsStreamController.close();
    });

    test('matrixStatsStream exposes matrix service stream', () {
      fakeAsync((FakeAsync async) {
        final container = ProviderContainer(
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
          ],
        );
        addTearDown(container.dispose);

        final captured = <MatrixStats>[];
        final sub = container.listen(
          matrixStatsStreamProvider,
          (_, next) => next.whenData(captured.add),
        );
        addTearDown(sub.close);
        const stats = MatrixStats(sentCount: 1, messageCounts: {});

        matrixStatsStreamController.add(stats);
        async.flushMicrotasks();
        expect(captured, contains(stats));
      });
    });

    test('MatrixStatsController falls back to current counters', () async {
      const fallbackStats = MatrixStats(
        sentCount: 4,
        messageCounts: {'m.text': 3, 'm.image': 1},
      );

      when(() => mockMatrixService.sentCount)
          .thenReturn(fallbackStats.sentCount);
      when(() => mockMatrixService.messageCounts)
          .thenReturn(fallbackStats.messageCounts);

      final container = ProviderContainer(
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(matrixStatsControllerProvider.future);

      expect(result.sentCount, fallbackStats.sentCount);
      expect(result.messageCounts, fallbackStats.messageCounts);
      verify(() => mockMatrixService.sentCount).called(1);
      verify(() => mockMatrixService.messageCounts).called(1);
    });

    test('MatrixStatsController returns latest stream value when available',
        () async {
      const streamedStats = MatrixStats(
        sentCount: 10,
        messageCounts: {'m.text': 7, 'm.image': 3},
      );

      when(() => mockMatrixService.sentCount).thenReturn(0);
      when(() => mockMatrixService.messageCounts).thenReturn(<String, int>{});

      // Use a StreamController that stays open to avoid disposal issues
      final controller = StreamController<MatrixStats>();

      final container = ProviderContainer(
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
          matrixStatsStreamProvider.overrideWith(
            (ref) => controller.stream,
          ),
        ],
      );
      addTearDown(() {
        controller.close();
        container.dispose();
      });

      // First, subscribe to the stream provider to ensure it's active
      final streamSub = container.listen(
        matrixStatsStreamProvider,
        (_, __) {},
      );
      addTearDown(streamSub.close);

      // Add value and wait for stream to propagate
      controller.add(streamedStats);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      // Now read the controller - the stream value should be available
      final result = await container.read(matrixStatsControllerProvider.future);

      expect(result.sentCount, streamedStats.sentCount);
      expect(result.messageCounts, streamedStats.messageCounts);
    });
  });
}
