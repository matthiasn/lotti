import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/speech/state/player_cubit.dart';
import 'package:lotti/features/speech/state/player_state.dart';
import 'package:lotti/features/speech/ui/widgets/progress/audio_progress_bar.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/cards/modern_base_card.dart';

const List<double> _speedSequence = <double>[
  0.5,
  0.75,
  1,
  1.25,
  1.5,
  1.75,
  2,
];

const double _compactControlSpacing = 14;
const double _standardControlSpacing = 20;

/// Minimal audio player card embedding play controls, progress, and speed toggle.
class AudioPlayerWidget extends ConsumerWidget {
  const AudioPlayerWidget(this.journalAudio, {super.key});

  final JournalAudio journalAudio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BlocBuilder<AudioPlayerCubit, AudioPlayerState>(
      builder: (BuildContext context, AudioPlayerState state) {
        final isActive = state.audioNote?.meta.id == journalAudio.meta.id;
        final cubit = context.read<AudioPlayerCubit>();
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final subtleShadows = <BoxShadow>[
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(
              alpha: isDark ? 0.22 : 0.12,
            ),
            blurRadius: isDark ? 14 : 10,
            offset: const Offset(0, 6),
          ),
        ];

        return AnimatedContainer(
          duration: const Duration(milliseconds: AppTheme.animationDuration),
          curve: AppTheme.animationCurve,
          margin: const EdgeInsets.only(top: AppTheme.cardPadding),
          child: ModernBaseCard(
            gradient: isDark ? GradientThemes.cardGradient(context) : null,
            backgroundColor: isDark
                ? null
                : theme.colorScheme.surfaceContainerHigh
                    .withValues(alpha: 0.92),
            borderColor: context.colorScheme.primary.withValues(alpha: 0.18),
            isEnhanced: true,
            customShadows: subtleShadows,
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.cardPadding,
              vertical: AppTheme.cardPadding * 0.4,
            ),
            child: _AudioPlayerCardShell(
              journalAudio: journalAudio,
              state: state,
              cubit: cubit,
              isActive: isActive,
            ),
          ),
        );
      },
    );
  }
}

/// Provides responsive layout selection for the audio player card.
class _AudioPlayerCardShell extends StatelessWidget {
  const _AudioPlayerCardShell({
    required this.journalAudio,
    required this.state,
    required this.cubit,
    required this.isActive,
  });

