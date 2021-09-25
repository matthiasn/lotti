import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AudioPage extends StatefulWidget {
  const AudioPage({Key? key}) : super(key: key);

  @override
  State<AudioPage> createState() => _AudioPageState();
}

class _AudioPageState extends State<AudioPage> {
  @override
  void initState() {
    super.initState();
  }

  void _record() async {
    print('record');
  }

  void _play() async {
    print('play');
  }

  void _pause() async {
    print('pause');
  }

  void _stop() async {
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
