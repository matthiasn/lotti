import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/geolocation.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/vector_clock.dart';
import 'package:lotti/logic/services/geolocation_service.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mocks.dart';

class _GeneratedGeolocationPendingScenario {
  const _GeneratedGeolocationPendingScenario({required this.idSlots});

  final List<int> idSlots;

  List<String> get ids => [
    for (final slot in idSlots) 'generated-entry-${slot % 5}',
  ];

  Set<String> get uniqueIds => ids.toSet();

  @override
  String toString() {
    return '_GeneratedGeolocationPendingScenario(ids: $ids)';
  }
}

extension _AnyGeneratedGeolocationPendingScenario on glados.Any {
  glados.Generator<_GeneratedGeolocationPendingScenario>
  get geolocationPendingScenario => glados.ListAnys(this)
      .listWithLengthInRange(1, 12, glados.IntAnys(this).intInRange(0, 1000))
      .map((idSlots) => _GeneratedGeolocationPendingScenario(idSlots: idSlots));
}

/// One stored entry, and the `persist` callback over it, applying a change
/// the way `PersistenceLogic.updateEntity` does: to the entry as stored when
/// the write lands. A missing entry is not written.
class _Store {
  _Store(this.entry);

  JournalEntity? entry;
  int writes = 0;

  Future<bool> persist(
    String id,
    JournalEntity? Function(JournalEntity stored) change,
  ) async {
    final stored = entry;
    if (stored == null || stored.id != id) return false;
    final changed = change(stored);
    if (changed != null) {
      entry = changed;
      writes++;
    }
    return true;
  }
}

