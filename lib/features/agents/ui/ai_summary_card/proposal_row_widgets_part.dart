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
      // Match the 40×40 footprint of a single non-busy
      // [_SquareIconButton] so the row doesn't reflow when toggling.
      return SizedBox(
        width: 40,
        height: 40,
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
    // Each [_SquareIconButton] is a quiet ghost icon inside a 40×40 hit
    // zone — color (meta-gray reject, accent confirm) carries the meaning,
    // so the rows shed the boxed chrome. A `step4` gap separates the two hit
    // zones so the destructive reject is never flush against accept.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SquareIconButton(
          icon: Icons.close_rounded,
          tooltip: context.messages.changeSetSwipeReject,
          onPressed: onReject,
          variant: _SquareIconVariant.outline,
        ),
        SizedBox(width: context.designTokens.spacing.step4),
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
    // Ghost chrome: just the glyph, centered in a 40×40 hit target so
    // reduced-motor-control users still get a compliant tap zone without the
    // slot inflating the row.
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
                width: 40,
                height: 40,
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
    final color = isConfirmed ? ai.accent : ai.faintMeta;
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
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}
