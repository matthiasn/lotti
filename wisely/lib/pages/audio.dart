import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:flutter_sound/public/flutter_sound_recorder.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wisely/theme.dart';

class AudioPage extends StatefulWidget {
  const AudioPage({Key? key}) : super(key: key);

  @override
  State<AudioPage> createState() => _AudioPageState();
}

class _AudioPageState extends State<AudioPage> {
  AudioPlayer _audioPlayer = AudioPlayer();
  FlutterSoundRecorder? _myRecorder = FlutterSoundRecorder();
  bool _mRecorderIsInited = false;
  bool _isRecording = false;
  bool _isPlaying = false;

  Duration totalDuration = Duration(minutes: 0);
  Duration progress = Duration(minutes: 0);

  @override
  void initState() {
    super.initState();
    // Be careful : openAudioSession return a Future.
    // Do not access your FlutterSoundPlayer or FlutterSoundRecorder before the completion of the Future

    _myRecorder?.openAudioSession().then((value) {
      setState(() {
        _mRecorderIsInited = true;
      });
    });
  }

  @override
  void dispose() {
    // Be careful : you must `close` the audio session when you have finished with it.
    _myRecorder?.closeAudioSession();
    _myRecorder = null;
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _record() async {
    var docDir = await getApplicationDocumentsDirectory();
    String _path = '${docDir.path}/flutter_sound.aac';
    print('RECORD: ${_path}');

    await _myRecorder
        ?.startRecorder(
          toFile: _path,
          codec: Codec.aacADTS,
        )
        .then((value) => setState(() {
              _isRecording = true;
            }));
  }

  Future<void> _stopRecorder() async {
    await _myRecorder?.stopRecorder().then((value) => setState(() {
          _isRecording = false;
        }));
  }

  _playLocal() async {
    var docDir = await getApplicationDocumentsDirectory();
    String localPath = '${docDir.path}/flutter_sound.aac';
    Duration? duration = await _audioPlayer.setFilePath(localPath);
    if (duration != null) {
      totalDuration = duration;
    }
    print('Player PLAY duration: ${totalDuration}');
    await _audioPlayer.setSpeed(1.2);

    _audioPlayer.positionStream.listen((event) {
      setState(() {
        progress = event;
      });
    });
    _audioPlayer.playbackEventStream.listen((event) {
      print(event);
    });

    await _audioPlayer.play();
    setState(() {
      _isPlaying = true;
    });
  }

  Future<void> _stopPlayer() async {
    await _audioPlayer.stop();
    setState(() {
      _isPlaying = false;
    });
    print('Player STOP');
  }

  void _pause() async {
    await _audioPlayer.pause();
    print('Player PAUSE');
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (_mRecorderIsInited) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                IconButton(
                  icon: const Icon(Icons.mic_rounded),
                  iconSize: 40.0,
                  tooltip: 'Record',
                  color: _isRecording
                      ? AppColors.activeAudioControl
                      : AppColors.inactiveAudioControl,
                  onPressed: _record,
                ),
                IconButton(
                  icon: const Icon(Icons.stop),
                  iconSize: 40.0,
                  tooltip: 'Stop',
                  color: AppColors.inactiveAudioControl,
                  onPressed: _stopRecorder,
                ),
              ],
            ),
          ],
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
                onPressed: _pause,
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
                onPressed: _pause,
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
                    //_player.seek(duration);
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
