import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai_chat/ui/controllers/chat_recorder_controller.dart';
import 'package:lotti/features/daily_os/state/daily_os_controller.dart';
import 'package:lotti/features/daily_os/ui/widgets/add_budget_sheet.dart'
    as add_block;
import 'package:lotti/features/daily_os/voice/day_plan_voice_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// A FAB that supports both tap (for manual block creation) and
/// long-press (for voice-based day planning).
///
/// Features:
/// - Tap: Opens the AddBlockSheet for manual block creation
/// - Long-press: Records audio, transcribes, and processes via LLM
/// - Visual feedback for recording/transcribing/processing states
/// - Snackbar feedback on completion/error
class VoiceDayPlanFab extends ConsumerWidget {
  const VoiceDayPlanFab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(dailyOsSelectedDateProvider);

    // Recording/transcription state from ChatRecorderController
    final recorderState = ref.watch(chatRecorderControllerProvider);

    // LLM processing state
    final llmState = ref.watch(
      dayPlanVoiceControllerProvider(date: selectedDate),
    );

    // Listen for completion/error to show snackbar, and recorder errors
    ref
      ..listen(
        dayPlanVoiceControllerProvider(date: selectedDate),
        (prev, next) {
          _handleLlmStateChange(context, ref, selectedDate, next);
        },
      )
      ..listen(
        chatRecorderControllerProvider,
        (prev, next) {
          if (next.errorType != null && prev?.errorType != next.errorType) {
            final message =
                _getLocalizedRecorderError(context, next.errorType!);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      );

    final isRecording = recorderState.status == ChatRecorderStatus.recording;
    final isTranscribing =
        recorderState.status == ChatRecorderStatus.processing;
    final isProcessingLlm = llmState.maybeWhen(
      processing: () => true,
      orElse: () => false,
    );

    final isWorking = isRecording || isTranscribing || isProcessingLlm;

    return GestureDetector(
      onLongPressStart: (_) {
        if (!isWorking) {
          ref.read(chatRecorderControllerProvider.notifier).start(
                purpose: ChatRecorderPurpose.dayPlanVoice,
              );
        }
      },
      onLongPressEnd: (_) {
        if (isRecording) {
          ref.read(chatRecorderControllerProvider.notifier).stopAndTranscribe();
        }
      },
      onLongPressCancel: () {
        if (isRecording) {
          ref.read(chatRecorderControllerProvider.notifier).cancel();
        }
      },
      child: FloatingActionButton(
        onPressed: isWorking
            ? null
            : () => add_block.AddBlockSheet.show(context, selectedDate),
        backgroundColor: isRecording ? Colors.red : null,
        child: _buildChild(
          isRecording: isRecording,
          isTranscribing: isTranscribing,
          isProcessingLlm: isProcessingLlm,
        ),
      ),
    );
  }

  Widget _buildChild({
    required bool isRecording,
    required bool isTranscribing,
    required bool isProcessingLlm,
  }) {
    if (isRecording) {
      return const Icon(Icons.mic);
    }
    if (isTranscribing || isProcessingLlm) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }
    return const Icon(Icons.add);
  }

  void _handleLlmStateChange(
    BuildContext context,
    WidgetRef ref,
    DateTime selectedDate,
    DayPlanLlmState state,
  ) {
    final l10n = context.messages;
    state.maybeWhen(
      completed: (actions) {
        final successCount = actions.where((a) => a.success).length;
        final failCount = actions.where((a) => !a.success).length;
        final message = failCount > 0
            ? l10n.voicePlanActionsWithErrors(successCount, failCount)
            : l10n.voicePlanActionsCompleted(successCount);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
        // Reset state to idle after showing completion feedback
        ref
            .read(dayPlanVoiceControllerProvider(date: selectedDate).notifier)
            .reset();
      },
      error: (errorType) {
        final message = _getLocalizedVoicePlanError(context, errorType);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
          ),
        );
        // Reset state to idle after showing error feedback
        ref
            .read(dayPlanVoiceControllerProvider(date: selectedDate).notifier)
            .reset();
      },
      orElse: () {},
    );
  }

  String _getLocalizedVoicePlanError(
    BuildContext context,
    DayPlanVoiceErrorType errorType,
  ) {
    final l10n = context.messages;
    return switch (errorType) {
      DayPlanVoiceErrorType.noModels => l10n.voicePlanErrorNoModels,
      DayPlanVoiceErrorType.network => l10n.voicePlanErrorNetwork,
      DayPlanVoiceErrorType.unknown => l10n.voicePlanError,
    };
  }

  String _getLocalizedRecorderError(
    BuildContext context,
    ChatRecorderErrorType errorType,
  ) {
    final l10n = context.messages;
    return switch (errorType) {
      ChatRecorderErrorType.permissionDenied =>
        l10n.recorderErrorPermissionDenied,
      ChatRecorderErrorType.startFailed => l10n.recorderErrorStartFailed,
      ChatRecorderErrorType.noAudioFile => l10n.recorderErrorNoAudioFile,
      ChatRecorderErrorType.transcriptionFailed =>
        l10n.recorderErrorTranscriptionFailed,
      ChatRecorderErrorType.concurrentOperation =>
        l10n.recorderErrorConcurrentOperation,
      ChatRecorderErrorType.storageFull => l10n.recorderErrorStorageFull,
      ChatRecorderErrorType.fileCorruption => l10n.recorderErrorFileCorruption,
      ChatRecorderErrorType.cleanupFailed => l10n.recorderErrorUnknown,
    };
  }
}
