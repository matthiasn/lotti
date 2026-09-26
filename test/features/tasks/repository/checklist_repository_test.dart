import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/journal_db/config_flags.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/features/tasks/model/membership_list.dart';
import 'package:lotti/features/tasks/repository/checklist_membership_intents.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/logic/services/geolocation_service.dart';
import 'package:lotti/logic/services/metadata_service.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider/path_provider.dart';

import '../../../helpers/fallbacks.dart';
import '../../../helpers/path_provider.dart';
import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../../widget_test_utils.dart';
import '../../agents/test_utils.dart' show makeTestChecklistApproval;

part 'checklist_membership_model_conformance.dart';

void main() {
  final testDate = DateTime(2024, 3, 15, 10, 30);

  late ChecklistRepository repository;
  late MockJournalDb mockJournalDb;
  late MockPersistenceLogic mockPersistenceLogic;
  late MockDomainLogger mockDomainLogger;
  late MockSettingsDb mockSettingsDb;
  late ProviderContainer container;

  // The membership intents in the mocked settings table, by key, and what
  // happened in order: `record <op>` / `clear <op>` for an intent, and
  // `create <id>` / `write <id>` / `delete <id>` for a row ([storeRows]).
  final intentRows = <String, String>{};
  final events = <String>[];

  // Rows whose guarded writes ([storeRows]) are refused, as when another
  // writer conflicts with them: logged as `refuse <id>`.
  final refused = <String>{};

  String intentOp(String key) =>
      (jsonDecode(intentRows[key] ?? '{}') as Map<String, dynamic>)['op']
          .toString();

  setUpAll(registerAllFallbackValues);

  setUp(() async {
    mockJournalDb = MockJournalDb();
    mockPersistenceLogic = MockPersistenceLogic();
    mockDomainLogger = MockDomainLogger();
    final mockNotificationService = MockNotificationService();
    when(mockNotificationService.updateBadge).thenAnswer((_) async {});

    final mocks = await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..unregister<JournalDb>()
          ..registerSingleton<JournalDb>(mockJournalDb)
          ..unregister<DomainLogger>()
          ..registerSingleton<DomainLogger>(mockDomainLogger)
          ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
          // Deleting an entry (JournalRepository.deleteJournalEntity) asks
          // for the running timer and refreshes the badge.
          ..registerSingleton<TimeService>(MockTimeService())
          ..registerSingleton<NotificationService>(mockNotificationService);
      },
    );

    // The intents a repository records live in the mocked settings table.
    intentRows.clear();
    events.clear();
    refused.clear();
    mockSettingsDb = mocks.settingsDb;
    when(() => mockSettingsDb.saveSettingsItem(any(), any())).thenAnswer((
      inv,
    ) async {
      final key = inv.positionalArguments.first as String;
      intentRows[key] = inv.positionalArguments.last as String;
      events.add('record ${intentOp(key)}');
      return 1;
    });
    when(() => mockSettingsDb.removeSettingsItem(any())).thenAnswer((
      inv,
    ) async {
      final key = inv.positionalArguments.first as String;
      events.add('clear ${intentOp(key)}');
      intentRows.remove(key);
    });
    when(
      () => mockSettingsDb.itemsWithKeyPrefix(
        ChecklistMembershipIntents.keyPrefix,
      ),
    ).thenAnswer((_) async => {...intentRows});

    // Error logging is exercised by several failure-path tests; the stub is
    // identical everywhere so it lives here instead of 11 inline copies.
    when(
      () => mockDomainLogger.error(
        any<LogDomain>(),
        any(),
        stackTrace: any(named: 'stackTrace'),
        subDomain: any(named: 'subDomain'),
      ),
    ).thenAnswer((_) async => true);

    // Create ProviderContainer
    container = ProviderContainer();
    repository = ChecklistRepository();
  });

  tearDown(() async {
    container.dispose();
    await tearDownTestGetIt();
  });

  // Checklist and task-list writes go through `writeOnStored`, which always
  // hands `updateDbEntity` a hook and the stored-version precondition. Each
  // write answers the next of [answers], and `true` once they run out.
  void stubWrites([List<bool?>? answers]) {
    final pending = [...?answers];
    when(
      () => mockPersistenceLogic.updateDbEntity(
        any(),
        linkedId: any(named: 'linkedId'),
        beforeNotify: any(named: 'beforeNotify'),
        precondition: any(named: 'precondition'),
      ),
    ).thenAnswer((_) async => pending.isEmpty ? true : pending.removeAt(0));
  }

  List<JournalEntity> capturedWrites() => verify(
    () => mockPersistenceLogic.updateDbEntity(
      captureAny(),
      linkedId: any(named: 'linkedId'),
      beforeNotify: any(named: 'beforeNotify'),
      precondition: any(named: 'precondition'),
    ),
  ).captured.cast<JournalEntity>();

  void verifyNoWrite() => verifyNever(
    () => mockPersistenceLogic.updateDbEntity(
      any(),
      linkedId: any(named: 'linkedId'),
      beforeNotify: any(named: 'beforeNotify'),
      precondition: any(named: 'precondition'),
    ),
  );

  // A version written by this device carries a new clock; the tests only
  // need it to be told apart from the stored one.
  final updatedMeta = Metadata(
    id: 'updated-meta',
    createdAt: testDate,
    updatedAt: testDate.add(const Duration(minutes: 1)),
    dateFrom: testDate,
    dateTo: testDate,
    vectorClock: const VectorClock({'device': 2}),
  );

  void stubUpdateMetadata() =>
      when(
        () => mockPersistenceLogic.updateMetadata(any()),
      ).thenAnswer(
        (inv) async => (inv.positionalArguments.first as Metadata).copyWith(
          updatedAt: updatedMeta.updatedAt,
          vectorClock: updatedMeta.vectorClock,
        ),
      );

  Checklist checklistWith(
    String id,
    List<String> items, {
    VectorClock clock = const VectorClock({'device': 1}),
  }) => Checklist(
    meta: Metadata(
      id: id,
      createdAt: testDate,
      updatedAt: testDate,
      dateFrom: testDate,
      dateTo: testDate,
      vectorClock: clock,
    ),
    data: ChecklistData(
      title: 'Todos',
      linkedChecklistItems: items,
      linkedTasks: const ['task-1'],
    ),
  );

  ChecklistItem itemIn(
    String id,
    List<String> checklists, {
    String title = 'Count the krill crates',
    bool isChecked = false,
    VectorClock clock = const VectorClock({'device': 1}),
  }) => ChecklistItem(
    meta: Metadata(
      id: id,
      createdAt: testDate,
      updatedAt: testDate,
      dateFrom: testDate,
      dateTo: testDate,
      vectorClock: clock,
    ),
    data: ChecklistItemData(
      title: title,
      isChecked: isChecked,
      linkedChecklists: checklists,
    ),
  );

  Task taskWith(List<String>? checklistIds) => testTask.copyWith(
    data: testTask.data.copyWith(checklistIds: checklistIds),
  );

  // Stored rows behind the mocked JournalDb and PersistenceLogic, for the
  // operations that write several of them: a read returns the row (none
  // once deleted, as JournalDb.journalEntityById hides it), and every create
  // and write replaces it and is logged to [events].
  Map<String, JournalEntity> storeRows(Iterable<JournalEntity> initial) {
    final rows = {for (final row in initial) row.meta.id: row};
    when(() => mockJournalDb.journalEntityById(any())).thenAnswer((inv) async {
      final row = rows[inv.positionalArguments.first as String];
      return row?.meta.deletedAt == null ? row : null;
    });
    stubUpdateMetadata();
    when(
      () => mockPersistenceLogic.updateMetadata(
        any(),
        deletedAt: any(named: 'deletedAt'),
      ),
    ).thenAnswer(
      (inv) async => (inv.positionalArguments.first as Metadata).copyWith(
        deletedAt: inv.namedArguments[#deletedAt] as DateTime?,
        vectorClock: updatedMeta.vectorClock,
      ),
    );
    Future<bool> put(Invocation inv, {bool created = false}) async {
      final row = inv.positionalArguments.first as JournalEntity;
      rows[row.meta.id] = row;
      final verb = created
          ? 'create'
          : row.meta.deletedAt != null
          ? 'delete'
          : 'write';
      events.add('$verb ${row.meta.id}');
      return true;
    }

    when(
      () => mockPersistenceLogic.updateDbEntity(
        any(),
        linkedId: any(named: 'linkedId'),
        beforeNotify: any(named: 'beforeNotify'),
        precondition: any(named: 'precondition'),
      ),
    ).thenAnswer((inv) async {
      final id = (inv.positionalArguments.first as JournalEntity).meta.id;
      if (refused.contains(id)) {
        events.add('refuse $id');
        return false;
      }
      return put(inv);
    });
    // JournalRepository.deleteJournalEntity writes the deletion as is.
    when(() => mockPersistenceLogic.updateDbEntity(any())).thenAnswer(put);
    when(
      () => mockPersistenceLogic.createDbEntity(any()),
    ).thenAnswer((inv) => put(inv, created: true));
    return rows;
  }

  List<String> listed(Map<String, JournalEntity> rows, String checklistId) =>
      (rows[checklistId]! as Checklist).data.linkedChecklistItems;

  // Seeds the settings table with [intent], as an earlier run recorded it.
  String seedIntent(MembershipIntent intent, [String suffix = '']) {
    final key = '${ChecklistMembershipIntents.keyPrefix}seeded$suffix';
    intentRows[key] = jsonEncode(intent.toJson());
    return key;
  }

  group('createChecklist', () {
    test('returns null checklist when taskId is null', () async {
      // Act
      final result = await repository.createChecklist(taskId: null);

      // Assert
      expect(result.checklist, isNull);
      expect(result.createdItems, isEmpty);
      verifyNever(() => mockJournalDb.journalEntityById(any()));
    });

    test('returns null checklist when task not found', () async {
      // Arrange
      const taskId = 'non-existent-task-id';
      when(
        () => mockJournalDb.journalEntityById(taskId),
      ).thenAnswer((_) async => null);

      // Act
      final result = await repository.createChecklist(taskId: taskId);

      // Assert
      expect(result.checklist, isNull);
      expect(result.createdItems, isEmpty);
      verify(() => mockJournalDb.journalEntityById(taskId)).called(1);
    });

    test('returns null checklist when entity is not a Task', () async {
      // Arrange
      final entryId = testTextEntry.id;
      when(
        () => mockJournalDb.journalEntityById(entryId),
      ).thenAnswer((_) async => testTextEntry);

      // Act
      final result = await repository.createChecklist(taskId: entryId);

      // Assert
      expect(result.checklist, isNull);
      expect(result.createdItems, isEmpty);
      verify(() => mockJournalDb.journalEntityById(entryId)).called(1);
    });

    test('creates checklist successfully', () async {
      // Arrange
      final taskId = testTask.id;
      final metadata = testTask.meta.copyWith(id: 'new-checklist-id');

      when(
        () => mockJournalDb.journalEntityById(taskId),
      ).thenAnswer((_) async => testTask);
      when(
        () => mockPersistenceLogic.createMetadata(),
      ).thenAnswer((_) async => metadata);
      when(
        () => mockPersistenceLogic.createDbEntity(any()),
      ).thenAnswer((_) async => true);
      stubUpdateMetadata();
      stubWrites();

      // Act
      final result = await repository.createChecklist(taskId: taskId);

      // Assert
      expect(result, isNotNull);
      expect(result.checklist, isNotNull);
      expect(result.checklist!.meta.id, equals(metadata.id));
      final checklist = result.checklist! as Checklist;
      expect(checklist.data.title, equals('Todos'));
      expect(checklist.data.linkedTasks, contains(taskId));
      expect(result.createdItems, isEmpty);

      verify(() => mockPersistenceLogic.createMetadata()).called(1);
      verify(() => mockPersistenceLogic.createDbEntity(any())).called(1);
      // The new checklist is listed on the task as stored.
      final written = capturedWrites().single as Task;
      expect(written.meta.id, taskId);
      expect(written.data.checklistIds, ['new-checklist-id']);
      expect(written.data.title, testTask.data.title);
    });

    test(
      'lists the new checklist after the ones the stored task lists',
      () async {
        final stored = testTask.copyWith(
          data: testTask.data.copyWith(checklistIds: ['synced-checklist']),
        );
        when(
          () => mockJournalDb.journalEntityById(testTask.id),
        ).thenAnswer((_) async => stored);
        when(
          () => mockPersistenceLogic.createMetadata(),
        ).thenAnswer((_) async => testTask.meta.copyWith(id: 'new-checklist'));
        when(
          () => mockPersistenceLogic.createDbEntity(any()),
        ).thenAnswer((_) async => true);
        stubUpdateMetadata();
        stubWrites();

        await repository.createChecklist(taskId: testTask.id);

        final written = capturedWrites().single as Task;
        expect(written.data.checklistIds, [
          'synced-checklist',
          'new-checklist',
        ]);
      },
    );

    test(
      'lists the checklist under a ListChecklistIntent, and all its items '
      'under one ListItemsIntent',
      () async {
        final rows = storeRows([
          taskWith(const ['first']),
        ]);
        final ids = ['new-checklist', 'item-1', 'item-2'];
        when(
          () => mockPersistenceLogic.createMetadata(),
        ).thenAnswer((_) async => testTask.meta.copyWith(id: ids.removeAt(0)));

        final result = await repository.createChecklist(
          taskId: testTask.id,
          items: const [
            ChecklistItemData(
              title: 'Pack the fish',
              isChecked: false,
              linkedChecklists: [],
            ),
            ChecklistItemData(
              title: 'Count the eggs',
              isChecked: true,
              linkedChecklists: [],
            ),
          ],
        );

        expect(result.createdItems.map((item) => item.id), [
          'item-1',
          'item-2',
        ]);
        expect(events, [
          'record listChecklist',
          'create new-checklist',
          'write ${testTask.id}',
          'clear listChecklist',
          'record listItems',
          'create item-1',
          'create item-2',
          'write new-checklist',
          'clear listItems',
        ]);
        final saved = verify(
          () => mockSettingsDb.saveSettingsItem(any(), captureAny()),
        ).captured.map((json) => jsonDecode(json as String)).toList();
        expect(saved, [
          {
            'op': 'listChecklist',
            'checklistId': 'new-checklist',
            'taskId': testTask.id,
          },
          {
            'op': 'listItems',
            'checklistId': 'new-checklist',
            'itemIds': ['item-1', 'item-2'],
          },
        ]);
        expect(intentRows, isEmpty);
        expect((rows[testTask.id]! as Task).data.checklistIds, [
          'first',
          'new-checklist',
        ]);
        expect(listed(rows, 'new-checklist'), ['item-1', 'item-2']);
        for (final id in ['item-1', 'item-2']) {
          expect(
            (rows[id]! as ChecklistItem).data.linkedChecklists,
            ['new-checklist'],
          );
        }
      },
    );

    test('creates checklist with items successfully', () async {
      // Arrange
      final taskId = testTask.id;
      final metadata = testTask.meta.copyWith(id: 'new-checklist-id');
      final approval = makeTestChecklistApproval();
      final items = [
        const ChecklistItemData(
          title: 'Item 1',
          isChecked: false,
          linkedChecklists: [],
        ),
        ChecklistItemData(
          title: 'Item 2',
          checkedAt: approval.approvedAt,
          approvalHistory: [approval],
          isChecked: true,
          linkedChecklists: [],
        ),
      ];

      final checklist = Checklist(
        meta: metadata,
        data: ChecklistData(
          title: testTask.data.title,
          linkedChecklistItems: [],
          linkedTasks: [taskId],
        ),
      );

      when(
        () => mockJournalDb.journalEntityById(taskId),
      ).thenAnswer((_) async => testTask);
      // The checklist first, then one id per item.
      final createdMeta = [
        metadata,
        testTask.meta.copyWith(id: 'item-1'),
        testTask.meta.copyWith(id: 'item-2'),
      ];
      when(
        () => mockPersistenceLogic.createMetadata(),
      ).thenAnswer((_) async => createdMeta.removeAt(0));
      when(
        () => mockPersistenceLogic.createDbEntity(any()),
      ).thenAnswer((_) async => true);
      stubUpdateMetadata();
      stubWrites();
      when(
        () => mockJournalDb.journalEntityById(metadata.id),
      ).thenAnswer((_) async => checklist);

      // Act
      final result = await repository.createChecklist(
        taskId: taskId,
        items: items,
      );

      // Assert
      expect(result.checklist, isNotNull);
      expect(result.createdItems.map((item) => item.id), ['item-1', 'item-2']);
      // The task lists the checklist, and the stored checklist lists both
      // created items.
      final updates = capturedWrites();
      expect(updates, hasLength(2));
      expect((updates.first as Task).data.checklistIds, [metadata.id]);
      final listed = updates.last as Checklist;
      expect(listed.meta.id, metadata.id);
      expect(listed.data.linkedChecklistItems, ['item-1', 'item-2']);
      final written = verify(
        () => mockPersistenceLogic.createDbEntity(captureAny()),
      ).captured.whereType<ChecklistItem>().toList();
      expect(written.length, 2);
      expect(
        written
            .singleWhere((item) => item.data.title == 'Item 2')
            .data
            .checkedStateApproval,
        approval,
      );
      expect(
        written
            .singleWhere((item) => item.data.title == 'Item 1')
            .data
            .approvalHistory,
        isEmpty,
      );
    });

    test(
      'returns the checklist without the items whose rows failed to write, '
      'and does not rewrite it',
      () async {
        final rows = storeRows([taskWith(const [])]);
        final ids = ['new-checklist', 'item-1'];
        when(
          () => mockPersistenceLogic.createMetadata(),
        ).thenAnswer((_) async => testTask.meta.copyWith(id: ids.removeAt(0)));
        final failure = Exception('disk full');
        when(
          () => mockPersistenceLogic.createDbEntity(any()),
        ).thenAnswer((inv) async {
          final entity = inv.positionalArguments.first as JournalEntity;
          if (entity is ChecklistItem) throw failure;
          rows[entity.meta.id] = entity;
          return true;
        });

        final result = await repository.createChecklist(
          taskId: testTask.id,
          items: const [
            ChecklistItemData(
              title: 'Item 1',
              isChecked: false,
              linkedChecklists: [],
            ),
          ],
        );

        expect(result.checklist?.meta.id, 'new-checklist');
        expect(result.createdItems, isEmpty);
        verify(
          () => mockDomainLogger.error(
            LogDomain.persistence,
            failure,
            stackTrace: any(named: 'stackTrace'),
            subDomain: 'createChecklistEntry',
          ),
        ).called(1);
        // The task lists the checklist; with no item created, the checklist
        // is not rewritten, and both intents are cleared.
        expect(events, [
          'record listChecklist',
          'write ${testTask.id}',
          'clear listChecklist',
          'record listItems',
          'clear listItems',
        ]);
        expect(listed(rows, 'new-checklist'), isEmpty);
        expect(intentRows, isEmpty);
      },
    );

    test(
      'writes nothing — no checklist, no task write, no intent — when an '
      "item's metadata cannot be created",
      () async {
        final rows = storeRows([
          taskWith(const ['first']),
        ]);
        final failure = StateError('vector clock unavailable');
        final metas = <Metadata Function()>[
          () => testTask.meta.copyWith(id: 'new-checklist'),
          () => testTask.meta.copyWith(id: 'item-1'),
          () => throw failure,
        ];
        when(
          () => mockPersistenceLogic.createMetadata(),
        ).thenAnswer((_) async => metas.removeAt(0)());

        final result = await repository.createChecklist(
          taskId: testTask.id,
          items: const [
            ChecklistItemData(
              title: 'Pack the fish',
              isChecked: false,
              linkedChecklists: [],
            ),
            ChecklistItemData(
              title: 'Count the eggs',
              isChecked: false,
              linkedChecklists: [],
            ),
          ],
        );

        expect(result.checklist, isNull);
        expect(result.createdItems, isEmpty);
        expect(events, isEmpty);
        expect(intentRows, isEmpty);
        expect(rows.keys, [testTask.id]);
        expect((rows[testTask.id]! as Task).data.checklistIds, ['first']);
        verify(
          () => mockDomainLogger.error(
            LogDomain.persistence,
            failure,
            stackTrace: any(named: 'stackTrace'),
            subDomain: 'createChecklistEntry',
          ),
        ).called(1);
      },
    );

    test(
      'keeps the ListChecklistIntent when the task write is refused, and the '
      'next start lists the checklist',
      () async {
        final rows = storeRows([
          taskWith(const ['first']),
        ]);
        when(
          () => mockPersistenceLogic.createMetadata(),
        ).thenAnswer((_) async => testTask.meta.copyWith(id: 'new-checklist'));
        refused.add(testTask.id);

        final result = await repository.createChecklist(taskId: testTask.id);

        expect(result.checklist?.meta.id, 'new-checklist');
        expect(events, [
          'record listChecklist',
          'create new-checklist',
          'refuse ${testTask.id}',
        ]);
        expect(
          intentRows.values.map(jsonDecode).single,
          containsPair('op', 'listChecklist'),
        );

        refused.clear();
        await repository.replayMembershipIntents();

        expect((rows[testTask.id]! as Task).data.checklistIds, [
          'first',
          'new-checklist',
        ]);
        expect(intentRows, isEmpty);
      },
    );

    test(
      'a checklist whose creation reported no result is not listed, creates '
      'no item, and clears its intent',
      () async {
        final rows = storeRows([
          taskWith(const ['first']),
        ]);
        final ids = ['new-checklist', 'item-1'];
        when(
          () => mockPersistenceLogic.createMetadata(),
        ).thenAnswer((_) async => testTask.meta.copyWith(id: ids.removeAt(0)));
        when(
          () => mockPersistenceLogic.createDbEntity(any()),
        ).thenAnswer((inv) async {
          events.add(
            'create? ${(inv.positionalArguments.first as JournalEntity).id}',
          );
          return null;
        });

        final result = await repository.createChecklist(
          taskId: testTask.id,
          items: const [
            ChecklistItemData(
              title: 'Pack the fish',
              isChecked: false,
              linkedChecklists: [],
            ),
          ],
        );

        expect(result.checklist, isNull);
        expect(result.createdItems, isEmpty);
        // No task write, no item row and no ListItemsIntent; the
        // ListChecklistIntent has nothing left to finish.
        expect(events, [
          'record listChecklist',
          'create? new-checklist',
          'clear listChecklist',
        ]);
        expect(intentRows, isEmpty);
        expect((rows[testTask.id]! as Task).data.checklistIds, ['first']);
        expect(rows.keys, [testTask.id]);
      },
    );

    test(
      'keeps the ListItemsIntent when the list write is refused, and the '
      'next start lists the items',
      () async {
        final rows = storeRows([taskWith(const [])]);
        final ids = ['new-checklist', 'item-1'];
        when(
          () => mockPersistenceLogic.createMetadata(),
        ).thenAnswer((_) async => testTask.meta.copyWith(id: ids.removeAt(0)));
        refused.add('new-checklist');

        final result = await repository.createChecklist(
          taskId: testTask.id,
          items: const [
            ChecklistItemData(
              title: 'Pack the fish',
              isChecked: false,
              linkedChecklists: [],
            ),
          ],
        );

        expect(result.checklist?.meta.id, 'new-checklist');
        expect(events.last, 'refuse new-checklist');
        expect(listed(rows, 'new-checklist'), isEmpty);
        expect(
          intentRows.values.map(jsonDecode).single,
          containsPair('op', 'listItems'),
        );

        refused.clear();
        await repository.replayMembershipIntents();

        expect(listed(rows, 'new-checklist'), ['item-1']);
        expect(intentRows, isEmpty);
      },
    );

    test('handles exceptions gracefully', () async {
      // Arrange
      final taskId = testTask.id;
      final exception = Exception('Test exception');

      when(() => mockJournalDb.journalEntityById(taskId)).thenThrow(exception);

      // Act
      final result = await repository.createChecklist(taskId: taskId);

      // Assert
      expect(result.checklist, isNull);
      expect(result.createdItems, isEmpty);
      verify(
        () => mockDomainLogger.error(
          LogDomain.persistence,
          exception,
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'createChecklistEntry',
        ),
      ).called(1);
    });
  });

  group('updateChecklist', () {
    ChecklistData appendItem(ChecklistData stored) => stored.copyWith(
      linkedChecklistItems: withMember(stored.linkedChecklistItems, 'new'),
    );

    test('returns null when checklist not found', () async {
      when(
        () => mockJournalDb.journalEntityById('missing'),
      ).thenAnswer((_) async => null);

      final result = await repository.updateChecklist(
        checklistId: 'missing',
        change: appendItem,
      );

      expect(result, isNull);
      verifyNoWrite();
    });

    test(
      'applies the change to the stored data and returns the written '
      'checklist',
      () async {
        final stored = checklistWith('checklist-id', ['stored-item']);
        when(
          () => mockJournalDb.journalEntityById('checklist-id'),
        ).thenAnswer((_) async => stored);
        stubUpdateMetadata();
        stubWrites();
        final seen = <ChecklistData>[];

        final result = await repository.updateChecklist(
          checklistId: 'checklist-id',
          change: (data) {
            seen.add(data);
            return appendItem(data).copyWith(title: 'Renamed');
          },
        );

        // The change saw the stored row, not a copy the caller held.
        expect(seen, [stored.data]);
        final written = capturedWrites().single as Checklist;
        expect(written.data.linkedChecklistItems, ['stored-item', 'new']);
        expect(written.data.title, 'Renamed');
        // Under a new clock, from updateMetadata on the stored meta.
        expect(written.meta.vectorClock, updatedMeta.vectorClock);
        verify(
          () => mockPersistenceLogic.updateMetadata(stored.meta),
        ).called(1);
        expect(result, written);
      },
    );

    test('a change that leaves the data as stored writes nothing and returns '
        'the stored checklist', () async {
      final stored = checklistWith('checklist-id', ['new']);
      when(
        () => mockJournalDb.journalEntityById('checklist-id'),
      ).thenAnswer((_) async => stored);
      stubWrites();

      final result = await repository.updateChecklist(
        checklistId: 'checklist-id',
        change: appendItem,
      );

      expect(result, stored);
      verifyNoWrite();
      verifyNever(() => mockPersistenceLogic.updateMetadata(any()));
    });

    test(
      'a refused write is built again on the row stored meanwhile, keeping '
      'the item that synced in (ChecklistMembership.tla NoLostItem)',
      () async {
        final first = checklistWith('checklist-id', ['a']);
        final synced = checklistWith(
          'checklist-id',
          ['a', 'synced'],
          clock: const VectorClock({'device': 1, 'other': 1}),
        );
        final reads = [first, synced];
        when(
          () => mockJournalDb.journalEntityById('checklist-id'),
        ).thenAnswer((_) async => reads.removeAt(0));
        stubUpdateMetadata();
        stubWrites([false, true]);

        final result = await repository.updateChecklist(
          checklistId: 'checklist-id',
          change: appendItem,
        );

        final attempts = capturedWrites().cast<Checklist>();
        expect(
          attempts.map((c) => c.data.linkedChecklistItems),
          [
            ['a', 'new'],
            ['a', 'synced', 'new'],
          ],
        );
        expect(result, attempts.last);
        expect(result!.data.linkedChecklistItems, ['a', 'synced', 'new']);
      },
    );

    test(
      'a write refused while the row stays as read is not retried: it was '
      'refused for another reason, and would be again',
      () async {
        when(
          () => mockJournalDb.journalEntityById('checklist-id'),
        ).thenAnswer((_) async => checklistWith('checklist-id', ['a']));
        stubUpdateMetadata();
        // A retry would be accepted: only the stop rule keeps it out.
        stubWrites([false]);

        final result = await repository.updateChecklist(
          checklistId: 'checklist-id',
          change: appendItem,
        );

        expect(result, isNull);
        expect(capturedWrites(), hasLength(1));
        // The row was read again to tell a race from a refusal.
        verify(
          () => mockJournalDb.journalEntityById('checklist-id'),
        ).called(2);
      },
    );

    test(
      'keeps building on the row for as long as it keeps moving, past any '
      'fixed number of attempts',
      () async {
        // Each read is a newer version: another item synced in each time.
        final reads = [
          for (var n = 1; n <= 5; n++)
            checklistWith('checklist-id', [
              for (var i = 1; i <= n; i++) 'synced-$i',
            ], clock: VectorClock({'other': n})),
        ];
        when(
          () => mockJournalDb.journalEntityById('checklist-id'),
        ).thenAnswer((_) async => reads.removeAt(0));
        stubUpdateMetadata();
        stubWrites([false, false, false, false, true]);

        final result = await repository.updateChecklist(
          checklistId: 'checklist-id',
          change: appendItem,
        );

        final attempts = capturedWrites().cast<Checklist>();
        expect(attempts, hasLength(5));
        expect(result!.data.linkedChecklistItems, [
          'synced-1',
          'synced-2',
          'synced-3',
          'synced-4',
          'synced-5',
          'new',
        ]);
      },
    );

    test(
      'returns null and logs for an entity that is not a checklist',
      () async {
        final entryId = testTextEntry.id;
        when(
          () => mockJournalDb.journalEntityById(entryId),
        ).thenAnswer((_) async => testTextEntry);

        final result = await repository.updateChecklist(
          checklistId: entryId,
          change: appendItem,
        );

        expect(result, isNull);
        verifyNoWrite();
        verify(
          () => mockDomainLogger.error(
            LogDomain.persistence,
            'not a checklist',
            stackTrace: any(named: 'stackTrace'),
            subDomain: 'updateChecklist',
          ),
        ).called(1);
      },
    );

    test('returns null and logs when the read throws', () async {
      final exception = Exception('Test exception');
      when(
        () => mockJournalDb.journalEntityById('checklist-id'),
      ).thenThrow(exception);

      final result = await repository.updateChecklist(
        checklistId: 'checklist-id',
        change: appendItem,
      );

      expect(result, isNull);
      verify(
        () => mockDomainLogger.error(
          LogDomain.persistence,
          exception,
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'updateChecklist',
        ),
      ).called(1);
    });
  });

  group('updateTaskChecklistIds', () {
    Task taskListing(List<String>? ids) => testTask.copyWith(
      data: testTask.data.copyWith(checklistIds: ids),
    );

    test('returns false for an entity that is not a task and writes '
        'nothing', () async {
      when(
        () => mockJournalDb.journalEntityById(testTextEntry.id),
      ).thenAnswer((_) async => testTextEntry);

      final result = await repository.updateTaskChecklistIds(
        taskId: testTextEntry.id,
        change: (ids) => withMember(ids, 'c'),
      );

      expect(result, isFalse);
      verifyNoWrite();
    });

    test('returns false when the task is missing', () async {
      when(
        () => mockJournalDb.journalEntityById('gone'),
      ).thenAnswer((_) async => null);

      final result = await repository.updateTaskChecklistIds(
        taskId: 'gone',
        change: (ids) => withMember(ids, 'c'),
      );

      expect(result, isFalse);
      verifyNoWrite();
    });

    test('a change that leaves the list as stored writes nothing', () async {
      when(
        () => mockJournalDb.journalEntityById(testTask.id),
      ).thenAnswer((_) async => taskListing(['c']));

      final result = await repository.updateTaskChecklistIds(
        taskId: testTask.id,
        change: (ids) => withMember(ids, 'c'),
      );

      expect(result, isTrue);
      verifyNoWrite();
      verifyNever(() => mockPersistenceLogic.updateMetadata(any()));
    });

    test(
      'applies the change to the stored list and keeps the rest of the task',
      () async {
        final seen = <List<String>>[];
        when(
          () => mockJournalDb.journalEntityById(testTask.id),
        ).thenAnswer((_) async => taskListing(null));
        stubUpdateMetadata();
        stubWrites();

        final result = await repository.updateTaskChecklistIds(
          taskId: testTask.id,
          change: (ids) {
            seen.add(ids);
            return withMember(ids, 'c');
          },
        );

        expect(result, isTrue);
        // A task that lists nothing yet hands the change an empty list.
        expect(seen, [const <String>[]]);
        final written = capturedWrites().single as Task;
        expect(written.data.checklistIds, ['c']);
        expect(written.data.title, testTask.data.title);
        expect(written.meta.vectorClock, updatedMeta.vectorClock);
      },
    );

    test('returns false and logs when the read throws', () async {
      final exception = Exception('Test exception');
      when(
        () => mockJournalDb.journalEntityById(testTask.id),
      ).thenThrow(exception);

      final result = await repository.updateTaskChecklistIds(
        taskId: testTask.id,
        change: (ids) => withMember(ids, 'c'),
      );

      expect(result, isFalse);
      verify(
        () => mockDomainLogger.error(
          LogDomain.persistence,
          exception,
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'updateTaskChecklistIds',
        ),
      ).called(1);
    });
  });

  group('updateChecklistItem', () {
    ChecklistItemData check(ChecklistItemData stored) =>
        stored.copyWith(isChecked: true, checkedBy: ChangeSource.user);

    test('a direct edit back to the approved title ends its approval', () {
      final approval = makeTestChecklistApproval(
        isChecked: null,
        title: 'Inspect feeder',
      );
      final approved = ChecklistItemData(
        title: 'Inspect feeder',
        isChecked: false,
        linkedChecklists: const ['checklist-id'],
        approvalHistory: [approval],
        titleSetAt: approval.approvedAt,
      );
      final edited = DateTime(2030, 1, 2, 9);
      return withClock(Clock.fixed(edited), () async {
        final stored = itemIn('item', const ['checklist-id']).copyWith(
          data: approved.copyWith(title: 'Inspect the feeder'),
        );
        when(
          () => mockJournalDb.journalEntityById('item'),
        ).thenAnswer((_) async => stored);
        stubUpdateMetadata();
        stubWrites();

        await repository.updateChecklistItem(
          checklistItemId: 'item',
          change: (data) => data.copyWith(title: 'Inspect feeder'),
          taskId: null,
        );

        final written = capturedWrites().single as ChecklistItem;
        expect(written.data.title, 'Inspect feeder');
        expect(written.data.titleSetAt, edited);
        expect(written.data.titleApproval, isNull);
        // Untouched fields keep their times.
        expect(written.data.archivedSetAt, isNull);
      });
    });

    test('returns null and writes nothing when the item is missing', () async {
      when(
        () => mockJournalDb.journalEntityById('missing'),
      ).thenAnswer((_) async => null);

      final result = await repository.updateChecklistItem(
        checklistItemId: 'missing',
        change: check,
        taskId: null,
      );

      expect(result, isNull);
      verifyNoWrite();
    });

    test(
      'applies the change to the stored item, under the task as linked id, '
      'and returns the written item',
      () async {
        final stored = itemIn('item', const ['checklist-id']);
        when(
          () => mockJournalDb.journalEntityById('item'),
        ).thenAnswer((_) async => stored);
        stubUpdateMetadata();
        stubWrites();
        final seen = <ChecklistItemData>[];

        final result = await repository.updateChecklistItem(
          checklistItemId: 'item',
          change: (data) {
            seen.add(data);
            return check(data);
          },
          taskId: 'task-id',
        );

        expect(seen, [stored.data]);
        final written =
            verify(
                  () => mockPersistenceLogic.updateDbEntity(
                    captureAny(),
                    linkedId: 'task-id',
                    beforeNotify: any(named: 'beforeNotify'),
                    precondition: any(named: 'precondition'),
                  ),
                ).captured.single
                as ChecklistItem;
        expect(written.data.isChecked, isTrue);
        expect(written.data.title, stored.data.title);
        expect(written.data.linkedChecklists, ['checklist-id']);
        expect(written.meta.vectorClock, updatedMeta.vectorClock);
        expect(result, written);
      },
    );

    test(
      'a refused write is built again on the item stored meanwhile, so a '
      'check from a screen that predates a move and a rename writes neither '
      'back (ChecklistMembership.tla BackLinkAgrees)',
      () async {
        final beforeMove = itemIn('item', const ['old-checklist']);
        final moved = itemIn(
          'item',
          const ['new-checklist'],
          title: 'Count the krill crates twice',
          clock: const VectorClock({'device': 1, 'other': 1}),
        );
        final reads = [beforeMove, moved];
        when(
          () => mockJournalDb.journalEntityById('item'),
        ).thenAnswer((_) async => reads.removeAt(0));
        stubUpdateMetadata();
        stubWrites([false, true]);

        final result = await repository.updateChecklistItem(
          checklistItemId: 'item',
          change: check,
          taskId: null,
        );

        final attempts = capturedWrites().cast<ChecklistItem>();
        expect(attempts.map((item) => item.data.linkedChecklists), [
          ['old-checklist'],
          ['new-checklist'],
        ]);
        expect(result!.data.linkedChecklists, ['new-checklist']);
        expect(result.data.title, 'Count the krill crates twice');
        expect(result.data.isChecked, isTrue);
      },
    );

    test(
      'a change that leaves the item as stored writes nothing and returns '
      'the stored item',
      () async {
        final stored = itemIn('item', const ['checklist-id'], isChecked: true);
        when(
          () => mockJournalDb.journalEntityById('item'),
        ).thenAnswer((_) async => stored);
        stubWrites();

        final result = await repository.updateChecklistItem(
          checklistItemId: 'item',
          change: (data) => data.copyWith(isChecked: true),
          taskId: null,
        );

        expect(result, stored);
        verifyNoWrite();
        verifyNever(() => mockPersistenceLogic.updateMetadata(any()));
      },
    );

    test('returns null when the write is refused', () async {
      when(
        () => mockJournalDb.journalEntityById('item'),
      ).thenAnswer((_) async => itemIn('item', const ['checklist-id']));
      stubUpdateMetadata();
      stubWrites([false]);

      final result = await repository.updateChecklistItem(
        checklistItemId: 'item',
        change: check,
        taskId: null,
      );

      expect(result, isNull);
      expect(capturedWrites(), hasLength(1));
    });

    test('returns null and logs for an entity that is not an item', () async {
      final entryId = testTextEntry.id;
      when(
        () => mockJournalDb.journalEntityById(entryId),
      ).thenAnswer((_) async => testTextEntry);

      final result = await repository.updateChecklistItem(
        checklistItemId: entryId,
        change: check,
        taskId: null,
      );

      expect(result, isNull);
      verifyNoWrite();
      verify(
        () => mockDomainLogger.error(
          LogDomain.persistence,
          'not a checklist item',
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'updateChecklistItem',
        ),
      ).called(1);
    });

    test('returns null and logs when the read throws', () async {
      final exception = Exception('Test exception');
      when(() => mockJournalDb.journalEntityById('item')).thenThrow(exception);

      final result = await repository.updateChecklistItem(
        checklistItemId: 'item',
        change: check,
        taskId: null,
      );

      expect(result, isNull);
      verify(
        () => mockDomainLogger.error(
          LogDomain.persistence,
          exception,
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'updateChecklistItem',
        ),
      ).called(1);
    });
  });

  group('derivedChecklistFor', () {
    Checklist checklistRow(String id, {bool deleted = false}) => Checklist(
      meta: Metadata(
        id: id,
        createdAt: testDate,
        updatedAt: testDate,
        dateFrom: testDate,
        dateTo: testDate,
        deletedAt: deleted ? testDate : null,
      ),
      data: const ChecklistData(
        title: 'Todos',
        linkedChecklistItems: [],
        linkedTasks: ['task-1'],
      ),
    );

    test('reports nothing when the task is gone', () async {
      when(
        () => mockJournalDb.journalEntityMapForIdsIncludingDeleted(any()),
      ).thenAnswer((inv) async {
        final id = (inv.positionalArguments.first as List<String>).single;
        return {id: checklistRow(id)};
      });
      when(
        () => mockJournalDb.journalEntityById('task-1'),
      ).thenAnswer((_) async => null);

      expect(
        await repository.derivedChecklistFor(
          taskId: 'task-1',
          uuidV5Input: 'k',
        ),
        isNull,
      );
      verifyNoWrite();
    });

    test(
      'lists a live derived checklist the stored task does not list yet',
      () async {
        final derivedId = MetadataService.deterministicId('k');
        when(
          () => mockJournalDb.journalEntityMapForIdsIncludingDeleted(any()),
        ).thenAnswer((inv) async {
          final id = (inv.positionalArguments.first as List<String>).single;
          return {id: checklistRow(id)};
        });
        when(() => mockJournalDb.journalEntityById(testTask.id)).thenAnswer(
          (_) async => testTask.copyWith(
            data: testTask.data.copyWith(checklistIds: ['other']),
          ),
        );
        stubUpdateMetadata();
        stubWrites();

        expect(
          await repository.derivedChecklistFor(
            taskId: testTask.id,
            uuidV5Input: 'k',
          ),
          derivedId,
        );
        final written = capturedWrites().single as Task;
        expect(written.data.checklistIds, ['other', derivedId]);
        verifyNever(() => mockPersistenceLogic.createDbEntity(any()));
      },
    );

    test(
      'falls back to a random id past eight deleted generations',
      () async {
        when(
          () => mockJournalDb.journalEntityMapForIdsIncludingDeleted(any()),
        ).thenAnswer((inv) async {
          final id = (inv.positionalArguments.first as List<String>).single;
          return {id: checklistRow(id, deleted: true)};
        });
        when(
          () => mockJournalDb.journalEntityById(testTask.id),
        ).thenAnswer((_) async => testTask);
        when(
          () => mockPersistenceLogic.createMetadata(),
        ).thenAnswer((_) async => testTask.meta.copyWith(id: 'random-id'));
        when(
          () => mockPersistenceLogic.createDbEntity(any()),
        ).thenAnswer((_) async => true);
        stubUpdateMetadata();
        stubWrites();

        expect(
          await repository.derivedChecklistFor(
            taskId: testTask.id,
            uuidV5Input: 'k',
          ),
          'random-id',
        );
        verify(
          () => mockJournalDb.journalEntityMapForIdsIncludingDeleted(any()),
        ).called(8);
        verify(() => mockPersistenceLogic.createMetadata()).called(1);
        expect((capturedWrites().single as Task).data.checklistIds, [
          'random-id',
        ]);
      },
    );
  });

  group('addItemToChecklist', () {
    test(
      'successfully creates item and updates checklist atomically',
      () async {
        // Arrange
        const checklistId = 'checklist-id';
        const title = 'New Item';
        const isChecked = false;
        const categoryId = 'category-id';

        final checklist = Checklist(
          meta: Metadata(
            id: checklistId,
            categoryId: categoryId,
            createdAt: testDate,
            updatedAt: testDate,
            dateFrom: testDate,
            dateTo: testDate,
            starred: false,
            private: false,
            utcOffset: 0,
            vectorClock: const VectorClock({}),
          ),
          data: const ChecklistData(
            title: 'Test Checklist',
            linkedChecklistItems: ['existing-item-1', 'existing-item-2'],
            linkedTasks: ['task-1'],
          ),
        );

        final newItem = ChecklistItem(
          meta: Metadata(
            id: 'new-item-id',
            categoryId: categoryId,
            createdAt: testDate,
            updatedAt: testDate,
            dateFrom: testDate,
            dateTo: testDate,
            starred: false,
            private: false,
            utcOffset: 0,
            vectorClock: const VectorClock({}),
          ),
          data: const ChecklistItemData(
            title: title,
            isChecked: isChecked,
            linkedChecklists: [checklistId],
          ),
        );

        when(
          () => mockPersistenceLogic.createMetadata(),
        ).thenAnswer((_) async => newItem.meta);
        when(
          () => mockPersistenceLogic.createDbEntity(any()),
        ).thenAnswer((_) async => true);
        when(
          () => mockJournalDb.journalEntityById(checklistId),
        ).thenAnswer((_) async => checklist);
        when(() => mockPersistenceLogic.updateMetadata(any())).thenAnswer(
          (_) async => checklist.meta.copyWith(
            updatedAt: testDate,
          ),
        );
        stubWrites();

        final approval = makeTestChecklistApproval(isChecked: isChecked);
        // Act
        final result = await repository.addItemToChecklist(
          checklistId: checklistId,
          title: title,
          isChecked: isChecked,
          categoryId: categoryId,
          checkedAt: approval.approvedAt,
          approvalHistory: [approval],
        );

        // Assert
        expect(result, isNotNull);
        expect(result!.data.title, equals(title));
        expect(result.data.isChecked, equals(isChecked));
        expect(result.data.checkedStateApproval, approval);

        // Verify that the checklist was updated with the new item
        final capturedChecklist = capturedWrites().single as Checklist;

        expect(
          capturedChecklist.data.linkedChecklistItems,
          equals(['existing-item-1', 'existing-item-2', 'new-item-id']),
        );
      },
    );

    test(
      'derives the id from uuidV5Input and lists an id the checklist holds '
      'only once',
      () async {
        // A confirmed agent change applied on two devices adds the same
        // derived id twice (ADR 0075).
        const checklistId = 'checklist-id';
        const uuidV5Input = 'change-effect:set-1:0:checklist-item:0';
        final meta = Metadata(
          id: 'derived-item-id',
          createdAt: testDate,
          updatedAt: testDate,
          dateFrom: testDate,
          dateTo: testDate,
        );
        final checklist = Checklist(
          meta: meta.copyWith(id: checklistId),
          data: const ChecklistData(
            title: 'Todos',
            linkedChecklistItems: ['derived-item-id'],
            linkedTasks: ['task-1'],
          ),
        );
        when(
          () => mockPersistenceLogic.createMetadata(uuidV5Input: uuidV5Input),
        ).thenAnswer((_) async => meta);
        when(
          () => mockPersistenceLogic.createDbEntity(any()),
        ).thenAnswer((_) async => false);
        when(
          () => mockJournalDb.journalEntityById(checklistId),
        ).thenAnswer((_) async => checklist);
        // The other device's row under the derived id, which refused the
        // creation.
        when(
          () => mockJournalDb.journalEntityById('derived-item-id'),
        ).thenAnswer((_) async => itemIn('derived-item-id', [checklistId]));
        // A rewrite of the checklist would go through here.
        when(
          () => mockPersistenceLogic.updateMetadata(any()),
        ).thenAnswer((_) async => checklist.meta);
        stubWrites();

        final result = await repository.addItemToChecklist(
          checklistId: checklistId,
          title: 'Send invites',
          isChecked: false,
          categoryId: null,
          uuidV5Input: uuidV5Input,
        );

        expect(result?.id, 'derived-item-id');
        verify(
          () => mockPersistenceLogic.createMetadata(uuidV5Input: uuidV5Input),
        ).called(1);
        verifyNoWrite();
      },
    );

    group('an item row the creation did not store', () {
      const checklistId = 'checklist-id';
      late Map<String, JournalEntity> rows;

      setUp(() {
        rows = storeRows([
          checklistWith(checklistId, const ['existing']),
        ]);
        when(
          () => mockPersistenceLogic.createMetadata(),
        ).thenAnswer((_) async => testTask.meta.copyWith(id: 'new-item'));
      });

      void stubCreate({required bool? answer}) =>
          when(
            () => mockPersistenceLogic.createDbEntity(any()),
          ).thenAnswer((inv) async {
            events.add(
              'create? ${(inv.positionalArguments.first as JournalEntity).id}',
            );
            return answer;
          });

      Future<ChecklistItem?> add() => repository.addItemToChecklist(
        checklistId: checklistId,
        title: 'Count the krill crates',
        isChecked: false,
        categoryId: null,
      );

      test(
        'reported no result: returns null, lists nothing and keeps the '
        'intent',
        () async {
          stubCreate(answer: null);

          expect(await add(), isNull);

          expect(events, ['record listItems', 'create? new-item']);
          expect(listed(rows, checklistId), ['existing']);
          expect(
            intentRows.values.map(jsonDecode).single,
            containsPair('op', 'listItems'),
          );
        },
      );

      test(
        'refused over a row already stored under the id: lists it',
        () async {
          // A derived id another device created first (ADR 0075).
          rows['new-item'] = itemIn('new-item', const [checklistId]);
          stubCreate(answer: false);

          final result = await add();

          expect(result?.id, 'new-item');
          expect(events, [
            'record listItems',
            'create? new-item',
            'write $checklistId',
            'clear listItems',
          ]);
          expect(listed(rows, checklistId), ['existing', 'new-item']);
          expect(intentRows, isEmpty);
        },
      );

      test(
        'refused with no row under the id: returns null and lists nothing',
        () async {
          stubCreate(answer: false);

          expect(await add(), isNull);

          expect(events, ['record listItems', 'create? new-item']);
          expect(listed(rows, checklistId), ['existing']);
          expect(intentRows.values.map(jsonDecode).single, {
            'op': 'listItems',
            'checklistId': checklistId,
            'itemIds': ['new-item'],
          });
        },
      );
    });

    // Stubs metadata/db-entity creation for the path-terminates-early error
    // cases; only the entity returned for the checklist lookup varies.
    void stubCreateItem({
      required String checklistId,
      required JournalEntity? lookedUpEntity,
    }) {
      final meta = Metadata(
        id: 'new-item-id',
        categoryId: 'category-id',
        createdAt: testDate,
        updatedAt: testDate,
        dateFrom: testDate,
        dateTo: testDate,
        starred: false,
        private: false,
        utcOffset: 0,
        vectorClock: const VectorClock({}),
      );
      when(
        () => mockPersistenceLogic.createMetadata(),
      ).thenAnswer((_) async => meta);
      when(
        () => mockPersistenceLogic.createDbEntity(any()),
      ).thenAnswer((_) async => true);
      when(
        () => mockJournalDb.journalEntityById(checklistId),
      ).thenAnswer((_) async => lookedUpEntity);
    }

    Task buildNonChecklistEntity(String id) => Task(
      meta: Metadata(
        id: id,
        categoryId: 'category-id',
        createdAt: testDate,
        updatedAt: testDate,
        dateFrom: testDate,
        dateTo: testDate,
        starred: false,
        private: false,
        utcOffset: 0,
        vectorClock: const VectorClock({}),
      ),
      data: TaskData(
        status: TaskStatus.open(
          id: 'status-1',
          createdAt: testDate,
          utcOffset: 0,
        ),
        title: 'Test Task',
        statusHistory: [],
        dateFrom: testDate,
        dateTo: testDate,
      ),
    );

    test('returns null when checklist not found', () async {
      const checklistId = 'lookup-id';
      stubCreateItem(checklistId: checklistId, lookedUpEntity: null);

      final result = await repository.addItemToChecklist(
        checklistId: checklistId,
        title: 'New Item',
        isChecked: false,
        categoryId: 'category-id',
      );

      expect(result, isNull);
      verifyNoWrite();
    });

    test('returns null and logs when entity is not a checklist', () async {
      const checklistId = 'lookup-id';
      stubCreateItem(
        checklistId: checklistId,
        lookedUpEntity: buildNonChecklistEntity(checklistId),
      );

      final result = await repository.addItemToChecklist(
        checklistId: checklistId,
        title: 'New Item',
        isChecked: false,
        categoryId: 'category-id',
      );

      expect(result, isNull);
      verifyNoWrite();
      verify(
        () => mockDomainLogger.error(
          LogDomain.persistence,
          'not a checklist',
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'updateChecklist',
        ),
      ).called(1);
    });

    test(
      'returns null and logs when the checklist lookup fails after the item '
      'was created',
      () async {
        const checklistId = 'lookup-id';
        stubCreateItem(checklistId: checklistId, lookedUpEntity: null);
        final error = StateError('journal db closed');
        when(
          () => mockJournalDb.journalEntityById(checklistId),
        ).thenAnswer((_) async => throw error);

        final result = await repository.addItemToChecklist(
          checklistId: checklistId,
          title: 'Count the krill crates',
          isChecked: false,
          categoryId: 'category-id',
        );

        expect(result, isNull);
        // The item was persisted first: this is the partial-failure path,
        // not a lookup that failed before anything was written.
        verify(() => mockPersistenceLogic.createDbEntity(any())).called(1);
        verify(
          () => mockDomainLogger.error(
            LogDomain.persistence,
            error,
            stackTrace: any(named: 'stackTrace'),
            subDomain: 'updateChecklist',
          ),
        ).called(1);
        // The checklist is never rewritten with a dangling item id.
        verifyNoWrite();
      },
    );

    test(
      'lists the new item on the checklist as stored, keeping an item that '
      'synced in while the write was refused',
      () async {
        const checklistId = 'checklist-id';
        stubCreateItem(checklistId: checklistId, lookedUpEntity: null);
        final reads = [
          checklistWith(checklistId, ['existing']),
          checklistWith(
            checklistId,
            ['existing', 'synced'],
            clock: const VectorClock({'device': 1, 'other': 1}),
          ),
        ];
        when(
          () => mockJournalDb.journalEntityById(checklistId),
        ).thenAnswer((_) async => reads.removeAt(0));
        stubUpdateMetadata();
        stubWrites([false, true]);

        final result = await repository.addItemToChecklist(
          checklistId: checklistId,
          title: 'Count the krill crates',
          isChecked: false,
          categoryId: 'category-id',
        );

        expect(result?.id, 'new-item-id');
        final attempts = capturedWrites().cast<Checklist>();
        expect(attempts.last.data.linkedChecklistItems, [
          'existing',
          'synced',
          'new-item-id',
        ]);
      },
    );

    test(
      'returns null when the checklist write is refused with the checklist '
      'unchanged',
      () async {
        const checklistId = 'checklist-id';
        stubCreateItem(
          checklistId: checklistId,
          lookedUpEntity: checklistWith(checklistId, ['existing']),
        );
        stubUpdateMetadata();
        stubWrites([false]);

        final result = await repository.addItemToChecklist(
          checklistId: checklistId,
          title: 'Count the krill crates',
          isChecked: false,
          categoryId: 'category-id',
        );

        expect(result, isNull);
        expect(capturedWrites(), hasLength(1));
      },
    );

    test(
      'records a ListItemsIntent before creating the item and clears it once '
      'the checklist lists it',
      () async {
        final rows = storeRows([
          checklistWith('checklist-id', ['existing']),
        ]);
        when(
          () => mockPersistenceLogic.createMetadata(),
        ).thenAnswer((_) async => testTask.meta.copyWith(id: 'new-item'));

        final result = await repository.addItemToChecklist(
          checklistId: 'checklist-id',
          title: 'Count the krill crates',
          isChecked: false,
          categoryId: null,
        );

        expect(result?.id, 'new-item');
        expect(events, [
          'record listItems',
          'create new-item',
          'write checklist-id',
          'clear listItems',
        ]);
        final saved = verify(
          () => mockSettingsDb.saveSettingsItem(captureAny(), captureAny()),
        ).captured;
        final key = saved.first as String;
        expect(key, startsWith(ChecklistMembershipIntents.keyPrefix));
        expect(jsonDecode(saved.last as String), {
          'op': 'listItems',
          'checklistId': 'checklist-id',
          'itemIds': ['new-item'],
        });
        verify(() => mockSettingsDb.removeSettingsItem(key)).called(1);
        expect(intentRows, isEmpty);
        expect(listed(rows, 'checklist-id'), ['existing', 'new-item']);
      },
    );

    test(
      'keeps the intent, and logs, when the app dies before it is cleared',
      () async {
        storeRows([
          checklistWith('checklist-id', ['existing']),
        ]);
        when(
          () => mockPersistenceLogic.createMetadata(),
        ).thenAnswer((_) async => testTask.meta.copyWith(id: 'new-item'));
        // The item row is written; the settings write clearing the intent
        // fails, as when the app dies there.
        when(
          () => mockSettingsDb.removeSettingsItem(any()),
        ).thenThrow(StateError('the app died'));

        final result = await repository.addItemToChecklist(
          checklistId: 'checklist-id',
          title: 'Count the krill crates',
          isChecked: false,
          categoryId: null,
        );

        expect(result, isNull);
        expect(
          intentRows.values.map(jsonDecode).single,
          containsPair('op', 'listItems'),
        );
        verify(
          () => mockDomainLogger.error(
            LogDomain.persistence,
            any(that: isA<StateError>()),
            stackTrace: any(named: 'stackTrace'),
            subDomain: 'addItemToChecklist',
          ),
        ).called(1);
      },
    );

    test(
      'keeps the ListItemsIntent when the checklist write is refused, and '
      'the next start lists the item',
      () async {
        final rows = storeRows([
          checklistWith('checklist-id', ['existing']),
        ]);
        when(
          () => mockPersistenceLogic.createMetadata(),
        ).thenAnswer((_) async => testTask.meta.copyWith(id: 'new-item'));
        refused.add('checklist-id');

        final result = await repository.addItemToChecklist(
          checklistId: 'checklist-id',
          title: 'Count the krill crates',
          isChecked: false,
          categoryId: null,
        );

        expect(result, isNull);
        expect(events, [
          'record listItems',
          'create new-item',
          'refuse checklist-id',
        ]);
        expect(intentRows.values.map(jsonDecode).single, {
          'op': 'listItems',
          'checklistId': 'checklist-id',
          'itemIds': ['new-item'],
        });
        expect(listed(rows, 'checklist-id'), ['existing']);

        refused.clear();
        await repository.replayMembershipIntents();

        expect(listed(rows, 'checklist-id'), ['existing', 'new-item']);
        expect(intentRows, isEmpty);
      },
    );

    test(
      'keeps the ListItemsIntent when the item row cannot be created, and '
      'the next start drops it without listing anything',
      () async {
        final rows = storeRows([
          checklistWith('checklist-id', ['existing']),
        ]);
        when(
          () => mockPersistenceLogic.createMetadata(),
        ).thenAnswer((_) async => testTask.meta.copyWith(id: 'new-item'));
        when(
          () => mockPersistenceLogic.createDbEntity(any()),
        ).thenThrow(StateError('disk full'));

        final result = await repository.addItemToChecklist(
          checklistId: 'checklist-id',
          title: 'Count the krill crates',
          isChecked: false,
          categoryId: null,
        );

        expect(result, isNull);
        expect(events, ['record listItems']);
        expect(
          intentRows.values.map(jsonDecode).single,
          containsPair('op', 'listItems'),
        );

        await repository.replayMembershipIntents();

        expect(events, ['record listItems', 'clear listItems']);
        expect(listed(rows, 'checklist-id'), ['existing']);
        expect(intentRows, isEmpty);
      },
    );

    test('persists the chat receipt together with the item', () async {
      final approval = makeTestChecklistApproval();
      storeRows([checklistWith('checklist-id', const [])]);
      when(
        () => mockPersistenceLogic.createMetadata(),
      ).thenAnswer((_) async => fallbackChecklistItem.meta);
      final receipt = approval.copyWith(title: 'Inspect feeder');

      final item = await repository.addItemToChecklist(
        checklistId: 'checklist-id',
        title: 'Inspect feeder',
        isChecked: true,
        categoryId: null,
        checkedAt: approval.approvedAt,
        approvalHistory: [receipt],
      );

      final written =
          verify(
                () => mockPersistenceLogic.createDbEntity(captureAny()),
              ).captured.single
              as ChecklistItem;
      expect(written.data.approvalHistory.single, receipt);
      expect(written.data.checkedStateApproval, receipt);
      // The approved title is timed by its approval, so it is protected.
      expect(written.data.titleSetAt, approval.approvedAt);
      expect(written.data.titleApproval, receipt);
      expect(written.data.linkedChecklists, ['checklist-id']);
      expect(item, written);
    });

    test('passes checkedBy and checkedAt to the created item', () async {
      final checkedAt = DateTime(2025, 6, 15);
      storeRows([checklistWith('checklist-id', const [])]);
      when(
        () => mockPersistenceLogic.createMetadata(),
      ).thenAnswer((_) async => testTask.meta.copyWith(id: 'agent-item'));

      final result = await repository.addItemToChecklist(
        checklistId: 'checklist-id',
        title: 'Agent Item',
        isChecked: false,
        categoryId: 'category-id',
        checkedBy: ChangeSource.agent,
        checkedAt: checkedAt,
      );

      final captured =
          verify(
                () => mockPersistenceLogic.createDbEntity(captureAny()),
              ).captured.single
              as ChecklistItem;
      expect(captured.data.checkedBy, ChangeSource.agent);
      expect(captured.data.checkedAt, checkedAt);
      expect(captured.meta.categoryId, 'category-id');
      expect(result, captured);
    });

    test('handles exceptions gracefully', () async {
      // Arrange
      const checklistId = 'checklist-id';
      const title = 'New Item';
      const isChecked = false;
      const categoryId = 'category-id';

      final exception = Exception('Test exception');

      when(() => mockPersistenceLogic.createMetadata()).thenThrow(exception);

      // Act
      final result = await repository.addItemToChecklist(
        checklistId: checklistId,
        title: title,
        isChecked: isChecked,
        categoryId: categoryId,
      );

      // Assert
      expect(result, isNull);
      verify(
        () => mockDomainLogger.error(
          LogDomain.persistence,
          exception,
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'addItemToChecklist',
        ),
      ).called(1);
      // Nothing was recorded or written before the item could be built.
      expect(events, isEmpty);
      verifyNever(() => mockPersistenceLogic.createDbEntity(any()));
    });
  });

  group('moveItem', () {
    Map<String, JournalEntity> twoChecklists() => storeRows([
      itemIn('item', const ['from']),
      checklistWith('from', ['item', 'stays']),
      checklistWith('to', ['already']),
    ]);

    test(
      'rewrites the back-link, then the target, then the source, under a '
      'recorded MoveItemIntent, and returns the target',
      () async {
        final rows = twoChecklists();

        final target = await repository.moveItem(
          itemId: 'item',
          fromId: 'from',
          toId: 'to',
          taskId: 'task-1',
        );

        expect(events, [
          'record moveItem',
          'write item',
          'write to',
          'write from',
          'clear moveItem',
        ]);
        expect(
          jsonDecode(
            verify(
                  () => mockSettingsDb.saveSettingsItem(any(), captureAny()),
                ).captured.single
                as String,
          ),
          {'op': 'moveItem', 'itemId': 'item', 'fromId': 'from', 'toId': 'to'},
        );
        expect((rows['item']! as ChecklistItem).data.linkedChecklists, ['to']);
        expect(listed(rows, 'to'), ['already', 'item']);
        expect(listed(rows, 'from'), ['stays']);
        expect(target, rows['to']);
        expect(intentRows, isEmpty);
        // The item's write notifies the task's listeners.
        verify(
          () => mockPersistenceLogic.updateDbEntity(
            any(that: isA<ChecklistItem>()),
            linkedId: 'task-1',
            beforeNotify: any(named: 'beforeNotify'),
            precondition: any(named: 'precondition'),
          ),
        ).called(1);
      },
    );

    test('puts the item where place says in the target', () async {
      final rows = twoChecklists();

      await repository.moveItem(
        itemId: 'item',
        fromId: 'from',
        toId: 'to',
        taskId: null,
        place: (ids) => ['item', ...ids],
      );

      expect(listed(rows, 'to'), ['item', 'already']);
    });

    test('returns null for a target that is gone, and counts the move as '
        'done: nothing is left to write there', () async {
      final rows = storeRows([
        itemIn('item', const ['from']),
        checklistWith('from', ['item']),
      ]);

      final target = await repository.moveItem(
        itemId: 'item',
        fromId: 'from',
        toId: 'gone',
        taskId: null,
      );

      expect(target, isNull);
      expect(listed(rows, 'from'), isEmpty);
      expect(events, [
        'record moveItem',
        'write item',
        'write from',
        'clear moveItem',
      ]);
      expect(intentRows, isEmpty);
    });

    test(
      'keeps the MoveItemIntent when the target write is refused, and the '
      'next start finishes the move',
      () async {
        final rows = twoChecklists();
        refused.add('to');

        final target = await repository.moveItem(
          itemId: 'item',
          fromId: 'from',
          toId: 'to',
          taskId: null,
        );

        expect(target, isNull);
        expect(events, [
          'record moveItem',
          'write item',
          'refuse to',
          'write from',
        ]);
        expect(
          intentRows.values.map(jsonDecode).single,
          containsPair('op', 'moveItem'),
        );
        expect(listed(rows, 'to'), ['already']);

        refused.clear();
        events.clear();
        await repository.replayMembershipIntents();

        expect(events, ['write to', 'clear moveItem']);
        expect((rows['item']! as ChecklistItem).data.linkedChecklists, ['to']);
        expect(listed(rows, 'to'), ['already', 'item']);
        expect(listed(rows, 'from'), ['stays']);
        expect(intentRows, isEmpty);
      },
    );

    test(
      'keeps the MoveItemIntent when the back-link write is refused',
      () async {
        final rows = twoChecklists();
        refused.add('item');

        await repository.moveItem(
          itemId: 'item',
          fromId: 'from',
          toId: 'to',
          taskId: null,
        );

        expect(
          intentRows.values.map(jsonDecode).single,
          containsPair('op', 'moveItem'),
        );
        expect(
          (rows['item']! as ChecklistItem).data.linkedChecklists,
          ['from'],
        );
      },
    );

    test(
      'a deleted item is not moved, only unlisted from the source',
      () async {
        final rows = storeRows([
          checklistWith('from', ['item', 'stays']),
          checklistWith('to', ['already']),
        ]);

        final target = await repository.moveItem(
          itemId: 'item',
          fromId: 'from',
          toId: 'to',
          taskId: null,
        );

        expect(target, isNull);
        expect(events, ['record moveItem', 'write from', 'clear moveItem']);
        expect(listed(rows, 'from'), ['stays']);
        expect(listed(rows, 'to'), ['already']);
        expect(rows.containsKey('item'), isFalse);
      },
    );

    test(
      'writes nothing, and logs, when the intent cannot be recorded',
      () async {
        final rows = twoChecklists();
        final error = StateError('settings db closed');
        when(
          () => mockSettingsDb.saveSettingsItem(any(), any()),
        ).thenThrow(error);

        final target = await repository.moveItem(
          itemId: 'item',
          fromId: 'from',
          toId: 'to',
          taskId: null,
        );

        expect(target, isNull);
        expect(events, isEmpty);
        expect(listed(rows, 'from'), ['item', 'stays']);
        verify(
          () => mockDomainLogger.error(
            LogDomain.persistence,
            error,
            stackTrace: any(named: 'stackTrace'),
            subDomain: 'moveItem',
          ),
        ).called(1);
      },
    );
  });

  group('item deletion', () {
    const undoWindow = Duration(seconds: 5);

    Map<String, JournalEntity> listedItem() => storeRows([
      itemIn('item', const ['checklist']),
      checklistWith('checklist', ['before', 'item', 'after']),
    ]);

    // Starts the deletion in fake time and returns its key once recorded.
    String? begin(FakeAsync async) {
      String? key;
      repository
          .beginItemDeletion(
            itemId: 'item',
            checklistId: 'checklist',
            undoWindow: undoWindow,
          )
          .then((recorded) => key = recorded);
      async.flushMicrotasks();
      return key;
    }

    test(
      'beginItemDeletion records a DeleteItemIntent, unlists the item at '
      'once, keeps the item row, and returns the key',
      () {
        fakeAsync((async) {
          final rows = listedItem();

          final key = begin(async);

          expect(events, ['record deleteItem', 'write checklist']);
          expect(jsonDecode(intentRows[key]!), {
            'op': 'deleteItem',
            'itemId': 'item',
            'checklistId': 'checklist',
          });
          expect(listed(rows, 'checklist'), ['before', 'after']);
          expect(rows['item']!.meta.deletedAt, isNull);
          // Nothing more happens inside the undo window.
          async.elapse(undoWindow - const Duration(milliseconds: 1));
          expect(rows['item']!.meta.deletedAt, isNull);
          expect(intentRows, hasLength(1));
        });
      },
    );

    test(
      'the item is deleted when the undo window closes, with nobody else '
      'calling anything — the row the user swiped has left the screen',
      () {
        fakeAsync((async) {
          final rows = listedItem();
          begin(async);
          events.clear();

          async.elapse(undoWindow);

          expect(events, ['delete item', 'clear deleteItem']);
          expect(rows['item']!.meta.deletedAt, isNotNull);
          expect(intentRows, isEmpty);
        });
      },
    );

    test('undoing inside the window cancels the pending delete', () {
      fakeAsync((async) {
        final rows = listedItem();
        final key = begin(async);
        async.elapse(undoWindow ~/ 2);
        events.clear();

        Checklist? checklist;
        repository
            .undoItemDeletion(
              key: key!,
              itemId: 'item',
              checklistId: 'checklist',
            )
            .then((relisted) => checklist = relisted);
        async
          ..flushMicrotasks()
          ..elapse(undoWindow * 2);

        expect(events, ['write checklist', 'clear deleteItem']);
        expect(listed(rows, 'checklist'), ['before', 'after', 'item']);
        expect(checklist, rows['checklist']);
        expect(rows['item']!.meta.deletedAt, isNull);
        expect(intentRows, isEmpty);
      });
    });

    test(
      'undoItemDeletion clears the intent even when the checklist is gone',
      () {
        fakeAsync((async) {
          final rows = listedItem();
          final key = begin(async);
          rows.remove('checklist');
          events.clear();

          Checklist? checklist;
          repository
              .undoItemDeletion(
                key: key!,
                itemId: 'item',
                checklistId: 'checklist',
              )
              .then((relisted) => checklist = relisted);
          async
            ..flushMicrotasks()
            ..elapse(undoWindow * 2);

          expect(checklist, isNull);
          expect(events, ['clear deleteItem']);
          expect(rows['item']!.meta.deletedAt, isNull);
          expect(intentRows, isEmpty);
        });
      },
    );

    test(
      'completeItemDeletion deletes the item at once, clears its intent and '
      'cancels the pending delete',
      () {
        fakeAsync((async) {
          final rows = listedItem();
          final key = begin(async);
          events.clear();

          bool? deleted;
          repository
              .completeItemDeletion(key: key!, itemId: 'item')
              .then((result) => deleted = result);
          async
            ..flushMicrotasks()
            ..elapse(undoWindow * 2);

          expect(deleted, isTrue);
          // Deleted once: the window's timer no longer fires.
          expect(events, ['delete item', 'clear deleteItem']);
          expect(rows['item']!.meta.deletedAt, isNotNull);
          expect(intentRows, isEmpty);
        });
      },
    );

    test(
      'completeItemDeletion counts an item already gone as deleted',
      () {
        fakeAsync((async) {
          final rows = listedItem();
          final key = begin(async);
          rows.remove('item');
          events.clear();

          bool? deleted;
          repository
              .completeItemDeletion(key: key!, itemId: 'item')
              .then((result) => deleted = result);
          async.flushMicrotasks();

          expect(deleted, isTrue);
          expect(events, ['clear deleteItem']);
          expect(intentRows, isEmpty);
        });
      },
    );

    test(
      'completeItemDeletion keeps the intent for the next start when the '
      'delete does not land',
      () {
        fakeAsync((async) {
          final rows = listedItem();
          final key = begin(async);
          events.clear();
          // There when completeItemDeletion looks, gone by the time the
          // delete reads it: the delete reports it did not land.
          final reads = <JournalEntity?>[rows['item'], null];
          when(
            () => mockJournalDb.journalEntityById('item'),
          ).thenAnswer((_) async => reads.removeAt(0));

          bool? deleted;
          repository
              .completeItemDeletion(key: key!, itemId: 'item')
              .then((result) => deleted = result);
          async.flushMicrotasks();

          expect(deleted, isFalse);
          expect(events, isEmpty);
          expect(intentRows.keys, [key]);
        });
      },
    );

    test(
      'beginItemDeletion unlists nothing, and logs, when the intent cannot '
      'be recorded',
      () {
        fakeAsync((async) {
          final rows = listedItem();
          final error = StateError('settings db closed');
          when(
            () => mockSettingsDb.saveSettingsItem(any(), any()),
          ).thenThrow(error);

          final key = begin(async);
          async.elapse(undoWindow * 2);

          expect(key, isNull);
          expect(listed(rows, 'checklist'), ['before', 'item', 'after']);
          expect(rows['item']!.meta.deletedAt, isNull);
          verify(
            () => mockDomainLogger.error(
              LogDomain.persistence,
              error,
              stackTrace: any(named: 'stackTrace'),
              subDomain: 'beginItemDeletion',
            ),
          ).called(1);
        });
      },
    );
  });

  group('deleteChecklist', () {
    test(
      'deletes the checklist, then removes it from the task, under a '
      'recorded DeleteChecklistIntent',
      () async {
        final rows = storeRows([
          taskWith(const ['first', 'doomed']),
          checklistWith('doomed', const []),
        ]);

        final deleted = await repository.deleteChecklist(
          checklistId: 'doomed',
          taskId: testTask.id,
        );

        expect(deleted, isTrue);
        expect(events, [
          'record deleteChecklist',
          'delete doomed',
          'write ${testTask.id}',
          'clear deleteChecklist',
        ]);
        expect(
          jsonDecode(
            verify(
                  () => mockSettingsDb.saveSettingsItem(any(), captureAny()),
                ).captured.single
                as String,
          ),
          {
            'op': 'deleteChecklist',
            'checklistId': 'doomed',
            'taskId': testTask.id,
          },
        );
        expect((rows[testTask.id]! as Task).data.checklistIds, ['first']);
      },
    );

    test(
      'still removes a checklist that is already gone from the task',
      () async {
        final rows = storeRows([
          taskWith(const ['first', 'gone']),
        ]);

        final deleted = await repository.deleteChecklist(
          checklistId: 'gone',
          taskId: testTask.id,
        );

        expect(deleted, isTrue);
        expect(events, [
          'record deleteChecklist',
          'write ${testTask.id}',
          'clear deleteChecklist',
        ]);
        expect((rows[testTask.id]! as Task).data.checklistIds, ['first']);
      },
    );

    test(
      'logs, still reports the deletion, and keeps the intent for the next '
      'start when the task write is refused',
      () async {
        final rows = storeRows([
          taskWith(const ['first', 'doomed']),
          checklistWith('doomed', const []),
        ]);
        refused.add(testTask.id);

        final deleted = await repository.deleteChecklist(
          checklistId: 'doomed',
          taskId: testTask.id,
        );

        expect(deleted, isTrue);
        expect(rows['doomed']!.meta.deletedAt, isNotNull);
        verify(
          () => mockDomainLogger.error(
            LogDomain.tasks,
            'Failed to remove checklist ID (doomed) from task '
            '(${testTask.id})',
            stackTrace: any(named: 'stackTrace'),
            subDomain: 'deleteChecklist',
          ),
        ).called(1);
        expect(
          intentRows.values.map(jsonDecode).single,
          containsPair('op', 'deleteChecklist'),
        );

        refused.clear();
        await repository.replayMembershipIntents();

        expect((rows[testTask.id]! as Task).data.checklistIds, ['first']);
        expect(intentRows, isEmpty);
      },
    );

    test(
      'a task that is gone counts as detached: the intent is cleared and '
      'nothing is logged',
      () async {
        final rows = storeRows([checklistWith('doomed', const [])]);

        final deleted = await repository.deleteChecklist(
          checklistId: 'doomed',
          taskId: 'missing-task',
        );

        expect(deleted, isTrue);
        expect(rows['doomed']!.meta.deletedAt, isNotNull);
        expect(events, [
          'record deleteChecklist',
          'delete doomed',
          'clear deleteChecklist',
        ]);
        expect(intentRows, isEmpty);
        verifyNever(
          () => mockDomainLogger.error(
            any<LogDomain>(),
            any(),
            stackTrace: any(named: 'stackTrace'),
            subDomain: any(named: 'subDomain'),
          ),
        );
      },
    );

    test(
      'returns false and leaves the task alone when the checklist cannot be '
      'deleted',
      () async {
        final rows = storeRows([
          taskWith(const ['first', 'doomed']),
        ]);
        // The checklist is there when deleteChecklist looks, and gone by the
        // time the delete reads it.
        final reads = <JournalEntity?>[checklistWith('doomed', const []), null];
        when(
          () => mockJournalDb.journalEntityById('doomed'),
        ).thenAnswer((_) async => reads.removeAt(0));

        final deleted = await repository.deleteChecklist(
          checklistId: 'doomed',
          taskId: testTask.id,
        );

        expect(deleted, isFalse);
        expect((rows[testTask.id]! as Task).data.checklistIds, [
          'first',
          'doomed',
        ]);
        expect(
          intentRows.values.map(jsonDecode).single,
          containsPair('op', 'deleteChecklist'),
        );
      },
    );
  });

  group('replayMembershipIntents', () {
    test(
      'ListItemsIntent: lists every created item, skips one never created, '
      'and clears the intent',
      () async {
        final rows = storeRows([
          checklistWith('checklist', ['old']),
          itemIn('created', const ['checklist']),
        ]);
        seedIntent(
          const ListItemsIntent(
            checklistId: 'checklist',
            itemIds: ['created', 'never-created'],
          ),
        );

        await repository.replayMembershipIntents();

        expect(listed(rows, 'checklist'), ['old', 'created']);
        expect(intentRows, isEmpty);
      },
    );

    test(
      'ListItemsIntent with no item created writes nothing',
      () async {
        storeRows([
          checklistWith('checklist', ['old']),
        ]);
        seedIntent(
          const ListItemsIntent(checklistId: 'checklist', itemIds: ['never']),
        );

        await repository.replayMembershipIntents();

        expect(events, ['clear listItems']);
      },
    );

    test(
      'MoveItemIntent: finishes a move the app died in the middle of',
      () async {
        // The back-link was rewritten; neither list was.
        final rows = storeRows([
          itemIn('item', const ['to']),
          checklistWith('from', ['item']),
          checklistWith('to', ['other']),
        ]);
        seedIntent(
          const MoveItemIntent(itemId: 'item', fromId: 'from', toId: 'to'),
        );

        await repository.replayMembershipIntents();

        expect((rows['item']! as ChecklistItem).data.linkedChecklists, ['to']);
        expect(listed(rows, 'to'), ['other', 'item']);
        expect(listed(rows, 'from'), isEmpty);
        expect(intentRows, isEmpty);
      },
    );

    test(
      'MoveItemIntent of an item that is gone only unlists it from the '
      'source',
      () async {
        final rows = storeRows([
          checklistWith('from', ['item']),
          checklistWith('to', const []),
        ]);
        seedIntent(
          const MoveItemIntent(itemId: 'item', fromId: 'from', toId: 'to'),
        );

        await repository.replayMembershipIntents();

        expect(events, ['write from', 'clear moveItem']);
        expect(listed(rows, 'from'), isEmpty);
        expect(listed(rows, 'to'), isEmpty);
      },
    );

    test(
      'an intent whose replayed write is refused stays for the next start',
      () async {
        final rows = storeRows([
          taskWith(const ['first']),
          checklistWith('created', const []),
          itemIn('item', const ['checklist']),
          checklistWith('checklist', ['item']),
        ]);
        refused.addAll([testTask.id, 'checklist']);
        final keys = [
          seedIntent(
            ListChecklistIntent(checklistId: 'created', taskId: testTask.id),
            '-1',
          ),
          seedIntent(
            const DeleteItemIntent(itemId: 'item', checklistId: 'checklist'),
            '-2',
          ),
        ];

        await repository.replayMembershipIntents();

        expect(intentRows.keys, keys);
        // The item is not deleted while it is still listed.
        expect(rows['item']!.meta.deletedAt, isNull);

        refused.clear();
        await repository.replayMembershipIntents();

        expect(intentRows, isEmpty);
        expect((rows[testTask.id]! as Task).data.checklistIds, [
          'first',
          'created',
        ]);
        expect(listed(rows, 'checklist'), isEmpty);
        expect(rows['item']!.meta.deletedAt, isNotNull);
      },
    );

    test(
      'DeleteItemIntent: unlists and deletes an item whose undo window the '
      'app died in',
      () async {
        final rows = storeRows([
          itemIn('item', const ['checklist']),
          checklistWith('checklist', ['item', 'kept']),
        ]);
        seedIntent(
          const DeleteItemIntent(itemId: 'item', checklistId: 'checklist'),
        );

        await repository.replayMembershipIntents();

        expect(listed(rows, 'checklist'), ['kept']);
        expect(rows['item']!.meta.deletedAt, isNotNull);
        expect(intentRows, isEmpty);
      },
    );

    test(
      'DeleteItemIntent of an item already deleted only unlists it',
      () async {
        final rows = storeRows([
          checklistWith('checklist', ['item', 'kept']),
        ]);
        seedIntent(
          const DeleteItemIntent(itemId: 'item', checklistId: 'checklist'),
        );

        await repository.replayMembershipIntents();

        expect(events, ['write checklist', 'clear deleteItem']);
        expect(listed(rows, 'checklist'), ['kept']);
      },
    );

    test(
      'ListChecklistIntent: lists a created checklist on the task',
      () async {
        final rows = storeRows([
          taskWith(const ['first']),
          checklistWith('created', const []),
        ]);
        seedIntent(
          ListChecklistIntent(checklistId: 'created', taskId: testTask.id),
        );

        await repository.replayMembershipIntents();

        expect((rows[testTask.id]! as Task).data.checklistIds, [
          'first',
          'created',
        ]);
        expect(intentRows, isEmpty);
      },
    );

    test(
      'ListChecklistIntent of a checklist never created writes nothing',
      () async {
        storeRows([
          taskWith(const ['first']),
        ]);
        seedIntent(
          ListChecklistIntent(checklistId: 'never', taskId: testTask.id),
        );

        await repository.replayMembershipIntents();

        expect(events, ['clear listChecklist']);
      },
    );

    test(
      'DeleteChecklistIntent: deletes the checklist and removes it from the '
      'task',
      () async {
        final rows = storeRows([
          taskWith(const ['first', 'doomed']),
          checklistWith('doomed', const []),
        ]);
        seedIntent(
          DeleteChecklistIntent(checklistId: 'doomed', taskId: testTask.id),
        );

        await repository.replayMembershipIntents();

        expect(rows['doomed']!.meta.deletedAt, isNotNull);
        expect((rows[testTask.id]! as Task).data.checklistIds, ['first']);
        expect(intentRows, isEmpty);
      },
    );

    test('an intent this build cannot read is dropped untouched', () async {
      storeRows(const []);
      intentRows['${ChecklistMembershipIntents.keyPrefix}unreadable'] =
          '{"op":"renameItem"}';

      await repository.replayMembershipIntents();

      expect(intentRows, isEmpty);
      expect(events, ['clear renameItem']);
      verifyNoWrite();
    });

    test(
      'a replay that throws keeps its intent for the next start, logs, and '
      'the others still replay',
      () async {
        final rows = storeRows([
          taskWith(const ['first']),
          checklistWith('created', const []),
        ]);
        final error = StateError('journal db closed');
        when(() => mockJournalDb.journalEntityById('boom')).thenThrow(error);
        final kept = seedIntent(
          const ListItemsIntent(checklistId: 'created', itemIds: ['boom']),
          '-1',
        );
        seedIntent(
          ListChecklistIntent(checklistId: 'created', taskId: testTask.id),
          '-2',
        );

        await repository.replayMembershipIntents();

        expect(intentRows.keys, [kept]);
        expect((rows[testTask.id]! as Task).data.checklistIds, [
          'first',
          'created',
        ]);
        verify(
          () => mockDomainLogger.error(
            LogDomain.persistence,
            error,
            stackTrace: any(named: 'stackTrace'),
            subDomain: 'replayMembershipIntents',
          ),
        ).called(1);
      },
    );
  });

  group('getChecklistItemsForTask', () {
    // Verifies the post-558ms-slow-query rewrite: the function used to
    // scan every ChecklistItem in the journal and filter in Dart. The
    // new shape issues two indexed bulk-by-id lookups: first the
    // parent Checklists, then their `linkedChecklistItems` ids.
    final taskMeta = Metadata(
      id: 'task-1',
      createdAt: testDate,
      updatedAt: testDate,
      dateFrom: testDate,
      dateTo: testDate,
    );

    Task buildTaskWithChecklists(List<String> checklistIds) => Task(
      meta: taskMeta,
      data: TaskData(
        status: TaskStatus.open(
          id: 'status-1',
          createdAt: testDate,
          utcOffset: 0,
        ),
        title: 'Task',
        statusHistory: const [],
        dateFrom: testDate,
        dateTo: testDate,
        checklistIds: checklistIds,
      ),
    );

    Checklist buildChecklist(String id, List<String> linkedItemIds) =>
        Checklist(
          meta: Metadata(
            id: id,
            createdAt: testDate,
            updatedAt: testDate,
            dateFrom: testDate,
            dateTo: testDate,
          ),
          data: ChecklistData(
            title: 'cl-$id',
            linkedChecklistItems: linkedItemIds,
            linkedTasks: const [],
          ),
        );

    ChecklistItem buildItem({
      required String id,
      required DateTime dateFrom,
      DateTime? deletedAt,
      List<String> linkedChecklists = const ['checklist-1'],
    }) {
      return ChecklistItem(
        meta: Metadata(
          id: id,
          createdAt: testDate,
          updatedAt: testDate,
          dateFrom: dateFrom,
          dateTo: dateFrom,
          deletedAt: deletedAt,
        ),
        data: ChecklistItemData(
          title: 'item-$id',
          isChecked: false,
          linkedChecklists: linkedChecklists,
        ),
      );
    }

    void stubByIds(Map<String, JournalEntity> byId) {
      when(
        () => mockJournalDb.journalEntitiesByIdsUnorderedAllPrivate(any()),
      ).thenAnswer((invocation) {
        final ids = invocation.positionalArguments.first as List<String>;
        final rows = ids
            .map((id) => byId[id])
            .whereType<JournalEntity>()
            .map(toDbEntity)
            .toList();
        return MockSelectable<JournalDbEntity>(rows);
      });
    }

    test('returns empty list when the task has no checklist ids', () async {
      final task = buildTaskWithChecklists(const []);

      final result = await repository.getChecklistItemsForTask(task: task);

      expect(result, isEmpty);
      verifyNever(
        () => mockJournalDb.journalEntitiesByIdsUnorderedAllPrivate(any()),
      );
    });

    test(
      'fetches parent checklists then their items via two bulk lookups, '
      'filtering soft-deleted items and sorting by dateFrom desc',
      () async {
        final checklist = buildChecklist('checklist-1', [
          'item-old',
          'item-new',
          'item-deleted',
        ]);
        final newer = buildItem(
          id: 'item-new',
          dateFrom: DateTime(2024, 6, 15),
        );
        final older = buildItem(
          id: 'item-old',
          dateFrom: DateTime(2024, 1, 15),
        );
        final deleted = buildItem(
          id: 'item-deleted',
          dateFrom: DateTime(2024, 5, 15),
          deletedAt: DateTime(2024, 5, 16),
        );
        stubByIds({
          'checklist-1': checklist,
          'item-new': newer,
          'item-old': older,
          'item-deleted': deleted,
        });

        final task = buildTaskWithChecklists(const ['checklist-1']);
        final result = await repository.getChecklistItemsForTask(task: task);

        expect(result.map((i) => i.meta.id), ['item-new', 'item-old']);
        // Two indexed bulk-by-id lookups (parent checklists, then
        // their items) — the prior shape did one global type-scan.
        verify(
          () => mockJournalDb.journalEntitiesByIdsUnorderedAllPrivate(any()),
        ).called(2);
      },
    );

    test(
      'returns empty list when none of the parent checklists are found',
      () async {
        stubByIds(const <String, JournalEntity>{});
        final task = buildTaskWithChecklists(const ['missing-checklist']);

        final result = await repository.getChecklistItemsForTask(task: task);

        expect(result, isEmpty);
        // Only the parent checklists were looked up — without item
        // ids to fetch, the second bulk read is skipped.
        verify(
          () => mockJournalDb.journalEntitiesByIdsUnorderedAllPrivate(any()),
        ).called(1);
      },
    );

    test(
      'logs and skips a parent checklist row whose serialized JSON is '
      'malformed instead of propagating the throw — a corrupt persisted '
      'row should not poison the entire fetch',
      () async {
        final corruptRow = JournalDbEntity(
          id: 'checklist-corrupt',
          createdAt: testDate,
          updatedAt: testDate,
          dateFrom: testDate,
          dateTo: testDate,
          deleted: false,
          starred: false,
          private: false,
          task: false,
          flag: 0,
          type: 'Checklist',
          serialized: 'this is not json',
          schemaVersion: 0,
          category: '',
        );
        when(
          () => mockJournalDb.journalEntitiesByIdsUnorderedAllPrivate(any()),
        ).thenAnswer((_) {
          return MockSelectable<JournalDbEntity>([corruptRow]);
        });

        final task = buildTaskWithChecklists(const ['checklist-corrupt']);
        final result = await repository.getChecklistItemsForTask(task: task);

        expect(result, isEmpty);
        verify(
          () => mockDomainLogger.error(
            any<LogDomain>(),
            any(),
            stackTrace: any(named: 'stackTrace'),
            subDomain: 'getChecklistItemsForTask',
          ),
        ).called(1);
        // No items recovered means the second bulk read is skipped.
        verify(
          () => mockJournalDb.journalEntitiesByIdsUnorderedAllPrivate(any()),
        ).called(1);
      },
    );

    test(
      'logs and skips a corrupt ITEM row from the second bulk read while '
      'still returning the intact items',
      () async {
        final checklist = buildChecklist('cl-1', const [
          'item-good',
          'item-corrupt',
        ]);
        final goodItem = ChecklistItem(
          meta: Metadata(
            id: 'item-good',
            createdAt: testDate,
            updatedAt: testDate,
            dateFrom: testDate,
            dateTo: testDate,
          ),
          data: const ChecklistItemData(
            title: 'Good item',
            isChecked: false,
            linkedChecklists: ['cl-1'],
          ),
        );
        final corruptItemRow = JournalDbEntity(
          id: 'item-corrupt',
          createdAt: testDate,
          updatedAt: testDate,
          dateFrom: testDate,
          dateTo: testDate,
          deleted: false,
          starred: false,
          private: false,
          task: false,
          flag: 0,
          type: 'ChecklistItem',
          serialized: '{not valid json either',
          schemaVersion: 0,
          category: '',
        );

        when(
          () => mockJournalDb.journalEntitiesByIdsUnorderedAllPrivate(any()),
        ).thenAnswer((invocation) {
          final ids = invocation.positionalArguments.first as List<String>;
          if (ids.contains('cl-1')) {
            return MockSelectable<JournalDbEntity>([toDbEntity(checklist)]);
          }
          return MockSelectable<JournalDbEntity>([
            toDbEntity(goodItem),
            corruptItemRow,
          ]);
        });

        final task = buildTaskWithChecklists(const ['cl-1']);
        final result = await repository.getChecklistItemsForTask(task: task);

        // The corrupt row is skipped and logged; the intact item survives.
        expect(result.map((i) => i.meta.id), ['item-good']);
        verify(
          () => mockDomainLogger.error(
            any<LogDomain>(),
            any(),
            stackTrace: any(named: 'stackTrace'),
            subDomain: 'getChecklistItemsForTask',
          ),
        ).called(1);
      },
    );
  });

  _registerChecklistMembershipConformance();
}
