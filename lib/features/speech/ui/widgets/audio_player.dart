import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/audio_player_state.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/speech/state/audio_waveform_provider.dart';
import 'package:lotti/features/speech/ui/widgets/progress/audio_progress_bar.dart';
import 'package:lotti/features/speech/ui/widgets/progress/audio_waveform_scrubber.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/audio_player_controller.dart';
import 'package:lotti/themes/theme.dart' show numericBadgeFontFeatures;
import 'package:lotti/utils/entry_tools.dart';
import 'package:material_ui/material_ui.dart';

const List<double> _speedSequence = <double>[
  0.5,
  0.75,
  1,
  1.25,
  1.5,
  1.75,
  2,
];

/// Diameter of the circular play/pause control, which is also the height of
/// the whole player: everything else sits on its row.
const double _playControlDiameter = 40;

/// One-row audio player: play control, waveform, time and speed.
class AudioPlayerWidget extends ConsumerWidget {
  const AudioPlayerWidget(this.journalAudio, {super.key});

  final JournalAudio journalAudio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(audioPlayerControllerProvider);
    final controller = ref.read(audioPlayerControllerProvider.notifier);
    final isActive = state.audioNote?.meta.id == journalAudio.meta.id;

    final totalDuration = state.totalDuration == Duration.zero
        ? journalAudio.data.duration
        : state.totalDuration;
    final progress = isActive ? state.progress : Duration.zero;
    final buffered = isActive ? state.buffered : Duration.zero;
    final isPlaying = isActive && state.status == AudioPlayerStatus.playing;

    void handleTap() {
      if (!isActive) {
        // One queued operation, not two un-awaited calls: `play()` used to run
        // while `setAudioNote()` was still resolving this entry's path, so it
        // re-opened the *previously* selected recording and every card after
        // the first played the first one's audio.
        unawaited(controller.playAudioNote(journalAudio));
        return;
      }

      if (state.status == AudioPlayerStatus.playing) {
        controller.pause();
        return;
      }

      controller.play();
    }

    final tokens = context.designTokens;
    final speedLabel = _speedLabel(state.speed);

    // No outer padding: the player is a body section whose surrounding
    // spacing is owned by its container.
    return Row(
      children: <Widget>[
        _PlayButton(
          isPlaying: isPlaying,
          status: state.status,
          isActive: isActive,
          onPressed: handleTap,
        ),
        SizedBox(width: tokens.spacing.step3),
        Expanded(
          child: _WaveformArea(
            // Keyed by recording, so one recording's drawn waveform is never
            // carried over to another.
            key: ValueKey(journalAudio.meta.id),
            journalAudio: journalAudio,
            progress: progress,
            buffered: buffered,
            totalDuration: totalDuration,
            isActive: isActive,
            onSeek: controller.seek,
          ),
        ),
        SizedBox(width: tokens.spacing.step3),
        // One label: the recording's length at rest, the position while it
        // is the one loaded. The waveform already shows position against
        // length, so the pair is not spelled out twice. lowEmphasis, as it is
        // supporting metadata like the card's timestamp; tabular figures so
        // the ticking counter does not shift the row.
        Text(
          formatElapsed(isActive ? progress : totalDuration),
          maxLines: 1,
          style: tokens.typography.styles.others.caption.copyWith(
            color: tokens.colors.text.lowEmphasis,
            fontFeatures: numericBadgeFontFeatures,
          ),
        ),
        SizedBox(width: tokens.spacing.step2),
        // Speed belongs to the loaded recording, so every other player's
        // control is disabled rather than drawn live and inert.
        DesignSystemButton(
          label: speedLabel,
          semanticsLabel: context.messages.audioPlayerSpeed(speedLabel),
          variant: DesignSystemButtonVariant.tertiary,
          size: DesignSystemButtonSize.dense,
          tabularFigures: true,
          onPressed: isActive
              ? () => controller.setSpeed(_nextSpeed(state.speed))
              : null,
        ),
      ],
    );
  }
}

class _WaveformArea extends ConsumerStatefulWidget {
  const _WaveformArea({
    required this.journalAudio,
    required this.progress,
    required this.buffered,
    required this.totalDuration,
    required this.isActive,
    required this.onSeek,
    super.key,
  });

  final JournalAudio journalAudio;
  final Duration progress;
  final Duration buffered;
  final Duration totalDuration;
  final bool isActive;
  final ValueChanged<Duration> onSeek;

