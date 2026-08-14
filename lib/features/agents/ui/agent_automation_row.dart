import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:lotti/features/agents/ui/wake_countdown_state.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_inline_action.dart';
import 'package:lotti/features/design_system/components/dividers/design_system_divider.dart';
import 'package:lotti/features/design_system/components/toggles/design_system_toggle.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/projects/ui/widgets/shared_widgets.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Shared automation controls for agent report surfaces.
///
/// The row answers two questions, and keeps each one in one place:
///
///  * **"Is this current, and can I refresh it now?"** — the freshness glyph
///    and word, with the manual trigger next to it. State and its remedy are
///    adjacent, on the leading edge.
///  * **"Does it refresh itself, and when next?"** — the automatic-updates
///    switch with the countdown as its own readout, plus the action that
///    cancels just the pending run. Kept whole on the trailing rail, so
///    "Automatic updates" cannot read as a caption for the button.
///
/// Three invariants shape it.
///
/// **The manual trigger is never absent.** It occupies the same slot in every
/// state; a run already in flight swaps its label and glyph in place rather
/// than vacating the row. An earlier revision replaced the trigger with the
/// countdown while an automatic update was pending, which meant the only way
/// to run the agent by hand was to cancel the schedule first. It is also the
/// quietest thing here that is still obviously a button — the loudest action
/// on the card must be the one that changes the user's task, not the one that
/// spends tokens.
///
/// **Prose degrades before payloads do.** As width runs out the schedule line
/// drops its sentence ("Next update in 1:30" → "in 1:30" → "1:30") and the row
/// finally stacks, but the countdown value, the trigger and the switch always
/// survive. Nothing here truncates a number.
///
/// **The two questions stay visibly separate.** Wide, they sit at opposite
/// ends of one line. Stacked, a rule divides them and both the manual trigger
/// and the switch terminate on the same trailing rail, so the band reads as
/// two deliberate bands rather than a pile of controls.
///
/// **Ticking digits move nothing.** The schedule label reserves the width of
/// the wording captured when the deadline was set, and the layout decision is
/// made against that same reserved width — so a `1:00:00` → `59:59` transition
/// can neither resize the label nor flip the row between its two forms.
///
/// Widths are measured rather than guessed: the labels are localized and
/// user-scaled, so no fixed breakpoint can tell whether "Automatische
/// Aktualisierungen" fits beside a trigger at 1.3× text scale.
class AgentAutomationRow extends StatefulWidget {
  const AgentAutomationRow({
    required this.automaticUpdatesEnabled,
    required this.automationBusy,
    required this.inferenceAvailable,
    required this.isRunning,
    required this.showCountdown,
    required this.nextWakeAt,
    required this.hasReportContent,
    required this.isStale,
    required this.onAutomaticUpdatesChanged,
    required this.onRunNow,
    required this.onSkipScheduledUpdate,
    required this.onCountdownExpired,
    super.key,
  });

  final bool automaticUpdatesEnabled;
  final bool automationBusy;
  final bool inferenceAvailable;
  final bool isRunning;
  final bool showCountdown;
  final DateTime? nextWakeAt;

  /// Whether the card has a summary whose freshness is worth describing. A
  /// blank task has nothing to be "out of date", so the status is omitted
  /// rather than shown in some default state.
  final bool hasReportContent;

  /// Whether the current report is stale. Only meaningful when
  /// [hasReportContent] is true.
  final bool isStale;
  final ValueChanged<bool> onAutomaticUpdatesChanged;
  final VoidCallback? onRunNow;

  /// Cancels the pending automatic update, leaving automatic updates on.
  final VoidCallback onSkipScheduledUpdate;
  final VoidCallback onCountdownExpired;

