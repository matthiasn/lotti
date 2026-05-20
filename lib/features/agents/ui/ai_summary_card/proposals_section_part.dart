part of '../ai_summary_card.dart';

/// Width threshold below which the proposal row drops its explicit
/// confirm/reject buttons. The whole row stays swipeable (right →
/// confirm, left → dismiss); on narrow phones the chevron-style
/// icon buttons just consume too much horizontal space and crowd the
/// proposal text. Matches `AgentInternalsPanel.mobileBreakpoint` so
/// the AI surface flips between compact and comfortable layouts at
/// the same screen size.
const double _proposalRowCompactWidth = 600;

bool _isCompactWidth(BuildContext context) =>
    MediaQuery.sizeOf(context).width < _proposalRowCompactWidth;

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
    super.key,
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
          // Title block on the left (icon + label + pending-count
          // pill, wraps internally if the card is too narrow to fit
          // them on one line) and the Confirm-all button pinned to
          // the right edge so it lines up with the Read-more pill in
          // the header above. `Expanded` collapses harmlessly on
          // empty/single-child rows when the button isn't shown.
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Icon(
                      Icons.fact_check_outlined,
                      size: 16,
                      color: ai.accent,
                    ),
                    Text(
                      messages.changeSetCardTitle,
                      style: tokens.typography.styles.body.bodySmall.copyWith(
                        color: ai.titleText,
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                      ),
                    ),
                    _PendingPill(count: open.length),
                  ],
                ),
              ),
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
                child: _ProposalRow(
                  suggestion: open[i],
                  // Only the first pending row gets the swipe-affordance
                  // wiggle hint so the page doesn't pulse with every
                  // visible row.
                  isFirst: i == 0,
                ),
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
            : ai.subtleWashStrong,
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
        color: ai.subtleWash,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ai.subtleBorder),
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
///
/// Pass `isFirst: true` to the topmost pending row to opt into a
/// one-shot wiggle hint that runs on narrow viewports (where the
/// confirm/reject buttons are hidden) so users learn the row is
/// swipeable. The hint respects `MediaQuery.disableAnimationsOf` and
/// is suppressed once the user starts interacting.
class _ProposalRow extends ConsumerStatefulWidget {
  const _ProposalRow({
    required PendingSuggestion this.suggestion,
    this.isFirst = false,
  }) : entry = null;

  const _ProposalRow.fromLedger({required LedgerEntry this.entry})
    : suggestion = null,
      isFirst = false;

  final PendingSuggestion? suggestion;
  final LedgerEntry? entry;

  /// Whether this row is the topmost pending row. Drives the
  /// swipe-affordance wiggle hint on narrow viewports.
  final bool isFirst;

  bool get isResolved => entry != null;

  @override
  ConsumerState<_ProposalRow> createState() => _ProposalRowState();
}

