import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/blocs/audio/recorder_cubit.dart';
import 'package:lotti/blocs/audio/recorder_state.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/widgets/audio/transcription_progress_modal.dart';
import 'package:lotti/widgets/audio/vu_meter.dart';
import 'package:visibility_detector/visibility_detector.dart';

const double iconSize = 64;

class AudioRecorderWidget extends ConsumerWidget {
  const AudioRecorderWidget({
    super.key,
    this.linkedId,
  });

  final String? linkedId;

  String formatDuration(String str) {
    return str.substring(0, str.length - 7);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BlocBuilder<AudioRecorderCubit, AudioRecorderState>(
      builder: (context, state) {
        final cubit = context.read<AudioRecorderCubit>();

        Future<void> stop() async {
          final entryId = await cubit.stop();

          final autoTranscribe = await getIt<JournalDb>().getConfigFlag(
            autoTranscribeFlag,
          );

          if (autoTranscribe) {
            if (!context.mounted) return;
            await TranscriptionProgressModal.show(context);

            if (entryId != null) {
              await Future<void>.delayed(const Duration(milliseconds: 100));
              final provider = entryControllerProvider(id: entryId);
              ref.read(provider.notifier)
                ..setController()
                ..emitState();
            }
          }

          getIt<NavService>().beamBack();
        }

        final textStyle = monospaceTextStyleLarge.copyWith(
          color: context.colorScheme.outline,
        );

        return VisibilityDetector(
          key: const Key('audio_Recorder'),
          onVisibilityChanged: (VisibilityInfo info) {
            debugPrint('visibleBounds: ${info.visibleBounds}');
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
                  style: textStyle,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  IconButton(
                    key: const Key('pauseIcon'),
                    icon: Icon(
                      Icons.pause_rounded,
                      color: context.colorScheme.outline,
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
                      color: context.colorScheme.outline,
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
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.language,
                    color: context.colorScheme.outline,
                  ),
                  const SizedBox(width: 20),
                  DropdownButton(
                    value: state.language,
                    iconEnabledColor: context.colorScheme.outline,
                    items: [
                      DropdownMenuItem(
                        value: '',
                        child: Text(
                          'auto',
                          style: textStyle,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'en',
                        child: Text(
                          'English',
                          style: textStyle,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'de',
                        child: Text(
                          'Deutsch',
                          style: textStyle,
                        ),
                      ),
                    ],
                    onChanged: (String? value) {
                      if (value != null) {
                        cubit.setLanguage(value);
                      }
                    },
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
