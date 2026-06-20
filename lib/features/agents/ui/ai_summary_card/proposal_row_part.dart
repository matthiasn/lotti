import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/proposal_ledger.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/change_set_providers.dart';
import 'package:lotti/features/agents/state/unified_suggestion_providers.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/proposal_kind_part.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/proposal_row_widgets_part.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Width threshold below which the proposal row drops its explicit
/// confirm/reject buttons. The whole row stays swipeable (right →
/// confirm, left → dismiss); on narrow phones the chevron-style
/// icon buttons just consume too much horizontal space and crowd the
/// proposal text. Matches `AgentInternalsPanel.mobileBreakpoint` so
/// the AI surface flips between compact and comfortable layouts at
/// the same screen size.
const double _proposalRowCompactWidth = 600;

bool isCompactWidth(BuildContext context) =>
    MediaQuery.sizeOf(context).width < _proposalRowCompactWidth;

/// Whether the one-shot swipe-affordance nudge has already played this session.
///
/// Held outside the row (session scope) on purpose: the old wiggle re-armed
/// every time a row was promoted to first, so clearing a stack replayed it
/// after every accept. Gating on a shared flag means it plays at most once per
/// session, then never again — not on the next promotion, not on a new
/// proposal. Reset only when the app (and this `ProviderScope`) restarts.
class ProposalSwipeNudgePlayed extends Notifier<bool> {
  @override
  bool build() => false;

  /// Mark the nudge as shown — call after it has been scheduled once.
  void markPlayed() => state = true;
}

final proposalSwipeNudgePlayedProvider =
    NotifierProvider<ProposalSwipeNudgePlayed, bool>(
      ProposalSwipeNudgePlayed.new,
    );

/// How a row is leaving: confirmed (accept) or dismissed (reject). Drives the
/// in-place "resolve" beat's glyph, wash colour, and motion before the row
/// collapses away.
enum ProposalResolveKind { accept, reject }

/// Single swipeable proposal row: swipe right to confirm, left to
/// dismiss, with wiggle hint + busy spinner state handling.
class ProposalRow extends ConsumerStatefulWidget {
  const ProposalRow({
    required PendingSuggestion this.suggestion,
    this.isFirst = false,
    this.confirmAllPulse = 0,
    this.cascadeIndex = 0,
    this.onResolveStart,
    this.onResolveEnd,
    this.settling = false,
    this.pendingCount = 0,
    super.key,
  }) : entry = null;

  const ProposalRow.fromLedger({required LedgerEntry this.entry, super.key})
    : suggestion = null,
      isFirst = false,
      confirmAllPulse = 0,
      cascadeIndex = 0,
      onResolveStart = null,
      onResolveEnd = null,
      settling = false,
      pendingCount = 0;

  final PendingSuggestion? suggestion;
  final LedgerEntry? entry;

  /// Whether this row is the topmost pending row. Drives the
  /// swipe-affordance wiggle hint on narrow viewports.
  final bool isFirst;

  /// Incremented by the parent each time "Confirm all" is pressed; the row
  /// reacts by running its resolve → collapse exit (staggered by
  /// [cascadeIndex]) so a batch confirm reads as one downward sweep that
  /// settles, rather than everything vanishing at once.
  final int confirmAllPulse;

  /// This row's position in the open list, used to stagger the confirm-all
  /// sweep so it rolls top-to-bottom.
  final int cascadeIndex;

  /// Called the instant the user commits to accept/reject this row, *before*
  /// the data write completes. The shell records the suggestion's fingerprint
  /// so it keeps the row mounted (collapsing in place) even after the provider
  /// drops it — the exit animation, not the provider, removes the row.
  final void Function(PendingSuggestion suggestion)? onResolveStart;

  /// Called once the row's exit animation has finished (`removed: true`), or
  /// when the write failed / was a no-op so the row must stay
  /// (`removed: false`). The shell stops retaining the suggestion and either
  /// drops it from the visible list now (independent of provider timing) or
  /// restores it from provider truth.
  final void Function(PendingSuggestion suggestion, {required bool removed})?
  onResolveEnd;

  /// True while *another* row in the section is committing and collapsing.
  /// During that window the surviving rows are sliding up, so this row treats
  /// a tap/swipe as inert — a fast second action can't land on a row that just
  /// moved under the pointer (the verdict for the row that's already leaving is
  /// guarded separately by its own busy/exiting state).
  final bool settling;

