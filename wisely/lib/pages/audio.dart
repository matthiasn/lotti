import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:wisely/widgets/audio_player_stateless.dart';
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

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: const [
          AudioRecorderWidget(),
          AudioPlayerWidgetStateless(),
        ],
      ),
    );
  }
}
