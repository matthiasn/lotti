import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:lotti/features/agents/ui/wake_countdown_state.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/toggles/design_system_toggle.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/projects/ui/widgets/shared_widgets.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// The task-agent card's automation controls: what state the summary is in,
/// when it updates next, an always-available manual trigger, and the
/// automatic-updates switch.
///
/// Three invariants shape this widget.
///
/// **The manual trigger is never absent.** It occupies the same slot in every
/// state; a run already in flight swaps its label and glyph in place rather
/// than vacating the row. An earlier revision replaced the trigger with the
/// countdown while an automatic update was pending, which meant the only way
/// to run the agent by hand was to cancel the schedule first.
///
/// **Prose degrades before payloads do.** As width runs out the schedule line
/// drops its sentence ("Next update in 1:30" → "in 1:30" → "1:30") and the row
/// finally stacks, but the countdown value, the trigger and the switch always
/// survive. Nothing here truncates a number.
///
/// **Ticking digits move nothing.** The schedule label reserves the width of
/// the wording captured when the deadline was set, and the layout decision is
/// made against that same reserved width — so a `1:00:00` → `59:59` transition
/// can neither resize the label nor flip the row between its two forms.
///
/// Widths are measured rather than guessed: the labels are localized and
/// user-scaled, so no fixed breakpoint can tell whether "Automatische
/// Aktualisierungen" fits beside a trigger at 1.3× text scale.
class TaskAgentAutomationRow extends StatefulWidget {
  const TaskAgentAutomationRow({
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
  State<TaskAgentAutomationRow> createState() => _TaskAgentAutomationRowState();
}

class _TaskAgentAutomationRowState extends State<TaskAgentAutomationRow> {
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
  void didUpdateWidget(covariant TaskAgentAutomationRow oldWidget) {
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
        final status = _StatusCluster(
          freshnessLabel: freshnessLabel,
          freshnessTooltip: widget.hasReportContent
              ? (widget.isStale
                    ? messages.taskAgentReportOutdatedTitle
                    : messages.taskAgentReportUpToDate)
              : null,
          isStale: widget.isStale,
          schedule: tier == null
              ? null
              : _ScheduleSpec(
                  tier: tier,
                  reservedWidth: metrics.scheduleWidths[tier],
                  staticLabel: _countdownVisible ? null : anchorLabels[tier],
                  nextWakeAt: _countdownVisible ? widget.nextWakeAt : null,
                  onExpired: widget.onCountdownExpired,
                ),
          skipLabel: metrics.skipLabel,
          skipTooltip: messages.taskAgentCancelTimerTooltip,
          onSkip: _countdownVisible ? widget.onSkipScheduledUpdate : null,
          stacked: layout.statusStacked,
        );
        final trigger = _UpdateNowButton(
          isRunning: widget.isRunning,
          onRunNow: widget.inferenceAvailable ? widget.onRunNow : null,
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
              Flexible(child: status),
              // One shrink-wrapped trailing cluster: "update it now" and
              // "update it automatically" are one decision, so they read as
              // one group on one rail.
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  trigger,
                  SizedBox(width: tokens.spacing.cardItemSpacing),
                  SizedBox(width: metrics.settingWidth, child: setting),
                ],
              ),
            ],
          );
        }

        return Column(
          key: const ValueKey('taskAgentAutomationRowStacked'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            status,
            SizedBox(height: tokens.spacing.step3),
            trigger,
            SizedBox(height: tokens.spacing.step3),
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
  /// latched with. Rounded up: the label carries the payload, so a fraction
  /// of a pixel too wide is invisible while a fraction too narrow clips a
  /// digit.
  final double reservedWidth;

  /// Set when the line is not a countdown and therefore does not tick.
  final String? staticLabel;

  /// Set when the line counts down to a pending automatic update.
  final DateTime? nextWakeAt;
  final VoidCallback onExpired;
}

/// Freshness and schedule: the "what am I looking at" half of the row.
class _StatusCluster extends StatelessWidget {
  const _StatusCluster({
    required this.freshnessLabel,
    required this.freshnessTooltip,
    required this.isStale,
    required this.schedule,
    required this.skipLabel,
    required this.skipTooltip,
    required this.onSkip,
    required this.stacked,
  });

  final String? freshnessLabel;
  final String? freshnessTooltip;
  final bool isStale;
  final _ScheduleSpec? schedule;
  final String? skipLabel;
  final String skipTooltip;
  final VoidCallback? onSkip;

  /// Whether freshness and schedule take a line each rather than sharing one.
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    final caption = tokens.typography.styles.others.caption;
    final freshness = freshnessLabel;
    final spec = schedule;
    if (freshness == null && spec == null) return const SizedBox.shrink();

    final scheduleLine = spec == null
        ? null
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ScheduleLabel(spec: spec),
              if (onSkip != null && skipLabel != null) ...[
                SizedBox(width: tokens.spacing.step2),
                _SkipAction(
                  label: skipLabel!,
                  tooltip: skipTooltip,
                  onSkip: onSkip!,
                ),
              ],
            ],
          );

    final freshnessLine = freshness == null
        ? null
        : Text(
            freshness,
            key: const ValueKey('taskAgentFreshnessLabel'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: caption.copyWith(color: ai.metaText),
          );

    final glyph = freshness == null
        ? null
        : Tooltip(
            message: freshnessTooltip ?? '',
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
                  : ai.accent,
            ),
          );

    // Stacked, the schedule sits under the freshness *text* rather than under
    // its glyph, so the status reads as one indented block.
    final body = stacked && freshnessLine != null && scheduleLine != null
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              freshnessLine,
              SizedBox(height: tokens.spacing.step1),
              scheduleLine,
            ],
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (freshnessLine != null) Flexible(child: freshnessLine),
              if (freshnessLine != null && scheduleLine != null)
                _Separator(style: caption.copyWith(color: ai.faintMeta)),
              ?scheduleLine,
            ],
          );

    return Row(
      key: const ValueKey('taskAgentStatusCluster'),
      mainAxisSize: MainAxisSize.min,
      children: [
        if (glyph != null) ...[
          glyph,
          SizedBox(width: tokens.spacing.step2),
        ],
        Flexible(child: body),
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
  /// Only reached while [_ScheduleSpec.nextWakeAt] is set; the mixin is not
  /// driven at all for a static line.
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
        maxLines: 1,
        // Deliberately no ellipsis: this line carries the payload, and a
        // truncated time is worse than a missing one. The wording ladder,
        // not overflow handling, is what makes it fit.
        softWrap: false,
        style: scheduleLabelStyle(context.designTokens),
      ),
    );
  }
}

