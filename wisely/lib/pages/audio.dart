import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wisely/widgets/audio_player.dart';
import 'package:wisely/widgets/audio_recorder.dart';

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

  String formatDecibels(double? decibels) {
    var f = NumberFormat("###.0#", "en_US");
    return (decibels != null) ? '${f.format(decibels)} dB' : '';
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: const [
          AudioRecorderWidget(),
          AudioPlayerWidget(),
        ],
      ),
    );
  }
}
