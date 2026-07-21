import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/tldr_section_part.dart';
import 'package:lotti/features/agents/ui/task_agent_freshness_strip.dart';
import 'package:lotti/features/agents/ui/task_agent_identity_region.dart';
import 'package:lotti/features/agents/ui/task_agent_model_identity.dart';
import 'package:lotti/features/agents/ui/wake_countdown_state.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/components/toggles/design_system_toggle.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/projects/ui/widgets/shared_widgets.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Quiet settings zone pinned to the bottom of the task-agent card.
///
/// Wake status and automatic updates form one bounded automation cluster so
/// the countdown, spinner, and switch read as one system. Wide cards place
/// that cluster beside model identity. Narrow cards place the cluster first
/// and wrap identity below it; the cluster itself also wraps when its wake
/// status and switch cannot share a line. The countdown reserves the width of
/// its initial label so ticking digits never move adjacent controls.
///
/// The wide/compact choice is content-aware, not a fixed breakpoint: in wide
/// layout the automation cluster only gets a 6/10 share of the available
/// width (identity gets the other 4/10, in `wideFooter`), and a longer
/// locale's wake-control label plus "Automatische Aktualisierungen" (German)
/// can need more than that share even when English's shorter strings fit
/// comfortably at the same width. `_countdownNaturalWidth` /
/// `_thinkingNaturalWidth` / `_wakeButtonNaturalWidth` mirror the exact width
/// formulas [_CountdownControl] and [_ThinkingStatus] use for their own
/// sizing, so the parent's compact/wide decision matches what actually gets
/// rendered instead of drifting out of sync with it.
///
/// The wake control is omitted while the freshness strip above owns the CTA
/// (`showWakeButton` false).
double _measureTextWidth(BuildContext context, String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  return painter.width;
}

/// Natural (unconstrained) width of the countdown pill + its separate cancel
/// target for [seconds] remaining — must match [_CountdownControl]'s own
/// sizing exactly, since callers use this to decide layout *before* that
/// widget builds.
double _countdownNaturalWidth(
  BuildContext context,
  DsTokens tokens,
  int seconds,
) {
  final label = context.messages.taskAgentNextUpdateIn(
    formatCountdown(seconds),
  );
  final labelStyle = tokens.typography.styles.others.caption.copyWith(
    fontFeatures: const [FontFeature.tabularFigures()],
  );
  return _measureTextWidth(context, label, labelStyle) +
      tokens.spacing.step4 +
      tokens.spacing.step2 +
      (tokens.spacing.step3 * 2) +
      tokens.spacing.step9;
}

/// Natural width of the "Thinking…" status row — must match
/// [_ThinkingStatus]'s own sizing exactly.
double _thinkingNaturalWidth(BuildContext context, DsTokens tokens) {
  final label = context.messages.aiSummaryThinkingLabel;
  final labelStyle = tokens.typography.styles.subtitle.subtitle2;
  return tokens.spacing.step4 +
      tokens.spacing.step3 +
      _measureTextWidth(context, label, labelStyle);
}

/// Natural width of the "Wake agent" button — mirrors
/// [DesignSystemButton]'s `small`-size spec (the default, used here):
/// horizontal padding on both sides + icon + item gap + label.
double _wakeButtonNaturalWidth(
  BuildContext context,
  DsTokens tokens,
  AppLocalizations messages,
) {
  final labelStyle = tokens.typography.styles.subtitle.subtitle2;
  return (tokens.spacing.step3 * 2) +
      tokens.typography.lineHeight.subtitle2 +
      tokens.spacing.step2 +
      _measureTextWidth(context, messages.taskAgentWakeAgent, labelStyle);
}

class TaskAgentControlsFooter extends StatelessWidget {
  const TaskAgentControlsFooter({
    required this.automaticUpdatesEnabled,
    required this.automationBusy,
    required this.inferenceAvailable,
    required this.isRunning,
    required this.showWakeButton,
    required this.showCountdown,
    required this.nextWakeAt,
    required this.onAutomaticUpdatesChanged,
    required this.onRunNow,
    required this.onCancelTimer,
    required this.onCountdownExpired,
    required this.identityData,
    required this.onSetupTap,
    super.key,
  });

  final bool automaticUpdatesEnabled;
  final bool automationBusy;
  final bool inferenceAvailable;
  final bool isRunning;
  final bool showWakeButton;
  final bool showCountdown;
  final DateTime? nextWakeAt;
  final ValueChanged<bool> onAutomaticUpdatesChanged;
  final VoidCallback? onRunNow;
  final VoidCallback onCancelTimer;
  final VoidCallback onCountdownExpired;
  final TaskAgentModelIdentityViewData identityData;
  final VoidCallback onSetupTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    final messages = context.messages;
    final wakeAt = nextWakeAt;
    final countdownVisible = showCountdown && wakeAt != null;
    final hasWakeControl = showWakeButton || countdownVisible;

