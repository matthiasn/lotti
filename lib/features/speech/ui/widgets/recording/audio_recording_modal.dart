import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai_chat/services/realtime_transcription_service.dart';
import 'package:lotti/features/speech/state/checkbox_visibility_provider.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/features/speech/ui/widgets/recording/analog_vu_meter.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/ui/app_fonts.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:lotti/widgets/ui/lotti_animated_checkbox.dart';

class AudioRecordingModal {
  static Future<void> show(
    BuildContext context, {
    String? linkedId,
    String? categoryId,
    bool useRootNavigator = true,
  }) async {
    // Get the controller before showing the modal
    final container = ProviderScope.containerOf(context);
    final controller = container.read(audioRecorderControllerProvider.notifier)
      // Set modal visible before showing
      ..setModalVisible(modalVisible: true);
    if (categoryId != null) {
      controller.setCategoryId(categoryId);
    }

    try {
      await ModalUtils.showSinglePageModal<void>(
        context: context,
        hasTopBarLayer: false,
        showCloseButton: false,
        padding: ModalUtils.defaultPadding.copyWith(bottom: 20),
        builder: (BuildContext _) {
          return AudioRecordingModalContent(
            linkedId: linkedId,
            categoryId: categoryId,
          );
        },
      );
    } finally {
      // Modal has been dismissed (either by stop button, back gesture, or tapping outside)
      // Always set modal visibility to false after dismissal
      controller.setModalVisible(modalVisible: false);
    }
  }
}

class AudioRecordingModalContent extends ConsumerStatefulWidget {
  const AudioRecordingModalContent({
    super.key,
    this.linkedId,
    this.categoryId,
  });

  final String? linkedId;
  final String? categoryId;

  @override
  ConsumerState<AudioRecordingModalContent> createState() =>
      _AudioRecordingModalContentState();
}

