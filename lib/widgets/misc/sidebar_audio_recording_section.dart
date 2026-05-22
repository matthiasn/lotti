import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/features/speech/ui/widgets/recording/audio_recording_modal.dart';
import 'package:lotti/features/speech/ui/widgets/recording/audio_recording_orb.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart' show numericBadgeFontFeatures;

final FutureProviderFamily<JournalEntity?, String>
sidebarAudioRecordingLinkedEntryProvider = FutureProvider.autoDispose
    .family<JournalEntity?, String>((ref, id) {
      return getIt<JournalDb>().journalEntityById(id);
    });

bool sidebarAudioRecordingHasVisibleContent(WidgetRef ref) {
  final state = ref.watch(audioRecorderControllerProvider);
  return state.status == AudioRecorderStatus.recording && !state.modalVisible;
}

/// Inline audio recording panel rendered in the desktop sidebar's
/// `aboveSettings` slot whenever the microphone is active and the modal is
/// not already open.
///
/// The card intentionally mirrors `SidebarTimerSection`: title row, live
/// elapsed time, and a stop button. The leading orb is driven by the recorder's
/// live dBFS stream so background sidebar recording remains visually active
/// even when the user is working in another tab or route.
class SidebarAudioRecordingSection extends ConsumerWidget {
  const SidebarAudioRecordingSection({super.key});

  /// Matches `SidebarTimerSection.animationDuration` so the audio and timer
  /// cards collapse with the same rhythm.
  static const Duration animationDuration = Duration(milliseconds: 220);

  static const Key _hiddenKey = ValueKey('sidebar-audio-recording-hidden');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(audioRecorderControllerProvider);
    final shouldShow =
        state.status == AudioRecorderStatus.recording && !state.modalVisible;

    final child = shouldShow
        ? _SidebarAudioRecordingCard(
            key: const ValueKey('sidebar-audio-recording-card-visible'),
            state: state,
          )
        : const SizedBox.shrink(key: _hiddenKey);

    return AnimatedSize(
      duration: animationDuration,
      curve: Curves.easeInOut,
      alignment: Alignment.bottomCenter,
      child: AnimatedSwitcher(
        duration: animationDuration,
        switchInCurve: Curves.easeIn,
        switchOutCurve: Curves.easeOut,
        child: child,
      ),
    );
  }
}

class _SidebarAudioRecordingCard extends ConsumerWidget {
  const _SidebarAudioRecordingCard({
    required this.state,
    super.key,
  });

  final AudioRecorderState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final linkedId = state.linkedId;
    final linkedEntry = linkedId == null
        ? null
        : ref.watch(sidebarAudioRecordingLinkedEntryProvider(linkedId)).value;
    final title = _resolveTitle(
      linkedEntry: linkedEntry,
      fallback: messages.taskActionBarAudioRecordingActive,
    );
    final durationText = formatDuration(state.progress);

    return Semantics(
      container: true,
      liveRegion: true,
      label: messages.taskActionBarAudioRecordingActive,
      child: _SignalReactiveCardFrame(
        dBFS: state.dBFS,
        child: Material(
          key: const Key('sidebar_audio_recording_card'),
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(tokens.radii.s),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => AudioRecordingModal.show(
              context,
              linkedId: linkedId,
              categoryId: linkedEntry?.meta.categoryId,
              useRootNavigator: false,
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                tokens.spacing.step4,
                tokens.spacing.step3,
                tokens.spacing.step3,
                tokens.spacing.step3,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _RecordingTitleRow(title: title),
                  SizedBox(height: tokens.spacing.step2),
                  _RecordingBodyRow(
                    dBFS: state.dBFS,
                    durationText: durationText,
                    onStop: () => unawaited(_stop(ref)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _resolveTitle({
    required JournalEntity? linkedEntry,
    required String fallback,
  }) {
    if (linkedEntry is Task) {
      final title = linkedEntry.data.title.trim();
      if (title.isNotEmpty) return title;
    }

    final linkedText = linkedEntry?.entryText?.plainText.trim();
    if (linkedText != null && linkedText.isNotEmpty) return linkedText;
    return fallback;
  }

  Future<void> _stop(WidgetRef ref) async {
    final controller = ref.read(audioRecorderControllerProvider.notifier);
    if (state.isRealtimeMode) {
      await controller.stopRealtime();
    } else {
      await controller.stop();
    }
  }
}

class _SignalReactiveCardFrame extends StatelessWidget {
  const _SignalReactiveCardFrame({
    required this.dBFS,
    required this.child,
  });

  final double dBFS;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final signalLevel = AudioRecordingSignalLevel.fromDbfs(dBFS);
    final signal = signalLevel.normalized;
    final frameSignal = math.pow(signal, 3).toDouble();
    final color = tokens.colors.alert.error.defaultColor;
    final borderRadius = BorderRadius.circular(tokens.radii.s);
    final borderWidth = tokens.spacing.step1 * (0.25 + frameSignal * 0.75);
    final borderAlpha = (0.22 + frameSignal * 0.50).clamp(0.0, 0.78);
    final shadowAlpha = (0.04 + frameSignal * 0.12).clamp(0.0, 0.18);
    final backgroundAlpha = (0.08 + frameSignal * 0.05).clamp(0.0, 0.16);

    return AnimatedContainer(
      key: const Key('sidebar_audio_recording_card_frame'),
      duration: SidebarAudioRecordingSection.animationDuration,
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: color.withValues(alpha: backgroundAlpha),
        borderRadius: borderRadius,
        border: Border.all(
          color: color.withValues(alpha: borderAlpha),
          width: borderWidth,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: shadowAlpha),
            blurRadius:
                tokens.spacing.step3 + frameSignal * tokens.spacing.step5,
            spreadRadius: frameSignal * tokens.spacing.step1 * 0.5,
          ),
        ],
      ),
      child: child,
    );
  }
}

class _RecordingTitleRow extends StatelessWidget {
  const _RecordingTitleRow({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Text(
      title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: tokens.typography.styles.others.caption.copyWith(
        color: tokens.colors.text.mediumEmphasis,
      ),
    );
  }
}

class _RecordingBodyRow extends StatelessWidget {
  const _RecordingBodyRow({
    required this.dBFS,
    required this.durationText,
    required this.onStop,
  });

  final double dBFS;
  final String durationText;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final errorColor = tokens.colors.alert.error.defaultColor;

    return Row(
      children: [
        AudioRecordingOrb(
          dBFS: dBFS,
          size: tokens.spacing.step7,
        ),
        SizedBox(width: tokens.spacing.step3),
        Expanded(
          child: Text(
            durationText,
            style: tokens.typography.styles.subtitle.subtitle2.copyWith(
              color: errorColor,
              fontFeatures: numericBadgeFontFeatures,
            ),
          ),
        ),
        _StopAudioRecordingButton(onStop: onStop),
      ],
    );
  }
}

class _StopAudioRecordingButton extends StatelessWidget {
  const _StopAudioRecordingButton({required this.onStop});

  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final errorColor = tokens.colors.alert.error.defaultColor;
    final tooltip = context.messages.audioRecordingStop;

    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        excludeFromSemantics: true,
        child: Material(
          color: errorColor.withAlpha(40),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onStop,
            child: SizedBox.square(
              dimension: tokens.spacing.step7,
              child: Icon(
                Icons.stop_rounded,
                size: tokens.spacing.step5,
                color: errorColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
