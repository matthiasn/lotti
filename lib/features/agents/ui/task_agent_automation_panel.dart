import 'package:flutter/material.dart';
import 'package:lotti/features/agents/ui/wake_countdown_state.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/toggles/design_system_toggle.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/projects/ui/widgets/shared_widgets.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Top-level task-agent automation and freshness controls.
///
/// Automatic inference is an explicit opt-in. When a relevant task change is
/// observed while automation is off, [isStale] surfaces a single manual wake
/// CTA without turning the whole card into an error surface.
class TaskAgentAutomationPanel extends StatelessWidget {
  const TaskAgentAutomationPanel({
    required this.automaticUpdatesEnabled,
    required this.automationBusy,
    required this.inferenceAvailable,
    required this.isRunning,
    required this.isStale,
    required this.showCountdown,
    required this.nextWakeAt,
    required this.onAutomaticUpdatesChanged,
    required this.onRunNow,
    required this.onCancelTimer,
    required this.onCountdownExpired,
    super.key,
  });

  final bool automaticUpdatesEnabled;
  final bool automationBusy;
  final bool inferenceAvailable;
  final bool isRunning;
  final bool isStale;
  final bool showCountdown;
  final DateTime? nextWakeAt;
  final ValueChanged<bool> onAutomaticUpdatesChanged;
  final VoidCallback? onRunNow;
  final VoidCallback onCancelTimer;
  final VoidCallback onCountdownExpired;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    final messages = context.messages;
    final toggleEnabled = inferenceAvailable && !automationBusy;
    final description = !inferenceAvailable
        ? messages.taskAgentAutomaticUpdatesNeedsSetup
        : automaticUpdatesEnabled
        ? messages.taskAgentAutomaticUpdatesSummary
        : messages.taskAgentAutomaticUpdatesOffDescription;

    return Container(
      key: const ValueKey('taskAgentAutomationPanel'),
      padding: EdgeInsets.all(tokens.spacing.cardPadding),
      decoration: BoxDecoration(
        color: ai.backgroundRaised,
        borderRadius: BorderRadius.circular(tokens.radii.m),
        border: Border.all(color: ai.subtleBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      messages.taskAgentAutomaticUpdatesLabel,
                      style: tokens.typography.styles.subtitle.subtitle2
                          .copyWith(color: ai.titleText),
                    ),
                    SizedBox(height: tokens.spacing.step1),
                    Text(
                      description,
                      style: tokens.typography.styles.others.caption.copyWith(
                        color: ai.metaText,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: tokens.spacing.step4),
              DesignSystemToggle(
                key: const Key('taskAgentAutomaticUpdatesCheckbox'),
                value: automaticUpdatesEnabled,
                semanticsLabel: messages.taskAgentAutomaticUpdatesLabel,
                enabled: toggleEnabled,
                onChanged: onAutomaticUpdatesChanged,
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.step4),
          if (isStale && !automaticUpdatesEnabled)
            _StaleReportNotice(
              isRunning: isRunning,
              onRunNow: onRunNow,
            )
          else
            _WakeActions(
              isRunning: isRunning,
              inferenceAvailable: inferenceAvailable,
              showCountdown: showCountdown && nextWakeAt != null,
              nextWakeAt: nextWakeAt,
              onRunNow: onRunNow,
              onCancelTimer: onCancelTimer,
              onCountdownExpired: onCountdownExpired,
            ),
        ],
      ),
    );
  }
}

class _StaleReportNotice extends StatelessWidget {
  const _StaleReportNotice({
    required this.isRunning,
    required this.onRunNow,
  });

  final bool isRunning;
  final VoidCallback? onRunNow;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    final error = tokens.colors.alert.error.defaultColor;
    final messages = context.messages;

