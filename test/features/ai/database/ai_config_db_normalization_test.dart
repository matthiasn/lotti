import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/database/ai_api_key_storage.dart';
import 'package:lotti/features/ai/database/ai_config_db.dart';
import 'package:lotti/features/ai/model/ai_config.dart';

import '../test_utils.dart';

void main() {
  group('AiConfigDb getConfigById provider type normalization', () {
    late AiConfigDb db;
    late AiApiKeyStorage storage;

    setUp(() {
      storage = AiApiKeyStorage.inMemory();
      db = AiConfigDb(inMemoryDatabase: true, apiKeyStorage: storage);
    });

    tearDown(() async {
      await db.close();
    });

    Future<void> insertSerialized({
      required String id,
      required Object? rawType,
    }) async {
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

      // `!` + typed cast: a null or wrong-typed result throws a precise
      // error right here, so no isNotNull pre-checks are needed.
      final pNull =
          (await db.getConfigById('p-null'))! as AiConfigInferenceProvider;
      final pInt =
          (await db.getConfigById('p-int'))! as AiConfigInferenceProvider;
      final pUnknown =
          (await db.getConfigById('p-unknown'))! as AiConfigInferenceProvider;

      expect(pNull.inferenceProviderType, InferenceProviderType.genericOpenAi);
      expect(pInt.inferenceProviderType, InferenceProviderType.genericOpenAi);
      expect(
        pUnknown.inferenceProviderType,
        InferenceProviderType.genericOpenAi,
      );
    });

    test(
      'inferenceProfile type is persisted and retrieved correctly',
      () async {
        final profile = AiConfig.inferenceProfile(
          id: 'profile-1',
          name: 'Gemini Flash',
          thinkingModelId: 'models/gemini-3-flash-preview',
          createdAt: DateTime(2024),
        );

        await db.saveConfig(profile);

        final retrieved = await db.getConfigById('profile-1');
        expect(retrieved, isA<AiConfigInferenceProfile>());
        final p = retrieved! as AiConfigInferenceProfile;
        expect(p.name, 'Gemini Flash');
        expect(p.thinkingModelId, 'models/gemini-3-flash-preview');
      },
    );

    test('valid string values remain unchanged', () async {
      await insertSerialized(id: 'p-ollama', rawType: 'ollama');

      final p =
          (await db.getConfigById('p-ollama'))! as AiConfigInferenceProvider;
      expect(p.inferenceProviderType, InferenceProviderType.ollama);
    });

    test(
      'deleting an unmigrated provider removes its retry credential',
      () async {
        await insertSerialized(id: 'legacy-delete', rawType: 'openAi');
        final key = apiKeyStorageKeyFor('legacy-delete');
        // A previous migration may have written the key but not committed SQL.
        await storage.write(key: key, value: 'k');
        await db.deleteConfig('legacy-delete');
        expect(await storage.read(key), isNull);
        expect(await db.getConfigById('legacy-delete'), isNull);
      },
    );
  });

  group('AiConfigDb CRUD', () {
    late AiConfigDb db;
    late AiApiKeyStorage storage;

    setUp(() {
      storage = AiApiKeyStorage.inMemory();
      db = AiConfigDb(inMemoryDatabase: true, apiKeyStorage: storage);
    });

    tearDown(() async {
      await db.close();
    });

    test('model, prompt, and skill configs round-trip via fromJson', () async {
      final model = AiTestDataFactory.createTestModel(id: 'm-1');
      final prompt = AiTestDataFactory.createTestPrompt(id: 'p-1');
      final skill = AiTestDataFactory.createTestSkill(id: 's-1');

      await db.saveConfig(model);
      await db.saveConfig(prompt);
      await db.saveConfig(skill);

      final m = (await db.getConfigById('m-1'))! as AiConfigModel;
      expect(m.providerModelId, model.providerModelId);
      expect(m.inferenceProviderId, model.inferenceProviderId);
      expect(m.inputModalities, model.inputModalities);
      expect(m.isReasoningModel, model.isReasoningModel);

      final pr = (await db.getConfigById('p-1'))! as AiConfigPrompt;
      expect(pr.systemMessage, prompt.systemMessage);
      expect(pr.userMessage, prompt.userMessage);
      expect(pr.defaultModelId, prompt.defaultModelId);
      expect(pr.aiResponseType, prompt.aiResponseType);

      final s = (await db.getConfigById('s-1'))! as AiConfigSkill;
      expect(s.skillType, SkillType.transcription);
      expect(s.systemInstructions, skill.systemInstructions);
      expect(s.userInstructions, skill.userInstructions);
      expect(s.requiredInputModalities, skill.requiredInputModalities);
    });

    test(
      'saveConfig upserts: same id updates and preserves createdAt',
      () async {
        final original = AiTestDataFactory.createTestModel(id: 'm-up');
        await db.saveConfig(original);
        final createdAt = (await db.getAllConfigs()).single.createdAt;

        await db.saveConfig(
          AiTestDataFactory.createTestModel(id: 'm-up', name: 'Renamed'),
        );

        final rows = await db.getAllConfigs();
        expect(rows, hasLength(1));
        expect(rows.single.name, 'Renamed');
        expect(rows.single.createdAt, createdAt);
      },
    );

    test('deleteConfig removes the row; getConfigById returns null', () async {
      await db.saveConfig(AiTestDataFactory.createTestModel(id: 'm-del'));
      expect(await db.getConfigById('m-del'), isNotNull);

      await db.deleteConfig('m-del');

      expect(await db.getConfigById('m-del'), isNull);
      expect(await db.getAllConfigs(), isEmpty);
    });

    test('getConfigsByType filters by serialized type discriminator', () async {
      await db.saveConfig(AiTestDataFactory.createTestModel(id: 'm-t'));
      await db.saveConfig(AiTestDataFactory.createTestPrompt(id: 'p-t'));
      await db.saveConfig(AiTestDataFactory.createTestSkill(id: 's-t'));

      final models = await db.getConfigsByType('model');
      final prompts = await db.getConfigsByType('prompt');
      final skills = await db.getConfigsByType('skill');

      expect(models.map((r) => r.id), ['m-t']);
      expect(prompts.map((r) => r.id), ['p-t']);
      expect(skills.map((r) => r.id), ['s-t']);
    });

    test('watchAllConfigs emits the row set after a save', () async {
      await db.saveConfig(AiTestDataFactory.createTestModel(id: 'm-w'));

      final first = await db.watchAllConfigs().first;
      expect(first.map((r) => r.id), ['m-w']);
    });

    test(
      'provider API keys are stored securely, not in the database JSON',
      () async {
        final provider = AiConfig.inferenceProvider(
          id: 'secure-provider',
          baseUrl: 'https://example.com',
          apiKey: 'secret-value',
          name: 'Provider',
          createdAt: DateTime(2024),
          inferenceProviderType: InferenceProviderType.openAi,
        );

        await db.saveConfig(provider);
        final row = (await db.getAllConfigs()).single;
        expect(row.serialized, isNot(contains('secret-value')));
        expect(
          await storage.read(apiKeyStorageKeyFor(provider.id)),
          'secret-value',
        );
        final loaded = await db.getConfigById(provider.id);
        expect((loaded! as AiConfigInferenceProvider).apiKey, 'secret-value');
      },
    );

    test(
      'legacy plaintext keys migrate idempotently and are cleared',
      () async {
        final now = DateTime(2024);
        const id = 'legacy-provider';
        final entity = AiConfigDbEntity(
          id: id,
          type: 'inferenceProvider',
          name: 'Legacy',
          serialized: jsonEncode({
            'runtimeType': 'inferenceProvider',
            'id': id,
            'baseUrl': 'https://example.com',
            'apiKey': 'legacy-secret',
            'name': 'Legacy',
            'createdAt': now.toIso8601String(),
            'inferenceProviderType': 'openAi',
          }),
          createdAt: now,
          updatedAt: now,
        );
        await db.into(db.aiConfigs).insert(entity);

        final first = await db.getConfigById(id);
        expect((first! as AiConfigInferenceProvider).apiKey, 'legacy-secret');
        expect(
          (await db.getAllConfigs()).single.serialized,
          isNot(contains('legacy-secret')),
        );
        final second = await db.getConfigById(id);
        expect((second! as AiConfigInferenceProvider).apiKey, 'legacy-secret');
      },
    );

    test('deleting a provider removes its secure credential', () async {
      final provider = AiConfig.inferenceProvider(
        id: 'delete-secure-provider',
        baseUrl: 'https://example.com',
        apiKey: 'secret-value',
        name: 'Provider',
        createdAt: DateTime(2024),
        inferenceProviderType: InferenceProviderType.openAi,
      );
      await db.saveConfig(provider);
      await db.deleteConfig(provider.id);
      expect(await storage.read(apiKeyStorageKeyFor(provider.id)), isNull);
    });

    test(
      'metadata-only save does not overwrite the secure credential',
      () async {
        final provider = AiConfig.inferenceProvider(
          id: 'metadata-provider',
          baseUrl: 'https://example.com',
          apiKey: 'secret-value',
          name: 'Provider',
          createdAt: DateTime(2024),
          inferenceProviderType: InferenceProviderType.openAi,
        );
        await db.saveConfig(provider);
        await db.saveConfig(
          (provider as AiConfigInferenceProvider).copyWith(apiKey: ''),
          persistApiKey: false,
        );
        final loaded = await db.getConfigById(provider.id);
        expect((loaded! as AiConfigInferenceProvider).apiKey, 'secret-value');
      },
    );

    test(
      'preserving an empty key retains authentication, clearing removes it',
      () async {
        final provider = AiConfigInferenceProvider(
          id: 'preserve-key',
          baseUrl: 'https://example.com',
          apiKey: 'stored-key',
          name: 'Provider',
          createdAt: DateTime(2024),
          inferenceProviderType: InferenceProviderType.openAi,
        );
        await db.saveConfig(provider);
        await db.saveConfig(
          provider.copyWith(apiKey: '', name: 'Renamed'),
          preserveExistingApiKeyOnEmpty: true,
        );
        final loaded =
            (await db.getConfigById(provider.id))! as AiConfigInferenceProvider;
        expect(loaded.name, 'Renamed');
        expect(loaded.apiKey, 'stored-key');
        expect(
          await storage.read(apiKeyStorageKeyFor(provider.id)),
          'stored-key',
        );
        await db.saveConfig(provider.copyWith(apiKey: ''));
        expect(await storage.read(apiKeyStorageKeyFor(provider.id)), isNull);
        expect(
          ((await db.getConfigById(provider.id))! as AiConfigInferenceProvider)
              .apiKey,
          isEmpty,
        );
      },
    );
  });
}
