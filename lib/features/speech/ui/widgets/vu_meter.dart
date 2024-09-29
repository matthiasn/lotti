import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/features/speech/state/recorder_cubit.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/themes/theme.dart';

class CustomRect extends CustomClipper<Rect> {
  CustomRect(this.heightFactor);
  double heightFactor;

  @override
  Rect getClip(Size size) {
    final rect = Rect.fromLTRB(
      0,
      size.height * (1 - heightFactor),
      size.width,
      size.height,
    );
    return rect;
  }

  @override
  bool shouldReclip(CustomRect oldClipper) {
    return true;
  }
}

const iconSize = 200.0;

class VuMeterButtonWidget extends StatelessWidget {
  const VuMeterButtonWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AudioRecorderCubit, AudioRecorderState>(
      builder: (context, state) {
        final hot = state.decibels > 130;
        final audioLevel = state.decibels / 160;

        return Padding(
          padding: const EdgeInsets.all(8),
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Icon(
                Icons.mic_rounded,
                size: iconSize,
                color: context.colorScheme.outline,
                semanticLabel: 'Microphone',
              ),
              if (!hot)
                ClipRect(
                  key: Key(state.decibels.toString()),
                  clipper: CustomRect(audioLevel),
                  child: Icon(
                    Icons.mic_rounded,
                    size: iconSize,
                    color: context.colorScheme.error.withOpacity(0.6),
                    semanticLabel: 'Microphone',
                  ),
                ),
              if (hot)
                ClipRect(
                  key: Key(state.decibels.toString()),
                  clipper: CustomRect(audioLevel),
                  child: Icon(
                    Icons.mic_rounded,
                    size: iconSize,
                    color: context.colorScheme.error,
                    semanticLabel: 'Microphone',
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