    return Container(
      key: const ValueKey('taskAgentStaleNotice'),
      padding: EdgeInsets.all(tokens.spacing.step4),
      decoration: BoxDecoration(
        color: ai.subtleWashStrong,
        borderRadius: BorderRadius.circular(tokens.radii.s),
        border: Border(
          left: BorderSide(color: error, width: tokens.spacing.step1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: tokens.spacing.step5,
                color: error,
              ),
              SizedBox(width: tokens.spacing.step3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      messages.taskAgentReportOutdatedTitle,
                      style: tokens.typography.styles.subtitle.subtitle2
                          .copyWith(color: error),
                    ),
                    SizedBox(height: tokens.spacing.step1),
                    Text(
                      messages.taskAgentReportOutdatedDescription,
                      style: tokens.typography.styles.others.caption.copyWith(
                        color: ai.bodyText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.step4),
          DesignSystemButton(
            key: const ValueKey('taskAgentWakeButton'),
            label: isRunning
                ? messages.aiSummaryThinkingLabel
                : messages.taskAgentWakeAgent,
            leadingIcon: Icons.refresh_rounded,
            fullWidth: true,
            isLoading: isRunning,
            onPressed: onRunNow,
          ),
        ],
      ),
    );
  }
}

class _WakeActions extends StatelessWidget {
  const _WakeActions({
    required this.isRunning,
    required this.inferenceAvailable,
    required this.showCountdown,
    required this.nextWakeAt,
    required this.onRunNow,
    required this.onCancelTimer,
    required this.onCountdownExpired,
  });

  final bool isRunning;
  final bool inferenceAvailable;
  final bool showCountdown;
  final DateTime? nextWakeAt;
  final VoidCallback? onRunNow;
  final VoidCallback onCancelTimer;
  final VoidCallback onCountdownExpired;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    final messages = context.messages;

    return Wrap(
      spacing: tokens.spacing.step3,
      runSpacing: tokens.spacing.step3,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        DesignSystemButton(
          key: const ValueKey('taskAgentWakeButton'),
          label: isRunning
              ? messages.aiSummaryThinkingLabel
              : messages.taskAgentWakeAgent,
          leadingIcon: Icons.refresh_rounded,
          variant: DesignSystemButtonVariant.secondary,
          isLoading: isRunning,
          onPressed: inferenceAvailable ? onRunNow : null,
        ),
        if (showCountdown && nextWakeAt != null)
          _CountdownPill(
            nextWakeAt: nextWakeAt!,
            onExpired: onCountdownExpired,
          ),
        if (showCountdown)
          IconButton(
            icon: Icon(
              Icons.close_rounded,
              size: tokens.spacing.step5,
              color: ai.metaText,
            ),
            tooltip: messages.taskAgentCancelTimerTooltip,
            constraints: BoxConstraints.tightFor(
              width: tokens.spacing.step9,
              height: tokens.spacing.step9,
            ),
            onPressed: onCancelTimer,
          ),
      ],
    );
  }
}

class _CountdownPill extends StatefulWidget {
  const _CountdownPill({
    required this.nextWakeAt,
    required this.onExpired,
  });

  final DateTime nextWakeAt;
  final VoidCallback onExpired;

  @override
  State<_CountdownPill> createState() => _CountdownPillState();
}

class _CountdownPillState extends State<_CountdownPill>
    with WakeCountdownState<_CountdownPill> {
  @override
  DateTime get nextWakeAt => widget.nextWakeAt;

  @override
  void didUpdateWidget(covariant _CountdownPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nextWakeAt != widget.nextWakeAt) resyncCountdown();
  }

  @override
  void onCountdownExpired() => widget.onExpired();

  @override
  Widget build(BuildContext context) {
    if (countdownSeconds <= 0) return const SizedBox.shrink();
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    final countdownText = formatCountdown(countdownSeconds);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step4,
        vertical: tokens.spacing.step2,
      ),
      decoration: BoxDecoration(
        color: ai.accentSoft,
        borderRadius: BorderRadius.circular(tokens.radii.xl),
        border: Border.all(color: ai.border),
      ),
      child: Text(
        countdownText,
        textAlign: TextAlign.center,
        style: tokens.typography.styles.others.caption.copyWith(
          color: ai.accent,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
