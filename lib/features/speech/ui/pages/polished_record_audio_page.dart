import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/speech/state/recorder_cubit.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/features/speech/ui/widgets/analog_vu_meter.dart';
import 'package:lotti/features/speech/ui/widgets/transcription_progress_modal.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/consts.dart';
import 'package:visibility_detector/visibility_detector.dart';

class PolishedRecordAudioPage extends StatelessWidget {
  const PolishedRecordAudioPage({
    super.key,
    required this.linkedId,
    this.categoryId,
  });

  final String? linkedId;
  final String? categoryId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: SafeArea(
        child: Column(
          children: [
            // Custom app bar
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.grey,
                        size: 28,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const Text(
                    'AUDIO RECORDING',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                    ),
                  ),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: RecordingIndicator(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PolishedAudioRecorderWidget(
                linkedId: linkedId,
                categoryId: categoryId,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RecordingIndicator extends StatefulWidget {
  const RecordingIndicator({super.key});

  @override
  State<RecordingIndicator> createState() => _RecordingIndicatorState();
}

class _RecordingIndicatorState extends State<RecordingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);
    
    _animation = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.red,
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.6 * _animation.value),
                blurRadius: 8 + (4 * _animation.value),
                spreadRadius: 2 * _animation.value,
              ),
            ],
          ),
        );
      },
    );
  }
}

class PolishedAudioRecorderWidget extends ConsumerWidget {
  const PolishedAudioRecorderWidget({
    super.key,
    this.linkedId,
    this.categoryId,
  });

  final String? linkedId;
  final String? categoryId;

  String formatDuration(String str) {
    return str.substring(0, str.length - 7);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BlocBuilder<AudioRecorderCubit, AudioRecorderState>(
      builder: (context, state) {
        final cubit = context.read<AudioRecorderCubit>()
          ..setCategoryId(categoryId);

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

        final isRecording = state.status == AudioRecorderStatus.recording ||
                           state.status == AudioRecorderStatus.paused;

        return VisibilityDetector(
          key: const Key('polished_audio_recorder'),
          onVisibilityChanged: (VisibilityInfo info) {
            cubit.setIndicatorVisible(
              showIndicator: info.visibleBounds == Rect.zero,
            );
          },
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // VU Meter
                AnalogVuMeter(
                  decibels: state.decibels,
                  size: MediaQuery.of(context).size.width * 0.8,
                ),
                const SizedBox(height: 40),
                // Duration display
                Text(
                  formatDuration(state.progress.toString()),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.w200,
                    fontFamily: 'monospace',
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 60),
                // Control button - only one visible at a time
                if (isRecording)
                  GestureDetector(
                    onTap: stop,
                    child: Container(
                      width: 220,
                      height: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3A3A3A),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: Colors.grey.withOpacity(0.2),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          'STOP',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 3,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  GestureDetector(
                    onTap: () => cubit.record(linkedId: linkedId),
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.transparent,
                        border: Border.all(
                          color: Colors.grey.withOpacity(0.5),
                          width: 3,
                        ),
                      ),
                      child: Center(
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.red,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.4),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 80),
                // Language selector
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.language,
                      color: Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<String>(
                      value: state.language ?? '',
                      dropdownColor: const Color(0xFF2A2A2A),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                      underline: Container(),
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: Colors.grey,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: '',
                          child: Text(
                            'Auto',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'en',
                          child: Text(
                            'English',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'de',
                          child: Text(
                            'Deutsch', 
                            style: TextStyle(color: Colors.white),
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
          ),
        );
      },
    );
  }
}