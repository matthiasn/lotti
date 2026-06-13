import 'package:flutter/material.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/proposal_kind_part.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

class KindChip extends StatelessWidget {
  const KindChip({required this.meta, super.key});

  final KindMeta meta;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      margin: const EdgeInsets.only(top: 1),
      decoration: BoxDecoration(
        color: meta.surface,
        borderRadius: BorderRadius.circular(5),
      ),
      alignment: Alignment.center,
      child: Text(
        meta.label,
        style: tokens.typography.styles.others.caption.copyWith(
          color: meta.color,
          fontWeight: FontWeight.w600,
          height: 1,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

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
    // Each [_SquareIconButton] already centers its 26×26 visual inside
    // a 48×48 hit zone, so the visible chips end up ≈22px apart with
    // no extra gap — matching the spec'd compact rhythm.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SquareIconButton(
          icon: Icons.close_rounded,
          tooltip: context.messages.changeSetSwipeReject,
          onPressed: onReject,
          variant: _SquareIconVariant.outline,
        ),
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
    final ai = context.designTokens.colors.aiCard;
    final isAccent = variant == _SquareIconVariant.accent;
    // The visual chip stays at the spec'd 26×26, but it's centered
    // inside a 48×48 hit target so users with reduced motor control or
    // touch precision still get a Material-compliant tap zone. The
    // outer SizedBox + InkWell expand the gesture-accepting region;
    // the inner Container preserves the compact look.
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed.call,
          borderRadius: BorderRadius.circular(7),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: isAccent ? ai.accent.withValues(alpha: 0.13) : null,
                  border: Border.all(
                    color: isAccent
                        ? ai.accent.withValues(alpha: 0.33)
                        : ai.rowBorderStrong,
                  ),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(
                  icon,
                  size: 14,
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
