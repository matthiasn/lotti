import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_updates.dart';
import 'package:lotti/logic/services/geolocation_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fallbacks.dart';
import '../mocks/mocks.dart';
import '../test_data/test_data.dart';
import '../widget_test_utils.dart';

/// Mirror test for [PersistenceUpdates].
///
/// Confirms the cross-collaborator wiring that the facade owns:
///   * `updateXxx`/`upsertXxx` wrappers forward to the facade's `*Impl`,
///   * [PersistenceUpdates.updateJournalEntity] runs the metadata refresh and
///     the DB write through the (overridable) facade methods, and
///   * geolocation persists through the facade's `updateDbEntity`, so the
///     [GeolocationService] receives exactly that callback.
void main() {
  late MockPersistenceLogic logic;
  late MockVectorClockService vectorClockService;
  late MockGeolocationService geolocationService;
  late PersistenceUpdates updates;
  late TestGetItMocks mocks;

  setUp(() async {
    registerAllFallbackValues();
    vectorClockService = MockVectorClockService();
    geolocationService = MockGeolocationService();
    mocks = await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..registerSingleton<VectorClockService>(vectorClockService)
          ..registerSingleton<GeolocationService>(geolocationService);
      },
    );
    logic = MockPersistenceLogic();
    updates = PersistenceUpdates(logic);
  });

  tearDown(tearDownTestGetIt);

  test(
    'updateJournalEntry forwards to the facade updateJournalEntryImpl',
    () async {
      when(
        () => logic.updateJournalEntryImpl(
          journalEntityId: any(named: 'journalEntityId'),
          entryText: any(named: 'entryText'),
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
        ),
      ).thenAnswer((_) async => true);

      final ok = await updates.updateJournalEntry(journalEntityId: 'e1');

      expect(ok, isTrue);
      verify(
        () => logic.updateJournalEntryImpl(journalEntityId: 'e1'),
      ).called(1);
    },
  );

  test('upsertDashboardDefinition forwards to the facade impl', () async {
    final dashboard = testDashboardConfig;
    when(
      () => logic.upsertDashboardDefinitionImpl(dashboard),
    ).thenAnswer((_) async => 1);

    final affected = await updates.upsertDashboardDefinition(dashboard);

    expect(affected, 1);
    verify(() => logic.upsertDashboardDefinitionImpl(dashboard)).called(1);
  });

  test(
    'updateJournalEntity routes metadata and write through the facade',
    () async {
      when(
        () => mocks.journalDb.journalEntityById(any()),
      ).thenAnswer((_) async => null);
      when(() => logic.updateMetadata(any())).thenAnswer(
        (invocation) async => invocation.positionalArguments.first as Metadata,
      );
      when(
        () => logic.updateDbEntity(
          any(),
          linkedId: any(named: 'linkedId'),
          enqueueSync: any(named: 'enqueueSync'),
          overrideComparison: any(named: 'overrideComparison'),
          beforeNotify: any(named: 'beforeNotify'),
        ),
      ).thenAnswer((_) async => true);
      when(
        () => mocks.journalDb.addLabeled(any()),
      ).thenAnswer((_) async => 1);

      final ok = await updates.updateJournalEntity(
        testTextEntry,
        testTextEntry.meta,
      );

      expect(ok, isTrue);
      verify(() => logic.updateMetadata(testTextEntry.meta)).called(1);
      verify(
        () => logic.updateDbEntity(
          any(),
          beforeNotify: any(named: 'beforeNotify'),
        ),
      ).called(1);
      // The write applied, so the label index must be refreshed.
      verify(() => mocks.journalDb.addLabeled(any())).called(1);
    },
  );

  test(
    'addGeolocation persists through the facade updateDbEntity callback',
    () async {
      when(
        () => geolocationService.addGeolocation(any(), any()),
      ).thenReturn(null);
      when(() => logic.updateDbEntity(any())).thenAnswer((_) async => true);

      updates.addGeolocation('entry-1');

      final captured =
          verify(
                () =>
                    geolocationService.addGeolocation('entry-1', captureAny()),
              ).captured.single
              as EntityPersister;
      // The persister handed to the geolocation service must be the facade's
      // overridable updateDbEntity, not the collaborator's local method. Invoke
      // it and assert the call lands on the facade.
      final result = await captured(testTextEntry);
      expect(result, isTrue);
      verify(() => logic.updateDbEntity(testTextEntry)).called(1);
    },
  );
}
