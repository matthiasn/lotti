import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/geolocation.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/logic/services/geolocation_service.dart';
import 'package:lotti/logic/services/metadata_service.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/location.dart';
import 'package:mocktail/mocktail.dart';

class MockJournalDb extends Mock implements JournalDb {}

class MockLoggingService extends Mock implements LoggingService {}

class MockMetadataService extends Mock implements MetadataService {}

class MockDeviceLocation extends Mock implements DeviceLocation {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GeolocationService', () {
    late GeolocationService geolocationService;
    late MockJournalDb mockJournalDb;
    late MockLoggingService mockLoggingService;
    late MockMetadataService mockMetadataService;
    late MockDeviceLocation mockDeviceLocation;

    final testGeolocation = Geolocation(
      createdAt: DateTime(2024, 1, 15, 10, 30),
      timezone: 'UTC',
      utcOffset: 0,
      latitude: 52.52,
      longitude: 13.405,
      geohashString: 'u33db2',
    );

    final testMetadata = Metadata(
      id: 'test-id',
      createdAt: DateTime(2024, 1, 15, 10),
      updatedAt: DateTime(2024, 1, 15, 10),
      dateFrom: DateTime(2024, 1, 15, 9),
      dateTo: DateTime(2024, 1, 15, 10),
      vectorClock: const VectorClock({'test-host': 1}),
    );

    final updatedMetadata = Metadata(
      id: 'test-id',
      createdAt: DateTime(2024, 1, 15, 10),
      updatedAt: DateTime(2024, 1, 15, 11),
      dateFrom: DateTime(2024, 1, 15, 9),
      dateTo: DateTime(2024, 1, 15, 10),
      vectorClock: const VectorClock({'test-host': 2}),
    );

    JournalEntry createTestEntry({
      String id = 'test-entry-id',
      Geolocation? geolocation,
      Metadata? meta,
    }) {
      return JournalEntry(
        meta: meta ?? testMetadata.copyWith(id: id),
        entryText: const EntryText(plainText: 'Test entry'),
        geolocation: geolocation,
      );
    }

    setUp(() {
      mockJournalDb = MockJournalDb();
      mockLoggingService = MockLoggingService();
      mockMetadataService = MockMetadataService();
      mockDeviceLocation = MockDeviceLocation();

      // Register fallback values for mocktail
      registerFallbackValue(testMetadata);
      registerFallbackValue(createTestEntry());

      geolocationService = GeolocationService(
        journalDb: mockJournalDb,
        loggingService: mockLoggingService,
        metadataService: mockMetadataService,
        deviceLocation: mockDeviceLocation,
      );
    });

    group('isPending', () {
      test('returns false when no operation is pending', () {
        expect(geolocationService.isPending('some-id'), isFalse);
      });

      test('returns true when operation is pending', () async {
        // Setup: device location returns a delayed response
        final completer = Completer<Geolocation?>();
        when(() => mockDeviceLocation.getCurrentGeoLocation())
            .thenAnswer((_) => completer.future);

        // Start the async operation (don't await)
        final future = geolocationService.addGeolocationAsync(
          'test-id',
          (_) async => true,
        );

        // Should be pending now
        expect(geolocationService.isPending('test-id'), isTrue);

        // Complete and cleanup
        completer.complete(null);
        await future;

        // Should no longer be pending
        expect(geolocationService.isPending('test-id'), isFalse);
      });
    });

    group('pendingCount', () {
      test('returns 0 initially', () {
        expect(geolocationService.pendingCount, equals(0));
      });

      test('increments during operation', () async {
        final completer = Completer<Geolocation?>();
        when(() => mockDeviceLocation.getCurrentGeoLocation())
            .thenAnswer((_) => completer.future);

        final future = geolocationService.addGeolocationAsync(
          'test-id',
          (_) async => true,
        );

        expect(geolocationService.pendingCount, equals(1));

        completer.complete(null);
        await future;

        expect(geolocationService.pendingCount, equals(0));
      });
    });

