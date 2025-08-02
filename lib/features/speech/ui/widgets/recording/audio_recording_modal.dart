import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/categories/state/category_details_controller.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/features/speech/ui/widgets/recording/analog_vu_meter.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';
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
              style: GoogleFonts.inconsolata(
                fontSize: fontSizeLarge,
                fontWeight: FontWeight.w300,
                color: theme.colorScheme.primaryFixedDim,
              ),
            ),

            const SizedBox(height: 20),

            // Control buttons in a row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Record/Stop button
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _isRecording(state)
                      ? _buildStopButton(context, _stop, theme)
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
    final createdId = await controller.stop();

    if (mounted) {
      Navigator.of(context).pop();
    }
    if (widget.linkedId == null && createdId != null) {
      beamToNamed('/journal/$createdId');
    }
  }

  Widget _buildStopButton(
      BuildContext context, VoidCallback onTap, ThemeData theme) {
    return GestureDetector(
      key: const ValueKey('stop'),
      onTap: onTap,
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
                'STOP',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecordButton(BuildContext context,
      AudioRecorderController controller, ThemeData theme) {
    return GestureDetector(
      key: const ValueKey('record'),
      onTap: () => controller.record(linkedId: widget.linkedId),
      child: Container(
        width: 120,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.red,
            width: 2,
          ),
        ),
        child: const Center(
          child: Text(
            'RECORD',
            style: TextStyle(
              color: Colors.red,
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
    if (widget.categoryId == null) {
      return const SizedBox.shrink();
    }

    // Get category to check if automatic prompts are configured
    final categoryDetailsState = ref.watch(
      categoryDetailsControllerProvider(widget.categoryId!),
    );

    final category = categoryDetailsState.category;

    if (category == null || category.automaticPrompts == null) {
      return const SizedBox.shrink();
    }

    final hasAutomaticTranscriptionPrompts = category.automaticPrompts!
            .containsKey(AiResponseType.audioTranscription) &&
        category
            .automaticPrompts![AiResponseType.audioTranscription]!.isNotEmpty;

    final hasAutomaticChecklistPrompts = category.automaticPrompts!
            .containsKey(AiResponseType.checklistUpdates) &&
        category.automaticPrompts![AiResponseType.checklistUpdates]!.isNotEmpty;

    final hasAutomaticTaskSummaryPrompts =
        category.automaticPrompts!.containsKey(AiResponseType.taskSummary) &&
            category.automaticPrompts![AiResponseType.taskSummary]!.isNotEmpty;

    // Always show the section to display warnings or checkboxes
    // Only hide if not linked to task and no ASR prompts
    if (!hasAutomaticTranscriptionPrompts && widget.linkedId == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        children: [
          // Speech recognition option
          LottiAnimatedCheckbox(
            label: 'Speech Recognition',
            value: state.enableSpeechRecognition ?? true,
            enabled: hasAutomaticTranscriptionPrompts,
            subtitle: hasAutomaticTranscriptionPrompts
                ? null
                : 'No prompt configured',
            disabledIcon: Icons.mic_off_outlined,
            onChanged: hasAutomaticTranscriptionPrompts
                ? (value) {
                    controller.setEnableSpeechRecognition(enable: value);
                  }
                : null,
          ),

          // Checklist updates option (only show if linked to task AND speech recognition will run)
          // It doesn't make sense to offer checklist updates when there's no transcription to update the task context
          // Speech recognition will run if:
          // - It's explicitly enabled (true), OR
          // - It's not set (null) AND there are automatic transcription prompts configured
          if (widget.linkedId != null &&
              (state.enableSpeechRecognition ??
                  hasAutomaticTranscriptionPrompts)) ...[
            const SizedBox(height: 4),
            LottiAnimatedCheckbox(
              label: 'Checklist Updates',
              value: state.enableChecklistUpdates ?? true,
              enabled: hasAutomaticChecklistPrompts,
              subtitle:
                  hasAutomaticChecklistPrompts ? null : 'No prompt configured',
              disabledIcon: Icons.checklist_rtl_outlined,
              onChanged: hasAutomaticChecklistPrompts
                  ? (value) {
                      controller.setEnableChecklistUpdates(enable: value);
                    }
                  : null,
            ),
          ],

          // Task summary option (only show if linked to task AND speech recognition will run)
          // It doesn't make sense to offer task summary when there's no transcription to update the task context
          // Speech recognition will run if:
          // - It's explicitly enabled (true), OR
          // - It's not set (null) AND there are automatic transcription prompts configured
          if (widget.linkedId != null &&
              (state.enableSpeechRecognition ??
                  hasAutomaticTranscriptionPrompts)) ...[
            const SizedBox(height: 4),
            LottiAnimatedCheckbox(
              label: 'Task Summary',
              value: state.enableTaskSummary ?? true,
              enabled: hasAutomaticTaskSummaryPrompts,
              subtitle: hasAutomaticTaskSummaryPrompts
                  ? null
                  : 'No prompt configured',
              disabledIcon: Icons.summarize_outlined,
              onChanged: hasAutomaticTaskSummaryPrompts
                  ? (value) {
                      controller.setEnableTaskSummary(enable: value);
                    }
                  : null,
            ),
          ],
        ],
      ),
    );
  }
}
