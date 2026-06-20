import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/speech/model/audio_player_state.dart';
import 'package:lotti/features/speech/state/audio_player_controller.dart';
import 'package:lotti/features/speech/state/audio_waveform_provider.dart';
import 'package:lotti/features/speech/ui/widgets/progress/audio_progress_bar.dart';
import 'package:lotti/features/speech/ui/widgets/progress/audio_waveform_scrubber.dart';
import 'package:lotti/themes/theme.dart';

const List<double> _speedSequence = <double>[
  0.5,
  0.75,
  1,
  1.25,
  1.5,
  1.75,
  2,
];

/// Minimal audio player card embedding play controls, progress, and speed toggle.
class AudioPlayerWidget extends ConsumerWidget {
  const AudioPlayerWidget(this.journalAudio, {super.key});

  final JournalAudio journalAudio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(audioPlayerControllerProvider);
    final controller = ref.read(audioPlayerControllerProvider.notifier);
    final isActive = state.audioNote?.meta.id == journalAudio.meta.id;

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppTheme.cardPadding * 0.4,
      ),
      child: _AudioPlayerCardShell(
        journalAudio: journalAudio,
        state: state,
        controller: controller,
        isActive: isActive,
      ),
    );
  }
}

/// Provides responsive layout selection for the audio player card.
class _AudioPlayerCardShell extends StatelessWidget {
  const _AudioPlayerCardShell({
    required this.journalAudio,
    required this.state,
    required this.controller,
    required this.isActive,
  });

  final JournalAudio journalAudio;
  final AudioPlayerState state;
  final AudioPlayerController controller;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final isCompact = constraints.maxWidth < 360;
        return _PlayerBody(
          controller: controller,
          journalAudio: journalAudio,
          state: state,
          isActive: isActive,
          isCompact: isCompact,
        );
      },
    );
  }
}

/// Horizontal row containing play control, progress bar, timestamps, and speed toggle.
class _PlayerBody extends StatelessWidget {
  const _PlayerBody({
    required this.controller,
    required this.journalAudio,
    required this.state,
    required this.isActive,
    required this.isCompact,
  });

  final AudioPlayerController controller;
  final JournalAudio journalAudio;
  final AudioPlayerState state;
  final bool isActive;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final totalDuration = state.totalDuration == Duration.zero
        ? journalAudio.data.duration
        : state.totalDuration;
    final progress = isActive ? state.progress : Duration.zero;
    final buffered = isActive ? state.buffered : Duration.zero;
    final isPlaying = isActive && state.status == AudioPlayerStatus.playing;

    void handleTap() {
      if (!isActive) {
        controller
          ..setAudioNote(journalAudio)
          ..play();
        return;
      }

      if (state.status == AudioPlayerStatus.playing) {
        controller.pause();
        return;
      }

      controller.play();
    }

    final theme = Theme.of(context);
    final tokens = theme.extension<DsTokens>();
    final timeColor =
        tokens?.colors.text.mediumEmphasis ??
        theme.colorScheme.onSurfaceVariant;
    final captionStyle = tokens?.typography.styles.others.caption;
    // Proportional body sans (no monospace/slashed-zero badge features) so the
    // timecodes share one numeric voice with the rest of the card.
    final timeStyle = (captionStyle ?? const TextStyle(fontSize: 12)).copyWith(
      color: timeColor,
    );