  @override
  State<AgentAutomationRow> createState() => _AgentAutomationRowState();
}

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
      if (mounted) widget.onCountdownExpired();
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
      _widthAnchorSeconds > 0;

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
    if (widget.automaticUpdatesEnabled && widget.inferenceAvailable) {
      return [messages.taskAgentUpdatesOnChange];
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final freshnessLabel = widget.hasReportContent
        ? (widget.isStale
              ? messages.taskAgentStatusOutOfDate
              : messages.taskAgentStatusUpToDate)
        : null;
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
          tooltip: widget.hasReportContent
              ? (widget.isStale
                    ? messages.taskAgentReportOutdatedTitle
                    : messages.taskAgentReportUpToDate)
              : null,
          isStale: widget.isStale,
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
                  onExpired: widget.onCountdownExpired,
                ),
                skipLabel: metrics.skipLabel,
                skipTooltip: messages.taskAgentCancelTimerTooltip,
                onSkip: _countdownVisible ? widget.onSkipScheduledUpdate : null,
                stacked: layout.scheduleStacked,
              );

        final setting = _AutomationSetting(
          enabled: widget.inferenceAvailable && !widget.automationBusy,
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

/// What the schedule line should render, and how much room it has reserved.
@immutable
class _ScheduleSpec {
  const _ScheduleSpec({
    required this.tier,
    required this.reservedWidth,
    required this.staticLabel,
    required this.nextWakeAt,
    required this.onExpired,
  });

  /// Index into the wording ladder (0 = the full sentence).
  final int tier;

  /// Width reserved for the wording, taken from the value the deadline was
  /// latched with. Rounded up: the label carries the payload, so a fraction of
  /// a pixel too wide is invisible while a fraction too narrow clips a digit.
  final double reservedWidth;

  /// Set when the line is not a countdown and therefore does not tick.
  final String? staticLabel;

  /// Set when the line counts down to a pending automatic update.
  final DateTime? nextWakeAt;
  final VoidCallback onExpired;
}

/// "Is this current?" — the freshness glyph and the word that goes with it.
///
/// The word is not decoration: colour alone cannot carry state, and a lone
/// alert-orange triangle reads as a problem the user caused.
class _FreshnessCluster extends StatelessWidget {
  const _FreshnessCluster({
    required this.label,
    required this.tooltip,
    required this.isStale,
  });

  final String? label;
  final String? tooltip;
  final bool isStale;

  @override
  Widget build(BuildContext context) {
    final text = label;
    if (text == null) return const SizedBox.shrink();
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    return Row(
      key: const ValueKey('taskAgentStatusCluster'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: tooltip ?? '',
          child: Icon(
            key: ValueKey(
              isStale ? 'taskAgentStaleGlyph' : 'taskAgentFreshGlyph',
            ),
            isStale
                ? Icons.warning_amber_rounded
                : Icons.check_circle_outline_rounded,
            size: tokens.spacing.step5,
            color: isStale
                ? tokens.colors.alert.warning.defaultColor
                : ai.metaText,
          ),
        ),
        SizedBox(width: tokens.spacing.step2),
        Flexible(
          child: Text(
            text,
            key: const ValueKey('taskAgentFreshnessLabel'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            // The state register, one step above the schedule and the control
            // labels: live status and static metadata must not read as the
            // same class of information.
            //
            // The word stays `bodyText` in both states and the glyph alone
            // carries the alert tint. Tinting the word too made the quiet
            // settings band the most chromatic thing on the card — louder
            // than `Confirm all`, which is the action that actually changes
            // the task — and it read *lower* contrast than the plain ink it
            // replaced. The state is already said twice, in the glyph and in
            // the word, so colour is not carrying it alone.
            style: tokens.typography.styles.others.caption.copyWith(
              color: ai.bodyText,
            ),
          ),
        ),
      ],
    );
  }
}

/// "When does it update itself?" — the switch's own readout, plus the action
/// that cancels just the pending run.
class _ScheduleCluster extends StatelessWidget {
  const _ScheduleCluster({
    required this.spec,
    required this.skipLabel,
    required this.skipTooltip,
    required this.onSkip,
    required this.stacked,
  });

  final _ScheduleSpec spec;
  final String? skipLabel;
  final String skipTooltip;
  final VoidCallback? onSkip;

  /// Whether the readout and its action need a line each — "Einmal
  /// überspringen" beside a countdown does not fit a 320px phone.
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final label = _ScheduleLabel(spec: spec);
    final skip = onSkip == null || skipLabel == null
        ? null
        : _SkipAction(
            label: skipLabel!,
            tooltip: skipTooltip,
            onSkip: onSkip!,
          );
    if (stacked && skip != null) {
      return Column(
        key: const ValueKey('taskAgentScheduleCluster'),
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [label, skip],
      );
    }
    return Row(
      key: const ValueKey('taskAgentScheduleCluster'),
      mainAxisSize: MainAxisSize.min,
      children: [
        label,
        if (skip != null) ...[
          SizedBox(width: tokens.spacing.step3),
          skip,
        ],
      ],
    );
  }
}

/// The schedule wording, in a slot wide enough for the value it was mounted
/// with. Ticks once a second when it describes a pending automatic update.
class _ScheduleLabel extends StatefulWidget {
  const _ScheduleLabel({required this.spec});

  final _ScheduleSpec spec;

  @override
  State<_ScheduleLabel> createState() => _ScheduleLabelState();
}

