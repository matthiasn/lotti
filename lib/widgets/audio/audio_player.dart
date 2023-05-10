import 'dart:io';

import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/audio/player_cubit.dart';
import 'package:lotti/blocs/audio/player_state.dart';
import 'package:lotti/blocs/journal/entry_cubit.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';

class AudioPlayerWidget extends StatelessWidget {
  const AudioPlayerWidget(this.journalAudio, {super.key});

  final JournalAudio journalAudio;

  @override
  Widget build(BuildContext context) {
    final speedToggleMap = <double, double>{
      0.5: 0.75,
      0.75: 1,
      1: 1.25,
      1.25: 1.5,
      1.5: 1.75,
      1.75: 2,
      2: 0.5,
    };

    final speedLabelMap = <double, String>{
      0.5: '0.5x',
      0.75: '0.75x',
      1: '1x',
      1.25: '1.25x',
      1.5: '1.5x',
      1.75: '1.75x',
      2: '2x',
    };

    return BlocBuilder<AudioPlayerCubit, AudioPlayerState>(
      builder: (BuildContext context, AudioPlayerState state) {
        final isActive = state.audioNote?.meta.id == journalAudio.meta.id;
        final cubit = context.read<AudioPlayerCubit>();
        final entryCubit = context.read<EntryCubit>();
        final transcripts = journalAudio.data.transcripts;

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                IconButton(
                  icon: const Icon(Icons.play_arrow),
                  iconSize: 32,
                  tooltip: 'Play',
                  color: (state.status == AudioPlayerStatus.playing && isActive)
                      ? styleConfig().activeAudioControl
                      : styleConfig().secondaryTextColor,
                  onPressed: () {
                    cubit
                      ..setAudioNote(journalAudio)
                      ..play();
                  },
                ),
                IgnorePointer(
                  ignoring: !isActive,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      IconButton(
                        icon: const Icon(Icons.fast_rewind),
                        iconSize: 32,
                        tooltip: 'Rewind 15s',
                        color: styleConfig().secondaryTextColor,
                        onPressed: cubit.rew,
                      ),
                      IconButton(
                        icon: const Icon(Icons.pause),
                        iconSize: 32,
                        tooltip: 'Pause',
                        color: styleConfig().secondaryTextColor,
                        onPressed: cubit.pause,
                      ),
                      IconButton(
                        icon: const Icon(Icons.fast_forward),
                        iconSize: 32,
                        tooltip: 'Fast forward 15s',
                        color: styleConfig().secondaryTextColor,
                        onPressed: cubit.fwd,
                      ),
                      IconButton(
                        icon: const Icon(Icons.stop),
                        iconSize: 32,
                        tooltip: 'Stop',
                        color: styleConfig().secondaryTextColor,
                        onPressed: cubit.stopPlay,
                      ),
                      IconButton(
                        icon: Text(
                          speedLabelMap[state.speed] ?? '1x',
                          style: TextStyle(
                            fontFamily: 'Oswald',
                            fontWeight: FontWeight.bold,
                            color: (state.speed != 1)
                                ? styleConfig().activeAudioControl
                                : styleConfig().secondaryTextColor,
                          ),
                        ),
                        iconSize: 32,
                        tooltip: 'Toggle speed',
                        onPressed: () =>
                            cubit.setSpeed(speedToggleMap[state.speed] ?? 1),
                      ),
                    ],
                  ),
                ),
                if (Platform.isMacOS)
                  IconButton(
                    icon: const Icon(Icons.transcribe_outlined),
                    iconSize: 20,
                    tooltip: 'Transcribe',
                    color: styleConfig().secondaryTextColor,
                    onPressed: () async {
                      await cubit.setAudioNote(journalAudio);
                      await cubit.transcribe();
                      await Future<void>.delayed(
                        const Duration(milliseconds: 100),
                      );
                      entryCubit
                        ..setController()
                        ..emitState();
                    },
                  ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 250,
                  child: ProgressBar(
                    progress: isActive ? state.progress : Duration.zero,
                    total: journalAudio.data.duration,
                    progressBarColor: Colors.red,
                    baseBarColor: Colors.white.withOpacity(0.24),
                    bufferedBarColor: Colors.white.withOpacity(0.24),
                    thumbColor: Colors.white,
                    barHeight: 3,
                    thumbRadius: 5,
                    onSeek: cubit.seek,
                    timeLabelTextStyle: monospaceTextStyle().copyWith(
                      color: styleConfig().secondaryTextColor,
                    ),
                  ),
                ),
              ],
            ),
            if (transcripts?.isNotEmpty ?? false)
              Column(
                children: [
                  const SizedBox(height: 10),
                  ...transcripts!.map(
                    TranscriptListItem.new,
                  ),
                ],
              ),
          ],
        );
      },
    );
  }
}

class TranscriptListItem extends StatefulWidget {
  const TranscriptListItem(
    this.transcript, {
    super.key,
  });

  final AudioTranscript transcript;

  @override
  State<TranscriptListItem> createState() => _TranscriptListItemState();
}

class _TranscriptListItemState extends State<TranscriptListItem> {
  bool show = false;

  void toggleShow() {
    setState(() {
      show = !show;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 2,
        horizontal: 30,
      ),
      child: Column(
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: toggleShow,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${dfShorter.format(widget.transcript.created)}  '
                    '${formatSeconds(widget.transcript.processingTime)}  '
                    'Language: ${widget.transcript.detectedLanguage}    ',
                    style: transcriptHeaderStyle(),
                  ),
                  Text(
                    '${widget.transcript.library}, '
                    ' ${widget.transcript.model}',
                    style: transcriptHeaderStyle(),
                  ),
                  if (show)
                    const Icon(
                      Icons.keyboard_double_arrow_up_outlined,
                      size: 15,
                    )
                  else
                    const Icon(
                      Icons.keyboard_double_arrow_down_outlined,
                      size: 15,
                    ),
                ],
              ),
            ),
          ),
          if (show)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SelectableText(
                widget.transcript.transcript,
                style: transcriptStyle(),
              ),
            ),
        ],
      ),
    );
  }
}
