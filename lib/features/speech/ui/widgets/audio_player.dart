import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/speech/state/player_cubit.dart';
import 'package:lotti/features/speech/state/player_state.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/cards/modern_base_card.dart';
import 'package:lotti/features/speech/ui/widgets/progress/audio_progress_bar.dart';

const Map<double, double> _speedToggleMap = <double, double>{
  0.5: 0.75,
  0.75: 1,
  1: 1.25,
  1.25: 1.5,
  1.5: 1.75,
  1.75: 2,
  2: 0.5,
};

const Map<double, String> _speedLabelMap = <double, String>{
  0.5: '0.5x',
  0.75: '0.75x',
  1: '1x',
  1.25: '1.25x',
  1.5: '1.5x',
  1.75: '1.75x',
  2: '2x',
};

String _formatDuration(Duration duration) {
  final totalSeconds = duration.inSeconds.clamp(0, 359999);
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;

  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

class AudioPlayerWidget extends ConsumerWidget {
  const AudioPlayerWidget(this.journalAudio, {super.key});

  final JournalAudio journalAudio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BlocBuilder<AudioPlayerCubit, AudioPlayerState>(
      builder: (BuildContext context, AudioPlayerState state) {
        final isActive = state.audioNote?.meta.id == journalAudio.meta.id;
        final cubit = context.read<AudioPlayerCubit>();

        return AnimatedContainer(
          duration: const Duration(milliseconds: AppTheme.animationDuration),
          curve: AppTheme.animationCurve,
          child: ModernBaseCard(
            gradient: GradientThemes.cardGradient(context),
            borderColor: context.colorScheme.primary.withValues(alpha: 0.18),
            isEnhanced: true,
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.cardPadding * 1.4,
              vertical: AppTheme.cardPadding,
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

        final primaryControls = _PrimaryControls(
          cubit: cubit,
          journalAudio: journalAudio,
          isActive: isActive,
          state: state,
          compact: isCompact,
        );

        final progressSection = _ProgressSection(
          cubit: cubit,
          journalAudio: journalAudio,
          state: state,
          isActive: isActive,
          compact: isCompact,
        );

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              primaryControls,
              const SizedBox(height: 12),
              progressSection,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            primaryControls,
            const SizedBox(width: 16),
            Expanded(child: progressSection),
          ],
        );
      },
    );
  }
}

class _PrimaryControls extends StatelessWidget {
  const _PrimaryControls({
    required this.cubit,
    required this.journalAudio,
    required this.isActive,
    required this.state,
    required this.compact,
  });

  final AudioPlayerCubit cubit;
  final JournalAudio journalAudio;
  final bool isActive;
  final AudioPlayerState state;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final playColor = (state.status == AudioPlayerStatus.playing && isActive)
        ? context.colorScheme.error
        : context.colorScheme.outline;

    final sharedPadding = compact
        ? const EdgeInsets.all(6)
        : const EdgeInsets.symmetric(horizontal: 12, vertical: 8);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        _GlassIconButton(
          icon: Icons.play_arrow_rounded,
          label: 'Play',
          color: playColor,
          tooltip: 'Play audio',
          onPressed: () {
            cubit
              ..setAudioNote(journalAudio)
              ..play();
          },
          padding: sharedPadding,
        ),
        IgnorePointer(
          ignoring: !isActive,
          child: Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              _GlassIconButton(
                icon: Icons.pause_rounded,
                label: 'Pause',
                color: context.colorScheme.outline,
                tooltip: 'Pause audio',
                onPressed: cubit.pause,
                padding: sharedPadding,
              ),
              _GlassIconButton(
                tooltip: 'Toggle playback speed',
                child: Text(
                  _speedLabelMap[state.speed] ?? '1x',
                  style: GoogleFonts.oswald(
                    fontWeight: FontWeight.bold,
                    color: (state.speed != 1)
                        ? context.colorScheme.error
                        : context.colorScheme.outline,
                  ),
                ),
                onPressed: () =>
                    cubit.setSpeed(_speedToggleMap[state.speed] ?? 1),
                padding: sharedPadding,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProgressSection extends StatelessWidget {
  const _ProgressSection({
    required this.cubit,
    required this.journalAudio,
    required this.state,
    required this.isActive,
    required this.compact,
  });

  final AudioPlayerCubit cubit;
  final JournalAudio journalAudio;
  final AudioPlayerState state;
  final bool isActive;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final duration = state.totalDuration == Duration.zero
        ? journalAudio.data.duration
        : state.totalDuration;
    final progress = isActive ? state.progress : Duration.zero;
    final buffered = isActive ? state.buffered : Duration.zero;

    final timeStyle = monoTabularStyle(
      fontSize: compact ? fontSizeSmall : fontSizeMedium,
      color: context.colorScheme.onSurfaceVariant,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AnimatedOpacity(
          opacity: isActive ? 1 : 0.6,
          duration: const Duration(milliseconds: AppTheme.animationDuration),
          child: _AudioProgressBar(
            progress: progress,
            buffered: buffered,
            total: duration,
            onSeek: cubit.seek,
            enabled: isActive,
            compact: compact,
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(_formatDuration(progress), style: timeStyle),
              Text(_formatDuration(duration), style: timeStyle),
            ],
          ),
        ),
      ],
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    this.icon,
    this.label,
    this.child,
    required this.onPressed,
    this.color,
    this.padding,
    this.tooltip,
  }) : assert(icon != null || child != null,
            'Either icon or child must be provided.');

  final IconData? icon;
  final String? label;
  final Widget? child;
  final VoidCallback onPressed;
  final Color? color;
  final EdgeInsets? padding;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final buttonColor = color ?? scheme.primary;

