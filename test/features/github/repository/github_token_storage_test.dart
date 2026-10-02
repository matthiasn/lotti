import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/github/repository/github_token_storage.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  late MockSecureStorage keystore;
  late Map<String, String> values;

  setUp(() {
    keystore = MockSecureStorage();
    values = {};
    when(() => keystore.read(key: any(named: 'key'))).thenAnswer(
      (invocation) async => values[invocation.namedArguments[#key] as String],
    );
    when(
      () => keystore.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((invocation) async {
      values[invocation.namedArguments[#key] as String] =
          invocation.namedArguments[#value] as String;
    });
    when(() => keystore.delete(key: any(named: 'key'))).thenAnswer((
      invocation,
    ) async {
      values.remove(invocation.namedArguments[#key] as String);
    });
  });

  test('saves the token and its login in the keystore, namespaced by '
      'profile', () async {
    final storage = GitHubTokenStorage(keystore, namespace: 'profile-1');

    await storage.save(token: 'ghp_secret', login: 'pingu');

    expect(values, {
      'github_token:profile-1': 'ghp_secret',
      'github_login:profile-1': 'pingu',
    });
    expect(await storage.readToken(), 'ghp_secret');
    expect(await storage.readLogin(), 'pingu');
  });

  test('another profile never reads the token', () async {
    await GitHubTokenStorage(
      keystore,
      namespace: 'real',
    ).save(token: 'ghp_secret', login: 'pingu');

    final demo = GitHubTokenStorage(keystore, namespace: 'demo');
    expect(await demo.readToken(), isNull);
    expect(await demo.readLogin(), isNull);
  });

  test('clear removes both', () async {
    final storage = GitHubTokenStorage(keystore, namespace: 'profile-1');
    await storage.save(token: 'ghp_secret', login: 'pingu');

    await storage.clear();

    expect(values, isEmpty);
    expect(await storage.readToken(), isNull);
  });
}
