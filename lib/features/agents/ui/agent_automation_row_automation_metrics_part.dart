part of 'agent_automation_row.dart';

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
/// ends of one line. Stacked, a rule divides them — the freshness word and its
/// trigger above it, the schedule readout and the switch it governs below —
/// so the band reads as two deliberate groups rather than a pile of controls.
/// While the state pair still fits one line, the trigger terminates on the
/// same trailing rail as the switch, and the two line up. Once it does not
/// (the narrowest tier, where the word goes above the button), the trigger
/// keeps the leading rail with everything else and only the rule separates
/// the groups.
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
    this.compact = false,
    this.showsIdleScheduleLabel = true,
    this.isRefreshingReport,
    super.key,
  }) : showsFreshConfirmation = true,
       reportUpdatedAt = null;

  /// The freshness word and the manual trigger alone, for a surface that
  /// keeps no settings of its own — the task and project summary cards, whose
  /// schedule, switch and model identity live in the agent internals panel.
  ///
  /// Everything the full band needs and this pair does not is fixed here
  /// rather than left to each caller: a card that has no switch cannot
  /// meaningfully answer "is the switch busy". Passing twelve arguments to use
  /// four was how the previous callers of `compact: true` read.
  ///
  /// [nextWakeAt] is the one piece of the schedule the pair does carry: while
  /// the summary reads out of date and an automatic update is pending, the
  /// trigger reads "Update now · 1:30", so an out-of-date summary also says
  /// that it is about to fix itself. It reports no expiry — the time simply
  /// leaves the label once it reaches zero.
  ///
  /// [onSkipScheduledUpdate], when given, puts *Skip once* beside that
  /// countdown, so the run can be skipped where it is announced rather than
  /// only from the agent internals panel.
  const AgentAutomationRow.compact({
    required this.inferenceAvailable,
    required this.isRunning,
    required this.hasReportContent,
    required this.isStale,
    required this.onRunNow,
    this.nextWakeAt,
    this.reportUpdatedAt,
    this.isRefreshingReport,
    this.showsFreshConfirmation = true,
    this.onSkipScheduledUpdate,
    super.key,
  }) : compact = true,
       automaticUpdatesEnabled = false,
       automationBusy = false,
       showCountdown = false,
       showsIdleScheduleLabel = false,
       onAutomaticUpdatesChanged = null,
       onCountdownExpired = null;

  /// Whether the row still renders while the report is current.
  ///
  /// False on a primary reading surface: a permanent "Up to date" line is a
  /// row of chrome that says nothing changed, and the reader is there for the
  /// summary. The row then appears only when it has something to report — the
  /// summary is behind, or a run is rewriting it — and takes no height at all
  /// otherwise. Only [AgentAutomationRow.compact] honours it; the full band
  /// is a settings surface, where a state that vanishes is worse than a state
  /// that reads "Up to date".
  final bool showsFreshConfirmation;

  /// Renders only the first question — the freshness word and the manual
  /// trigger on one line — for surfaces whose hero card cannot afford the
  /// full band. The automatic-updates switch moves to that surface's overflow
  /// menu; the next scheduled update remains available on wider layouts.
  final bool compact;

  /// Whether the settled state ("Updates on changes") takes the schedule slot
  /// while automation is on with nothing pending.
  ///
  /// On a surface whose switch is visible in the same band the sentence only
  /// restates it, so a denser card turns it off. A pending run's countdown is
  /// unaffected: it says something the switch cannot.
  final bool showsIdleScheduleLabel;

  final bool automaticUpdatesEnabled;
  final bool automationBusy;
  final bool inferenceAvailable;

  /// Whether any run currently holds this agent. The manual trigger reads
  /// "Thinking…" and is disabled for as long as it does — the runner admits
  /// one wake per agent at a time, whatever that wake is for.
  final bool isRunning;

  /// Whether the run in flight is rewriting the report this row describes.
  ///
  /// `null` means "assume so", which is right for task agents: every one of
  /// their completed wakes advances the fresh watermark. A surface whose
  /// agent also runs for other reasons — a goal agent's chat replies and
  /// subscription ticks hold the same lock without touching the read — passes
  /// its report-scoped flag here, so the word does not declare a fresh read
  /// out of date while an unrelated run keeps the trigger busy.
  final bool? isRefreshingReport;
  final bool showCountdown;
  final DateTime? nextWakeAt;

  /// When the summary on screen was written. While it is current, the
  /// compact form says so by its age — "20 min ago", "2 days ago", or the
  /// date once it is a week old — rather than a bare "Up to date", which
  /// cannot tell a summary from this morning from one from last month. Only
  /// [AgentAutomationRow.compact] takes it.
  final DateTime? reportUpdatedAt;

  /// Whether the card has a summary whose freshness is worth describing. A
  /// blank task has nothing to be "out of date", so the status is omitted
  /// rather than shown in some default state.
  final bool hasReportContent;

  /// Whether the current report is stale. Only meaningful when
  /// [hasReportContent] is true. A pending countdown and a report refresh in
  /// flight also count as stale — see [_AgentAutomationRowState._isOutdated]
  /// and [isRefreshingReport] — so a caller that passes `false` here while a
  /// wake is scheduled or running still gets an honest label.
  final bool isStale;

  /// Null only on [AgentAutomationRow.compact], which renders no switch: a
  /// no-op stand-in would have been a line of code that can never run.
  final ValueChanged<bool>? onAutomaticUpdatesChanged;
  final VoidCallback? onRunNow;

  /// Cancels the pending automatic update, leaving automatic updates on, and
  /// completes with whether it did.
  ///
  /// The row withdraws the countdown on the tap rather than on the round
  /// trip, and keeps reading "Out of date" meanwhile — skipping a run does
  /// not make the summary current. A `false` gives the countdown and its
  /// action back, because the wake is then still scheduled. Null where
  /// nothing may be skipped: no action is offered.
  final Future<bool> Function()? onSkipScheduledUpdate;

  /// Null on the compact form, whose deadline is never rendered and so never
  /// expires.
  final VoidCallback? onCountdownExpired;

  @override
  State<AgentAutomationRow> createState() => _AgentAutomationRowState();
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
            isStale ? LottiIcons.warning : LottiIcons.confirmCircled,
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

