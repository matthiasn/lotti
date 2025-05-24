import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/ai_input.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/ai_input_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/ollama_repository.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'unified_ai_inference_repository.g.dart';

/// Repository for unified AI inference handling
/// This replaces the specialized controllers and provides a generic way
/// to run any configured AI prompt
class UnifiedAiInferenceRepository {
  UnifiedAiInferenceRepository(this.ref);

  final Ref ref;

  /// Get all active prompts that match the current context
  Future<List<AiConfigPrompt>> getActivePromptsForContext({
    required JournalEntity entity,
  }) async {
    final allPrompts = await ref
        .read(aiConfigRepositoryProvider)
        .getConfigsByType(AiConfigType.prompt);

    final activePrompts = allPrompts
        .whereType<AiConfigPrompt>()
        .where((prompt) => !prompt.archived)
        .where((prompt) => _isPromptActiveForEntity(prompt, entity))
        .toList();

    return activePrompts;
  }

  /// Check if a prompt is active for a given entity type
  bool _isPromptActiveForEntity(AiConfigPrompt prompt, JournalEntity entity) {
    // Check if prompt requires specific input data types
    for (final inputType in prompt.requiredInputData) {
      switch (inputType) {
        case InputDataType.task:
        case InputDataType.tasksList:
          if (entity is! Task) return false;
        case InputDataType.images:
          if (entity is! JournalImage) return false;
        case InputDataType.audioFiles:
          if (entity is! JournalAudio) return false;
      }
    }
    return true;
  }

  /// Run inference with a given prompt configuration
  Future<void> runInference({
    required String entityId,
    required AiConfigPrompt promptConfig,
    required void Function(String) onProgress,
    required void Function(InferenceStatus) onStatusChange,
  }) async {
    final start = DateTime.now();

    try {
      onStatusChange(InferenceStatus.running);

      // Get the entity
      final entity =
          await ref.read(aiInputRepositoryProvider).getEntity(entityId);
      if (entity == null) {
        throw Exception('Entity not found: $entityId');
      }

      // Get the model configuration
      final model = await ref
          .read(aiConfigRepositoryProvider)
          .getConfigById(promptConfig.defaultModelId) as AiConfigModel?;

      if (model == null) {
        throw Exception('Model not found: ${promptConfig.defaultModelId}');
      }

      // Get the inference provider
      final provider = await ref
              .read(aiConfigRepositoryProvider)
              .getConfigById(model.inferenceProviderId)
          as AiConfigInferenceProvider?;

      if (provider == null) {
        throw Exception('Provider not found: ${model.inferenceProviderId}');
      }

      // Build the prompt with the entity data
      final prompt = await _buildPromptWithData(
        promptConfig: promptConfig,
        entity: entity,
      );

      if (prompt == null) {
        throw Exception('Failed to build prompt');
      }

      // Prepare any additional data (images, audio)
      final images = await _prepareImages(promptConfig, entity);
      final audioBase64 = await _prepareAudio(promptConfig, entity);

      // Run the inference
      final buffer = StringBuffer();
      final useCloudInference =
          await getIt<JournalDb>().getConfigFlag(useCloudInferenceFlag);

      Stream<dynamic> stream;

      if (useCloudInference) {
        stream = await _runCloudInference(
          prompt: prompt,
          model: model,
          provider: provider,
          images: images,
          audioBase64: audioBase64,
          temperature: 0.6,
          systemMessage: promptConfig.systemMessage,
        );
      } else {
        stream = _runOllamaInference(
          prompt: prompt,
          model: model.providerModelId,
          images: images,
          temperature: 0.6,
        );
      }

      // Process the stream
      await for (final chunk in stream) {
        final text = _extractTextFromChunk(chunk);
        buffer.write(text);
        onProgress(buffer.toString());
      }

      // Process the complete response
      await _processCompleteResponse(
        response: buffer.toString(),
        promptConfig: promptConfig,
        model: model,
        prompt: prompt,
        entity: entity,
        start: start,
      );

      onStatusChange(InferenceStatus.idle);
    } catch (e) {
      onStatusChange(InferenceStatus.error);
      rethrow;
    }
  }

  /// Build prompt with entity data
  Future<String?> _buildPromptWithData({
    required AiConfigPrompt promptConfig,
    required JournalEntity entity,
  }) async {
    final aiInputRepo = ref.read(aiInputRepositoryProvider);
    final jsonString = await aiInputRepo.buildTaskDetailsJson(id: entity.id);
    final prompt = '${promptConfig.userMessage} \n $jsonString';
    return prompt;
  }

  /// Prepare images if required
  Future<List<String>> _prepareImages(
    AiConfigPrompt promptConfig,
    JournalEntity entity,
  ) async {
    if (!promptConfig.requiredInputData.contains(InputDataType.images)) {
      return [];
    }

    if (entity is! JournalImage) return [];

    final fullPath = getFullImagePath(entity);
    final bytes = await File(fullPath).readAsBytes();
    final base64String = base64Encode(bytes);

    return [base64String];
  }

  /// Prepare audio if required
  Future<String?> _prepareAudio(
    AiConfigPrompt promptConfig,
    JournalEntity entity,
  ) async {
    if (!promptConfig.requiredInputData.contains(InputDataType.audioFiles)) {
      return null;
    }

    if (entity is! JournalAudio) return null;

    final fullPath = await AudioUtils.getFullAudioPath(entity);
    final bytes = await File(fullPath).readAsBytes();
    return base64Encode(bytes);
  }

