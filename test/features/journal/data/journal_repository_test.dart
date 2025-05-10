import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/features/journal/data/journal_repository.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

class MockJournalDb extends Mock implements JournalDb {}

class MockFts5Db extends Mock implements Fts5Db {}

class MockUpdateNotifications extends Mock implements UpdateNotifications {}

class MockEntitiesCacheService extends Mock implements EntitiesCacheService {}

void main() {
  late JournalRepository repository;
  late MockJournalDb mockJournalDb;
  late MockFts5Db mockFts5Db;
  late MockUpdateNotifications mockUpdateNotifications;
  late MockEntitiesCacheService mockEntitiesCacheService;

  setUp(() {
    mockJournalDb = MockJournalDb();
    mockFts5Db = MockFts5Db();
    mockUpdateNotifications = MockUpdateNotifications();
    mockEntitiesCacheService = MockEntitiesCacheService();

    repository = JournalRepository(
      db: mockJournalDb,
      fts5Db: mockFts5Db,
      updateNotifications: mockUpdateNotifications,
      entitiesCacheService: mockEntitiesCacheService,
    );
  });

  group('JournalRepository', () {
    test('getJournalEntities calls database with correct parameters', () async {
      // Arrange
      when(() => mockJournalDb.getJournalEntities(
            types: any(named: 'types'),
            starredStatuses: any(named: 'starredStatuses'),
            privateStatuses: any(named: 'privateStatuses'),
            flaggedStatuses: any(named: 'flaggedStatuses'),
            ids: any(named: 'ids'),
            categoryIds: any(named: 'categoryIds'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          )).thenAnswer((_) async => <JournalEntity>[]);

      // Act
      await repository.getJournalEntities(
        types: ['JournalEntry'],
        starredStatuses: [true, false],
        privateStatuses: [true, false],
        flaggedStatuses: [1, 0],
        offset: 0,
      );

      // Assert
      verify(() => mockJournalDb.getJournalEntities(
            types: ['JournalEntry'],
            starredStatuses: [true, false],
            privateStatuses: [true, false],
            flaggedStatuses: [1, 0],
            ids: null,
            categoryIds: null,
            limit: JournalRepository.pageSize,
            offset: 0,
          )).called(1);
    });

    test('getTasks calls database with correct parameters', () async {
      // Arrange
      when(() => mockJournalDb.getTasks(
            starredStatuses: any(named: 'starredStatuses'),
            taskStatuses: any(named: 'taskStatuses'),
            categoryIds: any(named: 'categoryIds'),
            ids: any(named: 'ids'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          )).thenAnswer((_) async => <JournalEntity>[]);

      // Act
      await repository.getTasks(
        starredStatuses: [true],
        taskStatuses: ['OPEN'],
        categoryIds: ['category1'],
        offset: 0,
      );

      // Assert
      verify(() => mockJournalDb.getTasks(
            starredStatuses: [true],
            taskStatuses: ['OPEN'],
            categoryIds: ['category1'],
            ids: null,
            limit: JournalRepository.pageSize,
            offset: 0,
          )).called(1);
    });

    test('fullTextSearch returns empty set when query is empty', () async {
      // Act
      final result = await repository.fullTextSearch('');

      // Assert
      expect(result, isEmpty);
      verifyNever(() => mockFts5Db.watchFullTextMatches(any()));
    });

    test('fullTextSearch returns results from fts5Db', () async {
      // Arrange
      when(() => mockFts5Db.watchFullTextMatches('test'))
          .thenAnswer((_) => Stream.value(['id1', 'id2']));

      // Act
      final result = await repository.fullTextSearch('test');

      // Assert
      expect(result, equals({'id1', 'id2'}));
      verify(() => mockFts5Db.watchFullTextMatches('test')).called(1);
    });
  });
}
