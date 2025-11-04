import 'package:flutter_test/flutter_test.dart';
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
          title: 'f',
        ),
      ),
    );
  });
  group('LabelsRepository suppression', () {
    late LabelsRepository repo;
    late MockJournalDb mockDb;
    late MockPersistenceLogic mockPl;
    late MockEntitiesCacheService mockCache;
    late MockLoggingService mockLog;

    setUp(() {
      mockDb = MockJournalDb();
      mockPl = MockPersistenceLogic();
      mockCache = MockEntitiesCacheService();
      mockLog = MockLoggingService();
      repo = LabelsRepository(
        mockPl,
        mockDb,
        mockCache,
        mockLog,
      );
    });

    test('removeLabel adds to aiSuppressedLabelIds; addLabels unsuppresses',
        () async {
      // Arrange: a task with one assigned label 'a'
      final task = Task(
        meta: Metadata(
          id: 't1',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
          labelIds: ['a'],
        ),
        data: TaskData(
          status: TaskStatus.open(
            id: 's',
            createdAt: DateTime.now(),
            utcOffset: 0,
          ),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
          statusHistory: [],
          title: 'x',
        ),
      );
      JournalEntity current = task;
      when(() => mockDb.journalEntityById('t1'))
          .thenAnswer((_) async => current);
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
              linkedId: any(named: 'linkedId'),
              enqueueSync: any(named: 'enqueueSync'),
              overrideComparison: any(named: 'overrideComparison')))
          .thenAnswer((inv) async {
        current = inv.positionalArguments.first as JournalEntity;
        return true;
      });

      // Act: remove 'a'
      await repo.removeLabel(journalEntityId: 't1', labelId: 'a');
      final afterRemove = current as Task;

      // Assert: suppression contains 'a'
      expect(afterRemove.data.aiSuppressedLabelIds, contains('a'));

      // Act: add 'a' back manually
      await repo.addLabels(journalEntityId: 't1', addedLabelIds: ['a']);
      final afterAdd = current as Task;

      // Assert: suppression no longer contains 'a'
      expect(
          afterAdd.data.aiSuppressedLabelIds?.contains('a') ?? false, isFalse);
    });
  });
}
