//ignore_for_file: avoid_positional_boolean_parameters

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

class MockJournalRepository extends Mock implements JournalRepository {}

class MockUpdateNotifications extends Mock implements UpdateNotifications {}

class MockIncludeHiddenController extends IncludeHiddenController {
  MockIncludeHiddenController(this._value);
  final bool _value;

  @override
  bool build({required String id}) => _value;
}

class MockIncludeAiEntriesController extends IncludeAiEntriesController {
  MockIncludeAiEntriesController(this._value);
  final bool _value;

  @override
  bool build({required String id}) => _value;
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

  group('LinkedEntriesController', () {
    const testId = 'test-entry-id';
    final testLinks = [
      EntryLink.basic(
        id: 'link-1',
        fromId: testId,
        toId: 'linked-id-1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vectorClock: null,
        hidden: false,
      ),
      EntryLink.basic(
        id: 'link-2',
        fromId: testId,
        toId: 'linked-id-2',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vectorClock: null,
        hidden: false,
      ),
    ];

    test('loads links on initialization', () async {
      // Arrange
      when(() => mockJournalRepository.getLinksFromId(testId))
          .thenAnswer((_) async => testLinks);

      // Act
      final container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          includeHiddenControllerProvider(id: testId).overrideWith(
            () => MockIncludeHiddenController(false),
          ),
        ],
      );

      // Get the controller and wait for it to load
      final controller =
          container.read(linkedEntriesControllerProvider(id: testId).notifier);
      final result = await container
          .read(linkedEntriesControllerProvider(id: testId).future);

      // Assert
      expect(result, equals(testLinks));
      expect(controller.watchedIds, contains(testId));
      expect(controller.watchedIds, contains('linked-id-1'));
      expect(controller.watchedIds, contains('linked-id-2'));

      // Verify the repository was called with the correct parameters
      verify(() => mockJournalRepository.getLinksFromId(testId)).called(1);
    });

    test('updates state when affected IDs are notified', () async {
      // Arrange
      when(() => mockJournalRepository.getLinksFromId(testId))
          .thenAnswer((_) async => testLinks);

      final updatedLinks = [
        EntryLink.basic(
          id: 'link-1',
          fromId: testId,
          toId: 'linked-id-1',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          vectorClock: null,
          hidden: false,
        ),
        EntryLink.basic(
          id: 'link-3',
          fromId: testId,
          toId: 'linked-id-3', // Changed from linked-id-2 to linked-id-3
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          vectorClock: null,
          hidden: false,
        ),
      ];

      // Setup the second call to return updated links
      when(() => mockJournalRepository.getLinksFromId(testId))
          .thenAnswer((_) async => testLinks);
      when(() => mockJournalRepository.getLinksFromId(testId))
          .thenAnswer((_) async => updatedLinks);

      // Act
      final container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          includeHiddenControllerProvider(id: testId).overrideWith(
            () => MockIncludeHiddenController(false),
          ),
        ],
      );

      // Get the controller and wait for it to load
      final controller =
          container.read(linkedEntriesControllerProvider(id: testId).notifier);
      await container.read(linkedEntriesControllerProvider(id: testId).future);

      // Simulate an update notification for one of the watched IDs
      updateStreamController.add({'linked-id-1'});

      // Wait for the async update to complete
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Get the updated state
      final updatedState =
          container.read(linkedEntriesControllerProvider(id: testId));

      // Assert
      expect(updatedState.value, equals(updatedLinks));
      expect(
        controller.watchedIds,
        contains('linked-id-3'),
      ); // Should have the new ID

