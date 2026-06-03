import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/skill_assignment.dart';
import 'package:lotti/features/ai/state/consts.dart';

// ---------------------------------------------------------------------------
// Glados generators for AiConfig union-variant JSON round-trip properties.
// ---------------------------------------------------------------------------
extension _AnyAiConfig on glados.Any {
  glados.Generator<String> get _shortId =>
      glados.any.stringOf('abcdefghijklmnopqrstuvwxyz0123456789-');

  glados.Generator<InferenceProviderType> get _providerType =>
      glados.AnyUtils(this).choose(InferenceProviderType.values);

  glados.Generator<Modality> get _modality =>
      glados.AnyUtils(this).choose(Modality.values);

  glados.Generator<AiResponseType> get _responseType =>
      glados.AnyUtils(this).choose(AiResponseType.values);

  glados.Generator<InputDataType> get _inputDataType =>
      glados.AnyUtils(this).choose(InputDataType.values);

  glados.Generator<SkillType> get _skillType =>
      glados.AnyUtils(this).choose(SkillType.values);

  glados.Generator<ContextPolicy> get _contextPolicy =>
      glados.AnyUtils(this).choose(ContextPolicy.values);

  /// Produces a small list (0–3 elements) drawn from [gen].
  glados.Generator<List<T>> _smallListOf<T>(glados.Generator<T> gen) =>
      glados.ListAnys(this).listWithLengthInRange(0, 3, gen);

  glados.Generator<AiConfigInferenceProvider> get inferenceProviderConfig =>
      glados.CombinableAny(this).combine3(
        _shortId,
        _shortId,
        _providerType,
        (id, name, pt) => AiConfig.inferenceProvider(
          id: id.isEmpty ? 'p' : id,
          name: name.isEmpty ? 'n' : name,
          baseUrl: 'https://example.com',
          apiKey: 'sk-test',
          createdAt: DateTime.utc(2025),
          inferenceProviderType: pt,
        ) as AiConfigInferenceProvider,
      );

  glados.Generator<AiConfigModel> get aiConfigModelConfig =>
      glados.CombinableAny(this).combine4(
        _shortId,
        _smallListOf(_modality),
        _smallListOf(_modality),
        glados.any.bool,
        (id, inMods, outMods, isReasoning) => AiConfig.model(
          id: id.isEmpty ? 'm' : id,
          name: 'model-name',
          providerModelId: 'gpt-4o',
          inferenceProviderId: 'provider-1',
          createdAt: DateTime.utc(2025),
          inputModalities: inMods.isEmpty ? [Modality.text] : inMods,
          outputModalities: outMods.isEmpty ? [Modality.text] : outMods,
          isReasoningModel: isReasoning,
        ) as AiConfigModel,
      );

  glados.Generator<AiConfigPrompt> get aiConfigPromptConfig =>
      glados.CombinableAny(this).combine4(
        _shortId,
        _responseType,
        glados.any.bool,
        _smallListOf(_inputDataType),
        (id, rt, useReasoning, inputData) => AiConfig.prompt(
          id: id.isEmpty ? 'q' : id,
          name: 'prompt-name',
          systemMessage: 'You are a helpful assistant.',
          userMessage: 'Summarise this.',
          defaultModelId: 'model-1',
          modelIds: <String>['model-1'],
          createdAt: DateTime.utc(2025),
          useReasoning: useReasoning,
          requiredInputData: inputData,
          aiResponseType: rt,
        ) as AiConfigPrompt,
      );

