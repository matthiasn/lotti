import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/skill_assignment.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'ai_config_test_helpers.dart';

void main() {
  group('AiConfigPrompt JSON round-trip', () {
    test('round-trips required fields', () {
      final config =
          AiConfig.prompt(
                id: 'prompt-1',
                name: 'Task Summary',
                systemMessage: 'You are a summariser.',
                userMessage: 'Summarise the task.',
                defaultModelId: 'model-1',
                modelIds: ['model-1', 'model-2'],
                createdAt: DateTime.utc(2025, 4),
                useReasoning: false,
                requiredInputData: [InputDataType.task],
                aiResponseType: AiResponseType
                    .taskSummary, // ignore: deprecated_member_use_from_same_package
              )
              as AiConfigPrompt;

      final decoded =
          AiConfig.fromJson(
                jsonDecode(jsonEncode(config.toJson())) as Map<String, dynamic>,
              )
              as AiConfigPrompt;

      expect(decoded.id, config.id);
      expect(decoded.systemMessage, config.systemMessage);
      expect(decoded.userMessage, config.userMessage);
      expect(decoded.defaultModelId, config.defaultModelId);
      expect(decoded.modelIds, config.modelIds);
      expect(decoded.useReasoning, config.useReasoning);
      expect(decoded.requiredInputData, config.requiredInputData);
      expect(decoded.aiResponseType, config.aiResponseType);
    });

    test('nullable defaultVariables Map round-trips correctly', () {
      final withVars =
          AiConfig.prompt(
                id: 'prompt-2',
                name: 'Prompt with vars',
                systemMessage: 'Sys',
                userMessage: 'User',
                defaultModelId: 'model-1',
                modelIds: ['model-1'],
                createdAt: DateTime.utc(2025),
                useReasoning: true,
                requiredInputData: [],
                aiResponseType: AiResponseType.audioTranscription,
                defaultVariables: {'lang': 'en', 'style': 'concise'},
              )
              as AiConfigPrompt;

      final decoded =
          AiConfig.fromJson(
                jsonDecode(jsonEncode(withVars.toJson()))
                    as Map<String, dynamic>,
              )
              as AiConfigPrompt;

      expect(decoded.defaultVariables, <String, String>{
        'lang': 'en',
        'style': 'concise',
      });
    });

    test('null defaultVariables survives round-trip as null', () {
      final noVars =
          AiConfig.prompt(
                id: 'prompt-3',
                name: 'No vars',
                systemMessage: 'Sys',
                userMessage: 'User',
                defaultModelId: 'model-1',
                modelIds: ['model-1'],
                createdAt: DateTime.utc(2025),
                useReasoning: false,
                requiredInputData: [],
                aiResponseType: AiResponseType.imageAnalysis,
              )
              as AiConfigPrompt;

      final decoded =
          AiConfig.fromJson(
                jsonDecode(jsonEncode(noVars.toJson())) as Map<String, dynamic>,
              )
              as AiConfigPrompt;

      expect(decoded.defaultVariables, isNull);
    });

    test('all AiResponseType values survive round-trip', () {
      for (final rt in AiResponseType.values) {
        final config =
            AiConfig.prompt(
                  id: 'prompt-rt-${rt.name}',
                  name: rt.name,
                  systemMessage: 'S',
                  userMessage: 'U',
                  defaultModelId: 'm',
                  modelIds: <String>['m'],
                  createdAt: DateTime.utc(2025),
                  useReasoning: false,
                  requiredInputData: <InputDataType>[],
                  aiResponseType: rt,
                )
                as AiConfigPrompt;

        final decoded =
            AiConfig.fromJson(
                  jsonDecode(jsonEncode(config.toJson()))
                      as Map<String, dynamic>,
                )
                as AiConfigPrompt;

        expect(
          decoded.aiResponseType,
          rt,
          reason: 'AiResponseType.${rt.name} should survive round-trip',
        );
      }
    });
  });

  group('AiConfigSkill JSON round-trip', () {
    test('round-trips required fields', () {
      final config =
          AiConfig.skill(
                id: 'skill-1',
                name: 'Transcription',
                createdAt: DateTime.utc(2025, 2),
                skillType: SkillType.transcription,
                requiredInputModalities: [Modality.audio],
                systemInstructions: 'Transcribe the audio.',
                userInstructions: 'Please transcribe.',
                contextPolicy: ContextPolicy.dictionaryOnly,
              )
              as AiConfigSkill;

      final decoded =
          AiConfig.fromJson(
                jsonDecode(jsonEncode(config.toJson())) as Map<String, dynamic>,
              )
              as AiConfigSkill;

      expect(decoded.id, config.id);
      expect(decoded.skillType, config.skillType);
      expect(decoded.requiredInputModalities, config.requiredInputModalities);
      expect(decoded.systemInstructions, config.systemInstructions);
      expect(decoded.userInstructions, config.userInstructions);
      expect(decoded.contextPolicy, config.contextPolicy);
      expect(decoded.useReasoning, config.useReasoning);
    });

    test('all SkillType values survive round-trip', () {
      for (final st in SkillType.values) {
        final config =
            AiConfig.skill(
                  id: 'skill-${st.name}',
                  name: st.name,
                  createdAt: DateTime.utc(2025),
                  skillType: st,
                  requiredInputModalities: <Modality>[],
                  systemInstructions: 'S',
                  userInstructions: 'U',
                )
                as AiConfigSkill;

        final decoded =
            AiConfig.fromJson(
                  jsonDecode(jsonEncode(config.toJson()))
                      as Map<String, dynamic>,
                )
                as AiConfigSkill;

        expect(
          decoded.skillType,
          st,
          reason: 'SkillType.${st.name} should survive round-trip',
        );
      }
    });

    test('all ContextPolicy values survive round-trip', () {
      for (final cp in ContextPolicy.values) {
        final config =
            AiConfig.skill(
                  id: 'skill-cp-${cp.name}',
                  name: cp.name,
                  createdAt: DateTime.utc(2025),
                  skillType: SkillType.imageAnalysis,
                  requiredInputModalities: <Modality>[],
                  systemInstructions: 'S',
                  userInstructions: 'U',
                  contextPolicy: cp,
                )
                as AiConfigSkill;

        final decoded =
            AiConfig.fromJson(
                  jsonDecode(jsonEncode(config.toJson()))
                      as Map<String, dynamic>,
                )
                as AiConfigSkill;

        expect(
          decoded.contextPolicy,
          cp,
          reason: 'ContextPolicy.${cp.name} should survive round-trip',
        );
      }
    });

    test('AiConfigInferenceProfile with skillAssignments round-trips', () {
      final profile =
          AiConfig.inferenceProfile(
                id: 'prof-sa',
                name: 'Profile with skills',
                createdAt: DateTime.utc(2025),
                thinkingModelId: 'model-think',
                skillAssignments: const [
                  SkillAssignment(skillId: 'sk-1', automate: true),
                  SkillAssignment(skillId: 'sk-2'),
                ],
              )
              as AiConfigInferenceProfile;

      final decoded =
          AiConfig.fromJson(
                jsonDecode(jsonEncode(profile.toJson()))
                    as Map<String, dynamic>,
              )
              as AiConfigInferenceProfile;

      expect(decoded.skillAssignments.length, 2);
      expect(decoded.skillAssignments[0].skillId, 'sk-1');
      expect(decoded.skillAssignments[0].automate, isTrue);
      expect(decoded.skillAssignments[1].skillId, 'sk-2');
      expect(decoded.skillAssignments[1].automate, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // Glados property: JSON round-trip holds for all generated variants.
  // -------------------------------------------------------------------------

  glados.Glados(
    glados.any.inferenceProviderConfig,
    glados.ExploreConfig(numRuns: 120),
  ).test(
    'AiConfigInferenceProvider JSON encode→decode is identity',
    (config) {
      final decoded =
          AiConfig.fromJson(
                jsonDecode(jsonEncode(config.toJson())) as Map<String, dynamic>,
              )
              as AiConfigInferenceProvider;
      expect(decoded.id, config.id);
      expect(decoded.inferenceProviderType, config.inferenceProviderType);
      expect(decoded.baseUrl, config.baseUrl);
    },
    tags: 'glados',
  );

  glados.Glados(
    glados.any.aiConfigModelConfig,
    glados.ExploreConfig(numRuns: 120),
  ).test(
    'AiConfigModel JSON encode→decode is identity',
    (config) {
      final decoded =
          AiConfig.fromJson(
                jsonDecode(jsonEncode(config.toJson())) as Map<String, dynamic>,
              )
              as AiConfigModel;
      expect(decoded.id, config.id);
      expect(decoded.inputModalities, config.inputModalities);
      expect(decoded.outputModalities, config.outputModalities);
      expect(decoded.isReasoningModel, config.isReasoningModel);
    },
    tags: 'glados',
  );

  glados.Glados(
    glados.any.aiConfigPromptConfig,
    glados.ExploreConfig(numRuns: 120),
  ).test(
    'AiConfigPrompt JSON encode→decode is identity',
    (config) {
      final decoded =
          AiConfig.fromJson(
                jsonDecode(jsonEncode(config.toJson())) as Map<String, dynamic>,
              )
              as AiConfigPrompt;
      expect(decoded.id, config.id);
      expect(decoded.aiResponseType, config.aiResponseType);
      expect(decoded.useReasoning, config.useReasoning);
      expect(decoded.requiredInputData, config.requiredInputData);
      expect(decoded.defaultVariables, config.defaultVariables);
    },
    tags: 'glados',
  );

  glados.Glados(
    glados.any.aiConfigSkillConfig,
    glados.ExploreConfig(numRuns: 120),
  ).test(
    'AiConfigSkill JSON encode→decode is identity',
    (config) {
      final decoded =
          AiConfig.fromJson(
                jsonDecode(jsonEncode(config.toJson())) as Map<String, dynamic>,
              )
              as AiConfigSkill;
      expect(decoded.id, config.id);
      expect(decoded.skillType, config.skillType);
      expect(decoded.contextPolicy, config.contextPolicy);
      expect(decoded.useReasoning, config.useReasoning);
      expect(decoded.requiredInputModalities, config.requiredInputModalities);
    },
    tags: 'glados',
  );
}
