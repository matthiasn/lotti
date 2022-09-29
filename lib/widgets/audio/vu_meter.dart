import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:lotti/blocs/audio/recorder_cubit.dart';
import 'package:lotti/blocs/audio/recorder_state.dart';
import 'package:lotti/themes/theme.dart';

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
                  ? styleConfig().audioMeterPeakedBar
                  : (state.decibels > 100)
                      ? styleConfig().audioMeterTooHotBar
                      : styleConfig().audioMeterBar,
              backgroundColor: styleConfig().audioMeterBarBackground,
            ),
          ),
        );
      },
    );
  }
}

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
              Padding(
                padding: const EdgeInsets.all(8),
                child: SvgPicture.asset('assets/icons/mic.svg'),
              ),
              if (!hot)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: ClipRect(
                    key: Key(state.decibels.toString()),
                    clipper: CustomRect(audioLevel),
                    child: SvgPicture.asset('assets/icons/mic_rec.svg'),
                  ),
                ),
              if (hot)
                ClipRect(
                  key: Key(state.decibels.toString()),
                  clipper: CustomRect(audioLevel),
                  child: SvgPicture.asset('assets/icons/mic_hot.svg'),
                ),
            ],
          ),
        );
      },
    );
  }
}
