import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/github/repository/github_account_sync.dart';
import 'package:lotti/features/github/repository/github_token_storage.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/model/sync_secret.dart';

import '../in_memory_keychain.dart';

void main() {
  late GitHubTokenStorage storage;
  late List<SyncMessage> sent;
  late bool outboxRefuses;
  late int rescans;

  setUp(() {
    storage = GitHubTokenStorage(inMemoryKeychain({}), namespace: 'real');
    sent = [];
    outboxRefuses = false;
    rescans = 0;
  });

  GitHubAccountSync sync({bool canRescan = true}) => GitHubAccountSync(
    storage: storage,
    enqueueOrThrow: (message) async {
      if (outboxRefuses) throw Exception('no outbox row');
      sent.add(message);
    },
    rescan: canRescan ? () async => rescans++ : null,
  );

  group('flushOwed', () {
    test(
      'sends an owed token as a secret, with its own stamp and without the '
      'device-local marks, then owes nothing',
      () async {
        final record = await storage.save(token: 'ghp_secret', login: 'pingu');

        expect(await sync().flushOwed(), isTrue);

        expect(sent, [
          SyncMessage.gitHubAccount(
            updatedAt: record.updatedAt,
            status: SyncEntryStatus.update,
            token: const SyncSecret('ghp_secret'),
            login: 'pingu',
          ),
        ]);
        final json = sent.single.toJson();
        expect(json.containsKey('verified'), isFalse);
        expect(json.containsKey('owed'), isFalse);
        expect((await storage.read())!.owed, isFalse);
      },
    );

    test('sends an owed disconnection as no token', () async {
      await storage.save(token: 'ghp_secret', login: 'pingu');
      await sync().flushOwed();
      await storage.clear();

      await sync().flushOwed();

      final message = sent.last as SyncGitHubAccount;
      expect(message.token, isNull);
      expect(message.login, isNull);
    });

    test(
      'a refused outbox row stays owed, and is sent by a later flush '
      '(RetryOwed)',
      () async {
        await storage.save(token: 'ghp_secret', login: 'pingu');
        outboxRefuses = true;

        expect(await sync().flushOwed(), isFalse);
        expect(sent, isEmpty);
        expect((await storage.read())!.owed, isTrue);

        outboxRefuses = false;
        expect(await sync().flushOwed(), isTrue);
        expect(sent, hasLength(1));
        expect((await storage.read())!.owed, isFalse);
      },
    );

    test('nothing owed sends nothing', () async {
      expect(await sync().flushOwed(), isTrue);
      await storage.applyIfNewer(
        const GitHubAccountRecord(token: 'ghp_synced', updatedAt: 1),
      );
      expect(await sync().flushOwed(), isTrue);
      expect(sent, isEmpty);
    });
  });

  group('resend', () {
    test('sends the held token again, owed or not', () async {
      final record = await storage.save(token: 'ghp_secret', login: 'pingu');
      await sync().flushOwed();

      expect(await sync().resend(), isTrue);

      expect(sent, hasLength(2));
      expect((sent.last as SyncGitHubAccount).updatedAt, record.updatedAt);
    });

    test('says so when the outbox refuses it', () async {
      await storage.save(token: 'ghp_secret', login: 'pingu');
      outboxRefuses = true;
      expect(await sync().resend(), isFalse);
    });

    test('has nothing to send without a token', () async {
      expect(await sync().resend(), isNull);
      await storage.clear();
      expect(await sync().resend(), isNull);
      expect(sent, isEmpty);
    });
  });

  test('checking other devices asks sync to catch up', () async {
    final s = sync();
    expect(s.canCheckOtherDevices, isTrue);

    await s.checkOtherDevices();

    expect(rescans, 1);
  });

  test('a world without sync has nothing to check', () async {
    final s = sync(canRescan: false);
    expect(s.canCheckOtherDevices, isFalse);

    await s.checkOtherDevices();

    expect(rescans, 0);
  });
}
