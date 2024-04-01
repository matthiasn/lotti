import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/audio/recorder_cubit.dart';
import 'package:lotti/blocs/audio/recorder_state.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/widgets/audio/transcription_progress_modal.dart';
import 'package:lotti/widgets/audio/vu_meter.dart';
import 'package:visibility_detector/visibility_detector.dart';

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

        Future<void> stop() async {
          await cubit.stop();

          final autoTranscribe = await getIt<JournalDb>().getConfigFlag(
            autoTranscribeFlag,
          );

          if (autoTranscribe) {
            if (!context.mounted) return;
            await TranscriptionProgressModal.show(context);
          }

          getIt<NavService>().beamBack();
        }

        return VisibilityDetector(
          key: const Key('audio_Recorder'),
          onVisibilityChanged: (VisibilityInfo info) {
            cubit.setIndicatorVisible(
              showIndicator: info.visibleBounds == Rect.zero,
            );
          },
          child: Column(
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
                  style: monospaceTextStyleLarge.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  IconButton(
                    key: const Key('pauseIcon'),
                    icon: Icon(
                      Icons.pause_rounded,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    padding: const EdgeInsets.only(
                      left: 8,
                      top: 8,
                      bottom: 8,
                      right: 29,
                    ),
                    iconSize: iconSize,
                    tooltip: 'Pause',
                    onPressed: cubit.pause,
                  ),
                  IconButton(
                    key: const Key('stopIcon'),
                    icon: Icon(
                      Icons.stop_rounded,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    padding: const EdgeInsets.only(
                      left: 29,
                      top: 8,
                      bottom: 8,
                      right: 8,
                    ),
                    iconSize: iconSize,
                    tooltip: 'Stop',
                    onPressed: stop,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
