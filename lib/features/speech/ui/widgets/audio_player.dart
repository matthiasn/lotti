import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/speech/state/player_cubit.dart';
import 'package:lotti/features/speech/state/player_state.dart';
import 'package:lotti/themes/theme.dart';

class AudioPlayerWidget extends ConsumerWidget {
  const AudioPlayerWidget(this.journalAudio, {super.key});

  final JournalAudio journalAudio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speedToggleMap = <double, double>{
      0.5: 0.75,
      0.75: 1,
      1: 1.25,
      1.25: 1.5,
      1.5: 1.75,
      1.75: 2,
      2: 0.5,
    };

    final speedLabelMap = <double, String>{
      0.5: '0.5x',
      0.75: '0.75x',
      1: '1x',
      1.25: '1.25x',
      1.5: '1.5x',
      1.75: '1.75x',
      2: '2x',
    };

    return BlocBuilder<AudioPlayerCubit, AudioPlayerState>(
      builder: (BuildContext context, AudioPlayerState state) {
        final isActive = state.audioNote?.meta.id == journalAudio.meta.id;
        final cubit = context.read<AudioPlayerCubit>();

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                IconButton(
                  icon: const Icon(Icons.play_arrow_rounded),
                  iconSize: 32,
                  tooltip: 'Play',
                  color: (state.status == AudioPlayerStatus.playing && isActive)
                      ? context.colorScheme.error
                      : context.colorScheme.outline,
                  onPressed: () {
                    cubit
                      ..setAudioNote(journalAudio)
                      ..play();
                  },
                ),
                IgnorePointer(
                  ignoring: !isActive,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      IconButton(
                        icon: const Icon(Icons.pause_rounded),
                        iconSize: 32,
                        tooltip: 'Pause',
                        color: context.colorScheme.outline,
                        onPressed: cubit.pause,
                      ),
                      IconButton(
                        icon: Text(
                          speedLabelMap[state.speed] ?? '1x',
                          style: TextStyle(
                            fontFamily: 'Oswald',
                            fontWeight: FontWeight.bold,
                            color: (state.speed != 1)
                                ? context.colorScheme.error
                                : context.colorScheme.outline,
                          ),
                        ),
                        iconSize: 32,
                        tooltip: 'Toggle speed',
                        onPressed: () =>
                            cubit.setSpeed(speedToggleMap[state.speed] ?? 1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 250,
                  child: ProgressBar(
                    progress: isActive ? state.progress : Duration.zero,
                    total: journalAudio.data.duration,
                    progressBarColor: Colors.red,
                    baseBarColor: Colors.white.withOpacity(0.24),
                    bufferedBarColor: Colors.white.withOpacity(0.24),
                    thumbColor: Colors.white,
                    barHeight: 3,
                    thumbRadius: 5,
                    onSeek: cubit.seek,
                    timeLabelTextStyle: monospaceTextStyle.copyWith(
                      color: context.colorScheme.outline,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
