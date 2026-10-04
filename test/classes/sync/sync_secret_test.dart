import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/sync/sync_message.dart';
import 'package:lotti/classes/sync/sync_secret.dart';

void main() {
  const message = SyncMessage.gitHubAccount(
    updatedAt: 42,
    status: SyncEntryStatus.update,
    token: SyncSecret('ghp_secret'),
    login: 'pingu',
  );

  test('a message carrying a secret never prints it', () {
    expect(const SyncSecret('ghp_secret').toString(), 'SyncSecret(redacted)');
    expect(message.toString(), isNot(contains('ghp_secret')));
    expect('$message', contains('SyncSecret(redacted)'));
  });

  test('the JSON carries it, and reads back equal', () {
    final json =
        jsonDecode(jsonEncode(message.toJson())) as Map<String, dynamic>;

    expect(json['token'], 'ghp_secret');
    expect(SyncMessage.fromJson(json), message);
  });

  test('equal by value', () {
    expect(const SyncSecret('a'), const SyncSecret('a'));
    expect(const SyncSecret('a').hashCode, const SyncSecret('a').hashCode);
    expect(const SyncSecret('a'), isNot(const SyncSecret('b')));
  });
}