  glados.Generator<AiConfigSkill> get aiConfigSkillConfig =>
      glados.CombinableAny(this).combine4(
        _shortId,
        _skillType,
        _smallListOf(_modality),
        _contextPolicy,
        (id, st, mods, cp) => AiConfig.skill(
          id: id.isEmpty ? 's' : id,
          name: 'skill-name',
          createdAt: DateTime.utc(2025),
          skillType: st,
          requiredInputModalities: mods,
          systemInstructions: 'Do something useful.',
          userInstructions: 'Apply the skill.',
          contextPolicy: cp,
        ) as AiConfigSkill,
      );
}

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
      final config = AiConfig.inferenceProvider(
        id: 'prov-1',
        name: 'My Provider',
        baseUrl: 'https://api.example.com',
        apiKey: 'sk-abc',
        createdAt: DateTime.utc(2025, 6),
        inferenceProviderType: InferenceProviderType.openAi,
      ) as AiConfigInferenceProvider;

      final decoded = AiConfig.fromJson(
        jsonDecode(jsonEncode(config.toJson())) as Map<String, dynamic>,
      ) as AiConfigInferenceProvider;

      expect(decoded.id, config.id);
      expect(decoded.name, config.name);
      expect(decoded.baseUrl, config.baseUrl);
      expect(decoded.apiKey, config.apiKey);
      expect(decoded.inferenceProviderType, config.inferenceProviderType);
      expect(decoded.createdAt, config.createdAt);
    });

    test('round-trips optional description', () {
      final config = AiConfig.inferenceProvider(
        id: 'prov-2',
        name: 'Annotated',
        baseUrl: 'https://api.example.com',
        apiKey: 'sk-xyz',
        createdAt: DateTime.utc(2025),
        inferenceProviderType: InferenceProviderType.gemini,
        description: 'My favourite provider',
      ) as AiConfigInferenceProvider;

      final decoded = AiConfig.fromJson(
        jsonDecode(jsonEncode(config.toJson())) as Map<String, dynamic>,
      ) as AiConfigInferenceProvider;

      expect(decoded.description, 'My favourite provider');
    });

    test('all InferenceProviderType values survive round-trip', () {
      for (final pt in InferenceProviderType.values) {
        final config = AiConfig.inferenceProvider(
          id: 'prov-${pt.name}',
          name: pt.name,
          baseUrl: 'https://example.com',
          apiKey: 'k',
          createdAt: DateTime.utc(2025),
          inferenceProviderType: pt,
        ) as AiConfigInferenceProvider;

        final decoded = AiConfig.fromJson(
          jsonDecode(jsonEncode(config.toJson())) as Map<String, dynamic>,
        ) as AiConfigInferenceProvider;

        expect(decoded.inferenceProviderType, pt,
            reason: 'provider type ${pt.name} should survive round-trip');
      }
    });
  });

  group('AiConfigModel JSON round-trip', () {
    test('round-trips with multi-modal fields', () {
      final config = AiConfig.model(
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
      ) as AiConfigModel;

      final decoded = AiConfig.fromJson(
        jsonDecode(jsonEncode(config.toJson())) as Map<String, dynamic>,
      ) as AiConfigModel;

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
      final config = AiConfig.model(
        id: 'model-2',
        name: 'Small Model',
        providerModelId: 'small',
        inferenceProviderId: 'prov-1',
        createdAt: DateTime.utc(2025),
        inputModalities: [Modality.text],
        outputModalities: [Modality.text],
        isReasoningModel: false,
      ) as AiConfigModel;

      final decoded = AiConfig.fromJson(
        jsonDecode(jsonEncode(config.toJson())) as Map<String, dynamic>,
      ) as AiConfigModel;

      expect(decoded.maxCompletionTokens, isNull);
    });

    test('all Modality values survive round-trip', () {
      const modalities = Modality.values;
      final config = AiConfig.model(
        id: 'model-3',
        name: 'All Modalities',
        providerModelId: 'all',
        inferenceProviderId: 'prov-1',
        createdAt: DateTime.utc(2025),
        inputModalities: modalities,
        outputModalities: modalities,
        isReasoningModel: false,
      ) as AiConfigModel;

      final decoded = AiConfig.fromJson(
        jsonDecode(jsonEncode(config.toJson())) as Map<String, dynamic>,
      ) as AiConfigModel;

      expect(decoded.inputModalities, modalities);
      expect(decoded.outputModalities, modalities);
    });
  });

  group('AiConfigPrompt JSON round-trip', () {
    test('round-trips required fields', () {
      final config = AiConfig.prompt(
        id: 'prompt-1',
        name: 'Task Summary',
        systemMessage: 'You are a summariser.',
        userMessage: 'Summarise the task.',
        defaultModelId: 'model-1',
        modelIds: ['model-1', 'model-2'],
        createdAt: DateTime.utc(2025, 4),
        useReasoning: false,
        requiredInputData: [InputDataType.task],
        aiResponseType: AiResponseType.taskSummary, // ignore: deprecated_member_use_from_same_package
      ) as AiConfigPrompt;

      final decoded = AiConfig.fromJson(
        jsonDecode(jsonEncode(config.toJson())) as Map<String, dynamic>,
      ) as AiConfigPrompt;

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
      final withVars = AiConfig.prompt(
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
      ) as AiConfigPrompt;

      final decoded = AiConfig.fromJson(
        jsonDecode(jsonEncode(withVars.toJson())) as Map<String, dynamic>,
      ) as AiConfigPrompt;

      expect(decoded.defaultVariables, <String, String>{'lang': 'en', 'style': 'concise'});
    });

    test('null defaultVariables survives round-trip as null', () {
      final noVars = AiConfig.prompt(
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
      ) as AiConfigPrompt;

      final decoded = AiConfig.fromJson(
        jsonDecode(jsonEncode(noVars.toJson())) as Map<String, dynamic>,
      ) as AiConfigPrompt;

      expect(decoded.defaultVariables, isNull);
    });

    test('all AiResponseType values survive round-trip', () {
      for (final rt in AiResponseType.values) {
        final config = AiConfig.prompt(
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
        ) as AiConfigPrompt;

        final decoded = AiConfig.fromJson(
          jsonDecode(jsonEncode(config.toJson())) as Map<String, dynamic>,
        ) as AiConfigPrompt;

        expect(decoded.aiResponseType, rt,
            reason: 'AiResponseType.${rt.name} should survive round-trip');
      }
    });
  });

  group('AiConfigSkill JSON round-trip', () {
    test('round-trips required fields', () {
      final config = AiConfig.skill(
        id: 'skill-1',
        name: 'Transcription',
        createdAt: DateTime.utc(2025, 2),
        skillType: SkillType.transcription,
        requiredInputModalities: [Modality.audio],
        systemInstructions: 'Transcribe the audio.',
        userInstructions: 'Please transcribe.',
        contextPolicy: ContextPolicy.dictionaryOnly,
      ) as AiConfigSkill;

      final decoded = AiConfig.fromJson(
        jsonDecode(jsonEncode(config.toJson())) as Map<String, dynamic>,
      ) as AiConfigSkill;

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
        final config = AiConfig.skill(
          id: 'skill-${st.name}',
          name: st.name,
          createdAt: DateTime.utc(2025),
          skillType: st,
          requiredInputModalities: <Modality>[],
          systemInstructions: 'S',
          userInstructions: 'U',
        ) as AiConfigSkill;

        final decoded = AiConfig.fromJson(
          jsonDecode(jsonEncode(config.toJson())) as Map<String, dynamic>,
        ) as AiConfigSkill;

        expect(decoded.skillType, st,
            reason: 'SkillType.${st.name} should survive round-trip');
      }
    });

    test('all ContextPolicy values survive round-trip', () {
      for (final cp in ContextPolicy.values) {
        final config = AiConfig.skill(
          id: 'skill-cp-${cp.name}',
          name: cp.name,
          createdAt: DateTime.utc(2025),
          skillType: SkillType.imageAnalysis,
          requiredInputModalities: <Modality>[],
          systemInstructions: 'S',
          userInstructions: 'U',
          contextPolicy: cp,
        ) as AiConfigSkill;

        final decoded = AiConfig.fromJson(
          jsonDecode(jsonEncode(config.toJson())) as Map<String, dynamic>,
        ) as AiConfigSkill;

        expect(decoded.contextPolicy, cp,
            reason: 'ContextPolicy.${cp.name} should survive round-trip');
      }
    });

    test('AiConfigInferenceProfile with skillAssignments round-trips', () {
      final profile = AiConfig.inferenceProfile(
        id: 'prof-sa',
        name: 'Profile with skills',
        createdAt: DateTime.utc(2025),
        thinkingModelId: 'model-think',
        skillAssignments: const [
          SkillAssignment(skillId: 'sk-1', automate: true),
          SkillAssignment(skillId: 'sk-2'),
        ],
      ) as AiConfigInferenceProfile;

      final decoded = AiConfig.fromJson(
        jsonDecode(jsonEncode(profile.toJson())) as Map<String, dynamic>,
      ) as AiConfigInferenceProfile;

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
      final decoded = AiConfig.fromJson(
        jsonDecode(jsonEncode(config.toJson())) as Map<String, dynamic>,
      ) as AiConfigInferenceProvider;
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
      final decoded = AiConfig.fromJson(
        jsonDecode(jsonEncode(config.toJson())) as Map<String, dynamic>,
      ) as AiConfigModel;
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
      final decoded = AiConfig.fromJson(
        jsonDecode(jsonEncode(config.toJson())) as Map<String, dynamic>,
      ) as AiConfigPrompt;
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
      final decoded = AiConfig.fromJson(
        jsonDecode(jsonEncode(config.toJson())) as Map<String, dynamic>,
      ) as AiConfigSkill;
      expect(decoded.id, config.id);
      expect(decoded.skillType, config.skillType);
      expect(decoded.contextPolicy, config.contextPolicy);
      expect(decoded.useReasoning, config.useReasoning);
      expect(decoded.requiredInputModalities, config.requiredInputModalities);
    },
    tags: 'glados',
  );
}
