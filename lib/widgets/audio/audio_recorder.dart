import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:lotti/blocs/audio/recorder_cubit.dart';
import 'package:lotti/blocs/audio/recorder_state.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/audio/vu_meter.dart';

const double iconSize = 64;

class AudioRecorderWidget extends StatelessWidget {
  const AudioRecorderWidget({
    super.key,
    this.linkedId,
  });

  final String? linkedId;

  String formatDuration(String str) {
    return str.substring(0, str.length - 7);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AudioRecorderCubit, AudioRecorderState>(
      builder: (context, state) {
        final cubit = context.read<AudioRecorderCubit>();

        return Column(
          children: [
            GestureDetector(
              key: const Key('micIcon'),
              onTap: () => cubit.record(linkedId: linkedId),
              child: const VuMeterButtonWidget(),
            ),
            Padding(
              padding: const EdgeInsets.all(30),
              child: Text(
                formatDuration(state.progress.toString()),
                style: monospaceTextStyleLarge(),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                IconButton(
                  key: const Key('pauseIcon'),
                  icon: SvgPicture.asset('assets/icons/pause.svg'),
                  padding: const EdgeInsets.only(
                    left: 8,
                    top: 8,
                    bottom: 8,
                    right: 29,
                  ),
                  iconSize: iconSize,
                  tooltip: 'Pause',
                  color: colorConfig().inactiveAudioControl,
                  onPressed: () {},
                ),
                IconButton(
                  key: const Key('stopIcon'),
                  icon: SvgPicture.asset('assets/icons/stop.svg'),
                  padding: const EdgeInsets.only(
                    left: 29,
                    top: 8,
                    bottom: 8,
                    right: 8,
                  ),
                  iconSize: iconSize,
                  tooltip: 'Stop',
                  color: colorConfig().inactiveAudioControl,
                  onPressed: () {
                    context.read<AudioRecorderCubit>().stop();
                    Navigator.of(context).maybePop();
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
