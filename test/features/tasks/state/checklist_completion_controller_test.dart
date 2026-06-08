import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/features/tasks/state/checklist_completion_controller.dart';
import 'package:lotti/features/tasks/state/checklist_controller.dart';
import 'package:lotti/features/tasks/state/checklist_item_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

void main() {
  late MockJournalDb mockDb;
  late MockUpdateNotifications mockUpdateNotifications;
  late MockJournalRepository mockJournalRepository;
  late MockPersistenceLogic mockPersistenceLogic;
  late MockDomainLogger mockDomainLogger;
  late StreamController<Set<String>> updateStreamController;

  final testChecklist = Checklist(
    meta: Metadata(
      id: 'checklist-1',
      createdAt: DateTime(2025),
      updatedAt: DateTime(2025),
      dateFrom: DateTime(2025),
      dateTo: DateTime(2025),
    ),
    data: const ChecklistData(
      title: 'Test Checklist',
      linkedChecklistItems: ['item-1', 'item-2'],
      linkedTasks: ['task-1'],
    ),
  );

  final testTask = Task(
    meta: Metadata(
      id: 'task-1',
      createdAt: DateTime(2025),
      updatedAt: DateTime(2025),
      dateFrom: DateTime(2025),
      dateTo: DateTime(2025),
    ),
    data: TaskData(
      title: 'Test Task',
      status: TaskStatus.open(
        id: 'status-1',
        createdAt: DateTime(2025),
        utcOffset: 0,
      ),
      dateFrom: DateTime(2025),
      dateTo: DateTime(2025),
      statusHistory: const [],
      checklistIds: ['checklist-1', 'checklist-2'],
    ),
  );

  setUpAll(registerAllFallbackValues);

  setUp(() async {
    mockDb = MockJournalDb();
    mockUpdateNotifications = MockUpdateNotifications();
    mockJournalRepository = MockJournalRepository();
    mockPersistenceLogic = MockPersistenceLogic();
    mockDomainLogger = MockDomainLogger();
    updateStreamController = StreamController<Set<String>>.broadcast();

    await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..unregister<JournalDb>()
          ..registerSingleton<JournalDb>(mockDb)
          ..unregister<UpdateNotifications>()
          ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
          ..unregister<DomainLogger>()
          ..registerSingleton<DomainLogger>(mockDomainLogger)
          ..registerSingleton<PersistenceLogic>(mockPersistenceLogic);
      },
    );

    // Setup stubs
    when(
      () => mockDb.journalEntityById('checklist-1'),
    ).thenAnswer((_) async => testChecklist);
    when(
      () => mockDb.journalEntityById('task-1'),
    ).thenAnswer((_) async => testTask);
    when(
      () => mockUpdateNotifications.updateStream,
    ).thenAnswer((_) => updateStreamController.stream);
    when(
      () => mockJournalRepository.deleteJournalEntity(any()),
    ).thenAnswer((_) async => true);
    when(
      () => mockPersistenceLogic.updateTask(
        journalEntityId: any(named: 'journalEntityId'),
        taskData: any(named: 'taskData'),
        entryText: any(named: 'entryText'),
      ),
    ).thenAnswer((_) async => true);
  });

  tearDown(() async {
    await updateStreamController.close();
    await tearDownTestGetIt();
  });

  /// Builds a [ChecklistItem] linked to `checklist-comp` for the completion
  /// and completion-rate controller tests.
  ChecklistItem makeCompletionItem({
    required String id,
    required bool isChecked,
    bool isArchived = false,
    bool isDeleted = false,
  }) {
    return ChecklistItem(
      meta: Metadata(
        id: id,
        createdAt: DateTime(2025),
        updatedAt: DateTime(2025),
        dateFrom: DateTime(2025),
        dateTo: DateTime(2025),
        deletedAt: isDeleted ? DateTime(2025) : null,
      ),
      data: ChecklistItemData(
        title: id,
        isChecked: isChecked,
        linkedChecklists: const ['checklist-comp'],
        isArchived: isArchived,
      ),
    );
  }

  /// Builds a [ProviderContainer] with the checklist and all item controllers
  /// warmed up so completion/rate state computations see resolved values.
  Future<ProviderContainer> buildCompletionContainer({
    required Checklist checklist,
    required List<String> itemIds,
  }) async {
    final mockChecklistRepository = MockChecklistRepository();
    when(
      () => mockChecklistRepository.updateChecklist(
        checklistId: any(named: 'checklistId'),
        data: any(named: 'data'),
      ),
    ).thenAnswer((_) async => true);
    when(
      () => mockChecklistRepository.updateChecklistItem(
        checklistItemId: any(named: 'checklistItemId'),
        data: any(named: 'data'),
        taskId: any(named: 'taskId'),
      ),
    ).thenAnswer((_) async => true);

    final container = ProviderContainer(
      overrides: [
        journalRepositoryProvider.overrideWithValue(mockJournalRepository),
        checklistRepositoryProvider.overrideWithValue(mockChecklistRepository),
      ],
    );
    addTearDown(container.dispose);

    // Warm up the checklist controller first so its state is resolved.
    await container.read(
      checklistControllerProvider((
        id: checklist.meta.id,
        taskId: null,
      )).future,
    );

    // Warm up every item controller so the aggregation sees resolved values.
    for (final itemId in itemIds) {
      await container.read(
        checklistItemControllerProvider((
          id: itemId,
          taskId: null,
        )).future,
      );
    }

    return container;
  }

  group('ChecklistCompletionController', () {
    test('computes correct completion counts from checklist items', () async {
      final checklist = Checklist(
        meta: Metadata(
          id: 'checklist-comp',
          createdAt: DateTime(2025),
          updatedAt: DateTime(2025),
          dateFrom: DateTime(2025),
          dateTo: DateTime(2025),
        ),
        data: const ChecklistData(
          title: 'Completion Test',
          linkedChecklistItems: ['item-a', 'item-b', 'item-c'],
          linkedTasks: [],
        ),
      );

      when(
        () => mockDb.journalEntityById('checklist-comp'),
      ).thenAnswer((_) async => checklist);
      when(
        () => mockDb.journalEntityById('item-a'),
      ).thenAnswer(
        (_) async => makeCompletionItem(id: 'item-a', isChecked: true),
      );
      when(
        () => mockDb.journalEntityById('item-b'),
      ).thenAnswer(
        (_) async => makeCompletionItem(id: 'item-b', isChecked: false),
      );
      when(
        () => mockDb.journalEntityById('item-c'),
      ).thenAnswer(
        (_) async => makeCompletionItem(id: 'item-c', isChecked: true),
      );

      final container = await buildCompletionContainer(
        checklist: checklist,
        itemIds: const ['item-a', 'item-b', 'item-c'],
      );

      final result = await container.read(
        checklistCompletionControllerProvider((
          id: 'checklist-comp',
          taskId: null,
        )).future,
      );

      expect(result.totalCount, 3);
      expect(result.completedCount, 2);
    });

    test('excludes archived and deleted items from counts', () async {
      final checklist = Checklist(
        meta: Metadata(
          id: 'checklist-comp',
          createdAt: DateTime(2025),
          updatedAt: DateTime(2025),
          dateFrom: DateTime(2025),
          dateTo: DateTime(2025),
        ),
        data: const ChecklistData(
          title: 'Filter Test',
          linkedChecklistItems: ['item-a', 'item-b', 'item-c'],
          linkedTasks: [],
        ),
      );

      when(
        () => mockDb.journalEntityById('checklist-comp'),
      ).thenAnswer((_) async => checklist);
      when(
        () => mockDb.journalEntityById('item-a'),
      ).thenAnswer(
        (_) async => makeCompletionItem(id: 'item-a', isChecked: true),
      );
      // item-b is archived
      when(
        () => mockDb.journalEntityById('item-b'),
      ).thenAnswer(
        (_) async => makeCompletionItem(
          id: 'item-b',
          isChecked: true,
          isArchived: true,
        ),
      );
      // item-c is deleted
      when(
        () => mockDb.journalEntityById('item-c'),
      ).thenAnswer(
        (_) async => makeCompletionItem(
          id: 'item-c',
          isChecked: true,
          isDeleted: true,
        ),
      );

      final container = await buildCompletionContainer(
        checklist: checklist,
        itemIds: const ['item-a', 'item-b', 'item-c'],
      );

      final result = await container.read(
        checklistCompletionControllerProvider((
          id: 'checklist-comp',
          taskId: null,
        )).future,
      );

      // Only item-a is active and counted
      expect(result.totalCount, 1);
      expect(result.completedCount, 1);
    });

    test('returns zeros when checklist has no items', () async {
      final emptyChecklist = Checklist(
        meta: Metadata(
          id: 'checklist-comp',
          createdAt: DateTime(2025),
          updatedAt: DateTime(2025),
          dateFrom: DateTime(2025),
          dateTo: DateTime(2025),
        ),
        data: const ChecklistData(
          title: 'Empty',
          linkedChecklistItems: [],
          linkedTasks: [],
        ),
      );

      when(
        () => mockDb.journalEntityById('checklist-comp'),
      ).thenAnswer((_) async => emptyChecklist);

      final container = await buildCompletionContainer(
        checklist: emptyChecklist,
        itemIds: const [],
      );

      final result = await container.read(
        checklistCompletionControllerProvider((
          id: 'checklist-comp',
          taskId: null,
        )).future,
      );

      expect(result.totalCount, 0);
      expect(result.completedCount, 0);
    });
  });

  group('ChecklistCompletionRateController', () {
    Checklist makeRateChecklist(List<String> itemIds) => Checklist(
      meta: Metadata(
        id: 'checklist-comp',
        createdAt: DateTime(2025),
        updatedAt: DateTime(2025),
        dateFrom: DateTime(2025),
        dateTo: DateTime(2025),
      ),
      data: ChecklistData(
        title: 'Rate Test',
        linkedChecklistItems: itemIds,
        linkedTasks: const [],
      ),
    );

    /// Warms the completion controller (holding it alive) and then resolves
    /// the rate controller, returning the container with both subscribed.
    Future<ProviderContainer> bootstrapRate({
      required Checklist checklist,
      required List<String> itemIds,
    }) async {
      final container = await buildCompletionContainer(
        checklist: checklist,
        itemIds: itemIds,
      );

      final completionSub = container.listen(
        checklistCompletionControllerProvider((
          id: 'checklist-comp',
          taskId: null,
        )),
        (_, _) {},
      );
      addTearDown(completionSub.close);
      await container.read(
        checklistCompletionControllerProvider((
          id: 'checklist-comp',
          taskId: null,
        )).future,
      );

      final rateSub = container.listen(
        checklistCompletionRateControllerProvider((
          id: 'checklist-comp',
          taskId: null,
        )),
        (_, _) {},
      );
      addTearDown(rateSub.close);
      await container.read(
        checklistCompletionRateControllerProvider((
          id: 'checklist-comp',
          taskId: null,
        )).future,
      );

      return container;
    }

    double? readRate(ProviderContainer container) => container
        .read(
          checklistCompletionRateControllerProvider((
            id: 'checklist-comp',
            taskId: null,
          )),
        )
        .value;

    test('computes rate as completedCount / totalCount', () async {
      final checklist = makeRateChecklist(
        const ['item-a', 'item-b', 'item-c'],
      );
      when(
        () => mockDb.journalEntityById('checklist-comp'),
      ).thenAnswer((_) async => checklist);
      when(() => mockDb.journalEntityById('item-a')).thenAnswer(
        (_) async => makeCompletionItem(id: 'item-a', isChecked: true),
      );
      when(() => mockDb.journalEntityById('item-b')).thenAnswer(
        (_) async => makeCompletionItem(id: 'item-b', isChecked: false),
      );
      when(() => mockDb.journalEntityById('item-c')).thenAnswer(
        (_) async => makeCompletionItem(id: 'item-c', isChecked: true),
      );

      final container = await bootstrapRate(
        checklist: checklist,
        itemIds: const ['item-a', 'item-b', 'item-c'],
      );

      expect(readRate(container), closeTo(2 / 3, 1e-9));
    });

    test('returns 0.0 when the checklist has no active items', () async {
      final checklist = makeRateChecklist(const []);
      when(
        () => mockDb.journalEntityById('checklist-comp'),
      ).thenAnswer((_) async => checklist);

      final container = await bootstrapRate(
        checklist: checklist,
        itemIds: const [],
      );

      // totalCount == 0 must not divide by zero.
      expect(readRate(container), 0.0);
    });

    test('updates reactively when an item is checked', () async {
      final checklist = makeRateChecklist(const ['item-a', 'item-b']);
      when(
        () => mockDb.journalEntityById('checklist-comp'),
      ).thenAnswer((_) async => checklist);
      when(() => mockDb.journalEntityById('item-a')).thenAnswer(
        (_) async => makeCompletionItem(id: 'item-a', isChecked: false),
      );
      when(() => mockDb.journalEntityById('item-b')).thenAnswer(
        (_) async => makeCompletionItem(id: 'item-b', isChecked: false),
      );

      final container = await bootstrapRate(
        checklist: checklist,
        itemIds: const ['item-a', 'item-b'],
      );
      expect(readRate(container), 0.0);

      // item-a gets checked and a DB notification fires.
      when(() => mockDb.journalEntityById('item-a')).thenAnswer(
        (_) async => makeCompletionItem(id: 'item-a', isChecked: true),
      );
      updateStreamController.add({'item-a'});
      await pumpEventQueue();

      expect(readRate(container), closeTo(0.5, 1e-9));
    });
  });

  group('ChecklistCompletionController.aggregateCompletion (pure)', () {
    // Each int 0..7 encodes a 3-bit item state:
    //   bit 0 -> isChecked, bit 1 -> isArchived, bit 2 -> isDeleted.
    ChecklistItem itemFromCode(int code, int index) => ChecklistItem(
      meta: Metadata(
        id: 'item-$index',
        createdAt: DateTime(2025),
        updatedAt: DateTime(2025),
        dateFrom: DateTime(2025),
        dateTo: DateTime(2025),
        deletedAt: (code & 4) != 0 ? DateTime(2025) : null,
      ),
      data: ChecklistItemData(
        title: 'item-$index',
        isChecked: (code & 1) != 0,
        linkedChecklists: const [],
        isArchived: (code & 2) != 0,
      ),
    );

    glados.Glados<List<int>>(
      glados.any.list(glados.IntAnys(glados.any).intInRange(0, 8)),
      glados.ExploreConfig(numRuns: 160),
    ).test('counting/filtering invariants hold for any item mix', (codes) {
      final items = <ChecklistItem>[
        for (var i = 0; i < codes.length; i++) itemFromCode(codes[i], i),
      ];

      final result = ChecklistCompletionController.aggregateCompletion(items);

      // Reference counts computed independently of the implementation.
      final activeCount = codes
          .where((c) => (c & 2) == 0 && (c & 4) == 0)
          .length;
      final activeCheckedCount = codes
          .where((c) => (c & 2) == 0 && (c & 4) == 0 && (c & 1) != 0)
          .length;

      final reason = 'codes=$codes';

      // totalCount counts exactly the active (non-archived, non-deleted) items.
      expect(result.totalCount, activeCount, reason: reason);
      // completedCount counts exactly the active AND checked items.
      expect(result.completedCount, activeCheckedCount, reason: reason);
      // completedCount never exceeds totalCount (rate stays in [0, 1]).
      expect(
        result.completedCount,
        lessThanOrEqualTo(result.totalCount),
        reason: reason,
      );
      expect(result.completedCount, greaterThanOrEqualTo(0), reason: reason);
    }, tags: 'glados');

    glados.Glados<List<int>>(
      glados.any.list(glados.IntAnys(glados.any).intInRange(0, 8)),
      glados.ExploreConfig(numRuns: 120),
    ).test('totalCount is 0 when every item is archived or deleted', (codes) {
      // Force every item to be archived or deleted (set bit 1 and/or bit 2),
      // so none remain active regardless of the checked bit.
      final inactiveCodes = codes
          .map((c) => (c & 1) | (c.isEven ? 2 : 4))
          .toList();
      final items = <ChecklistItem>[
        for (var i = 0; i < inactiveCodes.length; i++)
          itemFromCode(inactiveCodes[i], i),
      ];

      final result = ChecklistCompletionController.aggregateCompletion(items);

      expect(result.totalCount, 0, reason: 'codes=$inactiveCodes');
      expect(result.completedCount, 0, reason: 'codes=$inactiveCodes');
    }, tags: 'glados');
  });
}
