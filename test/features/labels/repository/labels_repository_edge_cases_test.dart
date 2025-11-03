import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/sync/vector_clock.dart';
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

  test('updateLabel clears description when empty string provided', () async {
    when(() => persistenceLogic.upsertEntityDefinition(any()))
        .thenAnswer((_) async => 1);

    final original = testLabelDefinition1.copyWith(description: 'a');

    final updated = await repository.updateLabel(
      original,
      description: '', // signal clear
    );

    expect(updated.description, isNull,
        reason: 'Empty string should clear (persist as null)');

    verify(
      () => persistenceLogic.upsertEntityDefinition(
        any(
          that: predicate<LabelDefinition>(
            (l) => l.description == null,
          ),
        ),
      ),
    ).called(1);
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

  test('createLabel handles all categories deleted during validation',
      () async {
    when(() => persistenceLogic.upsertEntityDefinition(any()))
        .thenAnswer((_) async => 1);
    // Cache returns no categories → all provided IDs are invalid
    when(() => cacheService.getCategoryById(any())).thenReturn(null);

    final label = await repository.createLabel(
      name: 'Scoped but invalid',
      color: '#010203',
      applicableCategoryIds: const ['gone-1', 'gone-2'],
    );

    expect(label.applicableCategoryIds, isNull,
        reason: 'Invalid categories should result in null (global)');
  });

  test('updateLabel preserves other fields when only updating categories',
      () async {
    when(() => persistenceLogic.upsertEntityDefinition(any()))
        .thenAnswer((_) async => 1);
    when(() => cacheService.getCategoryById('cat')).thenReturn(
      CategoryDefinition(
        id: 'cat',
        name: 'Work',
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        vectorClock: null,
        private: false,
        active: true,
      ),
    );

    final original = LabelDefinition(
      id: 'id',
      name: 'Name',
      color: '#AABBCC',
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
      vectorClock: const VectorClock(<String, int>{}),
      description: 'desc',
      private: true,
    );

    final updated = await repository.updateLabel(
      original,
      applicableCategoryIds: const ['cat'],
    );

    expect(updated.name, original.name);
    expect(updated.color, original.color);
    expect(updated.description, original.description);
    expect(updated.private, original.private);
    expect(updated.applicableCategoryIds, equals(const ['cat']));
  });

  test('createLabel trims whitespace from category IDs', () async {
    when(() => persistenceLogic.upsertEntityDefinition(any()))
        .thenAnswer((_) async => 1);
    when(() => cacheService.getCategoryById('cat')).thenReturn(
      CategoryDefinition(
        id: 'cat',
        name: 'Cat',
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        vectorClock: null,
        private: false,
        active: true,
      ),
    );

    final label = await repository.createLabel(
      name: 'Trim',
      color: '#000000',
      applicableCategoryIds: const ['  cat  '],
    );

    expect(label.applicableCategoryIds, equals(const ['cat']));
  });

  test('createLabel accepts extremely long descriptions', () async {
    when(() => persistenceLogic.upsertEntityDefinition(any()))
        .thenAnswer((_) async => 1);

    final longDescription = 'long ' * 250; // 1000+ chars
    final label = await repository.createLabel(
      name: 'Knowledge base',
      color: '#010203',
      description: '$longDescription ',
    );

    expect(label.description?.length, greaterThan(1000));
    expect(label.description?.endsWith(' '), isFalse,
        reason: 'Description should be trimmed');
  });

  test('setLabels deduplicates ids and sorts alphabetically', () async {
    final entry = buildEntry(labelIds: const ['label-a']);
    when(() => journalDb.journalEntityById(entry.meta.id))
        .thenAnswer((_) async => entry);
    when(() => cacheService.getLabelById('label-a')).thenReturn(
      testLabelDefinition1.copyWith(id: 'label-a', name: 'Analytics'),
    );
    when(() => cacheService.getLabelById('label-b')).thenReturn(
      testLabelDefinition2.copyWith(id: 'label-b', name: 'Backend'),
    );
    when(() => journalDb.getLabelDefinitionById(any()))
        .thenAnswer((_) async => null);
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
      labelIds: const ['label-b', 'label-a', 'label-a'],
    );

    expect(result, isTrue);
    verify(
      () => persistenceLogic.updateMetadata(
        entry.meta,
        labelIds: ['label-a', 'label-b'],
        clearLabelIds: any(named: 'clearLabelIds'),
      ),
    ).called(1);
  });

  test('setLabels skips ids for labels deleted mid-assignment', () async {
    final entry = buildEntry();
    when(() => journalDb.journalEntityById(entry.meta.id))
        .thenAnswer((_) async => entry);
    when(() => cacheService.getLabelById('label-live')).thenReturn(
      testLabelDefinition1.copyWith(id: 'label-live', name: 'Live'),
    );
    when(() => cacheService.getLabelById('label-zombie')).thenReturn(null);
    when(() => journalDb.getLabelDefinitionById('label-live'))
        .thenAnswer((_) async => testLabelDefinition1.copyWith(
              id: 'label-live',
              name: 'Live',
            ));
    when(() => journalDb.getLabelDefinitionById('label-zombie'))
        .thenAnswer((_) async => null);
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
      labelIds: const ['label-live', 'label-zombie'],
    );

    expect(result, isTrue);
    verify(
      () => persistenceLogic.updateMetadata(
        entry.meta,
        labelIds: ['label-live'],
        clearLabelIds: any(named: 'clearLabelIds'),
      ),
    ).called(1);
  });
}
