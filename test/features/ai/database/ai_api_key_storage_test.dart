import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/database/ai_api_key_storage.dart';

void main() {
  test('in-memory storage writes, reads, and deletes values', () async {
    final storage = AiApiKeyStorage.inMemory();

    await storage.write(key: 'provider', value: 'secret');
    expect(await storage.read('provider'), 'secret');

    await storage.delete('provider');
    expect(await storage.read('provider'), isNull);
  });
}
