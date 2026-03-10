import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/state/purge_controller.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  late MockJournalDb mockDb;
  late ProviderContainer container;
  late PurgeController controller;

  setUp(() {
    mockDb = MockJournalDb();

    container = ProviderContainer(
      overrides: [
        journalDbProvider.overrideWithValue(mockDb),
        loggingServiceProvider.overrideWithValue(MockLoggingService()),
      ],
    );
    controller = container.read(purgeControllerProvider.notifier);
  });

  tearDown(() => container.dispose());

  group('PurgeController', () {
    test('initial state should be correct', () {
      final state = container.read(purgeControllerProvider);
      expect(state.progress, 0);
      expect(state.isPurging, false);
      expect(state.error, isNull);
    });

    test('purgeDeleted should update state correctly', () async {
      when(() => mockDb.purgeDeleted()).thenAnswer(
        (_) => Stream.fromIterable([0.25, 0.5, 0.75, 1.0]),
      );

      final purgeFuture = controller.purgeDeleted();

      var state = container.read(purgeControllerProvider);
      expect(state.isPurging, true);
      expect(state.progress, 0);

      await purgeFuture;

      state = container.read(purgeControllerProvider);
      expect(state.isPurging, false);
      expect(state.progress, 1.0);
      expect(state.error, isNull);
    });

    test('purgeDeleted should handle errors gracefully', () async {
      const testError = 'Test error';

      when(() => mockDb.purgeDeleted()).thenAnswer(
        (_) => Stream.error(Exception(testError)),
      );

      final purgeFuture = controller.purgeDeleted();

      var state = container.read(purgeControllerProvider);
      expect(state.isPurging, true);
      expect(state.progress, 0);

      await purgeFuture;

      state = container.read(purgeControllerProvider);
      expect(state.isPurging, false);
      expect(state.progress, 0);
      expect(state.error, contains(testError));
    });

    test('purgeDeleted should update progress incrementally', () async {
      when(() => mockDb.purgeDeleted()).thenAnswer(
        (_) => Stream.fromIterable([0.25, 0.5, 0.75, 1.0]),
      );

      final states = <PurgeState>[];
      final sub = container.listen<PurgeState>(
        purgeControllerProvider,
        (previous, next) => states.add(next),
        fireImmediately: true,
      );

      await controller.purgeDeleted();

      expect(states.length, 7);
      expect(states[0].progress, 0);
      expect(states[0].isPurging, false);
      expect(states[1].progress, 0);
      expect(states[1].isPurging, true);
      expect(states[2].progress, 0.25);
      expect(states[3].progress, 0.5);
      expect(states[4].progress, 0.75);
      expect(states[5].progress, 1.0);
      expect(states[5].isPurging, true);
      expect(states[6].progress, 1.0);
      expect(states[6].isPurging, false);

      sub.close();
    });
  });
}
