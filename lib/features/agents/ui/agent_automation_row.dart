import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/rendering.dart';
import 'package:lotti/features/agents/ui/wake_countdown_state.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/dividers/design_system_divider.dart';
import 'package:lotti/features/design_system/components/ds_quiet_ink.dart';
import 'package:lotti/features/design_system/components/toggles/design_system_toggle.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/relative_age_label.dart';
import 'package:material_ui/material_ui.dart';

part 'agent_automation_row_automation_metrics_part.dart';

class _AgentAutomationRowState extends State<AgentAutomationRow> {
  /// Seconds remaining when the current deadline was handed to this widget.
  ///
  /// The schedule label reserves the width of *this* value's rendering, and
  /// the layout decision is taken against that same width. Re-deriving it per
  /// tick would let a digit change resize the label or flip the row between
  /// its one-line and stacked forms. Only a new deadline re-latches it: time
  /// alone always runs the label shorter, never wider.
  late int _widthAnchorSeconds;

  /// Guards the deadline-already-passed report so a rebuild cannot repeat it.
  bool _expiryReported = false;

  /// Rebuilds the age label when it would next read differently.
  Timer? _ageTimer;

  /// The deadline *Skip once* was tapped against, so the countdown withdraws
  /// on the tap rather than on the round trip.
  ///
  /// The deadline rather than a bare flag: a wake rescheduled meanwhile
  /// carries a new timestamp, and a boolean would have kept its countdown
  /// hidden behind a cancellation of the run before it.
  DateTime? _skippedWakeAt;

  /// Whether the deadline on screen is the one just skipped.
  bool get _skipPending =>
      _skippedWakeAt != null && _skippedWakeAt == widget.nextWakeAt;

