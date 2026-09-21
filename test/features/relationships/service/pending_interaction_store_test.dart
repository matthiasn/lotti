import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/relationships/service/pending_interaction_store.dart';
import 'package:lotti/get_it.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SettingsDb settingsDb;
  late PendingInteractionStore store;

  /// Fixed so every assertion about the TTL is arithmetic rather than a race
  /// with the wall clock.
  final now = DateTime.utc(2026, 8, 17, 12);

  setUp(() {
    settingsDb = SettingsDb(inMemoryDatabase: true);
    store = PendingInteractionStore(settingsDb: settingsDb);
  });

  tearDown(() => settingsDb.close());

  Future<void> writeRaw(String value) =>
      settingsDb.saveSettingsItem(pendingInteractionKey, value);

  group('remember', () {
    test(
      'stores the person, the interaction type and the departure time',
      () async {
        await withClock(Clock.fixed(now), () async {
          await store.remember(
            relationshipId: 'anna',
            interactionType: CheckInInteractionType.call,
          );
        });

        final pending = await withClock(Clock.fixed(now), store.read);

        expect(pending!.relationshipId, 'anna');
        expect(pending.interactionType, CheckInInteractionType.call);
        expect(pending.startedAt, now);
      },
    );

    test('keeps only the most recent departure', () async {
      await withClock(Clock.fixed(now), () async {
        await store.remember(
          relationshipId: 'anna',
          interactionType: CheckInInteractionType.call,
        );
        await store.remember(
          relationshipId: 'bo',
          interactionType: CheckInInteractionType.message,
        );
      });

      final pending = await withClock(Clock.fixed(now), store.read);

      expect(
        pending!.relationshipId,
        'bo',
        reason:
            'the most recent departure is the one the user just came '
            'back from; a queue of prompts would be worse than missing one',
      );
      expect(pending.interactionType, CheckInInteractionType.message);
    });

    test('round-trips every interaction type', () async {
      for (final type in CheckInInteractionType.values) {
        await withClock(Clock.fixed(now), () async {
          await store.remember(relationshipId: 'anna', interactionType: type);
        });

        final pending = await withClock(Clock.fixed(now), store.read);

        expect(pending!.interactionType, type, reason: 'lost $type');
      }
    });
  });

  group('read — absence', () {
    test('returns null when nothing was ever remembered', () async {
      expect(await store.read(), isNull);
    });

    test('returns null after the marker is cleared', () async {
      await withClock(Clock.fixed(now), () async {
        await store.remember(
          relationshipId: 'anna',
          interactionType: CheckInInteractionType.call,
        );
      });
      await store.clear();

      expect(await withClock(Clock.fixed(now), store.read), isNull);
    });

    test('treats an empty stored value as absence', () async {
      await writeRaw('');

      expect(await store.read(), isNull);
    });
  });

  group('read — expiry', () {
    test('offers a marker from just inside the window', () async {
      await withClock(Clock.fixed(now), () async {
        await store.remember(
          relationshipId: 'anna',
          interactionType: CheckInInteractionType.call,
        );
      });

      final justInside = now.add(
        pendingInteractionTtl - const Duration(minutes: 1),
      );
      final pending = await withClock(Clock.fixed(justInside), store.read);

      expect(pending, isNotNull);
    });

    test('drops a marker exactly at the window edge', () async {
      await withClock(Clock.fixed(now), () async {
        await store.remember(
          relationshipId: 'anna',
          interactionType: CheckInInteractionType.call,
        );
      });

      final atEdge = now.add(pendingInteractionTtl);

      expect(await withClock(Clock.fixed(atEdge), store.read), isNull);
    });

    test('drops a call from yesterday rather than greeting the user with a '
        'stale prompt', () async {
      await withClock(Clock.fixed(now), () async {
        await store.remember(
          relationshipId: 'anna',
          interactionType: CheckInInteractionType.call,
        );
      });

      final tomorrow = now.add(const Duration(days: 1));

      expect(await withClock(Clock.fixed(tomorrow), store.read), isNull);
    });

    test(
      'clears an expired marker so it cannot sit in settings forever',
      () async {
        await withClock(Clock.fixed(now), () async {
          await store.remember(
            relationshipId: 'anna',
            interactionType: CheckInInteractionType.call,
          );
        });

        final tomorrow = now.add(const Duration(days: 1));
        await withClock(Clock.fixed(tomorrow), store.read);

        expect(await settingsDb.itemByKey(pendingInteractionKey), isNull);
      },
    );
  });

  group('read — unreadable values', () {
    test(
      'treats malformed JSON as absence rather than failing the resume',
      () async {
        await writeRaw('not json at all');

        expect(await store.read(), isNull);
      },
    );

    test('treats a JSON value that is not an object as absence', () async {
      await writeRaw('[1, 2, 3]');

      expect(await store.read(), isNull);
    });

    test('rejects a marker with no relationship', () async {
      await writeRaw(
        jsonEncode({
          'interactionType': 'call',
          'startedAt': now.toIso8601String(),
        }),
      );

      expect(await withClock(Clock.fixed(now), store.read), isNull);
    });

    test('rejects a marker whose relationship id is empty', () async {
      await writeRaw(
        jsonEncode({
          'relationshipId': '',
          'interactionType': 'call',
          'startedAt': now.toIso8601String(),
        }),
      );

      expect(await withClock(Clock.fixed(now), store.read), isNull);
    });

    test('rejects a marker with an unparseable timestamp', () async {
      await writeRaw(
        jsonEncode({
          'relationshipId': 'anna',
          'interactionType': 'call',
          'startedAt': 'whenever',
        }),
      );

      expect(await withClock(Clock.fixed(now), store.read), isNull);
    });

    test('rejects an interaction type this build does not know', () async {
      await writeRaw(
        jsonEncode({
          'relationshipId': 'anna',
          'interactionType': 'telepathy',
          'startedAt': now.toIso8601String(),
        }),
      );

      expect(await withClock(Clock.fixed(now), store.read), isNull);
    });

    test(
      'clears an unreadable marker so it cannot be re-parsed forever',
      () async {
        await writeRaw('not json at all');
        await store.read();

        expect(await settingsDb.itemByKey(pendingInteractionKey), isNull);
      },
    );
  });

  group('clear', () {
    test(
      'leaves no trace, so declining and never calling look the same',
      () async {
        await withClock(Clock.fixed(now), () async {
          await store.remember(
            relationshipId: 'anna',
            interactionType: CheckInInteractionType.call,
          );
        });

        await store.clear();

        expect(await settingsDb.itemByKey(pendingInteractionKey), isNull);
      },
    );

    test('is safe to call when there is nothing to clear', () async {
      await expectLater(store.clear(), completes);
    });
  });

  group('production wiring', () {
    setUp(() {
      if (getIt.isRegistered<SettingsDb>()) getIt.unregister<SettingsDb>();
      getIt.registerSingleton<SettingsDb>(settingsDb);
    });

    tearDown(() => getIt.unregister<SettingsDb>());

    test('resolves its database from getIt when none is injected', () async {
      await withClock(Clock.fixed(now), () async {
        await PendingInteractionStore().remember(
          relationshipId: 'anna',
          interactionType: CheckInInteractionType.call,
        );
      });

      expect(
        await settingsDb.itemByKey(pendingInteractionKey),
        isNotNull,
        reason:
            'the default constructor must reach the same settings db the '
            'rest of the app writes to',
      );
    });

    group('claiming the marker through another door', () {
      ({ProviderContainer container, PendingInteractionStore store}) build() {
        final store = PendingInteractionStore(settingsDb: settingsDb);
        final container = ProviderContainer(
          overrides: [pendingInteractionStoreProvider.overrideWithValue(store)],
        );
        addTearDown(container.dispose);
        return (container: container, store: store);
      }

      test('hands over the marker for the person asked about, clears it, '
          'and counts the claim so the offer can stop asking', () async {
        final (:container, :store) = build();
        await store.remember(
          relationshipId: 'anna',
          interactionType: CheckInInteractionType.call,
        );

        final claimed = await container
            .read(pendingInteractionClaimsProvider.notifier)
            .claimFor('anna');

        expect(claimed?.relationshipId, 'anna');
        expect(claimed?.interactionType, CheckInInteractionType.call);
        expect(await store.read(), isNull);
        expect(container.read(pendingInteractionClaimsProvider), 1);
      });

      test('leaves a marker about someone else alone — a check-in with Bo '
          'must not swallow the call just placed to Anna', () async {
        final (:container, :store) = build();
        await store.remember(
          relationshipId: 'anna',
          interactionType: CheckInInteractionType.call,
        );

        final claimed = await container
            .read(pendingInteractionClaimsProvider.notifier)
            .claimFor('bo');

        expect(claimed, isNull);
        expect((await store.read())?.relationshipId, 'anna');
        expect(container.read(pendingInteractionClaimsProvider), 0);
      });

      test('claims are exclusive: two landing together get one marker '
          'between them, so one call opens one composer', () async {
        final (:container, :store) = build();
        await store.remember(
          relationshipId: 'anna',
          interactionType: CheckInInteractionType.call,
        );
        final claims = container.read(
          pendingInteractionClaimsProvider.notifier,
        );

        final results = await Future.wait([
          claims.claimFor('anna'),
          claims.claimFor('anna'),
        ]);

        expect(results.nonNulls, hasLength(1));
        expect(container.read(pendingInteractionClaimsProvider), 1);
      });

      test('a released claim comes back exactly as it was — its original '
          'start kept, so it keeps its age and its expiry — and is counted, '
          'so the offer reads it again', () async {
        final (:container, :store) = build();
        await withClock(Clock.fixed(DateTime(2026, 8, 17, 11, 30)), () async {
          await store.remember(
            relationshipId: 'anna',
            interactionType: CheckInInteractionType.message,
          );
        });
        final claims = container.read(
          pendingInteractionClaimsProvider.notifier,
        );

        await withClock(Clock.fixed(DateTime(2026, 8, 17, 11, 45)), () async {
          final claimed = await claims.claimFor('anna');
          expect(await store.read(), isNull);
          await claims.release(claimed!);

          expect(await store.read(), (
            relationshipId: 'anna',
            interactionType: CheckInInteractionType.message,
            startedAt: DateTime(2026, 8, 17, 11, 30),
          ));
        });
        expect(container.read(pendingInteractionClaimsProvider), 2);
      });

      test('claims nothing when there is no marker', () async {
        final (:container, store: _) = build();

        expect(
          await container
              .read(pendingInteractionClaimsProvider.notifier)
              .claimFor('anna'),
          isNull,
        );
        expect(container.read(pendingInteractionClaimsProvider), 0);
      });
    });

    test('is provided ready to use', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final provided = container.read(pendingInteractionStoreProvider);

      expect(provided, isA<PendingInteractionStore>());
      await expectLater(provided.read(), completes);
    });
  });
}
