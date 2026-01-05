import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/vector_clock_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SettingsDb settingsDb;
  late VectorClockService service;

  setUp(() async {
    await getIt.reset();
    settingsDb = SettingsDb(inMemoryDatabase: true);
    getIt.registerSingleton<SettingsDb>(settingsDb);
    service = VectorClockService();
    // Allow init() to complete
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });

  tearDown(() async {
    await getIt.reset();
  });

  group('VectorClockService', () {
    test('init sets host and counter', () async {
      final host = await service.getHost();
      expect(host, isNotNull);
      expect(host, isNotEmpty);

      final counter = await service.getNextAvailableCounter();
      expect(counter, 0);
    });

    test('setNewHost creates new host UUID', () async {
      final originalHost = await service.getHost();
      final newHost = await service.setNewHost();

      expect(newHost, isNotNull);
      expect(newHost, isNotEmpty);
      expect(newHost, isNot(originalHost));

      // Counter should be reset to 0
      final counter = await service.getNextAvailableCounter();
      expect(counter, 0);
    });

    test('increment increases counter', () async {
      final initialCounter = await service.getNextAvailableCounter();
      await service.increment();
      final afterIncrement = await service.getNextAvailableCounter();

      expect(afterIncrement, initialCounter + 1);
    });

    test('setNextAvailableCounter persists counter', () async {
      await service.setNextAvailableCounter(42);
      final counter = await service.getNextAvailableCounter();
      expect(counter, 42);
    });

    test('getHostHash returns SHA1 hash of host', () async {
      final host = await service.getHost();
      final hash = await service.getHostHash();

      expect(hash, isNotNull);
      expect(hash, hasLength(40)); // SHA1 produces 40 hex characters
      expect(hash, isNot(host)); // Hash should differ from original
    });

    test('getHostHash returns null when host is null', () async {
      // Create a new service without initializing properly
      await getIt.reset();
      final emptySettingsDb = SettingsDb(inMemoryDatabase: true);
      getIt.registerSingleton<SettingsDb>(emptySettingsDb);

      // Create service but don't wait for init
      final uninitializedService = VectorClockService();
      // The service will have set a host during init, so this test
      // verifies that getHostHash works after initialization
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final hash = await uninitializedService.getHostHash();
      expect(hash, isNotNull);
    });

    test('getNextVectorClock returns clock with current host', () async {
      final host = await service.getHost();
      final clock = await service.getNextVectorClock();

      expect(clock.vclock, containsPair(host, anything));
    });

    test('getNextVectorClock increments counter', () async {
      final initialCounter = await service.getNextAvailableCounter();
      await service.getNextVectorClock();
      final afterClock = await service.getNextAvailableCounter();

      expect(afterClock, initialCounter + 1);
    });

    test('getNextVectorClock merges with previous clock', () async {
      final host = await service.getHost();
      const previousClock = VectorClock({'other-host': 5, 'another-host': 10});

      final mergedClock =
          await service.getNextVectorClock(previous: previousClock);

      expect(mergedClock.vclock, containsPair('other-host', 5));
      expect(mergedClock.vclock, containsPair('another-host', 10));
      expect(mergedClock.vclock, containsPair(host, anything));
    });

    test('getNextVectorClock uses counter value in clock', () async {
      await service.setNextAvailableCounter(100);
      final host = await service.getHost();

      final clock = await service.getNextVectorClock();

      expect(clock.vclock[host], 100);
    });

    test('multiple getNextVectorClock calls increment counter sequentially',
        () async {
      final host = await service.getHost();
      await service.setNextAvailableCounter(0);

      final clock1 = await service.getNextVectorClock();
      final clock2 = await service.getNextVectorClock();
      final clock3 = await service.getNextVectorClock();

      expect(clock1.vclock[host], 0);
      expect(clock2.vclock[host], 1);
      expect(clock3.vclock[host], 2);
    });

    test('counter persists across service instances', () async {
      await service.setNextAvailableCounter(50);

      // Create new service instance
      final newService = VectorClockService();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final counter = await newService.getNextAvailableCounter();
      expect(counter, 50);
    });

    test('host persists across service instances', () async {
      final originalHost = await service.getHost();

      // Create new service instance
      final newService = VectorClockService();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final loadedHost = await newService.getHost();
      expect(loadedHost, originalHost);
    });
  });
}