  /// Run cloud inference
  Future<Stream<CreateChatCompletionStreamResponse>> _runCloudInference({
    required String prompt,
    required String systemMessage,
    required AiConfigModel model,
    required AiConfigInferenceProvider provider,
    required List<String> images,
    required String? audioBase64,
    required double temperature,
  }) async {
    final cloudRepo = ref.read(cloudInferenceRepositoryProvider);

    if (audioBase64 != null) {
      return cloudRepo.generateWithAudio(
        prompt,
        model: model.providerModelId,
        audioBase64: audioBase64,
        baseUrl: provider.baseUrl,
        apiKey: provider.apiKey,
      );
    } else if (images.isNotEmpty) {
      return cloudRepo.generateWithImages(
        prompt,
        model: model.providerModelId,
        temperature: temperature,
        images: images,
        baseUrl: provider.baseUrl,
        apiKey: provider.apiKey,
      );
    } else {
      return cloudRepo.generate(
        prompt,
        model: model.providerModelId,
        temperature: temperature,
        baseUrl: provider.baseUrl,
        apiKey: provider.apiKey,
        systemMessage: systemMessage,
      );
    }
  }

  /// Run Ollama inference
  Stream<dynamic> _runOllamaInference({
    required String prompt,
    required String model,
    required List<String> images,
    required double temperature,
  }) {
    return ref.read(ollamaRepositoryProvider).generate(
          prompt,
          model: model,
          temperature: temperature,
          images: images.isNotEmpty ? images : null,
        );
  }

  /// Extract text from stream chunk
  String _extractTextFromChunk(dynamic chunk) {
    if (chunk is CreateChatCompletionStreamResponse) {
      return chunk.choices[0].delta.content ?? '';
    } else {
      // Assume Ollama response with text property
      try {
        final text = (chunk as dynamic).text;
        return text?.toString() ?? '';
      } catch (_) {
        return '';
      }
    }
  }

  /// Process complete response and create appropriate entry
  Future<void> _processCompleteResponse({
    required String response,
    required AiConfigPrompt promptConfig,
    required AiConfigModel model,
    required String prompt,
    required JournalEntity entity,
    required DateTime start,
  }) async {
    var thoughts = '';
    var cleanResponse = response;

    // Extract thoughts if present (for reasoning models)
    if (response.contains('</think>')) {
      final parts = response.split('</think>');
      if (parts.length == 2) {
        thoughts = parts[0];
        cleanResponse = parts[1];
      }
    }

    // Parse action items if this is an action item suggestions prompt
    List<AiActionItem>? suggestedActionItems;
    if (promptConfig.aiResponseType == AiResponseType.actionItemSuggestions) {
      try {
        final exp = RegExp(r'\[(.|\n)*\]', multiLine: true);
        final match = exp.firstMatch(cleanResponse)?.group(0) ?? '[]';
        final actionItemsJson = '{"items": $match}';
        final decoded = jsonDecode(actionItemsJson) as Map<String, dynamic>;
        suggestedActionItems = AiInputActionItemsList.fromJson(decoded).items;
      } catch (e) {
        // Failed to parse action items, continue without them
      }
    }

    // Create AI response data
    final data = AiResponseData(
      model: model.providerModelId,
      temperature: 0.6,
      systemMessage: promptConfig.systemMessage,
      prompt: prompt,
      thoughts: thoughts,
      response: cleanResponse,
      suggestedActionItems: suggestedActionItems,
      type: promptConfig.aiResponseType,
    );

    // Save the AI response entry
    await ref.read(aiInputRepositoryProvider).createAiResponseEntry(
          data: data,
          start: start,
          linkedId: entity.id,
          categoryId: entity is Task ? entity.categoryId : null,
        );

    // Handle special post-processing
    await _handlePostProcessing(
      entity: entity,
      promptConfig: promptConfig,
      response: cleanResponse,
    );
  }

  /// Handle any special post-processing based on response type
  Future<void> _handlePostProcessing({
    required JournalEntity entity,
    required AiConfigPrompt promptConfig,
    required String response,
  }) async {
    final journalRepo = ref.read(journalRepositoryProvider);

    switch (promptConfig.aiResponseType) {
      case AiResponseType.imageAnalysis:
        if (entity is JournalImage) {
          final completeResponse = '''
```
Disclaimer: the image analysis was generated by AI and may contain inaccuracies or errors.
```


$response
''';
          // Add text to image
          final updated = entity.copyWith(
            entryText: EntryText(
              plainText: completeResponse,
              markdown: completeResponse,
            ),
          );
          await journalRepo.updateJournalEntity(updated);
        }
      case AiResponseType.audioTranscription:
        if (entity is JournalAudio) {
          final transcript = AudioTranscript(
            created: DateTime.now(),
            library: 'AI Transcription',
            model: '-',
            detectedLanguage: '-',
            transcript: response.trim(),
            processingTime: DateTime.now().difference(DateTime.now()),
          );
          // Add transcript to audio
          final existingTranscripts = entity.data.transcripts ?? [];
          final updated = entity.copyWith(
            data: entity.data.copyWith(
              transcripts: [...existingTranscripts, transcript],
            ),
          );
          await journalRepo.updateJournalEntity(updated);
        }
      case AiResponseType.actionItemSuggestions:
      case AiResponseType.taskSummary:
    }
  }
}

@riverpod
UnifiedAiInferenceRepository unifiedAiInferenceRepository(Ref ref) {
  return UnifiedAiInferenceRepository(ref);
}
