import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/database/ai_api_key_storage.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  test('in-memory storage writes, reads, and deletes values', () async {
    final storage = AiApiKeyStorage.inMemory();

    await storage.write(key: 'provider', value: 'secret');
    expect(await storage.read('provider'), 'secret');

    await storage.delete('provider');
    expect(await storage.read('provider'), isNull);
  });

  test('delegates platform operations to SecureStorage', () async {
    final secureStorage = MockSecureStorage();
    when(
      () => secureStorage.read(key: 'provider'),
    ).thenAnswer((_) async => 'secret');
    when(
      () => secureStorage.write(key: 'provider', value: 'secret'),
    ).thenAnswer((_) async {});
    when(() => secureStorage.delete(key: 'provider')).thenAnswer((_) async {});
    final storage = AiApiKeyStorage(secureStorage);

    expect(await storage.read('provider'), 'secret');
    await storage.write(key: 'provider', value: 'secret');
    await storage.delete('provider');
    verify(() => secureStorage.read(key: 'provider')).called(1);
    verify(
      () => secureStorage.write(key: 'provider', value: 'secret'),
    ).called(1);
    verify(() => secureStorage.delete(key: 'provider')).called(1);
  });
}
