import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  setUpAll(() {
    registerAllFallbackValues();
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
    late MockDomainLogger mockDomainLogger;

    late MockUpdateNotifications mockNotifications;

    setUp(() {
      mockDb = MockJournalDb();
      mockPl = MockPersistenceLogic();
      mockCache = MockEntitiesCacheService();
      mockDomainLogger = MockDomainLogger();
      mockNotifications = MockUpdateNotifications();
      repo = LabelsRepository(
        mockPl,
        mockDb,
        mockCache,
        mockDomainLogger,
        mockNotifications,
      );
    });

    test(
      'setLabels suppresses removals and unsuppresses additions',
      () async {
        // Arrange: a task with one assigned label 'a'
        final task = Task(
          meta: Metadata(
            id: 't1',
            createdAt: DateTime(2024, 3, 15, 10, 30),
            updatedAt: DateTime(2024, 3, 15, 10, 30),
            dateFrom: DateTime(2024, 3, 15, 10, 30),
            dateTo: DateTime(2024, 3, 15, 10, 30),
            labelIds: ['a'],
          ),
          data: TaskData(
            status: TaskStatus.open(
              id: 's',
              createdAt: DateTime(2024, 3, 15, 10, 30),
              utcOffset: 0,
            ),
            dateFrom: DateTime(2024, 3, 15, 10, 30),
            dateTo: DateTime(2024, 3, 15, 10, 30),
            statusHistory: [],
            title: 'x',
          ),
        );
        JournalEntity current = task;
        when(
          () => mockDb.journalEntityById('t1'),
        ).thenAnswer((_) async => current);
        when(
          () => mockPl.updateMetadata(
            any(),
            dateFrom: any(named: 'dateFrom'),
            dateTo: any(named: 'dateTo'),
            categoryId: any(named: 'categoryId'),
            clearCategoryId: any(named: 'clearCategoryId'),
            deletedAt: any(named: 'deletedAt'),
            labelIds: any<List<String>?>(named: 'labelIds'),
            clearLabelIds: any<bool>(named: 'clearLabelIds'),
          ),
        ).thenAnswer((inv) async => inv.positionalArguments.first as Metadata);
        when(
          () => mockPl.updateDbEntity(
            any(),
            linkedId: any(named: 'linkedId'),
            enqueueSync: any(named: 'enqueueSync'),
            overrideComparison: any(named: 'overrideComparison'),
          ),
        ).thenAnswer((inv) async {
          current = inv.positionalArguments.first as JournalEntity;
          return true;
        });
        when(() => mockCache.getLabelById('a')).thenReturn(
          LabelDefinition(
            id: 'a',
            name: 'Alpha',
            color: '#000000',
            createdAt: DateTime(2024, 3, 15, 10, 30),
            updatedAt: DateTime(2024, 3, 15, 10, 30),
            vectorClock: const VectorClock(<String, int>{}),
          ),
        );

        // Act: remove 'a'
        await repo.setLabels(journalEntityId: 't1', labelIds: const []);
        final afterRemove = current as Task;

        // Assert: suppression contains 'a'
        expect(afterRemove.data.aiSuppressedLabelIds, contains('a'));

        // Act: add 'a' back manually
        await repo.setLabels(journalEntityId: 't1', labelIds: const ['a']);
        final afterAdd = current as Task;

        // Assert: suppression no longer contains 'a'
        expect(
          afterAdd.data.aiSuppressedLabelIds?.contains('a') ?? false,
          isFalse,
        );
      },
    );
  });
}
