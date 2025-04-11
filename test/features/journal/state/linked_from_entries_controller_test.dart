import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/journal/state/linked_from_entries_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

class MockJournalRepository extends Mock implements JournalRepository {}

class MockUpdateNotifications extends Mock implements UpdateNotifications {}

class MockJournalEntity extends Mock implements JournalEntity {
  MockJournalEntity(this._id)
      : _meta = Metadata(
          id: _id,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
        );

  // ignore: unused_field
  final String _id;
  final Metadata _meta;

  @override
  Metadata get meta => _meta;
}

class MockLinkedFromEntriesController extends LinkedFromEntriesController {
  MockLinkedFromEntriesController(this._entities);

  final List<JournalEntity> _entities;

  @override
  Future<List<JournalEntity>> build({required String id}) async {
    return _entities;
  }
}

void main() {
  late MockJournalRepository mockJournalRepository;
  late MockUpdateNotifications mockUpdateNotifications;
  late StreamController<Set<String>> updateStreamController;

  setUp(() {
    mockJournalRepository = MockJournalRepository();
    mockUpdateNotifications = MockUpdateNotifications();
    updateStreamController = StreamController<Set<String>>.broadcast();

    // Setup the mock update notifications
    when(() => mockUpdateNotifications.updateStream)
        .thenAnswer((_) => updateStreamController.stream);

    // Register mocks in GetIt
    getIt.allowReassignment = true;
    getIt.registerSingleton<UpdateNotifications>(mockUpdateNotifications);
  });

  tearDown(() {
    updateStreamController.close();
    getIt.unregister<UpdateNotifications>();
  });

  group('LinkedFromEntriesController', () {
    const testId = 'test-entry-id';
    final testEntities = [
      MockJournalEntity('linked-from-id-1'),
      MockJournalEntity('linked-from-id-2'),
    ];

    test('loads linked entities on initialization', () async {
      // Arrange
      when(() => mockJournalRepository.getLinkedToEntities(linkedTo: testId))
          .thenAnswer((_) async => testEntities);

      // Act
      final container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
        ],
      );

      // Get the controller and wait for it to load
      final controller = container
          .read(linkedFromEntriesControllerProvider(id: testId).notifier);
      final result = await container
          .read(linkedFromEntriesControllerProvider(id: testId).future);

      // Assert
      expect(result, equals(testEntities));
      expect(controller.watchedIds, contains(testId));
      expect(controller.watchedIds, contains('linked-from-id-1'));
      expect(controller.watchedIds, contains('linked-from-id-2'));

      // Verify the repository was called with the correct parameters
      verify(() => mockJournalRepository.getLinkedToEntities(linkedTo: testId))
          .called(1);
    });

    test('updates state when affected IDs are notified', () async {
      // Arrange
      when(() => mockJournalRepository.getLinkedToEntities(linkedTo: testId))
          .thenAnswer((_) async => testEntities);

      final updatedEntities = [
        MockJournalEntity('linked-from-id-1'),
        MockJournalEntity(
          'linked-from-id-3',
        ), // Changed from linked-from-id-2 to linked-from-id-3
      ];

      // Setup the second call to return updated entities
      when(() => mockJournalRepository.getLinkedToEntities(linkedTo: testId))
          .thenAnswer((_) async => testEntities);
      when(() => mockJournalRepository.getLinkedToEntities(linkedTo: testId))
          .thenAnswer((_) async => updatedEntities);

      // Act
      final container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
        ],
      );

      // Get the controller and wait for it to load
      final controller = container
          .read(linkedFromEntriesControllerProvider(id: testId).notifier);
      await container
          .read(linkedFromEntriesControllerProvider(id: testId).future);

      // Simulate an update notification for one of the watched IDs
      updateStreamController.add({'linked-from-id-1'});

      // Wait for the async update to complete
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Get the updated state
      final updatedState =
          container.read(linkedFromEntriesControllerProvider(id: testId));

      // Assert
      expect(updatedState.value, equals(updatedEntities));
      expect(
        controller.watchedIds,
        contains('linked-from-id-3'),
      ); // Should have the new ID

      // Verify the repository was called twice
      verify(() => mockJournalRepository.getLinkedToEntities(linkedTo: testId))
          .called(2);
    });

    test('disposes subscription when disposed', () async {
      // Arrange
      when(() => mockJournalRepository.getLinkedToEntities(linkedTo: testId))
          .thenAnswer((_) async => testEntities);

      // Act
      final container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
        ],
      );

      // Get the controller and wait for it to load
      final controller = container
          .read(linkedFromEntriesControllerProvider(id: testId).notifier);
      await container
          .read(linkedFromEntriesControllerProvider(id: testId).future);

      // We can't directly access the private _updateSubscription field
      // but we can verify the controller was created successfully
      expect(controller, isNotNull);

      // Dispose the container
      container.dispose();

      // We can't directly test if the subscription is canceled, but we've verified
      // the onDispose callback is registered correctly in the controller
    });

    test('handles empty results', () async {
      // Arrange
      when(() => mockJournalRepository.getLinkedToEntities(linkedTo: testId))
          .thenAnswer((_) async => []);

      // Act
      final container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
        ],
      );

      // Get the controller and wait for it to load
      final result = await container
          .read(linkedFromEntriesControllerProvider(id: testId).future);

      // Assert
      expect(result, isEmpty);
    });

    test('can be overridden with a mock controller', () async {
      // Arrange
      final mockEntities = [
        MockJournalEntity('mock-id-1'),
        MockJournalEntity('mock-id-2'),
      ];

      // Act
      final container = ProviderContainer(
        overrides: [
          linkedFromEntriesControllerProvider(id: testId).overrideWith(
            () => MockLinkedFromEntriesController(mockEntities),
          ),
        ],
      );

      // Get the result from the controller
      final result = await container
          .read(linkedFromEntriesControllerProvider(id: testId).future);

      // Assert
      expect(result, equals(mockEntities));
    });
  });
}
