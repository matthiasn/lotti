import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/features/speech/ui/widgets/recording/audio_recording_modal.dart';
import 'package:lotti/themes/theme.dart';

class AudioRecordingIndicatorConstants {
  const AudioRecordingIndicatorConstants._();

  static const double indicatorWidth = 100;
  static const double indicatorHeight = 25;
  static const double iconSize = 20;
  static const double borderRadius = 8;
  static const EdgeInsets textPadding = EdgeInsets.only(
    left: 2,
    bottom: 4,
    right: 4,
  );
}

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
        child: GestureDetector(
          key: const Key('audio_recording_indicator'),
          onTap: onTap,
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(
                  AudioRecordingIndicatorConstants.borderRadius),
              topRight: Radius.circular(
                  AudioRecordingIndicatorConstants.borderRadius),
            ),
            child: Container(
              width: AudioRecordingIndicatorConstants.indicatorWidth,
              height: AudioRecordingIndicatorConstants.indicatorHeight,
              color: context.colorScheme.error,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        const Icon(
                          Icons.mic_outlined,
                          size: AudioRecordingIndicatorConstants.iconSize,
                          color: Colors.black87,
                        ),
                        Padding(
                          padding: AudioRecordingIndicatorConstants.textPadding,
                          child: Text(
                            formatDuration(state.progress),
                            style: monospaceTextStyle.copyWith(
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