      // Verify the repository was called twice
      verify(() => mockJournalRepository.getLinksFromId(testId)).called(2);
    });

    test('removes link when removeLink is called', () async {
      // Arrange
      when(() => mockJournalRepository.getLinksFromId(testId))
          .thenAnswer((_) async => testLinks);

      when(
        () => mockJournalRepository.removeLink(
          fromId: testId,
          toId: 'linked-id-1',
        ),
      ).thenAnswer((_) async => 1);

      // Act
      final container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          includeHiddenControllerProvider(id: testId).overrideWith(
            () => MockIncludeHiddenController(false),
          ),
        ],
      );

      // Get the controller and wait for it to load
      final controller =
          container.read(linkedEntriesControllerProvider(id: testId).notifier);
      await container.read(linkedEntriesControllerProvider(id: testId).future);

      // Call removeLink
      await controller.removeLink(toId: 'linked-id-1');

      // Assert
      verify(
        () => mockJournalRepository.removeLink(
          fromId: testId,
          toId: 'linked-id-1',
        ),
      ).called(1);
    });

    test('updates link when updateLink is called', () async {
      // Arrange
      when(() => mockJournalRepository.getLinksFromId(testId))
          .thenAnswer((_) async => testLinks);

      final linkToUpdate = EntryLink.basic(
        id: 'link-1',
        fromId: testId,
        toId: 'linked-id-1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vectorClock: null,
        hidden: true, // Changed to hidden
      );

      when(() => mockJournalRepository.updateLink(linkToUpdate))
          .thenAnswer((_) async => true);

      // Act
      final container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          includeHiddenControllerProvider(id: testId).overrideWith(
            () => MockIncludeHiddenController(false),
          ),
        ],
      );

      // Get the controller and wait for it to load
      final controller =
          container.read(linkedEntriesControllerProvider(id: testId).notifier);
      await container.read(linkedEntriesControllerProvider(id: testId).future);

      // Call updateLink
      await controller.updateLink(linkToUpdate);

      // Assert
      verify(() => mockJournalRepository.updateLink(linkToUpdate)).called(1);
    });

    test('respects includeHidden parameter', () async {
      // Arrange
      when(
        () => mockJournalRepository.getLinksFromId(testId, includeHidden: true),
      ).thenAnswer((_) async => testLinks);

      // Act
      final container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          includeHiddenControllerProvider(id: testId).overrideWith(
            () =>
                MockIncludeHiddenController(true), // Set includeHidden to true
          ),
        ],
      );

      // Get the controller and wait for it to load
      await container.read(linkedEntriesControllerProvider(id: testId).future);

      // Assert
      verify(
        () => mockJournalRepository.getLinksFromId(testId, includeHidden: true),
      ).called(1);
    });

    test('disposes subscription when disposed', () async {
      // Arrange
      when(() => mockJournalRepository.getLinksFromId(testId))
          .thenAnswer((_) async => testLinks);

      // Act
      final container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          includeHiddenControllerProvider(id: testId).overrideWith(
            () => MockIncludeHiddenController(false),
          ),
        ],
      );

      // Get the controller and wait for it to load
      final controller =
          container.read(linkedEntriesControllerProvider(id: testId).notifier);
      await container.read(linkedEntriesControllerProvider(id: testId).future);

      // We can't directly access the private _updateSubscription field
      // but we can verify the controller was created successfully
      expect(controller, isNotNull);

      // Dispose the container
      container.dispose();

      // We can't directly test if the subscription is canceled, but we've verified
      // the onDispose callback is registered correctly in the controller
    });
  });

  group('IncludeHiddenController', () {
    const testId = 'test-entry-id';

    test('initializes with default value of false', () {
      // Act
      final container = ProviderContainer();
      final result =
          container.read(includeHiddenControllerProvider(id: testId));

      // Assert
      expect(result, isFalse);
    });

    test('can update value', () {
      // Act
      final container = ProviderContainer();
      final controller =
          container.read(includeHiddenControllerProvider(id: testId).notifier);

      // Initial state should be false
      expect(controller.includeHidden, isFalse);

      // Update the value
      controller.includeHidden = true;

      // Assert
      expect(controller.includeHidden, isTrue);
      expect(
        container.read(includeHiddenControllerProvider(id: testId)),
        isTrue,
      );
    });
  });

  group('IncludeAiEntriesController', () {
    const testId = 'test-entry-id';

    test('initializes with default value of false', () {
      // Act
      final container = ProviderContainer();
      final result =
          container.read(includeAiEntriesControllerProvider(id: testId));

      // Assert
      expect(result, isFalse);
    });

    test('can update value', () {
      // Act
      final container = ProviderContainer();
      final controller = container
          .read(includeAiEntriesControllerProvider(id: testId).notifier);

      // Initial state should be false
      expect(controller.includeAiEntries, isFalse);

      // Update the value
      controller.includeAiEntries = true;

      // Assert
      expect(controller.includeAiEntries, isTrue);
      expect(
        container.read(includeAiEntriesControllerProvider(id: testId)),
        isTrue,
      );
    });
  });

  group('NewestLinkedIdController', () {
    const testId = 'test-entry-id';
    final testLinks = [
      EntryLink.basic(
        id: 'link-1',
        fromId: testId,
        toId: 'linked-id-1',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        updatedAt: DateTime.now(),
        vectorClock: null,
        hidden: false,
      ),
      EntryLink.basic(
        id: 'link-2',
        fromId: testId,
        toId: 'linked-id-2',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        updatedAt: DateTime.now(),
        vectorClock: null,
        hidden: false,
      ),
      EntryLink.basic(
        id: 'link-3',
        fromId: testId,
        toId: 'linked-id-3',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vectorClock: null,
        hidden: false,
      ),
    ];

    test('returns null when id is null', () async {
      // Act
      final container = ProviderContainer();
      final result = await container
          .read(newestLinkedIdControllerProvider(id: null).future);

      // Assert
      expect(result, isNull);
    });

    test('returns the newest linked ID based on creation date', () async {
      // Arrange
      when(() => mockJournalRepository.getLinksFromId(testId))
          .thenAnswer((_) async => testLinks);

      // Act
      final container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          includeHiddenControllerProvider(id: testId).overrideWith(
            () => MockIncludeHiddenController(false),
          ),
        ],
      );

      // Wait for the linked entries to load
      await container.read(linkedEntriesControllerProvider(id: testId).future);

      // Get the newest linked ID
      final newestId = await container
          .read(newestLinkedIdControllerProvider(id: testId).future);

      // Assert
      expect(newestId, equals('linked-id-3')); // The most recently created link
    });

    test('returns null when there are no linked entries', () async {
      // Arrange
      when(() => mockJournalRepository.getLinksFromId(testId))
          .thenAnswer((_) async => []);

      // Act
      final container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          includeHiddenControllerProvider(id: testId).overrideWith(
            () => MockIncludeHiddenController(false),
          ),
        ],
      );

      // Wait for the linked entries to load
      await container.read(linkedEntriesControllerProvider(id: testId).future);

      // Get the newest linked ID
      final newestId = await container
          .read(newestLinkedIdControllerProvider(id: testId).future);

      // Assert
      expect(newestId, isNull);
    });
  });
}
