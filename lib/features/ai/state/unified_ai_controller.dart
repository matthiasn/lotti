// ignore_for_file: specify_nonobvious_property_types

import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/unified_ai_inference_repository.dart';
import 'package:lotti/features/ai/state/active_inference_controller.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/util/ai_error_utils.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';

/// State object for unified AI inference
@immutable
class UnifiedAiState {
  const UnifiedAiState({
    required this.message,
    this.error,
  });

  final String message;
  final Exception? error;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnifiedAiState &&
          runtimeType == other.runtimeType &&
          message == other.message &&
          error == other.error;

  @override
  int get hashCode => message.hashCode ^ error.hashCode;
}

/// Record type for unified AI controller parameters.
typedef UnifiedAiParams = ({String entityId, String promptId});

/// Controller for running unified AI inference with configurable prompts
/// Note: keepAlive prevents auto-dispose during async operations in catch blocks,
/// ensuring error state persists until the widget can read it.
final unifiedAiControllerProvider =
    NotifierProvider.family<
      UnifiedAiController,
      UnifiedAiState,
      UnifiedAiParams
    >(
      UnifiedAiController.new,
    );

class UnifiedAiController extends Notifier<UnifiedAiState> {
  UnifiedAiController(this._params);

  final UnifiedAiParams _params;

  @override
  UnifiedAiState build() => const UnifiedAiState(message: '');
  Future<void>? _activeInferenceFuture;
  String? _activeLinkedEntityId;
  int _runCounter = 0;
  int? _activeRunId;

  String get entityId => _params.entityId;
  String get promptId => _params.promptId;

  // Helper method to update inference status for both entities
  void _updateInferenceStatus(
    InferenceStatus status,
    AiResponseType responseType, {
    String? linkedEntityId,
  }) {
    ref
        .read(
          inferenceStatusControllerProvider((
            id: entityId,
            aiResponseType: responseType,
          )).notifier,
        )
        .setStatus(status);

    if (linkedEntityId != null) {
      ref
          .read(
            inferenceStatusControllerProvider((
              id: linkedEntityId,
              aiResponseType: responseType,
            )).notifier,
          )
          .setStatus(status);
    }
  }

  // Helper method to start active inference for both entities
  void _startActiveInference(
    String promptId,
    AiResponseType responseType, {
    String? linkedEntityId,
  }) {
    ref
        .read(
          activeInferenceControllerProvider((
            entityId: entityId,
            aiResponseType: responseType,
          )).notifier,
        )
        .startInference(
          promptId: promptId,
          linkedEntityId: linkedEntityId,
        );

    if (linkedEntityId != null) {
      ref
          .read(
            activeInferenceControllerProvider((
              entityId: linkedEntityId,
              aiResponseType: responseType,
            )).notifier,
          )
          .startInference(
            promptId: promptId,
            linkedEntityId: entityId,
          );
    }
  }

  // Helper method to update progress for both entities
  void _updateActiveInferenceProgress(
    String progress,
    AiResponseType responseType, {
    String? linkedEntityId,
  }) {
    ref
        .read(
          activeInferenceControllerProvider((
            entityId: entityId,
            aiResponseType: responseType,
          )).notifier,
        )
        .updateProgress(progress);

    if (linkedEntityId != null) {
      ref
          .read(
            activeInferenceControllerProvider((
              entityId: linkedEntityId,
              aiResponseType: responseType,
            )).notifier,
          )
          .updateProgress(progress);
    }
  }

  // Helper method to clear active inference for both entities
  void _clearActiveInference(
    AiResponseType responseType, {
    String? linkedEntityId,
  }) {
    ref
        .read(
          activeInferenceControllerProvider((
            entityId: entityId,
            aiResponseType: responseType,
          )).notifier,
        )
        .clearInference();

    if (linkedEntityId != null) {
      ref
          .read(
            activeInferenceControllerProvider((
              entityId: linkedEntityId,
              aiResponseType: responseType,
            )).notifier,
          )
          .clearInference();
    }
  }

