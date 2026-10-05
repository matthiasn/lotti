import 'dart:convert';
import 'dart:io';

// Get the getIt instance to inject our mocks
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/geolocation.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/classes/sync/sync_message.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/classes/vector_clock.dart';
import 'package:lotti/database/agents/agent_database.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_types.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_entries.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/logic/repositories/journal_repository.dart';
import 'package:lotti/logic/repositories/relationship_cascade.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/outbox_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../features/sync/matrix/sync_event_processor_test_helpers.dart'
    as sync_harness;
import '../../helpers/commit_evaluating_vector_clock_service.dart';
import '../../helpers/entity_factories.dart';
import '../../helpers/fallbacks.dart';
import '../../helpers/service_overrides.dart';
import '../../mocks/mocks.dart';
import '../../test_data/test_data.dart';
import '../../widget_test_utils.dart';

/// Base metadata fixture for repository tests — every field defaults to the
/// shared 2023 timestamps; pass only what differs.
Metadata testMeta({
  String id = 'test-id',
  String? categoryId,
  DateTime? deletedAt,
  VectorClock? vectorClock,
  bool starred = false,
  bool private = false,
  EntryFlag flag = EntryFlag.none,
}) {
  return Metadata(
    id: id,
    createdAt: DateTime(2023),
    updatedAt: DateTime(2023),
    dateFrom: DateTime(2023),
    dateTo: DateTime(2023),
    starred: starred,
    private: private,
    flag: flag,
    categoryId: categoryId,
    deletedAt: deletedAt,
    vectorClock: vectorClock,
  );
}

/// Journal-entry fixture wrapping [testMeta]; pass only the fields that differ.
///
/// Defaults to the canonical `'Test content'` / `'test'` text used across the
/// mutation and read tests. Provide [meta] when a non-default metadata shape is
/// needed (e.g. a specific id or non-2023 timestamps).
JournalEntity testJournalEntry({
  Metadata? meta,
  String plainText = 'Test content',
  String markdown = 'test',
}) {
  return JournalEntity.journalEntry(
    entryText: EntryText(plainText: plainText, markdown: markdown),
    meta: meta ?? testMeta(),
  );
}