Future<bool> _neverCalled(
  String id,
  JournalEntity? Function(JournalEntity stored) change,
) async => fail('persisted without a location');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GeolocationService', () {
    late GeolocationService geolocationService;
    late MockDomainLogger mockDomainLogger;
    late MockDeviceLocation mockDeviceLocation;

    final testGeolocation = Geolocation(
      createdAt: DateTime(2024, 1, 15, 10, 30),
      timezone: 'UTC',
      utcOffset: 0,
      latitude: 52.52,
      longitude: 13.405,
      geohashString: 'u33db2',
    );

    final otherGeolocation = testGeolocation.copyWith(latitude: 48.14);

    JournalEntry createTestEntry({
      String id = 'test-id',
      Geolocation? geolocation,
      String text = 'Test entry',
    }) {
      return JournalEntry(
        meta: Metadata(
          id: id,
          createdAt: DateTime(2024, 1, 15, 10),
          updatedAt: DateTime(2024, 1, 15, 10),
          dateFrom: DateTime(2024, 1, 15, 9),
          dateTo: DateTime(2024, 1, 15, 10),
          vectorClock: const VectorClock({'test-host': 1}),
        ),
        entryText: EntryText(plainText: text),
        geolocation: geolocation,
      );
    }

    setUp(() {
      mockDomainLogger = MockDomainLogger();
      mockDeviceLocation = MockDeviceLocation();

      geolocationService = GeolocationService(
        loggingService: mockDomainLogger,
        deviceLocation: mockDeviceLocation,
      );
    });

    group('addGeolocationAsync', () {
      test('returns null when another operation is already pending', () async {
        final completer = Completer<Geolocation?>();
        when(
          () => mockDeviceLocation.getCurrentGeoLocation(),
        ).thenAnswer((_) => completer.future);

        // Start first operation
        final future1 = geolocationService.addGeolocationAsync(
          'test-id',
          _neverCalled,
        );

        // Second call should return null immediately
        final result = await geolocationService.addGeolocationAsync(
          'test-id',
          _neverCalled,
        );
        expect(result, isNull);

        // Cleanup
        completer.complete(null);
        await future1;
      });

      test('allows concurrent operations for different entity IDs', () async {
        final completer1 = Completer<Geolocation?>();
        final completer2 = Completer<Geolocation?>();

        var callCount = 0;
        when(() => mockDeviceLocation.getCurrentGeoLocation()).thenAnswer((_) {
          callCount++;
          if (callCount == 1) return completer1.future;
          return completer2.future;
        });

        // Start operations for different entities
        final future1 = geolocationService.addGeolocationAsync(
          'test-id-1',
          _neverCalled,
        );
        final future2 = geolocationService.addGeolocationAsync(
          'test-id-2',
          _neverCalled,
        );

        expect(callCount, equals(2));

        // Cleanup
        completer1.complete(null);
        completer2.complete(null);
        await future1;
        await future2;
      });

      test('returns null when device location is null', () async {
        final serviceWithoutLocation = GeolocationService(
          loggingService: mockDomainLogger,
          // deviceLocation is null
        );

        final result = await serviceWithoutLocation.addGeolocationAsync(
          'test-id',
          _neverCalled,
        );

        expect(result, isNull);
      });

      test('returns null when device location returns null', () async {
        when(
          () => mockDeviceLocation.getCurrentGeoLocation(),
        ).thenAnswer((_) async => null);

        final result = await geolocationService.addGeolocationAsync(
          'test-id',
          _neverCalled,
        );

        expect(result, isNull);
      });

      test('returns null when entry does not exist', () async {
        when(
          () => mockDeviceLocation.getCurrentGeoLocation(),
        ).thenAnswer((_) async => testGeolocation);
        final store = _Store(null);

        final result = await geolocationService.addGeolocationAsync(
          'non-existent',
          store.persist,
        );

        expect(result, isNull);
        expect(store.writes, 0);
      });

      test('keeps the geolocation the stored entry already has', () async {
        when(
          () => mockDeviceLocation.getCurrentGeoLocation(),
        ).thenAnswer((_) async => otherGeolocation);
        final store = _Store(createTestEntry(geolocation: testGeolocation));

        final result = await geolocationService.addGeolocationAsync(
          'test-id',
          store.persist,
        );

        expect(result, equals(testGeolocation));
        expect(store.writes, 0);
        expect(store.entry!.geolocation, testGeolocation);
      });

      test('adds geolocation to an entry without one', () async {
        when(
          () => mockDeviceLocation.getCurrentGeoLocation(),
        ).thenAnswer((_) async => testGeolocation);
        final store = _Store(createTestEntry());

        final result = await geolocationService.addGeolocationAsync(
          'test-id',
          store.persist,
        );

        expect(result, equals(testGeolocation));
        expect(store.writes, 1);
        expect(store.entry!.geolocation, equals(testGeolocation));
      });

      test(
        'sets the geolocation on the entry as stored when the fix arrives, '
        'keeping what was written while it was fixed',
        () async {
          final fix = Completer<Geolocation?>();
          when(
            () => mockDeviceLocation.getCurrentGeoLocation(),
          ).thenAnswer((_) => fix.future);
          final store = _Store(createTestEntry());

          final added = geolocationService.addGeolocationAsync(
            'test-id',
            store.persist,
          );
          // Another writer stores a version while the location is fixed.
          store.entry = createTestEntry(text: 'edited meanwhile');
          fix.complete(testGeolocation);

          expect(await added, testGeolocation);
          expect(store.entry!.entryText?.plainText, 'edited meanwhile');
          expect(store.entry!.geolocation, testGeolocation);
        },
      );

      test(
        'does not add a location a concurrent writer already stored',
        () async {
          final fix = Completer<Geolocation?>();
          when(
            () => mockDeviceLocation.getCurrentGeoLocation(),
          ).thenAnswer((_) => fix.future);
          final store = _Store(createTestEntry());

          final added = geolocationService.addGeolocationAsync(
            'test-id',
            store.persist,
          );
          store.entry = createTestEntry(geolocation: otherGeolocation);
          fix.complete(testGeolocation);

          expect(await added, otherGeolocation);
          expect(store.entry!.geolocation, otherGeolocation);
        },
      );

      test('returns null when the write is not stored', () async {
        when(
          () => mockDeviceLocation.getCurrentGeoLocation(),
        ).thenAnswer((_) async => testGeolocation);

        final result = await geolocationService.addGeolocationAsync(
          'test-id',
          (id, change) async => false,
        );

        expect(result, isNull);
      });

      test('logs exception when getting location fails', () async {
        final exception = Exception('Location error');
        when(
          () => mockDeviceLocation.getCurrentGeoLocation(),
        ).thenThrow(exception);

        await geolocationService.addGeolocationAsync('test-id', _neverCalled);

        verify(
          () => mockDomainLogger.error(
            LogDomain.location,
            exception,
            subDomain: 'getCurrentGeoLocation',
          ),
        ).called(1);
      });

      test('logs exception when persistence fails', () async {
        final exception = Exception('Persistence error');
        when(
          () => mockDeviceLocation.getCurrentGeoLocation(),
        ).thenAnswer((_) async => testGeolocation);

        final result = await geolocationService.addGeolocationAsync(
          'test-id',
          (id, change) async => throw exception,
        );

        expect(result, isNull);
        verify(
          () => mockDomainLogger.error(
            LogDomain.location,
            exception,
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
            subDomain: 'addGeolocation',
          ),
        ).called(1);
      });

      test('returns null on error but does not throw', () async {
        when(
          () => mockDeviceLocation.getCurrentGeoLocation(),
        ).thenThrow(Exception('Location error'));

        // Should not throw
        final result = await geolocationService.addGeolocationAsync(
          'test-id',
          _neverCalled,
        );

        expect(result, isNull);
      });
    });

    group('addGeolocation (fire-and-forget)', () {
      test('adds the location without the caller awaiting it', () async {
        final fix = Completer<Geolocation?>();
        when(
          () => mockDeviceLocation.getCurrentGeoLocation(),
        ).thenAnswer((_) => fix.future);
        final store = _Store(createTestEntry());

        // Fire-and-forget call
        geolocationService.addGeolocation('test-id', store.persist);

        verify(() => mockDeviceLocation.getCurrentGeoLocation()).called(1);
        expect(store.writes, 0);

        fix.complete(testGeolocation);
        await pumpEventQueue();

        expect(store.entry!.geolocation, testGeolocation);
      });
    });

    group('race condition prevention', () {
      test('concurrent calls for same entry only process once', () async {
        final locationCompleter = Completer<Geolocation?>();
        var locationCallCount = 0;

        when(() => mockDeviceLocation.getCurrentGeoLocation()).thenAnswer((_) {
          locationCallCount++;
          return locationCompleter.future;
        });

        // Start multiple concurrent calls for the same entry
        final futures = [
          geolocationService.addGeolocationAsync('test-id', _neverCalled),
          geolocationService.addGeolocationAsync('test-id', _neverCalled),
          geolocationService.addGeolocationAsync('test-id', _neverCalled),
        ];

        expect(locationCallCount, equals(1));

        // Complete and wait for all futures
        locationCompleter.complete(null);
        final results = await Future.wait(futures);

        // First call returns null (no geolocation from device),
        // subsequent calls return null immediately (already pending)
        expect(results.where((r) => r == null).length, equals(3));

        // Location should only be called once
        expect(locationCallCount, equals(1));
      });

      test('second call after first completes can proceed', () async {
        var callCount = 0;

        when(() => mockDeviceLocation.getCurrentGeoLocation()).thenAnswer((
          _,
        ) async {
          callCount++;
          return null;
        });

        // First call
        await geolocationService.addGeolocationAsync('test-id', _neverCalled);
        expect(callCount, equals(1));

        // Second call (should proceed since first completed)
        await geolocationService.addGeolocationAsync('test-id', _neverCalled);
        expect(callCount, equals(2));
      });

      glados.Glados(
        glados.any.geolocationPendingScenario,
        glados.ExploreConfig(numRuns: 120),
      ).test('coalesces generated duplicate pending entity ids', (
        scenario,
      ) async {
        clearInteractions(mockDeviceLocation);

        final locationCompleter = Completer<Geolocation?>();
        var locationCallCount = 0;
        when(() => mockDeviceLocation.getCurrentGeoLocation()).thenAnswer((_) {
          locationCallCount++;
          return locationCompleter.future;
        });

        final futures = [
          for (final id in scenario.ids)
            geolocationService.addGeolocationAsync(id, _neverCalled),
        ];

        expect(
          locationCallCount,
          scenario.uniqueIds.length,
          reason: '$scenario',
        );

        locationCompleter.complete(null);
        final results = await Future.wait(futures);

        expect(results, everyElement(isNull), reason: '$scenario');
        expect(
          locationCallCount,
          scenario.uniqueIds.length,
          reason: '$scenario',
        );
      }, tags: 'glados');
    });
  });
}