  Future<void> runInference({String? linkedEntityId}) async {
    final loggingService = getIt<DomainLogger>();

    if (_activeInferenceFuture != null) {
      loggingService.log(
        LogDomain.ai,
        'Unified AI inference already running for $entityId (prompt: $promptId). '
        'Joining existing run $_activeRunId (incoming linked: $linkedEntityId, active linked: $_activeLinkedEntityId).',
        subDomain: 'runInference',
      );
      return _activeInferenceFuture!;
    }

    final runId = ++_runCounter;
    _activeRunId = runId;
    _activeLinkedEntityId = linkedEntityId;

    final future = _performInference(
      loggingService: loggingService,
      linkedEntityId: linkedEntityId,
    );
    _activeInferenceFuture = future;

    try {
      await future;
    } finally {
      loggingService.log(
        LogDomain.ai,
        'Unified AI inference finished for $entityId (prompt: $promptId). '
        'Run $runId completed with linked: $linkedEntityId.',
        subDomain: 'runInference',
      );
      if (identical(_activeInferenceFuture, future)) {
        _activeInferenceFuture = null;
        _activeLinkedEntityId = null;
        _activeRunId = null;
      }
    }
  }

  Future<void> _performInference({
    required DomainLogger loggingService,
    String? linkedEntityId,
  }) async {
    loggingService.log(
      LogDomain.ai,
      'Starting unified AI inference for $entityId (prompt: $promptId, linked: $linkedEntityId, run $_activeRunId)',
      subDomain: 'runInference',
    );

    try {
      // Fetch the prompt config
      final config = await ref.read(aiConfigByIdProvider(promptId).future);
      if (config == null || config is! AiConfigPrompt) {
        throw Exception('Invalid prompt configuration for ID: $promptId');
      }
      final promptConfig = config;

      // Reset the inference status to idle before starting
      _updateInferenceStatus(
        InferenceStatus.idle,
        promptConfig.aiResponseType,
        linkedEntityId: linkedEntityId,
      );

      // Clear any previous progress message
      state = const UnifiedAiState(message: '');

      // Start tracking this inference
      _startActiveInference(
        promptId,
        promptConfig.aiResponseType,
        linkedEntityId: linkedEntityId,
      );

      final repo = ref.read(unifiedAiInferenceRepositoryProvider);
      await repo.runInference(
        entityId: entityId,
        promptConfig: promptConfig,
        onProgress: (progress) {
          state = UnifiedAiState(message: progress);
          _updateActiveInferenceProgress(
            progress,
            promptConfig.aiResponseType,
            linkedEntityId: linkedEntityId,
          );
        },
        onStatusChange: (status) {
          _updateInferenceStatus(
            status,
            promptConfig.aiResponseType,
            linkedEntityId: linkedEntityId,
          );
          if (status != InferenceStatus.running) {
            _clearActiveInference(
              promptConfig.aiResponseType,
              linkedEntityId: linkedEntityId,
            );
          }
        },
        linkedEntityId: linkedEntityId,
      );
    } catch (e, stackTrace) {
      // Categorize the error for better user feedback
      final inferenceError = AiErrorUtils.categorizeError(
        e,
        stackTrace: stackTrace,
      );

      developer.log(
        'Controller caught exception: ${e.runtimeType}, isException: ${e is Exception}',
        name: 'UnifiedAiController',
      );

      // Set the error message and preserve the original exception
      // Store the original caught exception 'e' directly, not inferenceError.originalError
      final newState = UnifiedAiState(
        message: inferenceError.message,
        error: e is Exception ? e : null,
      );

      developer.log(
        'Setting state with error: ${newState.error?.runtimeType}',
        name: 'UnifiedAiController',
      );

      state = newState;

      developer.log(
        'State after assignment: error=${state.error?.runtimeType}, '
        'entityId=$entityId, promptId=$promptId',
        name: 'UnifiedAiController',
      );

      // Try to set error status if we have prompt config
      try {
        final config = await ref.read(aiConfigByIdProvider(promptId).future);
        if (config != null && config is AiConfigPrompt) {
          loggingService.log(
            LogDomain.ai,
            'Setting inference status to ERROR for ${config.aiResponseType}',
            subDomain: 'runInference',
          );
          _updateInferenceStatus(
            InferenceStatus.error,
            config.aiResponseType,
            linkedEntityId: linkedEntityId,
          );
        }
      } catch (_) {
        // Ignore errors when setting status
      }

      loggingService.error(
        LogDomain.ai,
        (inferenceError.originalError ?? e) as Object,
        stackTrace: stackTrace,
        subDomain: 'runInference',
      );
    }
  }
}
