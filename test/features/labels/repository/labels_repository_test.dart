import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';

class MockPersistenceLogic extends Mock implements PersistenceLogic {}

class MockJournalDb extends Mock implements JournalDb {}

class MockEntitiesCacheService extends Mock implements EntitiesCacheService {}

class MockLoggingService extends Mock implements LoggingService {}

void main() {
  final baseTime = DateTime.utc(1970);

  setUpAll(() {
    registerFallbackValue(fallbackJournalEntity);
    registerFallbackValue(
      LabelDefinition(
        id: 'fallback-label',
        name: 'Fallback',
        color: '#000000',
        createdAt: baseTime,
        updatedAt: baseTime,
        vectorClock: const VectorClock(<String, int>{}),
      ),
    );
    registerFallbackValue(
      Metadata(
        id: 'meta-id',
        createdAt: baseTime,
        updatedAt: baseTime,
        dateFrom: baseTime,
        dateTo: baseTime,
      ),
    );
  });

  late MockPersistenceLogic persistenceLogic;
  late MockJournalDb journalDb;
  late MockEntitiesCacheService cacheService;
  late MockLoggingService loggingService;
  late LabelsRepository repository;

  Metadata buildMetadata({List<String>? labelIds}) {
    return Metadata(
      id: 'meta-id',
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
      entryText: const EntryText(plainText: 'entry'),
    );
  }

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

  test('createLabel upserts entity definition with trimmed values', () async {
    when(() => persistenceLogic.upsertEntityDefinition(any()))
        .thenAnswer((_) async => 1);

    final label = await repository.createLabel(
      name: '  Release ',
      color: '#FF0000',
      description: '  blockers ',
    );

    expect(label.name, 'Release');
    expect(label.description, 'blockers');

    final captured = verify(
      () => persistenceLogic
          .upsertEntityDefinition(captureAny<EntityDefinition>()),
    ).captured.single as LabelDefinition;

    expect(captured.name, 'Release');
    expect(captured.color, '#FF0000');
    expect(captured.description, 'blockers');
  });

  test('updateLabel propagates changes through persistence logic', () async {
    when(() => persistenceLogic.upsertEntityDefinition(any()))
        .thenAnswer((_) async => 1);

    final label = LabelDefinition(
      id: 'id',
      name: 'Old',
      color: '#000000',
      description: 'desc',
      createdAt: baseTime,
      updatedAt: baseTime,
      vectorClock: const VectorClock(<String, int>{}),
    );

    final updated = await repository.updateLabel(
      label,
      name: 'New',
      color: '#FFFFFF',
      description: 'changed',
    );

    expect(updated.name, 'New');
    expect(updated.color, '#FFFFFF');
    expect(updated.description, 'changed');
    verify(() => persistenceLogic.upsertEntityDefinition(any())).called(1);
  });

  test('deleteLabel marks label deleted when definition exists', () async {
    final label = LabelDefinition(
      id: 'label-id',
      name: 'Label',
      color: '#123456',
      createdAt: baseTime,
      updatedAt: baseTime,
      vectorClock: const VectorClock(<String, int>{}),
    );

    when(() => journalDb.getLabelDefinitionById(label.id))
        .thenAnswer((_) async => label);
    when(() => persistenceLogic.upsertEntityDefinition(any()))
        .thenAnswer((_) async => 1);

    await repository.deleteLabel(label.id);

    final captured = verify(
      () => persistenceLogic
          .upsertEntityDefinition(captureAny<EntityDefinition>()),
    ).captured.single as LabelDefinition;

    expect(captured.deletedAt, isNotNull);
    expect(captured.updatedAt.isAfter(label.updatedAt), isTrue);
  });

  test('deleteLabel no-ops when definition is missing', () async {
    when(() => journalDb.getLabelDefinitionById(any()))
        .thenAnswer((_) async => null);

    await repository.deleteLabel('missing');

    verifyNever(() => persistenceLogic.upsertEntityDefinition(any()));
  });

  test('addLabels short-circuits when no label ids provided', () async {
    final result = await repository.addLabels(
      journalEntityId: 'entity-id',
      addedLabelIds: const [],
    );

    expect(result, isTrue);
    verifyNever(() => journalDb.journalEntityById(any()));
  });

  test('addLabels merges unique ids and persists entity', () async {
    final entry = buildEntry(labelIds: const ['existing']);

    when(() => journalDb.journalEntityById(entry.meta.id))
        .thenAnswer((_) async => entry);

    Metadata? capturedMetadata;
    when(
      () => persistenceLogic.updateMetadata(
        any<Metadata>(),
        dateFrom: any<DateTime?>(named: 'dateFrom'),
        dateTo: any<DateTime?>(named: 'dateTo'),
        categoryId: any<String?>(named: 'categoryId'),
        clearCategoryId: any<bool>(named: 'clearCategoryId'),
        deletedAt: any<DateTime?>(named: 'deletedAt'),
      ),
    ).thenAnswer((invocation) async {
      capturedMetadata = invocation.positionalArguments.first as Metadata;
      return capturedMetadata!;
    });

    JournalEntity? capturedEntity;
    when(
      () => persistenceLogic.updateDbEntity(
        any<JournalEntity>(),
        linkedId: any<String?>(named: 'linkedId'),
        enqueueSync: any<bool>(named: 'enqueueSync'),
      ),
    ).thenAnswer((invocation) async {
      capturedEntity = invocation.positionalArguments.first as JournalEntity;
      return true;
    });

    final result = await repository.addLabels(
      journalEntityId: entry.meta.id,
      addedLabelIds: const ['new', 'existing'],
    );

    expect(result, isTrue);
    expect(capturedMetadata?.labelIds, unorderedEquals(['existing', 'new']));
    expect(capturedEntity?.meta.labelIds, unorderedEquals(['existing', 'new']));
  });

  test('addLabels returns false when journal entity is missing', () async {
    when(() => journalDb.journalEntityById(any()))
        .thenAnswer((_) async => null);

    final result = await repository.addLabels(
      journalEntityId: 'missing',
      addedLabelIds: const ['label'],
    );

    expect(result, isFalse);
  });

  test('removeLabel updates metadata and persists entity', () async {
    final entry = buildEntry(labelIds: const ['keep', 'remove']);
    when(() => journalDb.journalEntityById(entry.meta.id))
        .thenAnswer((_) async => entry);

    Metadata? capturedMetadata;
    when(
      () => persistenceLogic.updateMetadata(
        any<Metadata>(),
        dateFrom: any<DateTime?>(named: 'dateFrom'),
        dateTo: any<DateTime?>(named: 'dateTo'),
        categoryId: any<String?>(named: 'categoryId'),
        clearCategoryId: any<bool>(named: 'clearCategoryId'),
        deletedAt: any<DateTime?>(named: 'deletedAt'),
      ),
    ).thenAnswer((invocation) async {
      capturedMetadata = invocation.positionalArguments.first as Metadata;
      return capturedMetadata!;
    });

    JournalEntity? capturedEntity;
    when(
      () => persistenceLogic.updateDbEntity(
        any<JournalEntity>(),
        linkedId: any<String?>(named: 'linkedId'),
        enqueueSync: any<bool>(named: 'enqueueSync'),
      ),
    ).thenAnswer((invocation) async {
      capturedEntity = invocation.positionalArguments.first as JournalEntity;
      return true;
    });

    final result = await repository.removeLabel(
      journalEntityId: entry.meta.id,
      labelId: 'remove',
    );

    expect(result, isTrue);
    expect(capturedMetadata?.labelIds, unorderedEquals(['keep']));
    expect(capturedEntity?.meta.labelIds, unorderedEquals(['keep']));
  });

  test('removeLabel returns false when entity is missing', () async {
    when(() => journalDb.journalEntityById(any()))
        .thenAnswer((_) async => null);

    final result = await repository.removeLabel(
      journalEntityId: 'missing',
      labelId: 'remove',
    );

    expect(result, isFalse);
  });

  test('addLabels returns false on exception', () async {
    final entry = buildEntry(labelIds: const ['a']);
    when(() => journalDb.journalEntityById(entry.meta.id))
        .thenAnswer((_) async => entry);
    when(() => persistenceLogic.updateMetadata(any())).thenAnswer(
        (invocation) async => invocation.positionalArguments.first as Metadata);
    when(() => persistenceLogic.updateDbEntity(any(),
            linkedId: any(named: 'linkedId'),
            enqueueSync: any(named: 'enqueueSync')))
        .thenThrow(Exception('db error'));

    final result = await repository.addLabels(
      journalEntityId: entry.meta.id,
      addedLabelIds: const ['b'],
    );

    expect(result, isFalse);
  });

  test('addLabels does not modify original labelIds list', () async {
    final original = ['existing'];
    final entry = buildEntry(labelIds: original);
    when(() => journalDb.journalEntityById(entry.meta.id))
        .thenAnswer((_) async => entry);
    when(() => persistenceLogic.updateMetadata(any())).thenAnswer(
        (invocation) async => invocation.positionalArguments.first as Metadata);
    when(() => persistenceLogic.updateDbEntity(any(),
        linkedId: any(named: 'linkedId'),
        enqueueSync: any(named: 'enqueueSync'))).thenAnswer((_) async => true);

    await repository.addLabels(
      journalEntityId: entry.meta.id,
      addedLabelIds: const ['new'],
    );

    expect(original, equals(['existing']));
  });

  test('removeLabel returns false on database error', () async {
    final entry = buildEntry(labelIds: const ['x']);
    when(() => journalDb.journalEntityById(entry.meta.id))
        .thenAnswer((_) async => entry);
    when(() => persistenceLogic.updateMetadata(any())).thenAnswer(
        (invocation) async => invocation.positionalArguments.first as Metadata);
    when(() => persistenceLogic.updateDbEntity(any(),
            linkedId: any(named: 'linkedId'),
            enqueueSync: any(named: 'enqueueSync')))
        .thenThrow(Exception('db error'));

    final result = await repository.removeLabel(
      journalEntityId: entry.meta.id,
      labelId: 'x',
    );
    expect(result, isFalse);
  });

  test('setLabels handles empty list correctly', () async {
    final entry = buildEntry(labelIds: const ['a']);
    when(() => journalDb.journalEntityById(entry.meta.id))
        .thenAnswer((_) async => entry);
    when(() =>
        persistenceLogic.updateMetadata(any(),
            labelIds: any(named: 'labelIds'),
            clearLabelIds: any(named: 'clearLabelIds'))).thenAnswer(
        (invocation) async => invocation.positionalArguments.first as Metadata);
    JournalEntity? captured;
    when(() => persistenceLogic.updateDbEntity(any(),
        linkedId: any(named: 'linkedId'),
        enqueueSync: any(named: 'enqueueSync'))).thenAnswer((invocation) async {
      captured = invocation.positionalArguments.first as JournalEntity;
      return true;
    });

    final result = await repository.setLabels(
      journalEntityId: entry.meta.id,
      labelIds: const [],
    );
    expect(result, isTrue);
    expect(captured?.meta.labelIds, isNull);
  });

  test('setLabels filters deleted labels from final list and sorts by name',
      () async {
    final entry = buildEntry(labelIds: const ['a']);
    when(() => journalDb.journalEntityById(entry.meta.id))
        .thenAnswer((_) async => entry);
    when(() => cacheService.getLabelById('keep1')).thenReturn(
      LabelDefinition(
        id: 'keep1',
        name: 'Bravo',
        color: '#000000',
        createdAt: baseTime,
        updatedAt: baseTime,
        vectorClock: const VectorClock(<String, int>{}),
      ),
    );
    when(() => journalDb.getLabelDefinitionById('keep2')).thenAnswer(
      (_) async => LabelDefinition(
        id: 'keep2',
        name: 'Alpha',
        color: '#000000',
        createdAt: baseTime,
        updatedAt: baseTime,
        vectorClock: const VectorClock(<String, int>{}),
      ),
    );
    when(() => journalDb.getLabelDefinitionById('deleted')).thenAnswer(
      (_) async => LabelDefinition(
        id: 'deleted',
        name: 'Zulu',
        color: '#000000',
        createdAt: baseTime,
        updatedAt: baseTime,
        vectorClock: const VectorClock(<String, int>{}),
        deletedAt: baseTime,
      ),
    );
    when(() => journalDb.getLabelDefinitionById('missing'))
        .thenAnswer((_) async => null);

    when(() =>
        persistenceLogic.updateMetadata(any(),
            labelIds: any(named: 'labelIds'),
            clearLabelIds: any(named: 'clearLabelIds'))).thenAnswer(
        (invocation) async => invocation.positionalArguments.first as Metadata);
    JournalEntity? captured;
    when(() => persistenceLogic.updateDbEntity(any(),
        linkedId: any(named: 'linkedId'),
        enqueueSync: any(named: 'enqueueSync'))).thenAnswer((invocation) async {
      captured = invocation.positionalArguments.first as JournalEntity;
      return true;
    });

    final result = await repository.setLabels(
      journalEntityId: entry.meta.id,
      labelIds: const ['keep1', 'deleted', 'missing', 'keep2'],
    );
    expect(result, isTrue);
    // Sorted by name: Alpha (keep2), Bravo (keep1)
    expect(captured?.meta.labelIds, equals(['keep2', 'keep1']));
  });

  test('addLabelsToMeta merges ids without duplicates', () {
    final meta = buildMetadata(labelIds: const ['a', 'b']);
    final updated = addLabelsToMeta(meta, const ['b', 'c']);

    expect(updated.labelIds, ['a', 'b', 'c']);
  });

  test('removeLabelFromMeta clears list when last label removed', () {
    final meta = buildMetadata(labelIds: const ['only']);
    final updated = removeLabelFromMeta(meta, 'only');

    expect(updated.labelIds, isNull);
  });
}
