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
    test(
      'reserveNextVectorClock persists the advance eagerly — a crash '
      'between reserve and any subsequent entity write can only burn the '
      'counter, never re-hand it (collision-safe across DB files)',
      () async {
        await service.setNextAvailableCounter(10);

        final reservation = await service.reserveNextVectorClock();
        final host = await service.getHost();
        expect(reservation.vc.vclock[host], 10);

        // Counter already persisted BEFORE the caller can run any write.
        final reloaded = VectorClockService();
        await reloaded.initialized;
        expect(await reloaded.getNextAvailableCounter(), 11);

        // commit is a no-op under persist-on-reserve semantics.
        await reservation.commit();
        expect(reservation.isPending, isFalse);
      },
    );

    test(
      'release logs the burn and notifies the burn handler — the counter '
      'is already on disk (cannot rewind) so proactive broadcast is the '
      'only way for peers to skip gap detection',
      () async {
        await service.setNextAvailableCounter(20);
        final burnt = <int>[];
        service.setBurnHandler((_, counter) => burnt.add(counter));

        final reservation = await service.reserveNextVectorClock();
        reservation.release();

        expect(burnt, [20]);

        // In-memory watermark did NOT rewind.
        expect(await service.getNextAvailableCounter(), 21);

        // Persisted watermark held at 21 through the release.
        final reloaded = VectorClockService();
        await reloaded.initialized;
        expect(await reloaded.getNextAvailableCounter(), 21);

        service.setBurnHandler(null);
      },
    );

    test('commit is idempotent and safe to call before release', () async {
      await service.setNextAvailableCounter(40);
      final reservation = await service.reserveNextVectorClock();
      await reservation.commit();
      await reservation.commit(); // no-op
      expect(reservation.isPending, isFalse);
    });

    test(
      'release after commit is a no-op — a late release path does not '
      'double-broadcast a burn for a counter that actually carried a write',
      () async {
        await service.setNextAvailableCounter(50);
        final burnt = <int>[];
        service.setBurnHandler((_, counter) => burnt.add(counter));

        final reservation = await service.reserveNextVectorClock();
        await reservation.commit();
        reservation.release(); // no-op — already finalized by commit

        expect(burnt, isEmpty);
        final reloaded = VectorClockService();
        await reloaded.initialized;
        expect(await reloaded.getNextAvailableCounter(), 51);

        service.setBurnHandler(null);
      },
    );

    test(
      'concurrent reservations serialize — no two concurrent callers ever '
      'observe the same counter between reserve and persist',
      () async {
        await service.setNextAvailableCounter(1000);

        final futures = List.generate(
          10,
          (_) => service.reserveNextVectorClock(),
        );
        final reservations = await Future.wait(futures);
        final host = await service.getHost();

        final counters = reservations.map((r) => r.vc.vclock[host]!).toList()
          ..sort();
        expect(counters, List.generate(10, (i) => 1000 + i));
        expect(counters.toSet().length, 10); // no duplicates

        for (final r in reservations) {
          await r.commit();
        }
      },
    );
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
      'throw inside scope broadcasts a burn for every reserved counter '
      '— peers can mark them unresolvable on arrival instead of hitting '
      'the reactive backfill-request round-trip',
      () async {
        await service.setNextAvailableCounter(200);
        final burnt = <int>[];
        service.setBurnHandler((_, counter) => burnt.add(counter));

        expect(
          () => service.withVcScope<void>(() async {
            await service.getNextVectorClock();
            await service.getNextVectorClock();
            throw StateError('write rejected');
          }),
          throwsA(isA<StateError>()),
        );
        await Future<void>.delayed(Duration.zero);

        // Both counters burnt — broadcast in reverse (latest first) so
        // the handler's ordering matches the release order.
        expect(burnt, [201, 200]);

        // Persisted watermark stays at 202 (counters already on disk).
        final reloaded = VectorClockService();
        await reloaded.initialized;
        expect(await reloaded.getNextAvailableCounter(), 202);

        service.setBurnHandler(null);
      },
    );

    test(
      'commitWhen=false broadcasts a burn for every reserved counter — '
      'this is the applied=false path from persistence_logic.updateDbEntity '
      'when a VC comparison rejects an update as stale',
      () async {
        await service.setNextAvailableCounter(300);
        final burnt = <int>[];
        service.setBurnHandler((_, counter) => burnt.add(counter));

        final applied = await service.withVcScope<bool>(
          () async {
            await service.getNextVectorClock();
            await service.getNextVectorClock();
            return false;
          },
          commitWhen: (applied) => applied,
        );

        expect(applied, isFalse);
        expect(burnt, [301, 300]);

        // Persisted watermark stays at 302 — nothing we can rewind.
        final reloaded = VectorClockService();
        await reloaded.initialized;
        expect(await reloaded.getNextAvailableCounter(), 302);

        service.setBurnHandler(null);
      },
    );

    test('nested scopes delegate to the outermost scope', () async {
      await service.setNextAvailableCounter(400);
      final host = await service.getHost();

      // Outer scope commits on success; inner scope's own commitWhen=false
      // does not fire because the outermost scope owns finalization.
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
      'getNextVectorClock outside a scope auto-commits — legacy callers '
      'that do not opt into a scope still get the eager persist semantics',
      () async {
        await service.setNextAvailableCounter(500);
        await service.getNextVectorClock();

        final reloaded = VectorClockService();
        await reloaded.initialized;
        expect(await reloaded.getNextAvailableCounter(), 501);
      },
    );

    test(
      'commit-on-write invariant: a scoped action that swallows a '
      'post-DB-write exception still commits — the counter is already '
      'on disk and the write carried it, so no burn broadcast',
      () async {
        await service.setNextAvailableCounter(600);
        final burnt = <int>[];
        service.setBurnHandler((_, counter) => burnt.add(counter));

        final applied = await service.withVcScope<bool>(
          () async {
            await service.getNextVectorClock(); // reserve 600
            const dbWriteSucceeded = true;
            try {
              throw StateError('transient outbox failure');
            } catch (_) {
              // Swallow — simulates the pattern in persistence_logic where
              // the DB write already committed the counter to disk.
            }
            return dbWriteSucceeded;
          },
          commitWhen: (applied) => applied,
        );

        expect(applied, isTrue);
        expect(burnt, isEmpty);

        final reloaded = VectorClockService();
        await reloaded.initialized;
        expect(await reloaded.getNextAvailableCounter(), 601);

        service.setBurnHandler(null);
      },
    );

    test(
      'burn handler receives the host captured at reserve time, not the '
      "service's current host at release time — setNewHost between "
      'reserve and release must not re-attribute the burn to the new host',
      () async {
        await service.setNextAvailableCounter(800);
        final burnt = <({String hostId, int counter})>[];
        service.setBurnHandler((hostId, counter) {
          burnt.add((hostId: hostId, counter: counter));
        });

        final originalHost = await service.getHost();
        final reservation = await service.reserveNextVectorClock();

        // Swap to a brand-new host identity BEFORE releasing — simulates
        // a user re-linking to a different Matrix account.
        final newHost = await service.setNewHost();
        expect(newHost, isNot(originalHost));

        reservation.release();

        expect(burnt, hasLength(1));
        expect(burnt.single.hostId, originalHost);
        expect(burnt.single.counter, 800);

        service.setBurnHandler(null);
      },
    );

    test(
      'burn handler exception does not propagate into the scope finalizer '
      '— the counter is already burnt; a handler throw must not cascade',
      () async {
        await service.setNextAvailableCounter(700);
        service.setBurnHandler((_, _) {
          throw StateError('handler boom');
        });

        // Should not rethrow the handler's StateError.
        final applied = await service.withVcScope<bool>(
          () async {
            await service.getNextVectorClock();
            return false;
          },
          commitWhen: (applied) => applied,
        );
        expect(applied, isFalse);

        service.setBurnHandler(null);
      },
    );
  });
}
