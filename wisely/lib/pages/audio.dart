import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wisely/blocs/audio_recorder_cubit.dart';
import 'package:wisely/theme.dart';

class AudioPage extends StatefulWidget {
  const AudioPage({Key? key}) : super(key: key);

  @override
  State<AudioPage> createState() => _AudioPageState();
}

class _AudioPageState extends State<AudioPage> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;

  Duration totalDuration = Duration(minutes: 0);
  Duration progress = Duration(minutes: 0);
  Duration pausedAt = Duration(minutes: 0);

  @override
  void initState() {
    super.initState();
    _audioPlayer.positionStream.listen((event) {
      setState(() {
        progress = event;
      });
    });
    _audioPlayer.playbackEventStream.listen((event) {
      print(event);
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playLocal() async {
    var docDir = await getApplicationDocumentsDirectory();
    String localPath = '${docDir.path}/flutter_sound.aac';
    Duration? duration = await _audioPlayer.setFilePath(localPath);
    if (duration != null) {
      totalDuration = duration;
    }
    print('Player PLAY duration: ${totalDuration}');
    await _audioPlayer.setSpeed(1.2);

    _audioPlayer.play();
    await _audioPlayer.seek(pausedAt);
    print('PLAY from progress: $progress');

    setState(() {
      _isPlaying = true;
    });
  }

  Future<void> _stopPlayer() async {
    await _audioPlayer.stop();
    setState(() {
      _isPlaying = false;
      progress = Duration(minutes: 0);
    });
    print('Player STOP');
  }

  void _pause() async {
    await _audioPlayer.pause();
    pausedAt = progress;
    print('Player PAUSE');
  }

  void _forward() async {
    await _audioPlayer
        .seek(Duration(milliseconds: progress.inMilliseconds + 15000));
    print('Player FORWARD 15s');
  }

  void _rewind() async {
    await _audioPlayer
        .seek(Duration(milliseconds: progress.inMilliseconds - 15000));
    print('Player REWIND 15s');
  }

  String formatDuration(String str) {
    return str.substring(0, str.length - 7);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          BlocBuilder<AudioRecorderCubit, AudioRecorderState>(
              builder: (context, state) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                IconButton(
                  icon: const Icon(Icons.mic_rounded),
                  iconSize: 40.0,
                  tooltip: 'Record',
                  color: state.isRecording
                      ? AppColors.activeAudioControl
                      : AppColors.inactiveAudioControl,
                  onPressed: () => context.read<AudioRecorderCubit>().record(),
                ),
                IconButton(
                  icon: const Icon(Icons.stop),
                  iconSize: 40.0,
                  tooltip: 'Stop',
                  color: AppColors.inactiveAudioControl,
                  onPressed: () => context.read<AudioRecorderCubit>().stop(),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    formatDuration(state.progress.toString()),
                    style: TextStyle(
                      fontFamily: 'ShareTechMono',
                      fontSize: 32.0,
                      color: AppColors.headerBgColor,
                    ),
                  ),
                ),
              ],
            );
          }),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              IconButton(
                icon: const Icon(Icons.play_arrow),
                iconSize: 40.0,
                tooltip: 'Play',
                color: _isPlaying
                    ? AppColors.activeAudioControl
                    : AppColors.inactiveAudioControl,
                onPressed: _playLocal,
              ),
              IconButton(
                icon: const Icon(Icons.fast_rewind),
                iconSize: 40.0,
                tooltip: 'Rewind 15s',
                color: AppColors.inactiveAudioControl,
                onPressed: _rewind,
              ),
              IconButton(
                icon: const Icon(Icons.pause),
                iconSize: 40.0,
                tooltip: 'Pause',
                color: AppColors.inactiveAudioControl,
                onPressed: _pause,
              ),
              IconButton(
                icon: const Icon(Icons.fast_forward),
                iconSize: 40.0,
                tooltip: 'Fast forward 15s',
                color: AppColors.inactiveAudioControl,
                onPressed: _forward,
              ),
              IconButton(
                icon: const Icon(Icons.stop),
                iconSize: 40.0,
                tooltip: 'Stop',
                color: AppColors.inactiveAudioControl,
                onPressed: _stopPlayer,
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 250,
                child: ProgressBar(
                  progress: progress,
                  total: totalDuration,
                  progressBarColor: Colors.red,
                  baseBarColor: Colors.white.withOpacity(0.24),
                  bufferedBarColor: Colors.white.withOpacity(0.24),
                  thumbColor: Colors.white,
                  barHeight: 3.0,
                  thumbRadius: 5.0,
                  onSeek: (duration) {
                    print(duration);
                    _audioPlayer.seek(duration);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