  @override
  ConsumerState<_WaveformArea> createState() => _WaveformAreaState();
}

class _WaveformAreaState extends ConsumerState<_WaveformArea> {
  static const int _minBars = 24;
  static const int _maxBars = 320;

  /// The amplitudes last drawn for this recording. The bar count follows the
  /// width, and each count is its own provider instance, so a width change —
  /// a longer speed label, a resized window — would otherwise drop back to
  /// the plain bar until the new instance has loaded.
  List<double>? _drawn;

  @override
  Widget build(BuildContext context) {
    final journalAudio = widget.journalAudio;
    final progress = widget.progress;
    final buffered = widget.buffered;
    final totalDuration = widget.totalDuration;
    final isActive = widget.isActive;
    final onSeek = widget.onSeek;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final width = constraints.maxWidth;
        final estimated =
            width /
            (kAudioWaveformTargetBarWidth + kAudioWaveformTargetBarSpacing);
        int bucketCount;
        if (estimated.isFinite && estimated > 0) {
          bucketCount = estimated.floor();
        } else {
          bucketCount = _minBars;
        }
        bucketCount = bucketCount.clamp(_minBars, _maxBars);

        final asyncWaveform = ref.watch(
          audioWaveformProvider(
            AudioWaveformRequest(
              audio: journalAudio,
              bucketCount: bucketCount,
            ),
          ),
        );

        final progressBar = AudioProgressBar(
          progress: progress,
          buffered: buffered,
          total: totalDuration,
          onSeek: onSeek,
          enabled: isActive,
        );

        // `.value`, not `.when`: a reload keeps the drawn waveform instead of
        // dropping back to the bar. An answer replaces what is drawn (an
        // empty one clears it); no answer yet leaves it as it is.
        if (asyncWaveform.hasValue) {
          final loaded = asyncWaveform.value?.amplitudes;
          _drawn = loaded == null || loaded.isEmpty ? null : loaded;
        }
        final amplitudes = _drawn;
        if (amplitudes == null) return progressBar;
        return AudioWaveformScrubber(
          amplitudes: amplitudes,
          progress: progress,
          buffered: buffered,
          total: totalDuration,
          onSeek: onSeek,
          enabled: isActive,
        );
      },
    );
  }
}

/// Soft circular play/pause control matching the Figma audio card spec:
/// neutral surface token fill with a high-emphasis text glyph, no progress
/// ring or gradient.
class _PlayButton extends StatelessWidget {
  const _PlayButton({
    required this.isPlaying,
    required this.status,
    required this.isActive,
    required this.onPressed,
  });

  final bool isPlaying;
  final AudioPlayerStatus status;
  final bool isActive;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    const diameter = _playControlDiameter;
    final isLoading = status == AudioPlayerStatus.initializing && isActive;

    final iconColor = tokens.colors.text.highEmphasis;
    final surfaceColor = tokens.colors.surface.enabled;

    final icon = isLoading
        ? SizedBox(
            width: IconSizes.s,
            height: IconSizes.s,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(iconColor),
            ),
          )
        : Icon(
            isPlaying ? LottiIcons.pause : LottiIcons.play,
            size: IconSizes.m,
            color: iconColor,
          );

    return Semantics(
      button: true,
      label: isPlaying
          ? context.messages.audioPlayerPause
          : context.messages.audioPlayerPlay,
      onTap: onPressed,
      child: ExcludeSemantics(
        child: SizedBox(
          width: diameter,
          height: diameter,
          child: Material(
            key: const Key('audio_player_play_button_surface'),
            color: surfaceColor,
            // A visible accent ring makes the play control the focal point and
            // gives the button SHAPE a >=3:1 boundary (WCAG 1.4.11) — the bare
            // low-contrast fill alone read as nearly invisible chrome.
            shape: CircleBorder(
              side: BorderSide(
                color: tokens.colors.interactive.enabled,
                width: 1.5,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              child: Center(child: icon),
            ),
          ),
        ),
      ),
    );
  }
}

double _nextSpeed(double current) {
  final index = _speedSequence.indexOf(current);
  if (index == -1) {
    return 1;
  }
  final nextIndex = (index + 1) % _speedSequence.length;
  return _speedSequence[nextIndex];
}

String _speedLabel(double speed) {
  if (speed == speed.truncateToDouble()) {
    return '${speed.toInt()}x';
  }
  return '${speed}x';
}
