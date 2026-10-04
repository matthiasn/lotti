import 'dart:async';
import 'dart:convert';

import 'dart:io';
import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/github/repository/github_token_storage.dart';

import 'package:lotti/features/profiles/model/profile.dart';
import 'package:lotti/features/profiles/model/profile_context.dart';
import 'package:mocktail/mocktail.dart';
import '../../../mocks/mocks.dart';
import '../in_memory_keychain.dart';

void main() {
  late Map<String, String> values;
  late GitHubTokenStorage storage;
  final t0 = DateTime.utc(2026, 3, 15, 12);
  final stamp0 = t0.millisecondsSinceEpoch;

  setUp(() {
    values = {};
    storage = GitHubTokenStorage(inMemoryKeychain(values), namespace: 'real');
  });

  Map<String, dynamic> stored([String namespace = 'real']) =>
      jsonDecode(values['github_account:$namespace']!) as Map<String, dynamic>;

  group('a token entered here', () {
    test(
      'is one keystore value with its login and stamp, checked here, and '
      'namespaced by profile',
      () async {
        final record = await withClock(
          Clock.fixed(t0),
          () => storage.save(token: 'ghp_secret', login: 'pingu'),
        );

        expect(values.keys, ['github_account:real']);
        expect(stored(), {
          'token': 'ghp_secret',
          'login': 'pingu',
          'updatedAt': stamp0,
          'verified': true,
          'owed': true,
        });
        expect(record.updatedAt, stamp0);
        expect(await storage.readToken(), 'ghp_secret');
        expect(await storage.readLogin(), 'pingu');
      },
    );

    test('another profile never reads it', () async {
      await storage.save(token: 'ghp_secret', login: 'pingu');

      final demo = GitHubTokenStorage(inMemoryKeychain(values), namespace: 'x');
      expect(await demo.read(), isNull);
      expect(await demo.readToken(), isNull);
    });

    test(
      'a disconnection is a newer version with no token, so it syncs too',
      () async {
        await withClock(
          Clock.fixed(t0),
          () => storage.save(token: 'ghp_secret', login: 'pingu'),
        );

        final record = await withClock(
          Clock.fixed(t0.add(const Duration(minutes: 1))),
          storage.clear,
        );

        expect(record.connected, isFalse);
        expect(record.updatedAt, stamp0 + 60000);
        expect(await storage.readToken(), isNull);
        expect(await storage.readLogin(), isNull);
      },
    );

    test(
      'is stamped past the held version even when this clock is behind it '
      '(BumpStamp)',
      () async {
        await storage.applyIfNewer(
          GitHubAccountRecord(token: 'ghp_other', updatedAt: stamp0 + 5000),
        );

        final record = await withClock(Clock.fixed(t0), storage.clear);

        expect(record.updatedAt, stamp0 + 5001);
      },
    );
  });

  group('a token received from another device', () {
    test(
      'replaces an older one, and is not checked here yet',
      () async {
        await withClock(
          Clock.fixed(t0),
          () => storage.save(token: 'ghp_old', login: 'pingu'),
        );

        final applied = await storage.applyIfNewer(
          GitHubAccountRecord(
            token: 'ghp_new',
            login: 'pingu',
            updatedAt: stamp0 + 1,
            verified: true,
          ),
        );

        expect(applied, isTrue);
        final held = await storage.read();
        expect(held!.token, 'ghp_new');
        expect(held.verified, isFalse);
        // What was made here is superseded: nothing is owed any more.
        expect(held.owed, isFalse);
      },
    );

    test(
      'applySynced applies the account sync delivered as applyIfNewer',
      () async {
        await withClock(
          Clock.fixed(t0),
          () => storage.save(token: 'ghp_old', login: 'pingu'),
        );

        expect(
          await storage.applySynced(
            token: 'ghp_synced',
            login: 'pingu',
            updatedAt: stamp0 + 1,
          ),
          isTrue,
        );
        expect((await storage.read())!.token, 'ghp_synced');
        // An older delivery changes nothing.
        expect(
          await storage.applySynced(token: 'ghp_stale', updatedAt: stamp0),
          isFalse,
        );
        expect((await storage.read())!.token, 'ghp_synced');
      },
    );

    test(
      'never overwrites a newer change made here while it was being '
      'compared (AtomicApply)',
      () async {
        // A keychain whose next read answers with what it held when asked,
        // but only once the gate opens: an apply that read the old record
        // is still deciding when the user disconnects.
        final values = <String, String>{};
        final gate = Completer<void>();
        var holdNextRead = false;
        final keystore = MockSecureStorage();
        when(() => keystore.read(key: any(named: 'key'))).thenAnswer((
          invocation,
        ) async {
          final value = values[invocation.namedArguments[#key] as String];
          if (holdNextRead) {
            holdNextRead = false;
            await gate.future;
          }
          return value;
        });
        when(
          () => keystore.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          ),
        ).thenAnswer((invocation) async {
          values[invocation.namedArguments[#key] as String] =
              invocation.namedArguments[#value] as String;
        });
        final device = GitHubTokenStorage(keystore, namespace: 'real');
        await device.applyIfNewer(
          GitHubAccountRecord(token: 'ghp_held', updatedAt: stamp0),
        );

        holdNextRead = true;
        final applying = device.applyIfNewer(
          GitHubAccountRecord(token: 'ghp_late', updatedAt: stamp0 + 1),
        );
        await pumpEventQueue();
        final clearing = withClock(
          Clock.fixed(t0.add(const Duration(minutes: 1))),
          device.clear,
        );
        await pumpEventQueue();
        gate.complete();
        await Future.wait([applying, clearing]);

        final held = await device.read();
        expect(held!.connected, isFalse);
        expect(held.updatedAt, stamp0 + 60000);
      },
    );

    test('an older one is ignored', () async {
      await withClock(
        Clock.fixed(t0),
        () => storage.save(token: 'ghp_held', login: 'pingu'),
      );

      expect(
        await storage.applyIfNewer(
          GitHubAccountRecord(token: 'ghp_late', updatedAt: stamp0 - 1),
        ),
        isFalse,
      );
      expect(await storage.readToken(), 'ghp_held');
    });

    test(
      'an equal stamp is decided by content, the same way on every device '
      '(DeterministicTies)',
      () async {
        Future<String?> outcome(List<String> order) async {
          final keychain = <String, String>{};
          final device = GitHubTokenStorage(
            inMemoryKeychain(keychain),
            namespace: 'real',
          );
          for (final token in order) {
            await device.applyIfNewer(
              GitHubAccountRecord(token: token, updatedAt: stamp0),
            );
          }
          return device.readToken();
        }

        expect(await outcome(['ghp_a', 'ghp_b']), 'ghp_b');
        expect(await outcome(['ghp_b', 'ghp_a']), 'ghp_b');
      },
    );

    test('becomes checked once GitHub accepts that version here', () async {
      await storage.applyIfNewer(
        GitHubAccountRecord(token: 'ghp_new', updatedAt: stamp0),
      );

      final marked = await storage.markVerified(
        token: 'ghp_new',
        updatedAt: stamp0,
        login: 'pingu',
      );

      expect(marked, isTrue);
      final held = await storage.read();
      expect(held!.verified, isTrue);
      expect(held.login, 'pingu');
      expect(held.updatedAt, stamp0);
    });

    test(
      'a check of another version marks nothing: a newer token that arrived '
      'during the check is checked on its own (VerifyMatchesVersion)',
      () async {
        await storage.applyIfNewer(
          GitHubAccountRecord(token: 'ghp_b', updatedAt: stamp0 + 1),
        );

        final marked = await storage.markVerified(
          token: 'ghp_a',
          updatedAt: stamp0,
          login: 'someone-else',
        );

        expect(marked, isFalse);
        final held = await storage.read();
        expect(held!.verified, isFalse);
        expect(held.login, isNull);
        expect(
          await GitHubTokenStorage(
            inMemoryKeychain({}),
            namespace: 'real',
          ).markVerified(token: 'ghp_a', updatedAt: 1, login: 'pingu'),
          isFalse,
        );
      },
    );
  });

  test(
    'a token saved before the record existed is moved into it once, '
    'checked and stamped zero, so any synced version replaces it',
    () async {
      values
        ..['github_token:real'] = 'ghp_legacy'
        ..['github_login:real'] = 'pingu';

      final record = await storage.read();

      expect(record!.token, 'ghp_legacy');
      expect(record.login, 'pingu');
      expect(record.verified, isTrue);
      expect(record.updatedAt, 0);
      expect(values.keys, ['github_account:real']);
      expect(
        await storage.applyIfNewer(
          const GitHubAccountRecord(token: 'ghp_synced', updatedAt: 1),
        ),
        isTrue,
      );
    },
  );

  group('owed to the other devices', () {
    test('a change made here is owed until it is sent', () async {
      final saved = await storage.save(token: 'ghp_secret', login: 'pingu');
      expect(saved.owed, isTrue);

      await storage.markSent(saved);
      expect((await storage.read())!.owed, isFalse);

      final cleared = await storage.clear();
      expect(cleared.owed, isTrue);
      expect((await storage.read())!.owed, isTrue);
    });

    test(
      'sending an older version leaves a change made since still owed',
      () async {
        final first = await withClock(
          Clock.fixed(t0),
          () => storage.save(token: 'ghp_first', login: 'pingu'),
        );
        await withClock(
          Clock.fixed(t0.add(const Duration(seconds: 1))),
          storage.clear,
        );

        await storage.markSent(first);

        expect((await storage.read())!.owed, isTrue);
      },
    );

    test('a check keeps what is owed', () async {
      final saved = await storage.save(token: 'ghp_secret', login: 'pingu');
      await storage.markVerified(
        token: 'ghp_secret',
        updatedAt: saved.updatedAt,
        login: 'pingu',
      );
      expect((await storage.read())!.owed, isTrue);
    });
  });

  test(
    "a profile's storage is namespaced by the profile's id, so a guest world "
    'keeps its own',
    () async {
      final keychain = <String, String>{};
      final guest = gitHubTokenStorageForProfile(
        inMemoryKeychain(keychain),
        ProfileContext.forProfile(
          profile: Profile(
            id: 'g1',
            type: ProfileType.guest,
            name: 'Penguin world',
            dirName: 'guest_profiles/g1',
            createdAt: DateTime(2026),
          ),
          root: Directory('/data/lotti'),
        ),
      );

      await guest.save(token: 'ghp_guest', login: 'pingu');

      expect(keychain.keys, ['github_account:g1']);
    },
  );

  test('hasToken says whether a token is held', () async {
    expect(await storage.hasToken(), isFalse);

    await storage.save(token: 'ghp_secret', login: 'pingu');
    expect(await storage.hasToken(), isTrue);

    await storage.clear();
    expect(await storage.hasToken(), isFalse);
  });

  test('nothing held reads as nothing', () async {
    expect(await storage.read(), isNull);
    expect(await storage.readToken(), isNull);
    expect(await storage.readLogin(), isNull);
  });
}