  final JournalAudio journalAudio;
  final AudioPlayerState state;
  final AudioPlayerCubit cubit;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final isCompact = constraints.maxWidth < 360;
        return _PlayerBody(
          cubit: cubit,
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
    required this.cubit,
    required this.journalAudio,
    required this.state,
    required this.isActive,
    required this.isCompact,
  });

  final AudioPlayerCubit cubit;
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
    final progressRatio = totalDuration.inMilliseconds > 0
        ? (progress.inMilliseconds / totalDuration.inMilliseconds)
            .clamp(0.0, 1.0)
        : 0.0;
    final isPlaying = isActive && state.status == AudioPlayerStatus.playing;

    void handleTap() {
      if (!isActive) {
        cubit
          ..setAudioNote(journalAudio)
          ..play();
        return;
      }

      if (state.status == AudioPlayerStatus.playing) {
        cubit.pause();
        return;
      }

      cubit.play();
    }

    final timeStyle = monoTabularStyle(
      fontSize: fontSizeMedium,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );

    return Row(
      children: <Widget>[
        _PlayButton(
          isPlaying: isPlaying,
          status: state.status,
          isActive: isActive,
          isCompact: isCompact,
          progressRatio: progressRatio,
          onPressed: handleTap,
        ),
        SizedBox(
          width: isCompact ? _compactControlSpacing : _standardControlSpacing,
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AudioProgressBar(
                progress: progress,
                buffered: buffered,
                total: totalDuration,
                onSeek: cubit.seek,
                enabled: isActive,
                compact: isCompact,
              ),
              Row(
                children: <Widget>[
                  Text(formatAudioDuration(progress), style: timeStyle),
                  Expanded(
                    child: Align(
                      child: _SpeedButton(
                        cubit: cubit,
                        currentSpeed: state.speed,
                        isActive: isActive,
                      ),
                    ),
                  ),
                  Text(formatAudioDuration(totalDuration), style: timeStyle),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Circular primary play/pause button with progress ring animation.
class _PlayButton extends StatelessWidget {
  const _PlayButton({
    required this.isPlaying,
    required this.status,
    required this.isActive,
    required this.isCompact,
    required this.progressRatio,
    required this.onPressed,
  });

  final bool isPlaying;
  final AudioPlayerStatus status;
  final bool isActive;
  final bool isCompact;
  final double progressRatio;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final diameter = (isCompact ? 46 : 56).toDouble();
    final innerDiameter = diameter - (isCompact ? 12 : 14).toDouble();
    final isLoading = status == AudioPlayerStatus.initializing && isActive;

    final icon = isLoading
        ? SizedBox(
            width: isCompact ? 18 : 22,
            height: isCompact ? 18 : 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(scheme.onPrimary),
            ),
          )
        : Icon(
            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            size: isCompact ? 22 : 26,
            color: scheme.onPrimary,
          );

    final button = AnimatedContainer(
      duration: const Duration(milliseconds: AppTheme.animationDuration),
      curve: AppTheme.animationCurve,
      width: innerDiameter,
      height: innerDiameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: isPlaying
              ? <Color>[
                  scheme.error.withValues(alpha: 0.75),
                  scheme.error,
                ]
              : <Color>[
                  scheme.primary.withValues(alpha: 0.8),
                  scheme.primary,
                ],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.2),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Center(child: icon),
    );

    return Semantics(
      button: true,
      label: isPlaying ? 'Pause audio' : 'Play audio',
      onTap: onPressed,
      child: SizedBox(
        width: diameter,
        height: diameter,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: progressRatio),
          duration: const Duration(milliseconds: 340),
          curve: Curves.easeOutCubic,
          builder: (BuildContext context, double value, Widget? child) {
            return CustomPaint(
              painter: _PlayButtonRingPainter(
                progress: isActive ? value : 0,
                color: scheme.primary,
                backgroundColor:
                    scheme.surfaceContainerHighest.withValues(alpha: 0.28),
                glowColor: isDark
                    ? Colors.transparent
                    : scheme.primary.withValues(alpha: 0.28),
              ),
              child: child,
            );
          },
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(innerDiameter / 2),
              splashColor: scheme.primary.withValues(alpha: 0.2),
              highlightColor: scheme.primary.withValues(alpha: 0.1),
              onTap: onPressed,
              child: Center(child: button),
            ),
          ),
        ),
      ),
    );
  }
}

/// Displays the current playback speed and cycles through presets on tap.
class _SpeedButton extends StatelessWidget {
  const _SpeedButton({
    required this.cubit,
    required this.currentSpeed,
    required this.isActive,
  });

  final AudioPlayerCubit cubit;
  final double currentSpeed;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = _speedLabel(currentSpeed);
    final nextSpeed = _nextSpeed(currentSpeed);

    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: currentSpeed != 1
              ? scheme.error.withValues(alpha: 0.4)
              : scheme.primary.withValues(alpha: 0.18),
        ),
        color: scheme.surfaceTint.withValues(alpha: 0.05),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: currentSpeed != 1 ? scheme.error : scheme.onSurfaceVariant,
            ),
      ),
    );

    if (!isActive) {
      return Opacity(opacity: 0.5, child: child);
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
          onTap: () => cubit.setSpeed(nextSpeed),
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

class _PlayButtonRingPainter extends CustomPainter {
  const _PlayButtonRingPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
    required this.glowColor,
  });

  final double progress;
  final Color color;
  final Color backgroundColor;
  final Color glowColor;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 4.5;
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - strokeWidth / 2;

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = backgroundColor;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0) {
      return;
    }

    final sweep = (progress.clamp(0.0, 1.0)) * 2 * math.pi;
    final arcRect = Rect.fromCircle(center: center, radius: radius);

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = glowColor
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 5);
    canvas.drawArc(arcRect, -math.pi / 2, sweep, false, glowPaint);

    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        colors: <Color>[
          Color.lerp(color, Colors.white, 0.25)!,
          color,
        ],
      ).createShader(arcRect);
    canvas.drawArc(arcRect, -math.pi / 2, sweep, false, progressPaint);
  }

  @override
  bool shouldRepaint(_PlayButtonRingPainter oldDelegate) {
    return progress != oldDelegate.progress || color != oldDelegate.color;
  }
}
