import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
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
import 'package:lotti/utils/modals.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

class AudioRecordingModal {
  static Future<void> show(
    BuildContext context, {
    String? linkedId,
    String? categoryId,
    bool useRootNavigator = true,
  }) async {
    // Set modal visible before showing
    final cubit = context.read<AudioRecorderCubit>()
      ..setModalVisible(modalVisible: true);

    try {
      await WoltModalSheet.show<void>(
        context: context,
        useRootNavigator: useRootNavigator,
        pageListBuilder: (modalSheetContext) {
          return [
            _buildRecordingPage(
              context,
              linkedId: linkedId,
              categoryId: categoryId,
            ),
          ];
        },
        modalTypeBuilder: ModalUtils.modalTypeBuilder,
      );
    } finally {
      // Always set modal not visible when closed, regardless of how it was closed
      cubit.setModalVisible(modalVisible: false);
    }
  }

  static WoltModalSheetPage _buildRecordingPage(
    BuildContext context, {
    String? linkedId,
    String? categoryId,
  }) {
    final theme = Theme.of(context);

    return WoltModalSheetPage(
      backgroundColor: theme.colorScheme.surfaceContainer,
      hasSabGradient: false,
      isTopBarLayerAlwaysVisible: false,
      navBarHeight: 0,
      child: Theme(
        data: theme,
        child: AudioRecordingModalContent(
          linkedId: linkedId,
          categoryId: categoryId,
        ),
      ),
    );
  }
}

class AudioRecordingModalContent extends ConsumerWidget {
  const AudioRecordingModalContent({
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
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Main content
          BlocBuilder<AudioRecorderCubit, AudioRecorderState>(
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
                  Navigator.of(context).pop(); // Close modal first
                  await TranscriptionProgressModal.show(context);

                  if (entryId != null) {
                    await Future<void>.delayed(
                        const Duration(milliseconds: 100));
                    final provider = entryControllerProvider(id: entryId);
                    ref.read(provider.notifier)
                      ..setController()
                      ..emitState();
                  }
                } else {
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                }

                getIt<NavService>().beamBack();
              }

              final isRecording =
                  state.status == AudioRecorderStatus.recording ||
                      state.status == AudioRecorderStatus.paused;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // VU Meter
                  AnalogVuMeter(
                    decibels: state.decibels,
                    size: 400,
                    colorScheme: theme.colorScheme,
                  ),

                  // Duration display

                  Text(
                    formatDuration(state.progress.toString()),
                    style: GoogleFonts.inconsolata(
                      fontSize: fontSizeLarge,
                      fontWeight: FontWeight.w300,
                      color: theme.colorScheme.primaryFixedDim,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Control buttons in a row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Language selector - compact
                      Container(
                        height: 48, // Same height as record/stop button
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          borderRadius:
                              BorderRadius.circular(24), // Same radius
                          border: Border.all(
                            color: theme.colorScheme.outline
                                .withValues(alpha: 0.3),
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onTap: () => _showLanguageMenu(
                                context, cubit, state.language ?? ''),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.language,
                                    color: theme.colorScheme.onSurfaceVariant,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _getLanguageDisplay(state.language ?? ''),
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurface,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.keyboard_arrow_down,
                                    color: theme.colorScheme.onSurfaceVariant,
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 20),
                      // Record/Stop button
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: isRecording
                            ? _buildStopButton(context, stop, theme)
                            : _buildRecordButton(context, cubit, theme),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStopButton(
      BuildContext context, VoidCallback onTap, ThemeData theme) {
    return GestureDetector(
      key: const ValueKey('stop'),
      onTap: onTap,
      child: Container(
        width: 120,
        height: 48,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.6),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'STOP',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecordButton(
      BuildContext context, AudioRecorderCubit cubit, ThemeData theme) {
    return GestureDetector(
      key: const ValueKey('record'),
      onTap: () => cubit.record(linkedId: linkedId),
      child: Container(
        width: 120,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.red,
            width: 2,
          ),
        ),
        child: const Center(
          child: Text(
            'RECORD',
            style: TextStyle(
              color: Colors.red,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }

  String _getLanguageDisplay(String language) {
    switch (language) {
      case 'en':
        return 'English';
      case 'de':
        return 'Deutsch';
      default:
        return 'Auto';
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
                fontSize: 14,
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
}
