import 'package:flutter_test/flutter_test.dart';
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
  });
}
