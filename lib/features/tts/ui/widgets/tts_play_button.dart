import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Visual mode of the playback button, derived by the parent from the
/// playback state and whether this card is the active source.
enum TtsButtonMode { idle, preparing, playing }

/// Calm, accessible play/stop control for reading a TL;DR aloud.
///
/// A 44x44 hit target wrapping a ~36px filled-`accent` circle so it clearly
/// reads as the card's focal action. Play vs stop is conveyed by glyph SHAPE
/// (triangle vs square) plus a semantic label — never by color alone, so it
/// works under color blindness. While [TtsButtonMode.preparing] it shows an
/// indeterminate ring; while [TtsButtonMode.playing], a determinate progress
/// arc from [progress]. Reduced-motion renders the preparing ring static.
///
/// Sizes here are fixed control / accessibility dimensions (not layout
/// spacing), matching the surrounding header's existing convention; layout
/// gaps come from `tokens.spacing`.
class TtsPlayButton extends StatelessWidget {
  const TtsPlayButton({
    required this.mode,
    required this.onPlay,
    required this.onStop,
    this.progress,
    super.key,
  });

  final TtsButtonMode mode;

  /// Invoked on tap while [mode] is [TtsButtonMode.idle].
  final VoidCallback onPlay;

  /// Invoked on tap while preparing or playing; a preparing-tap cancels.
  final VoidCallback onStop;

  /// Playback progress in `[0, 1]` while [mode] is playing; ignored otherwise.
  final double? progress;

  static const double _hitSize = 44;
  static const double _circleSize = 36;
  static const double _ringSize = 42;
  static const double _glyphSize = 20;

  @override
  Widget build(BuildContext context) {
    final ai = context.designTokens.colors.aiCard;
    final messages = context.messages;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    final label = switch (mode) {
      TtsButtonMode.playing => messages.aiSummaryStopTooltip,
      TtsButtonMode.preparing => messages.aiSummaryPreparingTooltip,
      TtsButtonMode.idle => messages.aiSummaryPlayTooltip,
    };
    // Three distinct glyphs so the states are legible by shape alone —
    // including under reduced motion, where the ring/arc difference vanishes.
    final glyph = switch (mode) {
      TtsButtonMode.playing => Icons.stop_rounded,
      TtsButtonMode.preparing => Icons.hourglass_empty,
      TtsButtonMode.idle => Icons.play_arrow_rounded,
    };
    // Idle plays; preparing/playing stop (preparing-stop cancels).
    final onTap = mode == TtsButtonMode.idle ? onPlay : onStop;

    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: _hitSize,
              height: _hitSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (mode != TtsButtonMode.idle)
                    SizedBox(
                      width: _ringSize,
                      height: _ringSize,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        value: mode == TtsButtonMode.playing
                            ? (progress ?? 0).clamp(0.0, 1.0)
                            : (reduceMotion ? 1.0 : null),
                        color: ai.accent,
                        backgroundColor: ai.borderSoft,
                      ),
                    ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: ai.accent,
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox(
                      width: _circleSize,
                      height: _circleSize,
                      // Dark card-background glyph on the light accent fill:
                      // high contrast both ways. Verify AA at build.
                      child: Icon(
                        glyph,
                        size: _glyphSize,
                        color: ai.background,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
