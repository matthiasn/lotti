import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:flutter_sound/public/flutter_sound_recorder.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wisely/theme.dart';

class AudioPage extends StatefulWidget {
  const AudioPage({Key? key}) : super(key: key);

  @override
  State<AudioPage> createState() => _AudioPageState();
}

class _AudioPageState extends State<AudioPage> {
  AudioPlayer audioPlayer = AudioPlayer();
  FlutterSoundRecorder? _myRecorder = FlutterSoundRecorder();
  bool _mRecorderIsInited = false;
  bool _isRecording = false;
  bool _isPlaying = false;

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
    int result = await audioPlayer.play(localPath, isLocal: true);
    setState(() {
      _isPlaying = true;
    });
    print('Player PLAY: ${result}');
  }

  Future<void> _stopPlayer() async {
    int result = await audioPlayer.stop();
    setState(() {
      _isPlaying = false;
    });
    print('Player STOP: ${result}');
  }

  void _pause() async {
    int result = await audioPlayer.pause();
    print('Player PAUSE: ${result}');
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
        ],
      ),
    );
  }
}