    final button = AnimatedContainer(
      duration: const Duration(milliseconds: AppTheme.animationDuration),
      curve: AppTheme.animationCurve,
      decoration: ShapeDecoration(
        color: scheme.surfaceTint.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: buttonColor.withValues(alpha: 0.28),
          ),
        ),
        shadows: <BoxShadow>[
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onPressed,
        splashColor: scheme.primary.withValues(alpha: 0.18),
        highlightColor: scheme.primary.withValues(alpha: 0.1),
        child: Padding(
          padding: padding ??
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null)
                Icon(
                  icon,
                  size: 22,
                  color: buttonColor,
                ),
              if (child != null) child!,
              if (label != null && icon != null)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Text(
                    label!,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: buttonColor,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    if (tooltip == null) {
      return button;
    }

    return Tooltip(
      message: tooltip!,
      waitDuration: const Duration(milliseconds: 250),
      child: button,
    );
  }
}

class _AudioProgressBar extends StatelessWidget {
  const _AudioProgressBar({
    required this.progress,
    required this.buffered,
    required this.total,
    required this.onSeek,
    required this.enabled,
    required this.compact,
  });

  final Duration progress;
  final Duration buffered;
  final Duration total;
  final ValueChanged<Duration> onSeek;
  final bool enabled;
  final bool compact;

  bool get _hasTotal => total.inMilliseconds > 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trackHeight = compact ? 6.0 : 8.0;
    final thumbRadius = compact ? 6.0 : 7.5;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;

        final progressRatio = _hasTotal
            ? (progress.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0)
            : 0.0;

        final bufferedRatio = _hasTotal
            ? (buffered.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0)
            : 0.0;

        Widget bar = SizedBox(
          width: double.infinity,
          height: compact ? 32 : 36,
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _ProgressBarPainter(
                backgroundColor:
                    theme.colorScheme.surfaceVariant.withValues(alpha: 0.35),
                bufferedColor:
                    theme.colorScheme.primary.withValues(alpha: 0.22),
                progressColor: theme.colorScheme.primary,
                glowColor: theme.colorScheme.primary.withValues(alpha: 0.35),
                thumbColor: theme.colorScheme.onPrimary,
                progressRatio: progressRatio,
                bufferedRatio: bufferedRatio,
                trackHeight: trackHeight,
                thumbRadius: thumbRadius,
              ),
            ),
          ),
        );

        if (!enabled || !_hasTotal) {
          return bar;
        }

        void handle(Offset position) {
          if (width <= 0) {
            return;
          }
          final ratio = (position.dx / width).clamp(0.0, 1.0);
          final targetMs = (total.inMilliseconds * ratio).round();
          onSeek(Duration(milliseconds: targetMs));
        }

        return Semantics(
          label: 'Audio timeline',
          value: '${_formatDuration(progress)} of ${_formatDuration(total)}',
          increasedValue: 'Seek forward',
          decreasedValue: 'Seek backward',
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapDown: (details) => handle(details.localPosition),
            onHorizontalDragStart: (details) => handle(details.localPosition),
            onHorizontalDragUpdate: (details) => handle(details.localPosition),
            child: bar,
          ),
        );
      },
    );
  }
}

class _ProgressBarPainter extends CustomPainter {
  _ProgressBarPainter({
    required this.backgroundColor,
    required this.bufferedColor,
    required this.progressColor,
    required this.glowColor,
    required this.thumbColor,
    required this.progressRatio,
    required this.bufferedRatio,
    required this.trackHeight,
    required this.thumbRadius,
  });

  final Color backgroundColor;
  final Color bufferedColor;
  final Color progressColor;
  final Color glowColor;
  final Color thumbColor;
  final double progressRatio;
  final double bufferedRatio;
  final double trackHeight;
  final double thumbRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final trackTop = (size.height - trackHeight) / 2;
    final trackRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, trackTop, size.width, trackHeight),
      Radius.circular(trackHeight / 2),
    );

    final paint = Paint()..color = backgroundColor;
    canvas.drawRRect(trackRect, paint);

    if (bufferedRatio > 0) {
      final bufferedRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          0,
          trackTop,
          size.width * bufferedRatio,
          trackHeight,
        ),
        Radius.circular(trackHeight / 2),
      );
      canvas.drawRRect(
        bufferedRect,
        Paint()..color = bufferedColor,
      );
    }

    if (progressRatio > 0) {
      final progressRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          0,
          trackTop,
          size.width * progressRatio,
          trackHeight,
        ),
        Radius.circular(trackHeight / 2),
      );

      final gradient = LinearGradient(
        colors: <Color>[
          Color.lerp(progressColor, Colors.white, 0.25)!,
          progressColor,
        ],
      );

      final progressPaint = Paint()
        ..shader = gradient.createShader(progressRect.outerRect);
      canvas.drawRRect(progressRect, progressPaint);

      final thumbCenter = Offset(
        progressRect.outerRect.right,
        trackRect.center.dy,
      );

      final glowPaint = Paint()
        ..color = glowColor
        ..maskFilter = const ui.MaskFilter.blur(
          ui.BlurStyle.normal,
          6,
        );
      canvas.drawCircle(thumbCenter, thumbRadius + 3, glowPaint);

      canvas.drawCircle(
        thumbCenter,
        thumbRadius,
        Paint()..color = thumbColor,
      );
    }
  }

  @override
  bool shouldRepaint(_ProgressBarPainter oldDelegate) {
    return progressRatio != oldDelegate.progressRatio ||
        bufferedRatio != oldDelegate.bufferedRatio ||
        progressColor != oldDelegate.progressColor;
  }
}