class _ScheduleLabelState extends State<_ScheduleLabel>
    with WakeCountdownState<_ScheduleLabel> {
  /// Only driven while [_ScheduleSpec.nextWakeAt] is set; a static line never
  /// ticks.
  @override
  DateTime get nextWakeAt => widget.spec.nextWakeAt ?? clock.now();

  @override
  void didUpdateWidget(covariant _ScheduleLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spec.nextWakeAt != widget.spec.nextWakeAt) {
      resyncCountdown();
    }
  }

  @override
  void onCountdownExpired() {
    // A static line has no deadline to expire, so it must not report one.
    if (widget.spec.nextWakeAt != null) widget.spec.onExpired();
  }

  String _label(BuildContext context, int seconds) {
    final staticLabel = widget.spec.staticLabel;
    if (staticLabel != null) return staticLabel;
    final messages = context.messages;
    final value = formatCountdown(seconds);
    return switch (widget.spec.tier) {
      0 => messages.taskAgentNextUpdateIn(value),
      1 => messages.taskAgentNextUpdateInShort(value),
      _ => value,
    };
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // Reserved, not measured live: the digits inside may shrink, but the
      // slot they sit in never moves what is beside it.
      width: widget.spec.reservedWidth,
      child: Text(
        _label(context, countdownSeconds),
        key: const ValueKey('taskAgentScheduleLabel'),
        maxLines: widget.spec.staticLabel == null ? 1 : 2,
        // Deliberately no ellipsis: this line carries the payload, and a
        // truncated time is worse than a missing one. The wording ladder, not
        // overflow handling, is what makes a countdown fit. The idle helper is
        // prose and may wrap when the shared row is used on a narrow surface.
        softWrap: widget.spec.staticLabel != null,
        style: scheduleLabelStyle(context.designTokens),
      ),
    );
  }
}

/// Shared by the label and by the fit measurement — tabular figures change
/// digit advance, so measuring without them under-reports the width and clips
/// the payload.
TextStyle scheduleLabelStyle(DsTokens tokens) =>
    tokens.typography.styles.others.caption.copyWith(
      // The state register, shared with the freshness word: what is true right
      // now must not read as the same class of information as the static model
      // route two lines below it.
      color: tokens.colors.aiCard.bodyText,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

/// Cancels the pending automatic update without turning automation off.
///
/// Worded rather than a bare glyph, and never accented: accent in this band
/// means "this starts work", and Skip is its opposite. It sits at `bodyText`,
/// the same register as the countdown it acts on — an action quieter than the
/// static text beside it inverts the two. The shared hover fill carries the
/// affordance; an underline here made the cancel out-decorate the value it
/// cancels and gave the band a third dialect for "this is tappable".
class _SkipAction extends StatelessWidget {
  const _SkipAction({
    required this.label,
    required this.tooltip,
    required this.onSkip,
  });

  final String label;
  final String tooltip;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return DesignSystemInlineAction(
      key: const ValueKey('taskAgentSkipScheduledUpdate'),
      label: label,
      semanticsLabel: tooltip,
      tooltip: tooltip,
      ink: context.designTokens.colors.aiCard.bodyText,
      onTap: onSkip,
    );
  }
}

/// The always-present manual trigger. While a run is in flight it keeps its
/// slot and swaps to a spinner plus the thinking label, so the row's
/// silhouette never changes.
class _UpdateNowButton extends StatelessWidget {
  const _UpdateNowButton({required this.isRunning, required this.onRunNow});

  final bool isRunning;
  final VoidCallback? onRunNow;

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    return DesignSystemButton(
      key: const ValueKey('taskAgentWakeButton'),
      label: isRunning
          ? messages.aiSummaryThinkingLabel
          : messages.taskAgentUpdateNow,
      leadingIcon: Icons.refresh_rounded,
      isLoading: isRunning,
      // Caption tier: the footer must not field a string at the same size and
      // weight as the card's hero action one hairline above it.
      size: DesignSystemButtonSize.dense,
      // Tertiary, not outlined: this is a settings-zone action and must read
      // one tier below "Confirm all", the only thing on the card that changes
      // the user's own task. It stays labelled — an icon-only glyph beside an
      // automation switch is exactly the ambiguity the worded Skip refuses.
      variant: DesignSystemButtonVariant.tertiary,
      // The band's rows share one leading column; a button's inset is
      // internal, so without this its glyph would sit one inset inside that
      // column — invisible on a wide row, a broken column once stacked.
      alignsLabelToLeadingEdge: true,
      onPressed: isRunning ? null : onRunNow,
    );
  }
}

