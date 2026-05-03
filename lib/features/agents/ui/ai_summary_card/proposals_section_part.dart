part of '../ai_summary_card.dart';

/// Proposals section sandwiched between the TLDR body and the activity
/// footer. Always shows the section title + pending count badge +
/// optional "Confirm all" button. The body is either an empty-state
/// placeholder or a vertical list of [_ProposalRow]s. Resolved entries
/// are rendered through [_HistoryToggle] + a hidden-by-default list.
class _ProposalsSection extends StatelessWidget {
  const _ProposalsSection({
    required this.open,
    required this.resolved,
    required this.historyOpen,
    required this.onToggleHistory,
    required this.confirmAllBusy,
    required this.onConfirmAll,
  });

  final List<PendingSuggestion> open;
  final List<LedgerEntry> resolved;
  final bool historyOpen;
  final VoidCallback onToggleHistory;
  final bool confirmAllBusy;
  final Future<void> Function()? onConfirmAll;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    final messages = context.messages;

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: ai.borderSoft)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.fact_check_outlined, size: 16, color: ai.accent),
              const SizedBox(width: 8),
              Text(
                messages.changeSetCardTitle,
                style: tokens.typography.styles.body.bodySmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
              ),
              const SizedBox(width: 8),
              _PendingPill(count: open.length),
              const Spacer(),
              if (onConfirmAll != null)
                _ConfirmAllButton(
                  busy: confirmAllBusy,
                  onPressed: onConfirmAll!,
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (open.isEmpty)
            const _EmptyProposalsRow()
          else
            for (var i = 0; i < open.length; i++)
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
                child: _ProposalRow(suggestion: open[i]),
              ),
          if (resolved.isNotEmpty) ...[
            const SizedBox(height: 10),
            _HistoryToggle(
              open: historyOpen,
              count: resolved.length,
              onPressed: onToggleHistory,
            ),
            if (historyOpen) ...[
              const SizedBox(height: 8),
              for (var i = 0; i < resolved.length; i++)
                Padding(
                  padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
                  child: _ProposalRow.fromLedger(entry: resolved[i]),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

class _PendingPill extends StatelessWidget {
  const _PendingPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    final hasItems = count > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: hasItems
            ? ai.accent.withValues(alpha: 0.10)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        context.messages.changeSetPendingCount(count),
        style: tokens.typography.styles.others.caption.copyWith(
          color: hasItems ? ai.accent : ai.metaText,
          fontWeight: FontWeight.w600,
          height: 1.1,
        ),
      ),
    );
  }
}

class _ConfirmAllButton extends StatelessWidget {
  const _ConfirmAllButton({required this.busy, required this.onPressed});

  final bool busy;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    return TextButton.icon(
      onPressed: busy ? null : onPressed.call,
      icon: busy
          ? SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: ai.accent,
              ),
            )
          : Icon(Icons.done_all_rounded, size: 16, color: ai.accent),
      label: Text(
        context.messages.changeSetConfirmAll,
        style: tokens.typography.styles.others.caption.copyWith(
          color: ai.accent,
          fontWeight: FontWeight.w600,
          height: 1.1,
        ),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        // Keep the visual chrome compact while honoring the Material
        // 48dp minimum hit target — the button's inner padding stays
        // tight, but the inkwell expands to a 48dp touch zone.
        minimumSize: const Size(48, 48),
        foregroundColor: ai.accent,
      ),
    );
  }
}