void main() {
  group('JournalRepository', () {
    late MockJournalDb mockJournalDb;
    late MockPersistenceLogic mockPersistenceLogic;
    late MockNotificationService mockNotificationService;
    late MockDomainLogger mockDomainLogger;
    late CommitEvaluatingVectorClockService mockVectorClockService;
    late MockUpdateNotifications mockUpdateNotifications;
    late MockOutboxService mockOutboxService;
    late MockTimeService mockTimeService;
    late JournalRepository repository;

    setUpAll(registerAllFallbackValues);

    setUp(() async {
      mockJournalDb = MockJournalDb();
      mockPersistenceLogic = MockPersistenceLogic();
      mockNotificationService = MockNotificationService();
      mockDomainLogger = MockDomainLogger();
      mockVectorClockService = CommitEvaluatingVectorClockService();
      mockUpdateNotifications = MockUpdateNotifications();
      mockOutboxService = MockOutboxService();
      mockTimeService = MockTimeService();

      await setUpTestGetIt(
        additionalSetup: () {
          getIt
            ..unregister<JournalDb>()
            ..registerSingleton<JournalDb>(mockJournalDb)
            ..unregister<UpdateNotifications>()
            ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
            ..unregister<DomainLogger>()
            ..registerSingleton<DomainLogger>(mockDomainLogger)
            ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
            ..registerSingleton<NotificationService>(mockNotificationService)
            ..registerSingleton<VectorClockService>(mockVectorClockService)
            ..registerSingleton<OutboxService>(mockOutboxService)
            ..registerSingleton<TimeService>(mockTimeService)
            // The relationship repository the cascade writes a person through
            // is built over the agent store, which it reads only when a
            // person is marked important — never here, so a mock that
            // refuses every call proves it.
            ..registerSingleton<AgentDatabase>(MockAgentDatabase());
        },
      );

      // Through the app's provider, so every service reaches the repository
      // the way it does in the app: each provider bridged to the mocks above.
      final container = ProviderContainer(overrides: withServiceOverrides([]));
      addTearDown(container.dispose);
      repository = container.read(journalRepositoryProvider);
    });

    tearDown(() async {
      await tearDownTestGetIt();
    });

    /// The one change handed `PersistenceLogic.updateEntity` for [id],
    /// applied to [stored] — the entry as the write finds it, which may hold
    /// fields set after the caller decided.
    JournalEntity? changedOn(String id, JournalEntity stored) {
      final change =
          verify(
                () => mockPersistenceLogic.updateEntity(id, captureAny()),
              ).captured.single
              as JournalEntity? Function(JournalEntity);
      return change(stored);
    }

    /// [testTask] as stored once its agent set a status and a checklist was
    /// listed on it, after the caller read it.
    final storedSince = testTask.copyWith(
      meta: testTask.meta.copyWith(categoryId: 'existing-category'),
      data: testTask.data.copyWith(
        checklistIds: const ['listed-since'],
        estimate: const Duration(hours: 3),
      ),
    );

    group('updateCategoryId', () {
      setUp(() {
        when(
          () => mockPersistenceLogic.updateEntity(any(), any()),
        ).thenAnswer((_) async => true);
      });

      test('sets the category on the entry as stored, keeping every field '
          'set since (MetaOnStored)', () async {
        final result = await repository.updateCategoryId(
          testTask.id,
          categoryId: 'category-id',
        );

        expect(result, isTrue);
        final written = changedOn(testTask.id, storedSince)! as Task;
        expect(written.meta.categoryId, 'category-id');
        expect(written.data, storedSince.data);
        expect(
          written.meta.copyWith(categoryId: 'existing-category'),
          storedSince.meta,
        );
      });

      test('clears the category when passed null', () async {
        await repository.updateCategoryId(testTask.id, categoryId: null);

        expect(changedOn(testTask.id, storedSince)!.meta.categoryId, isNull);
      });

      test('a write that is not stored is reported as a failure — callers '
          'act on this boolean: a missing entry, or one refused', () async {
        when(
          () => mockPersistenceLogic.updateEntity(any(), any()),
        ).thenAnswer((_) async => false);

        expect(
          await repository.updateCategoryId(
            testTask.id,
            categoryId: 'category-id',
          ),
          isFalse,
        );
      });

      test('a thrown exception is logged and reported as a failed write — '
          'callers act on this boolean, so a swallowed failure would have '
          'them report success on an entity that never moved', () async {
        when(
          () => mockPersistenceLogic.updateEntity(any(), any()),
        ).thenThrow(Exception('Test exception'));

        final result = await repository.updateCategoryId(
          testTask.id,
          categoryId: 'category-id',
        );

        expect(result, isFalse);
        verify(
          () => mockDomainLogger.error(
            LogDomain.persistence,
            any(),
            stackTrace: any(named: 'stackTrace'),
            subDomain: 'updateCategoryId',
          ),
        ).called(1);
      });
    });

    group('deleteJournalEntity', () {
      test('writes a person through the registered RelationshipCascade, '
          'whatever builds it', () async {
        final relationship = JournalEntity.relationship(
          meta: testMeta(id: 'rel-1'),
          data: RelationshipData(
            title: 'Anna',
            status: RelationshipStatus.active(
              id: 'status-1',
              createdAt: DateTime(2023),
              utcOffset: 0,
            ),
          ),
        );
        when(
          () => mockJournalDb.journalEntityById('rel-1'),
        ).thenAnswer((_) async => relationship);
        final cascade = _RecordingCascade(deleteResult: false);
        getIt
          ..unregister<RelationshipCascadeFactory>()
          ..registerSingleton<RelationshipCascadeFactory>(
            (journalRepository, persistenceLogic) {
              expect(journalRepository, same(repository));
              return cascade;
            },
          );

        final result = await repository.deleteJournalEntity('rel-1');

        // The cascade's own answer is the delete's answer, and the journal
        // layer writes nothing for the person itself.
        expect(result, isFalse);
        expect(cascade.deleted, ['rel-1']);
        verifyNever(
          () => mockPersistenceLogic.updateDbEntity(
            any(),
            precondition: any(named: 'precondition'),
          ),
        );
      });

      test('routes a RelationshipEntry through the check-in cascade — the '
          'ADR 0037 §5 invariant holds on the generic delete path too '
          '(deep links included), not only on the People pages', () async {
        final relationship = JournalEntity.relationship(
          meta: testMeta(id: 'rel-1'),
          data: RelationshipData(
            title: 'Anna',
            status: RelationshipStatus.active(
              id: 'status-1',
              createdAt: DateTime(2023),
              utcOffset: 0,
            ),
          ),
        );
        final checkIn =
            JournalEntity.checkIn(
                  meta: testMeta(id: 'check-1'),
                  data: const CheckInData(
                    relationshipId: 'rel-1',
                    interactionType: CheckInInteractionType.call,
                  ),
                )
                as CheckInEntry;
        when(
          () => mockJournalDb.journalEntityById('rel-1'),
        ).thenAnswer((_) async => relationship);
        when(
          () => mockJournalDb.getAllCheckInsForRelationship('rel-1'),
        ).thenAnswer((_) async => [checkIn]);
        // The check-in holds no entries of its own to tombstone with it.
        when(
          () => mockJournalDb.linksFromIds(['check-1']),
        ).thenReturn(MockSelectable<LinkedDbEntry>(const []));
        when(
          () => mockPersistenceLogic.updateMetadata(
            any(),
            deletedAt: any(named: 'deletedAt'),
          ),
        ).thenAnswer(
          (invocation) async =>
              (invocation.positionalArguments.first as Metadata).copyWith(
                deletedAt: DateTime(2024, 3, 15, 11),
              ),
        );
        when(
          () => mockPersistenceLogic.updateDbEntity(any()),
        ).thenAnswer((_) async => true);

        final result = await repository.deleteJournalEntity('rel-1');

        expect(result, isTrue);
        final tombstoned = verify(
          () => mockPersistenceLogic.updateDbEntity(captureAny()),
        ).captured.cast<JournalEntity>();
        // Relationship first (a half-finished cascade reads as "gone"),
        // then its check-in — never the relationship alone.
        expect(tombstoned, hasLength(2));
        expect(tombstoned.first, isA<RelationshipEntry>());
        expect(tombstoned.last, isA<CheckInEntry>());
        expect(
          tombstoned.every((e) => e.meta.deletedAt != null),
          isTrue,
        );
      });

      test(
        'logs to DomainLogger and returns false when the lookup throws',
        () async {
          when(
            () => mockJournalDb.journalEntityById(any()),
          ).thenThrow(Exception('db exploded'));

          final result = await repository.deleteJournalEntity('boom-id');

          // Nothing was deleted, and the callers act on that: a checklist
          // operation keeps its intent, the entry page stays open.
          expect(result, isFalse);
          verify(
            () => mockDomainLogger.error(
              LogDomain.persistence,
              any(),
              stackTrace: any(named: 'stackTrace'),
              subDomain: 'deleteJournalEntity',
            ),
          ).called(1);
        },
      );

      // A delete that does not land is reported: the checklist membership
      // intents keep the operation for the next start, and the page stays
      // open (`specs/tla/ChecklistMembership.tla`, DeleteReportsFailure).
      for (final (name, outcome) in [
        ('refused', Future<bool?>.value(false)),
        ('fails', Future<bool?>.value()),
      ]) {
        test('a tombstone write that is $name is reported as not deleted, '
            'and leaves the running timer alone', () async {
          final entry = testJournalEntry();
          when(
            () => mockJournalDb.journalEntityById(entry.id),
          ).thenAnswer((_) async => entry);
          when(
            () => mockPersistenceLogic.updateMetadata(
              any(),
              deletedAt: any(named: 'deletedAt'),
            ),
          ).thenAnswer(
            (invocation) async =>
                invocation.positionalArguments.first as Metadata,
          );
          when(
            () => mockPersistenceLogic.updateDbEntity(
              any(),
              precondition: any(named: 'precondition'),
            ),
          ).thenAnswer((_) => outcome);
          when(() => mockTimeService.getCurrent()).thenReturn(entry);
          // The stored row is still live: nothing was deleted.
          when(
            () => mockJournalDb.journalEntityByIdIncludingDeleted(entry.id),
          ).thenAnswer((_) async => entry);

          expect(await repository.deleteJournalEntity(entry.id), isFalse);
          verifyNever(() => mockTimeService.stop());
          verifyNever(() => mockNotificationService.updateBadge());
        });
      }

      test('a tombstone that committed although work after the write threw '
          'is reported as deleted', () async {
        // updateDbEntity answers null too when the search index or the
        // badge throws after the row was written.
        final entry = testJournalEntry();
        when(
          () => mockJournalDb.journalEntityById(entry.id),
        ).thenAnswer((_) async => entry);
        when(
          () => mockPersistenceLogic.updateMetadata(
            any(),
            deletedAt: any(named: 'deletedAt'),
          ),
        ).thenAnswer(
          (invocation) async =>
              invocation.positionalArguments.first as Metadata,
        );
        when(
          () => mockPersistenceLogic.updateDbEntity(
            any(),
            precondition: any(named: 'precondition'),
          ),
        ).thenAnswer((_) async => null);
        when(
          () => mockJournalDb.journalEntityByIdIncludingDeleted(entry.id),
        ).thenAnswer(
          (_) async => entry.copyWith(
            meta: entry.meta.copyWith(deletedAt: DateTime(2024, 3, 15, 11)),
          ),
        );
        when(() => mockTimeService.getCurrent()).thenReturn(entry);
        when(
          () => mockTimeService.stop(persistEnd: any(named: 'persistEnd')),
        ).thenAnswer((_) async {});
        when(
          () => mockNotificationService.updateBadge(),
        ).thenAnswer((_) async {});

        expect(await repository.deleteJournalEntity(entry.id), isTrue);
        verify(() => mockTimeService.stop(persistEnd: false)).called(1);
      });

      test('the tombstone is built on the entry as stored: a version stored '
          'while it was written is built on again', () async {
        final entry = testJournalEntry();
        final since = entry.copyWith(
          meta: entry.meta.copyWith(
            starred: true,
            vectorClock: const VectorClock({'agent': 1}),
          ),
        );
        var reads = 0;
        when(
          () => mockJournalDb.journalEntityById(entry.id),
        ).thenAnswer((_) async => reads++ < 2 ? entry : since);
        when(
          () => mockPersistenceLogic.updateMetadata(
            any(),
            deletedAt: any(named: 'deletedAt'),
          ),
        ).thenAnswer(
          (invocation) async =>
              (invocation.positionalArguments.first as Metadata).copyWith(
                deletedAt: DateTime(2024, 3, 15, 11),
              ),
        );
        final written = <JournalEntity>[];
        when(
          () => mockPersistenceLogic.updateDbEntity(
            any(),
            precondition: any(named: 'precondition'),
          ),
        ).thenAnswer((invocation) async {
          written.add(invocation.positionalArguments.first as JournalEntity);
          // The first write is refused: the row moved under it.
          return written.length > 1;
        });
        when(() => mockTimeService.getCurrent()).thenReturn(null);
        when(
          () => mockNotificationService.updateBadge(),
        ).thenAnswer((_) async {});

        expect(await repository.deleteJournalEntity(entry.id), isTrue);
        expect(written, hasLength(2));
        expect(written.last.meta.starred, isTrue);
        expect(written.last.meta.deletedAt, isNotNull);
      });

      test('marks the entity as deleted and returns true on success', () async {
        // Arrange
        const journalEntityId = 'test-id';

        final testEntity = testJournalEntry();

        final updatedMeta = testEntity.meta.copyWith(
          deletedAt: DateTime(2024, 3, 15, 11),
          updatedAt: DateTime(2024, 3, 15, 11),
        );

        // Mock the journalEntityById call
        when(
          () => mockJournalDb.journalEntityById(journalEntityId),
        ).thenAnswer((_) async => testEntity);

        // Mock the updateMetadata call
        when(
          () => mockPersistenceLogic.updateMetadata(
            testEntity.meta,
            deletedAt: any(named: 'deletedAt'),
          ),
        ).thenAnswer((_) async => updatedMeta);

        // Mock the updateDbEntity call
        when(
          () => mockPersistenceLogic.updateDbEntity(
            any(),
            precondition: any(named: 'precondition'),
          ),
        ).thenAnswer((_) async => true);

        // Mock the updateBadge call
        when(
          () => mockNotificationService.updateBadge(),
        ).thenAnswer((_) async {});

        // Act
        final result = await repository.deleteJournalEntity(journalEntityId);

        // Assert
        expect(result, isTrue);
        verify(
          () => mockPersistenceLogic.updateMetadata(
            testEntity.meta,
            deletedAt: any(named: 'deletedAt'),
          ),
        ).called(1);
        verify(
          () => mockPersistenceLogic.updateDbEntity(
            any(),
            precondition: any(named: 'precondition'),
          ),
        ).called(1);
        verify(() => mockNotificationService.updateBadge()).called(1);
      });

      test('returns false when journal entity not found', () async {
        // Arrange
        const journalEntityId = 'non-existent-id';

        // Mock the journalEntityById call to return null
        when(
          () => mockJournalDb.journalEntityById(journalEntityId),
        ).thenAnswer((_) async => null);

        // Act
        final result = await repository.deleteJournalEntity(journalEntityId);

        // Assert
        expect(result, isFalse);
        verifyNever(
          () => mockPersistenceLogic.updateMetadata(
            any(),
            deletedAt: any(named: 'deletedAt'),
          ),
        );
        verifyNever(
          () => mockPersistenceLogic.updateDbEntity(
            any(),
            precondition: any(named: 'precondition'),
          ),
        );
        verifyNever(() => mockNotificationService.updateBadge());
      });

      test('stops timer when deleting an active timer entry', () async {
        // Arrange
        const journalEntityId = 'active-timer-id';

        final testEntity = testJournalEntry(
          plainText: 'Timer entry',
          markdown: 'timer',
          meta: testMeta(id: journalEntityId),
        );

        final updatedMeta = testEntity.meta.copyWith(
          deletedAt: DateTime(2024, 3, 15, 11),
          updatedAt: DateTime(2024, 3, 15, 11),
        );

        // Mock the journalEntityById call
        when(
          () => mockJournalDb.journalEntityById(journalEntityId),
        ).thenAnswer((_) async => testEntity);

        // Mock the updateMetadata call
        when(
          () => mockPersistenceLogic.updateMetadata(
            testEntity.meta,
            deletedAt: any(named: 'deletedAt'),
          ),
        ).thenAnswer((_) async => updatedMeta);

        // Mock the updateDbEntity call
        when(
          () => mockPersistenceLogic.updateDbEntity(
            any(),
            precondition: any(named: 'precondition'),
          ),
        ).thenAnswer((_) async => true);

        // Mock the updateBadge call
        when(
          () => mockNotificationService.updateBadge(),
        ).thenAnswer((_) async {});

        // Mock TimeService.getCurrent to return the current timer entry
        when(() => mockTimeService.getCurrent()).thenReturn(testEntity);

        // Mock TimeService.stop
        when(
          () => mockTimeService.stop(persistEnd: any(named: 'persistEnd')),
        ).thenAnswer((_) async {});

        // Act
        final result = await repository.deleteJournalEntity(journalEntityId);

        // Assert
        expect(result, isTrue);
        verify(
          () => mockPersistenceLogic.updateMetadata(
            testEntity.meta,
            deletedAt: any(named: 'deletedAt'),
          ),
        ).called(1);
        verify(
          () => mockPersistenceLogic.updateDbEntity(
            any(),
            precondition: any(named: 'precondition'),
          ),
        ).called(1);
        verify(() => mockNotificationService.updateBadge()).called(1);

        // Verify timer was stopped
        verify(() => mockTimeService.getCurrent()).called(1);
        // A deleted entry has no end left to write.
        verify(() => mockTimeService.stop(persistEnd: false)).called(1);
      });

      test('does not stop timer when deleting a non-active entry', () async {
        // Arrange
        const journalEntityId = 'non-active-timer-id';
        const activeTimerId = 'different-active-timer-id';

        final testEntity = testJournalEntry(
          plainText: 'Non-active entry',
          meta: testMeta(id: journalEntityId),
        );

        final activeTimer = testJournalEntry(
          plainText: 'Active timer',
          markdown: 'timer',
          meta: testMeta(id: activeTimerId),
        );

        final updatedMeta = testEntity.meta.copyWith(
          deletedAt: DateTime(2024, 3, 15, 11),
          updatedAt: DateTime(2024, 3, 15, 11),
        );

        // Mock the journalEntityById call
        when(
          () => mockJournalDb.journalEntityById(journalEntityId),
        ).thenAnswer((_) async => testEntity);

        // Mock the updateMetadata call
        when(
          () => mockPersistenceLogic.updateMetadata(
            testEntity.meta,
            deletedAt: any(named: 'deletedAt'),
          ),
        ).thenAnswer((_) async => updatedMeta);

        // Mock the updateDbEntity call
        when(
          () => mockPersistenceLogic.updateDbEntity(
            any(),
            precondition: any(named: 'precondition'),
          ),
        ).thenAnswer((_) async => true);

        // Mock the updateBadge call
        when(
          () => mockNotificationService.updateBadge(),
        ).thenAnswer((_) async {});

        // Mock TimeService.getCurrent to return a DIFFERENT active timer
        when(() => mockTimeService.getCurrent()).thenReturn(activeTimer);

        // Mock TimeService.stop (should NOT be called)
        when(() => mockTimeService.stop()).thenAnswer((_) async {});

        // Act
        final result = await repository.deleteJournalEntity(journalEntityId);

        // Assert
        expect(result, isTrue);
        verify(
          () => mockPersistenceLogic.updateMetadata(
            testEntity.meta,
            deletedAt: any(named: 'deletedAt'),
          ),
        ).called(1);
        verify(
          () => mockPersistenceLogic.updateDbEntity(
            any(),
            precondition: any(named: 'precondition'),
          ),
        ).called(1);
        verify(() => mockNotificationService.updateBadge()).called(1);

        // Verify timer was NOT stopped (different ID)
        verify(() => mockTimeService.getCurrent()).called(1);
        verifyNever(
          () => mockTimeService.stop(persistEnd: any(named: 'persistEnd')),
        );
      });

      // The timer's entry stays when its task is deleted: the timer stops
      // and writes the end, so the time tracked until the deletion is kept
      // and nothing keeps running for a task that is gone.
      for (final forThisTask in [true, false]) {
        test(
          'deleting a task ${forThisTask ? 'stops' : 'leaves'} the timer '
          'running ${forThisTask ? 'for it' : 'for another task'}',
          () async {
            const taskId = 'task-with-timer';
            final task = testJournalEntry(
              plainText: 'The task',
              meta: testMeta(id: taskId),
            );
            final timerEntry = testJournalEntry(
              plainText: 'Timer',
              meta: testMeta(id: 'timer-entry'),
            );
            when(
              () => mockJournalDb.journalEntityById(taskId),
            ).thenAnswer((_) async => task);
            when(
              () => mockPersistenceLogic.updateMetadata(
                task.meta,
                deletedAt: any(named: 'deletedAt'),
              ),
            ).thenAnswer(
              (_) async => task.meta.copyWith(deletedAt: DateTime(2024, 3, 15)),
            );
            when(
              () => mockPersistenceLogic.updateDbEntity(
                any(),
                precondition: any(named: 'precondition'),
              ),
            ).thenAnswer((_) async => true);
            when(
              () => mockNotificationService.updateBadge(),
            ).thenAnswer((_) async {});
            when(() => mockTimeService.getCurrent()).thenReturn(timerEntry);
            when(() => mockTimeService.linkedFrom).thenReturn(
              forThisTask
                  ? task
                  : testJournalEntry(
                      plainText: 'Another task',
                      meta: testMeta(id: 'another-task'),
                    ),
            );
            when(
              () => mockTimeService.stop(persistEnd: any(named: 'persistEnd')),
            ).thenAnswer((_) async {});

            expect(await repository.deleteJournalEntity(taskId), isTrue);

            if (forThisTask) {
              // The end is written: the default.
              verify(() => mockTimeService.stop()).called(1);
            } else {
              verifyNever(
                () =>
                    mockTimeService.stop(persistEnd: any(named: 'persistEnd')),
              );
            }
          },
        );
      }

      test('handles null timer when deleting entry', () async {
        // Arrange
        const journalEntityId = 'test-id';

        final testEntity = testJournalEntry();

        final updatedMeta = testEntity.meta.copyWith(
          deletedAt: DateTime(2024, 3, 15, 11),
          updatedAt: DateTime(2024, 3, 15, 11),
        );

        // Mock the journalEntityById call
        when(
          () => mockJournalDb.journalEntityById(journalEntityId),
        ).thenAnswer((_) async => testEntity);

        // Mock the updateMetadata call
        when(
          () => mockPersistenceLogic.updateMetadata(
            testEntity.meta,
            deletedAt: any(named: 'deletedAt'),
          ),
        ).thenAnswer((_) async => updatedMeta);

        // Mock the updateDbEntity call
        when(
          () => mockPersistenceLogic.updateDbEntity(
            any(),
            precondition: any(named: 'precondition'),
          ),
        ).thenAnswer((_) async => true);

        // Mock the updateBadge call
        when(
          () => mockNotificationService.updateBadge(),
        ).thenAnswer((_) async {});

        // Mock TimeService.getCurrent to return null (no active timer)
        when(() => mockTimeService.getCurrent()).thenReturn(null);

        // Mock TimeService.stop (should NOT be called)
        when(() => mockTimeService.stop()).thenAnswer((_) async {});

        // Act
        final result = await repository.deleteJournalEntity(journalEntityId);

        // Assert
        expect(result, isTrue);
        verify(
          () => mockPersistenceLogic.updateMetadata(
            testEntity.meta,
            deletedAt: any(named: 'deletedAt'),
          ),
        ).called(1);
        verify(
          () => mockPersistenceLogic.updateDbEntity(
            any(),
            precondition: any(named: 'precondition'),
          ),
        ).called(1);
        verify(() => mockNotificationService.updateBadge()).called(1);

        // Verify timer was NOT stopped (no active timer)
        verify(() => mockTimeService.getCurrent()).called(1);
        verifyNever(
          () => mockTimeService.stop(persistEnd: any(named: 'persistEnd')),
        );
      });
    });

    group('updateJournalEntityDate', () {
      final dateFrom = DateTime(2023);
      final dateTo = DateTime(2023, 1, 2);

      setUp(() {
        when(() => mockTimeService.updateCurrent(any())).thenReturn(null);
      });

      test('sets the range on the entry as stored, keeping every field set '
          'since, and hands the running timer that version', () async {
        // The write applies the change to the stored entry and lands.
        when(
          () => mockPersistenceLogic.updateEntity(testTask.id, any()),
        ).thenAnswer((invocation) async {
          (invocation.positionalArguments[1]
              as JournalEntity? Function(JournalEntity))(storedSince);
          return true;
        });

        final result = await repository.updateJournalEntityDate(
          testTask.id,
          dateFrom: dateFrom,
          dateTo: dateTo,
        );

        expect(result, isTrue);
        final written = changedOn(testTask.id, storedSince)! as Task;
        expect(written.meta.dateFrom, dateFrom);
        expect(written.meta.dateTo, dateTo);
        expect(written.data, storedSince.data);
        final current =
            verify(
                  () => mockTimeService.updateCurrent(captureAny()),
                ).captured.single
                as JournalEntity;
        expect(current.meta.dateTo, dateTo);
        expect((current as Task).data.checklistIds, ['listed-since']);
      });

      test('a write that is not stored is reported as a failure and leaves '
          'the running timer alone', () async {
        when(
          () => mockPersistenceLogic.updateEntity(any(), any()),
        ).thenAnswer((_) async => false);

        final result = await repository.updateJournalEntityDate(
          'non-existent-id',
          dateFrom: dateFrom,
          dateTo: dateTo,
        );

        expect(result, isFalse);
        verifyNever(() => mockTimeService.updateCurrent(any()));
      });

      test('a thrown exception is logged and reported as a failure', () async {
        when(
          () => mockPersistenceLogic.updateEntity(any(), any()),
        ).thenThrow(Exception('Test exception'));

        final result = await repository.updateJournalEntityDate(
          testTask.id,
          dateFrom: dateFrom,
          dateTo: dateTo,
        );

        expect(result, isFalse);
        verify(
          () => mockDomainLogger.error(
            LogDomain.persistence,
            any(),
            stackTrace: any(named: 'stackTrace'),
            subDomain: 'updateJournalEntityDate',
          ),
        ).called(1);
      });
    });

    group('updateJournalEntity', () {
      test('delegates to PersistenceLogic and returns the result', () async {
        // Arrange
        final testEntity = testJournalEntry();

        // Mock the updateJournalEntity call
        when(
          () => mockPersistenceLogic.updateJournalEntity(
            testEntity,
            testEntity.meta,
          ),
        ).thenAnswer((_) async => true);

        // Act
        final result = await repository.updateJournalEntity(testEntity);

        // Assert
        expect(result, isTrue);
        verify(
          () => mockPersistenceLogic.updateJournalEntity(
            testEntity,
            testEntity.meta,
          ),
        ).called(1);
      });

      test('onlyIfUnchanged writes only while the stored row is still the '
          'version the entity was built on', () async {
        final entity = testJournalEntry().copyWith(
          meta: testJournalEntry().meta.copyWith(
            vectorClock: const VectorClock({'host': 3}),
          ),
        );
        final preconditions = <Future<bool> Function()?>[];
        when(
          () => mockPersistenceLogic.updateJournalEntity(
            any(),
            any(),
            precondition: any(named: 'precondition'),
          ),
        ).thenAnswer((invocation) async {
          preconditions.add(
            invocation.namedArguments[#precondition]
                as Future<bool> Function()?,
          );
          return true;
        });
        // Another version was stored since the entity was read.
        when(
          () => mockJournalDb.isStoredVersion(
            entity.id,
            const VectorClock({'host': 3}),
          ),
        ).thenAnswer((_) async => false);

        await repository.updateJournalEntity(entity, onlyIfUnchanged: true);
        await repository.updateJournalEntity(entity);

        expect(preconditions, hasLength(2));
        expect(await preconditions.first!(), isFalse);
        expect(preconditions.last, isNull);
      });

      group('for a task', () {
        final stale = testTask.copyWith(
          data: testTask.data.copyWith(
            checklistIds: ['kept'],
            title: 'agent retitled',
          ),
        );
        Task storedAt(int counter, List<String> checklistIds) =>
            testTask.copyWith(
              meta: testTask.meta.copyWith(
                vectorClock: VectorClock({'host': counter}),
              ),
              data: testTask.data.copyWith(checklistIds: checklistIds),
            );

        /// Stubs the task's reads to answer [reads] in turn, the last one
        /// from then on.
        void stubReads(List<Task?> reads) {
          final pending = [...reads];
          when(
            () => mockJournalDb.journalEntityById(testTask.meta.id),
          ).thenAnswer(
            (_) async =>
                pending.length > 1 ? pending.removeAt(0) : pending.single,
          );
        }

        /// Stubs the writes to answer [answers] in turn.
        void stubWrites(List<bool> answers) {
          final pending = [...answers];
          when(
            () => mockPersistenceLogic.updateJournalEntity(
              any(),
              any(),
              precondition: any(named: 'precondition'),
            ),
          ).thenAnswer((_) async => pending.removeAt(0));
        }

        List<Object?> capturedWrites() => verify(
          () => mockPersistenceLogic.updateJournalEntity(
            captureAny(),
            stale.meta,
            precondition: captureAny(named: 'precondition'),
          ),
        ).captured;

        test(
          "keeps the checklists its stored row lists — the caller's copy "
          'was read before a checklist was added, and saving its title must '
          'not drop that checklist (ChecklistMembership.tla)',
          () async {
            stubReads([
              storedAt(1, ['kept', 'new']),
            ]);
            stubWrites([true]);

            final result = await repository.updateJournalEntity(stale);

            expect(result, isTrue);
            final written = capturedWrites().first! as Task;
            expect(written.data.title, 'agent retitled');
            expect(written.data.checklistIds, ['kept', 'new']);
          },
        );

        test(
          'joins the applied agent changes its stored row records with the '
          "ones the caller's copy adds (ADR 0098)",
          () async {
            final stored = storedAt(1, ['kept']);
            stubReads([
              stored.copyWith(
                data: stored.data.copyWith(appliedChangeEffects: {'set-1:0'}),
              ),
            ]);
            stubWrites([true]);

            final result = await repository.updateJournalEntity(
              stale.copyWith(
                data: stale.data.copyWith(appliedChangeEffects: {'set-2:0'}),
              ),
            );

            expect(result, isTrue);
            final written = capturedWrites().first! as Task;
            expect(written.data.title, 'agent retitled');
            expect(written.data.appliedChangeEffects, {'set-1:0', 'set-2:0'});
          },
        );

        test(
          'writes only while the row it took the checklists from is still '
          'stored',
          () async {
            stubReads([
              storedAt(4, ['kept', 'new']),
            ]);
            stubWrites([true]);
            when(
              () => mockJournalDb.isStoredVersion(any(), any()),
            ).thenAnswer((_) async => false);

            await repository.updateJournalEntity(stale);

            final precondition =
                capturedWrites()[1]! as Future<bool> Function();
            expect(await precondition(), isFalse);
            verify(
              () => mockJournalDb.isStoredVersion(
                testTask.meta.id,
                const VectorClock({'host': 4}),
              ),
            ).called(1);
          },
        );

        test(
          'a write refused because a checklist was listed meanwhile is '
          'built again on the row that lists it',
          () async {
            stubReads([
              storedAt(1, ['kept', 'new']),
              storedAt(1, ['kept', 'new']),
              storedAt(2, ['kept', 'new', 'newer']),
            ]);
            stubWrites([false, true]);

            final result = await repository.updateJournalEntity(stale);

            expect(result, isTrue);
            final captured = capturedWrites();
            final writes = [captured[0]! as Task, captured[2]! as Task];
            expect(
              writes.map((task) => task.data.checklistIds),
              [
                ['kept', 'new'],
                ['kept', 'new', 'newer'],
              ],
            );
            expect(writes.last.data.title, 'agent retitled');
          },
        );

        test(
          'without a stored task it is written as given, with no '
          'precondition',
          () async {
            stubReads([null]);
            when(
              () => mockPersistenceLogic.updateJournalEntity(
                stale,
                stale.meta,
              ),
            ).thenAnswer((_) async => true);

            final result = await repository.updateJournalEntity(stale);

            expect(result, isTrue);
            verify(
              () => mockPersistenceLogic.updateJournalEntity(
                stale,
                stale.meta,
              ),
            ).called(1);
            verifyNever(
              () => mockPersistenceLogic.updateJournalEntity(
                any(),
                any(),
                precondition: any(
                  named: 'precondition',
                  that: isNotNull,
                ),
              ),
            );
          },
        );
      });

      test('handles exceptions and returns false', () async {
        // Arrange
        final testEntity = testJournalEntry();

        // Mock the updateJournalEntity call to throw an exception
        when(
          () => mockPersistenceLogic.updateJournalEntity(
            testEntity,
            testEntity.meta,
          ),
        ).thenThrow(Exception('Test exception'));

        // Act
        final result = await repository.updateJournalEntity(testEntity);

        // Assert
        expect(result, isFalse);
        verify(
          () => mockDomainLogger.error(
            LogDomain.persistence,
            any(),
            stackTrace: any(named: 'stackTrace'),
            subDomain: 'updateJournalEntity',
          ),
        ).called(1);
      });
    });

    group('updateLink', () {
      test(
        'returns false without notifying when upsertEntryLink writes 0 rows '
        '(identical row already exists inside the VC scope)',
        () async {
          final testLink = EntryLink.basic(
            id: 'link-id',
            fromId: 'from-id',
            toId: 'to-id',
            createdAt: DateTime(2023),
            updatedAt: DateTime(2023),
            vectorClock: null,
          );
          final changed = testLink.copyWith(hidden: true);

          when(
            () => mockJournalDb.entryLinkById(changed.id),
          ).thenAnswer((_) async => testLink);
          when(
            () => mockVectorClockService.getNextVectorClock(
              previous: any(named: 'previous'),
              payload: any(named: 'payload'),
            ),
          ).thenAnswer((_) async => const VectorClock({'node1': 1}));
          // Identical row already on disk: zero rows written.
          when(
            () => mockJournalDb.upsertEntryLink(any()),
          ).thenAnswer((_) async => 0);

          final result = await repository.updateLink(changed);

          expect(result, isFalse);
          // The reserved vector-clock tick is released, not committed.
          expect(mockVectorClockService.commits, [false]);
          verifyNever(() => mockUpdateNotifications.notify(any()));
          verifyNever(() => mockOutboxService.enqueueMessage(any()));
        },
      );

      test(
        'logs the outbox failure and still returns true when enqueueMessage '
        'throws after the row was written',
        () async {
          final testLink = EntryLink.basic(
            id: 'link-id',
            fromId: 'from-id',
            toId: 'to-id',
            createdAt: DateTime(2023),
            updatedAt: DateTime(2023),
            vectorClock: null,
          );
          final changed = testLink.copyWith(hidden: true);

          when(
            () => mockJournalDb.entryLinkById(changed.id),
          ).thenAnswer((_) async => testLink);
          when(
            () => mockVectorClockService.getNextVectorClock(
              previous: any(named: 'previous'),
              payload: any(named: 'payload'),
            ),
          ).thenAnswer((_) async => const VectorClock({'node1': 1}));
          when(
            () => mockJournalDb.upsertEntryLink(any()),
          ).thenAnswer((_) async => 1);
          when(
            () => mockUpdateNotifications.notify(any()),
          ).thenAnswer((_) async {});
          when(
            () => mockOutboxService.enqueueMessage(any()),
          ).thenThrow(Exception('outbox unavailable'));

          final result = await repository.updateLink(changed);

          // The local write landed; an outbox failure must not undo it.
          expect(result, isTrue);
          verify(
            () => mockDomainLogger.error(
              LogDomain.sync,
              any(),
              message: any(named: 'message'),
              stackTrace: any(named: 'stackTrace'),
              subDomain: 'updateLink.enqueue',
            ),
          ).called(1);
        },
      );

      test('updates the link and enqueues a sync message', () async {
        // Arrange
        final testLink = EntryLink.basic(
          id: 'link-id',
          fromId: 'from-id',
          toId: 'to-id',
          createdAt: DateTime(2023),
          updatedAt: DateTime(2023),
          vectorClock: null,
        );
        final updatedLink = testLink.copyWith(hidden: true);

        when(
          () => mockJournalDb.entryLinkById(updatedLink.id),
        ).thenAnswer((_) async => testLink);

        // Mock VectorClockService
        when(
          () => mockVectorClockService.getNextVectorClock(
            previous: any(named: 'previous'),
            payload: any(named: 'payload'),
          ),
        ).thenAnswer((_) async => const VectorClock({'node1': 1}));

        // Mock JournalDb
        when(
          () => mockJournalDb.upsertEntryLink(any()),
        ).thenAnswer((_) async => 1);

        // Mock UpdateNotifications
        when(
          () => mockUpdateNotifications.notify(any()),
        ).thenAnswer((_) async {});

        // Mock OutboxService
        when(
          () => mockOutboxService.enqueueMessage(any()),
        ).thenAnswer((_) async {});

        // Act
        final result = await repository.updateLink(updatedLink);

        // Assert
        expect(result, isTrue);
        expect(mockVectorClockService.commits, [true]);
        verify(() => mockJournalDb.entryLinkById(updatedLink.id)).called(1);
        verify(
          () => mockVectorClockService.getNextVectorClock(
            previous: any(named: 'previous'),
            payload: any(named: 'payload'),
          ),
        ).called(1);
        verify(() => mockJournalDb.upsertEntryLink(any())).called(1);
        verify(
          () => mockUpdateNotifications.notify({
            testLink.fromId,
            testLink.toId,
            linkNotification,
          }),
        ).called(1);
        verify(() => mockOutboxService.enqueueMessage(any())).called(1);
      });

      test('skips update when the link is unchanged', () async {
        // Arrange
        final testLink = EntryLink.basic(
          id: 'link-id',
          fromId: 'from-id',
          toId: 'to-id',
          createdAt: DateTime(2023),
          updatedAt: DateTime(2023),
          vectorClock: null,
        );
        final existingLink = testLink.copyWith(hidden: false);

        when(
          () => mockJournalDb.entryLinkById(testLink.id),
        ).thenAnswer((_) async => existingLink);

        // Act
        final result = await repository.updateLink(testLink);

        // Assert
        expect(result, isFalse);
        verify(() => mockJournalDb.entryLinkById(testLink.id)).called(1);
        verifyNever(
          () => mockVectorClockService.getNextVectorClock(
            previous: any(named: 'previous'),
            payload: any(named: 'payload'),
          ),
        );
        verifyNever(() => mockJournalDb.upsertEntryLink(any()));
        verifyNever(() => mockUpdateNotifications.notify(any()));
        verifyNever(() => mockOutboxService.enqueueMessage(any()));
      });
    });

    group('getTypedLinksForTaskIds', () {
      test('delegates to JournalDb.typedLinksForTaskIds', () async {
        final link = EntryLink.blocks(
          id: 'link-1',
          fromId: 'blocker',
          toId: 'blocked',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          vectorClock: null,
        );
        when(
          () => mockJournalDb.typedLinksForTaskIds(
            {'blocked'},
            types: {'BlocksLink'},
          ),
        ).thenAnswer((_) async => [link]);

        final result = await repository.getTypedLinksForTaskIds(
          {'blocked'},
          linkTypes: {'BlocksLink'},
        );

        expect(result, [link]);
      });
    });

    group('getJournalEntitiesByIdsIncludingDeleted', () {
      test(
        'returns empty list without hitting the DB for empty input',
        () async {
          final result = await repository
              .getJournalEntitiesByIdsIncludingDeleted(
                <String>[],
              );

          expect(result, isEmpty);
          verifyNever(() => mockJournalDb.entriesForIds(any()));
        },
      );

      test(
        'resolves entities including tombstoned ones via entriesForIds',
        () async {
          final tombstoned = testJournalEntry(
            meta: testMeta(id: 'tombstoned', deletedAt: DateTime(2024)),
          );
          when(
            () => mockJournalDb.entriesForIds(['tombstoned']),
          ).thenReturn(MockSelectable([toDbEntity(tombstoned)]));

          final result = await repository
              .getJournalEntitiesByIdsIncludingDeleted(['tombstoned']);

          expect(result.single.id, 'tombstoned');
          expect(result.single.meta.deletedAt, isNotNull);
        },
      );
    });

    group('getLinkedEntities', () {
      test('returns all linked entities for the specified entity', () async {
        // Arrange
        const linkedTo = 'linked-to-id';

        final testEntities = [
          testJournalEntry(
            plainText: 'Entry 1',
            markdown: 'Entry 1',
            meta: testMeta(id: 'entry-1'),
          ),
          testJournalEntry(
            plainText: 'Entry 2',
            markdown: 'Entry 2',
            meta: testMeta(id: 'entry-2'),
          ),
        ];

        // Mock JournalDb
        when(
          () => mockJournalDb.getLinkedEntities(linkedTo),
        ).thenAnswer((_) async => testEntities);

        // Act
        final result = await repository.getLinkedEntities(linkedTo: linkedTo);

        // Assert
        expect(result, equals(testEntities));
        verify(() => mockJournalDb.getLinkedEntities(linkedTo)).called(1);
      });

      test('concurrent lookups each hit the DB', () async {
        const linkedTo = 'linked-to-id';
        final testEntities = [
          testJournalEntry(
            plainText: 'Entry 1',
            markdown: 'Entry 1',
            meta: testMeta(id: 'entry-1'),
          ),
        ];

        when(
          () => mockJournalDb.getLinkedEntities(linkedTo),
        ).thenAnswer((_) async => testEntities);

        final futureA = repository.getLinkedEntities(linkedTo: linkedTo);
        final futureB = repository.getLinkedEntities(linkedTo: linkedTo);

        expect(await futureA, testEntities);
        expect(await futureB, testEntities);
        // Without caching, each call hits the DB independently
        verify(() => mockJournalDb.getLinkedEntities(linkedTo)).called(2);
      });

      test('fetches from DB on each call', () async {
        const linkedTo = 'linked-to-id';
        final initialEntities = [
          testJournalEntry(
            plainText: 'Entry 1',
            markdown: 'Entry 1',
            meta: testMeta(id: 'entry-1'),
          ),
        ];
        final refreshedEntities = [
          ...initialEntities,
          testJournalEntry(
            plainText: 'Entry 2',
            markdown: 'Entry 2',
            meta: Metadata(
              id: 'entry-2',
              createdAt: DateTime(2024),
              updatedAt: DateTime(2024),
              dateFrom: DateTime(2024),
              dateTo: DateTime(2024),
            ),
          ),
        ];

        when(
          () => mockJournalDb.getLinkedEntities(linkedTo),
        ).thenAnswer((_) async => initialEntities);

        final first = await repository.getLinkedEntities(linkedTo: linkedTo);
        expect(first, initialEntities);
        verify(() => mockJournalDb.getLinkedEntities(linkedTo)).called(1);

        when(
          () => mockJournalDb.getLinkedEntities(linkedTo),
        ).thenAnswer((_) async => refreshedEntities);

        final refreshed = await repository.getLinkedEntities(
          linkedTo: linkedTo,
        );
        expect(refreshed.map((entity) => entity.meta.id), [
          'entry-1',
          'entry-2',
        ]);
        verify(() => mockJournalDb.getLinkedEntities(linkedTo)).called(1);
      });
    });

    group('getJournalEntityById', () {
      test('returns the journal entity when found', () async {
        // Arrange
        const entityId = 'test-entity-id';
        final testEntity = testJournalEntry(meta: testMeta(id: entityId));

        // Mock the journalEntityById call
        when(
          () => mockJournalDb.journalEntityById(entityId),
        ).thenAnswer((_) async => testEntity);

        // Act
        final result = await repository.getJournalEntityById(entityId);

        // Assert
        expect(result, equals(testEntity));
        verify(() => mockJournalDb.journalEntityById(entityId)).called(1);
      });

      test('returns null when entity not found', () async {
        // Arrange
        const entityId = 'non-existent-id';

        // Mock the journalEntityById call to return null
        when(
          () => mockJournalDb.journalEntityById(entityId),
        ).thenAnswer((_) async => null);

        // Act
        final result = await repository.getJournalEntityById(entityId);

        // Assert
        expect(result, isNull);
        verify(() => mockJournalDb.journalEntityById(entityId)).called(1);
      });

      test('fetches from DB on each call without caching', () async {
        const entityId = 'test-entity-id';
        final initialEntity = testJournalEntry(
          plainText: 'Initial content',
          markdown: 'initial',
          meta: testMeta(id: entityId),
        );
        final updatedEntity = testJournalEntry(
          plainText: 'Updated content',
          markdown: 'updated',
          meta: Metadata(
            id: entityId,
            createdAt: DateTime(2023),
            updatedAt: DateTime(2024),
            dateFrom: DateTime(2023),
            dateTo: DateTime(2024),
            starred: false,
            private: false,
            flag: EntryFlag.none,
          ),
        );

        when(
          () => mockJournalDb.journalEntityById(entityId),
        ).thenAnswer((_) async => initialEntity);

        expect(await repository.getJournalEntityById(entityId), initialEntity);
        expect(await repository.getJournalEntityById(entityId), initialEntity);
        // Without caching, each call hits the DB
        verify(() => mockJournalDb.journalEntityById(entityId)).called(2);

        when(
          () => mockJournalDb.journalEntityById(entityId),
        ).thenAnswer((_) async => updatedEntity);

        expect(await repository.getJournalEntityById(entityId), updatedEntity);
        verify(() => mockJournalDb.journalEntityById(entityId)).called(1);
      });
    });

    group('getLinksFromId', () {
      test(
        'returns empty list without sorting when there are no links',
        () async {
          const fromId = 'from-id';
          final mockLinksQuery = MockSelectable<LinkedDbEntry>(
            <LinkedDbEntry>[],
          );

          when(
            () => mockJournalDb.linksFromId(fromId, [false]),
          ).thenReturn(mockLinksQuery);

          final result = await repository.getLinksFromId(fromId);

          expect(result, isEmpty);
          verify(() => mockJournalDb.linksFromId(fromId, [false])).called(1);
          verifyNever(
            () => mockJournalDb.getJournalEntityIdsSortedByDateFromDesc(any()),
          );
        },
      );

      test('returns links from a specific ID with sorted order', () async {
        // Arrange
        const fromId = 'from-id';
        final dateTime2023 = DateTime(2023);

        // Create proper serialized JSON for the EntryLink
        final entryLink1 = EntryLink.basic(
          id: 'link-id-1',
          fromId: fromId,
          toId: 'to-id-1',
          createdAt: dateTime2023,
          updatedAt: dateTime2023,
          vectorClock: null,
        );

        final entryLink2 = EntryLink.basic(
          id: 'link-id-2',
          fromId: fromId,
          toId: 'to-id-2',
          createdAt: dateTime2023,
          updatedAt: dateTime2023,
          vectorClock: null,
        );

        final mockDbEntry1 = LinkedDbEntry(
          id: 'link-id-1',
          fromId: fromId,
          toId: 'to-id-1',
          createdAt: dateTime2023,
          updatedAt: dateTime2023,
          hidden: false,
          type: 'BasicLink',
          serialized: jsonEncode(entryLink1),
        );

        final mockDbEntry2 = LinkedDbEntry(
          id: 'link-id-2',
          fromId: fromId,
          toId: 'to-id-2',
          createdAt: dateTime2023,
          updatedAt: dateTime2023,
          hidden: false,
          type: 'BasicLink',
          serialized: jsonEncode(entryLink2),
        );

        final mockEntries = [mockDbEntry1, mockDbEntry2];
        final mockLinksQuery = MockSelectable<LinkedDbEntry>(mockEntries);

        // Mock the linksFromId query
        when(
          () => mockJournalDb.linksFromId(fromId, [false]),
        ).thenReturn(mockLinksQuery);

        // Mock the journalEntityIdsByDateFromDesc query
        when(
          () => mockJournalDb.getJournalEntityIdsSortedByDateFromDesc([
            'to-id-1',
            'to-id-2',
          ]),
        ).thenAnswer((_) async => ['to-id-2', 'to-id-1']);

        // Act
        final result = await repository.getLinksFromId(fromId);

        // Assert
        expect(result, hasLength(2));
        // The order should match what was returned by journalEntityIdsByDateFromDesc
        expect(result[0].toId, equals('to-id-2'));
        expect(result[1].toId, equals('to-id-1'));
        verify(() => mockJournalDb.linksFromId(fromId, [false])).called(1);
        verify(
          () => mockJournalDb.getJournalEntityIdsSortedByDateFromDesc([
            'to-id-1',
            'to-id-2',
          ]),
        ).called(1);
      });

      test('includes hidden links when includeHidden is true', () async {
        // Arrange
        const fromId = 'from-id';
        final dateTime2023 = DateTime(2023);

        // Create proper serialized JSON for the EntryLink
        final entryLink = EntryLink.basic(
          id: 'link-id-1',
          fromId: fromId,
          toId: 'to-id-1',
          createdAt: dateTime2023,
          updatedAt: dateTime2023,
          vectorClock: null,
          hidden: true,
        );

        final mockDbEntry = LinkedDbEntry(
          id: 'link-id-1',
          fromId: fromId,
          toId: 'to-id-1',
          createdAt: dateTime2023,
          updatedAt: dateTime2023,
          hidden: true,
          type: 'BasicLink',
          serialized: jsonEncode(entryLink),
        );

        final mockEntries = [mockDbEntry];
        final mockLinksQuery = MockSelectable<LinkedDbEntry>(mockEntries);

        // Mock the linksFromId query
        when(
          () => mockJournalDb.linksFromId(fromId, [false, true]),
        ).thenReturn(mockLinksQuery);

        // Mock the journalEntityIdsByDateFromDesc query
        when(
          () => mockJournalDb.getJournalEntityIdsSortedByDateFromDesc([
            'to-id-1',
          ]),
        ).thenAnswer((_) async => ['to-id-1']);

        // Act
        final result = await repository.getLinksFromId(
          fromId,
          includeHidden: true,
        );

        // Assert
        expect(result, hasLength(1));
        expect(result[0].toId, equals('to-id-1'));
        expect(result[0].hidden, isTrue);
        verify(
          () => mockJournalDb.linksFromId(fromId, [false, true]),
        ).called(1);
      });

      test('filters out null links when some IDs do not have links', () async {
        // Arrange
        const fromId = 'from-id';
        final dateTime2023 = DateTime(2023);

        // Create proper serialized JSON for the EntryLink
        final entryLink1 = EntryLink.basic(
          id: 'link-id-1',
          fromId: fromId,
          toId: 'to-id-1',
          createdAt: dateTime2023,
          updatedAt: dateTime2023,
          vectorClock: null,
        );

        final entryLink2 = EntryLink.basic(
          id: 'link-id-2',
          fromId: fromId,
          toId: 'to-id-2',
          createdAt: dateTime2023,
          updatedAt: dateTime2023,
          vectorClock: null,
        );

        final mockDbEntry1 = LinkedDbEntry(
          id: 'link-id-1',
          fromId: fromId,
          toId: 'to-id-1',
          createdAt: dateTime2023,
          updatedAt: dateTime2023,
          hidden: false,
          type: 'BasicLink',
          serialized: jsonEncode(entryLink1),
        );

        final mockDbEntry2 = LinkedDbEntry(
          id: 'link-id-2',
          fromId: fromId,
          toId: 'to-id-2',
          createdAt: dateTime2023,
          updatedAt: dateTime2023,
          hidden: false,
          type: 'BasicLink',
          serialized: jsonEncode(entryLink2),
        );

        final mockEntries = [mockDbEntry1, mockDbEntry2];
        final mockLinksQuery = MockSelectable<LinkedDbEntry>(mockEntries);

        // Mock the linksFromId query
        when(
          () => mockJournalDb.linksFromId(fromId, [false]),
        ).thenReturn(mockLinksQuery);

        // Mock the journalEntityIdsByDateFromDesc query to return an ID that doesn't exist
        // in our links map to test the nonNulls filtering
        when(
          () => mockJournalDb.getJournalEntityIdsSortedByDateFromDesc([
            'to-id-1',
            'to-id-2',
          ]),
        ).thenAnswer((_) async => ['to-id-3', 'to-id-2', 'to-id-1']);

        // Act
        final result = await repository.getLinksFromId(fromId);

        // Assert
        expect(
          result,
          hasLength(2),
        ); // Only 2 links exist, even though 3 IDs were returned
        expect(result[0].toId, equals('to-id-2'));
        expect(result[1].toId, equals('to-id-1'));
        verify(() => mockJournalDb.linksFromId(fromId, [false])).called(1);
        verify(
          () => mockJournalDb.getJournalEntityIdsSortedByDateFromDesc([
            'to-id-1',
            'to-id-2',
          ]),
        ).called(1);
      });
    });

    group('createTextEntry', () {
      test('successfully creates a text entry', () async {
        // Arrange
        const entryText = EntryText(
          plainText: 'Test content',
          markdown: 'Test content',
        );
        final started = DateTime(2023);
        const id = 'test-id';
        const linkedId = 'linked-id';
        const categoryId = 'category-id';

        final testMetadata = Metadata(
          id: id,
          createdAt: DateTime(2023),
          updatedAt: DateTime(2023),
          dateFrom: started,
          dateTo: started,
          starred: false,
          private: false,
          flag: EntryFlag.none,
          categoryId: categoryId,
        );

        // Mock the createMetadata call
        when(
          () => mockPersistenceLogic.createMetadata(
            dateFrom: started,
            categoryId: categoryId,
          ),
        ).thenAnswer((_) async => testMetadata);

        // Mock the createDbEntity call
        when(
          () => mockPersistenceLogic.createDbEntity(
            any(),
            linkedId: linkedId,
          ),
        ).thenAnswer((_) async => true);

        // Act
        final result = await JournalRepository.createTextEntry(
          entryText,
          started: started,
          linkedId: linkedId,
          categoryId: categoryId,
        );

        // Assert: the entry is written under the id its metadata minted —
        // the id the clock reservation names.
        expect(result, isNotNull);
        expect(result, isA<JournalEntry>());
        expect(result?.meta.id, id);
        expect((result as JournalEntry?)?.entryText, equals(entryText));
        expect(result?.meta.categoryId, equals(categoryId));

        verify(
          () => mockPersistenceLogic.createMetadata(
            dateFrom: started,
            categoryId: categoryId,
          ),
        ).called(1);
        verify(
          () => mockPersistenceLogic.createDbEntity(
            any(),
            linkedId: linkedId,
          ),
        ).called(1);
      });

      test('handles exceptions and returns null', () async {
        // Arrange
        const entryText = EntryText(
          plainText: 'Test content',
          markdown: 'Test content',
        );
        final started = DateTime(2023);

        // Mock the createMetadata call to throw an exception
        when(
          () => mockPersistenceLogic.createMetadata(
            dateFrom: any(named: 'dateFrom'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenThrow(Exception('Test exception'));

        // Act
        final result = await JournalRepository.createTextEntry(
          entryText,
          started: started,
        );

        // Assert
        expect(result, isNull);
        verify(
          () => mockDomainLogger.error(
            LogDomain.persistence,
            any(),
            stackTrace: any(named: 'stackTrace'),
            subDomain: 'createTextEntry',
          ),
        ).called(1);
      });
    });

    group('createImageEntry', () {
      test('successfully creates an image entry', () async {
        // Arrange
        final imageData = ImageData(
          capturedAt: DateTime(2023),
          imageId: 'image-id',
          imageFile: 'image.jpg',
          imageDirectory: '/path/to/images',
          geolocation: Geolocation(
            createdAt: DateTime(2023),
            latitude: 37.7749,
            longitude: -122.4194,
            geohashString: 'test-geohash',
            accuracy: 10,
            altitude: 0,
          ),
        );
        const linkedId = 'linked-id';
        const categoryId = 'category-id';

        final testMetadata = Metadata(
          id: 'test-id',
          createdAt: DateTime(2023),
          updatedAt: DateTime(2023),
          dateFrom: imageData.capturedAt,
          dateTo: imageData.capturedAt,
          starred: false,
          private: false,
          flag: EntryFlag.import,
          categoryId: categoryId,
        );

        // Mock the createMetadata call
        when(
          () => mockPersistenceLogic.createMetadata(
            dateFrom: imageData.capturedAt,
            dateTo: imageData.capturedAt,
            uuidV5Input: json.encode(imageData),
            flag: EntryFlag.import,
            categoryId: categoryId,
          ),
        ).thenAnswer((_) async => testMetadata);

        // Mock the createDbEntity call
        when(
          () => mockPersistenceLogic.createDbEntity(
            any(),
            linkedId: linkedId,
            shouldAddGeolocation: false,
          ),
        ).thenAnswer((_) async => true);

        // Act
        final result = await JournalRepository.createImageEntry(
          imageData,
          linkedId: linkedId,
          categoryId: categoryId,
        );

        // Assert
        expect(result, isNotNull);
        expect(result, isA<JournalImage>());
        expect((result as JournalImage?)?.data, equals(imageData));
        expect(result?.geolocation, equals(imageData.geolocation));
        expect(result?.meta.categoryId, equals(categoryId));
        expect(result?.meta.flag, equals(EntryFlag.import));

        verify(
          () => mockPersistenceLogic.createMetadata(
            dateFrom: imageData.capturedAt,
            dateTo: imageData.capturedAt,
            uuidV5Input: json.encode(imageData),
            flag: EntryFlag.import,
            categoryId: categoryId,
          ),
        ).called(1);
        verify(
          () => mockPersistenceLogic.createDbEntity(
            any(),
            linkedId: linkedId,
            shouldAddGeolocation: false,
          ),
        ).called(1);
      });

      group('createImageEntryTracked', () {
        final imageData = ImageData(
          capturedAt: DateTime(2023),
          imageId: 'image-id',
          imageFile: 'image.jpg',
          imageDirectory: '/path/to/images',
        );

        setUp(() {
          when(
            () => mockPersistenceLogic.createMetadata(
              dateFrom: any(named: 'dateFrom'),
              dateTo: any(named: 'dateTo'),
              uuidV5Input: any(named: 'uuidV5Input'),
              flag: any(named: 'flag'),
              categoryId: any(named: 'categoryId'),
            ),
          ).thenAnswer((_) async => testMeta(id: 'image-entry'));
        });

        test('says the row was inserted when the write was applied', () async {
          when(
            () => mockPersistenceLogic.createDbEntity(
              any(),
              linkedId: any(named: 'linkedId'),
              shouldAddGeolocation: false,
            ),
          ).thenAnswer((_) async => true);

          final seen = <JournalEntity>[];
          final result = await JournalRepository.createImageEntryTracked(
            imageData,
            onCreated: seen.add,
          );

          expect(result!.created, isTrue);
          expect(result.entry.meta.id, 'image-entry');
          expect(
            seen.map((entity) => entity.meta.id),
            ['image-entry'],
            reason: 'onCreated fires for the row this call inserted',
          );
        });

        test(
          'says the row was not inserted when the write was declined — the '
          'deterministic id of a photo imported before',
          () async {
            when(
              () => mockPersistenceLogic.createDbEntity(
                any(),
                linkedId: any(named: 'linkedId'),
                shouldAddGeolocation: false,
              ),
            ).thenAnswer((_) async => false);

            var callbacks = 0;
            final result = await JournalRepository.createImageEntryTracked(
              imageData,
              onCreated: (_) => callbacks++,
            );

            expect(result!.created, isFalse);
            expect(
              result.entry.meta.id,
              'image-entry',
              reason: 'the caller still gets the entry it can reference',
            );
            expect(
              callbacks,
              0,
              reason:
                  'an existing image must not have its analysis re-triggered '
                  'because it was picked again',
            );
          },
        );
      });

      test('handles exceptions and returns null', () async {
        // Arrange
        final imageData = ImageData(
          capturedAt: DateTime(2023),
          imageId: 'image-id',
          imageFile: 'image.jpg',
          imageDirectory: '/path/to/images',
        );

        // Mock the createMetadata call to throw an exception
        when(
          () => mockPersistenceLogic.createMetadata(
            dateFrom: any(named: 'dateFrom'),
            dateTo: any(named: 'dateTo'),
            uuidV5Input: any(named: 'uuidV5Input'),
            flag: any(named: 'flag'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenThrow(Exception('Test exception'));

        // Act
        final result = await JournalRepository.createImageEntry(imageData);

        // Assert
        expect(result, isNull);
        verify(
          () => mockDomainLogger.error(
            LogDomain.persistence,
            any(),
            stackTrace: any(named: 'stackTrace'),
            subDomain: 'createImageEntry',
          ),
        ).called(1);
      });
    });

    group('getLinkedToEntities', () {
      test('converts db entities using fromDbEntity', () async {
        // Arrange
        const linkedTo = 'linked-to-id';
        final dateTime2023 = DateTime(2023);

        // Create mock db entities
        final dbEntity1 = JournalDbEntity(
          id: 'entity-1',
          createdAt: dateTime2023,
          updatedAt: dateTime2023,
          dateFrom: dateTime2023,
          deleted: false,
          type: 'JournalEntry',
          subtype: '',
          task: false,
          taskStatus: '',
          starred: false,
          private: false,
          flag: 0,
          category: 'journal',
          dateTo: dateTime2023,
          schemaVersion: 1,
          serialized: jsonEncode(
            testJournalEntry(
              plainText: 'Entry 1',
              markdown: 'Entry 1',
              meta: testMeta(id: 'entity-1'),
            ).toJson(),
          ),
        );

        final dbEntity2 = JournalDbEntity(
          id: 'entity-2',
          createdAt: dateTime2023,
          updatedAt: dateTime2023,
          dateFrom: dateTime2023,
          deleted: false,
          type: 'JournalEntry',
          subtype: '',
          task: false,
          taskStatus: '',
          starred: false,
          private: false,
          flag: 0,
          category: 'journal',
          dateTo: dateTime2023,
          schemaVersion: 1,
          serialized: jsonEncode(
            testJournalEntry(
              plainText: 'Entry 2',
              markdown: 'Entry 2',
              meta: testMeta(id: 'entity-2'),
            ).toJson(),
          ),
        );

        final mockDbEntities = [dbEntity1, dbEntity2];

        // Mock JournalDb
        when(
          () => mockJournalDb.getLinkedToEntities(linkedTo),
        ).thenAnswer((_) async => mockDbEntities);

        // Act
        final result = await repository.getLinkedToEntities(linkedTo: linkedTo);

        // Assert
        expect(result, hasLength(2));
        expect(result[0], isA<JournalEntry>());
        expect(result[1], isA<JournalEntry>());
        expect((result[0] as JournalEntry).meta.id, equals('entity-1'));
        expect((result[1] as JournalEntry).meta.id, equals('entity-2'));

        verify(() => mockJournalDb.getLinkedToEntities(linkedTo)).called(1);
      });

      test(
        'fetches reverse-linked entities from DB on each call',
        () async {
          const linkedTo = 'linked-to-id';
          final dateTime2023 = DateTime(2023);
          final dbEntity = JournalDbEntity(
            id: 'entity-1',
            createdAt: dateTime2023,
            updatedAt: dateTime2023,
            dateFrom: dateTime2023,
            deleted: false,
            type: 'JournalEntry',
            subtype: '',
            task: false,
            taskStatus: '',
            starred: false,
            private: false,
            flag: 0,
            category: 'journal',
            dateTo: dateTime2023,
            schemaVersion: 1,
            serialized: jsonEncode(
              testJournalEntry(
                plainText: 'Entry 1',
                markdown: 'Entry 1',
                meta: testMeta(id: 'entity-1'),
              ).toJson(),
            ),
          );

          when(
            () => mockJournalDb.getLinkedToEntities(linkedTo),
          ).thenAnswer((_) async => [dbEntity]);

          final result = await repository.getLinkedToEntities(
            linkedTo: linkedTo,
          );

          expect(result.single.meta.id, 'entity-1');
          verify(() => mockJournalDb.getLinkedToEntities(linkedTo)).called(1);
        },
      );
    });

    group('getLinkedImagesForTask', () {
      test('returns only JournalImage entities from linked entities', () async {
        // Arrange
        const taskId = 'task-id';
        final dateTime2023 = DateTime(2023);

        // Create a mix of entity types
        final journalEntry = JournalEntity.journalEntry(
          entryText: const EntryText(
            plainText: 'Entry 1',
            markdown: 'Entry 1',
          ),
          meta: Metadata(
            id: 'entry-1',
            createdAt: dateTime2023,
            updatedAt: dateTime2023,
            dateFrom: dateTime2023,
            dateTo: dateTime2023,
          ),
        );

        final journalImage1 = JournalEntity.journalImage(
          meta: Metadata(
            id: 'image-1',
            createdAt: dateTime2023,
            updatedAt: dateTime2023,
            dateFrom: dateTime2023,
            dateTo: dateTime2023,
          ),
          data: ImageData(
            capturedAt: dateTime2023,
            imageId: 'img-1',
            imageFile: 'image1.jpg',
            imageDirectory: '/path/to/images',
          ),
        );

        final journalImage2 = JournalEntity.journalImage(
          meta: Metadata(
            id: 'image-2',
            createdAt: dateTime2023,
            updatedAt: dateTime2023,
            dateFrom: dateTime2023,
            dateTo: dateTime2023,
          ),
          data: ImageData(
            capturedAt: dateTime2023,
            imageId: 'img-2',
            imageFile: 'image2.jpg',
            imageDirectory: '/path/to/images',
          ),
        );

        final linkedEntities = [journalEntry, journalImage1, journalImage2];

        // Mock JournalDb
        when(
          () => mockJournalDb.getLinkedEntities(taskId),
        ).thenAnswer((_) async => linkedEntities);

        // Act
        final result = await repository.getLinkedImagesForTask(taskId);

        // Assert
        expect(result, hasLength(2));
        expect(result[0], isA<JournalImage>());
        expect(result[1], isA<JournalImage>());
        expect(result[0].meta.id, equals('image-1'));
        expect(result[1].meta.id, equals('image-2'));

        verify(() => mockJournalDb.getLinkedEntities(taskId)).called(1);
      });

      test('returns empty list when no images are linked', () async {
        // Arrange
        const taskId = 'task-id';
        final dateTime2023 = DateTime(2023);

        // Create only non-image entities
        final journalEntry = JournalEntity.journalEntry(
          entryText: const EntryText(
            plainText: 'Entry 1',
            markdown: 'Entry 1',
          ),
          meta: Metadata(
            id: 'entry-1',
            createdAt: dateTime2023,
            updatedAt: dateTime2023,
            dateFrom: dateTime2023,
            dateTo: dateTime2023,
          ),
        );

        final audioEntry = JournalEntity.journalAudio(
          meta: Metadata(
            id: 'audio-1',
            createdAt: dateTime2023,
            updatedAt: dateTime2023,
            dateFrom: dateTime2023,
            dateTo: dateTime2023,
          ),
          data: AudioData(
            audioFile: 'audio.m4a',
            audioDirectory: '/path/to/audio',
            dateFrom: dateTime2023,
            dateTo: dateTime2023,
            duration: const Duration(minutes: 2),
          ),
        );

        final linkedEntities = [journalEntry, audioEntry];

        // Mock JournalDb
        when(
          () => mockJournalDb.getLinkedEntities(taskId),
        ).thenAnswer((_) async => linkedEntities);

        // Act
        final result = await repository.getLinkedImagesForTask(taskId);

        // Assert
        expect(result, isEmpty);

        verify(() => mockJournalDb.getLinkedEntities(taskId)).called(1);
      });

      test('returns empty list when no linked entities exist', () async {
        // Arrange
        const taskId = 'task-id';

        // Mock JournalDb to return empty list
        when(
          () => mockJournalDb.getLinkedEntities(taskId),
        ).thenAnswer((_) async => []);

        // Act
        final result = await repository.getLinkedImagesForTask(taskId);

        // Assert
        expect(result, isEmpty);

        verify(() => mockJournalDb.getLinkedEntities(taskId)).called(1);
      });
    });

    group('deleteJournalEntity clears relationship image references', () {
      final dateTime2023 = DateTime(2023);
      const imageId = 'image-to-delete';

      JournalEntity image() => JournalEntity.journalImage(
        meta: testMeta(id: imageId),
        data: ImageData(
          capturedAt: dateTime2023,
          imageId: 'img-uuid',
          imageFile: 'face.jpg',
          imageDirectory: '/path/to/images',
        ),
      );

      RelationshipEntry person({
        String? avatarImageId,
        AvatarCrop? avatarCrop,
        String? bannerImageId,
      }) =>
          JournalEntity.relationship(
                meta: testMeta(id: 'rel-1'),
                data: RelationshipData(
                  title: 'Anna',
                  avatarImageId: avatarImageId,
                  avatarCrop: avatarCrop,
                  bannerImageId: bannerImageId,
                  status: RelationshipStatus.active(
                    id: 'status-1',
                    createdAt: dateTime2023,
                    utcOffset: 0,
                  ),
                ),
              )
              as RelationshipEntry;

      JournalDbEntity dbEntityFor(RelationshipEntry entry) => JournalDbEntity(
        id: entry.meta.id,
        createdAt: dateTime2023,
        updatedAt: dateTime2023,
        dateFrom: dateTime2023,
        dateTo: dateTime2023,
        deleted: false,
        type: 'RelationshipEntry',
        subtype: '',
        task: false,
        starred: false,
        private: false,
        flag: 0,
        category: '',
        schemaVersion: 1,
        serialized: jsonEncode(entry.toJson()),
      );

      /// Deletes [imageId] with [linked] as the only entity pointing at it,
      /// and hands back every entity that was written as a result.
      Future<List<JournalEntity>> deleteImageLinkedTo(
        RelationshipEntry linked,
      ) async {
        when(
          () => mockJournalDb.journalEntityById(imageId),
        ).thenAnswer((_) async => image());
        when(
          () => mockJournalDb.getLinkedToEntities(imageId),
        ).thenAnswer((_) async => [dbEntityFor(linked)]);
        // The relationship write reads the stored person first.
        when(
          () => mockJournalDb.journalEntityById(linked.meta.id),
        ).thenAnswer((_) async => linked);
        when(() => mockPersistenceLogic.updateMetadata(any())).thenAnswer(
          (invocation) async =>
              invocation.positionalArguments.first as Metadata,
        );
        when(
          () => mockPersistenceLogic.updateMetadata(
            any(),
            deletedAt: any(named: 'deletedAt'),
          ),
        ).thenAnswer(
          (invocation) async =>
              (invocation.positionalArguments.first as Metadata).copyWith(
                deletedAt: dateTime2023,
              ),
        );
        when(
          () => mockPersistenceLogic.updateDbEntity(
            any(),
            precondition: any(named: 'precondition'),
          ),
        ).thenAnswer((_) async => true);
        when(
          () => mockNotificationService.updateBadge(),
        ).thenAnswer((_) async {});
        when(() => mockTimeService.getCurrent()).thenReturn(null);

        expect(await repository.deleteJournalEntity(imageId), isTrue);
        return verify(
          () => mockPersistenceLogic.updateDbEntity(
            captureAny(),
            precondition: any(named: 'precondition'),
          ),
        ).captured.cast<JournalEntity>();
      }

      test('deleting the avatar image clears the id and its framing, and '
          'leaves the banner alone', () async {
        final written = await deleteImageLinkedTo(
          person(
            avatarImageId: imageId,
            avatarCrop: const AvatarCrop(x: 0.2, y: 0.7, scale: 3),
            bannerImageId: 'other-image',
          ),
        );

        final updated = written.whereType<RelationshipEntry>().single;
        expect(updated.data.avatarImageId, isNull);
        expect(
          updated.data.avatarCrop,
          isNull,
          reason:
              'a framing for an image that is gone would be inherited by '
              'the next photo chosen',
        );
        expect(
          updated.data.bannerImageId,
          'other-image',
          reason: 'only the reference to the deleted image is cleared',
        );
      });

      test(
        'a refused reference clear is logged and does not block the '
        'tombstone: the deletion the user asked for goes ahead',
        () async {
          when(
            () => mockJournalDb.journalEntityById(imageId),
          ).thenAnswer((_) async => image());
          final linked = person(avatarImageId: imageId);
          when(
            () => mockJournalDb.getLinkedToEntities(imageId),
          ).thenAnswer((_) async => [dbEntityFor(linked)]);
          when(
            () => mockJournalDb.journalEntityById(linked.meta.id),
          ).thenAnswer((_) async => linked);
          when(() => mockPersistenceLogic.updateMetadata(any())).thenAnswer(
            (invocation) async =>
                invocation.positionalArguments.first as Metadata,
          );
          when(
            () => mockPersistenceLogic.updateMetadata(
              any(),
              deletedAt: any(named: 'deletedAt'),
            ),
          ).thenAnswer(
            (invocation) async =>
                (invocation.positionalArguments.first as Metadata).copyWith(
                  deletedAt: dateTime2023,
                ),
          );
          when(
            () => mockPersistenceLogic.updateDbEntity(
              any(that: isA<RelationshipEntry>()),
              precondition: any(named: 'precondition'),
            ),
          ).thenAnswer((_) async => false);
          when(
            () => mockPersistenceLogic.updateDbEntity(
              any(that: isA<JournalImage>()),
              precondition: any(named: 'precondition'),
            ),
          ).thenAnswer((_) async => true);
          when(
            () => mockNotificationService.updateBadge(),
          ).thenAnswer((_) async {});
          when(() => mockTimeService.getCurrent()).thenReturn(null);

          expect(await repository.deleteJournalEntity(imageId), isTrue);

          final written = verify(
            () => mockPersistenceLogic.updateDbEntity(
              captureAny(),
              precondition: any(named: 'precondition'),
            ),
          ).captured.cast<JournalEntity>();
          expect(
            written.whereType<JournalImage>().single.meta.deletedAt,
            dateTime2023,
            reason: 'the image is tombstoned regardless',
          );
          verify(
            () => mockDomainLogger.log(
              LogDomain.persistence,
              any(that: contains(imageId)),
              subDomain: 'deleteJournalEntity',
              level: InsightLevel.warn,
            ),
          ).called(1);
        },
      );

      test('deleting the banner image leaves the avatar and its framing '
          'untouched', () async {
        const crop = AvatarCrop(x: 0.4, y: 0.35, scale: 1.8);
        final written = await deleteImageLinkedTo(
          person(
            avatarImageId: 'other-image',
            avatarCrop: crop,
            bannerImageId: imageId,
          ),
        );

        final updated = written.whereType<RelationshipEntry>().single;
        expect(updated.data.bannerImageId, isNull);
        expect(updated.data.avatarImageId, 'other-image');
        expect(updated.data.avatarCrop, crop);
      });

      test('a relationship linked to the image but referencing it in neither '
          'field is not written at all', () async {
        final written = await deleteImageLinkedTo(
          person(avatarImageId: 'other-image', bannerImageId: 'another-image'),
        );

        expect(
          written.whereType<RelationshipEntry>(),
          isEmpty,
          reason:
              'rewriting an unchanged person would bump its vector clock '
              'and enqueue sync for nothing',
        );
      });
    });

    group('deleteJournalEntity with JournalImage cover art', () {
      test('clears coverArtId from tasks that reference deleted image', () async {
        // Arrange
        const imageId = 'image-to-delete';
        final dateTime2023 = DateTime(2023);

        // Create the image entity to be deleted
        final imageEntity = JournalEntity.journalImage(
          meta: Metadata(
            id: imageId,
            createdAt: dateTime2023,
            updatedAt: dateTime2023,
            dateFrom: dateTime2023,
            dateTo: dateTime2023,
          ),
          data: ImageData(
            capturedAt: dateTime2023,
            imageId: 'img-uuid',
            imageFile: 'test.jpg',
            imageDirectory: '/path/to/images',
          ),
        );

        // Create tasks that reference this image as cover art
        final taskWithCoverArt = JournalEntity.task(
          meta: Metadata(
            id: 'task-with-cover',
            createdAt: dateTime2023,
            updatedAt: dateTime2023,
            dateFrom: dateTime2023,
            dateTo: dateTime2023,
          ),
          data: TaskData(
            status: TaskStatus.open(
              id: 's',
              createdAt: dateTime2023,
              utcOffset: 0,
            ),
            dateFrom: dateTime2023,
            dateTo: dateTime2023,
            statusHistory: const [],
            title: 'Task with cover art',
            coverArtId: imageId, // References the image being deleted
          ),
        );

        // Create a task without the coverArtId (should not be updated)
        final taskWithoutCoverArt = JournalEntity.task(
          meta: Metadata(
            id: 'task-without-cover',
            createdAt: dateTime2023,
            updatedAt: dateTime2023,
            dateFrom: dateTime2023,
            dateTo: dateTime2023,
          ),
          data: TaskData(
            status: TaskStatus.open(
              id: 's2',
              createdAt: dateTime2023,
              utcOffset: 0,
            ),
            dateFrom: dateTime2023,
            dateTo: dateTime2023,
            statusHistory: const [],
            title: 'Task without cover art',
          ),
        );

        final updatedMeta = imageEntity.meta.copyWith(
          deletedAt: dateTime2023,
          updatedAt: dateTime2023,
        );

        // Create JournalDbEntity representations for the tasks
        final taskDbEntity1 = JournalDbEntity(
          id: 'task-with-cover',
          createdAt: dateTime2023,
          updatedAt: dateTime2023,
          dateFrom: dateTime2023,
          deleted: false,
          type: 'Task',
          subtype: '',
          task: true,
          taskStatus: 'open',
          starred: false,
          private: false,
          flag: 0,
          category: '',
          dateTo: dateTime2023,
          schemaVersion: 1,
          serialized: jsonEncode(taskWithCoverArt.toJson()),
        );

        final taskDbEntity2 = JournalDbEntity(
          id: 'task-without-cover',
          createdAt: dateTime2023,
          updatedAt: dateTime2023,
          dateFrom: dateTime2023,
          deleted: false,
          type: 'Task',
          subtype: '',
          task: true,
          taskStatus: 'open',
          starred: false,
          private: false,
          flag: 0,
          category: '',
          dateTo: dateTime2023,
          schemaVersion: 1,
          serialized: jsonEncode(taskWithoutCoverArt.toJson()),
        );

        // Mock the journalEntityById call for the image
        when(
          () => mockJournalDb.journalEntityById(imageId),
        ).thenAnswer((_) async => imageEntity);

        // Mock linkedToJournalEntities to return tasks that link to this image
        when(
          () => mockJournalDb.getLinkedToEntities(imageId),
        ).thenAnswer((_) async => [taskDbEntity1, taskDbEntity2]);

        // Mock updateTask for clearing coverArtId
        when(
          () => mockPersistenceLogic.updateTask(
            journalEntityId: any(named: 'journalEntityId'),
            change: any(named: 'change'),
          ),
        ).thenAnswer((_) async => taskWithCoverArt as Task);

        // Mock the updateMetadata call for the image deletion
        when(
          () => mockPersistenceLogic.updateMetadata(
            imageEntity.meta,
            deletedAt: any(named: 'deletedAt'),
          ),
        ).thenAnswer((_) async => updatedMeta);

        // Mock the updateDbEntity call for the image
        when(
          () => mockPersistenceLogic.updateDbEntity(
            any(),
            precondition: any(named: 'precondition'),
          ),
        ).thenAnswer((_) async => true);

        // Mock the updateBadge call
        when(
          () => mockNotificationService.updateBadge(),
        ).thenAnswer((_) async {});

        // Mock TimeService.getCurrent to return null
        when(() => mockTimeService.getCurrent()).thenReturn(null);

        // Act
        final result = await repository.deleteJournalEntity(imageId);

        // Assert
        expect(result, isTrue);

        // Verify the image was looked up

        // Verify that we looked for tasks that link to this image
        verify(() => mockJournalDb.getLinkedToEntities(imageId)).called(1);

        // Verify updateTask was called once (only for the task with coverArtId)
        final change =
            verify(
                  () => mockPersistenceLogic.updateTask(
                    journalEntityId: 'task-with-cover',
                    change: captureAny(named: 'change'),
                  ),
                ).captured.single
                as TaskData Function(TaskData);
        verifyNever(
          () => mockPersistenceLogic.updateTask(
            journalEntityId: 'task-without-cover',
            change: any(named: 'change'),
          ),
        );

        // The change clears the cover art on the task as stored, keeping a
        // field set there since the task was read...
        final stored = (taskWithCoverArt as Task).data.copyWith(
          title: 'Renamed meanwhile',
        );
        expect(change(stored), stored.copyWith(coverArtId: null));
        // ...and leaves a cover art picked since then as it is.
        final repicked = stored.copyWith(coverArtId: 'another-image');
        expect(change(repicked), same(repicked));

        // Verify the image entity was soft-deleted
        verify(
          () => mockPersistenceLogic.updateMetadata(
            imageEntity.meta,
            deletedAt: any(named: 'deletedAt'),
          ),
        ).called(1);
      });
    });

    group('updateTask', () {
      test('applies the change through PersistenceLogic and returns the task '
          'as stored', () async {
        final stored = TestTaskFactory.create(id: 'task-1', title: 'Stored');
        final written = stored.copyWith(
          data: stored.data.copyWith(title: 'Written'),
        );
        when(
          () => mockPersistenceLogic.updateTask(
            journalEntityId: 'task-1',
            change: any(named: 'change'),
          ),
        ).thenAnswer((_) async => written);

        final result = await repository.updateTask(
          'task-1',
          (data) => data.copyWith(title: 'Written'),
        );

        expect(result, same(written));
        final change =
            verify(
                  () => mockPersistenceLogic.updateTask(
                    journalEntityId: 'task-1',
                    change: captureAny(named: 'change'),
                  ),
                ).captured.single
                as TaskData Function(TaskData);
        expect(change(stored.data).title, 'Written');
      });

      test('answers null when PersistenceLogic could not write', () async {
        when(
          () => mockPersistenceLogic.updateTask(
            journalEntityId: any(named: 'journalEntityId'),
            change: any(named: 'change'),
          ),
        ).thenAnswer((_) async => null);

        expect(await repository.updateTask('missing', (data) => data), isNull);
      });
    });

    group('createImageEntry - callback behavior', () {
      test('invokes onCreated callback after successful creation', () async {
        // Arrange
        final imageData = ImageData(
          capturedAt: DateTime(2023),
          imageId: 'image-id',
          imageFile: 'image.jpg',
          imageDirectory: '/path/to/images',
        );
        const linkedId = 'linked-id';

        final testMetadata = Metadata(
          id: 'test-id',
          createdAt: DateTime(2023),
          updatedAt: DateTime(2023),
          dateFrom: imageData.capturedAt,
          dateTo: imageData.capturedAt,
          starred: false,
          private: false,
          flag: EntryFlag.import,
        );

        JournalEntity? callbackEntity;

        // Mock the createMetadata call
        when(
          () => mockPersistenceLogic.createMetadata(
            dateFrom: any(named: 'dateFrom'),
            dateTo: any(named: 'dateTo'),
            uuidV5Input: any(named: 'uuidV5Input'),
            flag: any(named: 'flag'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => testMetadata);

        // Mock the createDbEntity call
        when(
          () => mockPersistenceLogic.createDbEntity(
            any(),
            linkedId: linkedId,
            shouldAddGeolocation: false,
          ),
        ).thenAnswer((_) async => true);

        // Act
        final result = await JournalRepository.createImageEntry(
          imageData,
          linkedId: linkedId,
          onCreated: (entity) {
            callbackEntity = entity;
          },
        );

        // Assert
        expect(result, isNotNull);
        expect(result, isA<JournalImage>());

        // Verify callback was invoked with the created entity
        expect(callbackEntity, isNotNull);
        expect(callbackEntity, isA<JournalImage>());
        expect(callbackEntity!.meta.id, equals(result!.meta.id));
      });

      test('does not invoke onCreated callback when creation fails', () async {
        // Arrange
        final imageData = ImageData(
          capturedAt: DateTime(2023),
          imageId: 'image-id',
          imageFile: 'image.jpg',
          imageDirectory: '/path/to/images',
        );

        var callbackInvoked = false;

        // Mock the createMetadata call to throw an exception
        when(
          () => mockPersistenceLogic.createMetadata(
            dateFrom: any(named: 'dateFrom'),
            dateTo: any(named: 'dateTo'),
            uuidV5Input: any(named: 'uuidV5Input'),
            flag: any(named: 'flag'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenThrow(Exception('Test exception'));

        // Act
        final result = await JournalRepository.createImageEntry(
          imageData,
          onCreated: (entity) {
            callbackInvoked = true;
          },
        );

        // Assert
        expect(result, isNull);
        expect(callbackInvoked, isFalse);
      });
    });

    group('getJournalEntitiesByIds', () {
      test(
        'returns exactly what the DB yields when some ids resolve to '
        'no entity',
        () async {
          final onlyFound = testJournalEntry(
            plainText: 'found',
            markdown: 'found',
            meta: testMeta(id: 'found-id'),
          );
          when(
            () => mockJournalDb.getJournalEntitiesForIdsUnordered(
              {'found-id', 'missing-id'},
            ),
          ).thenAnswer((_) async => [onlyFound]);

          final result = await repository.getJournalEntitiesByIds(
            {'found-id', 'missing-id'},
          );

          expect(result, [onlyFound]);
        },
      );

      test(
        'returns empty list without hitting the DB for an empty input',
        () async {
          final result = await repository.getJournalEntitiesByIds(
            const <String>[],
          );

          expect(result, isEmpty);
          // Crucially: the bulk fetch must NOT be called for the empty
          // case — otherwise we issue an unnecessary `id IN ()` query
          // that drift would reject.
          verifyNever(
            () => mockJournalDb.getJournalEntitiesForIdsUnordered(any()),
          );
        },
      );

      test('delegates to the bulk fetcher and dedupes the input set', () async {
        final entity = testJournalEntry(
          plainText: 'bulk-fetch',
          markdown: 'bulk',
          meta: Metadata(
            id: 'a',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            dateFrom: DateTime(2024, 3, 15),
            dateTo: DateTime(2024, 3, 15),
            starred: false,
            private: false,
            flag: EntryFlag.none,
          ),
        );
        when(
          () => mockJournalDb.getJournalEntitiesForIdsUnordered(any()),
        ).thenAnswer((_) async => [entity]);

        final result = await repository.getJournalEntitiesByIds(
          ['a', 'a', 'b'],
        );

        expect(result, [entity]);
        final captured =
            verify(
                  () => mockJournalDb.getJournalEntitiesForIdsUnordered(
                    captureAny(),
                  ),
                ).captured.single
                as Set<String>;
        expect(captured, {'a', 'b'});
      });
    });
  });

  // ---------------------------------------------------------------------------
  // Tests from journal_repository_collapsed_test.dart — collapsed-link logic
  // Uses LoggingService (instead of DomainLogger) so setUp/tearDown are
  // isolated inside this group.
  // ---------------------------------------------------------------------------
  group('updateLink collapsed', () {
    late MockJournalDb collapsedMockJournalDb;
    late MockVectorClockService collapsedMockVectorClockService;
    late MockUpdateNotifications collapsedMockUpdateNotifications;
    late MockOutboxService collapsedMockOutboxService;
    late JournalRepository collapsedRepository;

    setUp(() {
      collapsedMockJournalDb = MockJournalDb();
      collapsedMockVectorClockService = MockVectorClockService();
      collapsedMockUpdateNotifications = MockUpdateNotifications();
      collapsedMockOutboxService = MockOutboxService();

      getIt
        ..registerSingleton<JournalDb>(collapsedMockJournalDb)
        ..registerSingleton<PersistenceLogic>(MockPersistenceLogic())
        ..registerSingleton<NotificationService>(MockNotificationService())
        ..registerSingleton<VectorClockService>(collapsedMockVectorClockService)
        ..registerSingleton<UpdateNotifications>(
          collapsedMockUpdateNotifications,
        )
        ..registerSingleton<OutboxService>(collapsedMockOutboxService)
        ..registerSingleton<TimeService>(MockTimeService());

      collapsedRepository = buildJournalRepository();

      registerFallbackValue(
        testMeta(),
      );
      registerFallbackValue(
        testJournalEntry(plainText: 'test'),
      );
      registerFallbackValue(
        SyncMessage.entryLink(
          entryLink: EntryLink.basic(
            id: 'link-id',
            fromId: 'from-id',
            toId: 'to-id',
            updatedAt: DateTime(2023),
            createdAt: DateTime(2023),
            vectorClock: null,
          ),
          status: SyncEntryStatus.update,
        ),
      );
      registerFallbackValue(
        EntryLink.basic(
          id: 'link-id',
          fromId: 'from-id',
          toId: 'to-id',
          updatedAt: DateTime(2023),
          createdAt: DateTime(2023),
          vectorClock: null,
        ),
      );
      registerFallbackValue(
        TaskData(
          status: TaskStatus.open(
            id: 'status-id',
            createdAt: DateTime(2023),
            utcOffset: 0,
          ),
          dateFrom: DateTime(2023),
          dateTo: DateTime(2023),
          statusHistory: const [],
          title: 'Test Task',
        ),
      );
      registerFallbackValue(EntryFlag.none);
      registerFallbackValue(DateTime(2023));
    });

    tearDown(() async {
      await getIt.reset();
    });

    group('updateLink with collapsed', () {
      test('syncs collapsed change to other devices', () async {
        final testLink = EntryLink.basic(
          id: 'link-id',
          fromId: 'from-id',
          toId: 'to-id',
          createdAt: DateTime(2023),
          updatedAt: DateTime(2023),
          vectorClock: null,
        );
        final updatedLink = testLink.copyWith(collapsed: true);

        when(
          () => collapsedMockJournalDb.entryLinkById(updatedLink.id),
        ).thenAnswer((_) async => testLink);
        when(
          () => collapsedMockVectorClockService.getNextVectorClock(
            previous: any(named: 'previous'),
            payload: any(named: 'payload'),
          ),
        ).thenAnswer((_) async => const VectorClock({'node1': 1}));
        when(
          () => collapsedMockJournalDb.upsertEntryLink(any()),
        ).thenAnswer((_) async => 1);
        when(
          () => collapsedMockUpdateNotifications.notify(any()),
        ).thenAnswer((_) async {});
        when(
          () => collapsedMockOutboxService.enqueueMessage(any()),
        ).thenAnswer((_) async {});

        final result = await collapsedRepository.updateLink(updatedLink);

        expect(result, isTrue);
        verify(() => collapsedMockJournalDb.upsertEntryLink(any())).called(1);
        verify(() => collapsedMockUpdateNotifications.notify(any())).called(1);
        verify(
          () => collapsedMockVectorClockService.getNextVectorClock(
            previous: any(named: 'previous'),
            payload: any(named: 'payload'),
          ),
        ).called(1);
        verify(
          () => collapsedMockOutboxService.enqueueMessage(any()),
        ).called(1);
      });

      test('skips update when collapsed is unchanged (both null)', () async {
        final testLink = EntryLink.basic(
          id: 'link-id',
          fromId: 'from-id',
          toId: 'to-id',
          createdAt: DateTime(2023),
          updatedAt: DateTime(2023),
          vectorClock: null,
        );

        when(
          () => collapsedMockJournalDb.entryLinkById(testLink.id),
        ).thenAnswer((_) async => testLink);

        final result = await collapsedRepository.updateLink(testLink);

        expect(result, isFalse);
        verifyNever(() => collapsedMockJournalDb.upsertEntryLink(any()));
        verifyNever(() => collapsedMockOutboxService.enqueueMessage(any()));
      });

      test('skips update when collapsed is unchanged (both false)', () async {
        final testLink = EntryLink.basic(
          id: 'link-id',
          fromId: 'from-id',
          toId: 'to-id',
          createdAt: DateTime(2023),
          updatedAt: DateTime(2023),
          vectorClock: null,
          collapsed: false,
        );
        final existing = testLink.copyWith(collapsed: false);

        when(
          () => collapsedMockJournalDb.entryLinkById(testLink.id),
        ).thenAnswer((_) async => existing);

        final result = await collapsedRepository.updateLink(testLink);

        expect(result, isFalse);
        verifyNever(() => collapsedMockJournalDb.upsertEntryLink(any()));
      });

      test('treats null and false collapsed as equivalent', () async {
        final existingLink = EntryLink.basic(
          id: 'link-id',
          fromId: 'from-id',
          toId: 'to-id',
          createdAt: DateTime(2023),
          updatedAt: DateTime(2023),
          vectorClock: null,
          // collapsed is null
        );
        final incomingLink = existingLink.copyWith(collapsed: false);

        when(
          () => collapsedMockJournalDb.entryLinkById(incomingLink.id),
        ).thenAnswer((_) async => existingLink);

        final result = await collapsedRepository.updateLink(incomingLink);

        expect(result, isFalse);
        verifyNever(() => collapsedMockJournalDb.upsertEntryLink(any()));
      });

      test('syncs collapsed true -> false to other devices', () async {
        final existingLink = EntryLink.basic(
          id: 'link-id',
          fromId: 'from-id',
          toId: 'to-id',
          createdAt: DateTime(2023),
          updatedAt: DateTime(2023),
          vectorClock: null,
          collapsed: true,
        );
        final incomingLink = existingLink.copyWith(collapsed: false);

        when(
          () => collapsedMockJournalDb.entryLinkById(incomingLink.id),
        ).thenAnswer((_) async => existingLink);
        when(
          () => collapsedMockVectorClockService.getNextVectorClock(
            previous: any(named: 'previous'),
            payload: any(named: 'payload'),
          ),
        ).thenAnswer((_) async => const VectorClock({'node1': 1}));
        when(
          () => collapsedMockJournalDb.upsertEntryLink(any()),
        ).thenAnswer((_) async => 1);
        when(
          () => collapsedMockUpdateNotifications.notify(any()),
        ).thenAnswer((_) async {});
        when(
          () => collapsedMockOutboxService.enqueueMessage(any()),
        ).thenAnswer((_) async {});

        final result = await collapsedRepository.updateLink(incomingLink);

        expect(result, isTrue);
        verify(() => collapsedMockJournalDb.upsertEntryLink(any())).called(1);
        verify(
          () => collapsedMockVectorClockService.getNextVectorClock(
            previous: any(named: 'previous'),
            payload: any(named: 'payload'),
          ),
        ).called(1);
        verify(
          () => collapsedMockOutboxService.enqueueMessage(any()),
        ).called(1);
      });

      test('notifies affected IDs after collapsed update', () async {
        final testLink = EntryLink.basic(
          id: 'link-id',
          fromId: 'from-id',
          toId: 'to-id',
          createdAt: DateTime(2023),
          updatedAt: DateTime(2023),
          vectorClock: null,
        );
        final updatedLink = testLink.copyWith(collapsed: true);

        when(
          () => collapsedMockJournalDb.entryLinkById(updatedLink.id),
        ).thenAnswer((_) async => testLink);
        when(
          () => collapsedMockVectorClockService.getNextVectorClock(
            previous: any(named: 'previous'),
            payload: any(named: 'payload'),
          ),
        ).thenAnswer((_) async => const VectorClock({'node1': 1}));
        when(
          () => collapsedMockJournalDb.upsertEntryLink(any()),
        ).thenAnswer((_) async => 1);
        when(
          () => collapsedMockUpdateNotifications.notify(any()),
        ).thenAnswer((_) async {});
        when(
          () => collapsedMockOutboxService.enqueueMessage(any()),
        ).thenAnswer((_) async {});

        await collapsedRepository.updateLink(updatedLink);

        verify(
          () => collapsedMockUpdateNotifications.notify({
            'from-id',
            'to-id',
            linkNotification,
          }),
        ).called(1);
      });
    });

    group('_hasChange via updateLink', () {
      test('detects fromId change as meaningful', () async {
        final existing = EntryLink.basic(
          id: 'link-id',
          fromId: 'from-1',
          toId: 'to-id',
          createdAt: DateTime(2023),
          updatedAt: DateTime(2023),
          vectorClock: null,
        );
        final incoming = EntryLink.basic(
          id: 'link-id',
          fromId: 'from-2',
          toId: 'to-id',
          createdAt: DateTime(2023),
          updatedAt: DateTime(2023),
          vectorClock: null,
        );

        when(
          () => collapsedMockJournalDb.entryLinkById(incoming.id),
        ).thenAnswer((_) async => existing);
        when(
          () => collapsedMockVectorClockService.getNextVectorClock(
            previous: any(named: 'previous'),
            payload: any(named: 'payload'),
          ),
        ).thenAnswer((_) async => const VectorClock({'node1': 1}));
        when(
          () => collapsedMockJournalDb.upsertEntryLink(any()),
        ).thenAnswer((_) async => 1);
        when(
          () => collapsedMockUpdateNotifications.notify(any()),
        ).thenAnswer((_) async {});
        when(
          () => collapsedMockOutboxService.enqueueMessage(any()),
        ).thenAnswer((_) async {});

        final result = await collapsedRepository.updateLink(incoming);

        expect(result, isTrue);
        verify(() => collapsedMockJournalDb.upsertEntryLink(any())).called(1);
      });

      test('detects toId change as meaningful', () async {
        final existing = EntryLink.basic(
          id: 'link-id',
          fromId: 'from-id',
          toId: 'to-1',
          createdAt: DateTime(2023),
          updatedAt: DateTime(2023),
          vectorClock: null,
        );
        final incoming = EntryLink.basic(
          id: 'link-id',
          fromId: 'from-id',
          toId: 'to-2',
          createdAt: DateTime(2023),
          updatedAt: DateTime(2023),
          vectorClock: null,
        );

        when(
          () => collapsedMockJournalDb.entryLinkById(incoming.id),
        ).thenAnswer((_) async => existing);
        when(
          () => collapsedMockVectorClockService.getNextVectorClock(
            previous: any(named: 'previous'),
            payload: any(named: 'payload'),
          ),
        ).thenAnswer((_) async => const VectorClock({'node1': 1}));
        when(
          () => collapsedMockJournalDb.upsertEntryLink(any()),
        ).thenAnswer((_) async => 1);
        when(
          () => collapsedMockUpdateNotifications.notify(any()),
        ).thenAnswer((_) async {});
        when(
          () => collapsedMockOutboxService.enqueueMessage(any()),
        ).thenAnswer((_) async {});

        final result = await collapsedRepository.updateLink(incoming);

        expect(result, isTrue);
        verify(() => collapsedMockJournalDb.upsertEntryLink(any())).called(1);
      });

      test('detects createdAt change as meaningful', () async {
        final existing = EntryLink.basic(
          id: 'link-id',
          fromId: 'from-id',
          toId: 'to-id',
          createdAt: DateTime(2023),
          updatedAt: DateTime(2023),
          vectorClock: null,
        );
        final incoming = EntryLink.basic(
          id: 'link-id',
          fromId: 'from-id',
          toId: 'to-id',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2023),
          vectorClock: null,
        );

        when(
          () => collapsedMockJournalDb.entryLinkById(incoming.id),
        ).thenAnswer((_) async => existing);
        when(
          () => collapsedMockVectorClockService.getNextVectorClock(
            previous: any(named: 'previous'),
            payload: any(named: 'payload'),
          ),
        ).thenAnswer((_) async => const VectorClock({'node1': 1}));
        when(
          () => collapsedMockJournalDb.upsertEntryLink(any()),
        ).thenAnswer((_) async => 1);
        when(
          () => collapsedMockUpdateNotifications.notify(any()),
        ).thenAnswer((_) async {});
        when(
          () => collapsedMockOutboxService.enqueueMessage(any()),
        ).thenAnswer((_) async {});

        final result = await collapsedRepository.updateLink(incoming);

        expect(result, isTrue);
      });

      test('detects deletedAt change as meaningful', () async {
        final existing = EntryLink.basic(
          id: 'link-id',
          fromId: 'from-id',
          toId: 'to-id',
          createdAt: DateTime(2023),
          updatedAt: DateTime(2023),
          vectorClock: null,
        );
        final incoming = EntryLink.basic(
          id: 'link-id',
          fromId: 'from-id',
          toId: 'to-id',
          createdAt: DateTime(2023),
          updatedAt: DateTime(2023),
          vectorClock: null,
          deletedAt: DateTime(2024),
        );

        when(
          () => collapsedMockJournalDb.entryLinkById(incoming.id),
        ).thenAnswer((_) async => existing);
        when(
          () => collapsedMockVectorClockService.getNextVectorClock(
            previous: any(named: 'previous'),
            payload: any(named: 'payload'),
          ),
        ).thenAnswer((_) async => const VectorClock({'node1': 1}));
        when(
          () => collapsedMockJournalDb.upsertEntryLink(any()),
        ).thenAnswer((_) async => 1);
        when(
          () => collapsedMockUpdateNotifications.notify(any()),
        ).thenAnswer((_) async {});
        when(
          () => collapsedMockOutboxService.enqueueMessage(any()),
        ).thenAnswer((_) async {});

        final result = await collapsedRepository.updateLink(incoming);

        expect(result, isTrue);
      });

      test('includes collapsed in sync payload', () async {
        final existing = EntryLink.basic(
          id: 'link-id',
          fromId: 'from-id',
          toId: 'to-id',
          createdAt: DateTime(2023),
          updatedAt: DateTime(2023),
          vectorClock: null,
          collapsed: true,
        );
        // Change hidden while collapsed is true
        final incoming = existing.copyWith(hidden: true);

        when(
          () => collapsedMockJournalDb.entryLinkById(incoming.id),
        ).thenAnswer((_) async => existing);
        when(
          () => collapsedMockVectorClockService.getNextVectorClock(
            previous: any(named: 'previous'),
            payload: any(named: 'payload'),
          ),
        ).thenAnswer((_) async => const VectorClock({'node1': 1}));
        when(
          () => collapsedMockJournalDb.upsertEntryLink(any()),
        ).thenAnswer((_) async => 1);
        when(
          () => collapsedMockUpdateNotifications.notify(any()),
        ).thenAnswer((_) async {});
        when(
          () => collapsedMockOutboxService.enqueueMessage(any()),
        ).thenAnswer((_) async {});

        await collapsedRepository.updateLink(incoming);

        // Verify the sync message includes collapsed state
        final captured =
            verify(
                  () => collapsedMockOutboxService.enqueueMessage(captureAny()),
                ).captured.single
                as SyncEntryLink;
        expect(captured.entryLink.collapsed, isTrue);
      });

      test('detects hidden change as meaningful', () async {
        final existing = EntryLink.basic(
          id: 'link-id',
          fromId: 'from-id',
          toId: 'to-id',
          createdAt: DateTime(2023),
          updatedAt: DateTime(2023),
          vectorClock: null,
        );
        final incoming = EntryLink.basic(
          id: 'link-id',
          fromId: 'from-id',
          toId: 'to-id',
          createdAt: DateTime(2023),
          updatedAt: DateTime(2023),
          vectorClock: null,
          hidden: true,
        );

        when(
          () => collapsedMockJournalDb.entryLinkById(incoming.id),
        ).thenAnswer((_) async => existing);
        when(
          () => collapsedMockVectorClockService.getNextVectorClock(
            previous: any(named: 'previous'),
            payload: any(named: 'payload'),
          ),
        ).thenAnswer((_) async => const VectorClock({'node1': 1}));
        when(
          () => collapsedMockJournalDb.upsertEntryLink(any()),
        ).thenAnswer((_) async => 1);
        when(
          () => collapsedMockUpdateNotifications.notify(any()),
        ).thenAnswer((_) async {});
        when(
          () => collapsedMockOutboxService.enqueueMessage(any()),
        ).thenAnswer((_) async {});

        final result = await collapsedRepository.updateLink(incoming);

        expect(result, isTrue);
      });

      test(
        'detects a link-type-only change as meaningful (everything else '
        'identical)',
        () async {
          final existing = EntryLink.followsUp(
            id: 'link-id',
            fromId: 'from-id',
            toId: 'to-id',
            createdAt: DateTime(2023),
            updatedAt: DateTime(2023),
            vectorClock: null,
          );
          final incoming = EntryLink.blocks(
            id: 'link-id',
            fromId: 'from-id',
            toId: 'to-id',
            createdAt: DateTime(2023),
            updatedAt: DateTime(2023),
            vectorClock: null,
          );

          when(
            () => collapsedMockJournalDb.entryLinkById(incoming.id),
          ).thenAnswer((_) async => existing);
          when(
            () => collapsedMockVectorClockService.getNextVectorClock(
              previous: any(named: 'previous'),
              payload: any(named: 'payload'),
            ),
          ).thenAnswer((_) async => const VectorClock({'node1': 1}));
          when(
            () => collapsedMockJournalDb.upsertEntryLink(any()),
          ).thenAnswer((_) async => 1);
          when(
            () => collapsedMockUpdateNotifications.notify(any()),
          ).thenAnswer((_) async {});
          when(
            () => collapsedMockOutboxService.enqueueMessage(any()),
          ).thenAnswer((_) async {});

          final result = await collapsedRepository.updateLink(incoming);

          expect(result, isTrue);
          final persisted =
              verify(
                    () => collapsedMockJournalDb.upsertEntryLink(captureAny()),
                  ).captured.single
                  as EntryLink;
          expect(persisted, isA<BlocksLink>());
        },
      );

      test('skips update when no fields changed', () async {
        final link = EntryLink.basic(
          id: 'link-id',
          fromId: 'from-id',
          toId: 'to-id',
          createdAt: DateTime(2023),
          updatedAt: DateTime(2023),
          vectorClock: null,
          hidden: true,
          collapsed: true,
        );

        when(
          () => collapsedMockJournalDb.entryLinkById(link.id),
        ).thenAnswer((_) async => link);

        final result = await collapsedRepository.updateLink(link);

        expect(result, isFalse);
        verifyNever(() => collapsedMockJournalDb.upsertEntryLink(any()));
      });

      test('proceeds when existing link is null (new link)', () async {
        final link = EntryLink.basic(
          id: 'new-link',
          fromId: 'from-id',
          toId: 'to-id',
          createdAt: DateTime(2023),
          updatedAt: DateTime(2023),
          vectorClock: null,
        );

        when(
          () => collapsedMockJournalDb.entryLinkById(link.id),
        ).thenAnswer((_) async => null);
        when(
          () => collapsedMockVectorClockService.getNextVectorClock(
            previous: any(named: 'previous'),
            payload: any(named: 'payload'),
          ),
        ).thenAnswer((_) async => const VectorClock({'node1': 1}));
        when(
          () => collapsedMockJournalDb.upsertEntryLink(any()),
        ).thenAnswer((_) async => 1);
        when(
          () => collapsedMockUpdateNotifications.notify(any()),
        ).thenAnswer((_) async {});
        when(
          () => collapsedMockOutboxService.enqueueMessage(any()),
        ).thenAnswer((_) async {});

        final result = await collapsedRepository.updateLink(link);

        expect(result, isTrue);
        verify(() => collapsedMockJournalDb.upsertEntryLink(any())).called(1);
      });
    });

    group('updateLinkType', () {
      void stubSuccessfulUpsert() {
        when(
          () => collapsedMockVectorClockService.getNextVectorClock(
            previous: any(named: 'previous'),
            payload: any(named: 'payload'),
          ),
        ).thenAnswer((_) async => const VectorClock({'node1': 1}));
        when(
          () => collapsedMockJournalDb.upsertEntryLink(any()),
        ).thenAnswer((_) async => 1);
        when(
          () => collapsedMockUpdateNotifications.notify(any()),
        ).thenAnswer((_) async {});
        when(
          () => collapsedMockOutboxService.enqueueMessage(any()),
        ).thenAnswer((_) async {});
      }

      test(
        'retypes an existing link in place: same id, bumped VC, synced',
        () async {
          final existing = EntryLink.followsUp(
            id: 'link-id',
            fromId: 'from-id',
            toId: 'to-id',
            createdAt: DateTime(2023),
            updatedAt: DateTime(2023),
            vectorClock: const VectorClock({'node1': 0}),
          );
          when(
            () => collapsedMockJournalDb.entryLinkById('link-id'),
          ).thenAnswer((_) async => existing);
          when(
            () => collapsedMockJournalDb.typedLinksForTaskIds(
              any(),
              types: any(named: 'types'),
            ),
          ).thenAnswer((_) async => <EntryLink>[]);
          stubSuccessfulUpsert();

          final result = await collapsedRepository.updateLinkType(
            linkId: 'link-id',
            newType: EntryLinkType.blocks,
            swapDirection: false,
          );

          expect(result, isTrue);
          final persisted =
              verify(
                    () => collapsedMockJournalDb.upsertEntryLink(captureAny()),
                  ).captured.single
                  as EntryLink;
          expect(persisted, isA<BlocksLink>());
          expect(persisted.id, 'link-id');
          expect(persisted.fromId, 'from-id');
          expect(persisted.toId, 'to-id');
          verify(
            () => collapsedMockOutboxService.enqueueMessage(
              SyncMessage.entryLink(
                entryLink: persisted,
                status: SyncEntryStatus.update,
              ),
            ),
          ).called(1);
        },
      );

      test(
        'swapDirection flips fromId/toId while keeping the same type',
        () async {
          final existing = EntryLink.followsUp(
            id: 'link-id',
            fromId: 'a',
            toId: 'b',
            createdAt: DateTime(2023),
            updatedAt: DateTime(2023),
            vectorClock: null,
          );
          when(
            () => collapsedMockJournalDb.entryLinkById('link-id'),
          ).thenAnswer((_) async => existing);
          stubSuccessfulUpsert();

          final result = await collapsedRepository.updateLinkType(
            linkId: 'link-id',
            newType: EntryLinkType.followsUp,
            swapDirection: true,
          );

          expect(result, isTrue);
          final persisted =
              verify(
                    () => collapsedMockJournalDb.upsertEntryLink(captureAny()),
                  ).captured.single
                  as EntryLink;
          expect(persisted, isA<FollowsUpLink>());
          expect(persisted.fromId, 'b');
          expect(persisted.toId, 'a');
        },
      );

      test(
        'rejects a retype to blocks that would close a cycle via an '
        'unrelated existing blocks edge',
        () async {
          // 'flip-me' is a followsUp link (x->y) being retyped to blocks.
          // A separate, real blocks edge (y->x) already exists, so the
          // retype must be rejected exactly like a fresh create would be.
          final existing = EntryLink.followsUp(
            id: 'flip-me',
            fromId: 'x',
            toId: 'y',
            createdAt: DateTime(2023),
            updatedAt: DateTime(2023),
            vectorClock: null,
          );
          when(
            () => collapsedMockJournalDb.entryLinkById('flip-me'),
          ).thenAnswer((_) async => existing);
          when(
            () => collapsedMockJournalDb.typedLinksForTaskIds(
              {'y'},
              types: {'BlocksLink'},
            ),
          ).thenAnswer(
            (_) async => [
              EntryLink.blocks(
                id: 'other-edge',
                fromId: 'y',
                toId: 'x',
                createdAt: DateTime(2023),
                updatedAt: DateTime(2023),
                vectorClock: null,
              ),
            ],
          );

          final result = await collapsedRepository.updateLinkType(
            linkId: 'flip-me',
            newType: EntryLinkType.blocks,
            swapDirection: false,
          );

          expect(result, isFalse);
          verifyNever(() => collapsedMockJournalDb.upsertEntryLink(any()));
        },
      );

      test(
        'a direction flip on an existing blocks edge is not rejected '
        'against its own stale row',
        () async {
          final existing = EntryLink.blocks(
            id: 'flip-me',
            fromId: 'a',
            toId: 'b',
            createdAt: DateTime(2023),
            updatedAt: DateTime(2023),
            vectorClock: null,
          );
          when(
            () => collapsedMockJournalDb.entryLinkById('flip-me'),
          ).thenAnswer((_) async => existing);
          when(
            () => collapsedMockJournalDb.typedLinksForTaskIds(
              {'a'},
              types: {'BlocksLink'},
            ),
          ).thenAnswer((_) async => [existing]);
          stubSuccessfulUpsert();

          final result = await collapsedRepository.updateLinkType(
            linkId: 'flip-me',
            newType: EntryLinkType.blocks,
            swapDirection: true,
          );

          expect(result, isTrue);
          verify(() => collapsedMockJournalDb.upsertEntryLink(any())).called(1);
        },
      );

      test(
        'checks the cycle again inside the write: a blocks link stored after '
        'the first check refuses the retype (ADR 0106)',
        () async {
          final existing = EntryLink.followsUp(
            id: 'retype-me',
            fromId: 'a',
            toId: 'b',
            createdAt: DateTime(2023),
            updatedAt: DateTime(2023),
            vectorClock: null,
          );
          when(
            () => collapsedMockJournalDb.entryLinkById('retype-me'),
          ).thenAnswer((_) async => existing);
          // The first check finds nothing; by the write, another writer on
          // this device has stored b -> a.
          var reads = 0;
          when(
            () => collapsedMockJournalDb.typedLinksForTaskIds(
              {'b'},
              types: {'BlocksLink'},
            ),
          ).thenAnswer(
            (_) async => [
              if (++reads > 1)
                EntryLink.blocks(
                  id: 'raced-in',
                  fromId: 'b',
                  toId: 'a',
                  createdAt: DateTime(2023),
                  updatedAt: DateTime(2023),
                  vectorClock: null,
                ),
            ],
          );
          stubSuccessfulUpsert();

          final result = await collapsedRepository.updateLinkType(
            linkId: 'retype-me',
            newType: EntryLinkType.blocks,
            swapDirection: false,
          );

          expect(result, isFalse);
          expect(reads, 2);
          verifyNever(() => collapsedMockJournalDb.upsertEntryLink(any()));
        },
      );

      test(
        'refuses the retype when the link is no longer stored as it was read',
        () async {
          final existing = EntryLink.followsUp(
            id: 'retype-me',
            fromId: 'a',
            toId: 'b',
            createdAt: DateTime(2023),
            updatedAt: DateTime(2023),
            vectorClock: null,
          );
          // The retype and updateLink read the link as it was; by the write
          // it has been removed.
          var reads = 0;
          when(
            () => collapsedMockJournalDb.entryLinkById('retype-me'),
          ).thenAnswer(
            (_) async => ++reads > 2
                ? existing.copyWith(deletedAt: DateTime(2023, 2))
                : existing,
          );
          when(
            () => collapsedMockJournalDb.typedLinksForTaskIds(
              any(),
              types: any(named: 'types'),
            ),
          ).thenAnswer((_) async => <EntryLink>[]);
          stubSuccessfulUpsert();

          final result = await collapsedRepository.updateLinkType(
            linkId: 'retype-me',
            newType: EntryLinkType.blocks,
            swapDirection: false,
          );

          expect(result, isFalse);
          verifyNever(() => collapsedMockJournalDb.upsertEntryLink(any()));
        },
      );

      test(
        'refuses to move a link onto a relationship another live link is, '
        'and moves it onto a removed one',
        () async {
          final existing = EntryLink.basic(
            id: 'retype-me',
            fromId: 'a',
            toId: 'b',
            createdAt: DateTime(2023),
            updatedAt: DateTime(2023),
            vectorClock: null,
          );
          final occupant = EntryLink.followsUp(
            id: 'occupant',
            fromId: 'a',
            toId: 'b',
            createdAt: DateTime(2023),
            updatedAt: DateTime(2023),
            vectorClock: null,
          );
          when(
            () => collapsedMockJournalDb.entryLinkById('retype-me'),
          ).thenAnswer((_) async => existing);
          when(
            () => collapsedMockJournalDb.linksBetween(
              'a',
              'b',
              type: 'FollowsUpLink',
            ),
          ).thenAnswer((_) async => [occupant]);
          stubSuccessfulUpsert();

          Future<bool> retype() => collapsedRepository.updateLinkType(
            linkId: 'retype-me',
            newType: EntryLinkType.followsUp,
            swapDirection: false,
          );

          // The receive keeps one version per relationship, so the retype
          // would replace the occupant rather than sit beside it.
          expect(await retype(), isFalse);
          verifyNever(() => collapsedMockJournalDb.upsertEntryLink(any()));

          when(
            () => collapsedMockJournalDb.linksBetween(
              'a',
              'b',
              type: 'FollowsUpLink',
            ),
          ).thenAnswer(
            (_) async => [
              occupant.copyWith(hidden: true, deletedAt: DateTime(2023)),
            ],
          );
          expect(await retype(), isTrue);
          verify(() => collapsedMockJournalDb.upsertEntryLink(any())).called(1);
        },
      );

      test('returns false when linkId no longer resolves to a link', () async {
        when(
          () => collapsedMockJournalDb.entryLinkById('missing'),
        ).thenAnswer((_) async => null);

        final result = await collapsedRepository.updateLinkType(
          linkId: 'missing',
          newType: EntryLinkType.blocks,
          swapDirection: false,
        );

        expect(result, isFalse);
        verifyNever(() => collapsedMockJournalDb.upsertEntryLink(any()));
      });
    });
  });

  group('updateLink across devices', () {
    late JournalDb db;
    late MockOutboxService outboxService;

    setUpAll(registerAllFallbackValues);

    setUp(() async {
      db = JournalDb(inMemoryDatabase: true);
      outboxService = MockOutboxService();
      when(() => outboxService.enqueueMessage(any())).thenAnswer((_) async {});
      await setUpTestGetIt(
        additionalSetup: () {
          getIt
            ..unregister<JournalDb>()
            ..registerSingleton<JournalDb>(db)
            ..registerSingleton<OutboxService>(outboxService)
            // The real service: the clock it reserves is what is under test.
            ..registerSingleton<VectorClockService>(buildVectorClockService());
        },
      );
      // A fresh device: its first counter is 0, which VectorClock.compare
      // reads the same as an absent host — the link order must not.
      await getIt<VectorClockService>().initialized;
    });

    tearDown(() async {
      await tearDownTestGetIt();
      await db.close();
    });

    test(
      'an edit made here outranks a later-stamped copy of the version it '
      'replaced, so the edit is not undone when that copy arrives',
      () async {
        // Device A created the link; its wall clock runs well ahead of ours.
        final fromDeviceA = EntryLink.basic(
          id: 'shared-link',
          fromId: 'task-id',
          toId: 'note-id',
          createdAt: DateTime(2100),
          updatedAt: DateTime(2100),
          vectorClock: const VectorClock({'device-a': 5}),
          collapsed: false,
        );
        expect(await db.upsertEntryLink(fromDeviceA), 1);

        expect(
          await buildJournalRepository().updateLink(
            fromDeviceA.copyWith(collapsed: true),
          ),
          isTrue,
        );
        final edited = (await db.entryLinkById('shared-link'))!;
        final host = (await getIt<VectorClockService>().getHost())!;
        // The edit extends the clock of the version it replaced, and is not
        // stamped earlier than that version.
        expect(edited.vectorClock?.vclock, {
          'device-a': 5,
          host: firstVectorClockCounter,
        });
        expect(edited.updatedAt, DateTime(2100));

        // Device A's next journal-entity message embeds its snapshot of the
        // link as it was; the sync receive upserts it like this.
        expect(await db.upsertEntryLink(fromDeviceA), 0);
        expect(await db.entryLinkById('shared-link'), edited);
        expect(edited.collapsed, isTrue);
      },
    );

    // A card's toggle edits the link as stored (`changeLink`), never the
    // copy it rendered (`specs/tla/EntryLinkIdentity.tla`, EditOnStored).
    EntryLink storedLink({bool collapsed = false, DateTime? deletedAt}) =>
        EntryLink.basic(
          id: 'card-link',
          fromId: 'task-id',
          toId: 'note-id',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: const VectorClock({'device-a': 1}),
          collapsed: collapsed,
          deletedAt: deletedAt,
        );

    test('changeLink sets its flag on the link as stored, keeping a flag '
        'another writer set since the card rendered it', () async {
      final rendered = storedLink();
      expect(await db.upsertEntryLink(rendered), 1);
      // Another device collapses the link after the card rendered it.
      expect(
        await db.upsertEntryLink(
          rendered.copyWith(
            collapsed: true,
            vectorClock: const VectorClock({'device-a': 2}),
          ),
        ),
        1,
      );

      expect(
        await buildJournalRepository().changeLink(
          'card-link',
          (stored) => stored.copyWith(hidden: true),
        ),
        isTrue,
      );

      final written = (await db.entryLinkById('card-link'))!;
      expect(written.hidden, isTrue);
      expect(written.collapsed, isTrue);
    });

    test('changeLink leaves a link removed since the card rendered it '
        'removed, and says so', () async {
      expect(await db.upsertEntryLink(storedLink()), 1);
      final removal = storedLink(deletedAt: DateTime(2024, 3, 16)).copyWith(
        vectorClock: const VectorClock({'device-a': 2}),
        updatedAt: DateTime(2024, 3, 16),
        hidden: true,
      );
      expect(await db.upsertEntryLink(removal), 1);

      expect(
        await buildJournalRepository().changeLink(
          'card-link',
          (stored) => stored.copyWith(collapsed: true),
        ),
        isFalse,
      );
      expect(await db.entryLinkById('card-link'), removal);
      verifyNever(() => outboxService.enqueueMessage(any()));
    });

    test('changeLink writes nothing when its change leaves the link as it '
        'is, and nothing for a link that does not exist', () async {
      expect(await db.upsertEntryLink(storedLink(collapsed: true)), 1);

      expect(
        await buildJournalRepository().changeLink(
          'card-link',
          (stored) => stored.copyWith(collapsed: true),
        ),
        isTrue,
      );
      expect(
        await buildJournalRepository().changeLink(
          'no-such-link',
          (stored) => stored.copyWith(collapsed: true),
        ),
        isFalse,
      );
      verifyNever(() => outboxService.enqueueMessage(any()));
    });
  });

  group('link removal', () {
    late JournalDb db;
    late MockOutboxService outboxService;
    late TestGetItMocks mocks;
    late String host;

    setUpAll(registerAllFallbackValues);

    setUp(() async {
      db = JournalDb(inMemoryDatabase: true);
      outboxService = MockOutboxService();
      when(() => outboxService.enqueueMessage(any())).thenAnswer((_) async {});
      mocks = await setUpTestGetIt(
        additionalSetup: () {
          getIt
            ..unregister<JournalDb>()
            ..registerSingleton<JournalDb>(db)
            ..registerSingleton<OutboxService>(outboxService)
            ..registerSingleton<VectorClockService>(buildVectorClockService());
        },
      );
      await getIt<VectorClockService>().initialized;
      host = (await getIt<VectorClockService>().getHost())!;
    });

    tearDown(() async {
      await tearDownTestGetIt();
      await db.close();
    });

    EntryLink stored(String id, EntryLinkType type, {DateTime? deletedAt}) =>
        type.buildLink(
          id: id,
          fromId: 'task-a',
          toId: 'task-b',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          vectorClock: const VectorClock({'peer': 2}),
          hidden: deletedAt != null,
          deletedAt: deletedAt,
        );

    List<SyncEntryLink> sentLinks() => verify(
      () => outboxService.enqueueMessage(captureAny()),
    ).captured.cast<SyncEntryLink>();

    test(
      'removeTypedLink replaces only that type with a tombstone that '
      'succeeds it, and sends the tombstone',
      () async {
        await db.upsertEntryLink(stored('basic', EntryLinkType.basic));
        await db.upsertEntryLink(stored('blocks', EntryLinkType.blocks));

        final removed = await buildJournalRepository().removeTypedLink(
          fromId: 'task-a',
          toId: 'task-b',
          linkType: 'BlocksLink',
        );

        expect(removed, 1);
        final tombstone = (await db.entryLinkById('blocks'))!;
        expect(tombstone.deletedAt, isNotNull);
        expect(tombstone.hidden, isTrue);
        // Extends the removed version's clock, so it outranks every copy of
        // it on every device.
        expect(tombstone.vectorClock?.vclock, {
          'peer': 2,
          host: firstVectorClockCounter,
        });
        expect(
          await db.entryLinkById('basic'),
          stored('basic', EntryLinkType.basic),
        );
        final live = await db.typedLinksForTaskIds(
          {'task-b'},
          types: {'BasicLink', 'BlocksLink'},
        );
        expect(live.map((link) => link.id), ['basic']);

        final sent = sentLinks().single;
        expect(sent.entryLink, tombstone);
        expect(sent.status, SyncEntryStatus.update);
        verify(
          () => mocks.updateNotifications.notify({
            'task-a',
            'task-b',
            linkNotification,
          }),
        ).called(1);
      },
    );

    test(
      'removeLink removes every live link between the pair, hidden ones '
      'included, and leaves an earlier removal alone',
      () async {
        await db.upsertEntryLink(
          stored('basic', EntryLinkType.basic).copyWith(hidden: true),
        );
        await db.upsertEntryLink(stored('blocks', EntryLinkType.blocks));
        final earlier = stored(
          'follows-up',
          EntryLinkType.followsUp,
          deletedAt: DateTime(2024, 2),
        );
        await db.upsertEntryLink(earlier);

        final removed = await buildJournalRepository().removeLink(
          fromId: 'task-a',
          toId: 'task-b',
        );

        expect(removed, 2);
        final versions = await db.linksBetween('task-a', 'task-b');
        expect(versions, hasLength(3));
        expect(versions.every((link) => link.deletedAt != null), isTrue);
        expect(await db.entryLinkById('follows-up'), earlier);
        expect(sentLinks().map((message) => message.entryLink.id).toSet(), {
          'basic',
          'blocks',
        });
      },
    );

    test(
      'returns 0 and sends nothing when no live link matches',
      () async {
        await db.upsertEntryLink(
          stored('blocks', EntryLinkType.blocks, deletedAt: DateTime(2024, 2)),
        );

        final removed = await buildJournalRepository().removeTypedLink(
          fromId: 'task-a',
          toId: 'task-b',
          linkType: 'BlocksLink',
        );

        expect(removed, 0);
        verifyNever(() => outboxService.enqueueMessage(any()));
      },
    );
  });

  group('link removal across devices', () {
    late _Device deviceA;
    late _Device deviceB;
    late Directory documentsDirectory;

    final entryId = fallbackJournalEntity.meta.id;

    setUpAll(sync_harness.registerSyncProcessorFallbacks);

    setUp(() async {
      sync_harness.setUpProcessorMocks();
      when(
        () => sync_harness.journalEntityLoader.load(
          jsonPath: _Device.snapshotPath,
        ),
      ).thenAnswer((_) async => fallbackJournalEntity);
      // Applying a journal entity writes its JSON sidecar.
      documentsDirectory = Directory.systemTemp.createTempSync('lotti_test_');
      await setUpTestGetIt(
        additionalSetup: () {
          getIt
            ..unregister<JournalDb>()
            ..registerSingleton<Directory>(documentsDirectory);
        },
      );
      deviceA = await _Device.boot();
      deviceB = await _Device.boot();
    });

    tearDown(() async {
      await tearDownTestGetIt();
      await deviceA.db.close();
      await deviceB.db.close();
      documentsDirectory.deleteSync(recursive: true);
    });

    Future<bool> link(_Device device) => device.act(
      () => PersistenceEntries(
        MockPersistenceLogic(),
        buildPersistenceServices(),
      ).createLink(fromId: entryId, toId: 'note-id'),
    );

    Future<int> unlink(_Device device) => device.act(
      () => buildJournalRepository().removeTypedLink(
        fromId: entryId,
        toId: 'note-id',
        linkType: 'BasicLink',
      ),
    );

    Future<void> expectConverged({required bool live}) async {
      final onA = await deviceA.db.linksBetween(entryId, 'note-id');
      final onB = await deviceB.db.linksBetween(entryId, 'note-id');
      expect(onA, hasLength(1));
      expect(onB, onA);
      expect(onA.single.deletedAt == null, live);
      for (final device in [deviceA, deviceB]) {
        expect(
          await device.db.linksForEntryIdsBidirectional({entryId}),
          live ? onA : isEmpty,
        );
      }
    }

    test('a removal on one device reaches the other', () async {
      expect(await link(deviceA), isTrue);
      await deviceB.receiveAll(deviceA.takeOutgoing());

      expect(await unlink(deviceA), 1);
      await deviceB.receiveAll(deviceA.takeOutgoing());

      await expectConverged(live: false);
    });

    test(
      "the other device's late snapshot does not bring the removed link back",
      () async {
        expect(await link(deviceA), isTrue);
        await deviceB.receiveAll(deviceA.takeOutgoing());
        expect(await unlink(deviceA), 1);

        // B has not heard of the removal yet; its next journal-entity message
        // embeds the link as B holds it — live.
        await deviceA.receive(await deviceB.journalEntityMessage(entryId));
        // The entity itself was applied — only the stale link was refused.
        expect(await deviceA.db.journalEntityById(entryId), isNotNull);
        expect(
          await deviceA.db.linksForEntryIdsBidirectional({entryId}),
          isEmpty,
        );

        await deviceB.receiveAll(deviceA.takeOutgoing());
        await expectConverged(live: false);
      },
    );

    test(
      'linking again after a removal converges, whatever order the versions '
      'arrive in',
      () async {
        expect(await link(deviceA), isTrue);
        await deviceB.receiveAll(deviceA.takeOutgoing());
        expect(await unlink(deviceA), 1);
        expect(await link(deviceA), isTrue);

        // The re-link arrives first, the removal it succeeds after it.
        await deviceB.receiveAll(deviceA.takeOutgoing().reversed);
        await expectConverged(live: true);

        // And B's snapshot of the result changes nothing on A.
        await deviceA.receive(await deviceB.journalEntityMessage(entryId));
        await expectConverged(live: true);
      },
    );

    test(
      'undoing a new link and redoing it converges on the other device, '
      'whatever order the versions arrive in',
      () async {
        expect(await link(deviceA), isTrue);
        // The undo of the "link created" message is local and instant: the
        // link is gone here before anything is delivered.
        expect(await unlink(deviceA), 1);
        expect(
          await deviceA.db.linksForEntryIdsBidirectional({entryId}),
          isEmpty,
        );
        expect(await link(deviceA), isTrue);

        final sent = deviceA.takeOutgoing();
        expect(sent, hasLength(3));
        // The redo overtakes the undo on its way to B.
        await deviceB.receiveAll([sent[0], sent[2], sent[1]]);
        await expectConverged(live: true);
      },
    );

    test(
      'the same link created offline on both devices is one link: a removal '
      "on either stays removed, and the other's snapshot does not bring it "
      'back',
      () async {
        expect(await link(deviceA), isTrue);
        expect(await link(deviceB), isTrue);
        final fromA = deviceA.takeOutgoing();
        final fromB = deviceB.takeOutgoing();
        await deviceA.receiveAll(fromB);
        await deviceB.receiveAll(fromA);
        await expectConverged(live: true);

        expect(await unlink(deviceA), 1);
        // B has not heard of the removal yet and sends its snapshot.
        await deviceA.receive(await deviceB.journalEntityMessage(entryId));
        expect(
          await deviceA.db.linksForEntryIdsBidirectional({entryId}),
          isEmpty,
        );

        await deviceB.receiveAll(deviceA.takeOutgoing());
        await expectConverged(live: false);
        await deviceA.receive(await deviceB.journalEntityMessage(entryId));
        await expectConverged(live: false);
      },
    );

    for (final (label, stamp) in [
      ('before', DateTime(2024)),
      ('after', DateTime(2100)),
    ]) {
      test(
        'a removal covers the copy an older build created under a random '
        'id, stamped $label the removal',
        () async {
          // B runs a build before ADR 0096: its link has a random id.
          final legacy = EntryLink.basic(
            id: 'legacy-random-id',
            fromId: entryId,
            toId: 'note-id',
            createdAt: stamp,
            updatedAt: stamp,
            vectorClock: const VectorClock({'legacy-host': 1}),
          );
          await deviceB.db.upsertEntryLink(legacy);

          expect(await link(deviceA), isTrue);
          await deviceA.receive(await deviceB.journalEntityMessage(entryId));
          expect(await unlink(deviceA), 1);

          // B's next snapshot still carries its live copy.
          await deviceA.receive(await deviceB.journalEntityMessage(entryId));
          expect(
            await deviceA.db.linksForEntryIdsBidirectional({entryId}),
            isEmpty,
          );

          await deviceB.receiveAll(deviceA.takeOutgoing());
          await expectConverged(live: false);
        },
      );
    }

    test(
      'a removal on the device that did not create the link reaches the '
      'creator, and linking again there brings it back on both',
      () async {
        expect(await link(deviceA), isTrue);
        await deviceB.receiveAll(deviceA.takeOutgoing());

        expect(await unlink(deviceB), 1);
        await deviceA.receiveAll(deviceB.takeOutgoing());
        await expectConverged(live: false);

        expect(await link(deviceA), isTrue);
        await deviceB.receiveAll(deviceA.takeOutgoing());
        await expectConverged(live: true);
      },
    );
  });
}

/// One simulated device for the cross-device link tests: its own database,
/// its own vector-clock host and an outbox that keeps what it would send.
class _Device {
  _Device._(this.db, this.clock, this._outbox);

  /// Where the journal-entity messages below say their entity lives; the
  /// shared loader stub answers it with `fallbackJournalEntity`.
  static const snapshotPath = '/entry.json';

  static Future<_Device> boot() async {
    final outbox = MockOutboxService();
    final device = _Device._(
      JournalDb(inMemoryDatabase: true),
      buildVectorClockService(),
      outbox,
    );
    when(() => outbox.enqueueMessage(any())).thenAnswer((invocation) async {
      device._outgoing.add(invocation.positionalArguments.first as SyncMessage);
    });
    await device.clock.initialized;
    return device;
  }

  final JournalDb db;
  final VectorClockService clock;
  final MockOutboxService _outbox;
  final List<SyncMessage> _outgoing = [];

  /// Runs [action] as this device: the app's singletons resolve to this
  /// device's database, clock and outbox while it runs.
  Future<T> act<T>(Future<T> Function() action) {
    _register<JournalDb>(db);
    _register<VectorClockService>(clock);
    _register<OutboxService>(_outbox);
    return action();
  }

  static void _register<T extends Object>(T instance) {
    if (getIt.isRegistered<T>()) getIt.unregister<T>();
    getIt.registerSingleton<T>(instance);
  }

  /// The messages this device has sent since the last call, oldest first.
  List<SyncMessage> takeOutgoing() {
    final sent = [..._outgoing];
    _outgoing.clear();
    return sent;
  }

  /// Applies [message] here through the real sync receive path.
  Future<void> receive(SyncMessage message) async {
    when(
      () => sync_harness.event.text,
    ).thenReturn(sync_harness.encodeMessage(message));
    await sync_harness.processor.process(
      event: sync_harness.event,
      journalDb: db,
    );
  }

  Future<void> receiveAll(Iterable<SyncMessage> messages) async {
    for (final message in messages) {
      await receive(message);
    }
  }

  /// The journal-entity message this device sends for [entryId]: like the
  /// outbox writer, it embeds this device's snapshot of the entry's links.
  Future<SyncMessage> journalEntityMessage(String entryId) async =>
      SyncMessage.journalEntity(
        id: entryId,
        jsonPath: snapshotPath,
        vectorClock: null,
        status: SyncEntryStatus.update,
        entryLinks: await db.linksForEntryIdsBidirectionalIncludingRemoved({
          entryId,
        }),
      );
}

/// Records what the journal layer asks of the people it cascades into.
class _RecordingCascade implements RelationshipCascade {
  _RecordingCascade({required this.deleteResult});

  final bool deleteResult;
  final deleted = <String>[];
  final updated = <RelationshipEntry>[];

  @override
  Future<bool> deleteRelationship(String relationshipId) async {
    deleted.add(relationshipId);
    return deleteResult;
  }

  @override
  Future<bool> updateRelationship(RelationshipEntry relationship) async {
    updated.add(relationship);
    return true;
  }
}
