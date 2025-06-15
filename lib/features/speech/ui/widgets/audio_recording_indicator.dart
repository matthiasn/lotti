import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/features/speech/state/recorder_cubit.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/features/speech/ui/widgets/audio_recording_modal.dart';
import 'package:lotti/themes/theme.dart';

class AudioRecordingIndicator extends ConsumerWidget {
  const AudioRecordingIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BlocBuilder<AudioRecorderCubit, AudioRecorderState>(
      builder: (BuildContext context, AudioRecorderState state) {
        final shouldShow = state.status == AudioRecorderStatus.recording && 
            !state.modalVisible;
        
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
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
              child: Container(
                width: 100,
                height: 25,
                color: context.colorScheme.error,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        const Icon(
                          Icons.mic_outlined,
                          size: 20,
                          color: Colors.black87,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 2,
                            bottom: 4,
                            right: 4,
                          ),
                          child: Text(
                            formatDuration(state.progress),
                            style: monospaceTextStyle.copyWith(
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
