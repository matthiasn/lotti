import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/journal_update_result.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/logic/services/metadata_service.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fallbacks.dart';
import '../mocks/mocks.dart';

enum _GeneratedPersistenceEntityKind {
  journalEntry,
  event,
  task,
  measurement,
  habitCompletion,
  image,
  audio,
}

class _GeneratedUpdateDbEntityScenario {
  const _GeneratedUpdateDbEntityScenario({
    required this.kind,
    required this.seed,
    required this.applied,
    required this.enqueueSync,
    required this.hasLinkedId,
    required this.parentCount,
  });

  final _GeneratedPersistenceEntityKind kind;
  final int seed;
  final bool applied;
  final bool enqueueSync;
  final bool hasLinkedId;
  final int parentCount;

  String? get linkedId => hasLinkedId ? 'linked-$seed' : null;

  List<String> get parentIds => [
    for (var index = 0; index < parentCount; index++) 'parent-$seed-$index',
  ];

  JournalEntity get entity => _buildGeneratedEntity(kind, seed);

  Set<String> get expectedNotificationIds => {
    ..._expectedAffectedIds(kind, 'entity-$seed'),
    ?linkedId,
    ...parentIds,
    // Each parent ID is also emitted in propagated form so the wake
    // orchestrator can defer parent-fan-out matches to the next 06:00
    // instead of treating them as direct edits.
    for (final id in parentIds) propagatedNotification(id),
    labelUsageNotification,
  };

  bool get shouldEnqueueSync => applied && enqueueSync;

  @override
  String toString() {
    return '_GeneratedUpdateDbEntityScenario('
        'kind: $kind, '
        'seed: $seed, '
        'applied: $applied, '
        'enqueueSync: $enqueueSync, '
        'linkedId: $linkedId, '
        'parentIds: $parentIds)';
  }
}

class _GeneratedCreateDbEntityScenario {
  const _GeneratedCreateDbEntityScenario({
    required this.seed,
    required this.saved,
    required this.enqueueSync,
    required this.hasLinkedEntity,
    required this.hasExplicitCategory,
    required this.linkedPrivate,
  });

  final int seed;
  final bool saved;
  final bool enqueueSync;
  final bool hasLinkedEntity;
  final bool hasExplicitCategory;
  final bool linkedPrivate;

  String get entityId => 'created-$seed';

  String? get linkedId => hasLinkedEntity ? 'linked-$seed' : null;

  String? get explicitCategoryId =>
      hasExplicitCategory ? 'entity-category-$seed' : null;

  String? get linkedCategoryId =>
      hasLinkedEntity ? 'linked-category-$seed' : null;

  JournalEntity get entity => JournalEntity.journalEntry(
    meta: _metadata(
      id: entityId,
      categoryId: explicitCategoryId,
      private: !linkedPrivate,
    ),
    entryText: EntryText(plainText: 'created text $seed'),
  );

  JournalEntity? get linkedEntity {
    if (!hasLinkedEntity) return null;
    return JournalEntity.journalEntry(
      meta: _metadata(
        id: linkedId!,
        categoryId: linkedCategoryId,
        private: linkedPrivate,
      ),
      entryText: EntryText(plainText: 'linked text $seed'),
    );
  }

  String? get expectedCategoryId => explicitCategoryId ?? linkedCategoryId;

  bool? get expectedPrivate => hasLinkedEntity ? linkedPrivate : null;

  bool get shouldEnqueueSync => saved && enqueueSync;

  Set<String> get expectedCreateNotificationIds => {
    entityId,
    textEntryNotification,
    ?linkedId,
    labelUsageNotification,
  };

  @override
  String toString() {
    return '_GeneratedCreateDbEntityScenario('
        'seed: $seed, '
        'saved: $saved, '
        'enqueueSync: $enqueueSync, '
        'linkedId: $linkedId, '
        'explicitCategoryId: $explicitCategoryId, '
        'linkedPrivate: $linkedPrivate)';
  }
}

extension _AnyGeneratedPersistenceScenario on glados.Any {
  glados.Generator<_GeneratedPersistenceEntityKind> get persistenceEntityKind =>
      glados.AnyUtils(this).choose(_GeneratedPersistenceEntityKind.values);

  glados.Generator<_GeneratedUpdateDbEntityScenario>
  get updateDbEntityScenario => glados.CombinableAny(this).combine6(
    persistenceEntityKind,
    glados.IntAnys(this).intInRange(0, 10000),
    glados.AnyUtils(this).choose([false, true]),
    glados.AnyUtils(this).choose([false, true]),
    glados.AnyUtils(this).choose([false, true]),
    glados.IntAnys(this).intInRange(0, 4),
    (
      _GeneratedPersistenceEntityKind kind,
      int seed,
      bool applied,
      bool enqueueSync,
      bool hasLinkedId,
      int parentCount,
    ) => _GeneratedUpdateDbEntityScenario(
      kind: kind,
      seed: seed,
      applied: applied,
      enqueueSync: enqueueSync,
      hasLinkedId: hasLinkedId,
      parentCount: parentCount,
    ),
  );

  glados.Generator<_GeneratedCreateDbEntityScenario>
  get createDbEntityScenario => glados.CombinableAny(this).combine6(
    glados.IntAnys(this).intInRange(0, 10000),
    glados.AnyUtils(this).choose([false, true]),
    glados.AnyUtils(this).choose([false, true]),
    glados.AnyUtils(this).choose([false, true]),
    glados.AnyUtils(this).choose([false, true]),
    glados.AnyUtils(this).choose([false, true]),
    (
      int seed,
      bool saved,
      bool enqueueSync,
      bool hasLinkedEntity,
      bool hasExplicitCategory,
      bool linkedPrivate,
    ) => _GeneratedCreateDbEntityScenario(
      seed: seed,
      saved: saved,
      enqueueSync: enqueueSync,
      hasLinkedEntity: hasLinkedEntity,
      hasExplicitCategory: hasExplicitCategory,
      linkedPrivate: linkedPrivate,
    ),
  );
}

