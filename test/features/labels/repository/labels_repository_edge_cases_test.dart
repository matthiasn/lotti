import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';

void main() {
  late MockPersistenceLogic persistenceLogic;
  late MockJournalDb journalDb;
  late MockEntitiesCacheService cacheService;
  late MockLoggingService loggingService;
  late LabelsRepository repository;

  final baseTime = DateTime.utc(2024);

  Metadata buildMetadata({List<String>? labelIds}) {
    return Metadata(
      id: 'task-1',
      createdAt: baseTime,
      updatedAt: baseTime,
      dateFrom: baseTime,
      dateTo: baseTime,
      labelIds: labelIds,
    );
  }

  JournalEntity buildEntry({List<String>? labelIds}) {
    return JournalEntity.journalEntry(
      meta: buildMetadata(labelIds: labelIds),
    );
  }

  setUpAll(() {
    registerFallbackValue(testLabelDefinition1);
    registerFallbackValue(StackTrace.empty);
    registerFallbackValue(
      Metadata(
        id: 'meta-id',
        createdAt: baseTime,
        updatedAt: baseTime,
        dateFrom: baseTime,
        dateTo: baseTime,
      ),
    );
    registerFallbackValue(
      JournalEntity.journalEntry(
        meta: Metadata(
          id: 'meta-id',
          createdAt: baseTime,
          updatedAt: baseTime,
          dateFrom: baseTime,
          dateTo: baseTime,
        ),
      ),
    );
  });

  setUp(() {
    persistenceLogic = MockPersistenceLogic();
    journalDb = MockJournalDb();
    cacheService = MockEntitiesCacheService();
    loggingService = MockLoggingService();

    repository = LabelsRepository(
      persistenceLogic,
      journalDb,
      cacheService,
      loggingService,
    );
  });

  test('createLabel generates unique ids and trims whitespace', () async {
    when(() => persistenceLogic.upsertEntityDefinition(any()))
        .thenAnswer((_) async => 1);

    final first = await repository.createLabel(
      name: '  Focus ',
      color: '#FF0000',
      description: ' urgent ',
    );
    final second = await repository.createLabel(
      name: 'Focus',
      color: '#00FF00',
    );

    expect(first.id, isNot(second.id));
    expect(first.name, 'Focus');
    expect(first.description, 'urgent');
  });

  test('setLabels sorts ids alphabetically via cache service', () async {
    final entry = buildEntry(labelIds: const ['label-c']);
    when(() => journalDb.journalEntityById(entry.meta.id))
        .thenAnswer((_) async => entry);
    when(() => cacheService.getLabelById('label-b')).thenReturn(
      testLabelDefinition1.copyWith(
        id: 'label-b',
        name: 'Backend',
      ),
    );
    when(() => cacheService.getLabelById('label-a')).thenReturn(
      testLabelDefinition2.copyWith(
        id: 'label-a',
        name: 'Analytics',
      ),
    );
    when(
      () => persistenceLogic.updateMetadata(
        entry.meta,
        labelIds: any(named: 'labelIds'),
        clearLabelIds: any(named: 'clearLabelIds'),
      ),
    ).thenAnswer((invocation) async {
      final ids = invocation.namedArguments[#labelIds] as List<String>;
      return entry.meta.copyWith(labelIds: ids);
    });
    when(() => persistenceLogic.updateDbEntity(any()))
        .thenAnswer((_) async => true);

    final result = await repository.setLabels(
      journalEntityId: entry.meta.id,
      labelIds: const ['label-b', 'label-a'],
    );

    expect(result, isTrue);
    verify(
      () => persistenceLogic.updateDbEntity(
        any(
          that: predicate<JournalEntity>((entity) {
            final labels = entity.meta.labelIds!;
            return labels[0] == 'label-a' && labels[1] == 'label-b';
          }),
        ),
      ),
    ).called(1);
  });

  test('addLabels logs and returns false when db lookup fails', () async {
    when(() => journalDb.journalEntityById(any()))
        .thenThrow(Exception('offline'));

    final result = await repository.addLabels(
      journalEntityId: 'task-1',
      addedLabelIds: const ['label-1'],
    );

    expect(result, isFalse);
    verify(
      () => loggingService.captureException(
        any<dynamic>(),
        domain: any<String>(named: 'domain'),
        subDomain: any<String>(named: 'subDomain'),
        stackTrace: any<StackTrace>(named: 'stackTrace'),
      ),
    ).called(1);
  });

  test('removeLabel clears metadata when last label removed', () async {
    final entry = buildEntry(labelIds: const ['label-1']);
    when(() => journalDb.journalEntityById(entry.meta.id))
        .thenAnswer((_) async => entry);
    when(() => persistenceLogic.updateMetadata(any())).thenAnswer(
      (invocation) async => invocation.positionalArguments.first as Metadata,
    );
    when(() => persistenceLogic.updateDbEntity(any()))
        .thenAnswer((_) async => true);

    final result = await repository.removeLabel(
      journalEntityId: entry.meta.id,
      labelId: 'label-1',
    );

    expect(result, isTrue);
    verify(
      () => persistenceLogic.updateDbEntity(
        any(
          that: predicate<JournalEntity>(
            (entity) => entity.meta.labelIds == null,
          ),
        ),
      ),
    ).called(1);
  });

  test('createLabel preserves provided color even if malformed', () async {
    when(() => persistenceLogic.upsertEntityDefinition(any()))
        .thenAnswer((_) async => 1);

    final label = await repository.createLabel(
      name: 'Malformed',
      color: 'not-a-color',
    );

    expect(label.color, 'not-a-color');
  });
}
