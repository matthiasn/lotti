import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/database/ai_config_db.dart';
import 'package:lotti/features/ai/model/ai_config.dart';

void main() {
  group('AiConfigDb getConfigById provider type normalization', () {
    late AiConfigDb db;

    setUp(() {
      db = AiConfigDb(inMemoryDatabase: true);
    });

    tearDown(() async {
      await db.close();
    });

    Future<void> insertSerialized(
        {required String id, required Object? rawType}) async {
      final now = DateTime(2024);
      final payload = <String, dynamic>{
        'runtimeType': 'inferenceProvider',
        'id': id,
        'baseUrl': 'http://example.com',
        'apiKey': 'k',
        'name': 'Legacy Provider',
        'createdAt': now.toIso8601String(),
        'inferenceProviderType': rawType,
      };

      final entity = AiConfigDbEntity(
        id: id,
        type: 'inferenceProvider',
        name: 'Legacy Provider',
        serialized: jsonEncode(payload),
        createdAt: now,
        updatedAt: now,
      );

      await db.into(db.aiConfigs).insertOnConflictUpdate(entity);
    }

    test('null and non-string values normalize to genericOpenAi', () async {
      await insertSerialized(id: 'p-null', rawType: null);
      await insertSerialized(id: 'p-int', rawType: 123);
      await insertSerialized(id: 'p-unknown', rawType: 'unknown');

      final pNull =
          await db.getConfigById('p-null') as AiConfigInferenceProvider?;
      final pInt =
          await db.getConfigById('p-int') as AiConfigInferenceProvider?;
      final pUnknown =
          await db.getConfigById('p-unknown') as AiConfigInferenceProvider?;

      expect(pNull, isNotNull);
      expect(pInt, isNotNull);
      expect(pUnknown, isNotNull);

      expect(pNull!.inferenceProviderType, InferenceProviderType.genericOpenAi);
      expect(pInt!.inferenceProviderType, InferenceProviderType.genericOpenAi);
      expect(
          pUnknown!.inferenceProviderType, InferenceProviderType.genericOpenAi);
    });

    test('valid string values remain unchanged', () async {
      await insertSerialized(id: 'p-ollama', rawType: 'ollama');

      final p =
          await db.getConfigById('p-ollama') as AiConfigInferenceProvider?;
      expect(p, isNotNull);
      expect(p!.inferenceProviderType, InferenceProviderType.ollama);
    });
  });
}
