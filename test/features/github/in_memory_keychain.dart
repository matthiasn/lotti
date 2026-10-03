import 'package:mocktail/mocktail.dart';

import '../../mocks/mocks.dart';

/// A [MockSecureStorage] backed by [values], so a test reads back what was
/// written and can look at the keychain afterwards.
MockSecureStorage inMemoryKeychain(Map<String, String> values) {
  final keystore = MockSecureStorage();
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
  return keystore;
}
