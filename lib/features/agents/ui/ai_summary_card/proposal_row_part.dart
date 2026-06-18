import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
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

/// Single swipeable proposal row: swipe right to confirm, left to
/// dismiss, with wiggle hint + busy spinner state handling.
class ProposalRow extends ConsumerStatefulWidget {
  const ProposalRow({
    required PendingSuggestion this.suggestion,
    this.isFirst = false,
    this.confirmAllPulse = 0,
    this.cascadeIndex = 0,
    super.key,
  }) : entry = null;

  const ProposalRow.fromLedger({required LedgerEntry this.entry, super.key})
    : suggestion = null,
      isFirst = false,
      confirmAllPulse = 0,
      cascadeIndex = 0;

  final PendingSuggestion? suggestion;
  final LedgerEntry? entry;

  /// Whether this row is the topmost pending row. Drives the
  /// swipe-affordance wiggle hint on narrow viewports.
  final bool isFirst;

  /// Incremented by the parent each time "Confirm all" is pressed; the row
  /// reacts by popping (staggered by [cascadeIndex]) so a batch confirm reads
  /// as a satisfying downward sweep rather than everything vanishing at once.
  final int confirmAllPulse;

  /// This row's position in the open list, used to stagger the confirm-all pop.
  final int cascadeIndex;

  bool get isResolved => entry != null;

  @override
  ConsumerState<ProposalRow> createState() => _ProposalRowState();
}

class _ProposalRowState extends ConsumerState<ProposalRow>
    with TickerProviderStateMixin {
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

  /// One-shot scale pop played when "Confirm all" cascades to this row.
  late final AnimationController _confirmPopController;
  late final Animation<double> _confirmPopScale;
  Timer? _cascadeTimer;

  @override
  void initState() {
    super.initState();
    _confirmPopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _confirmPopScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1, end: 1.06).chain(
          CurveTween(curve: Curves.easeOut),
        ),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.06, end: 1).chain(
          CurveTween(curve: Curves.easeIn),
        ),
        weight: 55,
      ),
    ]).animate(_confirmPopController);
  }

  @override
  void didUpdateWidget(ProposalRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A fresh "Confirm all" press: pop this row after a per-index delay so the
    // batch confirm sweeps top-to-bottom. A light selection tick rides each
    // pop; the ~45ms stagger keeps the haptics from machine-gunning.
    if (widget.confirmAllPulse > oldWidget.confirmAllPulse &&
        !widget.isResolved) {
      _cascadeTimer?.cancel();
      final reduceMotion =
          MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      _cascadeTimer = Timer(
        Duration(milliseconds: 45 * widget.cascadeIndex),
        () {
          if (!mounted) return;
          unawaited(HapticFeedback.selectionClick());
          if (!reduceMotion) _confirmPopController.forward(from: 0);
        },
      );
    }
  }

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
    if (MediaQuery.disableAnimationsOf(context)) {
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
    _cascadeTimer?.cancel();
    _confirmPopController.dispose();
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
    } finally {
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

    return ScaleTransition(
      scale: _confirmPopScale,
      child: ClipRRect(
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
                alignment: dx > 0
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
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
                // Pending rows pick up a faint tint of their kind color so
                // the frame reinforces the proposal type at a glance;
                // resolved rows stay neutral.
                border: Border.all(
                  color: widget.isResolved
                      ? ai.rowBorder
                      : Color.alphaBlend(
                          meta.color.withValues(alpha: 0.55),
                          ai.rowBorder,
                        ),
                ),
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
                  child: ProposalRowContent(
                    meta: meta,
                    text: cleanText,
                    lineThrough: lineThrough,
                    isResolved: widget.isResolved,
                    resolvedStatus: _resolvedStatus,
                    busy: _busy,
                    onReject: _reject,
                    onConfirm: _confirm,
                  ),
                ),
              ),
            ),
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
    final key = '$kindLabel $summary';
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
    super.key,
  });

  final KindMeta meta;
  final String text;
  final bool lineThrough;
  final bool isResolved;
  final ChangeItemStatus? resolvedStatus;
  final bool busy;
  final Future<void> Function() onReject;
  final Future<void> Function() onConfirm;

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
              if (isResolved)
                ResolvedTag(status: resolvedStatus)
              else
                RowActions(
                  busy: busy,
                  onReject: onReject,
                  onConfirm: onConfirm,
                ),
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
        if (isResolved)
          ResolvedTag(status: resolvedStatus)
        else
          RowActions(busy: busy, onReject: onReject, onConfirm: onConfirm),
      ],
    );
  }
}
