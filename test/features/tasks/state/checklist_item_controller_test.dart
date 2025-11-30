import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/features/checklist/services/correction_capture_service.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/features/tasks/state/checklist_item_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

class MockJournalDb extends Mock implements JournalDb {}

class MockUpdateNotifications extends Mock implements UpdateNotifications {}

class MockChecklistRepository extends Mock implements ChecklistRepository {}

class MockCategoryRepository extends Mock implements CategoryRepository {}

void main() {
  late MockJournalDb mockDb;
  late MockUpdateNotifications mockUpdateNotifications;
  late MockChecklistRepository mockChecklistRepository;
  late MockCategoryRepository mockCategoryRepository;
  late StreamController<Set<String>> updateStreamController;

  final testChecklistItem = ChecklistItem(
    meta: Metadata(
      id: 'item-1',
      createdAt: DateTime(2025),
      updatedAt: DateTime(2025),
      dateFrom: DateTime(2025),
      dateTo: DateTime(2025),
      categoryId: 'category-1',
    ),
    data: const ChecklistItemData(
      title: 'Original Title',
      isChecked: false,
      linkedChecklists: ['checklist-1'],
    ),
  );

  final testCategory = CategoryDefinition(
    id: 'category-1',
    name: 'Test Category',
    createdAt: DateTime(2025),
    updatedAt: DateTime(2025),
    vectorClock: null,
    private: false,
    active: true,
    color: '#FF0000',
  );

  setUpAll(() {
    registerFallbackValue(testCategory);
    registerFallbackValue(testChecklistItem.data);
  });

  setUp(() {
    mockDb = MockJournalDb();
    mockUpdateNotifications = MockUpdateNotifications();
    mockChecklistRepository = MockChecklistRepository();
    mockCategoryRepository = MockCategoryRepository();
    updateStreamController = StreamController<Set<String>>.broadcast();

    // Register getIt dependencies
    if (getIt.isRegistered<JournalDb>()) {
      getIt.unregister<JournalDb>();
    }
    getIt.registerSingleton<JournalDb>(mockDb);

    if (getIt.isRegistered<UpdateNotifications>()) {
      getIt.unregister<UpdateNotifications>();
    }
    getIt.registerSingleton<UpdateNotifications>(mockUpdateNotifications);

    // Setup stubs
    when(() => mockDb.journalEntityById('item-1'))
        .thenAnswer((_) async => testChecklistItem);
    when(() => mockUpdateNotifications.updateStream)
        .thenAnswer((_) => updateStreamController.stream);
    when(() => mockChecklistRepository.updateChecklistItem(
          checklistItemId: any(named: 'checklistItemId'),
          data: any(named: 'data'),
          taskId: any(named: 'taskId'),
        )).thenAnswer((_) async => true);
  });

  tearDown(() async {
    await updateStreamController.close();
    if (getIt.isRegistered<JournalDb>()) {
      getIt.unregister<JournalDb>();
    }
    if (getIt.isRegistered<UpdateNotifications>()) {
      getIt.unregister<UpdateNotifications>();
    }
  });

  group('ChecklistItemController', () {
    group('updateTitle with correction capture', () {
      test('captures correction and notifies on success', () async {
        when(() => mockCategoryRepository.getCategoryById('category-1'))
            .thenAnswer((_) async => testCategory);
        when(() => mockCategoryRepository.updateCategory(any()))
            .thenAnswer((_) async => testCategory);

        final container = ProviderContainer(
          overrides: [
            checklistRepositoryProvider
                .overrideWithValue(mockChecklistRepository),
            categoryRepositoryProvider
                .overrideWithValue(mockCategoryRepository),
          ],
        );
        addTearDown(container.dispose);

        // Set up listener to capture the notification event
        CorrectionCaptureEvent? capturedEvent;
        container.listen<CorrectionCaptureEvent?>(
          correctionCaptureNotifierProvider,
          (previous, next) {
            if (next != null) {
              capturedEvent = next;
            }
          },
          fireImmediately: true,
        );

        // Read the controller to trigger build
        await container.read(
          checklistItemControllerProvider(id: 'item-1', taskId: 'task-1')
              .future,
        );

        final notifier = container.read(
          checklistItemControllerProvider(id: 'item-1', taskId: 'task-1')
              .notifier,
        );

        // Update title - this should trigger correction capture
        notifier.updateTitle('Updated Title');

        // Wait for the async correction capture to complete
        await Future<void>.delayed(const Duration(milliseconds: 150));

        // Verify the checklist item was updated
        verify(
          () => mockChecklistRepository.updateChecklistItem(
            checklistItemId: 'item-1',
            data: any(named: 'data'),
            taskId: 'task-1',
          ),
        ).called(1);

        // Verify correction was captured
        verify(() => mockCategoryRepository.getCategoryById('category-1'))
            .called(1);
        verify(() => mockCategoryRepository.updateCategory(any())).called(1);

        // Check the notification was fired (captured by listener)
        expect(capturedEvent, isNotNull);
        expect(capturedEvent?.before, equals('Original Title'));
        expect(capturedEvent?.after, equals('Updated Title'));
      });

      test('does not notify when capture returns non-success', () async {
        // Make capture return noChange by using identical text
        when(() => mockCategoryRepository.getCategoryById('category-1'))
            .thenAnswer((_) async => testCategory);

        final container = ProviderContainer(
          overrides: [
            checklistRepositoryProvider
                .overrideWithValue(mockChecklistRepository),
            categoryRepositoryProvider
                .overrideWithValue(mockCategoryRepository),
          ],
        );
        addTearDown(container.dispose);

        await container.read(
          checklistItemControllerProvider(id: 'item-1', taskId: 'task-1')
              .future,
        );

        final notifier = container.read(
          checklistItemControllerProvider(id: 'item-1', taskId: 'task-1')
              .notifier,
        );

        // Update with normalized identical text (should be noChange)
        notifier.updateTitle('  Original Title  ');

        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Notification should NOT be fired (noChange result)
        final event = container.read(correctionCaptureNotifierProvider);
        expect(event, isNull);
      });

      test('continues with update even when no categoryId', () async {
        final itemNoCategory = ChecklistItem(
          meta: Metadata(
            id: 'item-no-cat',
            createdAt: DateTime(2025),
            updatedAt: DateTime(2025),
            dateFrom: DateTime(2025),
            dateTo: DateTime(2025),
            // No categoryId
          ),
          data: const ChecklistItemData(
            title: 'Original',
            isChecked: false,
            linkedChecklists: [],
          ),
        );

        when(() => mockDb.journalEntityById('item-no-cat'))
            .thenAnswer((_) async => itemNoCategory);

        final container = ProviderContainer(
          overrides: [
            checklistRepositoryProvider
                .overrideWithValue(mockChecklistRepository),
            categoryRepositoryProvider
                .overrideWithValue(mockCategoryRepository),
          ],
        );
        addTearDown(container.dispose);

        await container.read(
          checklistItemControllerProvider(id: 'item-no-cat', taskId: 'task-1')
              .future,
        );

        final notifier = container.read(
          checklistItemControllerProvider(id: 'item-no-cat', taskId: 'task-1')
              .notifier,
        );

        // Update should work even without category
        notifier.updateTitle('New Title');

        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Update should still happen
        verify(
          () => mockChecklistRepository.updateChecklistItem(
            checklistItemId: 'item-no-cat',
            data: any(named: 'data'),
            taskId: 'task-1',
          ),
        ).called(1);

        // No correction capture attempted (noCategory result)
        verifyNever(() => mockCategoryRepository.getCategoryById(any()));
      });

      test('does nothing when title is null', () async {
        final container = ProviderContainer(
          overrides: [
            checklistRepositoryProvider
                .overrideWithValue(mockChecklistRepository),
            categoryRepositoryProvider
                .overrideWithValue(mockCategoryRepository),
          ],
        );
        addTearDown(container.dispose);

        await container.read(
          checklistItemControllerProvider(id: 'item-1', taskId: 'task-1')
              .future,
        );

        final notifier = container.read(
          checklistItemControllerProvider(id: 'item-1', taskId: 'task-1')
              .notifier,
        );

        notifier.updateTitle(null);

        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Nothing should happen
        verifyNever(
          () => mockChecklistRepository.updateChecklistItem(
            checklistItemId: any(named: 'checklistItemId'),
            data: any(named: 'data'),
            taskId: any(named: 'taskId'),
          ),
        );
      });
    });
  });
}
