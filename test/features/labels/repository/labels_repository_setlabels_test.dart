import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

class MockJournalDb extends Mock implements JournalDb {}

class MockPersistenceLogic extends Mock implements PersistenceLogic {}

class MockEntitiesCacheService extends Mock implements EntitiesCacheService {}

class MockLoggingService extends Mock implements LoggingService {}

void main() {
  group('LabelsRepository.setLabels suppression updates', () {
    late LabelsRepository repo;
    late MockJournalDb mockDb;
    late MockPersistenceLogic mockPl;
    late MockEntitiesCacheService mockCache;
    late MockLoggingService mockLog;

    setUpAll(() {
      registerFallbackValue(
        Metadata(
          id: 'm',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          dateFrom: DateTime(2024),
          dateTo: DateTime(2024),
        ),
      );
      registerFallbackValue(
        Task(
          meta: Metadata(
            id: 'f',
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024),
            dateFrom: DateTime(2024),
            dateTo: DateTime(2024),
          ),
          data: TaskData(
            status: TaskStatus.open(
              id: 's',
              createdAt: DateTime(2024),
              utcOffset: 0,
            ),
            dateFrom: DateTime(2024),
            dateTo: DateTime(2024),
            statusHistory: const [],
            title: 't',
          ),
        ),
      );
    });

    setUp(() {
      mockDb = MockJournalDb();
      mockPl = MockPersistenceLogic();
      mockCache = MockEntitiesCacheService();
      mockLog = MockLoggingService();
      repo = LabelsRepository(mockPl, mockDb, mockCache, mockLog);
    });

    LabelDefinition def(String id) => LabelDefinition(
          id: id,
          name: id,
          color: '#000',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          vectorClock: null,
          private: false,
        );

    test('removed labels are added to suppression; added are unsuppressed',
        () async {
      // Task has a,b,c assigned; suppression already has x
      var current = Task(
        meta: Metadata(
          id: 't1',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
          labelIds: const ['a', 'b', 'c'],
        ),
        data: TaskData(
          status: TaskStatus.open(
            id: 's',
            createdAt: DateTime.now(),
            utcOffset: 0,
          ),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
          statusHistory: const [],
          title: 't',
          aiSuppressedLabelIds: const {'x'},
        ),
      );

      when(() => mockDb.journalEntityById('t1'))
          .thenAnswer((_) async => current);
      // Resolve labels via cache for speed
      when(() => mockCache.getLabelById(any())).thenReturn(def('a'));
      when(() => mockDb.getLabelDefinitionById(any()))
          .thenAnswer((_) async => def('a'));
      when(() => mockPl.updateMetadata(
            any(),
            dateFrom: any(named: 'dateFrom'),
            dateTo: any(named: 'dateTo'),
            categoryId: any(named: 'categoryId'),
            clearCategoryId: any(named: 'clearCategoryId'),
            deletedAt: any(named: 'deletedAt'),
            labelIds: any<List<String>?>(named: 'labelIds'),
            clearLabelIds: any<bool>(named: 'clearLabelIds'),
          ))
          .thenAnswer((inv) async => inv.positionalArguments.first as Metadata);
      when(() => mockPl.updateDbEntity(any(),
              linkedId: any<String?>(named: 'linkedId'),
              enqueueSync: any<bool>(named: 'enqueueSync'),
              overrideComparison: any<bool>(named: 'overrideComparison')))
          .thenAnswer((inv) async {
        current = inv.positionalArguments.first as Task;
        return true;
      });

      // New set removes b and adds none
      await repo.setLabels(journalEntityId: 't1', labelIds: const ['a', 'c']);

      // Suppression should be {'x','b'}
      expect(current.data.aiSuppressedLabelIds, containsAll({'x', 'b'}));

      // Now unsuppress by adding b back
      when(() => mockDb.journalEntityById('t1'))
          .thenAnswer((_) async => current);
      await repo
          .setLabels(journalEntityId: 't1', labelIds: const ['a', 'b', 'c']);
      expect(
          current.data.aiSuppressedLabelIds?.contains('b') ?? false, isFalse);
    });

    test('add/remove suppressed helpers work and ignore assigned labels on add',
        () async {
      var current = Task(
        meta: Metadata(
          id: 't2',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
          labelIds: const ['a'],
        ),
        data: TaskData(
          status: TaskStatus.open(
            id: 's',
            createdAt: DateTime.now(),
            utcOffset: 0,
          ),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
          statusHistory: const [],
          title: 't',
          aiSuppressedLabelIds: const {'x'},
        ),
      );
      when(() => mockDb.journalEntityById('t2'))
          .thenAnswer((_) async => current);
      when(() => mockPl.updateMetadata(any(),
              dateFrom: any(named: 'dateFrom'),
              dateTo: any(named: 'dateTo'),
              categoryId: any(named: 'categoryId'),
              clearCategoryId: any(named: 'clearCategoryId'),
              deletedAt: any(named: 'deletedAt'),
              labelIds: any<List<String>?>(named: 'labelIds'),
              clearLabelIds: any<bool>(named: 'clearLabelIds')))
          .thenAnswer((inv) async => inv.positionalArguments.first as Metadata);
      when(() => mockPl.updateDbEntity(any(),
              linkedId: any<String?>(named: 'linkedId'),
              enqueueSync: any<bool>(named: 'enqueueSync'),
              overrideComparison: any<bool>(named: 'overrideComparison')))
          .thenAnswer((inv) async {
        current = inv.positionalArguments.first as Task;
        return true;
      });

      // Add suppressed {'a','z'}; 'a' is assigned so should not remain suppressed
      await repo.addSuppressedLabels(
        journalEntityId: 't2',
        labelIds: const {'a', 'z'},
      );
      expect(current.data.aiSuppressedLabelIds, contains('z'));
      expect(current.data.aiSuppressedLabelIds, isNot(contains('a')));

      // Remove 'z'
      await repo.removeSuppressedLabels(
        journalEntityId: 't2',
        labelIds: const {'z'},
      );
      expect(current.data.aiSuppressedLabelIds?.contains('z') ?? false, isFalse);
    });

    test('addSuppressedLabels returns early on empty set', () async {
      final current = Task(
        meta: Metadata(
          id: 't3',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
        ),
        data: TaskData(
          status: TaskStatus.open(
            id: 's',
            createdAt: DateTime.now(),
            utcOffset: 0,
          ),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
          statusHistory: const [],
          title: 't',
        ),
      );
      when(() => mockDb.journalEntityById('t3'))
          .thenAnswer((_) async => current);
      // Should not call updateDbEntity when empty
      final res =
          await repo.addSuppressedLabels(journalEntityId: 't3', labelIds: {});
      expect(res, isTrue);
      verifyNever(() => mockPl.updateDbEntity(any(),
          linkedId: any<String?>(named: 'linkedId'),
          enqueueSync: any<bool>(named: 'enqueueSync'),
          overrideComparison: any<bool>(named: 'overrideComparison')));
    });

    test('removeSuppressedLabels returns early on empty set', () async {
      final res = await repo.removeSuppressedLabels(
        journalEntityId: 't3',
        labelIds: const {},
      );
      expect(res, isTrue);
    });

    test('non-Task entities do not touch suppression for add/remove/set', () async {
      final img = JournalImage(
        meta: Metadata(
          id: 'img1',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
        ),
        data: ImageData(
          capturedAt: DateTime.now(),
          imageId: 'i',
          imageFile: 'f',
          imageDirectory: 'd',
        ),
      );
      when(() => mockDb.journalEntityById('img1')).thenAnswer((_) async => img);
      when(() => mockPl.updateMetadata(any(),
              dateFrom: any(named: 'dateFrom'),
              dateTo: any(named: 'dateTo'),
              categoryId: any(named: 'categoryId'),
              clearCategoryId: any(named: 'clearCategoryId'),
              deletedAt: any(named: 'deletedAt'),
              labelIds: any<List<String>?>(named: 'labelIds'),
              clearLabelIds: any<bool>(named: 'clearLabelIds')))
          .thenAnswer((inv) async => inv.positionalArguments.first as Metadata);
      when(() => mockPl.updateDbEntity(any(),
              linkedId: any<String?>(named: 'linkedId'),
              enqueueSync: any<bool>(named: 'enqueueSync'),
              overrideComparison: any<bool>(named: 'overrideComparison')))
          .thenAnswer((_) async => true);
      // Also handle calls without named args
      when(() => mockPl.updateDbEntity(any())).thenAnswer((_) async => true);

      // addLabels/removeLabel/setLabels: all should call updateDbEntity without named args
      await repo.addLabels(journalEntityId: 'img1', addedLabelIds: ['a']);
      await repo.removeLabel(journalEntityId: 'img1', labelId: 'a');
      await repo.setLabels(journalEntityId: 'img1', labelIds: const ['a']);
      verify(() => mockPl.updateDbEntity(any())).called(2);
    });

    test('error handling returns false and logs', () async {
      when(() => mockDb.journalEntityById('bad')).thenThrow(Exception('db'));
      when(() => mockLog.captureException(any<dynamic>(),
              domain: any<String>(named: 'domain'),
              subDomain: any<String>(named: 'subDomain'),
              stackTrace: any<StackTrace?>(named: 'stackTrace')))
          .thenReturn(null);

      expect(
          await repo.addLabels(journalEntityId: 'bad', addedLabelIds: ['x']),
          isFalse);
      expect(
          await repo.removeLabel(journalEntityId: 'bad', labelId: 'x'), isFalse);
      expect(await repo.setLabels(journalEntityId: 'bad', labelIds: const []),
          isFalse);

      verify(() => mockLog.captureException(any<dynamic>(),
              domain: 'labels_repository',
              subDomain: any<String>(named: 'subDomain'),
              stackTrace: any<StackTrace?>(named: 'stackTrace')))
          .called(greaterThanOrEqualTo(1));
    });

    test('setLabels retries with overrideComparison when first update fails',
        () async {
      final current = Task(
        meta: Metadata(
          id: 't4',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
        ),
        data: TaskData(
          status: TaskStatus.open(
            id: 's',
            createdAt: DateTime.now(),
            utcOffset: 0,
          ),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
          statusHistory: const [],
          title: 't',
        ),
      );
      when(() => mockDb.journalEntityById('t4'))
          .thenAnswer((_) async => current);
      when(() => mockCache.getLabelById(any())).thenReturn(def('a'));
      when(() => mockPl.updateMetadata(any(),
              dateFrom: any(named: 'dateFrom'),
              dateTo: any(named: 'dateTo'),
              categoryId: any(named: 'categoryId'),
              clearCategoryId: any(named: 'clearCategoryId'),
              deletedAt: any(named: 'deletedAt'),
              labelIds: any<List<String>?>(named: 'labelIds'),
              clearLabelIds: any<bool>(named: 'clearLabelIds')))
          .thenAnswer((inv) async => inv.positionalArguments.first as Metadata);

      // First attempt without override -> false to trigger fallback
      when(() => mockPl.updateDbEntity(any())).thenAnswer((_) async => false);
      // Fallback attempt with override -> true (cover both signature variants)
      var overrideCallCount = 0;
      when(() => mockPl.updateDbEntity(
            any(),
            overrideComparison: any(named: 'overrideComparison'),
          )).thenAnswer((inv) async {
        overrideCallCount++;
        final override = inv.namedArguments[#overrideComparison] as bool?;
        return override == true;
      });
      when(() => mockPl.updateDbEntity(
            any(),
            linkedId: any(named: 'linkedId'),
            enqueueSync: any(named: 'enqueueSync'),
            overrideComparison: any(named: 'overrideComparison'),
          )).thenAnswer((inv) async {
        overrideCallCount++;
        final override = inv.namedArguments[#overrideComparison] as bool?;
        return override == true;
      });

      final result = await repo.setLabels(
        journalEntityId: 't4',
        labelIds: const ['a'],
      );

      // Verify fallback with override was attempted at least once
      expect(overrideCallCount, greaterThanOrEqualTo(1));
    });
  });
}
