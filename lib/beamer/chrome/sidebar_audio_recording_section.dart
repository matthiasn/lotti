import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/features/speech/state/recording_homes.dart';
import 'package:lotti/features/speech/state/recording_session.dart';
import 'package:lotti/features/speech/state/recording_subject.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/entry_tools.dart';
import 'package:lotti/widgets/misc/sidebar_live_card.dart';
import 'package:material_ui/material_ui.dart';

/// Whether a take is running for the sidebar's activity disclosure to
/// carry: one nothing draws in place — the rule the recording strip follows
/// ([takeAwayFromHome]).
bool sidebarAudioRecordingVisible(WidgetRef ref) => takeAwayFromHome(ref.watch);

/// The running take in the expanded desktop sidebar activity disclosure:
/// on a wide window it is where a take lives while the user is away from
/// the page it belongs to.
///
/// The card shares [SidebarLiveCard] with `SidebarTimerSection`: the red
/// accent, the microphone with its pulsing record dot (reduce-motion aware;
/// still, and *Paused*, while the take is paused), the subject's title, the
/// running time, and Stop. Its body takes the user
/// back to where the take started ([RecordingSession.returnToOrigin]), where
/// the take's own recorder shows; Stop saves it and puts up the receipt with
/// Undo ([RecordingSession.stop]).
class SidebarAudioRecordingSection extends ConsumerWidget {
  const SidebarAudioRecordingSection({super.key});

  /// Matches `SidebarTimerSection.animationDuration` so the audio and timer
  /// cards collapse with the same rhythm.
  static const Duration animationDuration = Duration(milliseconds: 220);

  static const Key cardKey = Key('sidebar_audio_recording_card');
  static const Key stopKey = Key('sidebar_audio_recording_stop');
  static const Key _hiddenKey = ValueKey('sidebar-audio-recording-hidden');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = sidebarAudioRecordingVisible(ref)
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
    final origin = ref.watch(
      audioRecorderControllerProvider.select((state) => state.origin),
    );
    final paused = ref.watch(
      audioRecorderControllerProvider.select(
        (state) => state.status == AudioRecorderStatus.paused,
      ),
    );
    // Whole seconds, which is all the card shows.
    final progress = Duration(
      seconds: ref.watch(
        audioRecorderControllerProvider.select(
          (state) => state.progress.inSeconds,
        ),
      ),
    );
    final tokens = context.designTokens;
    final messages = context.messages;
    final errorColor = tokens.colors.alert.error.defaultColor;
    final subject = linkedId == null
        ? null
        : ref.watch(recordingSubjectProvider(linkedId)).value;
    final title =
        recordingSubjectTitle(subject) ?? messages.recordingStripVoiceNote;
    final session = ref.read(recordingSessionProvider);

    return SidebarLiveCard(
      key: SidebarAudioRecordingSection.cardKey,
      accent: errorColor,
      glyph: LottiIcons.mic,
      // A paused take neither pulses nor says it is recording.
      statusLabel: paused
          ? messages.recordingStripPausedFor
          : messages.sidebarAudioRecordingStatusLabel,
      title: title,
      timeText: formatDuration(progress),
      pulse: !paused,
      liveRegion: true,
      semanticsLabel: paused
          ? messages.recordingStripPausedFor
          : messages.taskActionBarAudioRecordingActive,
      // A take with no origin has nowhere to go back to.
      onTap: origin == null ? null : () async => session.returnToOrigin(origin),
      trailing: _StopAudioRecordingButton(onStop: session.stop),
    );
  }
}

class _StopAudioRecordingButton extends StatelessWidget {
  const _StopAudioRecordingButton({required this.onStop});

  final Future<void> Function() onStop;

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
            key: SidebarAudioRecordingSection.stopKey,
            customBorder: const CircleBorder(),
            onTap: onStop,
            // The timer card's stop circle: 28 across, the glyph 16.
            child: SizedBox.square(
              dimension: tokens.spacing.step6 + tokens.spacing.step2,
              child: Icon(
                LottiIcons.stop,
                size: IconSizes.s,
                color: errorColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
