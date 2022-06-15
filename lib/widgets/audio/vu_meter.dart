import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/audio/recorder_cubit.dart';
import 'package:lotti/blocs/audio/recorder_state.dart';
import 'package:lotti/theme.dart';

class VuMeterWidget extends StatelessWidget {
  const VuMeterWidget({
    super.key,
    this.height = 6,
    this.width = 140,
  });

  final double height;
  final double width;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AudioRecorderCubit, AudioRecorderState>(
      builder: (context, state) {
        return ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          child: SizedBox(
            width: width,
            child: LinearProgressIndicator(
              value: state.decibels / 160,
              minHeight: height,
              color: (state.decibels > 130)
                  ? AppColors.audioMeterPeakedBar
                  : (state.decibels > 100)
                      ? AppColors.audioMeterTooHotBar
                      : AppColors.audioMeterBar,
              backgroundColor: AppColors.audioMeterBarBackground,
            ),
          ),
        );
      },
    );
  }
}
