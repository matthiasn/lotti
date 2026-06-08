import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';

enum GeneratedInferenceIdSlot { primary, secondary }

enum GeneratedInferenceResponseSlot {
  imageAnalysis,
  audioTranscription,
  promptGeneration,
  imagePromptGeneration,
  imageGeneration,
}

enum GeneratedInferenceStatusSlot { idle, running, error }

enum GeneratedInferenceResponseSetKind {
  empty,
  first,
  second,
  firstAndSecond,
  all,
}

String generatedInferenceId(GeneratedInferenceIdSlot slot) =>
    'generated-inference-${slot.name}';

AiResponseType generatedInferenceResponseType(
  GeneratedInferenceResponseSlot slot,
) {
  return switch (slot) {
    GeneratedInferenceResponseSlot.imageAnalysis =>
      AiResponseType.imageAnalysis,
    GeneratedInferenceResponseSlot.audioTranscription =>
      AiResponseType.audioTranscription,
    GeneratedInferenceResponseSlot.promptGeneration =>
      AiResponseType.promptGeneration,
    GeneratedInferenceResponseSlot.imagePromptGeneration =>
      AiResponseType.imagePromptGeneration,
    GeneratedInferenceResponseSlot.imageGeneration =>
      AiResponseType.imageGeneration,
  };
}

InferenceStatus generatedInferenceStatus(
  GeneratedInferenceStatusSlot slot,
) {
  return switch (slot) {
    GeneratedInferenceStatusSlot.idle => InferenceStatus.idle,
    GeneratedInferenceStatusSlot.running => InferenceStatus.running,
    GeneratedInferenceStatusSlot.error => InferenceStatus.error,
  };
}

class GeneratedInferenceOperation {
  const GeneratedInferenceOperation({
    required this.idSlot,
    required this.responseSlot,
    required this.statusSlot,
  });

  final GeneratedInferenceIdSlot idSlot;
  final GeneratedInferenceResponseSlot responseSlot;
  final GeneratedInferenceStatusSlot statusSlot;

  String get id => generatedInferenceId(idSlot);

  AiResponseType get responseType => generatedInferenceResponseType(
    responseSlot,
  );

  InferenceStatus get status => generatedInferenceStatus(statusSlot);

  @override
  String toString() {
    return 'GeneratedInferenceOperation('
        'idSlot: $idSlot, responseSlot: $responseSlot, '
        'statusSlot: $statusSlot)';
  }
}

class GeneratedInferenceScenario {
  const GeneratedInferenceScenario({
    required this.responseSetKind,
    required this.operations,
  });

  final GeneratedInferenceResponseSetKind responseSetKind;
  final List<GeneratedInferenceOperation> operations;

  Set<AiResponseType> get responseTypes {
    final generatedTypes = GeneratedInferenceResponseSlot.values
        .map(generatedInferenceResponseType)
        .toList();

    return switch (responseSetKind) {
      GeneratedInferenceResponseSetKind.empty => <AiResponseType>{},
      GeneratedInferenceResponseSetKind.first => {generatedTypes.first},
      GeneratedInferenceResponseSetKind.second => {generatedTypes[1]},
      GeneratedInferenceResponseSetKind.firstAndSecond => {
        generatedTypes.first,
        generatedTypes[1],
      },
      GeneratedInferenceResponseSetKind.all => generatedTypes.toSet(),
    };
  }

  @override
  String toString() {
    return 'GeneratedInferenceScenario('
        'responseSetKind: $responseSetKind, operations: $operations)';
  }
}

extension AnyGeneratedInferenceScenario on glados.Any {
  glados.Generator<GeneratedInferenceIdSlot> get inferenceIdSlot =>
      glados.AnyUtils(this).choose(GeneratedInferenceIdSlot.values);

  glados.Generator<GeneratedInferenceResponseSlot> get inferenceResponseSlot =>
      glados.AnyUtils(this).choose(GeneratedInferenceResponseSlot.values);

  glados.Generator<GeneratedInferenceStatusSlot> get inferenceStatusSlot =>
      glados.AnyUtils(this).choose(GeneratedInferenceStatusSlot.values);

  glados.Generator<GeneratedInferenceResponseSetKind>
  get inferenceResponseSetKind => glados.AnyUtils(
    this,
  ).choose(GeneratedInferenceResponseSetKind.values);

  glados.Generator<GeneratedInferenceOperation> get inferenceOperation =>
      glados.CombinableAny(this).combine3(
        inferenceIdSlot,
        inferenceResponseSlot,
        inferenceStatusSlot,
        (
          GeneratedInferenceIdSlot idSlot,
          GeneratedInferenceResponseSlot responseSlot,
          GeneratedInferenceStatusSlot statusSlot,
        ) => GeneratedInferenceOperation(
          idSlot: idSlot,
          responseSlot: responseSlot,
          statusSlot: statusSlot,
        ),
      );

  glados.Generator<GeneratedInferenceScenario> get inferenceScenario =>
      glados.CombinableAny(this).combine2(
        inferenceResponseSetKind,
        glados.ListAnys(this).listWithLengthInRange(
          0,
          55,
          inferenceOperation,
        ),
        (
          GeneratedInferenceResponseSetKind responseSetKind,
          List<GeneratedInferenceOperation> operations,
        ) => GeneratedInferenceScenario(
          responseSetKind: responseSetKind,
          operations: operations,
        ),
      );
}