/// The automatic-updates label and switch.
class _AutomationSetting extends StatelessWidget {
  const _AutomationSetting({
    required this.enabled,
    required this.value,
    required this.onChanged,
    required this.needsSetupHint,
  });

  final bool enabled;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? needsSetupHint;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final row = Row(
      children: [
        Expanded(
          // Silent: the toggle already publishes this exact string as its
          // label, and the merged node below would otherwise say it twice.
          child: ExcludeSemantics(
            child: Text(
              messages.taskAgentAutomaticUpdatesLabel,
              // Wraps rather than truncates: "Automatische Aktualisierungen"
              // cut to "Automatische Aktuali…" says less than the same words on
              // two lines.
              maxLines: 2,
              style: tokens.typography.styles.others.caption.copyWith(
                color: tokens.colors.aiCard.metaText,
              ),
            ),
          ),
        ),
        SizedBox(width: tokens.spacing.step3),
        // The switch is 40×24 and terminates on the trailing rail. It gets no
        // slot of its own: an outer box sized for a touch target used to sit
        // here, reserving 48 logical px of column while the only thing a
        // finger could actually hit was the 24px track inside it. The row
        // below is the target now, so the height is paid once and is real.
        DesignSystemToggle(
          key: const Key('taskAgentAutomaticUpdatesCheckbox'),
          value: value,
          semanticsLabel: messages.taskAgentAutomaticUpdatesLabel,
          // The disabled switch explains itself on demand instead of
          // spending a permanent caption line on it.
          tooltipIcon: needsSetupHint == null
              ? null
              : Icons.info_outline_rounded,
          tooltipMessage: needsSetupHint,
          enabled: enabled,
          onChanged: onChanged,
        ),
      ],
    );

    // The label is part of the control, not a caption beside it. Making the
    // whole row the gesture gives this setting a target the full width of the
    // band instead of the switch's own 40x24 track, which is well under the
    // 48 minimum in its short dimension. The switch keeps its own ink for
    // direct hits; nested taps resolve to the innermost, so this cannot fire
    // twice.
    // `excludeFromSemantics` on the ink below stops the row publishing a
    // second, unlabelled button — but on its own it also left the enlarged
    // target invisible to assistive tech, since the only actionable node was
    // the switch's own 40x24 track and the label beside it was inert. Merging
    // makes the row one node: the switch's toggled state and tap action, over
    // the union of their rects. Same shape as `SwitchListTile`.
    return MergeSemantics(
      child: Material(
        key: const ValueKey('taskAgentAutomationSetting'),
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? () => onChanged(!value) : null,
          borderRadius: BorderRadius.circular(tokens.radii.s),
          // The enlarged target is for pointers and thumbs. The switch inside
          // already publishes the accessible control — button, toggled state and
          // label — so this row must not add a second, unlabelled button node
          // beside it.
          excludeFromSemantics: true,
          // ...and it must not add a second *focus* stop either. Excluding
          // semantics does nothing to focus traversal, so without this Tab lands
          // twice on one setting — once on this wrapper, once on the switch —
          // and both stops toggle it. The switch keeps the keyboard; the row is
          // pointer-only.
          canRequestFocus: false,
          // ...and it must not add a second *focus* stop either. Excluding
          // semantics does nothing to focus traversal, so without this Tab lands
          // twice on one setting — once on this wrapper, once on the switch —
          // and both stops toggle it. The switch keeps the keyboard; the row is
          // pointer-only.
          // One row box, on the same `step8` minimum as every other row in this
          // band. It is 8px shorter than the slot it replaces and, unlike that
          // slot, all of it is tappable.
          child: ConstrainedBox(
            key: const ValueKey('taskAgentAutomaticUpdatesTarget'),
            constraints: BoxConstraints(minHeight: tokens.spacing.step8),
            child: row,
          ),
        ),
      ),
    );
  }
}

/// The arrangement chosen for one build.
@immutable
class _AutomationLayout {
  const _AutomationLayout({
    required this.tier,
    required this.rowStacked,
    required this.stateStacked,
    required this.scheduleStacked,
  });

  /// Index into the schedule wording ladder, or null when there is no schedule
  /// to describe.
  final int? tier;

  /// Whether the state cluster, the schedule and the switch each take a line.
  final bool rowStacked;

  /// Whether the freshness word and the trigger need a line each.
  final bool stateStacked;

  /// Whether the countdown and its Skip action need a line each.
  final bool scheduleStacked;
}

