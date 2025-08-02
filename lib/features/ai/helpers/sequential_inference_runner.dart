import 'dart:developer' as developer;

import 'package:collection/collection.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/consts.dart';

/// Helper class for running sequential AI inferences
/// This class handles the orchestration of multiple AI inferences in sequence,
/// such as transcription -> checklist updates -> task summary
class SequentialInferenceRunner {
  /// Runs a single inference step in a sequential workflow
  ///
  /// Returns true if the inference completed successfully, false otherwise
  static Future<bool> runSingleInferenceStep({
    required AiResponseType responseType,
    required List<AiConfigPrompt> activePrompts,
    required String entityId,
    required JournalEntity entity,
    required Future<void> Function(
      String entityId,
      AiConfigPrompt promptConfig, {
      JournalEntity? entity,
    }) runInference,
    required void Function(String) onProgress,
  }) async {
    try {
      // Find a prompt for this response type from the pre-fetched list
      final matchingPrompt = activePrompts
          .firstWhereOrNull((p) => p.aiResponseType == responseType);

      if (matchingPrompt == null) {
        developer.log(
          'No active prompt found for response type $responseType, skipping',
          name: 'SequentialInferenceRunner',
        );
        return false;
      }

      // Update progress message based on response type
      final progressMessage = _getProgressMessage(responseType);
      if (progressMessage.isNotEmpty) {
        onProgress(progressMessage);
      }

      // Run the inference and wait for completion, passing the entity to avoid redundant fetch
      await runInference(
        entityId,
        matchingPrompt,
        entity: entity,
      );

      developer.log(
        'Completed inference for response type $responseType',
        name: 'SequentialInferenceRunner',
      );

      return true;
    } catch (e) {
      developer.log(
        'Error in sequential inference for type $responseType: $e',
        name: 'SequentialInferenceRunner',
        error: e,
      );
      return false;
    }
  }

  /// Gets the appropriate progress message for a response type
  static String _getProgressMessage(AiResponseType responseType) {
    return switch (responseType) {
      AiResponseType.audioTranscription => 'Transcribing audio...',
      AiResponseType.checklistUpdates => 'Updating checklists...',
      AiResponseType.taskSummary => 'Generating summary...',
      AiResponseType.imageAnalysis => 'Analyzing image...',
      // ignore: deprecated_member_use_from_same_package
      AiResponseType.actionItemSuggestions => '',
    };
  }

  /// Determines the sequence of response types to run based on
  /// available prompts and entity type
  static List<AiResponseType> determineInferenceSequence({
    required List<AiConfigPrompt> activePrompts,
    required JournalEntity entity,
    bool includeTranscription = true,
    bool includeChecklistUpdates = true,
    bool includeTaskSummary = true,
  }) {
    final sequence = <AiResponseType>[];
    final availableTypes = activePrompts.map((p) => p.aiResponseType).toSet();

    // Add transcription first if available and requested
    if (includeTranscription &&
        availableTypes.contains(AiResponseType.audioTranscription)) {
      sequence.add(AiResponseType.audioTranscription);
    }

    // Add checklist updates second if available and requested
    if (includeChecklistUpdates &&
        availableTypes.contains(AiResponseType.checklistUpdates)) {
      sequence.add(AiResponseType.checklistUpdates);
    }

    // Add task summary last if available and requested
    if (includeTaskSummary &&
        availableTypes.contains(AiResponseType.taskSummary)) {
      sequence.add(AiResponseType.taskSummary);
    }

    // Add image analysis if available
    if (availableTypes.contains(AiResponseType.imageAnalysis)) {
      sequence.add(AiResponseType.imageAnalysis);
    }

    return sequence;
  }

  /// Validates that required prompts are available for a given workflow
  static bool validatePromptsAvailable({
    required List<AiConfigPrompt> activePrompts,
    required List<AiResponseType> requiredTypes,
  }) {
    final availableTypes = activePrompts.map((p) => p.aiResponseType).toSet();

    return requiredTypes.every(availableTypes.contains);
  }
}
