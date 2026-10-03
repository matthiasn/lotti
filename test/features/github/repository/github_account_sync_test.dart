import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/github/repository/github_account_sync.dart';
import 'package:lotti/features/github/repository/github_token_storage.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/model/sync_secret.dart';

void main() {
  late List<SyncMessage> sent;
  var rescans = 0;

  setUp(() {
    sent = [];
    rescans = 0;
  });

  GitHubAccountSync sync({bool canRescan = true}) => GitHubAccountSync(
    enqueue: (message) async => sent.add(message),
    rescan: canRescan ? () async => rescans++ : null,
  );

  test(
    'publishes a token as a secret, with its own stamp, and leaves the '
    'device-local check behind',
    () async {
      await sync().publish(
        const GitHubAccountRecord(
          token: 'ghp_secret',
          login: 'pingu',
          updatedAt: 42,
          verified: true,
        ),
      );

      expect(sent, [
        const SyncMessage.gitHubAccount(
          updatedAt: 42,
          status: SyncEntryStatus.update,
          token: SyncSecret('ghp_secret'),
          login: 'pingu',
        ),
      ]);
      expect(sent.single.toJson().containsKey('verified'), isFalse);
    },
  );

  test('publishes a disconnection as no token', () async {
    await sync().publish(const GitHubAccountRecord(updatedAt: 43));

    final message = sent.single as SyncGitHubAccount;
    expect(message.token, isNull);
    expect(message.login, isNull);
    expect(message.updatedAt, 43);
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
