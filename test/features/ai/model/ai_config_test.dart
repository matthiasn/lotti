import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';

void main() {
  // --- Mock Data Setup ---

  // Basic text-only model, not for reasoning
  final textModel = AiConfigModel(
    id: 'text-basic',
    name: 'Text Basic',
    inferenceProviderId: 'p1',
    inputModalities: [Modality.text],
    outputModalities: [Modality.text],
    isReasoningModel: false,
    createdAt: DateTime.now(),
  );

  // Reasoning model, supports text and images
  final reasoningTextImageModel = AiConfigModel(
    id: 'reason-text-img',
    name: 'Reason Text Image',
    inferenceProviderId: 'p2',
    inputModalities: [Modality.text, Modality.image],
    outputModalities: [Modality.text],
    isReasoningModel: true,
    createdAt: DateTime.now(),
  );

  // Non-reasoning model, supports text, image, audio
  final multiModalNonReasoningModel = AiConfigModel(
    id: 'multi-no-reason',
    name: 'Multi Modal Non Reason',
    inferenceProviderId: 'p1',
    inputModalities: [Modality.text, Modality.image, Modality.audio],
    outputModalities: [Modality.text, Modality.audio],
    isReasoningModel: false,
    createdAt: DateTime.now(),
  );

  // Reasoning model, supports text, image, audio
  final fullMultiModalReasoningModel = AiConfigModel(
    id: 'multi-reason',
    name: 'Full Multi Modal Reason',
    inferenceProviderId: 'p2',
    inputModalities: [Modality.text, Modality.image, Modality.audio],
    outputModalities: [Modality.text, Modality.audio],
    isReasoningModel: true,
    createdAt: DateTime.now(),
  );

  // --- Test Groups ---

  group('isModelSuitableForPrompt', () {
    test('should return true for basic text prompt and text model', () {
      final prompt = AiConfigPrompt(
        id: 'p1',
        name: 'Basic Question',
        modelId: '', // Not relevant for this function
        template: 'What is Flutter?',
        requiredInputData: [], // No specific data types needed
        useReasoning: false, createdAt: DateTime.now(),
      );
      expect(
        isModelSuitableForPrompt(prompt: prompt, model: textModel),
        isTrue,
      );
      // Also suitable for more capable models
      expect(
        isModelSuitableForPrompt(
          prompt: prompt,
          model: reasoningTextImageModel,
        ),
        isTrue,
      );
      expect(
        isModelSuitableForPrompt(
          prompt: prompt,
          model: fullMultiModalReasoningModel,
        ),
        isTrue,
      );
    });

    test(
        'should return false if prompt requires reasoning but model does not support it',
        () {
      final prompt = AiConfigPrompt(
        id: 'p2',
        name: 'Analyze deeply',
        modelId: '',
        template: 'Deduce the meaning...',
        requiredInputData: [],
        useReasoning: true, // Requires reasoning
        createdAt: DateTime.now(),
      );
      expect(
        isModelSuitableForPrompt(prompt: prompt, model: textModel),
        isFalse,
      ); // textModel is not reasoning
      expect(
        isModelSuitableForPrompt(
          prompt: prompt,
          model: multiModalNonReasoningModel,
        ),
        isFalse,
      );
    });

    test(
        'should return true if prompt requires reasoning and model supports it',
        () {
      final prompt = AiConfigPrompt(
        id: 'p3',
        name: 'Analyze deeply',
        modelId: '',
        template: 'Deduce the meaning...',
        requiredInputData: [],
        useReasoning: true,
        createdAt: DateTime.now(),
      );
      expect(
        isModelSuitableForPrompt(
          prompt: prompt,
          model: reasoningTextImageModel,
        ),
        isTrue,
      );
      expect(
        isModelSuitableForPrompt(
          prompt: prompt,
          model: fullMultiModalReasoningModel,
        ),
        isTrue,
      );
    });

    test(
        'should return true if prompt does not require reasoning, regardless of model capability',
        () {
      final prompt = AiConfigPrompt(
        id: 'p4',
        name: 'Simple Summary',
        modelId: '',
        template: 'Summarize this.',
        requiredInputData: [],
        useReasoning: false, // Does NOT require reasoning

        createdAt: DateTime.now(),
      );
      expect(
        isModelSuitableForPrompt(prompt: prompt, model: textModel),
        isTrue,
      ); // Non-reasoning OK
      expect(
        isModelSuitableForPrompt(
          prompt: prompt,
          model: reasoningTextImageModel,
        ),
        isTrue,
      ); // Reasoning OK too
    });

    test(
        'should return false if prompt requires image input but model does not support it',
        () {
      final prompt = AiConfigPrompt(
        id: 'p5',
        name: 'Describe Image',
        modelId: '',
        template: 'Describe the attached image.',
        requiredInputData: [InputDataType.images], // Needs image input
        useReasoning: false,
        createdAt: DateTime.now(),
      );
      expect(
        isModelSuitableForPrompt(prompt: prompt, model: textModel),
        isFalse,
      ); // textModel only supports text
    });

    test(
        'should return true if prompt requires image input and model supports it',
        () {
      final prompt = AiConfigPrompt(
        id: 'p6',
        name: 'Describe Image',
        modelId: '',
        template: 'Describe the attached image.',
        requiredInputData: [InputDataType.images],
        useReasoning: false,
        createdAt: DateTime.now(),
      );
      expect(
        isModelSuitableForPrompt(
          prompt: prompt,
          model: reasoningTextImageModel,
        ),
        isTrue,
      );
      expect(
        isModelSuitableForPrompt(
          prompt: prompt,
          model: fullMultiModalReasoningModel,
        ),
        isTrue,
      );
    });

    test(
        'should return false if prompt requires audio and text input but model only supports text',
        () {
      final prompt = AiConfigPrompt(
        id: 'p7',
        name: 'Transcribe and Summarize',
        modelId: '',
        template: 'Transcribe the audio and summarize the text.',
        // Requires both task (text) and audioFiles (audio)
        requiredInputData: [InputDataType.task, InputDataType.audioFiles],
        useReasoning: false,
        createdAt: DateTime.now(),
      );
      // reasoningTextImageModel supports Text and Image, but not Audio
      expect(
        isModelSuitableForPrompt(
          prompt: prompt,
          model: reasoningTextImageModel,
        ),
        isFalse,
      );
      // textModel only supports Text
      expect(
        isModelSuitableForPrompt(prompt: prompt, model: textModel),
        isFalse,
      );
    });

    test(
        'should return true if prompt requires audio and task list input and model supports audio and text',
        () {
      final prompt = AiConfigPrompt(
        id: 'p8',
        name: 'Process Audio and Tasks',
        modelId: '',
        template: 'Based on the audio and the task list...',
        requiredInputData: [
          InputDataType.audioFiles,
          InputDataType.tasksList,
        ], // Needs audio, needs text (for tasksList)
        useReasoning: false,

        createdAt: DateTime.now(),
      );
      // These models support both text and audio
      expect(
        isModelSuitableForPrompt(
          prompt: prompt,
          model: multiModalNonReasoningModel,
        ),
        isTrue,
      );
      expect(
        isModelSuitableForPrompt(
          prompt: prompt,
          model: fullMultiModalReasoningModel,
        ),
        isTrue,
      );
    });

    test('should return true if model supports more modalities than required',
        () {
      final prompt = AiConfigPrompt(
        id: 'p9',
        name: 'Describe Image (Reasoning)',
        modelId: '',
        template: 'Analyze and describe the attached image.',
        requiredInputData: [
          InputDataType.images,
        ], // Only needs image input explicitly
        useReasoning: true, // Requires reasoning

        createdAt: DateTime.now(),
      );
      // fullMultiModalReasoningModel supports text, image, audio AND reasoning
      expect(
        isModelSuitableForPrompt(
          prompt: prompt,
          model: fullMultiModalReasoningModel,
        ),
        isTrue,
      );
    });

    test(
        'should return false if complex requirements (reasoning + modalities) are not met',
        () {
      final prompt = AiConfigPrompt(
        id: 'p10',
        name: 'Analyze Audio and Image',
        modelId: '',
        template: 'Analyze the relationship between the audio and the image.',
        requiredInputData: [
          InputDataType.audioFiles,
          InputDataType.images,
        ], // Needs audio & image
        useReasoning: true, // Needs reasoning

        createdAt: DateTime.now(),
      );
      // reasoningTextImageModel has reasoning and image, but LACKS AUDIO
      expect(
        isModelSuitableForPrompt(
          prompt: prompt,
          model: reasoningTextImageModel,
        ),
        isFalse,
      );
      // multiModalNonReasoningModel has audio and image, but LACKS REASONING
      expect(
        isModelSuitableForPrompt(
          prompt: prompt,
          model: multiModalNonReasoningModel,
        ),
        isFalse,
      );
      // textModel lacks everything required
      expect(
        isModelSuitableForPrompt(prompt: prompt, model: textModel),
        isFalse,
      );
    });

    test(
        'should return true if complex requirements (reasoning + modalities) are met',
        () {
      final prompt = AiConfigPrompt(
        id: 'p11',
        name: 'Analyze Audio and Image',
        modelId: '',
        template: 'Analyze the relationship between the audio and the image.',
        requiredInputData: [InputDataType.audioFiles, InputDataType.images],
        useReasoning: true,
        createdAt: DateTime.now(),
      );
      // fullMultiModalReasoningModel has everything needed
      expect(
        isModelSuitableForPrompt(
          prompt: prompt,
          model: fullMultiModalReasoningModel,
        ),
        isTrue,
      );
    });
  });
}
