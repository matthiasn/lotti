import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/health.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_create_ops.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fallbacks.dart';
import '../mocks/mocks.dart';
import '../widget_test_utils.dart';

/// Mirror test for [PersistenceCreateOps].
///
/// The collaborator must never build metadata or write to the DB itself: it
/// routes both through the injected facade so the virtual-dispatch behaviour
/// test subclasses rely on is preserved. These tests assert that wiring with a
/// [MockPersistenceLogic] standing in as the facade.
void main() {
  late MockPersistenceLogic logic;
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
    await setUpTestGetIt(
      additionalSetup: () {
        getIt.registerSingleton<NotificationService>(MockNotificationService());
      },
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
        () => logic.createDbEntity(
          any<JournalEntity>(),
          linkedId: 'parent-1',
        ),
      ).called(1);
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
}
