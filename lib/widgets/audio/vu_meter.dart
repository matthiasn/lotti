import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:lotti/blocs/audio/recorder_cubit.dart';
import 'package:lotti/blocs/audio/recorder_state.dart';

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
