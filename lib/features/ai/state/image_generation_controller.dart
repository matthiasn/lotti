import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/helpers/prompt_builder_helper.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/ai_input_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/features/ai/util/preconfigured_prompts.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'image_generation_controller.freezed.dart';
part 'image_generation_controller.g.dart';

/// State for image generation operations.
@freezed
sealed class ImageGenerationState with _$ImageGenerationState {
  const factory ImageGenerationState.initial() = ImageGenerationInitial;

  const factory ImageGenerationState.generating({
    required String prompt,
  }) = ImageGenerationGenerating;

  const factory ImageGenerationState.success({
    required String prompt,
    required Uint8List imageBytes,
    required String mimeType,
  }) = ImageGenerationSuccess;

  const factory ImageGenerationState.error({
    required String prompt,
    required String errorMessage,
  }) = ImageGenerationError;
}

/// Parameters for the image generation controller.
typedef ImageGenerationParams = ({String entityId});

/// Controller for generating cover art images using AI.
///
/// This controller manages the state of image generation, including:
/// - Building prompts from task context and audio descriptions
/// - Calling the Gemini image generation API
/// - Managing generation state (idle, generating, success, error)
@riverpod
class ImageGenerationController extends _$ImageGenerationController {
  @override
  ImageGenerationState build({required String entityId}) {
    return const ImageGenerationState.initial();
  }

  /// Generates a cover art image by building the prompt from entity context.
  ///
  /// This method uses [PromptBuilderHelper] to build a full prompt with:
  /// - `{{task}}` - Full task JSON (title, status, checklists, labels, etc.)
  /// - `{{audioTranscript}}` - User's voice description
  ///
  /// Parameters:
  /// - [audioEntityId]: The ID of the audio entry containing the voice description.
  Future<void> generateImageFromEntity({
    required String audioEntityId,
  }) async {
    final loggingService = getIt<LoggingService>();

    try {
      // Get the audio entity
      final journalRepository = ref.read(journalRepositoryProvider);
      final entity =
          await journalRepository.getJournalEntityById(audioEntityId);

      if (entity == null) {
        throw Exception('Audio entity not found: $audioEntityId');
      }

      if (entity is! JournalAudio) {
        throw Exception(
          'Expected JournalAudio but got ${entity.runtimeType}',
        );
      }

      // Build the prompt using PromptBuilderHelper for full context
      final promptBuilderHelper = _createPromptBuilderHelper();
      final promptConfig = _createPromptConfigFromPreconfigured();

      final prompt = await promptBuilderHelper.buildPromptWithData(
        promptConfig: promptConfig,
        entity: entity,
      );

      if (prompt == null || prompt.isEmpty) {
        throw Exception('Failed to build prompt from entity context');
      }

      developer.log(
        'Built prompt from entity context (${prompt.length} chars)',
        name: 'ImageGenerationController',
      );

      // Generate the image with the built prompt
      await generateImage(prompt: prompt);
    } catch (e, stackTrace) {
      developer.log(
        'Image generation from entity failed: $e',
        name: 'ImageGenerationController',
        error: e,
        stackTrace: stackTrace,
      );

      loggingService.captureException(
        e,
        domain: 'ImageGenerationController',
        subDomain: 'generateImageFromEntity',
        stackTrace: stackTrace,
      );

      state = ImageGenerationState.error(
        prompt: '[Failed to build prompt]',
        errorMessage: e.toString(),
      );
    }
  }

