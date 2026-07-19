import 'package:flutter/material.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

class RowActions extends StatelessWidget {
  const RowActions({
    required this.busy,
    required this.onReject,
    required this.onConfirm,
    super.key,
  });

  final bool busy;
  final Future<void> Function() onReject;
  final Future<void> Function() onConfirm;

  @override
  Widget build(BuildContext context) {
    if (busy) {
      // Match the 48×48 footprint of a single non-busy
      // [_SquareIconButton] so the row doesn't reflow when toggling.
      return SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: context.designTokens.colors.aiCard.accent,
            ),
          ),
        ),
      );
    }
    // Reject is a quiet ghost glyph; confirm sits in a tonal wash circle so
    // the affirmative action reads as the row's one button. A `step2` gap
    // separates the two hit zones — the asymmetric chrome keeps the
    // opposite-meaning targets visually distinct, and swipe remains the
    // primary gesture.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SquareIconButton(
          icon: Icons.close_rounded,
          tooltip: context.messages.changeSetSwipeReject,
          onPressed: onReject,
          variant: _SquareIconVariant.outline,
        ),
        SizedBox(width: context.designTokens.spacing.step2),
        _SquareIconButton(
          icon: Icons.check_rounded,
          tooltip: context.messages.changeSetSwipeConfirm,
          onPressed: onConfirm,
          variant: _SquareIconVariant.accent,
        ),
      ],
    );
  }
}

enum _SquareIconVariant { outline, accent }

class _SquareIconButton extends StatelessWidget {
  const _SquareIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.variant,
  });

  final IconData icon;
  final String tooltip;
  final Future<void> Function() onPressed;
  final _SquareIconVariant variant;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    final isAccent = variant == _SquareIconVariant.accent;
    // A matched pair in weight, asymmetric in hue: confirm wears the accent
    // wash circle, reject the neutral wash circle — both read as buttons of
    // one component class while the color still ranks confirm first. The
    // compact discs center in full 48×48 hit targets so reduced-motor-control
    // users keep a Material-compliant tap zone.
    // Explicit button role + label, merged into one node, so screen readers
    // announce "Confirm, button" / "Reject, button" and rotor "next button"
    // navigation finds them — rather than leaning on the tooltip surfacing as
    // a label (which gives no role). The visual tooltip stays for pointer users
    // but is excluded from semantics to avoid a duplicate label.
    return MergeSemantics(
      child: Semantics(
        button: true,
        label: tooltip,
        child: Tooltip(
          message: tooltip,
          excludeFromSemantics: true,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed.call,
              borderRadius: BorderRadius.circular(tokens.radii.s),
              child: SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: Container(
                    width: tokens.spacing.step7,
                    height: tokens.spacing.step7,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isAccent ? ai.accentSoft : ai.subtleWashStrong,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: tokens.spacing.step5,
                      color: isAccent ? ai.accent : ai.metaText,
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

class ResolvedTag extends StatelessWidget {
  const ResolvedTag({required this.status, super.key});

  final ChangeItemStatus? status;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    final messages = context.messages;
    final isConfirmed = status == ChangeItemStatus.confirmed;
    // Quiet meta for confirmed too — an inert history tag must not flood the
    // card with accent when the ledger expands; the check glyph vs plain
    // word already separates the two outcomes.
    final color = isConfirmed ? ai.metaText : ai.faintMeta;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isConfirmed) ...[
            Icon(Icons.check, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            isConfirmed
                ? messages.aiCardProposalConfirmed
                : messages.aiCardProposalDismissed,
            style: tokens.typography.styles.others.caption.copyWith(
              color: color,
              fontWeight: tokens.typography.weight.semiBold,
            ),
          ),
        ],
      ),
    );
  }
}