    final controlSpacing = tokens?.spacing.step2 ?? 4.0;
    final timeRowLeftInset = (isCompact ? 40 : 48).toDouble() + controlSpacing;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            _PlayButton(
              isPlaying: isPlaying,
              status: state.status,
              isActive: isActive,
              isCompact: isCompact,
              onPressed: handleTap,
            ),
            SizedBox(width: controlSpacing),
            Expanded(
              child: _WaveformArea(
                journalAudio: journalAudio,
                progress: progress,
                buffered: buffered,
                totalDuration: totalDuration,
                isActive: isActive,
                isCompact: isCompact,
                onSeek: controller.seek,
              ),
            ),
          ],
        ),
        Padding(
          padding: EdgeInsets.only(left: timeRowLeftInset),
          child: Row(
            children: <Widget>[
              // Both timecodes grouped at the scrubber's left gutter (elapsed
              // then total) with the speed pill pushed to the trailing edge, so
              // the row keeps the card's single left-gutter scan path instead of
              // marooning the pill in the dead centre of a wide empty stretch.
              Text(formatAudioDuration(progress), style: timeStyle),
              SizedBox(width: tokens?.spacing.step3 ?? 8.0),
              Text(formatAudioDuration(totalDuration), style: timeStyle),
              const Spacer(),
              _SpeedButton(
                controller: controller,
                currentSpeed: state.speed,
                isActive: isActive,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WaveformArea extends ConsumerWidget {
  const _WaveformArea({
    required this.journalAudio,
    required this.progress,
    required this.buffered,
    required this.totalDuration,
    required this.isActive,
    required this.isCompact,
    required this.onSeek,
  });

  final JournalAudio journalAudio;
  final Duration progress;
  final Duration buffered;
  final Duration totalDuration;
  final bool isActive;
  final bool isCompact;
  final ValueChanged<Duration> onSeek;

  static const int _minBars = 24;
  static const int _maxBars = 320;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
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
          compact: isCompact,
        );

        return asyncWaveform.when(
          data: (data) {
            if (data == null || data.amplitudes.isEmpty) {
              return progressBar;
            }
            return AudioWaveformScrubber(
              amplitudes: data.amplitudes,
              progress: progress,
              buffered: buffered,
              total: totalDuration,
              onSeek: onSeek,
              enabled: isActive,
              compact: isCompact,
            );
          },
          loading: () => progressBar,
          error: (_, _) => progressBar,
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
    required this.isCompact,
    required this.onPressed,
  });

  final bool isPlaying;
  final AudioPlayerStatus status;
  final bool isActive;
  final bool isCompact;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<DsTokens>();
    final scheme = theme.colorScheme;
    final diameter = (isCompact ? 40 : 48).toDouble();
    final isLoading = status == AudioPlayerStatus.initializing && isActive;

    final iconColor = tokens?.colors.text.highEmphasis ?? scheme.onSurface;
    final surfaceColor =
        tokens?.colors.surface.enabled ??
        scheme.onSurface.withValues(alpha: 0.06);

    final icon = isLoading
        ? SizedBox(
            width: isCompact ? 16 : 20,
            height: isCompact ? 16 : 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(iconColor),
            ),
          )
        : Icon(
            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            size: isCompact ? 20 : 24,
            color: iconColor,
          );

    return Semantics(
      button: true,
      label: isPlaying ? 'Pause audio' : 'Play audio',
      onTap: onPressed,
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
              color: tokens?.colors.interactive.enabled ?? scheme.primary,
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
    );
  }
}

/// Displays the current playback speed and cycles through presets on tap.
class _SpeedButton extends StatelessWidget {
  const _SpeedButton({
    required this.controller,
    required this.currentSpeed,
    required this.isActive,
  });

  final AudioPlayerController controller;
  final double currentSpeed;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = theme.extension<DsTokens>();
    final label = _speedLabel(currentSpeed);
    final nextSpeed = _nextSpeed(currentSpeed);

    final captionStyle = tokens?.typography.styles.others.caption;
    final speedTextColor = currentSpeed != 1
        ? scheme.error
        : (tokens?.colors.text.mediumEmphasis ?? scheme.onSurfaceVariant);
    final speedTextStyle = (captionStyle ?? const TextStyle(fontSize: 12))
        .copyWith(color: speedTextColor);

    // A boundary at the same weight as the other header glyphs (mediumEmphasis,
    // well above the WCAG 1.4.11 3:1 floor) so the speed control reads as a
    // real, tappable pill rather than near-invisible chrome.
    final pillBorder =
        tokens?.colors.text.mediumEmphasis ?? scheme.outlineVariant;
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: currentSpeed != 1 ? scheme.error : pillBorder,
        ),
        color: scheme.surfaceTint.withValues(alpha: 0.05),
      ),
      child: Text(label, style: speedTextStyle),
    );

    if (!isActive) {
      // Quieter than the active state, but not so faint it disappears.
      return Opacity(opacity: 0.75, child: child);
    }

    return Semantics(
      button: true,
      label: 'Playback speed',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          splashColor: scheme.primary.withValues(alpha: 0.08),
          highlightColor: scheme.primary.withValues(alpha: 0.04),
          onTap: () => controller.setSpeed(nextSpeed),
          child: child,
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
