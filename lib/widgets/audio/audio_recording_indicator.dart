import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/blocs/audio/recorder_cubit.dart';
import 'package:lotti/blocs/audio/recorder_state.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/themes/theme.dart';

class AudioRecordingIndicator extends ConsumerWidget {
  const AudioRecordingIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BlocBuilder<AudioRecorderCubit, AudioRecorderState>(
      builder: (BuildContext context, AudioRecorderState state) {
        if (state.status != AudioRecorderStatus.recording ||
            !state.showIndicator) {
          return const SizedBox.shrink();
        }

        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            key: const Key('audio_recording_indicator'),
            onTap: () {
              context.read<AudioRecorderCubit>().stop();
            },
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
                        const Icon(Icons.mic_rounded, size: 20),
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 4),
                          child: Text(
                            formatDuration(state.progress),
                            style: monospaceTextStyle.copyWith(
                              color: Colors.black,
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
