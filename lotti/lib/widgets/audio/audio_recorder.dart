import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:lotti/blocs/audio/recorder_cubit.dart';
import 'package:lotti/blocs/audio/recorder_state.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/theme.dart';

const double iconSize = 64.0;

class AudioRecorderWidget extends StatelessWidget {
  const AudioRecorderWidget({
    Key? key,
    this.linked,
  }) : super(key: key);

  final JournalEntity? linked;

  String formatDuration(String str) {
    return str.substring(0, str.length - 7);
  }

  String formatDecibels(double? decibels) {
    var f = NumberFormat("###.0#", "en_US");
    return (decibels != null) ? '${f.format(decibels)} dB' : '';
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AudioRecorderCubit, AudioRecorderState>(
        builder: (context, state) {
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              IconButton(
                icon: const Icon(Icons.mic_rounded),
                iconSize: iconSize,
                tooltip: 'Record',
                color: state.status == AudioRecorderStatus.recording
                    ? AppColors.activeAudioControl
                    : AppColors.inactiveAudioControl,
                onPressed: () => context.read<AudioRecorderCubit>().record(),
              ),
              IconButton(
                icon: const Icon(Icons.stop),
                iconSize: iconSize,
                tooltip: 'Stop',
                color: AppColors.inactiveAudioControl,
                onPressed: () {
                  context.read<AudioRecorderCubit>().stop(linked: linked);
                  Navigator.pop(context);
                },
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  formatDuration(state.progress.toString()),
                  style: TextStyle(
                    fontFamily: 'ShareTechMono',
                    fontSize: 32.0,
                    color: AppColors.inactiveAudioControl,
                  ),
                ),
              ),
            ],
          ),
          VuMeterWidget(
            decibels: state.decibels,
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              formatDecibels(state.decibels),
              style: TextStyle(
                fontFamily: 'ShareTechMono',
                fontSize: 20.0,
                color: AppColors.inactiveAudioControl,
              ),
            ),
          ),
        ],
      );
    });
  }
}

class VuMeterWidget extends StatelessWidget {
  double decibels = 0;
  VuMeterWidget({Key? key, required this.decibels}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(8.0)),
      child: SizedBox(
        width: 280,
        child: LinearProgressIndicator(
          value: decibels / 160,
          minHeight: 16.0,
          color: (decibels > 130)
              ? AppColors.audioMeterPeakedBar
              : (decibels > 100)
                  ? AppColors.audioMeterTooHotBar
                  : AppColors.audioMeterBar,
          backgroundColor: AppColors.audioMeterBarBackground,
        ),
      ),
    );
  }
}
