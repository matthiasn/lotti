import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';

void main() {
  group('AiConfigInferenceProfile.pinnedHostId', () {
    final createdAt = DateTime.utc(2026, 3, 15, 12);

    test('round-trips when set', () {
      final profile =
          AiConfig.inferenceProfile(
                id: 'profile-1',
                name: 'Local Mac',
                createdAt: createdAt,
                thinkingModelId: 'qwen3:latest',
                pinnedHostId: 'host-uuid-abc',
              )
              as AiConfigInferenceProfile;

      final decoded =
          AiConfig.fromJson(
                jsonDecode(jsonEncode(profile.toJson()))
                    as Map<String, dynamic>,
              )
              as AiConfigInferenceProfile;

      expect(decoded.pinnedHostId, 'host-uuid-abc');
    });

    test('defaults to null when omitted', () {
      final profile =
          AiConfig.inferenceProfile(
                id: 'profile-2',
                name: 'Default',
                createdAt: createdAt,
                thinkingModelId: 'qwen3:latest',
              )
              as AiConfigInferenceProfile;

      expect(profile.pinnedHostId, isNull);

      final decoded =
          AiConfig.fromJson(
                jsonDecode(jsonEncode(profile.toJson()))
                    as Map<String, dynamic>,
              )
              as AiConfigInferenceProfile;

      expect(decoded.pinnedHostId, isNull);
    });

    test('deserializes legacy JSON (without the field) as null', () {
      // Simulates a profile written by an older client that doesn't know
      // about pinnedHostId. The new field must default to null, not crash.
      final json = <String, dynamic>{
        'runtimeType': 'inferenceProfile',
        'id': 'profile-3',
        'name': 'Legacy',
        'createdAt': createdAt.toIso8601String(),
        'thinkingModelId': 'qwen3:latest',
        'isDefault': false,
        'desktopOnly': false,
        'skillAssignments': <Map<String, dynamic>>[],
      };

      final decoded = AiConfig.fromJson(json) as AiConfigInferenceProfile;

      expect(decoded.pinnedHostId, isNull);
      expect(decoded.id, 'profile-3');
      expect(decoded.thinkingModelId, 'qwen3:latest');
    });

    test('clearing the pin via copyWith persists as null', () {
      final pinned =
          AiConfig.inferenceProfile(
                id: 'profile-4',
                name: 'Pinned',
                createdAt: createdAt,
                thinkingModelId: 'qwen3:latest',
                pinnedHostId: 'host-uuid-xyz',
              )
              as AiConfigInferenceProfile;

      final cleared = pinned.copyWith(pinnedHostId: null);
      final decoded =
          AiConfig.fromJson(
                jsonDecode(jsonEncode(cleared.toJson()))
                    as Map<String, dynamic>,
              )
              as AiConfigInferenceProfile;

      expect(decoded.pinnedHostId, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // JSON round-trip tests for the remaining four union variants.
  // -------------------------------------------------------------------------

  group('AiConfigInferenceProvider JSON round-trip', () {
    test('round-trips required fields', () {
      final config =
          AiConfig.inferenceProvider(
                id: 'prov-1',
                name: 'My Provider',
                baseUrl: 'https://api.example.com',
                apiKey: 'sk-abc',
                createdAt: DateTime.utc(2025, 6),
                inferenceProviderType: InferenceProviderType.openAi,
              )
              as AiConfigInferenceProvider;

      final decoded =
          AiConfig.fromJson(
                jsonDecode(jsonEncode(config.toJson())) as Map<String, dynamic>,
              )
              as AiConfigInferenceProvider;

      expect(decoded.id, config.id);
      expect(decoded.name, config.name);
      expect(decoded.baseUrl, config.baseUrl);
      expect(decoded.apiKey, config.apiKey);
      expect(decoded.inferenceProviderType, config.inferenceProviderType);
      expect(decoded.createdAt, config.createdAt);
    });

    test('round-trips optional description', () {
      final config =
          AiConfig.inferenceProvider(
                id: 'prov-2',
                name: 'Annotated',
                baseUrl: 'https://api.example.com',
                apiKey: 'sk-xyz',
                createdAt: DateTime.utc(2025),
                inferenceProviderType: InferenceProviderType.gemini,
                description: 'My favourite provider',
              )
              as AiConfigInferenceProvider;

      final decoded =
          AiConfig.fromJson(
                jsonDecode(jsonEncode(config.toJson())) as Map<String, dynamic>,
              )
              as AiConfigInferenceProvider;

      expect(decoded.description, 'My favourite provider');
    });

    test('all InferenceProviderType values survive round-trip', () {
      for (final pt in InferenceProviderType.values) {
        final config =
            AiConfig.inferenceProvider(
                  id: 'prov-${pt.name}',
                  name: pt.name,
                  baseUrl: 'https://example.com',
                  apiKey: 'k',
                  createdAt: DateTime.utc(2025),
                  inferenceProviderType: pt,
                )
                as AiConfigInferenceProvider;

        final decoded =
            AiConfig.fromJson(
                  jsonDecode(jsonEncode(config.toJson()))
                      as Map<String, dynamic>,
                )
                as AiConfigInferenceProvider;

        expect(
          decoded.inferenceProviderType,
          pt,
          reason: 'provider type ${pt.name} should survive round-trip',
        );
      }
    });
  });

  group('AiConfigModel JSON round-trip', () {
    test('round-trips with multi-modal fields', () {
      final config =
          AiConfig.model(
                id: 'model-1',
                name: 'GPT-4o',
                providerModelId: 'gpt-4o',
                inferenceProviderId: 'prov-1',
                createdAt: DateTime.utc(2025, 3),
                inputModalities: [Modality.text, Modality.image],
                outputModalities: [Modality.text],
                isReasoningModel: false,
                supportsFunctionCalling: true,
                maxCompletionTokens: 4096,
              )
              as AiConfigModel;

      final decoded =
          AiConfig.fromJson(
                jsonDecode(jsonEncode(config.toJson())) as Map<String, dynamic>,
              )
              as AiConfigModel;

      expect(decoded.id, config.id);
      expect(decoded.providerModelId, config.providerModelId);
      expect(decoded.inferenceProviderId, config.inferenceProviderId);
      expect(decoded.inputModalities, config.inputModalities);
      expect(decoded.outputModalities, config.outputModalities);
      expect(decoded.isReasoningModel, config.isReasoningModel);
      expect(decoded.supportsFunctionCalling, config.supportsFunctionCalling);
      expect(decoded.maxCompletionTokens, config.maxCompletionTokens);
    });

    test('maxCompletionTokens defaults to null when omitted', () {
      final config =
          AiConfig.model(
                id: 'model-2',
                name: 'Small Model',
                providerModelId: 'small',
                inferenceProviderId: 'prov-1',
                createdAt: DateTime.utc(2025),
                inputModalities: [Modality.text],
                outputModalities: [Modality.text],
                isReasoningModel: false,
              )
              as AiConfigModel;

      final decoded =
          AiConfig.fromJson(
                jsonDecode(jsonEncode(config.toJson())) as Map<String, dynamic>,
              )
              as AiConfigModel;

      expect(decoded.maxCompletionTokens, isNull);
    });

    test('all Modality values survive round-trip', () {
      const modalities = Modality.values;
      final config =
          AiConfig.model(
                id: 'model-3',
                name: 'All Modalities',
                providerModelId: 'all',
                inferenceProviderId: 'prov-1',
                createdAt: DateTime.utc(2025),
                inputModalities: modalities,
                outputModalities: modalities,
                isReasoningModel: false,
              )
              as AiConfigModel;

      final decoded =
          AiConfig.fromJson(
                jsonDecode(jsonEncode(config.toJson())) as Map<String, dynamic>,
              )
              as AiConfigModel;

      expect(decoded.inputModalities, modalities);
      expect(decoded.outputModalities, modalities);
    });
  });
}
