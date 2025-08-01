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
                // Language selector - compact
                Container(
                  height: 48, // Same height as record/stop button
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(24), // Same radius
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () => _showLanguageMenu(
                          context, controller, state.language ?? ''),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.language,
                              color: theme.colorScheme.onSurfaceVariant,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _getLanguageDisplay(state.language ?? ''),
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.keyboard_arrow_down,
                              color: theme.colorScheme.onSurfaceVariant,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 20),
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
              const SizedBox(height: 20),
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

  String _getLanguageDisplay(String language) {
    switch (language) {
      case 'en':
        return 'English';
      case 'de':
        return 'Deutsch';
      default:
        return 'Auto';
    }
  }

  void _showLanguageMenu(BuildContext context,
      AudioRecorderController controller, String currentLanguage) {
    final theme = Theme.of(context);
    final button = context.findRenderObject()! as RenderBox;
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero),
            ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: context,
      position: position,
      color: theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.5),
        ),
      ),
      elevation: 8,
      items: [
        _buildMenuItem(
            '', 'Auto-detect', currentLanguage == '', theme.colorScheme),
        _buildMenuItem(
            'en', 'English', currentLanguage == 'en', theme.colorScheme),
        _buildMenuItem(
            'de', 'Deutsch', currentLanguage == 'de', theme.colorScheme),
      ],
    ).then((String? value) {
      if (value != null) {
        controller.setLanguage(value);
      }
    });
  }

  PopupMenuItem<String> _buildMenuItem(
      String value, String label, bool isSelected, ColorScheme colorScheme) {
    return PopupMenuItem<String>(
      value: value,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            const Spacer(),
            if (isSelected)
              Icon(
                Icons.check,
                color: colorScheme.primary,
                size: 16,
              ),
          ],
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

    final hasTranscriptionPrompts = category.automaticPrompts!
            .containsKey(AiResponseType.audioTranscription) &&
        category
            .automaticPrompts![AiResponseType.audioTranscription]!.isNotEmpty;

    final hasTaskSummaryPrompts =
        category.automaticPrompts!.containsKey(AiResponseType.taskSummary) &&
            category.automaticPrompts![AiResponseType.taskSummary]!.isNotEmpty;

    if (!hasTranscriptionPrompts && !hasTaskSummaryPrompts) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Automatic Processing',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),

          // Speech recognition checkbox
          if (hasTranscriptionPrompts)
            InkWell(
              onTap: () {
                controller.setEnableSpeechRecognition(
                  enable: state.enableSpeechRecognition != true,
                );
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: Checkbox(
                        value: state.enableSpeechRecognition ?? true,
                        onChanged: (value) {
                          controller.setEnableSpeechRecognition(enable: value);
                        },
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Speech Recognition',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            state.enableSpeechRecognition == null
                                ? 'Using category default'
                                : state.enableSpeechRecognition!
                                    ? 'Enabled'
                                    : 'Disabled',
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Task summary checkbox (only show if linked to task)
          if (widget.linkedId != null && hasTaskSummaryPrompts) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () {
                controller.setEnableTaskSummary(
                  enable: state.enableTaskSummary != true,
                );
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: Checkbox(
                        value: state.enableTaskSummary ?? true,
                        onChanged: (value) {
                          controller.setEnableTaskSummary(enable: value);
                        },
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Task Summary',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            state.enableTaskSummary == null
                                ? 'Using category default'
                                : state.enableTaskSummary!
                                    ? 'Enabled'
                                    : 'Disabled',
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