  /// Generates a cover art image from the given prompt.
  ///
  /// Use [generateImageFromEntity] to build prompts with full context.
  /// This method is used for retries or when using an edited prompt.
  Future<void> generateImage({
    required String prompt,
    String? systemMessage,
  }) async {
    final loggingService = getIt<LoggingService>();

    try {
      state = ImageGenerationState.generating(prompt: prompt);

      developer.log(
        'Starting image generation for entity $entityId',
        name: 'ImageGenerationController',
      );

      // Get the Gemini provider with image generation capability
      final provider = await _getImageGenerationProvider();
      if (provider == null) {
        throw Exception('No Gemini provider configured for image generation');
      }

      // Get the image generation model
      final model = _getImageGenerationModel();
      if (model == null) {
        throw Exception('Image generation model not found');
      }

      // Get the system message from the preconfigured prompt if not provided
      final effectiveSystemMessage =
          systemMessage ?? coverArtGenerationPrompt.systemMessage;

      // Generate the image using the cloud inference repository
      final cloudRepo = ref.read(cloudInferenceRepositoryProvider);
      final generatedImage = await cloudRepo.generateImage(
        prompt: prompt,
        model: model.providerModelId,
        provider: provider,
        systemMessage: effectiveSystemMessage,
      );

      developer.log(
        'Image generation completed: ${generatedImage.bytes.length} bytes, '
        'mimeType: ${generatedImage.mimeType}',
        name: 'ImageGenerationController',
      );

      state = ImageGenerationState.success(
        prompt: prompt,
        imageBytes: Uint8List.fromList(generatedImage.bytes),
        mimeType: generatedImage.mimeType,
      );
    } catch (e, stackTrace) {
      developer.log(
        'Image generation failed: $e',
        name: 'ImageGenerationController',
        error: e,
        stackTrace: stackTrace,
      );

      loggingService.captureException(
        e,
        domain: 'ImageGenerationController',
        subDomain: 'generateImage',
        stackTrace: stackTrace,
      );

      state = ImageGenerationState.error(
        prompt: prompt,
        errorMessage: e.toString(),
      );
    }
  }

  /// Retries image generation with the current or a modified prompt.
  Future<void> retryGeneration({String? modifiedPrompt}) async {
    final currentPrompt = state.map(
      initial: (_) => null,
      generating: (s) => s.prompt,
      success: (s) => s.prompt,
      error: (s) => s.prompt,
    );

    final promptToUse = modifiedPrompt ?? currentPrompt;
    if (promptToUse == null) {
      throw Exception('No prompt available for retry');
    }

    await generateImage(prompt: promptToUse);
  }

  /// Resets the controller to its initial state.
  void reset() {
    state = const ImageGenerationState.initial();
  }

  /// Gets the first available Gemini provider for image generation.
  /// Uses repository directly to avoid autoDispose provider lifecycle issues.
  Future<AiConfigInferenceProvider?> _getImageGenerationProvider() async {
    final repository = ref.read(aiConfigRepositoryProvider);
    final providers =
        await repository.getConfigsByType(AiConfigType.inferenceProvider);

    return providers.whereType<AiConfigInferenceProvider>().firstWhere(
          (p) => p.inferenceProviderType == InferenceProviderType.gemini,
          orElse: () => throw Exception('No Gemini provider found'),
        );
  }

  /// Gets the image generation model (Nano Banana Pro).
  KnownModel? _getImageGenerationModel() {
    return geminiModels.firstWhere(
      (m) => m.outputModalities.contains(Modality.image),
      orElse: () => throw Exception('No image generation model found'),
    );
  }

  /// Creates a PromptBuilderHelper with all required repositories.
  PromptBuilderHelper _createPromptBuilderHelper() {
    return PromptBuilderHelper(
      aiInputRepository: ref.read(aiInputRepositoryProvider),
      journalRepository: ref.read(journalRepositoryProvider),
      checklistRepository: ref.read(checklistRepositoryProvider),
      labelsRepository: ref.read(labelsRepositoryProvider),
    );
  }

  /// Creates an AiConfigPrompt from the preconfigured cover art prompt.
  ///
  /// This allows us to use the PromptBuilderHelper infrastructure
  /// for placeholder substitution.
  AiConfigPrompt _createPromptConfigFromPreconfigured() {
    const preconfigured = coverArtGenerationPrompt;
    return AiConfigPrompt(
      id: preconfigured.id,
      name: preconfigured.name,
      systemMessage: preconfigured.systemMessage,
      userMessage: preconfigured.userMessage,
      defaultModelId: '', // Not used for prompt building
      modelIds: const [],
      createdAt: DateTime.now(),
      useReasoning: preconfigured.useReasoning,
      requiredInputData: preconfigured.requiredInputData,
      aiResponseType: preconfigured.aiResponseType,
      description: preconfigured.description,
      // Enable tracking to use the preconfigured prompt text
      trackPreconfigured: true,
      preconfiguredPromptId: preconfigured.id,
    );
  }
}