  /// The current pending-proposal count (including this row). Used only to
  /// announce the *remaining* count to screen-reader users on commit.
  final int pendingCount;

  bool get isResolved => entry != null;

  @override
  ConsumerState<ProposalRow> createState() => _ProposalRowState();
}

class _ProposalRowState extends ConsumerState<ProposalRow>
    with TickerProviderStateMixin {
  static const double _swipeTrigger = 70;

  /// Peek distance for the one-shot swipe-affordance nudge. A single, gentle
  /// peek toward the confirm (right) direction, out and back — a hint that
  /// *points*, not a two-way demo that performs the whole mechanic.
  static const double _wiggleAmplitude = 10;

  double _dx = 0;
  bool _animating = false;
  bool _busy = false;

  AnimationController? _wiggleController;
  Animation<double>? _wiggleOffset;
  Timer? _wiggleStartTimer;
  bool _wiggleScheduled = false;

  /// Per-row delay timer for the "Confirm all" downward sweep.
  Timer? _cascadeTimer;

  /// Drives the in-place acknowledgement beat (check / dismiss glyph fading in,
  /// the row's wash settling) — no layout change, so the row the finger is on
  /// never moves out from under it. Reversible: a failed write rewinds it.
  late final AnimationController _resolveController;
  late final Animation<double> _resolveT;

  /// Drives the height collapse + content fade once the write succeeds. Its
  /// reverse drives [_collapseSize] (height 1→0) and [_collapseContentOpacity]
  /// (content 1→0, leading the height so the gap reads as space *healing*).
  late final AnimationController _collapseController;
  late final Animation<double> _collapseSize;
  late final Animation<double> _collapseContentOpacity;

  /// Set the instant the user commits; reject leans the row toward the discard
  /// edge while accept locks in place.
  ProposalResolveKind? _resolveKind;

  /// True once the collapse has begun — the row is on its way out and must
  /// ignore further gestures.
  bool _exiting = false;

  @override
  void initState() {
    super.initState();
    _resolveController = AnimationController(
      vsync: this,
      duration: ProposalMotion.resolveHold,
    )..addListener(_onResolveTick);
    _resolveT = CurvedAnimation(
      parent: _resolveController,
      curve: MotionCurves.emphasizedDecelerate,
    );

    _collapseController = AnimationController(
      vsync: this,
      duration: ProposalMotion.collapse,
    );
    // Height holds for the first sliver of the collapse so the resolve beat
    // registers, then eases to zero on the soft-tail curve. Reversed because
    // the controller runs 0→1 while the height goes full→zero.
    _collapseSize = ReverseAnimation(
      CurvedAnimation(
        parent: _collapseController,
        curve: const Interval(0.10, 1, curve: ProposalMotion.collapseCurve),
      ),
    );
    // Content opacity leads the height: fully faded by ~60% of the collapse,
    // so by the time the gap is closing the row is already visually gone.
    _collapseContentOpacity = ReverseAnimation(
      CurvedAnimation(
        parent: _collapseController,
        curve: const Interval(0.18, 0.62, curve: MotionCurves.standard),
      ),
    );
  }

  @override
  void didUpdateWidget(ProposalRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A fresh "Confirm all" press: run this row's resolve → collapse exit
    // after a per-index delay so the batch reads as one downward sweep that
    // settles (the last row lands last), not N rows vanishing at once. The
    // service writes are done by the shell; here the row only plays its own
    // exit (and reports it, so the shell retains the row until it collapses).
    // The haptic fires once for the whole gesture in the shell, not per row.
    if (widget.confirmAllPulse > oldWidget.confirmAllPulse &&
        !widget.isResolved &&
        !_exiting &&
        !_busy) {
      _cascadeTimer?.cancel();
      final reduceMotion = MediaQuery.disableAnimationsOf(context);
      _cascadeTimer = Timer(
        ProposalMotion.staggerStep * math.min(widget.cascadeIndex, 8),
        () {
          if (!mounted || _exiting || _busy) return;
          final suggestion = widget.suggestion;
          if (suggestion == null) return;
          _stopWiggle();
          setState(() {
            _busy = true;
            _resolveKind = ProposalResolveKind.accept;
          });
          widget.onResolveStart?.call(suggestion);
          if (!reduceMotion) _resolveController.forward(from: 0);
          unawaited(_collapseAndPrune(suggestion, reduceMotion: reduceMotion));
        },
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeScheduleNudge();
  }

  /// Schedules the one-shot swipe-affordance nudge — once per session, on the
  /// first pending row. The "already played" flag lives in a session provider,
  /// not per-row state, so promoting the next row to first never re-fires it
  /// (the old wiggle's worst trait). Suppressed under reduced motion.
  /// Decorative, so it carries no semantics.
  void _maybeScheduleNudge() {
    if (_wiggleScheduled || widget.isResolved || !widget.isFirst) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _wiggleScheduled = true;
      return;
    }
    if (ref.read(proposalSwipeNudgePlayedProvider)) {
      _wiggleScheduled = true;
      return;
    }
    _wiggleScheduled = true;
    _wiggleController = AnimationController(
      vsync: this,
      duration: ProposalMotion.nudge,
    );
    // A single directional peek: out toward confirm (right) on the decelerate
    // curve, then settle back on the standard curve. One beat, one direction —
    // it suggests "this slides", it doesn't perform both directions.
    _wiggleOffset =
        TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween<double>(begin: 0, end: _wiggleAmplitude).chain(
              CurveTween(curve: MotionCurves.emphasizedDecelerate),
            ),
            weight: 45,
          ),
          TweenSequenceItem(
            tween: Tween<double>(begin: _wiggleAmplitude, end: 0).chain(
              CurveTween(curve: MotionCurves.standard),
            ),
            weight: 55,
          ),
        ]).animate(_wiggleController!)..addListener(() {
          if (mounted) setState(() {});
        });
    // Small delay so the row is settled and visible before it nudges — avoids
    // fighting the page's own appear animation. The session flag is set here
    // (post-frame, in the timer callback) rather than during the build-phase
    // `didChangeDependencies`, where mutating a provider is forbidden.
    _wiggleStartTimer = Timer(const Duration(milliseconds: 350), () {
      _wiggleStartTimer = null;
      if (!mounted || _wiggleController == null) return;
      ref.read(proposalSwipeNudgePlayedProvider.notifier).markPlayed();
      _wiggleController!.forward(from: 0);
    });
  }

  /// Rebuild as the resolve beat ticks so the wash + glyph track the curve.
  /// (`SizeTransition`/`FadeTransition` self-listen for the collapse, so the
  /// collapse controller needs no explicit `setState` listener.)
  void _onResolveTick() {
    if (mounted) setState(() {});
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
    _cascadeTimer?.cancel();
    _resolveController.dispose();
    _collapseController.dispose();
    super.dispose();
  }

  /// How many proposals remain after this row is committed — for the
  /// screen-reader announcement. Clamped at 0 (never negative).
  int get _remainingAfterCommit =>
      widget.pendingCount > 0 ? widget.pendingCount - 1 : 0;

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
    if (widget.isResolved || _busy || _exiting || widget.settling) return;
    // The user is interacting — drop the hint immediately so it
    // doesn't fight the real drag offset.
    _stopWiggle();
    setState(() => _animating = false);
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (widget.isResolved || _busy || _exiting || widget.settling) return;
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
    if (widget.isResolved || _busy || _exiting || widget.settling) return;
    setState(() => _animating = true);
    if (_dx > _swipeTrigger) {
      // Snap the drag offset back to rest first so the resolve beat plays
      // from the row's home position, not from wherever the finger let go.
      setState(() => _dx = 0);
      await _confirm();
      return;
    } else if (_dx < -_swipeTrigger) {
      setState(() => _dx = 0);
      await _reject();
      return;
    }
    if (mounted) setState(() => _dx = 0);
  }

  /// Reset the swipe state when an enclosing scrollable wins the
  /// gesture arena. Without this the row stays translated at its
  /// last `_dx` and looks stuck off-axis.
  void _onHorizontalDragCancel() {
    if (widget.isResolved || _busy || _exiting || widget.settling) return;
    setState(() {
      _animating = true;
      _dx = 0;
    });
  }

  /// Begin the in-place acknowledgement: record the verdict, fire the light
  /// haptic (feedback, so it plays even under reduced motion), and run the
  /// short resolve animation (skipped under reduced motion). No layout change.
  void _beginResolve(ProposalResolveKind kind, {required bool reduceMotion}) {
    setState(() => _resolveKind = kind);
    unawaited(HapticFeedback.lightImpact());
    if (!reduceMotion) _resolveController.forward(from: 0);
  }

  /// Rewind the resolve beat when the write failed — the row stays put. The
  /// wash + glyph fade back out, then the verdict is cleared.
  void _cancelResolve() {
    if (!mounted) return;
    _resolveController.reverse().whenCompleteOrCancel(() {
      if (mounted) setState(() => _resolveKind = null);
    });
  }

  /// Collapse the row away and tell the shell to prune it. Under reduced motion
  /// there is no height/opacity travel — the row is pruned immediately so the
  /// list re-lays-out in one frame.
  ///
  /// The collapse only begins once the resolve beat has established (~70%), so
  /// the row clearly acknowledges in place *before* it leaves — the two beats
  /// overlap on the tail rather than fighting on the same frame.
  Future<void> _collapseAndPrune(
    PendingSuggestion suggestion, {
    required bool reduceMotion,
  }) async {
    _exiting = true;
    if (reduceMotion) {
      widget.onResolveEnd?.call(suggestion, removed: true);
      return;
    }
    await _awaitResolveThreshold(ProposalMotion.collapseStart);
    if (!mounted) return;
    await _collapseController.forward(from: 0);
    if (mounted) widget.onResolveEnd?.call(suggestion, removed: true);
  }

  /// Completes once the resolve beat has progressed past [threshold] (0–1).
  /// Driven by the controller's ticks, so a widget `pump` advances it.
  Future<void> _awaitResolveThreshold(double threshold) {
    if (_resolveController.value >= threshold) return Future<void>.value();
    final completer = Completer<void>();
    void listener() {
      if (_resolveController.value >= threshold) {
        _resolveController.removeListener(listener);
        if (!completer.isCompleted) completer.complete();
      }
    }

    _resolveController.addListener(listener);
    return completer.future;
  }

  Future<void> _confirm() async {
    final suggestion = widget.suggestion;
    if (suggestion == null || _busy || _exiting || widget.settling) return;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    setState(() => _busy = true);
    _stopWiggle();
    // Acknowledge in place and signal the shell to keep the row mounted while
    // it leaves — the data write runs concurrently with the resolve beat.
    _beginResolve(ProposalResolveKind.accept, reduceMotion: reduceMotion);
    widget.onResolveStart?.call(suggestion);
    final messenger = ScaffoldMessenger.of(context);
    final messages = context.messages;
    final textDirection = Directionality.of(context);
    final view = View.of(context);
    final service = ref.read(changeSetConfirmationServiceProvider);
    final notifier = ref.read(updateNotificationsProvider);
    try {
      final result = await service.confirmItem(
        suggestion.changeSet,
        suggestion.itemIndex,
      );
      notifier.notify({suggestion.changeSet.agentId});
      if (result.success && result.errorMessage == null) {
        // Pure success: the in-place resolve beat + the ticking pending count
        // carry the confirmation, so the redundant success toast is skipped
        // (keeping the reward at the gesture). Announce the verdict AND the
        // remaining count for screen-reader users, who don't see the in-card
        // motion — assertive, because it's the direct result of their action.
        unawaited(
          SemanticsService.sendAnnouncement(
            view,
            '${messages.changeSetItemConfirmed}. '
            '${messages.changeSetPendingCount(_remainingAfterCommit)}',
            textDirection,
            assertiveness: Assertiveness.assertive,
          ),
        );
        await _collapseAndPrune(suggestion, reduceMotion: reduceMotion);
      } else if (result.success) {
        // Confirmed, but with a warning worth surfacing in a toast.
        messenger.showDesignSystemToast(
          tone: DesignSystemToastTone.warning,
          title: messages.changeSetItemConfirmedWithWarning(
            result.errorMessage!,
          ),
          clearQueue: true,
        );
        await _collapseAndPrune(suggestion, reduceMotion: reduceMotion);
      } else {
        messenger.showDesignSystemToast(
          tone: DesignSystemToastTone.error,
          title: messages.changeSetConfirmError,
          clearQueue: true,
        );
        _cancelResolve();
        widget.onResolveEnd?.call(suggestion, removed: false);
        if (mounted) setState(() => _busy = false);
      }
    } catch (e) {
      developer.log(
        'confirmItem failed',
        name: 'AiSummaryCard',
        error: e.runtimeType,
      );
      messenger.showDesignSystemToast(
        tone: DesignSystemToastTone.error,
        title: messages.changeSetConfirmError,
        clearQueue: true,
      );
      _cancelResolve();
      widget.onResolveEnd?.call(suggestion, removed: false);
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    final suggestion = widget.suggestion;
    if (suggestion == null || _busy || _exiting || widget.settling) return;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    setState(() => _busy = true);
    _stopWiggle();
    _beginResolve(ProposalResolveKind.reject, reduceMotion: reduceMotion);
    widget.onResolveStart?.call(suggestion);
    final messenger = ScaffoldMessenger.of(context);
    final messages = context.messages;
    final textDirection = Directionality.of(context);
    final view = View.of(context);
    final service = ref.read(changeSetConfirmationServiceProvider);
    final notifier = ref.read(updateNotificationsProvider);
    try {
      final applied = await service.rejectItem(
        suggestion.changeSet,
        suggestion.itemIndex,
      );
      notifier.notify({suggestion.changeSet.agentId});
      if (applied) {
        // As with confirm: the in-place dismiss beat + pending count carry it,
        // so skip the success toast and announce the verdict + remaining count
        // assertively for SR users.
        unawaited(
          SemanticsService.sendAnnouncement(
            view,
            '${messages.changeSetItemRejected}. '
            '${messages.changeSetPendingCount(_remainingAfterCommit)}',
            textDirection,
            assertiveness: Assertiveness.assertive,
          ),
        );
        await _collapseAndPrune(suggestion, reduceMotion: reduceMotion);
      } else {
        messenger.showDesignSystemToast(
          tone: DesignSystemToastTone.error,
          title: messages.changeSetConfirmError,
          clearQueue: true,
        );
        _cancelResolve();
        widget.onResolveEnd?.call(suggestion, removed: false);
        if (mounted) setState(() => _busy = false);
      }
    } catch (e) {
      developer.log(
        'rejectItem failed',
        name: 'AiSummaryCard',
        error: e.runtimeType,
      );
      messenger.showDesignSystemToast(
        tone: DesignSystemToastTone.error,
        title: messages.changeSetConfirmError,
        clearQueue: true,
      );
      _cancelResolve();
      widget.onResolveEnd?.call(suggestion, removed: false);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    final kind = resolveKind(_toolName, _args);
    final meta = kindMeta(context, kind);
    final cleanText = _cleanText(_humanSummary, meta.label);
    final errorColor = tokens.colors.alert.error.defaultColor;

    final resolveKindLocal = _resolveKind;
    // Eased 0→1 progress of the in-place acknowledgement beat.
    final resolveValue = _resolveT.value;

    // Reject leans the row toward the discard (leading) edge so the verdict is
    // felt by direction; accept locks in place under the finger.
    final leanDx = resolveKindLocal == ProposalResolveKind.reject
        ? -12.0 * resolveValue
        : 0.0;
    // Combine the user's drag offset with any hint-wiggle and the reject lean
    // so the gradient backdrop and the row translation stay in sync.
    final dx = _dx + (_wiggleOffset?.value ?? 0) + leanDx;
    final intentLabel = dx > 30
        ? context.messages.changeSetSwipeConfirm
        : dx < -30
        ? context.messages.changeSetSwipeReject
        : null;
    final intentColor = dx >= 0 ? ai.accent : errorColor;

    final lineThrough =
        _resolvedStatus == ChangeItemStatus.rejected ||
        _resolvedStatus == ChangeItemStatus.retracted;
    final dimmed = lineThrough;

    // Resolve wash: blend the row toward a restrained accent (accept) or
    // muted-error (reject) tint as the acknowledgement beat plays. Shape (the
    // glyph) and feel (the haptic) carry the confirmation; the wash is a quiet
    // supporting tint, not a flash.
    final baseRowColor = widget.isResolved ? ai.subtleWash : ai.row;
    final rowColor = switch (resolveKindLocal) {
      ProposalResolveKind.accept => Color.alphaBlend(
        ai.accent.withValues(alpha: 0.28 * resolveValue),
        baseRowColor,
      ),
      ProposalResolveKind.reject => Color.alphaBlend(
        errorColor.withValues(alpha: 0.18 * resolveValue),
        baseRowColor,
      ),
      null => baseRowColor,
    };
    final baseBorder = widget.isResolved
        ? ai.rowBorder
        : Color.alphaBlend(meta.color.withValues(alpha: 0.55), ai.rowBorder);
    final borderColor = switch (resolveKindLocal) {
      ProposalResolveKind.accept => Color.alphaBlend(
        ai.accent.withValues(alpha: 0.5 * resolveValue),
        baseBorder,
      ),
      ProposalResolveKind.reject => Color.alphaBlend(
        errorColor.withValues(alpha: 0.4 * resolveValue),
        baseBorder,
      ),
      null => baseBorder,
    };

    final rowVisual = ClipRRect(
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
              color: rowColor,
              borderRadius: BorderRadius.circular(10),
              // Pending rows pick up a faint tint of their kind color so
              // the frame reinforces the proposal type at a glance;
              // resolved rows stay neutral.
              border: Border.all(color: borderColor),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: _onHorizontalDragStart,
              onHorizontalDragUpdate: _onHorizontalDragUpdate,
              onHorizontalDragEnd: _onHorizontalDragEnd,
              onHorizontalDragCancel: _onHorizontalDragCancel,
              // Content fades out ahead of the height collapse so the gap
              // reads as space healing, not a row deflating.
              child: FadeTransition(
                opacity: _collapseContentOpacity,
                child: Opacity(
                  opacity: dimmed ? 0.45 : 1,
                  child: ProposalRowContent(
                    meta: meta,
                    text: cleanText,
                    lineThrough: lineThrough,
                    isResolved: widget.isResolved,
                    resolvedStatus: _resolvedStatus,
                    busy: _busy,
                    // While resolving, the badge below is the indicator — hide
                    // the trailing buttons/spinner so they don't peek behind it.
                    resolving: resolveKindLocal != null,
                    onReject: _reject,
                    onConfirm: _confirm,
                  ),
                ),
              ),
            ),
          ),
          // The acknowledgement badge — a filled, high-contrast disc plus a
          // plain-language word ("Confirmed" / "Dismissed") — fades + firms in
          // over the trailing edge as the resolve beat plays, *at the gesture*.
          // Shape + word + colour together, so it reads for low-vision and
          // slower-reading users without a separate bottom-of-screen toast.
          // Stays clear of the content fade so it is the last thing visible as
          // the row collapses away.
          if (resolveKindLocal != null && resolveValue > 0)
            Positioned.fill(
              child: IgnorePointer(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: tokens.spacing.step3,
                    ),
                    child: Opacity(
                      opacity: resolveValue.clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: 0.85 + 0.15 * resolveValue,
                        child: _ResolveBadge(kind: resolveKindLocal),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    // History (resolved) rows never collapse — they live in a separate list.
    if (widget.suggestion == null) return rowVisual;

    // Collapse upward (alignment topCenter) so neighbours below reflow up on
    // the same tween — the collapsing height *is* the reflow. The trailing gap
    // is inside the collapse so the inter-row spacing closes with the row,
    // leaving no leftover gap to snap when the row is finally pruned.
    return ExcludeSemantics(
      // Once committed, drop the row from the a11y tree immediately so a
      // screen-reader user can't focus a row that is visually leaving (the
      // verdict is announced separately by the shell).
      excluding: resolveKindLocal != null,
      child: SizeTransition(
        alignment: Alignment.topCenter,
        sizeFactor: _collapseSize,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            rowVisual,
            SizedBox(height: tokens.spacing.step4),
          ],
        ),
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
    final key = '$kindLabel $summary';
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
    final color = accept ? ai.accent : tokens.colors.alert.error.defaultColor;
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
            accept ? Icons.check_rounded : Icons.close_rounded,
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
            fontWeight: FontWeight.w700,
            height: 1.1,
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

  /// The trailing slot: a resolved-status tag for history rows, an empty
  /// 48×48 slot while resolving (the badge overlays it), else the action
  /// buttons. The fixed slot keeps the text from reflowing on resolve.
  Widget _trailing() {
    if (isResolved) return ResolvedTag(status: resolvedStatus);
    if (resolving) return const SizedBox(width: 48, height: 48);
    return RowActions(busy: busy, onReject: onReject, onConfirm: onConfirm);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    final textWidget = Text(
      text,
      style: tokens.typography.styles.body.bodySmall.copyWith(
        color: ai.bodyText,
        height: 1.5,
        decoration: lineThrough ? TextDecoration.lineThrough : null,
      ),
    );

    if (isCompactWidth(context)) {
      // Narrow viewports: kind chip + trailing actions on the first line, then
      // full-width text below. The whole row also stays swipeable (right =
      // confirm, left = dismiss) — the buttons are an additional, visible
      // affordance so the action isn't swipe-only-and-hidden.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              KindChip(meta: meta),
              const Spacer(),
              _trailing(),
            ],
          ),
          SizedBox(height: tokens.spacing.step2),
          textWidget,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KindChip(meta: meta),
        SizedBox(width: tokens.spacing.step3),
        Expanded(child: textWidget),
        SizedBox(width: tokens.spacing.step3),
        _trailing(),
      ],
    );
  }
}