    final automationToggle = ConstrainedBox(
      key: const ValueKey('taskAgentAutomaticUpdatesTarget'),
      constraints: BoxConstraints(
        minWidth: tokens.spacing.step9,
        minHeight: tokens.spacing.step9,
      ),
      child: DesignSystemToggle(
        key: const Key('taskAgentAutomaticUpdatesCheckbox'),
        value: automaticUpdatesEnabled,
        semanticsLabel: messages.taskAgentAutomaticUpdatesLabel,
        // The disabled toggle explains itself on demand instead of spending a
        // permanent caption line on it.
        tooltipIcon: inferenceAvailable ? null : Icons.info_outline_rounded,
        tooltipMessage: inferenceAvailable
            ? null
            : messages.taskAgentAutomaticUpdatesNeedsSetup,
        enabled: inferenceAvailable && !automationBusy,
        onChanged: onAutomaticUpdatesChanged,
      ),
    );
    final identity = TaskAgentIdentityRegion(
      data: identityData,
      onSetupTap: onSetupTap,
    );
    final wakeControl = countdownVisible
        ? _CountdownControl(
            nextWakeAt: wakeAt,
            onCancel: onCancelTimer,
            cancelTooltip: messages.taskAgentCancelTimerTooltip,
            onExpired: onCountdownExpired,
          )
        : isRunning
        ? const _ThinkingStatus()
        : DesignSystemButton(
            key: const ValueKey('taskAgentWakeButton'),
            label: messages.taskAgentWakeAgent,
            leadingIcon: Icons.refresh_rounded,
            variant: DesignSystemButtonVariant.tertiary,
            onPressed: inferenceAvailable ? onRunNow : null,
          );
    final automationLabelStyle = tokens.typography.styles.others.caption
        .copyWith(color: ai.metaText);
    final automationLabelPainter = TextPainter(
      text: TextSpan(
        text: messages.taskAgentAutomaticUpdatesLabel,
        style: automationLabelStyle,
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final automationSettingWidth =
        automationLabelPainter.width +
        tokens.spacing.step3 +
        tokens.spacing.step9;
    // Mirrors the exact widget that will render in `wakeControl` above, so
    // the compact/wide decision below reflects what actually needs to fit
    // rather than an assumption that drifts from the real content.
    final wakeControlNaturalWidth = !hasWakeControl
        ? 0.0
        : countdownVisible
        ? _countdownNaturalWidth(
            context,
            tokens,
            wakeAt.difference(clock.now()).inSeconds.clamp(0, 1 << 30),
          )
        : isRunning
        ? _thinkingNaturalWidth(context, tokens)
        : _wakeButtonNaturalWidth(context, tokens, messages);
    // The Wrap's own spacing between wakeControl/automationSetting, plus the
    // cluster Container's horizontal padding on both sides — see
    // automationCluster below.
    final clusterNaturalWidth =
        (hasWakeControl
            ? wakeControlNaturalWidth + tokens.spacing.cardItemSpacing
            : 0.0) +
        automationSettingWidth +
        (tokens.spacing.step3 * 2);
    final automationSetting = LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          key: const ValueKey('taskAgentAutomationSetting'),
          width: constraints.constrainWidth(automationSettingWidth),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  messages.taskAgentAutomaticUpdatesLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: automationLabelStyle,
                ),
              ),
              SizedBox(width: tokens.spacing.step3),
              automationToggle,
            ],
          ),
        );
      },
    );

    final automationCluster = Container(
      key: const ValueKey('taskAgentAutomationCluster'),
      constraints: BoxConstraints(minHeight: tokens.spacing.step9),
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step3),
      decoration: BoxDecoration(
        color: ai.subtleWashStrong,
        borderRadius: BorderRadius.circular(tokens.radii.s),
        border: Border.all(color: ai.rowBorder),
      ),
      child: Wrap(
        key: const ValueKey('taskAgentAutomationWrap'),
        alignment: hasWakeControl
            ? WrapAlignment.spaceBetween
            : WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: tokens.spacing.cardItemSpacing,
        runSpacing: tokens.spacing.step1,
        children: [
          if (hasWakeControl) wakeControl,
          automationSetting,
        ],
      ),
    );

    Widget wideFooter() {
      return Row(
        key: const ValueKey('taskAgentFooterWideLayout'),
        children: [
          Expanded(flex: 4, child: identity),
          SizedBox(width: tokens.spacing.cardItemSpacing),
          Expanded(flex: 6, child: automationCluster),
        ],
      );
    }

    Widget compactFooter() {
      return Column(
        key: const ValueKey('taskAgentFooterCompactLayout'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          automationCluster,
          SizedBox(height: tokens.spacing.step1),
          identity,
        ],
      );
    }

    return Container(
      key: const ValueKey('taskAgentControlsFooter'),
      decoration: BoxDecoration(
        color: ai.footerWash,
        border: Border(top: BorderSide(color: ai.borderSoft)),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.cardPadding,
        vertical: tokens.spacing.step2,
      ),
      // The wash band spans the card, but the content snaps to the same
      // reading measure as the summary and proposal rows.
      child: Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: TldrBody.maxReadingWidth),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final textScale = MediaQuery.textScalerOf(context).scale(1);
              // Wide layout only ever gives the cluster a 6/10 share (see
              // wideFooter) — when a wake control and the automation
              // setting are both competing for that share (hasWakeControl),
              // and their combined natural width wouldn't actually fit in
              // it, the Wrap would silently break them onto two lines
              // instead of showing identity beside a comfortably-sized
              // cluster, so fall back to compact instead. When the
              // automation setting is the cluster's ONLY content there is
              // nothing for it to wrap against — Wrap can't break a single
              // child onto "two lines" of itself — so this check does not
              // apply; a too-narrow share there is handled by the setting's
              // own label ellipsis, same as before.
              final wideModeClusterShare =
                  ((constraints.maxWidth - tokens.spacing.cardItemSpacing) *
                          6 /
                          10)
                      .clamp(0, double.infinity);
              final compact =
                  constraints.maxWidth < TaskAgentFreshnessStrip.compactWidth ||
                  textScale > 1.3 ||
                  (hasWakeControl &&
                      wideModeClusterShare < clusterNaturalWidth);
              return compact ? compactFooter() : wideFooter();
            },
          ),
        ),
      ),
    );
  }
}

