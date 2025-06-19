import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/ai_input.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/ai_input_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'unified_ai_inference_repository.g.dart';

/// Minimum title length for AI suggestion to be applied
const kMinExistingTitleLengthForAiSuggestion = 5;

/// Generic image analysis prompt for when no task context is available
const String _kGenericImageAnalysisPrompt = '''
Please analyze the provided image(s) and describe what you see. Focus on:
- Main subjects or objects
- Any text visible in the image
- Key details that might be important

Be concise and objective.''';

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
      final stream = await _runCloudInference(
        prompt: prompt,
        model: model,
        provider: provider,
        images: images,
        audioBase64: audioBase64,
        temperature: 0.6,
        systemMessage: promptConfig.systemMessage,
      );

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
        provider: provider,
        entity: entity,
        start: start,
      );

      onStatusChange(InferenceStatus.idle);
    } catch (e, stackTrace) {
      onStatusChange(InferenceStatus.error);

      // Log additional error details
      developer.log(
        'Inference failed',
        name: 'UnifiedAiInferenceRepository',
        error: e,
        stackTrace: stackTrace,
      );

      rethrow;
    }
  }

  /// Build prompt with entity data
  Future<String?> _buildPromptWithData({
    required AiConfigPrompt promptConfig,
    required JournalEntity entity,
  }) async {
    final aiInputRepo = ref.read(aiInputRepositoryProvider);
    var prompt = promptConfig.userMessage;

    // For image analysis, check if the image is linked to a task
    if (promptConfig.aiResponseType == AiResponseType.imageAnalysis &&
        entity is JournalImage) {
      final journalRepo = ref.read(journalRepositoryProvider);
      final linkedFromEntities = await journalRepo.getLinkedToEntities(
        linkedTo: entity.id,
      );

      // Find if any linked entity is a task
      final linkedTask = linkedFromEntities.firstWhereOrNull(
        (entity) => entity is Task,
      ) as Task?;

      if (linkedTask != null) {
        // Get task context and replace {{task}} placeholder
        final taskJson =
            await aiInputRepo.buildTaskDetailsJson(id: linkedTask.id);
        if (taskJson != null) {
          prompt = prompt.replaceAll('{{task}}', taskJson);
        } else {
          // No task context - provide generic prompt without task details
          prompt = _kGenericImageAnalysisPrompt;
        }
      } else {
        // No linked task - provide generic prompt
        prompt = _kGenericImageAnalysisPrompt;
      }
    } else if (promptConfig.requiredInputData.contains(InputDataType.task)) {
      // For prompts that require task data (summaries, action items)
      final jsonString = await aiInputRepo.buildTaskDetailsJson(id: entity.id);
      prompt = '${promptConfig.userMessage} \n $jsonString';
    }

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
        provider: provider,
        maxCompletionTokens: model.maxCompletionTokens,
      );
    } else if (images.isNotEmpty) {
      return cloudRepo.generateWithImages(
        prompt,
        model: model.providerModelId,
        temperature: temperature,
        images: images,
        baseUrl: provider.baseUrl,
        apiKey: provider.apiKey,
        maxCompletionTokens: model.maxCompletionTokens,
      );
    } else {
      return cloudRepo.generate(
        prompt,
        model: model.providerModelId,
        temperature: temperature,
        baseUrl: provider.baseUrl,
        apiKey: provider.apiKey,
        systemMessage: systemMessage,
        maxCompletionTokens: model.maxCompletionTokens,
      );
    }
  }

  /// Extract text from stream chunk
  String _extractTextFromChunk(CreateChatCompletionStreamResponse chunk) {
    try {
      // Handle potential null values in Anthropic's response
      final choices = chunk.choices;
      if (choices.isEmpty) {
        return '';
      }
      return choices.firstOrNull?.delta?.content ?? '';
    } catch (e) {
      // Log error but continue processing stream
      developer.log(
        'Error extracting text from chunk',
        name: 'UnifiedAiInferenceRepository',
        error: e,
      );
      return '';
    }
  }

  /// Process complete response and create appropriate entry
  Future<void> _processCompleteResponse({
    required String response,
    required AiConfigPrompt promptConfig,
    required AiConfigModel model,
    required AiConfigInferenceProvider provider,
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
      promptId: promptConfig.id,
      thoughts: thoughts,
      response: cleanResponse,
      suggestedActionItems: suggestedActionItems,
      type: promptConfig.aiResponseType,
    );

    // Save the AI response entry
    if (entity is! JournalAudio) {
      await ref.read(aiInputRepositoryProvider).createAiResponseEntry(
            data: data,
            start: start,
            linkedId: entity.id,
            categoryId: entity is Task ? entity.categoryId : null,
          );
    }

    // Handle special post-processing
    await _handlePostProcessing(
      entity: entity,
      promptConfig: promptConfig,
      response: cleanResponse,
      model: model,
      provider: provider,
      start: start,
    );
  }

  /// Handle any special post-processing based on response type
  Future<void> _handlePostProcessing({
    required JournalEntity entity,
    required AiConfigPrompt promptConfig,
    required AiConfigModel model,
    required AiConfigInferenceProvider provider,
    required String response,
    required DateTime start,
  }) async {
    final journalRepo = ref.read(journalRepositoryProvider);

    switch (promptConfig.aiResponseType) {
      case AiResponseType.imageAnalysis:
        if (entity is JournalImage) {
          final originalText = entity.entryText?.markdown ?? '';
          final amendedText =
              originalText.isEmpty ? response : '$originalText\n\n$response';

          // Add text to image by appending to existing content
          final updated = entity.copyWith(
            entryText: EntryText(
              plainText: amendedText,
              markdown: amendedText,
            ),
          );
          await journalRepo.updateJournalEntity(updated);
        }
      case AiResponseType.audioTranscription:
        if (entity is JournalAudio) {
          final transcript = AudioTranscript(
            created: DateTime.now(),
            library: provider.name,
            model: model.providerModelId,
            detectedLanguage: '-',
            transcript: response.trim(),
            processingTime: DateTime.now().difference(start),
          );

          final completeResponse = response.trim();

          // Add transcript to audio data and update entry text
          final existingTranscripts = entity.data.transcripts ?? [];
          final updated = entity.copyWith(
            data: entity.data.copyWith(
              transcripts: [...existingTranscripts, transcript],
            ),
            entryText: EntryText(
              plainText: completeResponse,
              markdown: completeResponse,
            ),
          );
          await journalRepo.updateJournalEntity(updated);
        }
      case AiResponseType.taskSummary:
        if (entity is Task) {
          // Extract title from response (H1 markdown format)
          final titleRegex = RegExp(r'^#\s+(.+)$', multiLine: true);
          final titleMatch = titleRegex.firstMatch(response);

          if (titleMatch != null) {
            final suggestedTitle = titleMatch.group(1)?.trim();
            final currentTitle = entity.data.title;

            // Update title if current title is empty or very short (less than 5 characters)
            if (suggestedTitle != null &&
                suggestedTitle.isNotEmpty &&
                currentTitle.length < kMinExistingTitleLengthForAiSuggestion) {
              final updated = entity.copyWith(
                data: entity.data.copyWith(
                  title: suggestedTitle,
                ),
              );
              await journalRepo.updateJournalEntity(updated);
            }
          }
        }
      case AiResponseType.actionItemSuggestions:
    }
  }
}

@riverpod
UnifiedAiInferenceRepository unifiedAiInferenceRepository(Ref ref) {
  return UnifiedAiInferenceRepository(ref);
}