/// Text measurements behind the fit decision.
///
/// Only text is measured; every other contribution is a token composition, so
/// the natural widths track the active locale and text scale without a
/// hard-coded breakpoint.
@immutable
class _AutomationMetrics {
  const _AutomationMetrics({
    required this.skipLabel,
    required this.freshnessWidth,
    required this.skipWidth,
    required this.scheduleWidths,
    required this.triggerWidth,
    required this.settingWidth,
    required this.clusterGap,
    required this.groupGap,
  });

  factory _AutomationMetrics.measure(
    BuildContext context, {
    required String? freshnessLabel,
    required List<String> scheduleLabels,
    required String? skipLabel,
    required String triggerLabel,
    required String settingLabel,
  }) {
    final tokens = context.designTokens;
    final styles = tokens.typography.styles;
    final direction = Directionality.of(context);
    final scaler = MediaQuery.textScalerOf(context);

    double widthOf(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      return painter.width;
    }

    final caption = styles.others.caption;
    return _AutomationMetrics(
      skipLabel: skipLabel,
      freshnessWidth: freshnessLabel == null
          ? 0
          : tokens.spacing.step5 +
                tokens.spacing.step2 +
                widthOf(freshnessLabel, caption) +
                tokens.spacing.cardItemSpacing,
      // The action's own symmetric step2 inset, plus the step3 separating it
      // from the schedule label.
      skipWidth: skipLabel == null
          ? 0
          : widthOf(skipLabel, caption) +
                tokens.spacing.step2 * 2 +
                tokens.spacing.step3,
      scheduleWidths: [
        for (final label in scheduleLabels)
          widthOf(label, scheduleLabelStyle(tokens)).ceilToDouble(),
      ],
      // `DesignSystemButton` at its small size: symmetric step3 padding, a
      // leading glyph at the subtitle2 line height, and a step2 item gap.
      // `DesignSystemButton` at its dense size: symmetric step2 padding, a
      // leading glyph at the caption line height, and a step2 item gap.
      triggerWidth:
          widthOf(triggerLabel, caption) +
          tokens.typography.lineHeight.caption +
          tokens.spacing.step2 * 3,
      // The switch's own track width, not the box that used to surround it:
      // `DesignSystemToggle` renders a `step8`-wide track and now sits in the
      // row directly.
      settingWidth:
          widthOf(settingLabel, caption) +
          tokens.spacing.step3 +
          tokens.spacing.step8,
      clusterGap: tokens.spacing.cardItemSpacing,
      groupGap: tokens.spacing.step6,
    );
  }

  final String? skipLabel;

  /// Freshness glyph, word and the gap to the trigger. Zero when there is no
  /// report to describe.
  final double freshnessWidth;
  final double skipWidth;

  /// Rendered width of the schedule wording at each tier, longest first.
  final List<double> scheduleWidths;
  final double triggerWidth;
  final double settingWidth;

  /// Gap between the two questions.
  final double clusterGap;

  /// Gap inside the automation group, between its readout and its switch.
  final double groupGap;

  double get _stateWidth => freshnessWidth + triggerWidth;

  double _trailingWidth(int? tier) => tier == null
      ? settingWidth
      : scheduleWidths[tier] + skipWidth + groupGap + settingWidth;

  /// Picks the longest wording that fits, and stacks only when none does.
  _AutomationLayout resolve(double maxWidth) {
    final stateStacked = _stateWidth > maxWidth;
    if (scheduleWidths.isEmpty) {
      return _AutomationLayout(
        tier: null,
        rowStacked: _stateWidth + clusterGap + _trailingWidth(null) > maxWidth,
        stateStacked: stateStacked,
        scheduleStacked: false,
      );
    }
    for (var tier = 0; tier < scheduleWidths.length; tier++) {
      if (_stateWidth + clusterGap + _trailingWidth(tier) <= maxWidth) {
        return _AutomationLayout(
          tier: tier,
          rowStacked: false,
          stateStacked: false,
          scheduleStacked: false,
        );
      }
    }
    // Stacked: the schedule owns a full line, so re-run the ladder against the
    // whole width before settling for the shortest wording.
    for (var tier = 0; tier < scheduleWidths.length; tier++) {
      if (scheduleWidths[tier] + skipWidth <= maxWidth) {
        return _AutomationLayout(
          tier: tier,
          rowStacked: true,
          stateStacked: stateStacked,
          scheduleStacked: false,
        );
      }
    }
    // Even the bare value cannot share a line with the action: give each its
    // own. The value still never truncates.
    return _AutomationLayout(
      tier: scheduleWidths.length - 1,
      rowStacked: true,
      stateStacked: stateStacked,
      scheduleStacked: true,
    );
  }
}
