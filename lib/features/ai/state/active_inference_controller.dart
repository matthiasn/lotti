import 'dart:async';

import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/utils/cache_extension.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'active_inference_controller.g.dart';

class ActiveInferenceData {
  ActiveInferenceData({
    required this.entityId,
    required this.promptId,
    required this.aiResponseType,
    this.linkedEntityId,
    this.progressText = '',
    StreamController<String>? progressStreamController,
  }) : progressStreamController =
            progressStreamController ?? StreamController<String>.broadcast();

  final String entityId;
  final String promptId;
  final AiResponseType aiResponseType;
  final String? linkedEntityId;
  final String progressText;
  final StreamController<String> progressStreamController;

  Stream<String> get progressStream => progressStreamController.stream;

  void updateProgress(String progress) {
    progressStreamController.add(progress);
  }

  void dispose() {
    progressStreamController.close();
  }

  ActiveInferenceData copyWith({
    String? progressText,
  }) {
    return ActiveInferenceData(
      entityId: entityId,
      promptId: promptId,
      aiResponseType: aiResponseType,
      linkedEntityId: linkedEntityId,
      progressText: progressText ?? this.progressText,
      progressStreamController: progressStreamController,
    );
  }
}

@riverpod
class ActiveInferenceController extends _$ActiveInferenceController {
  // Track current data to dispose in onDispose without accessing state
  ActiveInferenceData? _currentData;

  @override
  ActiveInferenceData? build({
    required String entityId,
    required AiResponseType aiResponseType,
  }) {
    ref
      ..cacheFor(inferenceStateCacheDuration)

      // Clean up when provider is disposed
      ..onDispose(() {
        _currentData?.dispose();
      });

    return null;
  }

  void startInference({
    required String promptId,
    String? linkedEntityId,
  }) {
    // Dispose of any existing inference data
    _currentData?.dispose();

    _currentData = ActiveInferenceData(
      entityId: entityId,
      promptId: promptId,
      aiResponseType: aiResponseType,
      linkedEntityId: linkedEntityId,
    );
    state = _currentData;
  }

  void updateProgress(String progress) {
    if (_currentData != null) {
      _currentData!.updateProgress(progress);
      _currentData = _currentData!.copyWith(progressText: progress);
      state = _currentData;
    }
  }

  void clearInference() {
    _currentData?.dispose();
    _currentData = null;
    state = null;
  }
}

@riverpod
class ActiveInferenceByEntity extends _$ActiveInferenceByEntity {
  @override
  ActiveInferenceData? build(String entityId) {
    ref.cacheFor(inferenceStateCacheDuration);

    // Watch all response types to find any active inference for this entity
    for (final responseType in AiResponseType.values) {
      final activeInference = ref.watch(
        activeInferenceControllerProvider(
          entityId: entityId,
          aiResponseType: responseType,
        ),
      );
      if (activeInference != null) {
        return activeInference;
      }

      // Note: Linked entities are already handled because when an inference
      // starts with a linkedEntityId, the unified_ai_controller creates
      // active inference entries for BOTH the primary and linked entities.
      // So this provider will find the inference for linked entities too.
    }

    return null;
  }
}