  /// Hides the countdown, then asks [skip] to cancel the run.
  ///
  /// The tap cannot await, so both outcomes are handled on the future
  /// itself: a skip that did not happen — refused or thrown — leaves the wake
  /// scheduled and about to fire, so the countdown and its action come back
  /// for a retry, and a throw is reported the way any widget callback's
  /// failure is rather than lost.
  void _skipScheduledUpdate(Future<bool> Function() skip) {
    final wakeAt = widget.nextWakeAt;
    setState(() => _skippedWakeAt = wakeAt);
    void release() {
      if (mounted && _skippedWakeAt == wakeAt) {
        setState(() => _skippedWakeAt = null);
      }
    }

    skip().then(
      (skipped) {
        if (!skipped) release();
      },
      onError: (Object error, StackTrace stackTrace) {
        release();
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'agents',
            context: ErrorDescription('while skipping the scheduled update'),
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _widthAnchorSeconds = _remainingSeconds();
    _reportExpiryIfAlreadyPassed();
  }

  @override
  void didUpdateWidget(covariant AgentAutomationRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nextWakeAt != widget.nextWakeAt) {
      _widthAnchorSeconds = _remainingSeconds();
      _expiryReported = false;
      _reportExpiryIfAlreadyPassed();
    }
  }

  /// A deadline that had already passed when it arrived never mounts a ticking
  /// label, so nothing else would ever tell the card the wake is done. Report
  /// it here instead, post-frame so the caller may rebuild.
  void _reportExpiryIfAlreadyPassed() {
    if (!widget.showCountdown || widget.nextWakeAt == null) return;
    if (_widthAnchorSeconds > 0 || _expiryReported) return;
    _expiryReported = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onCountdownExpired?.call();
    });
  }

  @override
  void dispose() {
    _ageTimer?.cancel();
    super.dispose();
  }

  /// One timer for the age label's next change — the next minute, hour or
  /// day — rather than a tick per second. A dated label waits for the next
  /// local midnight instead: "Dec 20" must gain its year the moment the
  /// reader's calendar crosses New Year, and midnight is the only time a
  /// date label can change. A row showing no age arms none.
  void _scheduleAgeRefresh(DateTime? updatedAt, DateTime now) {
    _ageTimer?.cancel();
    _ageTimer = null;
    if (updatedAt == null) return;
    final age = now.difference(updatedAt);
    final local = now.toLocal();
    final wait = age < relativeAgeDateThreshold
        ? untilNextAgeBucket(age)
        : DateTime(local.year, local.month, local.day + 1).difference(local) +
              const Duration(seconds: 1);
    _ageTimer = Timer(wait, () {
      if (mounted) setState(() {});
    });
  }

  int _remainingSeconds() {
    final wakeAt = widget.nextWakeAt;
    if (wakeAt == null) return 0;
    final remaining = wakeAt.difference(clock.now());
    return remaining <= Duration.zero ? 0 : remaining.inSeconds;
  }

  bool get _countdownVisible =>
      widget.showCountdown &&
      widget.nextWakeAt != null &&
      _widthAnchorSeconds > 0 &&
      !_skipPending;

  /// The one answer to "is this summary current?" that the label, glyph and
  /// tooltip all read. A scheduled update exists because something changed
  /// since the last report, so a ticking countdown is itself proof the
  /// summary is behind — the row must never say "Up to date" beside it, even
  /// when the caller's own staleness flag has not caught up.
  ///
  /// A report refresh in flight is the same proof: the summary on screen is
  /// the one the run is replacing, and the fresh watermark is written only
  /// once the wake succeeds. The card withdraws the countdown the moment the
  /// run starts — exactly when the caller's flag is most likely still
  /// `false` — so without this term that frame read "Up to date" beside
  /// "Thinking…". The word flips only after the run has ended, and then
  /// follows the flag alone: a failed run advances nothing and must not read
  /// as fresh. Which runs count is the caller's to say
  /// ([AgentAutomationRow.isRefreshingReport]); by default every run does.
  ///
  /// A skipped countdown is the same proof until the caller's flag catches
  /// up: skipping saves the run, not the fact that the summary is behind.
  bool get _isOutdated =>
      widget.isStale ||
      _countdownVisible ||
      _skipPending ||
      (widget.isRefreshingReport ?? widget.isRunning);

  /// The schedule wording at each width tier, longest first, rendered against
  /// [seconds]. Empty when there is nothing to say about the next update.
  List<String> _scheduleLabels(BuildContext context, int seconds) {
    final messages = context.messages;
    if (_countdownVisible) {
      final value = formatCountdown(seconds);
      return [
        messages.taskAgentNextUpdateIn(value),
        messages.taskAgentNextUpdateInShort(value),
        value,
      ];
    }
    // Nothing to promise about the next update while one is happening: the
    // trigger already reads "Thinking…", and "Updates on changes"
    // beside it describes a settled state the card is not in.
    if (widget.isRunning) return const [];
    // Automation is on but nothing is pending — say so, rather than leaving a
    // hole that appears and disappears as the user flips the switch.
    if (widget.showsIdleScheduleLabel &&
        widget.automaticUpdatesEnabled &&
        widget.inferenceAvailable) {
      return [messages.taskAgentUpdatesOnChange];
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final outdated = _isOutdated;
    final updatedAt = widget.reportUpdatedAt;
    final now = clock.now();
    _scheduleAgeRefresh(
      outdated || !widget.hasReportContent ? null : updatedAt,
      now,
    );
    final freshnessLabel = widget.hasReportContent
        ? (outdated
              ? messages.taskAgentStatusOutOfDate
              : updatedAt == null
              ? messages.taskAgentStatusUpToDate
              : relativeAgeOrDateLabel(messages, at: updatedAt, now: now))
        : null;
    final freshnessTooltip = widget.hasReportContent
        ? (outdated
              ? messages.taskAgentReportOutdatedTitle
              : messages.taskAgentReportUpToDate)
        : null;
    if (widget.compact) {
      // Nothing to report and not asked to confirm it: take no height at all,
      // rather than reserving a row for a word the reader did not come for.
      if (!widget.showsFreshConfirmation &&
          !(outdated && freshnessLabel != null)) {
        return const SizedBox.shrink(key: ValueKey('agentAutomationRowSilent'));
      }
      final pendingWakeAt = widget.nextWakeAt;
      final freshness = _FreshnessCluster(
        label: freshnessLabel,
        tooltip: freshnessTooltip,
        isStale: outdated,
      );
      // The countdown rides in the trigger only beside "Out of date": under a
      // fresh summary, or in place of "Thinking…", it would promise an update
      // that is not the point.
      final counting =
          outdated &&
          freshnessLabel != null &&
          !widget.isRunning &&
          widget.inferenceAvailable &&
          !_skipPending &&
          pendingWakeAt != null &&
          pendingWakeAt.isAfter(clock.now());
      final trigger = counting
          ? _CountdownUpdateNowButton(
              key: ValueKey(pendingWakeAt),
              nextWakeAt: pendingWakeAt,
              onRunNow: widget.onRunNow,
              onExpired: () {
                if (mounted) setState(() {});
              },
            )
          : _UpdateNowButton(
              isRunning: widget.isRunning,
              onRunNow: widget.inferenceAvailable ? widget.onRunNow : null,
            );
      // Skip once sits beside the countdown it cancels: a reader who sees a
      // paid run announced can decline it there, without opening the panel.
      final onSkip = widget.onSkipScheduledUpdate;
      final skip = counting && onSkip != null
          ? _SkipAction(
              label: messages.taskAgentSkipScheduledUpdate,
              tooltip: messages.taskAgentCancelTimerTooltip,
              onSkip: () => _skipScheduledUpdate(onSkip),
            )
          : null;
      Widget line(List<Widget> trailing) => Row(
        key: const ValueKey('agentAutomationRowCompact'),
        mainAxisAlignment: freshnessLabel == null
            ? MainAxisAlignment.end
            : MainAxisAlignment.spaceBetween,
        children: [
          if (freshnessLabel != null)
            Flexible(
              child: Padding(
                padding: EdgeInsetsDirectional.only(
                  end: tokens.spacing.cardItemSpacing,
                ),
                child: freshness,
              ),
            ),
          ...trailing,
        ],
      );
      final Widget row;
      if (skip == null) {
        row = line([trigger]);
      } else {
        // Measured against the time the deadline was handed over with — the
        // widest the label will be — so ticking never flips the layout.
        final metrics = _AutomationMetrics.measure(
          context,
          freshnessLabel: freshnessLabel,
          scheduleLabels: const [],
          skipLabel: messages.taskAgentSkipScheduledUpdate,
          triggerLabel: messages.taskAgentUpdateNowCountdown(
            formatCountdown(_widthAnchorSeconds),
          ),
          settingLabel: '',
        );
        row = LayoutBuilder(
          builder: (context, constraints) {
            // Skip hugs the trigger it qualifies. When the three cannot share
            // a line — German at 1.3x on a 320px phone — Skip takes its own
            // line under the trigger rather than squeezing the state word or
            // truncating the time.
            if (metrics.freshnessWidth +
                    metrics.skipWidth +
                    metrics.triggerWidth <=
                constraints.maxWidth) {
              // One trailing group: `spaceBetween` would otherwise float
              // Skip midway between the word and the trigger it qualifies.
              return line([
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    skip,
                    SizedBox(width: tokens.spacing.step3),
                    trigger,
                  ],
                ),
              ]);
            }
            return Column(
              key: const ValueKey('agentAutomationRowCompactStacked'),
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                line([trigger]),
                skip,
              ],
            );
          },
        );
      }
      // A band in a reading column pays for the air under it, and this pair
      // brings none of its own: the dense trigger is a 24-high box and the
      // word beside it is bare text, so without this the status sat four
      // pixels off the card's bottom edge while every other edge paid the
      // card inset. Only the silent-capable form pays it — a host that keeps
      // the row permanently (the goal page's hero) already spaces it, and an
      // inset there would be charged twice.
      if (widget.showsFreshConfirmation) return row;
      return Padding(
        padding: EdgeInsets.only(bottom: tokens.spacing.step4),
        child: row,
      );
    }

    final onSkip = widget.onSkipScheduledUpdate;
    final anchorLabels = _scheduleLabels(context, _widthAnchorSeconds);
    final metrics = _AutomationMetrics.measure(
      context,
      freshnessLabel: freshnessLabel,
      scheduleLabels: anchorLabels,
      skipLabel: _countdownVisible
          ? messages.taskAgentSkipScheduledUpdate
          : null,
      triggerLabel: widget.isRunning
          ? messages.aiSummaryThinkingLabel
          : messages.taskAgentUpdateNow,
      settingLabel: messages.taskAgentAutomaticUpdatesLabel,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = metrics.resolve(constraints.maxWidth);
        final tier = layout.tier;

        final freshness = _FreshnessCluster(
          label: freshnessLabel,
          tooltip: freshnessTooltip,
          isStale: outdated,
        );
        final trigger = _UpdateNowButton(
          isRunning: widget.isRunning,
          onRunNow: widget.inferenceAvailable ? widget.onRunNow : null,
        );
        // Normally the state and its remedy sit side by side. When even that
        // pair cannot share a line — German at 1.3x on a 320px phone — the
        // word goes above the button rather than the button truncating its
        // own fixed vocabulary.
        final state = layout.stateStacked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  freshness,
                  if (freshnessLabel != null)
                    SizedBox(height: tokens.spacing.step3),
                  trigger,
                ],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(child: freshness),
                  if (freshnessLabel != null)
                    SizedBox(width: tokens.spacing.cardItemSpacing),
                  trigger,
                ],
              );

        // Stacked, that same pair spans the whole band instead of clustering
        // on the leading edge. The trigger then terminates on the trailing
        // rail the switch below it already uses, so the two controls share one
        // vertical line. Left-packed, the button floated at whatever x the
        // status word happened to end at, which is what made three deliberate
        // controls read as three things crammed together.
        final stackedState = layout.stateStacked
            ? state
            : Row(
                mainAxisAlignment: freshnessLabel == null
                    ? MainAxisAlignment.end
                    : MainAxisAlignment.spaceBetween,
                children: [
                  if (freshnessLabel != null)
                    Flexible(
                      child: Padding(
                        padding: EdgeInsetsDirectional.only(
                          end: tokens.spacing.cardItemSpacing,
                        ),
                        child: freshness,
                      ),
                    ),
                  trigger,
                ],
              );

        final schedule = tier == null
            ? null
            : _ScheduleCluster(
                spec: _ScheduleSpec(
                  tier: tier,
                  reservedWidth:
                      layout.rowStacked &&
                          !_countdownVisible &&
                          metrics.scheduleWidths[tier] > constraints.maxWidth
                      ? constraints.maxWidth
                      : metrics.scheduleWidths[tier],
                  staticLabel: _countdownVisible ? null : anchorLabels[tier],
                  nextWakeAt: _countdownVisible ? widget.nextWakeAt : null,
                  onExpired: widget.onCountdownExpired ?? () {},
                ),
                skipLabel: metrics.skipLabel,
                skipTooltip: messages.taskAgentCancelTimerTooltip,
                onSkip: _countdownVisible && onSkip != null
                    ? () => _skipScheduledUpdate(onSkip)
                    : null,
                stacked: layout.scheduleStacked,
              );

        final setting = _AutomationSetting(
          enabled:
              widget.inferenceAvailable &&
              !widget.automationBusy &&
              widget.onAutomaticUpdatesChanged != null,
          value: widget.automaticUpdatesEnabled,
          onChanged: widget.onAutomaticUpdatesChanged,
          needsSetupHint: widget.inferenceAvailable
              ? null
              : messages.taskAgentAutomaticUpdatesNeedsSetup,
        );

        if (!layout.rowStacked) {
          return Row(
            key: const ValueKey('taskAgentAutomationRowWide'),
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: state),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (schedule != null) ...[
                    schedule,
                    // A real gap, not leftover slack: the readout and the
                    // switch are one group, and `spaceBetween` alone would put
                    // every spare pixel in the one place carrying no meaning.
                    SizedBox(width: tokens.spacing.step6),
                  ],
                  SizedBox(width: metrics.settingWidth, child: setting),
                ],
              ),
            ],
          );
        }

        // Two bands, not three stray lines: what the report *is* and how to
        // refresh it now, then whether it refreshes itself. The rule is what
        // makes that split legible — without it "Automatic updates" reads as a
        // caption belonging to the trigger above it.
        //
        // The rule carries the only declared gap here, and a small one. Each
        // row is a touch-target box taller than its ink — the trigger's
        // button, the switch's `step9` row — so it already contributes ~12
        // logical px of air above and below the text you can actually see.
        // Declared gaps sit on top of that and the band pays twice: `step5`
        // between two of these rows rendered as ~34px of visible space.
        return Column(
          key: const ValueKey('taskAgentAutomationRowStacked'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            stackedState,
            Padding(
              padding: EdgeInsets.symmetric(vertical: tokens.spacing.step1),
              child: const DesignSystemDivider(
                key: ValueKey('taskAgentAutomationRowRule'),
              ),
            ),
            // Below the rule, with the switch: the countdown describes and
            // cancels the *automatic* run, so it belongs to the toggle that
            // governs it. Above the rule it read as a footnote to the manual
            // trigger — which is the one thing it has nothing to do with.
            // The wide layout groups the two the same way.
            ?schedule,
            setting,
          ],
        );
      },
    );
  }
}