/// Shared by the label and by the fit measurement — tabular figures change
/// digit advance, so measuring without them under-reports the width.
TextStyle scheduleLabelStyle(DsTokens tokens) =>
    tokens.typography.styles.others.caption.copyWith(
      color: tokens.colors.aiCard.metaText,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

class _Separator extends StatelessWidget {
  const _Separator({required this.style});

  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.designTokens.spacing.step2,
      ),
      child: Text('·', style: style),
    );
  }
}

/// Cancels the pending automatic update without turning automation off.
///
/// Worded rather than a bare glyph: an unlabelled "×" sitting beside an
/// automatic-updates switch reads as "turn the whole thing off".
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
    return Semantics(
      button: true,
      label: tooltip,
      excludeSemantics: true,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: const ValueKey('taskAgentSkipScheduledUpdate'),
            onTap: onSkip,
            borderRadius: BorderRadius.circular(tokens.radii.s),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: tokens.spacing.step8),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.spacing.step2,
                ),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.typography.styles.others.caption.copyWith(
                      color: tokens.colors.aiCard.metaText,
                      decoration: TextDecoration.underline,
                      decorationColor: tokens.colors.aiCard.subtleBorder,
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
      variant: DesignSystemButtonVariant.outlined,
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
    return Row(
      key: const ValueKey('taskAgentAutomationSetting'),
      children: [
        Expanded(
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
        SizedBox(width: tokens.spacing.step3),
        // The switch itself is 40×24; the slot around it keeps a full-size
        // interaction target for anyone who cannot land on 24px.
        ConstrainedBox(
          key: const ValueKey('taskAgentAutomaticUpdatesTarget'),
          constraints: BoxConstraints(
            minWidth: tokens.spacing.step9,
            minHeight: tokens.spacing.step9,
          ),
          child: DesignSystemToggle(
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
        ),
      ],
    );
  }
}

/// The arrangement chosen for one build.
@immutable
class _AutomationLayout {
  const _AutomationLayout({
    required this.tier,
    required this.rowStacked,
    required this.statusStacked,
  });

  /// Index into the schedule wording ladder, or null when there is no
  /// schedule to describe.
  final int? tier;

  /// Whether status, trigger and switch each take their own line.
  final bool rowStacked;

  /// Whether freshness and schedule take a line each within the status.
  final bool statusStacked;
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
    required this.separatorWidth,
    required this.skipWidth,
    required this.scheduleWidths,
    required this.triggerWidth,
    required this.settingWidth,
    required this.minimumGap,
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
    final scheduleStyle = scheduleLabelStyle(tokens);
    return _AutomationMetrics(
      skipLabel: skipLabel,
      freshnessWidth: freshnessLabel == null
          ? 0
          : tokens.spacing.step5 +
                tokens.spacing.step2 +
                widthOf(freshnessLabel, caption),
      separatorWidth: (freshnessLabel != null && scheduleLabels.isNotEmpty)
          ? widthOf('·', caption) + tokens.spacing.step2 * 2
          : 0,
      // The action's own symmetric step2 inset, plus the step2 that separates
      // it from the schedule label.
      skipWidth: skipLabel == null
          ? 0
          : widthOf(skipLabel, caption) + tokens.spacing.step2 * 3,
      scheduleWidths: [
        for (final label in scheduleLabels)
          widthOf(label, scheduleStyle).ceilToDouble(),
      ],
      // `DesignSystemButton` at its small size: symmetric step3 padding, a
      // leading glyph at the subtitle2 line height, and a step2 item gap.
      triggerWidth:
          widthOf(triggerLabel, styles.subtitle.subtitle2) +
          tokens.typography.lineHeight.subtitle2 +
          tokens.spacing.step2 +
          tokens.spacing.step3 * 2,
      settingWidth:
          widthOf(settingLabel, caption) +
          tokens.spacing.step3 +
          tokens.spacing.step9,
      minimumGap: tokens.spacing.cardItemSpacing,
    );
  }

  final String? skipLabel;
  final double freshnessWidth;
  final double separatorWidth;
  final double skipWidth;

  /// Rendered width of the schedule wording at each tier, longest first.
  final List<double> scheduleWidths;
  final double triggerWidth;
  final double settingWidth;
  final double minimumGap;

  double get _trailingWidth => triggerWidth + minimumGap + settingWidth;

  /// Status width with freshness and the tier's schedule sharing one line.
  double _statusWidth(int? tier) =>
      freshnessWidth +
      (tier == null ? 0 : separatorWidth + scheduleWidths[tier] + skipWidth);

  /// Picks the longest wording that fits, and stacks only when none does.
  _AutomationLayout resolve(double maxWidth) {
    if (scheduleWidths.isEmpty) {
      return _AutomationLayout(
        tier: null,
        rowStacked: _statusWidth(null) + minimumGap + _trailingWidth > maxWidth,
        statusStacked: false,
      );
    }
    for (var tier = 0; tier < scheduleWidths.length; tier++) {
      if (_statusWidth(tier) + minimumGap + _trailingWidth <= maxWidth) {
        return _AutomationLayout(
          tier: tier,
          rowStacked: false,
          statusStacked: false,
        );
      }
    }
    // Stacked: the status owns a full line, so re-run the ladder against the
    // whole width before giving freshness and schedule a line each.
    for (var tier = 0; tier < scheduleWidths.length; tier++) {
      if (_statusWidth(tier) <= maxWidth) {
        return _AutomationLayout(
          tier: tier,
          rowStacked: true,
          statusStacked: false,
        );
      }
    }
    return _AutomationLayout(
      tier: scheduleWidths.length - 1,
      rowStacked: true,
      statusStacked: true,
    );
  }
}
