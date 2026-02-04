import 'dart:io';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/features/ai_chat/ui/controllers/chat_recorder_controller.dart';
import 'package:lotti/features/daily_os/voice/day_plan_voice_service.dart';
import 'package:lotti/features/daily_os/voice/day_plan_voice_strategy.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'day_plan_voice_controller.freezed.dart';
part 'day_plan_voice_controller.g.dart';

/// Error types for voice day planning.
/// Used to display appropriate localized messages to users.
enum DayPlanVoiceErrorType {
  /// No AI models configured with function calling support
  noModels,

  /// Network connectivity issue
  network,

  /// Generic/unknown error
  unknown,
}

/// Tracks LLM processing state after transcription completes.
/// Recording/transcription is handled by ChatRecorderController.
@freezed
sealed class DayPlanLlmState with _$DayPlanLlmState {
  const factory DayPlanLlmState.idle() = DayPlanLlmStateIdle;
  const factory DayPlanLlmState.processing() = DayPlanLlmStateProcessing;
  const factory DayPlanLlmState.completed({
    required List<DayPlanActionResult> actions,
  }) = DayPlanLlmStateCompleted;
  const factory DayPlanLlmState.error({
    required DayPlanVoiceErrorType errorType,
  }) = DayPlanLlmStateError;
}

/// Controller for voice-based day planning.
///
/// Listens to [ChatRecorderController] for completed transcripts and
/// processes them through [DayPlanVoiceService] to execute day plan actions.
///
/// Benefits of this approach:
/// - Avoids duplicating recording/transcription logic
/// - `ChatRecorderController` is battle-tested with proper race condition handling
/// - Separation of concerns: recording vs. LLM processing
/// - Easier to test each component independently
@riverpod
class DayPlanVoiceController extends _$DayPlanVoiceController {
  @override
  DayPlanLlmState build({required DateTime date}) {
    // Listen to ChatRecorderController for completed transcripts
    // Only consume transcripts with dayPlanVoice purpose to avoid conflicts
    // with other features (e.g., AI chat) using the same recorder
    ref.listen(chatRecorderControllerProvider, (prev, next) {
      if (next.transcript != null &&
          prev?.transcript != next.transcript &&
          next.purpose == ChatRecorderPurpose.dayPlanVoice) {
        // Transcript ready - consume it and process with LLM
        final transcript = next.transcript!;
        // Clear the transcript so it's not re-processed
        ref.read(chatRecorderControllerProvider.notifier).clearResult();
        // Process with LLM
        _processTranscript(transcript);
      }
    });
    return const DayPlanLlmState.idle();
  }

  Future<void> _processTranscript(String transcript) async {
    state = const DayPlanLlmState.processing();
    try {
      final result = await ref
          .read(dayPlanVoiceServiceProvider.notifier)
          .processTranscript(transcript: transcript, date: date);
      state = DayPlanLlmState.completed(actions: result.actions);
    } catch (e, stackTrace) {
      // Log the technical details for debugging
      getIt<LoggingService>().captureException(
        e,
        stackTrace: stackTrace,
        domain: 'DayPlanVoiceController',
        subDomain: 'processTranscript',
      );

      // Classify the error for user-friendly display
      final errorType = _classifyError(e);
      state = DayPlanLlmState.error(errorType: errorType);
    }
  }

  /// Classifies an exception into a user-friendly error type.
  DayPlanVoiceErrorType _classifyError(Object error) {
    final message = error.toString().toLowerCase();

    // Check for model configuration errors
    if (message.contains('no function-calling') ||
        message.contains('no models configured') ||
        message.contains('provider not found')) {
      return DayPlanVoiceErrorType.noModels;
    }

    // Check for network errors
    if (error is SocketException ||
        message.contains('network') ||
        message.contains('connection') ||
        message.contains('timeout') ||
        message.contains('socket')) {
      return DayPlanVoiceErrorType.network;
    }

    return DayPlanVoiceErrorType.unknown;
  }

  /// Resets the state to idle.
  void reset() => state = const DayPlanLlmState.idle();
}