    group('addGeolocationAsync', () {
      test('returns null when another operation is already pending', () async {
        final completer = Completer<Geolocation?>();
        when(() => mockDeviceLocation.getCurrentGeoLocation())
            .thenAnswer((_) => completer.future);

        // Start first operation
        final future1 = geolocationService.addGeolocationAsync(
          'test-id',
          (_) async => true,
        );

        // Second call should return null immediately
        final result = await geolocationService.addGeolocationAsync(
          'test-id',
          (_) async => true,
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
          (_) async => true,
        );
        final future2 = geolocationService.addGeolocationAsync(
          'test-id-2',
          (_) async => true,
        );

        // Both should be pending
        expect(geolocationService.isPending('test-id-1'), isTrue);
        expect(geolocationService.isPending('test-id-2'), isTrue);
        expect(geolocationService.pendingCount, equals(2));

        // Cleanup
        completer1.complete(null);
        completer2.complete(null);
        await future1;
        await future2;
      });

      test('returns null when device location is null', () async {
        final serviceWithoutLocation = GeolocationService(
          journalDb: mockJournalDb,
          loggingService: mockLoggingService,
          metadataService: mockMetadataService,
          // deviceLocation is null
        );

        final result = await serviceWithoutLocation.addGeolocationAsync(
          'test-id',
          (_) async => true,
        );

        expect(result, isNull);
      });

      test('returns null when device location returns null', () async {
        when(() => mockDeviceLocation.getCurrentGeoLocation())
            .thenAnswer((_) async => null);

        final result = await geolocationService.addGeolocationAsync(
          'test-id',
          (_) async => true,
        );

        expect(result, isNull);
      });

      test('returns null when entry does not exist', () async {
        when(() => mockDeviceLocation.getCurrentGeoLocation())
            .thenAnswer((_) async => testGeolocation);
        when(() => mockJournalDb.journalEntityById('non-existent'))
            .thenAnswer((_) async => null);

        final result = await geolocationService.addGeolocationAsync(
          'non-existent',
          (_) async => true,
        );

        expect(result, isNull);
      });

      test('returns existing geolocation when entry already has one', () async {
        final entryWithGeolocation = createTestEntry(
          id: 'test-id',
          geolocation: testGeolocation,
        );

        when(() => mockDeviceLocation.getCurrentGeoLocation())
            .thenAnswer((_) async => testGeolocation);
        when(() => mockJournalDb.journalEntityById('test-id'))
            .thenAnswer((_) async => entryWithGeolocation);

        var persisterCalled = false;
        final result = await geolocationService.addGeolocationAsync(
          'test-id',
          (_) async {
            persisterCalled = true;
            return true;
          },
        );

        expect(result, equals(testGeolocation));
        expect(persisterCalled, isFalse);
      });

      test('adds geolocation to entry without one', () async {
        final entryWithoutGeolocation = createTestEntry(
          id: 'test-id',
          meta: testMetadata.copyWith(id: 'test-id'),
        );

        when(() => mockDeviceLocation.getCurrentGeoLocation())
            .thenAnswer((_) async => testGeolocation);
        when(() => mockJournalDb.journalEntityById('test-id'))
            .thenAnswer((_) async => entryWithoutGeolocation);
        when(() => mockMetadataService.updateMetadata(any()))
            .thenAnswer((_) async => updatedMetadata);

        JournalEntity? persistedEntity;
        final result = await geolocationService.addGeolocationAsync(
          'test-id',
          (entity) async {
            persistedEntity = entity;
            return true;
          },
        );

        expect(result, equals(testGeolocation));
        expect(persistedEntity, isNotNull);
        expect(persistedEntity!.geolocation, equals(testGeolocation));
        expect(persistedEntity!.meta.vectorClock,
            equals(updatedMetadata.vectorClock));

        verify(() => mockMetadataService.updateMetadata(any())).called(1);
      });

      test('clears pending set after successful completion', () async {
        final entry = createTestEntry(id: 'test-id');

        when(() => mockDeviceLocation.getCurrentGeoLocation())
            .thenAnswer((_) async => testGeolocation);
        when(() => mockJournalDb.journalEntityById('test-id'))
            .thenAnswer((_) async => entry);
        when(() => mockMetadataService.updateMetadata(any()))
            .thenAnswer((_) async => updatedMetadata);

        expect(geolocationService.isPending('test-id'), isFalse);

        await geolocationService.addGeolocationAsync(
          'test-id',
          (_) async => true,
        );

        expect(geolocationService.isPending('test-id'), isFalse);
      });

      test('clears pending set after error', () async {
        when(() => mockDeviceLocation.getCurrentGeoLocation())
            .thenThrow(Exception('Location error'));

        await geolocationService.addGeolocationAsync(
          'test-id',
          (_) async => true,
        );

        expect(geolocationService.isPending('test-id'), isFalse);
      });

      test('logs exception when getting location fails', () async {
        final exception = Exception('Location error');
        when(() => mockDeviceLocation.getCurrentGeoLocation())
            .thenThrow(exception);

        await geolocationService.addGeolocationAsync(
          'test-id',
          (_) async => true,
        );

        verify(
          () => mockLoggingService.captureException(
            exception,
            domain: 'geolocation_service',
            subDomain: 'getCurrentGeoLocation',
          ),
        ).called(1);
      });

      test('logs exception when persistence fails', () async {
        final entry = createTestEntry(id: 'test-id');
        final exception = Exception('Persistence error');

        when(() => mockDeviceLocation.getCurrentGeoLocation())
            .thenAnswer((_) async => testGeolocation);
        when(() => mockJournalDb.journalEntityById('test-id'))
            .thenAnswer((_) async => entry);
        when(() => mockMetadataService.updateMetadata(any()))
            .thenThrow(exception);

        await geolocationService.addGeolocationAsync(
          'test-id',
          (_) async => true,
        );

        verify(
          () => mockLoggingService.captureException(
            exception,
            domain: 'geolocation_service',
            subDomain: 'addGeolocation',
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
          ),
        ).called(1);
      });

      test('returns null on error but does not throw', () async {
        when(() => mockDeviceLocation.getCurrentGeoLocation())
            .thenThrow(Exception('Location error'));

        // Should not throw
        final result = await geolocationService.addGeolocationAsync(
          'test-id',
          (_) async => true,
        );

        expect(result, isNull);
      });
    });

