import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/github/repository/github_token_storage.dart';

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

    test('becomes checked once GitHub accepts it here', () async {
      await storage.applyIfNewer(
        GitHubAccountRecord(token: 'ghp_new', updatedAt: stamp0),
      );

      await storage.markVerified('pingu');

      final held = await storage.read();
      expect(held!.verified, isTrue);
      expect(held.login, 'pingu');
      expect(held.updatedAt, stamp0);
    });

    test('marking nothing verified changes nothing', () async {
      await storage.markVerified('pingu');
      expect(await storage.read(), isNull);
    });
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

  test('nothing held reads as nothing', () async {
    expect(await storage.read(), isNull);
    expect(await storage.readToken(), isNull);
    expect(await storage.readLogin(), isNull);
  });
}