/// The compact form's trigger while an automatic update is pending:
/// "Update now · 1:30". The time says the summary will refresh itself; the
/// label still says what a tap does, which is run it now.
///
/// **Ticking digits move nothing.** The label uses tabular figures, so equal
/// digit counts are equal widths, and the button holds the widest width it
/// has shown for this deadline, so `10:00` → `9:59` does not pull its edge in
/// either. Callers key it by the deadline, which resets that width. Once the
/// deadline passes it is the plain trigger again, and [onExpired] tells the
/// row, whose *Skip once* beside it has nothing left to skip.
class _CountdownUpdateNowButton extends StatefulWidget {
  const _CountdownUpdateNowButton({
    required this.nextWakeAt,
    required this.onRunNow,
    required this.onExpired,
    super.key,
  });

  final DateTime nextWakeAt;
  final VoidCallback? onRunNow;
  final VoidCallback onExpired;

  @override
  State<_CountdownUpdateNowButton> createState() =>
      _CountdownUpdateNowButtonState();
}

class _CountdownUpdateNowButtonState extends State<_CountdownUpdateNowButton>
    with WakeCountdownState<_CountdownUpdateNowButton> {
  @override
  DateTime get nextWakeAt => widget.nextWakeAt;

  @override
  void onCountdownExpired() {
    if (!mounted) return;
    setState(() {});
    widget.onExpired();
  }

  @override
  Widget build(BuildContext context) {
    final seconds = countdownSeconds;
    if (seconds <= 0) {
      return _UpdateNowButton(isRunning: false, onRunNow: widget.onRunNow);
    }
    return _WidestSoFar(
      child: _UpdateNowButton(
        isRunning: false,
        onRunNow: widget.onRunNow,
        countdown: formatCountdown(seconds),
      ),
    );
  }
}

