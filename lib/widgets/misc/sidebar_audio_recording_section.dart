import 'dart:async';

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
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/misc/sidebar_live_card.dart';

final FutureProviderFamily<JournalEntity?, String>
sidebarAudioRecordingLinkedEntryProvider = FutureProvider.autoDispose
    .family<JournalEntity?, String>((ref, id) {
      return getIt<JournalDb>().journalEntityById(id);
    });

bool sidebarAudioRecordingHasVisibleContent(WidgetRef ref) {
  return ref.watch(
    audioRecorderControllerProvider.select(_recordingIsVisible),
  );
}

bool _recordingIsVisible(AudioRecorderState state) {
  return state.status == AudioRecorderStatus.recording && !state.modalVisible;
}

/// Inline audio recording panel rendered in the desktop sidebar's
/// `aboveSettings` slot whenever the microphone is active and the modal is
/// not already open.
///
/// The card shares [SidebarLiveCard] with `SidebarTimerSection`: a soft
/// accent-tinted card with an accent rail, a leading glyph, the linked title
/// (up to two lines), a prominent accent-coloured elapsed time, and a stop
/// button. Recording uses the red accent and a microphone glyph with a gentle
/// pulsing record dot (record convention, reduce-motion aware) — present and
/// unmistakable, but without the old signal-reactive orb/frame/glow.
class SidebarAudioRecordingSection extends ConsumerWidget {
  const SidebarAudioRecordingSection({super.key});

  /// Matches `SidebarTimerSection.animationDuration` so the audio and timer
  /// cards collapse with the same rhythm.
  static const Duration animationDuration = Duration(milliseconds: 220);

  static const Key _hiddenKey = ValueKey('sidebar-audio-recording-hidden');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shouldShow = ref.watch(
      audioRecorderControllerProvider.select(_recordingIsVisible),
    );

    final child = shouldShow
        ? const _SidebarAudioRecordingCard(
            key: ValueKey('sidebar-audio-recording-card-visible'),
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
  const _SidebarAudioRecordingCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final linkedId = ref.watch(
      audioRecorderControllerProvider.select((state) => state.linkedId),
    );
    final body = ref.watch(
      audioRecorderControllerProvider.select(
        (state) => (
          progress: state.progress,
          isRealtimeMode: state.isRealtimeMode,
        ),
      ),
    );
    final tokens = context.designTokens;
    final messages = context.messages;
    final errorColor = tokens.colors.alert.error.defaultColor;
    final linkedEntry = linkedId == null
        ? null
        : ref.watch(sidebarAudioRecordingLinkedEntryProvider(linkedId)).value;
    final title = _resolveTitle(
      linkedEntry: linkedEntry,
      fallback: messages.taskActionBarAudioRecordingActive,
    );
    final durationText = formatDuration(body.progress);

    // Red "live" accent card with a static mic glyph plus a gentle pulsing
    // record dot (record convention) — present without the old reactive orb,
    // and clearly distinct from the teal running timer.
    return SidebarLiveCard(
      key: const Key('sidebar_audio_recording_card'),
      accent: errorColor,
      glyph: Icons.mic_rounded,
      title: title,
      timeText: durationText,
      pulse: true,
      liveRegion: true,
      semanticsLabel: messages.taskActionBarAudioRecordingActive,
      onTap: () => AudioRecordingModal.show(
        context,
        linkedId: linkedId,
        categoryId: linkedEntry?.categoryId,
        useRootNavigator: false,
      ),
      trailing: _StopAudioRecordingButton(
        onStop: () => unawaited(
          _stop(ref, isRealtimeMode: body.isRealtimeMode),
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

  Future<void> _stop(
    WidgetRef ref, {
    required bool isRealtimeMode,
  }) async {
    final controller = ref.read(audioRecorderControllerProvider.notifier);
    if (isRealtimeMode) {
      await controller.stopRealtime();
    } else {
      await controller.stop();
    }
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

    // Stopping a recording is consequential, so this control keeps the
    // destructive red — the one place red survives in the calmed-down card.
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        excludeFromSemantics: true,
        child: Material(
          color: errorColor.withValues(alpha: 0.16),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onStop,
            child: SizedBox(
              width: 28,
              height: 28,
              child: Icon(
                Icons.stop_rounded,
                size: 16,
                color: errorColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
