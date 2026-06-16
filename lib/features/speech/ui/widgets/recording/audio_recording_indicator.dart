import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/features/speech/ui/widgets/recording/audio_recording_modal.dart';
import 'package:lotti/features/speech/ui/widgets/recording/audio_recording_orb.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

/// Fixed layout dimensions for the [AudioRecordingIndicator] chip.
class AudioRecordingIndicatorConstants {
  const AudioRecordingIndicatorConstants._();

  static const double indicatorHeight = 24;
  static const double iconSize = 20;
  static const double borderRadius = 8;
  static const EdgeInsets textPadding = EdgeInsets.only(
    left: 2,
    bottom: 1,
    right: 10,
  );
}

/// Floating chip shown while a recording is in progress but its modal is
/// closed, surfacing the live [AudioRecordingOrb] and elapsed time.
///
/// Renders nothing unless the recorder is actively recording with the modal
/// hidden. Tapping it reopens [AudioRecordingModal] for the in-flight session,
/// reusing the linked entry and its category. The whole build is wrapped in a
/// guard that degrades to an empty widget if audio/MediaKit wiring fails.
class AudioRecordingIndicator extends ConsumerWidget {
  const AudioRecordingIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    try {
      final state = ref.watch(audioRecorderControllerProvider);
      final shouldShow =
          state.status == AudioRecorderStatus.recording && !state.modalVisible;

      if (!shouldShow) {
        return const SizedBox.shrink();
      }

      final tokens = context.designTokens;
      final linkedId = state.linkedId;

      final linkedEntry = linkedId != null
          ? ref.watch(entryControllerProvider(id: linkedId)).value?.entry
          : null;

      void onTap() {
        AudioRecordingModal.show(
          context,
          linkedId: linkedId,
          categoryId: linkedEntry?.categoryId,
          useRootNavigator: false,
        );
      }

      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Semantics(
          button: true,
          label: context.messages.taskActionBarAudioRecordingActive,
          child: GestureDetector(
            key: const Key('audio_recording_indicator'),
            onTap: onTap,
            child: ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(tokens.radii.s),
                topRight: Radius.circular(tokens.radii.s),
              ),
              child: Container(
                height: tokens.spacing.step6,
                color: tokens.colors.alert.error.defaultColor,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(width: tokens.spacing.step2),
                    AudioRecordingOrb(
                      dBFS: state.dBFS,
                      size: tokens.spacing.step6,
                    ),
                    SizedBox(width: tokens.spacing.step2),
                    Padding(
                      padding: EdgeInsets.only(right: tokens.spacing.step4),
                      child: Text(
                        formatDuration(state.progress),
                        style: tokens.typography.styles.subtitle.subtitle2
                            .copyWith(
                              color: tokens.colors.text.onInteractiveAlert,
                              fontFeatures: numericBadgeFontFeatures,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      // Return empty widget if MediaKit/audio recording fails
      return const SizedBox.shrink();
    }
  }
}
