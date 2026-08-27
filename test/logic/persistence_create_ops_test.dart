import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/health.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_create_ops.dart';
import 'package:lotti/logic/services/metadata_service.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fallbacks.dart';
import '../mocks/mocks.dart';
import '../test_data/test_data.dart';
import '../widget_test_utils.dart';

/// Mirror test for [PersistenceCreateOps].
///
/// The collaborator must never build metadata or write to the DB itself: it
/// routes both through the injected facade so the virtual-dispatch behaviour
/// test subclasses rely on is preserved. These tests assert that wiring with a
/// [MockPersistenceLogic] standing in as the facade.
void main() {
  late MockPersistenceLogic logic;
  late MockDomainLogger domainLogger;
  late MockJournalDb journalDb;
  late MockMetadataService metadataService;
  late MockVectorClockService vectorClockService;
  late PersistenceCreateOps ops;

  Metadata metaFor(String id) => Metadata(
    id: id,
    createdAt: DateTime(2024, 3, 15),
    updatedAt: DateTime(2024, 3, 15),
    dateFrom: DateTime(2024, 3, 15),
    dateTo: DateTime(2024, 3, 15),
  );

  setUp(() async {
    registerAllFallbackValues();
    domainLogger = MockDomainLogger();
    metadataService = MockMetadataService();
    vectorClockService = MockVectorClockService();
    when(() => vectorClockService.getHost()).thenAnswer((_) async => 'host-a');
    final mocks = await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..unregister<DomainLogger>()
          ..registerSingleton<DomainLogger>(domainLogger)
          ..registerSingleton<MetadataService>(metadataService)
          ..registerSingleton<VectorClockService>(vectorClockService)
          ..registerSingleton<NotificationService>(MockNotificationService());
      },
    );
    journalDb = mocks.journalDb;
    when(
      () => metadataService.generateId(uuidV5Input: any(named: 'uuidV5Input')),
    ).thenAnswer(
      (invocation) =>
          'id:${invocation.namedArguments[const Symbol('uuidV5Input')]}',
    );
    logic = MockPersistenceLogic();
    ops = PersistenceCreateOps(logic);

    when(
      () => logic.createMetadata(
        dateFrom: any(named: 'dateFrom'),
        dateTo: any(named: 'dateTo'),
        uuidV5Input: any(named: 'uuidV5Input'),
        private: any(named: 'private'),
        labelIds: any(named: 'labelIds'),
        categoryId: any(named: 'categoryId'),
        starred: any(named: 'starred'),
        flag: any(named: 'flag'),
      ),
    ).thenAnswer((_) async => metaFor('meta-id'));
    when(
      () => logic.createDbEntity(
        any(),
        shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
        enqueueSync: any(named: 'enqueueSync'),
        linkedId: any(named: 'linkedId'),
      ),
    ).thenAnswer((_) async => true);
  });

  tearDown(tearDownTestGetIt);

  test(
    'createQuantitativeEntryImpl builds via facade and skips geolocation',
    () async {
      final result = await ops.createQuantitativeEntryImpl(
        QuantitativeData.cumulativeQuantityData(
          dateFrom: DateTime(2024, 3, 15),
          dateTo: DateTime(2024, 3, 15),
          value: 1,
          dataType: 'steps',
          unit: 'count',
        ),
      );

      expect(result, isA<QuantitativeEntry>());
      final captured = verify(
        () => logic.createDbEntity(
          captureAny(),
          shouldAddGeolocation: captureAny(named: 'shouldAddGeolocation'),
          enqueueSync: any(named: 'enqueueSync'),
          linkedId: any(named: 'linkedId'),
        ),
      ).captured;
      expect(captured[0], isA<QuantitativeEntry>());
      // Quantitative entries are never auto-geolocated.
      expect(captured[1], isFalse);
    },
  );

  // Health entries carry deterministic uuidV5 ids and are written with
  // `overwrite: false`, so re-importing an already-stored range is rejected row
  // by row. Returning the entity anyway left callers unable to tell a fresh
  // sample from a duplicate — the health import counted both.
  test(
    'createQuantitativeEntryImpl returns null on a rejected write',
    () async {
      when(
        () => logic.createDbEntity(
          any(),
          shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
          enqueueSync: any(named: 'enqueueSync'),
          linkedId: any(named: 'linkedId'),
        ),
      ).thenAnswer((_) async => false);

      final result = await ops.createQuantitativeEntryImpl(
        QuantitativeData.cumulativeQuantityData(
          dateFrom: DateTime(2024, 3, 15),
          dateTo: DateTime(2024, 3, 15),
          value: 1,
          dataType: 'steps',
          unit: 'count',
        ),
      );

      expect(result, isNull);
    },
  );

  group('createQuantitativeEntryImpl — cumulative days', () {
    final day = DateTime(2026, 8, 26);
    CumulativeQuantityData steps(num value, {DateTime? dateTo}) =>
        CumulativeQuantityData(
          dateFrom: day,
          dateTo: dateTo ?? DateTime(2026, 8, 26, 23, 59, 59, 999),
          value: value,
          dataType: 'cumulative_step_count',
          unit: 'count',
          deviceType: 'iPhone17,1',
          platformType: 'IOS',
        );
    const dayId = 'id:cumulative:cumulative_step_count:2026-08-26:host-a';

    QuantitativeEntry stored(num value) => QuantitativeEntry(
      data: steps(value),
      meta: metaFor(dayId).copyWith(dateFrom: day),
    );

    setUp(() {
      when(
        () => logic.updateMetadata(
          any(),
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
        ),
      ).thenAnswer(
        (invocation) async => invocation.positionalArguments.first as Metadata,
      );
      when(() => logic.updateDbEntity(any())).thenAnswer((_) async => true);
    });

    test('the id is keyed by type, local calendar day and sync host', () {
      String idOf(CumulativeQuantityData data, {String? host = 'host-a'}) =>
          PersistenceCreateOps.cumulativeQuantityEntryId(data, host: host);

      expect(idOf(steps(9800)), idOf(steps(11600)));
      expect(
        idOf(steps(1)),
        'cumulative:cumulative_step_count:2026-08-26:host-a',
      );
      expect(
        idOf(steps(1).copyWith(dateFrom: DateTime(2026, 8, 27))),
        isNot(idOf(steps(1))),
      );
      expect(
        idOf(steps(1).copyWith(dataType: 'cumulative_distance')),
        isNot(idOf(steps(1))),
      );
      // Two installations importing the same day keep separate rows rather
      // than racing for one through sync — even on the same hardware model.
      expect(idOf(steps(1), host: 'host-b'), isNot(idOf(steps(1))));
      expect(
        idOf(steps(1).copyWith(deviceType: 'iPad16,3')),
        idOf(steps(1)),
      );
    });

    test(
      'creates the day under its day-keyed id when none is stored',
      () async {
        final result = await ops.createQuantitativeEntryImpl(steps(9800));

        expect(result, isA<QuantitativeEntry>());
        verify(() => journalDb.journalEntityById(dayId)).called(1);
        verify(
          () => logic.createMetadata(
            dateFrom: day,
            dateTo: DateTime(2026, 8, 26, 23, 59, 59, 999),
            uuidV5Input: 'cumulative:cumulative_step_count:2026-08-26:host-a',
          ),
        ).called(1);
        verifyNever(() => logic.updateDbEntity(any()));
      },
    );

    // The stale-steps bug: the phone's count was stored before the band
    // synced its (higher) day overnight. Re-importing must replace the day.
    test('overwrites the stored day when the total changed', () async {
      when(
        () => journalDb.journalEntityById(dayId),
      ).thenAnswer((_) async => stored(9800));

      final result = await ops.createQuantitativeEntryImpl(steps(11600));

      expect(result, isA<QuantitativeEntry>());
      expect(result!.data.value, 11600);
      expect(result.meta.id, dayId);
      final updated =
          verify(() => logic.updateDbEntity(captureAny())).captured.single
              as QuantitativeEntry;
      expect(updated.data.value, 11600);
      expect(updated.meta.id, dayId);
      verifyNever(
        () => logic.createDbEntity(
          any(),
          shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
          enqueueSync: any(named: 'enqueueSync'),
          linkedId: any(named: 'linkedId'),
        ),
      );
    });

    test(
      'a lower re-read also overwrites — the store is the authority',
      () async {
        when(
          () => journalDb.journalEntityById(dayId),
        ).thenAnswer((_) async => stored(11600));

        final result = await ops.createQuantitativeEntryImpl(steps(9800));

        expect(result?.data.value, 9800);
        verify(() => logic.updateDbEntity(any())).called(1);
      },
    );

    test('leaves an unchanged day alone and reports nothing written', () async {
      when(
        () => journalDb.journalEntityById(dayId),
      ).thenAnswer((_) async => stored(9800));

      final result = await ops.createQuantitativeEntryImpl(steps(9800));

      expect(result, isNull);
      verifyNever(() => logic.updateDbEntity(any()));
      verifyNever(
        () => logic.createDbEntity(
          any(),
          shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
          enqueueSync: any(named: 'enqueueSync'),
          linkedId: any(named: 'linkedId'),
        ),
      );
    });

    // The day in progress carries "now" as its end, which moves on every
    // background refresh. Only the total decides whether to rewrite.
    test('an advanced end time with the same total is not a rewrite', () async {
      when(
        () => journalDb.journalEntityById(dayId),
      ).thenAnswer(
        (_) async => stored(9800).copyWith(
          data: steps(9800, dateTo: DateTime(2026, 8, 26, 10)),
        ),
      );

      final result = await ops.createQuantitativeEntryImpl(
        steps(9800, dateTo: DateTime(2026, 8, 26, 10, 10)),
      );

      expect(result, isNull);
      verifyNever(() => logic.updateDbEntity(any()));
    });

    test('returns null when the database rejects the rewrite', () async {
      when(
        () => journalDb.journalEntityById(dayId),
      ).thenAnswer((_) async => stored(9800));
      when(() => logic.updateDbEntity(any())).thenAnswer((_) async => false);

      expect(await ops.createQuantitativeEntryImpl(steps(11600)), isNull);
    });

    test(
      'a row under the day id that is not quantitative is not touched',
      () async {
        when(() => journalDb.journalEntityById(dayId)).thenAnswer(
          (_) async => JournalEntity.journalEntry(meta: metaFor(dayId)),
        );

        // Falls through to a create, which the DB will reject as a duplicate —
        // never an update that would clobber a foreign row.
        await ops.createQuantitativeEntryImpl(steps(9800));

        verifyNever(() => logic.updateDbEntity(any()));
        verify(
          () => logic.createDbEntity(
            any(),
            shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
            enqueueSync: any(named: 'enqueueSync'),
            linkedId: any(named: 'linkedId'),
          ),
        ).called(1);
      },
    );

    test('discrete samples keep the payload-keyed id', () async {
      await ops.createQuantitativeEntryImpl(
        QuantitativeData.discreteQuantityData(
          dateFrom: day,
          dateTo: day,
          value: 72,
          dataType: 'HealthDataType.HEART_RATE',
          unit: 'BEATS_PER_MINUTE',
        ),
      );

      verifyNever(() => journalDb.journalEntityById(any()));
      final input =
          verify(
                () => logic.createMetadata(
                  dateFrom: any(named: 'dateFrom'),
                  dateTo: any(named: 'dateTo'),
                  uuidV5Input: captureAny(named: 'uuidV5Input'),
                ),
              ).captured.single
              as String;
      expect(input, contains('"value":72'));
    });
  });

  test('createWorkoutEntryImpl returns null on a rejected write', () async {
    when(
      () => logic.createDbEntity(
        any(),
        shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
        enqueueSync: any(named: 'enqueueSync'),
        linkedId: any(named: 'linkedId'),
      ),
    ).thenAnswer((_) async => false);

    final result = await ops.createWorkoutEntryImpl(
      WorkoutData(
        id: 'w1',
        dateFrom: DateTime(2024, 3, 15),
        dateTo: DateTime(2024, 3, 15, 1),
        workoutType: 'RUNNING',
        energy: 100,
        distance: 1000,
        source: 'test',
      ),
    );

    expect(result, isNull);
  });

  test(
    'createEventEntryImpl forwards linkedId through the facade write',
    () async {
      final result = await ops.createEventEntryImpl(
        data: const EventData(
          title: 'e',
          status: EventStatus.tentative,
          stars: 0,
        ),
        entryText: const EntryText(plainText: 'body'),
        linkedId: 'parent-1',
      );

      expect(result, isA<JournalEvent>());
      verify(
        () => logic.createDbEntity(any<JournalEntity>(), linkedId: 'parent-1'),
      ).called(1);
    },
  );

  test(
    'createTaskEntryImpl returns null when the write is not applied',
    () async {
      when(
        () => logic.createDbEntity(
          any(),
          shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
          enqueueSync: any(named: 'enqueueSync'),
          linkedId: any(named: 'linkedId'),
        ),
      ).thenAnswer((_) async => false);

      // A rejected write does not throw — createDbEntity reports it by
      // returning false and burning the unbound vector clock. Discarding that
      // handed back a Task that is not in the database, which callers then
      // navigate to, link, and confirm as created.
      final result = await ops.createTaskEntryImpl(
        data: TaskData(
          status: TaskStatus.open(
            id: 'status-id',
            createdAt: DateTime(2024, 3, 15),
            utcOffset: 60,
          ),
          title: 'Write the guide',
          statusHistory: const [],
          dateFrom: DateTime(2024, 3, 15),
          dateTo: DateTime(2024, 3, 15),
        ),
        entryText: const EntryText(plainText: ''),
      );

      expect(result, isNull);
    },
  );

  test('createDbEntity returning null surfaces as a null entry impl', () async {
    when(
      () => logic.createDbEntity(
        any(),
        shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
        enqueueSync: any(named: 'enqueueSync'),
        linkedId: any(named: 'linkedId'),
      ),
    ).thenAnswer((_) async => false);

    // habit completion returns null when the write did not apply.
    final result = await ops.createHabitCompletionEntryImpl(
      data: HabitCompletionData(
        habitId: 'h1',
        dateFrom: DateTime(2024, 3, 15),
        dateTo: DateTime(2024, 3, 15),
        completionType: HabitCompletionType.success,
      ),
      habitDefinition: null,
    );

    expect(result, isNull);
  });

  test(
    'a failing reminder does not make a saved completion look unsaved',
    () async {
      // Regression: scheduleHabitNotification threw (on macOS, getLocation
      // rejected the "CEST" abbreviation), the exception escaped to the outer
      // catch, and the method returned null — after createDbEntity had already
      // committed. The caller reads null as "the write didn't commit", so the
      // user got no confirmation for a completion that IS in the database, and
      // would tap again and record a duplicate.
      when(
        () => logic.createDbEntity(
          any(),
          shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
          enqueueSync: any(named: 'enqueueSync'),
          linkedId: any(named: 'linkedId'),
        ),
      ).thenAnswer((_) async => true);

      final notificationService =
          getIt<NotificationService>() as MockNotificationService;
      when(
        () => notificationService.scheduleHabitNotification(
          any(),
          daysToAdd: any(named: 'daysToAdd'),
        ),
      ).thenThrow(
        // The real failure shape.
        ArgumentError('Location with the name "CEST" doesn\'t exist'),
      );

      final result = await ops.createHabitCompletionEntryImpl(
        data: HabitCompletionData(
          habitId: habitFlossing.id,
          dateFrom: DateTime(2024, 3, 15),
          dateTo: DateTime(2024, 3, 15),
          completionType: HabitCompletionType.success,
        ),
        habitDefinition: habitFlossing,
      );

      expect(
        result,
        isNotNull,
        reason:
            'the completion was written; a failed reminder is not a '
            'failed write',
      );
      expect(result!.data.habitId, habitFlossing.id);
      verify(
        () => domainLogger.error(
          LogDomain.persistence,
          any<Object>(),
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'createHabitCompletionEntry.scheduleNotification',
        ),
      ).called(1);
    },
  );
}
