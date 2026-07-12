import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/ai/model/skill_assignment.dart';

import '../../agents/test_utils.dart';
import '../test_utils.dart';

void main() {
  group('ResolvedProfile', () {
    final provider1 = testInferenceProvider(id: 'p1');
    final provider2 = testInferenceProvider(id: 'p2');

    test('equal instances are equal', () {
      final a = ResolvedProfile(
        thinkingModelId: 'model-a',
        thinkingProvider: provider1,
      );
      final b = ResolvedProfile(
        thinkingModelId: 'model-a',
        thinkingProvider: provider1,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('different thinkingModelId are not equal', () {
      final a = ResolvedProfile(
        thinkingModelId: 'model-a',
        thinkingProvider: provider1,
      );
      final b = ResolvedProfile(
        thinkingModelId: 'model-b',
        thinkingProvider: provider1,
      );

      expect(a, isNot(equals(b)));
    });

    test('different thinkingProvider are not equal', () {
      final a = ResolvedProfile(
        thinkingModelId: 'model-a',
        thinkingProvider: provider1,
      );
      final b = ResolvedProfile(
        thinkingModelId: 'model-a',
        thinkingProvider: provider2,
      );

      expect(a, isNot(equals(b)));
    });

    test('profiles with all slots populated are equal', () {
      final a = ResolvedProfile(
        thinkingModelId: 'thinking',
        thinkingProvider: provider1,
        thinkingHighEndModelId: 'thinking-pro',
        thinkingHighEndProvider: provider2,
        imageRecognitionModelId: 'vision',
        imageRecognitionProvider: provider2,
        transcriptionModelId: 'audio',
        transcriptionProvider: provider1,
        imageGenerationModelId: 'image',
        imageGenerationProvider: provider2,
      );
      final b = ResolvedProfile(
        thinkingModelId: 'thinking',
        thinkingProvider: provider1,
        thinkingHighEndModelId: 'thinking-pro',
        thinkingHighEndProvider: provider2,
        imageRecognitionModelId: 'vision',
        imageRecognitionProvider: provider2,
        transcriptionModelId: 'audio',
        transcriptionProvider: provider1,
        imageGenerationModelId: 'image',
        imageGenerationProvider: provider2,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('optional slot difference makes profiles unequal', () {
      final a = ResolvedProfile(
        thinkingModelId: 'thinking',
        thinkingProvider: provider1,
        imageRecognitionModelId: 'vision',
      );
      final b = ResolvedProfile(
        thinkingModelId: 'thinking',
        thinkingProvider: provider1,
      );

      expect(a, isNot(equals(b)));
    });

    test('different thinkingHighEndModelId are not equal', () {
      final a = ResolvedProfile(
        thinkingModelId: 'model-a',
        thinkingProvider: provider1,
        thinkingHighEndModelId: 'pro-1',
        thinkingHighEndProvider: provider2,
      );
      final b = ResolvedProfile(
        thinkingModelId: 'model-a',
        thinkingProvider: provider1,
        thinkingHighEndModelId: 'pro-2',
        thinkingHighEndProvider: provider2,
      );

      expect(a, isNot(equals(b)));
    });

    test('effectiveHighEndModelId returns high-end when set', () {
      final profile = ResolvedProfile(
        thinkingModelId: 'flash',
        thinkingProvider: provider1,
        thinkingHighEndModelId: 'pro',
        thinkingHighEndProvider: provider2,
      );

      expect(profile.effectiveHighEndModelId, 'pro');
      expect(profile.effectiveHighEndProvider, provider2);
    });

    test('effectiveHighEndModelId falls back to thinking when not set', () {
      final profile = ResolvedProfile(
        thinkingModelId: 'flash',
        thinkingProvider: provider1,
      );

      expect(profile.effectiveHighEndModelId, 'flash');
      expect(profile.effectiveHighEndProvider, provider1);
    });

    test('skillAssignments participate in equality', () {
      ResolvedProfile withSkills(List<SkillAssignment> skills) =>
          ResolvedProfile(
            thinkingModelId: 'thinking',
            thinkingProvider: provider1,
            skillAssignments: skills,
          );

      const skillA = SkillAssignment(skillId: 'skill-a', automate: true);
      const skillB = SkillAssignment(skillId: 'skill-b');

      // Equal lists (by value) keep profiles equal.
      expect(
        withSkills(const [skillA, skillB]),
        equals(withSkills(const [skillA, skillB])),
      );
      // Differing content, order, or length breaks equality.
      expect(
        withSkills(const [skillA, skillB]),
        isNot(equals(withSkills(const [skillB, skillA]))),
      );
      expect(
        withSkills(const [skillA]),
        isNot(equals(withSkills(const [skillA, skillB]))),
      );
    });

    test('optional resolved model slots participate in equality', () {
      final model = AiTestDataFactory.createTestModel(id: 'm-1');
      ResolvedProfile withModels({
        bool thinking = false,
        bool imageRecognition = false,
        bool transcription = false,
        bool imageGeneration = false,
      }) => ResolvedProfile(
        thinkingModelId: 'thinking',
        thinkingProvider: provider1,
        thinkingModel: thinking ? model : null,
        imageRecognitionModel: imageRecognition ? model : null,
        transcriptionModel: transcription ? model : null,
        imageGenerationModel: imageGeneration ? model : null,
      );

      final base = withModels();
      expect(withModels(), equals(base));
      expect(withModels(thinking: true), isNot(equals(base)));
      expect(withModels(imageRecognition: true), isNot(equals(base)));
      expect(withModels(transcription: true), isNot(equals(base)));
      expect(withModels(imageGeneration: true), isNot(equals(base)));
    });

    test('is not equal to a non-ResolvedProfile object', () {
      final profile = ResolvedProfile(
        thinkingModelId: 'model-a',
        thinkingProvider: provider1,
      );

      // ignore: unrelated_type_equality_checks
      expect(profile == 'not a profile', isFalse);
    });

    test('withThinkingRoute preserves every non-thinking slot', () {
      final originalModel = AiTestDataFactory.createTestModel(id: 'original');
      final replacementModel = AiTestDataFactory.createTestModel(
        id: 'replacement',
        providerModelId: 'replacement-wire-id',
      );
      final original = ResolvedProfile(
        thinkingModelId: 'original-wire-id',
        thinkingProvider: provider1,
        thinkingModel: originalModel,
        thinkingHighEndModelId: 'high-end',
        thinkingHighEndProvider: provider1,
        thinkingHighEndModel: originalModel,
        imageRecognitionModelId: 'vision',
        imageRecognitionProvider: provider1,
        imageRecognitionModel: originalModel,
        transcriptionModelId: 'audio',
        transcriptionProvider: provider1,
        transcriptionModel: originalModel,
        imageGenerationModelId: 'image',
        imageGenerationProvider: provider1,
        imageGenerationModel: originalModel,
        skillAssignments: const [
          SkillAssignment(skillId: 'skill', automate: true),
        ],
      );

      final replaced = original.withThinkingRoute(
        model: replacementModel,
        provider: provider2,
      );

      expect(replaced.thinkingModelId, 'replacement-wire-id');
      expect(replaced.thinkingProvider, provider2);
      expect(replaced.thinkingModel, replacementModel);
      expect(replaced.thinkingHighEndModelId, original.thinkingHighEndModelId);
      expect(
        replaced.imageRecognitionModelId,
        original.imageRecognitionModelId,
      );
      expect(replaced.transcriptionModelId, original.transcriptionModelId);
      expect(replaced.imageGenerationModelId, original.imageGenerationModelId);
      expect(replaced.skillAssignments, original.skillAssignments);
    });
  });

  group('InferenceRouteFingerprint', () {
    glados.Glados(
      glados.any.letterOrDigits,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'value equality and hashCode are stable for generated runtime settings',
      (value) {
        final normalized = value.isEmpty ? 'default' : value;
        final first = InferenceRouteFingerprint(
          modelConfigId: 'model-$normalized',
          providerModelId: 'wire-$normalized',
          providerConfigId: 'provider-$normalized',
          providerType: InferenceProviderType.openRouter,
          runtimeSettings: {'setting': normalized},
        );
        final second = InferenceRouteFingerprint(
          modelConfigId: 'model-$normalized',
          providerModelId: 'wire-$normalized',
          providerConfigId: 'provider-$normalized',
          providerType: InferenceProviderType.openRouter,
          runtimeSettings: {'setting': normalized},
        );

        expect(first, second, reason: 'value=$normalized');
        expect(first.hashCode, second.hashCode, reason: 'value=$normalized');
      },
      tags: 'glados',
    );

    test('fromProfile captures ids, provider type, and runtime settings', () {
      final model = AiTestDataFactory.createTestModel(
        id: 'model-config',
        providerModelId: 'wire-id',
      );
      final provider = testInferenceProvider(id: 'provider-config');
      final fingerprint = InferenceRouteFingerprint.fromProfile(
        ResolvedProfile(
          thinkingModelId: 'wire-id',
          thinkingProvider: provider,
          thinkingModel: model,
        ),
      );

      expect(fingerprint.modelConfigId, 'model-config');
      expect(fingerprint.providerModelId, 'wire-id');
      expect(fingerprint.providerConfigId, 'provider-config');
      expect(fingerprint.providerType, InferenceProviderType.gemini);
      expect(fingerprint.runtimeSettings, {
        'geminiThinkingMode': model.geminiThinkingMode.name,
      });
    });

    test('different route fields and runtime settings break equality', () {
      const base = InferenceRouteFingerprint(
        modelConfigId: 'model',
        providerModelId: 'wire',
        providerConfigId: 'provider',
        providerType: InferenceProviderType.gemini,
        runtimeSettings: {'setting': 'a'},
      );
      final variants = [
        const InferenceRouteFingerprint(
          modelConfigId: 'other',
          providerModelId: 'wire',
          providerConfigId: 'provider',
          providerType: InferenceProviderType.gemini,
          runtimeSettings: {'setting': 'a'},
        ),
        const InferenceRouteFingerprint(
          modelConfigId: 'model',
          providerModelId: 'other',
          providerConfigId: 'provider',
          providerType: InferenceProviderType.gemini,
          runtimeSettings: {'setting': 'a'},
        ),
        const InferenceRouteFingerprint(
          modelConfigId: 'model',
          providerModelId: 'wire',
          providerConfigId: 'other',
          providerType: InferenceProviderType.gemini,
          runtimeSettings: {'setting': 'a'},
        ),
        const InferenceRouteFingerprint(
          modelConfigId: 'model',
          providerModelId: 'wire',
          providerConfigId: 'provider',
          providerType: InferenceProviderType.openRouter,
          runtimeSettings: {'setting': 'a'},
        ),
        const InferenceRouteFingerprint(
          modelConfigId: 'model',
          providerModelId: 'wire',
          providerConfigId: 'provider',
          providerType: InferenceProviderType.gemini,
          runtimeSettings: {'setting': 'b'},
        ),
      ];

      for (final variant in variants) {
        expect(base, isNot(variant));
      }
      // ignore: unrelated_type_equality_checks
      expect(base == 'not a fingerprint', isFalse);
    });
  });

  group('ResolvedAgentSetup', () {
    test('derived state distinguishes runnable and broken selections', () {
      const resolved = ResolvedAgentSetup(
        status: AgentSetupResolutionStatus.resolved,
        brokenSelectionId: 'missing-override',
        setupOrigin: AgentInferenceSetupOrigin.categorySnapshot,
      );

      expect(resolved.canRun, isTrue);
      expect(resolved.hasBrokenSelection, isTrue);
      expect(resolved.setupOrigin, AgentInferenceSetupOrigin.categorySnapshot);
    });
  });
}
