import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/utils/cache_extension.dart';

/// Live state for one in-flight inference run.
///
/// Identifies the run ([entityId], [promptId], [aiResponseType], plus the
/// [linkedEntityId] when a primary/linked pair is processed together) and owns
/// a broadcast [progressStreamController] that streams incremental progress
/// text to the UI. Holders MUST call [dispose] to close the stream;
/// [copyWith] deliberately reuses the same controller so the stream survives
/// state updates.
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

/// Tracks the active inference (if any) for a single (entityId, responseType)
/// pair. State is null when idle and an [ActiveInferenceData] while a run is in
/// flight. The provider is kept alive briefly after disposal
/// ([inferenceStateCacheDuration]) and disposes the current data's progress
/// stream on teardown.
final NotifierProviderFamily<
  ActiveInferenceController,
  ActiveInferenceData?,
  ({AiResponseType aiResponseType, String entityId})
>
activeInferenceControllerProvider = NotifierProvider.autoDispose
    .family<
      ActiveInferenceController,
      ActiveInferenceData?,
      ({String entityId, AiResponseType aiResponseType})
    >(
      ActiveInferenceController.new,
      name: 'activeInferenceControllerProvider',
    );

class ActiveInferenceController extends Notifier<ActiveInferenceData?> {
  ActiveInferenceController(this._providerArgs);

  final ({String entityId, AiResponseType aiResponseType}) _providerArgs;
  String get entityId => _providerArgs.entityId;
  AiResponseType get aiResponseType => _providerArgs.aiResponseType;

  // Track current data to dispose in onDispose without accessing state
  ActiveInferenceData? _currentData;

  @override
  ActiveInferenceData? build() {
    ref
      ..cacheFor(inferenceStateCacheDuration)
      // Clean up when provider is disposed
      ..onDispose(() {
        _currentData?.dispose();
      });

    return null;
  }

  /// Begins tracking a new run, disposing any prior data first so a stale
  /// progress stream can't leak. Sets state to a fresh [ActiveInferenceData].
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

  /// Pushes [progress] onto the run's progress stream and mirrors it into
  /// `progressText` so late subscribers / rebuilds see the latest value.
  void updateProgress(String progress) {
    if (_currentData != null) {
      _currentData!.updateProgress(progress);
      _currentData = _currentData!.copyWith(progressText: progress);
      state = _currentData;
    }
  }

  /// Ends the run, closing the progress stream and resetting state to null.
  void clearInference() {
    _currentData?.dispose();
    _currentData = null;
    state = null;
  }
}

/// Resolves the active inference for an entity regardless of response type.
///
/// Scans every [AiResponseType]'s [ActiveInferenceController] and returns the
/// first in-flight run, or null if the entity is idle. Because the unified
/// controller registers active inference for BOTH the primary and linked
/// entity, this also reports runs that were started against a linked entity.
final NotifierProviderFamily<
  ActiveInferenceByEntity,
  ActiveInferenceData?,
  String
>
activeInferenceByEntityProvider = NotifierProvider.autoDispose
    .family<ActiveInferenceByEntity, ActiveInferenceData?, String>(
      ActiveInferenceByEntity.new,
      name: 'activeInferenceByEntityProvider',
    );

class ActiveInferenceByEntity extends Notifier<ActiveInferenceData?> {
  ActiveInferenceByEntity(this.entityId);

  final String entityId;

  @override
  ActiveInferenceData? build() {
    ref.cacheFor(inferenceStateCacheDuration);

    // Watch all response types to find any active inference for this entity
    for (final responseType in AiResponseType.values) {
      final activeInference = ref.watch(
        activeInferenceControllerProvider((
          entityId: entityId,
          aiResponseType: responseType,
        )),
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
