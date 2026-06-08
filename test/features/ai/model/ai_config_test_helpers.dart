import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/consts.dart';

// ---------------------------------------------------------------------------
// Glados generators for AiConfig union-variant JSON round-trip properties.
// ---------------------------------------------------------------------------
extension AnyAiConfig on glados.Any {
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
  glados.Generator<List<T>> hSmallListOf<T>(glados.Generator<T> gen) =>
      glados.ListAnys(this).listWithLengthInRange(0, 3, gen);

  glados.Generator<AiConfigInferenceProvider> get inferenceProviderConfig =>
      glados.CombinableAny(this).combine3(
        _shortId,
        _shortId,
        _providerType,
        (id, name, pt) =>
            AiConfig.inferenceProvider(
                  id: id.isEmpty ? 'p' : id,
                  name: name.isEmpty ? 'n' : name,
                  baseUrl: 'https://example.com',
                  apiKey: 'sk-test',
                  createdAt: DateTime.utc(2025),
                  inferenceProviderType: pt,
                )
                as AiConfigInferenceProvider,
      );

  glados.Generator<AiConfigModel> get aiConfigModelConfig =>
      glados.CombinableAny(this).combine4(
        _shortId,
        hSmallListOf(_modality),
        hSmallListOf(_modality),
        glados.any.bool,
        (id, inMods, outMods, isReasoning) =>
            AiConfig.model(
                  id: id.isEmpty ? 'm' : id,
                  name: 'model-name',
                  providerModelId: 'gpt-4o',
                  inferenceProviderId: 'provider-1',
                  createdAt: DateTime.utc(2025),
                  inputModalities: inMods.isEmpty ? [Modality.text] : inMods,
                  outputModalities: outMods.isEmpty ? [Modality.text] : outMods,
                  isReasoningModel: isReasoning,
                )
                as AiConfigModel,
      );

  glados.Generator<AiConfigPrompt> get aiConfigPromptConfig =>
      glados.CombinableAny(this).combine4(
        _shortId,
        _responseType,
        glados.any.bool,
        hSmallListOf(_inputDataType),
        (id, rt, useReasoning, inputData) =>
            AiConfig.prompt(
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
                )
                as AiConfigPrompt,
      );

  glados.Generator<AiConfigSkill> get aiConfigSkillConfig =>
      glados.CombinableAny(this).combine4(
        _shortId,
        _skillType,
        hSmallListOf(_modality),
        _contextPolicy,
        (id, st, mods, cp) =>
            AiConfig.skill(
                  id: id.isEmpty ? 's' : id,
                  name: 'skill-name',
                  createdAt: DateTime.utc(2025),
                  skillType: st,
                  requiredInputModalities: mods,
                  systemInstructions: 'Do something useful.',
                  userInstructions: 'Apply the skill.',
                  contextPolicy: cp,
                )
                as AiConfigSkill,
      );
}
