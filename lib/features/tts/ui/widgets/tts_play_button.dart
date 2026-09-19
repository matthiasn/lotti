import 'package:lotti/features/design_system/components/buttons/ds_ai_disc_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// Visual mode of the playback button, derived by the parent from the
/// playback state and whether this card is the active source.
enum TtsButtonMode { idle, preparing, playing }

/// Calm, accessible play/stop control for reading a TL;DR aloud — a
/// [DsAiDiscButton], so it matches the *Chat* disc beside it on the card's
/// header rail.
///
/// Play vs stop is conveyed by glyph SHAPE plus a semantic label — never by
/// color alone, so it works under color blindness. While
/// [TtsButtonMode.preparing] it shows an indeterminate ring; while
/// [TtsButtonMode.playing], a determinate progress arc from [progress].
/// Reduced-motion renders the preparing ring static.
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

  @override
  Widget build(BuildContext context) {
    final ai = context.designTokens.colors.aiCard;
    final messages = context.messages;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final idle = mode == TtsButtonMode.idle;

    final label = switch (mode) {
      TtsButtonMode.playing => messages.aiSummaryStopTooltip,
      TtsButtonMode.preparing => messages.aiSummaryPreparingTooltip,
      TtsButtonMode.idle => messages.aiSummaryPlayTooltip,
    };
    // Three distinct glyphs so the states are legible by shape alone —
    // including under reduced motion, where the ring/arc difference vanishes.
    // Idle uses a speaker, not a play triangle: on a card whose headline verb
    // is "Wake agent", a bare triangle reads as "run the agent" rather than
    // "read this aloud".
    final glyph = switch (mode) {
      TtsButtonMode.playing => LottiIcons.stop,
      TtsButtonMode.preparing => LottiIcons.pending,
      TtsButtonMode.idle => LottiIcons.volume,
    };

    return DsAiDiscButton(
      icon: glyph,
      label: label,
      // Idle plays; preparing/playing stop (preparing-stop cancels).
      onPressed: idle ? onPlay : onStop,
      active: !idle,
      ring: idle
          ? null
          : CircularProgressIndicator(
              strokeWidth: 2,
              value: mode == TtsButtonMode.playing
                  ? (progress ?? 0).clamp(0.0, 1.0)
                  : (reduceMotion ? 1.0 : null),
              color: ai.accent,
              backgroundColor: ai.borderSoft,
            ),
    );
  }
}