class TestPersistenceLogic extends PersistenceLogic {
  TestPersistenceLogic({this.updateDbEntityHandler});

  final Future<bool?> Function(
    JournalEntity entity, {
    String? linkedId,
    bool enqueueSync,
    bool overrideComparison,
    Future<void> Function()? beforeNotify,
  })?
  updateDbEntityHandler;
  int updateMetadataCalls = 0;
  JournalEntity? lastUpdateDbEntity;

  @override
  Future<Metadata> updateMetadata(
    Metadata metadata, {
    DateTime? dateFrom,
    DateTime? dateTo,
    String? categoryId,
    bool clearCategoryId = false,
    List<String>? labelIds,
    bool clearLabelIds = false,
    DateTime? deletedAt,
  }) async {
    updateMetadataCalls++;
    return super.updateMetadata(
      metadata,
      dateFrom: dateFrom,
      dateTo: dateTo,
      categoryId: categoryId,
      clearCategoryId: clearCategoryId,
      labelIds: labelIds,
      clearLabelIds: clearLabelIds,
      deletedAt: deletedAt,
    );
  }

  @override
  Future<bool?> updateDbEntity(
    JournalEntity journalEntity, {
    String? linkedId,
    bool enqueueSync = true,
    bool overrideComparison = false,
    Future<void> Function()? beforeNotify,
  }) async {
    lastUpdateDbEntity = journalEntity;
    if (updateDbEntityHandler != null) {
      return updateDbEntityHandler!(
        journalEntity,
        linkedId: linkedId,
        enqueueSync: enqueueSync,
        overrideComparison: overrideComparison,
        beforeNotify: beforeNotify,
      );
    }
    return super.updateDbEntity(
      journalEntity,
      linkedId: linkedId,
      enqueueSync: enqueueSync,
      overrideComparison: overrideComparison,
      beforeNotify: beforeNotify,
    );
  }
}

Metadata _metadata({
  required String id,
  String? categoryId,
  bool? private,
}) {
  final testDate = DateTime(2024, 3, 15, 10, 30);
  return Metadata(
    id: id,
    createdAt: testDate,
    updatedAt: testDate,
    dateFrom: testDate,
    dateTo: testDate,
    categoryId: categoryId,
    private: private,
    vectorClock: const VectorClock({'host': 1}),
  );
}

JournalEntity _buildGeneratedEntity(
  _GeneratedPersistenceEntityKind kind,
  int seed,
) {
  final id = 'entity-$seed';
  final meta = _metadata(id: id);
  final testDate = DateTime(2024, 3, 15, 10, seed % 60);

  return switch (kind) {
    _GeneratedPersistenceEntityKind.journalEntry => JournalEntity.journalEntry(
      meta: meta,
      entryText: EntryText(plainText: 'generated text $seed'),
    ),
    _GeneratedPersistenceEntityKind.event => JournalEntity.event(
      meta: meta,
      data: EventData(
        status: EventStatus.tentative,
        title: 'event $seed',
        stars: seed % 5,
      ),
      entryText: EntryText(plainText: 'event text $seed'),
    ),
    _GeneratedPersistenceEntityKind.task => JournalEntity.task(
      meta: meta,
      data: TaskData(
        status: TaskStatus.open(
          id: 'status-$seed',
          createdAt: testDate,
          utcOffset: 60,
        ),
        title: 'task $seed',
        statusHistory: const [],
        dateFrom: testDate,
        dateTo: testDate,
      ),
      entryText: EntryText(plainText: 'task text $seed'),
    ),
    _GeneratedPersistenceEntityKind.measurement => JournalEntity.measurement(
      meta: meta,
      data: MeasurementData(
        dateFrom: testDate,
        dateTo: testDate,
        value: seed,
        dataTypeId: 'measurement-type-$seed',
      ),
      entryText: EntryText(plainText: 'measurement text $seed'),
    ),
    _GeneratedPersistenceEntityKind.habitCompletion =>
      JournalEntity.habitCompletion(
        meta: meta,
        data: HabitCompletionData(
          dateFrom: testDate,
          dateTo: testDate,
          habitId: 'habit-$seed',
        ),
        entryText: EntryText(plainText: 'habit text $seed'),
      ),
    _GeneratedPersistenceEntityKind.image => JournalEntity.journalImage(
      meta: meta,
      data: ImageData(
        capturedAt: testDate,
        imageId: 'image-$seed',
        imageFile: 'image-$seed.jpg',
        imageDirectory: '/images/2024-03-15/',
      ),
      entryText: EntryText(plainText: 'image text $seed'),
    ),
    _GeneratedPersistenceEntityKind.audio => JournalEntity.journalAudio(
      meta: meta,
      data: AudioData(
        dateFrom: testDate,
        dateTo: testDate,
        audioFile: 'audio-$seed.m4a',
        audioDirectory: '/audio/2024-03-15/',
        duration: Duration(seconds: seed % 3600),
      ),
      entryText: EntryText(plainText: 'audio text $seed'),
    ),
  };
}

Set<String> _expectedAffectedIds(
  _GeneratedPersistenceEntityKind kind,
  String id,
) {
  return switch (kind) {
    _GeneratedPersistenceEntityKind.journalEntry => {
      id,
      textEntryNotification,
    },
    _GeneratedPersistenceEntityKind.event => {id, eventNotification},
    _GeneratedPersistenceEntityKind.task => {id, taskNotification},
    _GeneratedPersistenceEntityKind.measurement => {
      id,
      'measurement-type-${id.split('-').last}',
    },
    _GeneratedPersistenceEntityKind.habitCompletion => {
      id,
      'habit-${id.split('-').last}',
      habitCompletionNotification,
    },
    _GeneratedPersistenceEntityKind.image => {id, imageNotification},
    _GeneratedPersistenceEntityKind.audio => {id, audioNotification},
  };
}