class _ProposalRowState extends ConsumerState<_ProposalRow>
    with SingleTickerProviderStateMixin {
  static const double _swipeTrigger = 70;

  /// Peek distance for the swipe-affordance wiggle hint. The row
  /// peeks once to the right, settles back to zero, briefly holds at
  /// rest, then peeks once to the left and settles. Two distinct
  /// "look, I move this way" demos rather than one continuous
  /// sweep — the rest plateau is what separates them.
  static const double _wiggleAmplitude = 14;

  double _dx = 0;
  bool _animating = false;
  bool _busy = false;

  AnimationController? _wiggleController;
  Animation<double>? _wiggleOffset;
  Timer? _wiggleStartTimer;
  bool _wiggleScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Kick the wiggle hint off the first time we get a real
    // `BuildContext` (so we can read media queries), then never again.
    // The hint runs on every viewport — on desktop it teaches the
    // user the row is swipeable in addition to the buttons; on
    // mobile it's the only swipe affordance besides the gradient
    // backdrop. The only opt-out is system reduce-motion.
    if (_wiggleScheduled || widget.isResolved || !widget.isFirst) return;
    if (MediaQuery.of(context).disableAnimations) {
      _wiggleScheduled = true;
      return;
    }
    _wiggleScheduled = true;
    _wiggleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    // Right peek (350ms out + 350ms back, easeInOutSine), brief
    // hold at rest (200ms), then left peek (same shape mirrored).
    // The plateau at zero is the whole point of this variant —
    // it makes the right and left peeks read as two separate
    // demonstrations instead of one continuous sweep, so the
    // gradient backdrop has time to settle between them.
    Animatable<double> sineLeg(double from, double to) => Tween<double>(
      begin: from,
      end: to,
    ).chain(CurveTween(curve: Curves.easeInOutSine));
    _wiggleOffset =
        TweenSequence<double>([
          TweenSequenceItem(tween: sineLeg(0, _wiggleAmplitude), weight: 7),
          TweenSequenceItem(tween: sineLeg(_wiggleAmplitude, 0), weight: 7),
          TweenSequenceItem(
            tween: ConstantTween<double>(0),
            weight: 4,
          ),
          TweenSequenceItem(tween: sineLeg(0, -_wiggleAmplitude), weight: 7),
          TweenSequenceItem(tween: sineLeg(-_wiggleAmplitude, 0), weight: 7),
        ]).animate(_wiggleController!)..addListener(() {
          if (mounted) setState(() {});
        });
    // Small delay so the row is settled and visible before it
    // wiggles — avoids fighting the page's own appear animation.
    _wiggleStartTimer = Timer(const Duration(milliseconds: 350), () {
      _wiggleStartTimer = null;
      if (!mounted || _wiggleController == null) return;
      _wiggleController!.forward(from: 0);
    });
  }

  void _stopWiggle() {
    _wiggleStartTimer?.cancel();
    _wiggleStartTimer = null;
    _wiggleController?.stop();
    _wiggleController?.value = 0;
  }

  @override
  void dispose() {
    _wiggleStartTimer?.cancel();
    _wiggleController?.dispose();
    super.dispose();
  }

  String get _toolName =>
      widget.suggestion?.item.toolName ?? widget.entry!.toolName;
  Map<String, dynamic> get _args =>
      widget.suggestion?.item.args ?? widget.entry!.args;
  String get _humanSummary =>
      widget.suggestion?.item.humanSummary ?? widget.entry!.humanSummary;
  ChangeItemStatus? get _resolvedStatus => widget.entry?.status;

  // The row uses a `GestureDetector` (not a raw `Listener`) so its
  // horizontal drag participates in Flutter's gesture arena. This is
  // what lets a swipe still win when the touch starts inside one of
  // the row's child InkWells (icon buttons, kind chip) — a `Listener`
  // with `HitTestBehavior.opaque` only receives pointers that land
  // outside other interactive children, which made swipe-from-button
  // start a no-op. The arena correctly hands the pointer to whichever
  // gesture (tap / horizontal drag) the user actually expressed.

  void _onHorizontalDragStart(DragStartDetails details) {
    if (widget.isResolved || _busy) return;
    // The user is interacting — drop the hint immediately so it
    // doesn't fight the real drag offset.
    _stopWiggle();
    setState(() => _animating = false);
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (widget.isResolved || _busy) return;
    // Clamp to ±2× the swipe trigger so very fast or very long drags
    // can't translate the row off-screen — the gradient backdrop and
    // intent label both look sensible up to this range, past it the
    // row would just disappear without communicating anything new.
    setState(
      () => _dx = (_dx + details.delta.dx).clamp(
        -_swipeTrigger * 2,
        _swipeTrigger * 2,
      ),
    );
  }

  Future<void> _onHorizontalDragEnd(DragEndDetails details) async {
    if (widget.isResolved || _busy) return;
    setState(() => _animating = true);
    if (_dx > _swipeTrigger) {
      await _confirm();
    } else if (_dx < -_swipeTrigger) {
      await _reject();
    }
    if (mounted) setState(() => _dx = 0);
  }

  /// Reset the swipe state when an enclosing scrollable wins the
  /// gesture arena. Without this the row stays translated at its
  /// last `_dx` and looks stuck off-axis.
  void _onHorizontalDragCancel() {
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

    // Combine the user's drag offset with any hint-wiggle so the
    // gradient backdrop and the row translation stay in sync.
    final dx = _dx + (_wiggleOffset?.value ?? 0);
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
              color: widget.isResolved ? ai.subtleWash : ai.row,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ai.rowBorder),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: _onHorizontalDragStart,
              onHorizontalDragUpdate: _onHorizontalDragUpdate,
              onHorizontalDragEnd: _onHorizontalDragEnd,
              onHorizontalDragCancel: _onHorizontalDragCancel,
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
                    else if (_isCompactWidth(context))
                      // On narrow viewports the buttons take up too
                      // much horizontal space — rely on swipe alone
                      // (the `GestureDetector` above accepts a swipe
                      // anywhere on the row, and the gradient backdrop
                      // surfaces the "Confirm" / "Dismiss" intent past
                      // the swipe threshold).
                      const SizedBox.shrink()
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

  // Cache the cleaned proposal text so the kind-prefix regex isn't
  // recompiled on every frame — `build` runs continuously while the
  // row is being dragged or wiggled, and a `RegExp` allocation per
  // frame shows up under DevTools. Cleared whenever the underlying
  // tool / summary or the kind-label-driving locale changes.
  // Stays nullable so the cache hit branch is naturally guarded by
  // the input-key compare; promoting to `late` would make the cold
  // path indistinguishable from a hit on first build.
  // ignore: use_late_for_private_fields_and_variables
  String? _cachedCleanText;
  String? _cachedCleanInputKey;

  String _cleanText(String summary, String kindLabel) {
    final key = '$kindLabel\u0000$summary';
    if (_cachedCleanInputKey == key) return _cachedCleanText!;
    final pattern = RegExp(
      '^\\s*${RegExp.escape(kindLabel)}\\b[\\s:]*',
      caseSensitive: false,
    );
    final result = summary.replaceFirst(pattern, '').trim();
    _cachedCleanInputKey = key;
    _cachedCleanText = result;
    return result;
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