class _AudioRecordingModalContentState
    extends ConsumerState<AudioRecordingModalContent> {
  bool _useRealtimeMode = false;

  @override
  void initState() {
    super.initState();
    // Modal visibility is now managed in the show() method
  }

  @override
  void dispose() {
    // Modal visibility is now managed in the show() method
    super.dispose();
  }

  String formatDuration(String str) {
    return str.substring(0, str.length - 7);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(audioRecorderControllerProvider);
    final controller = ref.read(audioRecorderControllerProvider.notifier);
    final realtimeAvailable =
        ref.watch(realtimeAvailableProvider).value ?? false;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnalogVuMeter(
              vu: state.vu,
              dBFS: state.dBFS,
              size: 400,
              colorScheme: theme.colorScheme,
            ),

            // Duration display
            Text(
              formatDuration(state.progress.toString()),
              style: AppFonts.inconsolata(
                fontSize: fontSizeLarge,
                fontWeight: FontWeight.w300,
                color: theme.colorScheme.primaryFixedDim,
              ),
            ),

            // Live transcript display (realtime mode only)
            if (state.isRealtimeMode &&
                state.status == AudioRecorderStatus.recording)
              _buildLiveTranscript(state, theme),

            // Mode toggle (only when realtime is available and not recording)
            if (realtimeAvailable && !_isRecording(state))
              _buildModeToggle(context, theme),

            const SizedBox(height: 20),

            // Control buttons in a row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Record/Stop button
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _isRecording(state)
                      ? _buildStopButton(context, theme, state)
                      : _buildRecordButton(context, controller, theme),
                ),
              ],
            ),

            // Automatic prompt options
            if (widget.categoryId != null) ...[
              const SizedBox(height: 10),
              _buildAutomaticPromptOptions(context, controller, state, theme),
            ],
          ],
        ),
      ],
    );
  }

  bool _isRecording(AudioRecorderState state) {
    return state.status == AudioRecorderStatus.recording ||
        state.status == AudioRecorderStatus.paused;
  }

  Future<void> _stop() async {
    final controller = ref.read(audioRecorderControllerProvider.notifier);
    final state = ref.read(audioRecorderControllerProvider);

    final String? createdId;
    if (state.isRealtimeMode) {
      createdId = await controller.stopRealtime();
    } else {
      createdId = await controller.stop();
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
    if (widget.linkedId == null && createdId != null) {
      beamToNamed('/journal/$createdId');
    }
  }

  Future<void> _cancel() async {
    final controller = ref.read(audioRecorderControllerProvider.notifier);
    try {
      await controller.cancelRealtime();
    } finally {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Widget _buildLiveTranscript(AudioRecorderState state, ThemeData theme) {
    final text = state.partialTranscript;

    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 120),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: text == null || text.isEmpty
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      context.messages.audioRecordingListening,
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                        fontSize: 14,
                      ),
                    ),
                  ],
                )
              : SingleChildScrollView(
                  reverse: true,
                  child: Text(
                    text,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 14,
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildModeToggle(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            context.messages.audioRecordingStandard,
            style: TextStyle(
              color: !_useRealtimeMode
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight:
                  !_useRealtimeMode ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          Switch.adaptive(
            value: _useRealtimeMode,
            onChanged: (value) => setState(() => _useRealtimeMode = value),
          ),
          Text(
            context.messages.audioRecordingRealtime,
            style: TextStyle(
              color: _useRealtimeMode
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight:
                  _useRealtimeMode ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStopButton(
    BuildContext context,
    ThemeData theme,
    AudioRecorderState state,
  ) {
    return Row(
      key: const ValueKey('stop_controls'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // Cancel button (for realtime mode)
        if (state.isRealtimeMode) ...[
          GestureDetector(
            onTap: _cancel,
            child: Container(
              width: 90,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.5),
                ),
              ),
              child: Center(
                child: Text(
                  context.messages.audioRecordingCancel,
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
        // Stop button
        GestureDetector(
          onTap: _stop,
          child: Container(
            width: 120,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: theme.colorScheme.error,
                width: 2,
              ),
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withValues(alpha: 0.6),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    context.messages.audioRecordingStop,
                    style: TextStyle(
                      color: theme.colorScheme.error,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecordButton(BuildContext context,
      AudioRecorderController controller, ThemeData theme) {
    return GestureDetector(
      key: const ValueKey('record'),
      onTap: () {
        if (_useRealtimeMode) {
          controller.recordRealtime(linkedId: widget.linkedId);
        } else {
          controller.record(linkedId: widget.linkedId);
        }
      },
      child: Container(
        width: 120,
        height: 48,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        child: Center(
          child: Text(
            'RECORD',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAutomaticPromptOptions(
    BuildContext context,
    AudioRecorderController controller,
    AudioRecorderState state,
    ThemeData theme,
  ) {
    // Use the extracted provider to compute visibility
    // This makes the logic testable independently from the widget
    final visibility = ref.watch(
      checkboxVisibilityProvider(
        categoryId: widget.categoryId,
        linkedId: widget.linkedId,
        userSpeechPreference: state.enableSpeechRecognition,
      ),
    );

    if (visibility.none) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        children: [
          if (visibility.speech)
            LottiAnimatedCheckbox(
              key: const Key('speech_recognition_checkbox'),
              label: 'Speech Recognition',
              value: state.enableSpeechRecognition ?? true,
              onChanged: (value) {
                controller.setEnableSpeechRecognition(enable: value);
              },
            ),
          if (visibility.checklist) ...[
            const SizedBox(height: 4),
            LottiAnimatedCheckbox(
              key: const Key('checklist_updates_checkbox'),
              label: 'Checklist Updates',
              value: state.enableChecklistUpdates ?? true,
              onChanged: (value) {
                controller.setEnableChecklistUpdates(enable: value);
              },
            ),
          ],
          if (visibility.summary) ...[
            const SizedBox(height: 4),
            LottiAnimatedCheckbox(
              key: const Key('task_summary_checkbox'),
              label: 'Task Summary',
              value: state.enableTaskSummary ?? true,
              onChanged: (value) {
                controller.setEnableTaskSummary(enable: value);
              },
            ),
          ],
        ],
      ),
    );
  }
}
