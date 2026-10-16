import 'package:lotti/features/design_system/components/ds_quiet_ink.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// The one way into a conversation with an agent from the page it serves —
/// a goal's, a person's.
///
/// It wears the AI card's own pair (`accentSoft` fill, `accent` border, glyph
/// and label) and the sparkle that means "the agent" everywhere else in the
/// app, so it reads as the agent's doorway rather than as one more grey
/// toolbar pill beside the page's own actions. The goal page and the person
/// page used to offer two different buttons — a speech bubble on one, a
/// sparkle on the other, both dense secondary pills — for the same act.
///
/// [label] defaults to *Talk to agent*; it ellipsizes inside the pill, with
/// the full label kept in the tooltip and for screen readers.
///
/// Over a photograph the AI pair cannot be read — a soft wash and a coloured
/// label vanish into a bright picture — so a host there passes the glass its
/// other controls wear as [fill] and [foreground]: the pill then matches its
/// neighbours and only the sparkle keeps the agent's hue.
class AgentChatButton extends StatelessWidget {
  const AgentChatButton({
    required this.onPressed,
    this.label,
    this.fill,
    this.foreground,
    super.key,
  });

  final VoidCallback onPressed;
  final String? label;

  /// The pill's fill instead of `aiCard.accentSoft`.
  final Color? fill;

  /// The label's ink (and the resting border's) instead of `aiCard.accent`.
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    final text = label ?? context.messages.goalChatTalkToAgent;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
    );
    return Semantics(
      button: true,
      label: text,
      // One announcement: the visible label and the tooltip repeat what the
      // button's own label already says.
      child: Tooltip(
        message: text,
        excludeFromSemantics: true,
        // The ink IS the touch target, at the full recommended height the
        // toolbar has room for; the pill is drawn centred inside it. Putting
        // the minimum on a box around a smaller ink left taps on the target's
        // upper and lower margin hitting nothing.
        child: DsQuietInk(
          customBorder: shape,
          onTap: onPressed,
          focusRing: true,
          builder: (context, highlighted) => ConstrainedBox(
            constraints: const BoxConstraints(minHeight: TapTargets.minimum),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: fill ?? ai.accentSoft,
                  shape: shape.copyWith(
                    side: BorderSide(
                      // The border firms to the full accent on hover and
                      // focus, the way the AI card's header disc answers.
                      color: highlighted
                          ? ai.accent
                          : fill == null
                          ? ai.border
                          : Colors.transparent,
                    ),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: tokens.spacing.step4,
                    vertical: tokens.spacing.step2,
                  ),
                  child: ExcludeSemantics(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LottiIcons.aiSpark,
                          size: IconSizes.s,
                          color: ai.accent,
                        ),
                        SizedBox(width: tokens.spacing.step2),
                        Flexible(
                          child: Text(
                            text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tokens.typography.styles.subtitle.subtitle2
                                .copyWith(color: foreground ?? ai.accent),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
