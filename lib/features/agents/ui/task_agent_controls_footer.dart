import 'package:flutter/material.dart';
import 'package:lotti/features/agents/ui/task_agent_identity_region.dart';
import 'package:lotti/features/agents/ui/task_agent_model_identity.dart';
import 'package:lotti/features/agents/ui/wake_countdown_state.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/toggles/design_system_toggle.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/projects/ui/widgets/shared_widgets.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Quiet settings zone pinned to the bottom of the task-agent card.
///
/// Hosts the secondary affordances that must stay reachable without competing
/// with the report. Two fixed rows keep every control in one stable slot
/// across states:
///
/// 1. Wake row (present only while it has content, constant height): exactly
///    one wake affordance per state — the manual wake button, or, while an
///    automatic wake is scheduled, a self-explanatory informational
///    "Next update in m:ss" chip with its own dedicated cancel button (the
///    scheduled update *is* the pending wake, so no second button competes
///    with it).
/// 2. Identity row (always): the tappable model/provider line with the
///    automatic-updates toggle pinned trailing — flipping the toggle never
///    relocates it.
///
/// The wake button is also omitted while the freshness strip above owns the
/// CTA ([showWakeButton] false).
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
    final hasWakeRow = showWakeButton || countdownVisible;

    return Container(
      key: const ValueKey('taskAgentControlsFooter'),
      decoration: BoxDecoration(
        color: ai.footerWash,
        border: Border(top: BorderSide(color: ai.borderSoft)),
      ),
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.cardPadding,
        tokens.spacing.step3,
        tokens.spacing.cardPadding,
        tokens.spacing.step3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasWakeRow) ...[
            // One wake affordance per state, in a constant-height slot: the
            // countdown chip replaces the button while an automatic wake is
            // scheduled (the scheduled update *is* the pending wake). step8
            // fits the taller of the two (the cancel button) exactly — a
            // 48px floor left a dead band under the compact controls.
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: tokens.spacing.step8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: countdownVisible
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _CountdownChip(
                            nextWakeAt: wakeAt,
                            onExpired: onCountdownExpired,
                          ),
                          SizedBox(width: tokens.spacing.step2),
                          IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              size: tokens.spacing.step5,
                              color: ai.metaText,
                            ),
                            tooltip: messages.taskAgentCancelTimerTooltip,
                            constraints: BoxConstraints.tightFor(
                              width: tokens.spacing.step8,
                              height: tokens.spacing.step8,
                            ),
                            padding: EdgeInsets.zero,
                            onPressed: onCancelTimer,
                          ),
                        ],
                      )
                    : DesignSystemButton(
                        key: const ValueKey('taskAgentWakeButton'),
                        label: isRunning
                            ? messages.aiSummaryThinkingLabel
                            : messages.taskAgentWakeAgent,
                        leadingIcon: Icons.refresh_rounded,
                        variant: DesignSystemButtonVariant.tertiary,
                        isLoading: isRunning,
                        onPressed: inferenceAvailable ? onRunNow : null,
                      ),
              ),
            ),
            SizedBox(height: tokens.spacing.step2),
          ],
          Row(
            children: [
              Expanded(
                child: TaskAgentIdentityRegion(
                  data: identityData,
                  onSetupTap: onSetupTap,
                ),
              ),
              SizedBox(width: tokens.spacing.step3),
              Text(
                messages.taskAgentAutomaticUpdatesLabel,
                style: tokens.typography.styles.others.caption.copyWith(
                  color: ai.metaText,
                ),
              ),
              SizedBox(width: tokens.spacing.step2),
              DesignSystemToggle(
                key: const Key('taskAgentAutomaticUpdatesCheckbox'),
                value: automaticUpdatesEnabled,
                semanticsLabel: messages.taskAgentAutomaticUpdatesLabel,
                // The disabled toggle explains itself on demand instead of
                // spending a permanent caption line on it.
                tooltipIcon: inferenceAvailable
                    ? null
                    : Icons.info_outline_rounded,
                tooltipMessage: inferenceAvailable
                    ? null
                    : messages.taskAgentAutomaticUpdatesNeedsSetup,
                enabled: inferenceAvailable && !automationBusy,
                onChanged: onAutomaticUpdatesChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Informational countdown until the next scheduled automatic wake
/// ("Next update in 1:30"). Deliberately not tappable — cancelling lives on
/// the dedicated close button next to it so the largest surface in the row
/// can never destroy scheduled work by accident.
class _CountdownChip extends StatefulWidget {
  const _CountdownChip({
    required this.nextWakeAt,
    required this.onExpired,
  });

  final DateTime nextWakeAt;
  final VoidCallback onExpired;

  @override
  State<_CountdownChip> createState() => _CountdownChipState();
}

class _CountdownChipState extends State<_CountdownChip>
    with WakeCountdownState<_CountdownChip> {
  @override
  DateTime get nextWakeAt => widget.nextWakeAt;

  @override
  void didUpdateWidget(covariant _CountdownChip oldWidget) {
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

    // Neutral wash, not accent: an informational timer must not read with
    // the same urgency-class as pending proposals — the ON toggle is the
    // scheduled footer's single accent.
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step3,
        vertical: tokens.spacing.step1,
      ),
      decoration: BoxDecoration(
        color: ai.subtleWashStrong,
        borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
      ),
      child: Text(
        context.messages.taskAgentNextUpdateIn(
          formatCountdown(countdownSeconds),
        ),
        style: tokens.typography.styles.others.caption.copyWith(
          color: ai.metaText,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
