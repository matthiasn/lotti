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
    await service.initialized;
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

    test(
      'getHostHash returns a valid hash after service initialization',
      () async {
        // Create a new service without initializing properly
        await getIt.reset();
        final emptySettingsDb = SettingsDb(inMemoryDatabase: true);
        getIt.registerSingleton<SettingsDb>(emptySettingsDb);

        // Create service and wait for init
        final uninitializedService = VectorClockService();
        await uninitializedService.initialized;

        final hash = await uninitializedService.getHostHash();
        expect(hash, isNotNull);
      },
    );

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

      final mergedClock = await service.getNextVectorClock(
        previous: previousClock,
      );

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

    test(
      'multiple getNextVectorClock calls increment counter sequentially',
      () async {
        final host = await service.getHost();
        await service.setNextAvailableCounter(0);

        final clock1 = await service.getNextVectorClock();
        final clock2 = await service.getNextVectorClock();
        final clock3 = await service.getNextVectorClock();

        expect(clock1.vclock[host], 0);
        expect(clock2.vclock[host], 1);
        expect(clock3.vclock[host], 2);
      },
    );

    test('counter persists across service instances', () async {
      await service.setNextAvailableCounter(50);

      // Create new service instance
      final newService = VectorClockService();
      await newService.initialized;

      final counter = await newService.getNextAvailableCounter();
      expect(counter, 50);
    });

    test('host persists across service instances', () async {
      final originalHost = await service.getHost();

      // Create new service instance
      final newService = VectorClockService();
      await newService.initialized;

      final loadedHost = await newService.getHost();
      expect(loadedHost, originalHost);
    });

    test(
      'catches up when previous clock has higher counter for our host',
      () async {
        final host = await service.getHost();
        await service.setNextAvailableCounter(10);

        // Simulate a previous clock (e.g., from synced data) with higher counter
        final previousClock = VectorClock({host!: 100, 'other-host': 5});

        final newClock = await service.getNextVectorClock(
          previous: previousClock,
        );

        // Should use previousHostCounter + 1, not our local counter
        expect(newClock.vclock[host], 101);
        // Local counter should be updated to stay ahead
        expect(await service.getNextAvailableCounter(), 102);
      },
    );

    test(
      'does not catch up when previous clock has lower counter for our host',
      () async {
        final host = await service.getHost();
        await service.setNextAvailableCounter(100);

        // Previous clock has a lower counter for our host
        final previousClock = VectorClock({host!: 50, 'other-host': 5});

        final newClock = await service.getNextVectorClock(
          previous: previousClock,
        );

        // Should use our local counter, not the previous one
        expect(newClock.vclock[host], 100);
        // Local counter incremented normally
        expect(await service.getNextAvailableCounter(), 101);
      },
    );
  });

  group('VectorClockService reservations', () {
    test('commit persists the counter advance', () async {
      await service.setNextAvailableCounter(10);

      final reservation = await service.reserveNextVectorClock();
      final host = await service.getHost();
      expect(reservation.vc.vclock[host], 10);
      // In-memory bumped synchronously on reserve.
      expect(await service.getNextAvailableCounter(), 11);

      await reservation.commit();

      // Fresh service instance should observe the committed watermark.
      final reloaded = VectorClockService();
      await reloaded.initialized;
      expect(await reloaded.getNextAvailableCounter(), 11);
    });

    test(
      'release rewinds the in-memory watermark and does not persist — '
      'the next reservation reuses the slot so a rejected write never '
      'burns a VC counter',
      () async {
        await service.setNextAvailableCounter(20);

        final first = await service.reserveNextVectorClock();
        expect(first.vc.vclock[await service.getHost()], 20);
        expect(await service.getNextAvailableCounter(), 21);

        first.release();

        // In-memory rewinds because this was the latest reservation.
        expect(await service.getNextAvailableCounter(), 20);

        // SettingsDb still reports 20 — nothing was persisted.
        final reloaded = VectorClockService();
        await reloaded.initialized;
        expect(await reloaded.getNextAvailableCounter(), 20);

        // Next reservation reuses counter 20.
        final second = await service.reserveNextVectorClock();
        expect(second.vc.vclock[await service.getHost()], 20);
      },
    );

    test(
      'release does not rewind when a sibling reservation is outstanding — '
      'the counter is abandoned in-memory so siblings stay intact',
      () async {
        await service.setNextAvailableCounter(30);

        final first = await service.reserveNextVectorClock(); // 30
        final second = await service.reserveNextVectorClock(); // 31

        first.release();
        // In-memory stays at 32 (second is still outstanding at 31).
        expect(await service.getNextAvailableCounter(), 32);

        await second.commit();
        // Commit persists target = 32.
        final reloaded = VectorClockService();
        await reloaded.initialized;
        expect(await reloaded.getNextAvailableCounter(), 32);
      },
    );

    test('commit is idempotent', () async {
      await service.setNextAvailableCounter(40);
      final reservation = await service.reserveNextVectorClock();
      await reservation.commit();
      await reservation.commit(); // no-op
      expect(reservation.isPending, isFalse);
    });

    test('release after commit is a no-op', () async {
      await service.setNextAvailableCounter(50);
      final reservation = await service.reserveNextVectorClock();
      await reservation.commit();
      reservation.release(); // no-op

      final reloaded = VectorClockService();
      await reloaded.initialized;
      expect(await reloaded.getNextAvailableCounter(), 51);
    });
  });

  group('VectorClockService withVcScope', () {
    test('commits every nested reservation on success', () async {
      await service.setNextAvailableCounter(100);
      final host = await service.getHost();

      final result = await service.withVcScope<List<int>>(() async {
        final a = await service.getNextVectorClock();
        final b = await service.getNextVectorClock();
        return [a.vclock[host]!, b.vclock[host]!];
      });

      expect(result, [100, 101]);
      final reloaded = VectorClockService();
      await reloaded.initialized;
      expect(await reloaded.getNextAvailableCounter(), 102);
    });

    test(
      'releases every nested reservation on throw — covers the '
      'applied=false-style burn by rewinding the counter so the next '
      'write reuses the same slot',
      () async {
        await service.setNextAvailableCounter(200);

        expect(
          () => service.withVcScope<void>(() async {
            await service.getNextVectorClock();
            await service.getNextVectorClock();
            throw StateError('write rejected');
          }),
          throwsA(isA<StateError>()),
        );

        // Let microtasks drain.
        await Future<void>.delayed(Duration.zero);

        // All reservations released — in-memory watermark rewound to 200.
        expect(await service.getNextAvailableCounter(), 200);

        // Nothing persisted past the pre-scope watermark.
        final reloaded = VectorClockService();
        await reloaded.initialized;
        expect(await reloaded.getNextAvailableCounter(), 200);
      },
    );

    test(
      'releases reservations when commitWhen returns false — this is the '
      'applied=false path from persistence_logic.updateDbEntity where a '
      'VC comparison rejects an update as stale',
      () async {
        await service.setNextAvailableCounter(300);

        final applied = await service.withVcScope<bool>(
          () async {
            await service.getNextVectorClock();
            await service.getNextVectorClock();
            return false; // simulates applied=false
          },
          commitWhen: (applied) => applied,
        );

        expect(applied, isFalse);
        expect(await service.getNextAvailableCounter(), 300);

        final reloaded = VectorClockService();
        await reloaded.initialized;
        expect(await reloaded.getNextAvailableCounter(), 300);
      },
    );

    test('nested scopes delegate to the outermost scope', () async {
      await service.setNextAvailableCounter(400);
      final host = await service.getHost();

      // Outer scope commits on success; inner scope with commitWhen=false
      // would normally release, but because the outer scope controls
      // finalization here, both reservations commit together.
      final result = await service.withVcScope<int>(() async {
        final outer = await service.getNextVectorClock();
        final innerCounter = await service.withVcScope<int>(
          () async {
            final inner = await service.getNextVectorClock();
            return inner.vclock[host]!;
          },
          commitWhen: (_) => false,
        );
        return outer.vclock[host]! + innerCounter;
      });

      expect(result, 400 + 401);
      final reloaded = VectorClockService();
      await reloaded.initialized;
      expect(await reloaded.getNextAvailableCounter(), 402);
    });

    test(
      'getNextVectorClock outside a scope auto-commits — preserves the '
      'legacy single-shot behavior for low-stakes callers',
      () async {
        await service.setNextAvailableCounter(500);
        await service.getNextVectorClock();

        final reloaded = VectorClockService();
        await reloaded.initialized;
        expect(await reloaded.getNextAvailableCounter(), 501);
      },
    );

    test(
      'commit-on-write invariant: if the body observes a successful DB '
      'write and returns normally — even though a sync enqueue after it '
      'was supposed to throw but was swallowed — the counter commits. '
      'Rewinding here would let the next reservation re-hand the same '
      'counter to a different entity, producing a cross-entity collision '
      'because the first entity already persists the counter on disk.',
      () async {
        await service.setNextAvailableCounter(600);

        final applied = await service.withVcScope<bool>(
          () async {
            await service.getNextVectorClock(); // reserve 600
            const dbWriteSucceeded = true;
            try {
              throw StateError('transient outbox failure');
            } catch (_) {
              // Swallow — simulates the commit-on-write pattern in
              // persistence_logic where the DB write already claimed the
              // counter on disk.
            }
            return dbWriteSucceeded;
          },
          commitWhen: (applied) => applied,
        );

        expect(applied, isTrue);

        final reloaded = VectorClockService();
        await reloaded.initialized;
        expect(
          await reloaded.getNextAvailableCounter(),
          601,
          reason:
              'write landed — counter must persist despite the swallowed '
              'enqueue failure',
        );
      },
    );
  });
}