/// Non-interactive progress status. A running wake cannot be pressed, so it
/// is rendered as status rather than as a disabled/loading button.
class _ThinkingStatus extends StatelessWidget {
  const _ThinkingStatus();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    final label = context.messages.aiSummaryThinkingLabel;
    final labelStyle = tokens.typography.styles.subtitle.subtitle2.copyWith(
      color: ai.accent,
    );
    final naturalWidth = _thinkingNaturalWidth(context, tokens);

    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.constrainWidth(naturalWidth),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: tokens.spacing.step8),
            child: Row(
              children: [
                SizedBox.square(
                  key: const ValueKey('taskAgentThinkingSpinner'),
                  dimension: tokens.spacing.step4,
                  child: CircularProgressIndicator(
                    strokeWidth: tokens.spacing.step1,
                    color: ai.accent,
                  ),
                ),
                SizedBox(width: tokens.spacing.step3),
                Expanded(
                  child: Text(
                    label,
                    key: const ValueKey('taskAgentThinkingLabel'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: labelStyle,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A polished informational schedule pill plus a separate full-size cancel
/// target. Keeping cancellation outside the pill prevents an informational
/// surface from behaving like a destructive button.
class _CountdownControl extends StatefulWidget {
  const _CountdownControl({
    required this.nextWakeAt,
    required this.onCancel,
    required this.cancelTooltip,
    required this.onExpired,
  });

  final DateTime nextWakeAt;
  final VoidCallback onCancel;
  final String cancelTooltip;
  final VoidCallback onExpired;

  @override
  State<_CountdownControl> createState() => _CountdownControlState();
}

class _CountdownControlState extends State<_CountdownControl>
    with WakeCountdownState<_CountdownControl> {
  late int _widthAnchorSeconds;

  @override
  DateTime get nextWakeAt => widget.nextWakeAt;

  @override
  void initState() {
    super.initState();
    _widthAnchorSeconds = countdownSeconds;
  }

  @override
  void didUpdateWidget(covariant _CountdownControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nextWakeAt != widget.nextWakeAt) {
      resyncCountdown();
      _widthAnchorSeconds = countdownSeconds;
    }
  }

  @override
  void onCountdownExpired() => widget.onExpired();

  @override
  Widget build(BuildContext context) {
    if (countdownSeconds <= 0) return const SizedBox.shrink();
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    final label = context.messages.taskAgentNextUpdateIn(
      formatCountdown(countdownSeconds),
    );
    final widthAnchorLabel = context.messages.taskAgentNextUpdateIn(
      formatCountdown(_widthAnchorSeconds),
    );
    final labelStyle = tokens.typography.styles.others.caption.copyWith(
      color: ai.metaText,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final widthAnchorPainter = TextPainter(
      text: TextSpan(text: widthAnchorLabel, style: labelStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    // Same formula the parent footer uses to decide compact/wide layout —
    // see _countdownNaturalWidth.
    final naturalWidth = _countdownNaturalWidth(
      context,
      tokens,
      _widthAnchorSeconds,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.constrainWidth(naturalWidth),
          child: Row(
            children: [
              Flexible(
                child: DsPill(
                  variant: DsPillVariant.filled,
                  bordered: true,
                  borderColor: ai.borderSoft,
                  leading: Icon(
                    Icons.schedule_rounded,
                    size: tokens.spacing.step4,
                    color: ai.metaText,
                  ),
                  labelWidget: SizedBox(
                    width: widthAnchorPainter.width,
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: labelStyle,
                    ),
                  ),
                ),
              ),
              Semantics(
                button: true,
                label: widget.cancelTooltip,
                excludeSemantics: true,
                child: Tooltip(
                  message: widget.cancelTooltip,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: widget.onCancel,
                      borderRadius: BorderRadius.circular(
                        tokens.radii.badgesPills,
                      ),
                      child: SizedBox(
                        key: const ValueKey(
                          'taskAgentCancelCountdownTarget',
                        ),
                        width: tokens.spacing.step9,
                        height: tokens.spacing.step9,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: EdgeInsets.only(
                              left: tokens.spacing.step1,
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              size: tokens.spacing.step4,
                              color: ai.metaText,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