class _EmptyProposalsRow extends StatelessWidget {
  const _EmptyProposalsRow();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Center(
        child: Text(
          context.messages.aiCardEmptyProposals,
          style: tokens.typography.styles.others.caption.copyWith(
            color: ai.metaText,
            fontWeight: FontWeight.w400,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

class _HistoryToggle extends StatelessWidget {
  const _HistoryToggle({
    required this.open,
    required this.count,
    required this.onPressed,
  });

  final bool open;
  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                open ? Icons.keyboard_arrow_down : Icons.chevron_right,
                size: 14,
                color: ai.metaText,
              ),
              const SizedBox(width: 4),
              Text(
                context.messages.aiCardHistoryToggle(count),
                style: tokens.typography.styles.others.caption.copyWith(
                  color: ai.metaText,
                  fontWeight: FontWeight.w500,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One row in the open-proposals list (or, in resolved-history mode, a
/// read-only entry from the ledger). Pending rows are swipeable: drag
/// past `±_swipeTrigger` to confirm or reject. The `[✕]` / `[✓]`
/// icon buttons fire the same callbacks immediately. Resolved rows
/// render as a dimmed body with a Confirmed / Dismissed tag.
class _ProposalRow extends ConsumerStatefulWidget {
  const _ProposalRow({required PendingSuggestion this.suggestion})
    : entry = null;

  const _ProposalRow.fromLedger({required LedgerEntry this.entry})
    : suggestion = null;

  final PendingSuggestion? suggestion;
  final LedgerEntry? entry;

  bool get isResolved => entry != null;

  @override
  ConsumerState<_ProposalRow> createState() => _ProposalRowState();
}

class _ProposalRowState extends ConsumerState<_ProposalRow> {
  static const double _swipeTrigger = 70;

  double _dx = 0;
  bool _animating = false;
  bool _busy = false;

  String get _toolName =>
      widget.suggestion?.item.toolName ?? widget.entry!.toolName;
  Map<String, dynamic> get _args =>
      widget.suggestion?.item.args ?? widget.entry!.args;
  String get _humanSummary =>
      widget.suggestion?.item.humanSummary ?? widget.entry!.humanSummary;
  ChangeItemStatus? get _resolvedStatus => widget.entry?.status;

  void _onPointerDown(PointerDownEvent event) {
    if (widget.isResolved || _busy) return;
    setState(() => _animating = false);
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (widget.isResolved || _busy) return;
    setState(() => _dx += event.delta.dx);
  }

  Future<void> _onPointerUp(PointerUpEvent event) async {
    if (widget.isResolved || _busy) return;
    setState(() => _animating = true);
    if (_dx > _swipeTrigger) {
      await _confirm();
    } else if (_dx < -_swipeTrigger) {
      await _reject();
    }
    if (mounted) setState(() => _dx = 0);
  }

  /// Reset the swipe state when an enclosing scrollable wins the gesture
  /// arena (which fires a `PointerCancelEvent` instead of pointer-up).
  /// Without this the row stays translated at its last `_dx` and looks
  /// stuck off-axis.
  void _onPointerCancel(PointerCancelEvent event) {
    if (widget.isResolved || _busy) return;
    setState(() {
      _animating = true;
      _dx = 0;
    });
  }

  Future<void> _confirm() async {
    final suggestion = widget.suggestion;
    if (suggestion == null || _busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final messages = context.messages;
    final service = ref.read(changeSetConfirmationServiceProvider);
    final notifier = ref.read(updateNotificationsProvider);
    try {
      final result = await service.confirmItem(
        suggestion.changeSet,
        suggestion.itemIndex,
      );
      notifier.notify({suggestion.changeSet.agentId});
      final tone = !result.success
          ? DesignSystemToastTone.error
          : result.errorMessage != null
          ? DesignSystemToastTone.warning
          : DesignSystemToastTone.success;
      final message = !result.success
          ? messages.changeSetConfirmError
          : result.errorMessage != null
          ? messages.changeSetItemConfirmedWithWarning(result.errorMessage!)
          : messages.changeSetItemConfirmed;
      messenger.showDesignSystemToast(
        tone: tone,
        title: message,
        clearQueue: true,
      );
    } catch (e) {
      developer.log('confirmItem failed: $e', name: 'AiSummaryCard');
      messenger.showDesignSystemToast(
        tone: DesignSystemToastTone.error,
        title: messages.changeSetConfirmError,
        clearQueue: true,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    final suggestion = widget.suggestion;
    if (suggestion == null || _busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final messages = context.messages;
    final service = ref.read(changeSetConfirmationServiceProvider);
    final notifier = ref.read(updateNotificationsProvider);
    try {
      final applied = await service.rejectItem(
        suggestion.changeSet,
        suggestion.itemIndex,
      );
      notifier.notify({suggestion.changeSet.agentId});
      messenger.showDesignSystemToast(
        tone: applied
            ? DesignSystemToastTone.success
            : DesignSystemToastTone.error,
        title: applied
            ? messages.changeSetItemRejected
            : messages.changeSetConfirmError,
        clearQueue: true,
      );
    } catch (e) {
      developer.log('rejectItem failed: $e', name: 'AiSummaryCard');
      messenger.showDesignSystemToast(
        tone: DesignSystemToastTone.error,
        title: messages.changeSetConfirmError,
        clearQueue: true,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    final kind = _resolveKind(_toolName, _args);
    final kindMeta = _kindMeta(context, kind);
    final cleanText = _cleanText(_humanSummary, kindMeta.label);

    final dx = _dx;
    final intentLabel = dx > 30
        ? context.messages.changeSetSwipeConfirm
        : dx < -30
        ? context.messages.changeSetSwipeReject
        : null;
    final intentColor = dx >= 0
        ? ai.accent
        : tokens.colors.alert.error.defaultColor;

    final lineThrough =
        _resolvedStatus == ChangeItemStatus.rejected ||
        _resolvedStatus == ChangeItemStatus.retracted;
    final dimmed = lineThrough;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              decoration: BoxDecoration(
                gradient: dx == 0
                    ? null
                    : LinearGradient(
                        begin: dx > 0
                            ? Alignment.centerLeft
                            : Alignment.centerRight,
                        end: dx > 0
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        colors: [
                          intentColor.withValues(alpha: 0.20),
                          Colors.transparent,
                        ],
                      ),
              ),
              alignment: dx > 0 ? Alignment.centerLeft : Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: intentLabel == null
                  ? const SizedBox.shrink()
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (dx > 0)
                          Icon(Icons.check, size: 14, color: intentColor),
                        if (dx > 0) const SizedBox(width: 6),
                        Text(
                          intentLabel,
                          style: tokens.typography.styles.others.caption
                              .copyWith(
                                color: intentColor,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        if (dx < 0) const SizedBox(width: 6),
                        if (dx < 0)
                          Icon(Icons.close, size: 14, color: intentColor),
                      ],
                    ),
            ),
          ),
          AnimatedContainer(
            duration: _animating
                ? const Duration(milliseconds: 180)
                : Duration.zero,
            transform: Matrix4.translationValues(dx, 0, 0),
            decoration: BoxDecoration(
              color: widget.isResolved
                  ? Colors.white.withValues(alpha: 0.02)
                  : ai.row,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ai.rowBorder),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Listener(
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
              onPointerUp: _onPointerUp,
              onPointerCancel: _onPointerCancel,
              behavior: HitTestBehavior.opaque,
              child: Opacity(
                opacity: dimmed ? 0.45 : 1,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _KindChip(meta: kindMeta),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        cleanText,
                        style: tokens.typography.styles.body.bodySmall.copyWith(
                          color: ai.bodyText,
                          height: 1.5,
                          decoration: lineThrough
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (widget.isResolved)
                      _ResolvedTag(status: _resolvedStatus)
                    else
                      _RowActions(
                        busy: _busy,
                        onReject: _reject,
                        onConfirm: _confirm,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _cleanText(String summary, String kindLabel) {
    final pattern = RegExp(
      '^\\s*${RegExp.escape(kindLabel)}\\b[\\s:]*',
      caseSensitive: false,
    );
    return summary.replaceFirst(pattern, '').trim();
  }
}

class _KindChip extends StatelessWidget {
  const _KindChip({required this.meta});

  final _KindMeta meta;

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

class _RowActions extends StatelessWidget {
  const _RowActions({
    required this.busy,
    required this.onReject,
    required this.onConfirm,
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

class _ResolvedTag extends StatelessWidget {
  const _ResolvedTag({required this.status});

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
