import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/features/categories/state/category_task_count_provider.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

void main() {
  group('categoryTaskCountProvider', () {
    late MockCategoryRepository mockRepository;
    late MockUpdateNotifications mockNotifications;
    late StreamController<Set<String>> notificationController;

    setUp(() async {
      final mocks = await setUpTestGetIt();
      mockRepository = MockCategoryRepository();
      mockNotifications = mocks.updateNotifications;
      notificationController = StreamController<Set<String>>.broadcast();

      when(
        () => mockNotifications.updateStream,
      ).thenAnswer((_) => notificationController.stream);
    });

    tearDown(() async {
      await notificationController.close();
      await tearDownTestGetIt();
    });

    ProviderContainer createContainer() {
      return ProviderContainer(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );
    }

    test('returns correct count for category from batch query', () async {
      when(
        () => mockRepository.getTaskCountsByCategory(),
      ).thenAnswer((_) async => {'cat-1': 7, 'cat-2': 3});

      final container = createContainer();
      addTearDown(container.dispose);

      final count = await container.read(
        categoryTaskCountProvider('cat-1').future,
      );

      expect(count, 7);
      verify(() => mockRepository.getTaskCountsByCategory()).called(1);
    });

    test('returns zero for category not in batch result', () async {
      when(
        () => mockRepository.getTaskCountsByCategory(),
      ).thenAnswer((_) async => {'cat-1': 5});

      final container = createContainer();
      addTearDown(container.dispose);

      final count = await container.read(
        categoryTaskCountProvider('cat-empty').future,
      );

      expect(count, 0);
    });

    test('shares single batch query across multiple categories', () async {
      when(
        () => mockRepository.getTaskCountsByCategory(),
      ).thenAnswer((_) async => {'cat-a': 2, 'cat-b': 8});

      final container = createContainer();
      addTearDown(container.dispose);

      final countA = await container.read(
        categoryTaskCountProvider('cat-a').future,
      );
      final countB = await container.read(
        categoryTaskCountProvider('cat-b').future,
      );

      expect(countA, 2);
      expect(countB, 8);

      // Batch query should only be called once
      verify(() => mockRepository.getTaskCountsByCategory()).called(1);
    });

    test('invalidates when categories notification fires', () async {
      var callCount = 0;

      when(() => mockRepository.getTaskCountsByCategory()).thenAnswer((
        _,
      ) async {
        callCount++;
        return callCount == 1 ? {'cat-1': 2} : {'cat-1': 10};
      });

      final container = createContainer();
      addTearDown(container.dispose);

      final firstCount = await container.read(
        categoryTaskCountProvider('cat-1').future,
      );
      expect(firstCount, 2);

      // Fire the global categories notification
      notificationController.add({categoriesNotification});

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final secondCount = await container.read(
        categoryTaskCountProvider('cat-1').future,
      );
      expect(secondCount, 10);
    });

    test('invalidates when task notification fires', () async {
      var callCount = 0;

      when(() => mockRepository.getTaskCountsByCategory()).thenAnswer((
        _,
      ) async {
        callCount++;
        return callCount == 1 ? {'cat-1': 3} : {'cat-1': 5};
      });

      final container = createContainer();
      addTearDown(container.dispose);

      final firstCount = await container.read(
        categoryTaskCountProvider('cat-1').future,
      );
      expect(firstCount, 3);

      // Fire a task notification (task created/updated/deleted)
      notificationController.add({taskNotification});

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final secondCount = await container.read(
        categoryTaskCountProvider('cat-1').future,
      );
      expect(secondCount, 5);
    });

    test('ignores unrelated notifications', () async {
      when(
        () => mockRepository.getTaskCountsByCategory(),
      ).thenAnswer((_) async => {'cat-1': 4});

      final container = createContainer();
      addTearDown(container.dispose);

      await container.read(
        categoryTaskCountProvider('cat-1').future,
      );

      // Fire an unrelated notification
      notificationController.add({'some-other-id'});

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      // Should only have been called once (no re-fetch)
      verify(() => mockRepository.getTaskCountsByCategory()).called(1);
    });
  });
}
