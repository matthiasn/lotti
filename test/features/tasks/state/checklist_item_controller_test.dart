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

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

typedef ItemChange = ChecklistItemData Function(ChecklistItemData stored);

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

  /// The items as the database holds them, keyed by id — what the
  /// `updateChecklistItem` stub applies each change to.
  late Map<String, ChecklistItem> storedItems;

  setUpAll(() {
    registerAllFallbackValues();
    // The change `ChecklistRepository.updateChecklistItem` applies to the
    // stored item data.
    registerFallbackValue((ChecklistItemData stored) => stored);
  });

  setUp(() async {
    mockDb = MockJournalDb();
    mockUpdateNotifications = MockUpdateNotifications();
    mockChecklistRepository = MockChecklistRepository();
    mockCategoryRepository = MockCategoryRepository();
    updateStreamController = StreamController<Set<String>>.broadcast();

    await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..unregister<JournalDb>()
          ..registerSingleton<JournalDb>(mockDb)
          ..unregister<UpdateNotifications>()
          ..registerSingleton<UpdateNotifications>(mockUpdateNotifications);
      },
    );

    // Setup stubs
    when(
      () => mockDb.journalEntityById('item-1'),
    ).thenAnswer((_) async => testChecklistItem);
    when(
      () => mockUpdateNotifications.updateStream,
    ).thenAnswer((_) => updateStreamController.stream);
    storedItems = {};
    // Serves `updateChecklistItem` as the repository does: the change is
    // applied to the item as stored and the written item returned.
    when(
      () => mockChecklistRepository.updateChecklistItem(
        checklistItemId: any(named: 'checklistItemId'),
        change: any(named: 'change'),
        taskId: any(named: 'taskId'),
      ),
    ).thenAnswer((invocation) async {
      final id = invocation.namedArguments[#checklistItemId] as String;
      final change = invocation.namedArguments[#change] as ItemChange;
      final current = storedItems[id];
      if (current == null) return null;
      return storedItems[id] = current.copyWith(data: change(current.data));
    });
  });

  tearDown(() async {
    await updateStreamController.close();
    await tearDownTestGetIt();
  });

  group('ChecklistItemController', () {
    group('updateTitle with correction capture', () {
      test('captures correction and notifies on success', () async {
        when(
          () => mockCategoryRepository.getCategoryById('category-1'),
        ).thenAnswer((_) async => testCategory);
        when(
          () => mockCategoryRepository.updateCategory(any()),
        ).thenAnswer((_) async => testCategory);

        final container = ProviderContainer(
          overrides: [
            checklistRepositoryProvider.overrideWithValue(
              mockChecklistRepository,
            ),
            categoryRepositoryProvider.overrideWithValue(
              mockCategoryRepository,
            ),
          ],
        );
        addTearDown(container.dispose);

        // Set up listener to capture the pending correction
        PendingCorrection? capturedPending;
        container.listen<PendingCorrection?>(
          correctionCaptureProvider,
          (previous, next) {
            if (next != null) {
              capturedPending = next;
            }
          },
          fireImmediately: true,
        );

        // Wait for the async build to complete before calling methods
        await container.read(
          checklistItemControllerProvider((
            id: 'item-1',
            taskId: 'task-1',
          )).future,
        );

        final notifier = container.read(
          checklistItemControllerProvider((
            id: 'item-1',
            taskId: 'task-1',
          )).notifier,
        );

        // Update title - this should trigger correction capture
        // ignore: cascade_invocations
        notifier.updateTitle('Updated Title');

        // Wait for the async correction capture to complete
        await pumpEventQueue();

        // Verify the checklist item was updated
        verify(
          () => mockChecklistRepository.updateChecklistItem(
            checklistItemId: 'item-1',
            change: any(named: 'change'),
            taskId: 'task-1',
          ),
        ).called(1);

        // Verify correction capture called getCategoryById for validation
        verify(
          () => mockCategoryRepository.getCategoryById('category-1'),
        ).called(1);

        // Note: updateCategory is NOT called immediately - it's delayed
        // The pending correction should be set instead
        verifyNever(() => mockCategoryRepository.updateCategory(any()));

        // Check the pending correction was set
        expect(capturedPending, isNotNull);
        expect(capturedPending?.before, equals('Original Title'));
        expect(capturedPending?.after, equals('Updated Title'));
      });

      test('does not notify when capture returns non-success', () async {
        // Make capture return noChange by using identical text
        when(
          () => mockCategoryRepository.getCategoryById('category-1'),
        ).thenAnswer((_) async => testCategory);

        final container = ProviderContainer(
          overrides: [
            checklistRepositoryProvider.overrideWithValue(
              mockChecklistRepository,
            ),
            categoryRepositoryProvider.overrideWithValue(
              mockCategoryRepository,
            ),
          ],
        );
        addTearDown(container.dispose);

        // Wait for the async build to complete before calling methods
        await container.read(
          checklistItemControllerProvider((
            id: 'item-1',
            taskId: 'task-1',
          )).future,
        );

        final notifier = container.read(
          checklistItemControllerProvider((
            id: 'item-1',
            taskId: 'task-1',
          )).notifier,
        );

        // Update with normalized identical text (should be noChange)
        // ignore: cascade_invocations
        notifier.updateTitle('  Original Title  ');

        await pumpEventQueue();

        // Notification should NOT be fired (noChange result)
        final event = container.read(correctionCaptureProvider);
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

        when(
          () => mockDb.journalEntityById('item-no-cat'),
        ).thenAnswer((_) async => itemNoCategory);

        final container = ProviderContainer(
          overrides: [
            checklistRepositoryProvider.overrideWithValue(
              mockChecklistRepository,
            ),
            categoryRepositoryProvider.overrideWithValue(
              mockCategoryRepository,
            ),
          ],
        );
        addTearDown(container.dispose);

        // Wait for the async build to complete before calling methods
        await container.read(
          checklistItemControllerProvider((
            id: 'item-no-cat',
            taskId: 'task-1',
          )).future,
        );

        final notifier = container.read(
          checklistItemControllerProvider((
            id: 'item-no-cat',
            taskId: 'task-1',
          )).notifier,
        );

        // Update should work even without category
        // ignore: cascade_invocations
        notifier.updateTitle('New Title');

        await pumpEventQueue();

        // Update should still happen
        verify(
          () => mockChecklistRepository.updateChecklistItem(
            checklistItemId: 'item-no-cat',
            change: any(named: 'change'),
            taskId: 'task-1',
          ),
        ).called(1);

        // No correction capture attempted (noCategory result)
        verifyNever(() => mockCategoryRepository.getCategoryById(any()));
      });

      test('does nothing when title is null', () async {
        final container = ProviderContainer(
          overrides: [
            checklistRepositoryProvider.overrideWithValue(
              mockChecklistRepository,
            ),
            categoryRepositoryProvider.overrideWithValue(
              mockCategoryRepository,
            ),
          ],
        );
        addTearDown(container.dispose);

        // Wait for the async build to complete before calling methods
        await container.read(
          checklistItemControllerProvider((
            id: 'item-1',
            taskId: 'task-1',
          )).future,
        );

        final notifier = container.read(
          checklistItemControllerProvider((
            id: 'item-1',
            taskId: 'task-1',
          )).notifier,
        );

        // ignore: cascade_invocations
        notifier.updateTitle(null);

        await pumpEventQueue();

        // Nothing should happen
        verifyNever(
          () => mockChecklistRepository.updateChecklistItem(
            checklistItemId: any(named: 'checklistItemId'),
            change: any(named: 'change'),
            taskId: any(named: 'taskId'),
          ),
        );
      });
    });

    group('updateChecked provenance', () {
      final fixedTime = DateTime(2026, 2, 28, 22, 30);

      test('stamps checkedBy: user and checkedAt on check', () async {
        final container = ProviderContainer(
          overrides: [
            checklistRepositoryProvider.overrideWithValue(
              mockChecklistRepository,
            ),
            clockProvider.overrideWithValue(() => fixedTime),
          ],
        );
        addTearDown(container.dispose);

        await container.read(
          checklistItemControllerProvider((
            id: 'item-1',
            taskId: 'task-1',
          )).future,
        );

        final notifier = container.read(
          checklistItemControllerProvider((
            id: 'item-1',
            taskId: 'task-1',
          )).notifier,
        );

        // ignore: cascade_invocations
        notifier.updateChecked(checked: true);

        final updatedState = container.read(
          checklistItemControllerProvider((id: 'item-1', taskId: 'task-1')),
        );
        expect(updatedState.value?.data.isChecked, isTrue);
        expect(
          updatedState.value?.data.checkedBy,
          ChangeSource.user,
        );
        expect(updatedState.value?.data.checkedAt, fixedTime);

        verify(
          () => mockChecklistRepository.updateChecklistItem(
            checklistItemId: 'item-1',
            change: any(named: 'change'),
            taskId: 'task-1',
          ),
        ).called(1);
      });

      test('stamps checkedBy: user and checkedAt on uncheck', () async {
        // Create an item that is already checked
        final checkedItem = ChecklistItem(
          meta: Metadata(
            id: 'item-checked',
            createdAt: DateTime(2025),
            updatedAt: DateTime(2025),
            dateFrom: DateTime(2025),
            dateTo: DateTime(2025),
            categoryId: 'category-1',
          ),
          data: const ChecklistItemData(
            title: 'Checked Item',
            isChecked: true,
            linkedChecklists: ['checklist-1'],
            checkedBy: ChangeSource.agent,
          ),
        );

        when(
          () => mockDb.journalEntityById('item-checked'),
        ).thenAnswer((_) async => checkedItem);

        final container = ProviderContainer(
          overrides: [
            checklistRepositoryProvider.overrideWithValue(
              mockChecklistRepository,
            ),
            clockProvider.overrideWithValue(() => fixedTime),
          ],
        );
        addTearDown(container.dispose);

        await container.read(
          checklistItemControllerProvider((
            id: 'item-checked',
            taskId: 'task-1',
          )).future,
        );

        final notifier = container.read(
          checklistItemControllerProvider((
            id: 'item-checked',
            taskId: 'task-1',
          )).notifier,
        );

        // ignore: cascade_invocations
        notifier.updateChecked(checked: false);

        final updatedState = container.read(
          checklistItemControllerProvider((
            id: 'item-checked',
            taskId: 'task-1',
          )),
        );
        expect(updatedState.value?.data.isChecked, isFalse);
        // Provenance flips from agent to user
        expect(
          updatedState.value?.data.checkedBy,
          ChangeSource.user,
        );
        expect(updatedState.value?.data.checkedAt, fixedTime);
      });
    });

    group('archive and unarchive', () {
      test(
        'archive sets isArchived to true and keeps isChecked unchanged',
        () async {
          final container = ProviderContainer(
            overrides: [
              checklistRepositoryProvider.overrideWithValue(
                mockChecklistRepository,
              ),
            ],
          );
          addTearDown(container.dispose);

          await container.read(
            checklistItemControllerProvider((
              id: 'item-1',
              taskId: 'task-1',
            )).future,
          );

          final notifier = container.read(
            checklistItemControllerProvider((
              id: 'item-1',
              taskId: 'task-1',
            )).notifier,
          );

          // ignore: cascade_invocations
          notifier.archive();

          // Verify the state was updated with isArchived = true
          final updatedState = container.read(
            checklistItemControllerProvider((id: 'item-1', taskId: 'task-1')),
          );
          expect(updatedState.value?.data.isArchived, isTrue);
          expect(updatedState.value?.data.isChecked, isFalse);

          // Verify the repository was called
          verify(
            () => mockChecklistRepository.updateChecklistItem(
              checklistItemId: 'item-1',
              change: any(named: 'change'),
              taskId: 'task-1',
            ),
          ).called(1);
        },
      );

      test('unarchive sets isArchived to false', () async {
        // Create an item that's already archived
        final archivedItem = ChecklistItem(
          meta: Metadata(
            id: 'item-archived',
            createdAt: DateTime(2025),
            updatedAt: DateTime(2025),
            dateFrom: DateTime(2025),
            dateTo: DateTime(2025),
          ),
          data: const ChecklistItemData(
            title: 'Archived Item',
            isChecked: false,
            isArchived: true,
            linkedChecklists: ['checklist-1'],
          ),
        );

        when(
          () => mockDb.journalEntityById('item-archived'),
        ).thenAnswer((_) async => archivedItem);

        final container = ProviderContainer(
          overrides: [
            checklistRepositoryProvider.overrideWithValue(
              mockChecklistRepository,
            ),
          ],
        );
        addTearDown(container.dispose);

        await container.read(
          checklistItemControllerProvider((
            id: 'item-archived',
            taskId: 'task-1',
          )).future,
        );

        final notifier = container.read(
          checklistItemControllerProvider((
            id: 'item-archived',
            taskId: 'task-1',
          )).notifier,
        );

        // ignore: cascade_invocations
        notifier.unarchive();

        final updatedState = container.read(
          checklistItemControllerProvider((
            id: 'item-archived',
            taskId: 'task-1',
          )),
        );
        expect(updatedState.value?.data.isArchived, isFalse);
      });

      test('archive preserves checked state when item is checked', () async {
        final checkedItem = ChecklistItem(
          meta: Metadata(
            id: 'item-checked',
            createdAt: DateTime(2025),
            updatedAt: DateTime(2025),
            dateFrom: DateTime(2025),
            dateTo: DateTime(2025),
          ),
          data: const ChecklistItemData(
            title: 'Checked Item',
            isChecked: true,
            linkedChecklists: ['checklist-1'],
          ),
        );

        when(
          () => mockDb.journalEntityById('item-checked'),
        ).thenAnswer((_) async => checkedItem);

        final container = ProviderContainer(
          overrides: [
            checklistRepositoryProvider.overrideWithValue(
              mockChecklistRepository,
            ),
          ],
        );
        addTearDown(container.dispose);

        await container.read(
          checklistItemControllerProvider((
            id: 'item-checked',
            taskId: 'task-1',
          )).future,
        );

        final notifier = container.read(
          checklistItemControllerProvider((
            id: 'item-checked',
            taskId: 'task-1',
          )).notifier,
        );

        // ignore: cascade_invocations
        notifier.archive();

        final updatedState = container.read(
          checklistItemControllerProvider((
            id: 'item-checked',
            taskId: 'task-1',
          )),
        );
        // Both isArchived and isChecked should be true
        expect(updatedState.value?.data.isArchived, isTrue);
        expect(updatedState.value?.data.isChecked, isTrue);
      });
    });

    group('_listen — update stream notification', () {
      test(
        'refreshes state when update stream emits the matching id',
        () async {
          final updatedItem = ChecklistItem(
            meta: Metadata(
              id: 'item-1',
              createdAt: DateTime(2025),
              updatedAt: DateTime(2025, 1, 2),
              dateFrom: DateTime(2025),
              dateTo: DateTime(2025),
              categoryId: 'category-1',
            ),
            data: const ChecklistItemData(
              title: 'Refreshed Title',
              isChecked: true,
              linkedChecklists: ['checklist-1'],
            ),
          );

          // First call returns original; second call (after notification) returns updatedItem
          var fetchCount = 0;
          when(() => mockDb.journalEntityById('item-1')).thenAnswer((_) async {
            fetchCount++;
            return fetchCount == 1 ? testChecklistItem : updatedItem;
          });

          final container = ProviderContainer(
            overrides: [
              checklistRepositoryProvider.overrideWithValue(
                mockChecklistRepository,
              ),
            ],
          );
          addTearDown(container.dispose);

          // Build the provider and let the initial fetch complete.
          await container.read(
            checklistItemControllerProvider((
              id: 'item-1',
              taskId: 'task-1',
            )).future,
          );

          // Verify the initial state is the original item.
          final initialState = container.read(
            checklistItemControllerProvider((id: 'item-1', taskId: 'task-1')),
          );
          expect(initialState.value?.data.title, 'Original Title');
          expect(initialState.value?.data.isChecked, isFalse);

          // Emit an update notification that includes the item's id.
          updateStreamController.add({'item-1', 'other-id'});

          // Let the async callback run.
          await pumpEventQueue();

          // State should now reflect the updated item fetched after notification.
          final refreshedState = container.read(
            checklistItemControllerProvider((id: 'item-1', taskId: 'task-1')),
          );
          expect(refreshedState.value?.data.title, 'Refreshed Title');
          expect(refreshedState.value?.data.isChecked, isTrue);
        },
      );

      test(
        'ignores update stream emission when id is not in the affected set',
        () async {
          // Track extra fetch calls triggered by the stream.
          var extraFetches = 0;
          when(() => mockDb.journalEntityById('item-1')).thenAnswer((_) async {
            extraFetches++;
            return testChecklistItem;
          });

          final container = ProviderContainer(
            overrides: [
              checklistRepositoryProvider.overrideWithValue(
                mockChecklistRepository,
              ),
            ],
          );
          addTearDown(container.dispose);

          await container.read(
            checklistItemControllerProvider((
              id: 'item-1',
              taskId: 'task-1',
            )).future,
          );

          // Reset the counter after initial build fetch(es).
          extraFetches = 0;

          // Emit a notification for a *different* id — should be ignored.
          updateStreamController.add({'other-id', 'yet-another-id'});
          await pumpEventQueue();

          // The controller must not have re-fetched after an irrelevant notification.
          expect(extraFetches, 0);

          // State must remain the original item (no spurious refresh).
          final stateAfterIrrelevant = container.read(
            checklistItemControllerProvider((id: 'item-1', taskId: 'task-1')),
          );
          expect(stateAfterIrrelevant.value?.data.title, 'Original Title');
        },
      );
    });

    group('writes onto the item as stored', () {
      final fixedTime = DateTime(2026, 3, 1, 9, 15);
      const params = (id: 'item-1', taskId: 'task-1');

      /// The item as stored after this controller loaded it: moved to
      /// another checklist and renamed elsewhere — nothing the controller's
      /// state knows about.
      final movedMeanwhile = testChecklistItem.copyWith(
        data: testChecklistItem.data.copyWith(
          title: 'Renamed elsewhere',
          linkedChecklists: const ['checklist-2'],
        ),
      );

      Future<(ProviderContainer, ChecklistItemController)> load() async {
        final container = ProviderContainer(
          overrides: [
            checklistRepositoryProvider.overrideWithValue(
              mockChecklistRepository,
            ),
            clockProvider.overrideWithValue(() => fixedTime),
            categoryRepositoryProvider.overrideWithValue(
              mockCategoryRepository,
            ),
          ],
        );
        addTearDown(container.dispose);
        await container.read(checklistItemControllerProvider(params).future);
        return (
          container,
          container.read(checklistItemControllerProvider(params).notifier),
        );
      }

      /// The change the controller sent for the item.
      ItemChange capturedChange() =>
          verify(
                () => mockChecklistRepository.updateChecklistItem(
                  checklistItemId: 'item-1',
                  change: captureAny(named: 'change'),
                  taskId: 'task-1',
                ),
              ).captured.single
              as ItemChange;

      ChecklistItem? stateOf(ProviderContainer container) =>
          container.read(checklistItemControllerProvider(params)).value;

      setUp(() {
        when(
          () => mockCategoryRepository.getCategoryById(any()),
        ).thenAnswer((_) async => null);
      });

      test(
        'a check from stale state keeps the stored back-link and title',
        () async {
          final (container, notifier) = await load();
          storedItems['item-1'] = movedMeanwhile;

          notifier.updateChecked(checked: true);
          await pumpEventQueue();

          final written = capturedChange()(movedMeanwhile.data);
          expect(written.linkedChecklists, ['checklist-2']);
          expect(written.title, 'Renamed elsewhere');
          expect(written.isChecked, isTrue);
          expect(written.checkedBy, ChangeSource.user);
          expect(written.checkedAt, fixedTime);
          // What was stored is published, not the stale optimistic state.
          expect(stateOf(container)?.data, written);
        },
      );

      test('a rename keeps the stored back-link and checked state', () async {
        final (container, notifier) = await load();
        final checkedAndMoved = movedMeanwhile.copyWith(
          data: movedMeanwhile.data.copyWith(isChecked: true),
        );
        storedItems['item-1'] = checkedAndMoved;

        notifier.updateTitle('My title');
        await pumpEventQueue();

        final written = capturedChange()(checkedAndMoved.data);
        expect(written.title, 'My title');
        expect(written.linkedChecklists, ['checklist-2']);
        expect(written.isChecked, isTrue);
        expect(stateOf(container)?.data, written);
      });

      test('archive and unarchive change only isArchived', () async {
        final (container, notifier) = await load();
        storedItems['item-1'] = movedMeanwhile;

        notifier.archive();
        await pumpEventQueue();

        final archived = capturedChange()(movedMeanwhile.data);
        expect(
          archived,
          movedMeanwhile.data.copyWith(isArchived: true),
        );
        expect(stateOf(container)?.data, archived);

        notifier.unarchive();
        await pumpEventQueue();

        final restored = capturedChange()(archived);
        expect(restored, movedMeanwhile.data.copyWith(isArchived: false));
        expect(stateOf(container)?.data, restored);
      });

      test(
        'publishes the change at once, then the item the write returns',
        () async {
          final write = Completer<ChecklistItem?>();
          when(
            () => mockChecklistRepository.updateChecklistItem(
              checklistItemId: any(named: 'checklistItemId'),
              change: any(named: 'change'),
              taskId: any(named: 'taskId'),
            ),
          ).thenAnswer((_) => write.future);
          final (container, notifier) = await load();

          notifier.updateChecked(checked: true);

          // Optimistic: the change applied to the state, before the write.
          expect(stateOf(container)?.data.isChecked, isTrue);
          expect(stateOf(container)?.data.linkedChecklists, ['checklist-1']);

          write.complete(
            movedMeanwhile.copyWith(
              data: movedMeanwhile.data.copyWith(isChecked: true),
            ),
          );
          await pumpEventQueue();

          expect(stateOf(container)?.data.isChecked, isTrue);
          expect(stateOf(container)?.data.linkedChecklists, ['checklist-2']);
        },
      );

      test(
        'keeps the optimistic state when the write stores nothing',
        () async {
          final (container, notifier) = await load();
          // Nothing stored: the stub returns null, as a refused write does.

          notifier.archive();
          await pumpEventQueue();

          expect(stateOf(container)?.data.isArchived, isTrue);
          expect(stateOf(container)?.data.linkedChecklists, ['checklist-1']);
        },
      );
    });
  });
}
