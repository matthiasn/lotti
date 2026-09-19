import 'package:lotti/features/design_system/components/ds_quiet_ink.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Calm, round glyph control for an AI card's header rail — the report's
/// read-aloud control and its *Chat* entry wear the same disc, so the rail
/// reads as one set of utilities rather than two unrelated buttons.
///
/// A [hitSize] target wrapping a ~36px tonal disc. Idle stays a whispered
/// utility (`subtleWash` fill, `metaText` glyph) so the header keeps a single
/// accent — the sparkle badge; [active] earns the accent pair (`accentSoft`
/// fill, `accent` glyph) while the control is doing something. [ring] is
/// painted behind the disc at [ringSize] — the TTS control's progress arc.
///
/// The visible button is the disc, not the hit circle — a hover fill over the
/// hit area haloed the disc with a phantom ring — so the disc answers
/// hover/focus/press itself: its border firms a step and the idle glyph
/// brightens.
///
/// Sizes here are fixed control / accessibility dimensions (not layout
/// spacing); layout gaps around the control come from `tokens.spacing`.
class DsAiDiscButton extends StatelessWidget {
  const DsAiDiscButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.active = false,
    this.ring,
    super.key,
  });

  final IconData icon;

  /// Tooltip and screen-reader label; the disc has no visible text.
  final String label;
  final VoidCallback onPressed;

  /// Whether the control is busy on the user's behalf (preparing, playing).
  final bool active;

  /// Drawn behind the disc, sized to [ringSize].
  final Widget? ring;

  static const double hitSize = TapTargets.compact;
  static const double ringSize = 42;
  static const double _discSize = 36;
  static const double _glyphSize = 20;

  @override
  Widget build(BuildContext context) {
    final ai = context.designTokens.colors.aiCard;
    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: DsQuietInk(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          builder: (context, highlighted) => SizedBox(
            width: hitSize,
            height: hitSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (ring case final ring?)
                  SizedBox(width: ringSize, height: ringSize, child: ring),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: active ? ai.accentSoft : ai.subtleWash,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: active
                          ? (highlighted ? ai.accent : ai.border)
                          : (highlighted ? ai.border : ai.subtleBorder),
                    ),
                  ),
                  child: SizedBox(
                    width: _discSize,
                    height: _discSize,
                    child: Icon(
                      icon,
                      size: _glyphSize,
                      color: active
                          ? ai.accent
                          : (highlighted ? ai.bodyText : ai.metaText),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
