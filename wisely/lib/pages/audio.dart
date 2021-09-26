import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:flutter_sound/public/flutter_sound_player.dart';
import 'package:flutter_sound/public/flutter_sound_recorder.dart';
import 'package:path_provider/path_provider.dart';

class AudioPage extends StatefulWidget {
  const AudioPage({Key? key}) : super(key: key);

  @override
  State<AudioPage> createState() => _AudioPageState();
}

class _AudioPageState extends State<AudioPage> {
  FlutterSoundPlayer? _myPlayer = FlutterSoundPlayer();
  FlutterSoundRecorder? _myRecorder = FlutterSoundRecorder();
  bool _mPlayerIsInited = false;
  bool _mRecorderIsInited = false;
  String _mPath = '';

  @override
  void initState() {
    super.initState();
    // Be careful : openAudioSession return a Future.
    // Do not access your FlutterSoundPlayer or FlutterSoundRecorder before the completion of the Future
    _myPlayer?.openAudioSession().then((value) {
      setState(() {
        _mPlayerIsInited = true;
      });
    });

    _myRecorder?.openAudioSession().then((value) {
      setState(() {
        _mRecorderIsInited = true;
      });
    });
  }

  @override
  void dispose() {
    // Be careful : you must `close` the audio session when you have finished with it.
    _myPlayer?.closeAudioSession();
    _myPlayer = null;
    _myRecorder?.closeAudioSession();
    _myRecorder = null;
    super.dispose();
  }

  Future<void> _record() async {
    var tempDir = await getTemporaryDirectory();
    String _path = '${tempDir.path}/flutter_sound.aac';
    print('RECORD: ${_path}');

    await _myRecorder?.startRecorder(
      toFile: _path,
      codec: Codec.aacADTS,
    );
  }

  Future<void> stopRecorder() async {
    await _myRecorder?.stopRecorder();
  }

  void _play() async {
    var tempDir = await getTemporaryDirectory();
    String _path = '${tempDir.path}/flutter_sound.aac';
    print('PLAY: ${_path}');

    await _myPlayer?.startPlayer(
        fromURI: _mPath,
        codec: Codec.mp3,
        whenFinished: () {
          setState(() {});
        });
    setState(() {});
  }

  Future<void> _stopPlayer() async {
    if (_myPlayer != null) {
      await _myPlayer?.stopPlayer();
    }
  }

  void _pause() async {
    print('pause');
  }

  void _stop() async {
    stopRecorder();
    _stopPlayer();
    print('stop');
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          IconButton(
            icon: const Icon(Icons.mic_rounded),
            iconSize: 40.0,
            tooltip: 'Record',
            color: Colors.deepOrange,
            onPressed: _record,
          ),
          IconButton(
            icon: const Icon(Icons.play_arrow),
            iconSize: 40.0,
            tooltip: 'Play',
            onPressed: _play,
          ),
          IconButton(
            icon: const Icon(Icons.fast_rewind),
            iconSize: 40.0,
            tooltip: 'Rewind 15s',
            onPressed: _pause,
          ),
          IconButton(
            icon: const Icon(Icons.pause),
            iconSize: 40.0,
            tooltip: 'Pause',
            onPressed: _pause,
          ),
          IconButton(
            icon: const Icon(Icons.fast_forward),
            iconSize: 40.0,
            tooltip: 'Fast forward 15s',
            onPressed: _pause,
          ),
          IconButton(
            icon: const Icon(Icons.stop),
            iconSize: 40.0,
            tooltip: 'Stop',
            onPressed: _stop,
          ),
        ],
      ),
    );
  }
}
