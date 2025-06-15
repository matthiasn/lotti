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
    required this.linkedId,
    super.key,
    this.categoryId,
  });

  final String? linkedId;
  final String? categoryId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLow,
      body: SafeArea(
        child: Column(
          children: [
            // Custom app bar with recording state
            BlocBuilder<AudioRecorderCubit, AudioRecorderState>(
              builder: (context, state) {
                final isRecording =
                    state.status == AudioRecorderStatus.recording ||
                        state.status == AudioRecorderStatus.paused;

                return Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          size: 24,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      if (isRecording)
                        const RecordingIndicator()
                      else
                        const SizedBox(width: 32, height: 32),
                    ],
                  ),
                );
              },
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
      end: 1,
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
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.red,
            boxShadow: [
              BoxShadow(
                color: Colors.red.withValues(alpha: 0.6 * _animation.value),
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

  String _getLanguageDisplay(String language) {
    switch (language) {
      case 'en':
        return 'English';
      case 'de':
        return 'Deutsch';
      default:
        return 'Auto-detect';
    }
  }

  void _showLanguageMenu(
      BuildContext context, AudioRecorderCubit cubit, String currentLanguage) {
    final theme = Theme.of(context);
    final button = context.findRenderObject()! as RenderBox;
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero),
            ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: context,
      position: position,
      color: theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.5),
        ),
      ),
      elevation: 8,
      items: [
        _buildMenuItem(
            '', 'Auto-detect', currentLanguage == '', theme.colorScheme),
        _buildMenuItem(
            'en', 'English', currentLanguage == 'en', theme.colorScheme),
        _buildMenuItem(
            'de', 'Deutsch', currentLanguage == 'de', theme.colorScheme),
      ],
    ).then((String? value) {
      if (value != null) {
        cubit.setLanguage(value);
      }
    });
  }

  PopupMenuItem<String> _buildMenuItem(
      String value, String label, bool isSelected, ColorScheme colorScheme) {
    return PopupMenuItem<String>(
      value: value,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                fontSize: fontSizeMedium,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            const Spacer(),
            if (isSelected)
              Icon(
                Icons.check,
                color: colorScheme.primary,
                size: 16,
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BlocBuilder<AudioRecorderCubit, AudioRecorderState>(
      builder: (context, state) {
        final theme = Theme.of(context);
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
                // VU Meter with responsive sizing
                LayoutBuilder(
                  builder: (context, constraints) {
                    // Calculate meter size based on available space
                    final screenWidth = constraints.maxWidth;

                    // Simple sizing: 85% of width with min/max constraints
                    final size = (screenWidth * 0.85).clamp(300.0, 500.0);

                    return AnalogVuMeter(
                      decibels: state.decibels,
                      size: size,
                      colorScheme: theme.colorScheme,
                    );
                  },
                ),
                const SizedBox(height: 30),
                // Duration display with responsive font size
                Text(
                  formatDuration(state.progress.toString()),
                  style: TextStyle(
                    color: theme.colorScheme.outline,
                    fontSize: fontSizeLarge,
                    fontWeight: FontWeight.w200,
                    fontFeatures: const [
                      FontFeature.tabularFigures(),
                    ],
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 40),
                // Control buttons with responsive size
                LayoutBuilder(
                  builder: (context, constraints) {
                    final buttonWidth =
                        (constraints.maxWidth * 0.5).clamp(180.0, 220.0);
                    final buttonHeight = (buttonWidth * 0.29).clamp(52.0, 64.0);

                    return SizedBox(
                      height: buttonHeight,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: isRecording
                            ? GestureDetector(
                                key: const ValueKey('stop'),
                                onTap: stop,
                                child: Container(
                                  width: buttonWidth,
                                  height: buttonHeight,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        theme.colorScheme
                                            .surfaceContainerHighest,
                                        theme.colorScheme.surface,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(32),
                                    border: Border.all(
                                      color: theme.colorScheme.outline
                                          .withValues(alpha: 0.2),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            Colors.black.withValues(alpha: 0.5),
                                        blurRadius: 15,
                                        offset: const Offset(0, 8),
                                      ),
                                      BoxShadow(
                                        color:
                                            Colors.white.withValues(alpha: 0.1),
                                        blurRadius: 1,
                                        offset: const Offset(0, -1),
                                      ),
                                    ],
                                  ),
                                  child: Stack(
                                    children: [
                                      Center(
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                color: Colors.red.shade400,
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.red
                                                        .withValues(alpha: 0.6),
                                                    blurRadius: 4,
                                                    spreadRadius: 1,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              'STOP',
                                              style: TextStyle(
                                                color:
                                                    theme.colorScheme.onSurface,
                                                fontSize: fontSizeMedium,
                                                fontWeight: FontWeight.w500,
                                                letterSpacing: 1,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : GestureDetector(
                                key: const ValueKey('record'),
                                onTap: () => cubit.record(linkedId: linkedId),
                                child: Container(
                                  width: buttonWidth,
                                  height: buttonHeight,
                                  decoration: BoxDecoration(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(32),
                                    border: Border.all(
                                      color: Colors.red.withValues(alpha: 0.8),
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            Colors.red.withValues(alpha: 0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      'RECORD',
                                      style: TextStyle(
                                        color: Colors.red.shade300,
                                        fontSize: fontSizeMedium,
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 40),
                // Language selector with custom styling
                Builder(
                  builder: (buttonContext) => Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () {
                          // Show custom dropdown
                          _showLanguageMenu(
                              buttonContext, cubit, state.language ?? '');
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.language,
                                color: theme.colorScheme.onSurfaceVariant,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _getLanguageDisplay(state.language ?? ''),
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface,
                                  fontSize: fontSizeMedium,
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: 0,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.keyboard_arrow_down,
                                color: theme.colorScheme.onSurfaceVariant,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