void main() {
  setUpAll(() {
    registerFallbackValue(
      const SyncMessage.journalEntity(
        id: 'fallback',
        jsonPath: '/fallback.json',
        vectorClock: VectorClock({'host': 1}),
        status: SyncEntryStatus.update,
      ),
    );
    registerFallbackValue(fallbackJournalEntity);
    registerFallbackValue(
      EntryLink.basic(
        id: 'fallback-link',
        fromId: 'fallback-from',
        toId: 'fallback-to',
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        vectorClock: const VectorClock({'host': 1}),
      ),
    );
  });

  late MockJournalDb journalDb;
  late MockUpdateNotifications updateNotifications;
  late MockLoggingService loggingService;
  late MockOutboxService outboxService;
  late MockFts5Db fts5Db;
  late MockNotificationService notificationService;
  late MockVectorClockService vectorClockService;
  late TestPersistenceLogic logic;
  void stubUpdateResult(JournalUpdateResult result) {
    when(
      () => journalDb.updateJournalEntity(
        any<JournalEntity>(),
        overrideComparison: any<bool>(named: 'overrideComparison'),
        overwrite: any<bool>(named: 'overwrite'),
      ),
    ).thenAnswer((_) async => result);
  }

  JournalEntity buildEntry({
    String id = 'entry-id',
    VectorClock? clock,
  }) {
    final testDate = DateTime(2024, 3, 15, 10, 30);
    return JournalEntity.journalEntry(
      meta: Metadata(
        id: id,
        createdAt: testDate,
        updatedAt: testDate,
        dateFrom: testDate,
        dateTo: testDate,
        vectorClock: clock ?? const VectorClock({'host': 1}),
      ),
      entryText: const EntryText(plainText: 'text'),
    );
  }

  setUp(() async {
    await getIt.reset();
    journalDb = MockJournalDb();
    updateNotifications = MockUpdateNotifications();
    loggingService = MockLoggingService();
    outboxService = MockOutboxService();
    fts5Db = MockFts5Db();
    notificationService = MockNotificationService();
    vectorClockService = MockVectorClockService();

    when(
      () => fts5Db.insertText(
        any<JournalEntity>(),
        removePrevious: any<bool>(named: 'removePrevious'),
      ),
    ).thenAnswer((_) async {});
    when(notificationService.updateBadge).thenAnswer((_) async {});
    when(() => updateNotifications.notify(any<Set<String>>())).thenReturn(null);
    when(
      () => outboxService.enqueueMessage(any<SyncMessage>()),
    ).thenAnswer((_) async {});
    when(
      () => vectorClockService.getNextVectorClock(),
    ).thenAnswer((_) async => const VectorClock({'host': 1}));
    when(
      () => vectorClockService.getNextVectorClock(
        previous: any<VectorClock?>(named: 'previous'),
      ),
    ).thenAnswer((_) async => const VectorClock({'host': 1}));
    when(
      () => vectorClockService.getHost(),
    ).thenAnswer((_) async => 'test-host-id');
    when(
      () => vectorClockService.burnUnboundVectorClock(
        any<VectorClock?>(),
        reason: any<String>(named: 'reason'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => journalDb.addLabeled(any<JournalEntity>()),
    ).thenAnswer((_) async {});
    when(
      () => journalDb.parentLinkedEntityIds(any<String>()),
    ).thenReturn(MockSelectable<String>([]));
    when(
      () => journalDb.updateTaskPriorityColumn(
        id: any(named: 'id'),
        priority: any(named: 'priority'),
        rank: any(named: 'rank'),
      ),
    ).thenAnswer((_) async {});

    getIt
      ..registerSingleton<JournalDb>(journalDb)
      ..registerSingleton<UpdateNotifications>(updateNotifications)
      ..registerSingleton<LoggingService>(loggingService)
      ..registerSingleton<OutboxService>(outboxService)
      ..registerSingleton<Fts5Db>(fts5Db)
      ..registerSingleton<NotificationService>(notificationService)
      ..registerSingleton<VectorClockService>(vectorClockService)
      ..registerSingleton<MetadataService>(
        MetadataService(vectorClockService: vectorClockService),
      );

    logic = TestPersistenceLogic();
  });

  tearDown(() async {
    await getIt.reset();
  });

  test('updateDbEntity returns true when update applied', () async {
    stubUpdateResult(JournalUpdateResult.applied());

    final result = await logic.updateDbEntity(buildEntry());

    expect(result, isTrue);
    verify(() => outboxService.enqueueMessage(any<SyncMessage>())).called(1);
    verify(() => updateNotifications.notify(any<Set<String>>())).called(1);
  });

  test(
    'updateDbEntity logs beforeNotify failures and still propagates changes',
    () async {
      stubUpdateResult(JournalUpdateResult.applied());

      final result = await logic.updateDbEntity(
        buildEntry(),
        beforeNotify: () async => throw Exception('beforeNotify failed'),
      );

      expect(result, isTrue);
      verify(
        () => loggingService.captureException(
          any<Object>(),
          domain: 'persistence_logic',
          subDomain: 'updateDbEntity.beforeNotify',
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
        ),
      ).called(1);
      verify(() => updateNotifications.notify(any<Set<String>>())).called(1);
      verify(() => outboxService.enqueueMessage(any<SyncMessage>())).called(1);
      verify(
        () => fts5Db.insertText(
          any<JournalEntity>(),
          removePrevious: true,
        ),
      ).called(1);
      verify(notificationService.updateBadge).called(1);
    },
  );

  test('updateDbEntity returns false when update skipped', () async {
    stubUpdateResult(
      JournalUpdateResult.skipped(
        reason: JournalUpdateSkipReason.olderOrEqual,
      ),
    );

    final result = await logic.updateDbEntity(buildEntry());

    expect(result, isFalse);
    verifyNever(() => outboxService.enqueueMessage(any<SyncMessage>()));
  });

  test(
    'updateDbEntity burns the pre-minted VC counter when the write is '
    'rejected — without this the counter leaks as plain reserved since the '
    'incoming clock was minted by updateMetadata outside this scope',
    () async {
      stubUpdateResult(
        JournalUpdateResult.skipped(
          reason: JournalUpdateSkipReason.olderOrEqual,
        ),
      );

      final entry = buildEntry(clock: const VectorClock({'host': 42}));
      final result = await logic.updateDbEntity(entry);

      expect(result, isFalse);
      verify(
        () => vectorClockService.burnUnboundVectorClock(
          entry.meta.vectorClock,
          reason: any<String>(
            named: 'reason',
            that: contains('updateDbEntity write rejected id=entry-id'),
          ),
        ),
      ).called(1);
    },
  );

  test('updateDbEntity returns null on exception', () async {
    when(
      () => journalDb.updateJournalEntity(
        any<JournalEntity>(),
        overrideComparison: any<bool>(named: 'overrideComparison'),
        overwrite: any<bool>(named: 'overwrite'),
      ),
    ).thenThrow(Exception('db down'));

    final result = await logic.updateDbEntity(buildEntry());

    expect(result, isNull);
    verify(
      () => loggingService.captureException(
        any<Object>(),
        domain: 'persistence_logic',
        subDomain: 'updateDbEntity',
        stackTrace: any<StackTrace?>(named: 'stackTrace'),
      ),
    ).called(1);
  });

  test('updateDbEntity does not enqueue when enqueueSync is false', () async {
    stubUpdateResult(JournalUpdateResult.applied());

    final result = await logic.updateDbEntity(buildEntry(), enqueueSync: false);

    expect(result, isTrue);
    verifyNever(() => outboxService.enqueueMessage(any<SyncMessage>()));
  });

  glados.Glados(
    glados.any.updateDbEntityScenario,
    glados.ExploreConfig(numRuns: 120),
  ).test(
    'updateDbEntity matches generated notification and sync invariants',
    (
      scenario,
    ) async {
      clearInteractions(updateNotifications);
      clearInteractions(outboxService);
      clearInteractions(fts5Db);
      clearInteractions(notificationService);

      stubUpdateResult(
        scenario.applied
            ? JournalUpdateResult.applied()
            : JournalUpdateResult.skipped(
                reason: JournalUpdateSkipReason.olderOrEqual,
              ),
      );
      when(
        () => journalDb.parentLinkedEntityIds(scenario.entity.id),
      ).thenReturn(MockSelectable<String>(scenario.parentIds));

      final result = await logic.updateDbEntity(
        scenario.entity,
        linkedId: scenario.linkedId,
        enqueueSync: scenario.enqueueSync,
      );

      expect(result, scenario.applied, reason: '$scenario');

      final notificationIds =
          verify(
                () => updateNotifications.notify(captureAny<Set<String>>()),
              ).captured.single
              as Set<String>;
      expect(notificationIds, scenario.expectedNotificationIds);

      verify(
        () => fts5Db.insertText(
          scenario.entity,
          removePrevious: true,
        ),
      ).called(1);
      verify(notificationService.updateBadge).called(1);

      if (scenario.shouldEnqueueSync) {
        verify(
          () => outboxService.enqueueMessage(any<SyncMessage>()),
        ).called(1);
      } else {
        verifyNever(() => outboxService.enqueueMessage(any<SyncMessage>()));
      }
    },
    tags: 'glados',
  );

  test('createDbEntity skips addLabeled when update skipped', () async {
    stubUpdateResult(
      JournalUpdateResult.skipped(
        reason: JournalUpdateSkipReason.olderOrEqual,
      ),
    );

    final entity = buildEntry(clock: const VectorClock({'host': 5}));
    final saved = await logic.createDbEntity(
      entity,
      shouldAddGeolocation: false,
    );

    expect(saved, isFalse);
    verifyNever(() => journalDb.addLabeled(any<JournalEntity>()));
    verifyNever(() => outboxService.enqueueMessage(any<SyncMessage>()));
    verify(
      () => vectorClockService.burnUnboundVectorClock(
        entity.meta.vectorClock,
        reason: any<String>(
          named: 'reason',
          that: contains('createDbEntity write rejected id=entry-id'),
        ),
      ),
    ).called(1);
  });

  glados.Glados(
    glados.any.createDbEntityScenario,
    glados.ExploreConfig(numRuns: 120),
  ).test('createDbEntity matches generated context and sync invariants', (
    scenario,
  ) async {
    clearInteractions(updateNotifications);
    clearInteractions(outboxService);
    clearInteractions(notificationService);
    clearInteractions(journalDb);

    JournalEntity? persistedEntity;
    when(
      () => journalDb.updateJournalEntity(
        any<JournalEntity>(),
        overrideComparison: any<bool>(named: 'overrideComparison'),
        overwrite: any<bool>(named: 'overwrite'),
      ),
    ).thenAnswer((invocation) async {
      persistedEntity = invocation.positionalArguments.first as JournalEntity;
      return scenario.saved
          ? JournalUpdateResult.applied()
          : JournalUpdateResult.skipped(
              reason: JournalUpdateSkipReason.overwritePrevented,
            );
    });
    when(
      () => journalDb.parentLinkedEntityIds(any<String>()),
    ).thenReturn(MockSelectable<String>([]));
    when(
      () => journalDb.upsertEntryLink(any<EntryLink>()),
    ).thenAnswer((_) async => 1);

    final linked = scenario.linkedEntity;
    if (linked != null) {
      when(
        () => journalDb.journalEntityById(scenario.linkedId!),
      ).thenAnswer((_) async => linked);
    }

    final result = await logic.createDbEntity(
      scenario.entity,
      linkedId: scenario.linkedId,
      enqueueSync: scenario.enqueueSync,
      shouldAddGeolocation: false,
    );

    expect(result, scenario.saved, reason: '$scenario');
    expect(persistedEntity, isNotNull, reason: '$scenario');
    expect(persistedEntity!.meta.categoryId, scenario.expectedCategoryId);
    expect(persistedEntity!.meta.private, scenario.expectedPrivate);

    final expectedOutboxMessages =
        (scenario.shouldEnqueueSync ? 1 : 0) +
        (scenario.hasLinkedEntity ? 1 : 0);
    if (expectedOutboxMessages == 0) {
      verifyNever(() => outboxService.enqueueMessage(any<SyncMessage>()));
    } else {
      verify(
        () => outboxService.enqueueMessage(any<SyncMessage>()),
      ).called(expectedOutboxMessages);
    }

    final notifications = verify(
      () => updateNotifications.notify(captureAny<Set<String>>()),
    ).captured.cast<Set<String>>().toList();
    expect(notifications.last, scenario.expectedCreateNotificationIds);

    if (scenario.hasLinkedEntity) {
      expect(notifications.first, {scenario.linkedId, scenario.entityId});
      verify(() => journalDb.upsertEntryLink(any<EntryLink>())).called(1);
    } else {
      verifyNever(() => journalDb.upsertEntryLink(any<EntryLink>()));
    }

    verify(notificationService.updateBadge).called(1);
  }, tags: 'glados');

  group('updateJournalEntity', () {
    test(
      'adds labels only when update applies and reuses metadata',
      () async {
        final labeledCaptures = <JournalEntity>[];
        when(() => journalDb.addLabeled(captureAny())).thenAnswer((
          invocation,
        ) async {
          labeledCaptures.add(
            invocation.positionalArguments.first as JournalEntity,
          );
        });

        logic = TestPersistenceLogic(
          updateDbEntityHandler:
              (
                entity, {
                linkedId,
                enqueueSync = true,
                overrideComparison = false,
                beforeNotify,
              }) async => true,
        );

        final baseEntry = buildEntry();
        final result = await logic.updateJournalEntity(
          baseEntry,
          baseEntry.meta,
        );

        expect(result, isTrue);
        expect(labeledCaptures, hasLength(1));
        final labeledEntity = labeledCaptures.first;
        expect(
          identical(labeledEntity.meta, logic.lastUpdateDbEntity?.meta),
          isTrue,
        );
        expect(logic.updateMetadataCalls, 1);

        clearInteractions(journalDb);
        labeledCaptures.clear();

        logic = TestPersistenceLogic(
          updateDbEntityHandler:
              (
                entity, {
                linkedId,
                enqueueSync = true,
                overrideComparison = false,
                beforeNotify,
              }) async => false,
        );

        final skipped = await logic.updateJournalEntity(
          baseEntry,
          baseEntry.meta,
        );

        expect(skipped, isFalse);
        verifyNever(() => journalDb.addLabeled(any<JournalEntity>()));
      },
    );

    test(
      'updates task priority columns before notifying listeners for task updates',
      () async {
        final testDate = DateTime(2024, 3, 15, 10, 30);
        final callOrder = <String>[];
        Set<String>? notifiedIds;
        final task = Task(
          meta: Metadata(
            id: 'task-id',
            createdAt: testDate,
            updatedAt: testDate,
            dateFrom: testDate,
            dateTo: testDate,
            vectorClock: const VectorClock({'host': 1}),
          ),
          data: TaskData(
            status: TaskStatus.open(
              id: 'status-id',
              createdAt: testDate,
              utcOffset: 60,
            ),
            title: 'task',
            statusHistory: const [],
            dateTo: testDate,
            dateFrom: testDate,
            priority: TaskPriority.p0Urgent,
          ),
        );

        when(() => journalDb.journalEntityById('task-id')).thenAnswer(
          (_) async => task,
        );
        stubUpdateResult(JournalUpdateResult.applied());
        when(
          () => journalDb.updateTaskPriorityColumn(
            id: 'task-id',
            priority: 'P1',
            rank: 1,
          ),
        ).thenAnswer((_) async {
          callOrder.add('priority-column');
        });
        when(
          () => updateNotifications.notify(
            any<Set<String>>(),
            fromSync: any(named: 'fromSync'),
          ),
        ).thenAnswer((invocation) {
          callOrder.add('notify');
          notifiedIds = invocation.positionalArguments.first as Set<String>;
        });

        final updatedTask = task.copyWith(
          data: task.data.copyWith(priority: TaskPriority.p1High),
        );
        final result = await logic.updateJournalEntity(
          updatedTask,
          updatedTask.meta,
        );

        expect(result, isTrue);
        expect(callOrder, equals(['priority-column', 'notify']));
        expect(notifiedIds, contains('task-id'));
      },
    );

    test(
      'skips task priority column updates when updateJournalEntity keeps priority unchanged',
      () async {
        final testDate = DateTime(2024, 3, 15, 10, 30);
        final task = Task(
          meta: Metadata(
            id: 'task-id',
            createdAt: testDate,
            updatedAt: testDate,
            dateFrom: testDate,
            dateTo: testDate,
            vectorClock: const VectorClock({'host': 1}),
          ),
          data: TaskData(
            status: TaskStatus.open(
              id: 'status-id',
              createdAt: testDate,
              utcOffset: 60,
            ),
            title: 'task',
            statusHistory: const [],
            dateTo: testDate,
            dateFrom: testDate,
            priority: TaskPriority.p1High,
          ),
        );

        when(
          () => journalDb.journalEntityById('task-id'),
        ).thenAnswer((_) async => task);
        stubUpdateResult(JournalUpdateResult.applied());

        final result = await logic.updateJournalEntity(task, task.meta);

        expect(result, isTrue);
        verifyNever(
          () => journalDb.updateTaskPriorityColumn(
            id: any(named: 'id'),
            priority: any(named: 'priority'),
            rank: any(named: 'rank'),
          ),
        );
      },
    );
  });

  group('agent execution zone routing', () {
    test(
      'updateDbEntity calls notify when outside agent execution zone',
      () async {
        stubUpdateResult(JournalUpdateResult.applied());

        await logic.updateDbEntity(buildEntry());

        verify(() => updateNotifications.notify(any<Set<String>>())).called(1);
        verifyNever(
          () => updateNotifications.notifyUiOnly(any<Set<String>>()),
        );
      },
    );

    test(
      'updateDbEntity calls notifyUiOnly when inside agent execution zone',
      () async {
        stubUpdateResult(JournalUpdateResult.applied());
        when(
          () => updateNotifications.notifyUiOnly(any<Set<String>>()),
        ).thenReturn(null);

        await runZoned(
          () => logic.updateDbEntity(buildEntry()),
          zoneValues: {agentExecutionZoneKey: true},
        );

        verify(
          () => updateNotifications.notifyUiOnly(any<Set<String>>()),
        ).called(1);
        verifyNever(() => updateNotifications.notify(any<Set<String>>()));
      },
    );
  });

  group('updateJournalEntityText - entity type branches', () {
    test('updates MeasurementEntry with new text and metadata', () async {
      final testDate = DateTime(2024, 3, 15, 10, 30);
      final measurementEntry = JournalEntity.measurement(
        meta: Metadata(
          id: 'measurement-id',
          createdAt: testDate,
          updatedAt: testDate,
          dateFrom: testDate,
          dateTo: testDate,
          vectorClock: const VectorClock({'host': 1}),
        ),
        data: MeasurementData(
          dateFrom: testDate,
          dateTo: testDate,
          value: 500,
          dataTypeId: 'water-type-id',
        ),
        entryText: const EntryText(plainText: 'original text'),
      );

      when(
        () => journalDb.journalEntityById('measurement-id'),
      ).thenAnswer((_) async => measurementEntry);

      logic = TestPersistenceLogic(
        updateDbEntityHandler:
            (
              entity, {
              linkedId,
              enqueueSync = true,
              overrideComparison = false,
              beforeNotify,
            }) async => true,
      );

      const newText = EntryText(plainText: 'updated measurement notes');
      final result = await logic.updateJournalEntityText(
        'measurement-id',
        newText,
        DateTime(2024, 3, 15, 10, 35),
      );

      expect(result, isTrue);
      expect(logic.lastUpdateDbEntity, isA<MeasurementEntry>());
      final updated = logic.lastUpdateDbEntity! as MeasurementEntry;
      expect(updated.entryText?.plainText, 'updated measurement notes');
      expect(updated.data.value, 500);
      expect(updated.data.dataTypeId, 'water-type-id');
      expect(logic.updateMetadataCalls, 1);
    });

    test('updates HabitCompletionEntry with new text and metadata', () async {
      final testDate = DateTime(2024, 3, 15, 10, 30);
      final habitEntry = JournalEntity.habitCompletion(
        meta: Metadata(
          id: 'habit-id',
          createdAt: testDate,
          updatedAt: testDate,
          dateFrom: testDate,
          dateTo: testDate,
          vectorClock: const VectorClock({'host': 1}),
        ),
        data: HabitCompletionData(
          dateFrom: testDate,
          dateTo: testDate,
          habitId: 'flossing-habit-id',
        ),
        entryText: const EntryText(plainText: 'original habit text'),
      );

      when(
        () => journalDb.journalEntityById('habit-id'),
      ).thenAnswer((_) async => habitEntry);

      logic = TestPersistenceLogic(
        updateDbEntityHandler:
            (
              entity, {
              linkedId,
              enqueueSync = true,
              overrideComparison = false,
              beforeNotify,
            }) async => true,
      );

      const newText = EntryText(plainText: 'updated habit notes');
      final result = await logic.updateJournalEntityText(
        'habit-id',
        newText,
        DateTime(2024, 3, 15, 10, 35),
      );

      expect(result, isTrue);
      expect(logic.lastUpdateDbEntity, isA<HabitCompletionEntry>());
      final updated = logic.lastUpdateDbEntity! as HabitCompletionEntry;
      expect(updated.entryText?.plainText, 'updated habit notes');
      expect(updated.data.habitId, 'flossing-habit-id');
      expect(logic.updateMetadataCalls, 1);
    });

    test(
      'returns false when an exception is thrown during the update',
      () async {
        // Force the lookup to throw so the body runs into the catch block.
        // Per the contract documented on updateJournalEntityText (mirroring
        // updateJournalEntity), a caught exception means the write did not
        // commit and callers must see `false`, not a silently-true result.
        when(
          () => journalDb.journalEntityById('boom-id'),
        ).thenThrow(StateError('boom'));

        logic = TestPersistenceLogic();

        const newText = EntryText(plainText: 'whatever');
        final result = await logic.updateJournalEntityText(
          'boom-id',
          newText,
          DateTime(2024, 3, 15, 10, 35),
        );

        expect(result, isFalse);
        verify(
          () => loggingService.captureException(
            any<Object>(),
            domain: 'persistence_logic',
            subDomain: 'updateJournalEntityText',
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
          ),
        ).called(1);
      },
    );
  });

  group('updateJournalEntry', () {
    test('returns false when no fields are provided', () async {
      final result = await logic.updateJournalEntry(
        journalEntityId: 'entry-id',
      );

      expect(result, isFalse);
      verifyNever(() => journalDb.journalEntityById(any<String>()));
    });

    test('updates JournalEntry text, dateFrom, and dateTo', () async {
      final entry = buildEntry();
      when(
        () => journalDb.journalEntityById('entry-id'),
      ).thenAnswer((_) async => entry);

      logic = TestPersistenceLogic(
        updateDbEntityHandler:
            (
              entity, {
              linkedId,
              enqueueSync = true,
              overrideComparison = false,
              beforeNotify,
            }) async => true,
      );

      final result = await logic.updateJournalEntry(
        journalEntityId: 'entry-id',
        entryText: const EntryText(plainText: 'updated text'),
        dateFrom: DateTime(2024, 3, 15, 9),
        dateTo: DateTime(2024, 3, 15, 11),
      );

      expect(result, isTrue);
      expect(logic.lastUpdateDbEntity, isA<JournalEntry>());
      final updated = logic.lastUpdateDbEntity! as JournalEntry;
      expect(updated.entryText?.plainText, 'updated text');
      expect(updated.meta.dateFrom, DateTime(2024, 3, 15, 9));
      expect(updated.meta.dateTo, DateTime(2024, 3, 15, 11));
      expect(logic.updateMetadataCalls, 1);
    });

    test('keeps existing text when entryText is omitted', () async {
      final entry = buildEntry();
      when(
        () => journalDb.journalEntityById('entry-id'),
      ).thenAnswer((_) async => entry);

      logic = TestPersistenceLogic(
        updateDbEntityHandler:
            (
              entity, {
              linkedId,
              enqueueSync = true,
              overrideComparison = false,
              beforeNotify,
            }) async => true,
      );

      final result = await logic.updateJournalEntry(
        journalEntityId: 'entry-id',
        dateTo: DateTime(2024, 3, 15, 12),
      );

      expect(result, isTrue);
      final updated = logic.lastUpdateDbEntity! as JournalEntry;
      expect(updated.entryText?.plainText, 'text');
      expect(updated.meta.dateTo, DateTime(2024, 3, 15, 12));
    });

    test('returns false when entity is missing', () async {
      when(
        () => journalDb.journalEntityById('missing-id'),
      ).thenAnswer((_) async => null);

      final result = await logic.updateJournalEntry(
        journalEntityId: 'missing-id',
        entryText: const EntryText(plainText: 'updated'),
      );

      expect(result, isFalse);
    });

    test('returns false when entity is not a JournalEntry', () async {
      final testDate = DateTime(2024, 3, 15, 10, 30);
      final task = JournalEntity.task(
        meta: Metadata(
          id: 'task-id',
          createdAt: testDate,
          updatedAt: testDate,
          dateFrom: testDate,
          dateTo: testDate,
          vectorClock: const VectorClock({'host': 1}),
        ),
        data: TaskData(
          status: TaskStatus.open(
            id: 'task-id',
            createdAt: testDate,
            utcOffset: 0,
          ),
          dateFrom: testDate,
          dateTo: testDate,
          statusHistory: [],
          title: 'Task',
        ),
      );
      when(
        () => journalDb.journalEntityById('task-id'),
      ).thenAnswer((_) async => task);

      final result = await logic.updateJournalEntry(
        journalEntityId: 'task-id',
        entryText: const EntryText(plainText: 'updated'),
      );

      expect(result, isFalse);
    });

    test('returns false and logs when lookup throws', () async {
      when(
        () => journalDb.journalEntityById('boom-id'),
      ).thenThrow(StateError('boom'));

      final result = await logic.updateJournalEntry(
        journalEntityId: 'boom-id',
        entryText: const EntryText(plainText: 'updated'),
      );

      expect(result, isFalse);
      verify(
        () => loggingService.captureException(
          any<Object>(),
          domain: 'persistence_logic',
          subDomain: 'updateJournalEntry',
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
        ),
      ).called(1);
    });
  });

  group('updateTask - orElse path', () {
    test('logs captureException when entity is not a Task', () async {
      final testDate = DateTime(2024, 3, 15, 10, 30);
      final journalEntry = JournalEntity.journalEntry(
        meta: Metadata(
          id: 'not-a-task-id',
          createdAt: testDate,
          updatedAt: testDate,
          dateFrom: testDate,
          dateTo: testDate,
          vectorClock: const VectorClock({'host': 1}),
        ),
        entryText: const EntryText(plainText: 'just a journal entry'),
      );

      when(
        () => journalDb.journalEntityById('not-a-task-id'),
      ).thenAnswer((_) async => journalEntry);

      final taskData = TaskData(
        status: TaskStatus.open(
          id: 'status-id',
          createdAt: testDate,
          utcOffset: 60,
        ),
        title: 'test task',
        statusHistory: [],
        dateTo: testDate,
        dateFrom: testDate,
      );

      final result = await logic.updateTask(
        journalEntityId: 'not-a-task-id',
        taskData: taskData,
      );

      expect(result, isTrue);
      verify(
        () => loggingService.captureException(
          'not a task',
          domain: 'persistence_logic',
          subDomain: 'updateTask',
        ),
      ).called(1);
    });
  });

  group('updateTask', () {
    test(
      'updates priority columns before notifying listeners for priority changes',
      () async {
        final testDate = DateTime(2024, 3, 15, 10, 30);
        final callOrder = <String>[];
        Set<String>? notifiedIds;
        final task = Task(
          meta: Metadata(
            id: 'task-id',
            createdAt: testDate,
            updatedAt: testDate,
            dateFrom: testDate,
            dateTo: testDate,
            vectorClock: const VectorClock({'host': 1}),
          ),
          data: TaskData(
            status: TaskStatus.open(
              id: 'status-id',
              createdAt: testDate,
              utcOffset: 60,
            ),
            title: 'task',
            statusHistory: const [],
            dateTo: testDate,
            dateFrom: testDate,
            priority: TaskPriority.p1High,
          ),
        );

        when(
          () => journalDb.journalEntityById('task-id'),
        ).thenAnswer((_) async => task);
        stubUpdateResult(JournalUpdateResult.applied());
        when(
          () => journalDb.updateTaskPriorityColumn(
            id: 'task-id',
            priority: 'P0',
            rank: 0,
          ),
        ).thenAnswer((_) async {
          callOrder.add('priority-column');
        });
        when(
          () => updateNotifications.notify(
            any<Set<String>>(),
            fromSync: any(named: 'fromSync'),
          ),
        ).thenAnswer((invocation) {
          callOrder.add('notify');
          notifiedIds = invocation.positionalArguments.first as Set<String>;
        });

        final updatedTaskData = task.data.copyWith(
          priority: TaskPriority.p0Urgent,
        );

        await logic.updateTask(
          journalEntityId: 'task-id',
          taskData: updatedTaskData,
        );

        expect(callOrder, equals(['priority-column', 'notify']));
        expect(notifiedIds, contains('task-id'));
      },
    );
  });

  group('sequence-log integration', () {
    late MockSyncSequenceLogService sequenceLog;

    setUpAll(() => registerFallbackValue(const VectorClock({'host': 0})));

    setUp(() {
      sequenceLog = MockSyncSequenceLogService();
      when(
        () => sequenceLog.recordSentEntry(
          entryId: any(named: 'entryId'),
          vectorClock: any(named: 'vectorClock'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => sequenceLog.recordSentEntryLink(
          linkId: any(named: 'linkId'),
          vectorClock: any(named: 'vectorClock'),
        ),
      ).thenAnswer((_) async {});
      getIt.registerSingleton<SyncSequenceLogService>(sequenceLog);
    });

    test(
      'updateDbEntity records the journal entity sequence after applied write',
      () async {
        stubUpdateResult(JournalUpdateResult.applied());

        final entry = buildEntry();
        final result = await logic.updateDbEntity(entry);

        expect(result, isTrue);
        verify(
          () => sequenceLog.recordSentEntry(
            entryId: entry.meta.id,
            vectorClock: entry.meta.vectorClock!,
          ),
        ).called(1);
      },
    );

    test(
      'updateDbEntity does not record when the write is skipped',
      () async {
        stubUpdateResult(
          JournalUpdateResult.skipped(
            reason: JournalUpdateSkipReason.olderOrEqual,
          ),
        );

        await logic.updateDbEntity(buildEntry());

        verifyNever(
          () => sequenceLog.recordSentEntry(
            entryId: any(named: 'entryId'),
            vectorClock: any(named: 'vectorClock'),
          ),
        );
      },
    );

    test(
      'updateDbEntity sequence-record failure is swallowed and logged via '
      'LoggingService; outbox is still enqueued',
      () async {
        stubUpdateResult(JournalUpdateResult.applied());
        when(
          () => sequenceLog.recordSentEntry(
            entryId: any(named: 'entryId'),
            vectorClock: any(named: 'vectorClock'),
          ),
        ).thenThrow(StateError('sequence ledger boom'));

        final result = await logic.updateDbEntity(buildEntry());

        expect(result, isTrue);
        verify(
          () => loggingService.captureException(
            any<Object>(),
            domain: 'SYNC_SEQUENCE',
            subDomain: 'updateDbEntity.recordSent',
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
          ),
        ).called(1);
        verify(
          () => outboxService.enqueueMessage(any<SyncMessage>()),
        ).called(1);
      },
    );

    test(
      'createDbEntity records the journal entity sequence after saved write',
      () async {
        stubUpdateResult(JournalUpdateResult.applied());
        when(
          () => journalDb.parentLinkedEntityIds(any<String>()),
        ).thenReturn(MockSelectable<String>([]));

        final entity = buildEntry(clock: const VectorClock({'host': 7}));
        final saved = await logic.createDbEntity(
          entity,
          shouldAddGeolocation: false,
        );

        expect(saved, isTrue);
        verify(
          () => sequenceLog.recordSentEntry(
            entryId: entity.meta.id,
            vectorClock: entity.meta.vectorClock!,
          ),
        ).called(1);
      },
    );

    test(
      'createDbEntity sequence-record failure is swallowed and logged via '
      'LoggingService',
      () async {
        stubUpdateResult(JournalUpdateResult.applied());
        when(
          () => journalDb.parentLinkedEntityIds(any<String>()),
        ).thenReturn(MockSelectable<String>([]));
        when(
          () => sequenceLog.recordSentEntry(
            entryId: any(named: 'entryId'),
            vectorClock: any(named: 'vectorClock'),
          ),
        ).thenThrow(StateError('sequence ledger boom'));

        final entity = buildEntry(clock: const VectorClock({'host': 8}));
        final saved = await logic.createDbEntity(
          entity,
          shouldAddGeolocation: false,
        );

        expect(saved, isTrue);
        verify(
          () => loggingService.captureException(
            any<Object>(),
            domain: 'SYNC_SEQUENCE',
            subDomain: 'createDbEntity.recordSent',
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
          ),
        ).called(1);
      },
    );

    test(
      'createLink records the entry-link sequence after the upsert returns >0 '
      'rows',
      () async {
        when(
          () => journalDb.upsertEntryLink(any<EntryLink>()),
        ).thenAnswer((_) async => 1);

        final created = await logic.createLink(
          fromId: 'from-id',
          toId: 'to-id',
        );

        expect(created, isTrue);
        verify(
          () => sequenceLog.recordSentEntryLink(
            linkId: any(named: 'linkId'),
            vectorClock: const VectorClock({'host': 1}),
          ),
        ).called(1);
      },
    );

    test(
      'createLink sequence-record failure is swallowed and routed through '
      'LoggingService.captureException',
      () async {
        when(
          () => journalDb.upsertEntryLink(any<EntryLink>()),
        ).thenAnswer((_) async => 1);
        when(
          () => sequenceLog.recordSentEntryLink(
            linkId: any(named: 'linkId'),
            vectorClock: any(named: 'vectorClock'),
          ),
        ).thenThrow(StateError('sequence ledger boom'));

        final created = await logic.createLink(
          fromId: 'from-id',
          toId: 'to-id',
        );

        expect(created, isTrue);
        verify(
          () => loggingService.captureException(
            any<Object>(),
            domain: 'SYNC_SEQUENCE',
            subDomain: 'createLink.recordSent',
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
          ),
        ).called(1);
      },
    );
  });

  group('updateEvent - orElse path', () {
    test('logs captureException when entity is not an Event', () async {
      final testDate = DateTime(2024, 3, 15, 10, 30);
      final journalEntry = JournalEntity.journalEntry(
        meta: Metadata(
          id: 'not-an-event-id',
          createdAt: testDate,
          updatedAt: testDate,
          dateFrom: testDate,
          dateTo: testDate,
          vectorClock: const VectorClock({'host': 1}),
        ),
        entryText: const EntryText(plainText: 'just a journal entry'),
      );

      when(
        () => journalDb.journalEntityById('not-an-event-id'),
      ).thenAnswer((_) async => journalEntry);

      const eventData = EventData(
        status: EventStatus.tentative,
        title: 'Test Event',
        stars: 3,
      );

      final result = await logic.updateEvent(
        journalEntityId: 'not-an-event-id',
        data: eventData,
      );

      expect(result, isTrue);
      verify(
        () => loggingService.captureException(
          'not an event',
          domain: 'persistence_logic',
          subDomain: 'updateEvent',
        ),
      ).called(1);
    });
  });
}