    group('addGeolocation (fire-and-forget)', () {
      test('calls addGeolocationAsync without awaiting', () async {
        final completer = Completer<Geolocation?>();
        when(() => mockDeviceLocation.getCurrentGeoLocation())
            .thenAnswer((_) => completer.future);

        // Fire-and-forget call
        geolocationService.addGeolocation('test-id', (_) async => true);

        // Should be pending
        expect(geolocationService.isPending('test-id'), isTrue);

        // Cleanup
        completer.complete(null);

        // Wait for the background operation to complete
        await Future<void>.delayed(Duration.zero);
        expect(geolocationService.isPending('test-id'), isFalse);
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
          geolocationService.addGeolocationAsync('test-id', (_) async => true),
          geolocationService.addGeolocationAsync('test-id', (_) async => true),
          geolocationService.addGeolocationAsync('test-id', (_) async => true),
        ];

        // Only one should be pending
        expect(geolocationService.pendingCount, equals(1));

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

        when(() => mockDeviceLocation.getCurrentGeoLocation())
            .thenAnswer((_) async {
          callCount++;
          return null;
        });

        // First call
        await geolocationService.addGeolocationAsync(
          'test-id',
          (_) async => true,
        );
        expect(callCount, equals(1));

        // Second call (should proceed since first completed)
        await geolocationService.addGeolocationAsync(
          'test-id',
          (_) async => true,
        );
        expect(callCount, equals(2));
      });
    });
  });
}
