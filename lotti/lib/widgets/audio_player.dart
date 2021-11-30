import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/audio/player_cubit.dart';
import 'package:lotti/blocs/audio/player_state.dart';
import 'package:lotti/theme.dart';

class AudioPlayerWidget extends StatelessWidget {
  const AudioPlayerWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AudioPlayerCubit, AudioPlayerState>(
        builder: (BuildContext context, AudioPlayerState state) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                IconButton(
                  icon: const Icon(Icons.play_arrow),
                  iconSize: 40.0,
                  tooltip: 'Play',
                  color: (state.status == AudioPlayerStatus.playing)
                      ? AppColors.activeAudioControl
                      : AppColors.inactiveAudioControl,
                  onPressed: () => context.read<AudioPlayerCubit>().play(),
                ),
                IconButton(
                  icon: const Icon(Icons.fast_rewind),
                  iconSize: 40.0,
                  tooltip: 'Rewind 15s',
                  color: AppColors.inactiveAudioControl,
                  onPressed: () => context.read<AudioPlayerCubit>().rew(),
                ),
                IconButton(
                  icon: const Icon(Icons.pause),
                  iconSize: 40.0,
                  tooltip: 'Pause',
                  color: AppColors.inactiveAudioControl,
                  onPressed: () => context.read<AudioPlayerCubit>().pause(),
                ),
                IconButton(
                  icon: const Icon(Icons.fast_forward),
                  iconSize: 40.0,
                  tooltip: 'Fast forward 15s',
                  color: AppColors.inactiveAudioControl,
                  onPressed: () => context.read<AudioPlayerCubit>().fwd(),
                ),
                IconButton(
                  icon: const Icon(Icons.stop),
                  iconSize: 40.0,
                  tooltip: 'Stop',
                  color: AppColors.inactiveAudioControl,
                  onPressed: () => context.read<AudioPlayerCubit>().stopPlay(),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 250,
                  child: ProgressBar(
                    progress: state.progress,
                    total: state.totalDuration,
                    progressBarColor: Colors.red,
                    baseBarColor: Colors.white.withOpacity(0.24),
                    bufferedBarColor: Colors.white.withOpacity(0.24),
                    thumbColor: Colors.white,
                    barHeight: 3.0,
                    thumbRadius: 5.0,
                    onSeek: (newPosition) {
                      context.read<AudioPlayerCubit>().seek(newPosition);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }
}
