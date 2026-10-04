part of 'proposal_row_part.dart';

/// The in-place acknowledgement badge shown while a row resolves: a **filled**,
/// high-contrast disc (a dark glyph on the verdict colour) next to a
/// plain-language word — "Confirmed" for accept, "Dismissed" for reject. The
/// solid disc reads clearly against the teal card where a faint outline ring
/// did not (for low-vision users), the word states the outcome literally (for
/// users who want to be *told*, not just shown), and both live at the gesture
/// rather than in a separate toast.
class _ResolveBadge extends StatelessWidget {
  const _ResolveBadge({required this.kind});

  final ProposalResolveKind kind;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    final messages = context.messages;
    final accept = kind == ProposalResolveKind.accept;
    final color = accept ? ai.accent : tokens.colors.alert.error.ink;
    final label = accept
        ? messages.aiCardProposalConfirmed
        : messages.aiCardProposalDismissed;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Icon(
            accept ? LottiIcons.confirm : LottiIcons.close,
            size: 17,
            // A dark glyph on the bright verdict fill — maximum contrast on the
            // card, and fully token-driven (the card's own background colour).
            color: ai.background,
          ),
        ),
        SizedBox(width: tokens.spacing.step2),
        Text(
          label,
          style: tokens.typography.styles.others.caption.copyWith(
            color: color,
            fontWeight: tokens.typography.weight.bold,
          ),
        ),
      ],
    );
  }
}

/// The inner content of a proposal row: the kind chip, the human summary
/// text, and the trailing actions / resolved tag.
///
/// Layout adapts to width:
/// * **Narrow viewports** stack the kind chip *above* full-width text, so
///   the summary reads as one clean rectangular block instead of text
///   squished into a ragged column beside the chip. Action buttons stay
///   hidden here — the whole row is swipeable (right = confirm, left =
///   dismiss) — so only resolved rows show a trailing status tag, pinned
///   to the chip line.
/// * **Comfortable viewports** keep the chip, text, and trailing actions
///   on a single row.
class ProposalRowContent extends StatelessWidget {
  const ProposalRowContent({
    required this.meta,
    required this.text,
    required this.lineThrough,
    required this.isResolved,
    required this.resolvedStatus,
    required this.busy,
    required this.onReject,
    required this.onConfirm,
    this.resolving = false,
    super.key,
  });

  final KindMeta meta;
  final String text;
  final bool lineThrough;
  final bool isResolved;
  final ChangeItemStatus? resolvedStatus;
  final bool busy;

  /// True while the row is acknowledging a commit: the trailing ✓/✕ buttons
  /// (and busy spinner) are hidden because the resolve badge is the indicator.
  final bool resolving;

  final Future<void> Function() onReject;
  final Future<void> Function() onConfirm;

  /// The trailing slot: a resolved-status tag for history rows, an empty slot
  /// the width of the action rail while resolving (the badge overlays it),
  /// else the action buttons. The slot keeps [RowActions.footprintWidth] in
  /// every pending state so the text beside it never rewraps on resolve.
  Widget _trailing(BuildContext context) {
    if (isResolved) return ResolvedTag(status: resolvedStatus);
    if (resolving) {
      return SizedBox(
        width: RowActions.footprintWidth(context),
        height: RowActions.buttonSize,
      );
    }
    return RowActions(busy: busy, onReject: onReject, onConfirm: onConfirm);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    // One anatomy at every width: the proposal text leads with its kind as a
    // quiet inline prefix ("Update · …"), the verdict actions sit trailing
    // and vertically centered. Every summary starts on the same axis (no
    // variable-width leading chip) and the kind never owns a line of its
    // own. The prefix keeps the body's size and metrics — color alone
    // separates it, so the line reads as one run of text instead of two
    // sizes patched together. The whole row stays swipeable (right =
    // confirm, left = dismiss) — the buttons are an additional, visible
    // affordance so the action isn't swipe-only-and-hidden.
    final textWidget = Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '${meta.label} · ',
            style: TextStyle(color: ai.metaText),
          ),
          TextSpan(text: text),
        ],
      ),
      style: tokens.typography.styles.body.bodySmall.copyWith(
        color: ai.bodyText,
        decoration: lineThrough ? TextDecoration.lineThrough : null,
      ),
    );

    return Row(
      children: [
        Expanded(child: textWidget),
        SizedBox(width: tokens.spacing.step2),
        _trailing(context),
      ],
    );
  }
}