/// Sizes to the widest width its child has had, so a label that only ever
/// gets shorter never moves what is beside it. Height follows the child.
class _WidestSoFar extends SingleChildRenderObjectWidget {
  const _WidestSoFar({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderWidestSoFar();
}

class _RenderWidestSoFar extends RenderProxyBox {
  double _widest = 0;

  @override
  void performLayout() {
    final child = this.child!
      ..layout(constraints.loosen(), parentUsesSize: true);
    _widest = math.max(_widest, child.size.width);
    size = constraints.constrain(Size(_widest, child.size.height));
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
/// static text beside it inverts the two. A quiet link, not a button: no
/// hover fill (which read as a phantom button in the settings band) and no
/// underline — the word's own ink lifts a step on hover/focus/press. Its row
/// box matches the switch row's `step7`, so the scheduled state does not
/// grow the band beyond the idle state's silhouette.
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
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        excludeFromSemantics: true,
        child: DsQuietInk(
          key: const ValueKey('taskAgentSkipScheduledUpdate'),
          onTap: onSkip,
          borderRadius: BorderRadius.circular(tokens.radii.s),
          builder: (context, highlighted) => ExcludeSemantics(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: tokens.spacing.step7),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.spacing.step2,
                ),
                child: Align(
                  widthFactor: 1,
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.typography.styles.others.caption.copyWith(
                      color: highlighted ? ai.titleText : ai.bodyText,
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

/// The always-present manual trigger. While a run is in flight it keeps its
/// slot and swaps to a spinner plus the thinking label, so the row's
/// silhouette never changes.
class _UpdateNowButton extends StatelessWidget {
  const _UpdateNowButton({
    required this.isRunning,
    required this.onRunNow,
    this.countdown,
  });

  final bool isRunning;
  final VoidCallback? onRunNow;

  /// Time until the pending automatic update, shown after the label.
  final String? countdown;

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    return DesignSystemButton(
      key: const ValueKey('taskAgentWakeButton'),
      label: isRunning
          ? messages.aiSummaryThinkingLabel
          : countdown == null
          ? messages.taskAgentUpdateNow
          : messages.taskAgentUpdateNowCountdown(countdown!),
      // The separator glyph is not worth reading aloud; the full sentence is.
      semanticsLabel: countdown == null || isRunning
          ? null
          : '${messages.taskAgentUpdateNow}, '
                '${messages.taskAgentNextUpdateIn(countdown!)}',
      tabularFigures: countdown != null,
      leadingIcon: LottiIcons.refresh,
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
  final ValueChanged<bool>? onChanged;
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
          tooltipIcon: needsSetupHint == null ? null : LottiIcons.info,
          tooltipMessage: needsSetupHint,
          enabled: enabled,
          // Non-null wherever the switch renders: `enabled` is false without
          // a handler, and a disabled `DesignSystemToggle` never calls it.
          onChanged: onChanged ?? (_) {},
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
      child: KeyedSubtree(
        key: const ValueKey('taskAgentAutomationSetting'),
        // Quiet target: the band is a setting row, not a button, so no hover
        // fill — a full-width wash on hover made the footer sprout a phantom
        // button. The switch inside carries the visible state; the enlarged
        // row target stays purely a hit area.
        child: DsQuietInk(
          onTap: enabled && onChanged != null ? () => onChanged!(!value) : null,
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
          // One row box, sized to breathe around the 24px toggle track
          // (step7 leaves 4px air each side) rather than the step8 the band
          // used to pay — part of shrinking a footer that claimed more of
          // the card than the summary it annotates. All of it is tappable.
          builder: (context, _) => ConstrainedBox(
            key: const ValueKey('taskAgentAutomaticUpdatesTarget'),
            constraints: BoxConstraints(minHeight: tokens.spacing.step7),
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
