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
import 'package:lotti/l10n/app_localizations_context.dart';

/// Quiet settings zone pinned to the bottom of the task-agent card.
///
/// Wide cards place model identity, wake status, and automation on one compact
/// utility rail. Narrow cards use two intentional groups: wake status first,
/// then one settings row that stacks the automation label directly above
/// model identity with the toggle pinned trailing. This preserves full-size
/// controls without turning every caption into its own airy footer band.
///
/// The wake control is omitted while the freshness strip above owns the CTA
/// ([showWakeButton] false).
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

    final automationLabel = Text(
      messages.taskAgentAutomaticUpdatesLabel,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: tokens.typography.styles.others.caption.copyWith(
        color: ai.metaText,
      ),
    );
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

    Widget wideUtilityRail() {
      return Row(
        key: const ValueKey('taskAgentFooterWideLayout'),
        children: [
          Expanded(flex: 7, child: identity),
          if (hasWakeControl) ...[
            SizedBox(width: tokens.spacing.cardItemSpacing),
            Flexible(flex: 6, child: wakeControl),
          ],
          SizedBox(width: tokens.spacing.cardItemSpacing),
          Flexible(
            flex: 5,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: automationLabel),
                SizedBox(width: tokens.spacing.step2),
                automationToggle,
              ],
            ),
          ),
        ],
      );
    }

    Widget compactUtilityStack() {
      return Column(
        key: const ValueKey('taskAgentFooterCompactLayout'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasWakeControl) ...[
            Align(alignment: Alignment.centerLeft, child: wakeControl),
            SizedBox(height: tokens.spacing.step1),
          ],
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    automationLabel,
                    identity,
                  ],
                ),
              ),
              SizedBox(width: tokens.spacing.step2),
              automationToggle,
            ],
          ),
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
              final compactWidth =
                  TaskAgentFreshnessStrip.compactWidth +
                  (hasWakeControl ? tokens.spacing.step10 : 0);
              final compact =
                  constraints.maxWidth < compactWidth || textScale > 1.3;
              return compact ? compactUtilityStack() : wideUtilityRail();
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
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: tokens.spacing.step8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
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
          Text(
            context.messages.aiSummaryThinkingLabel,
            key: const ValueKey('taskAgentThinkingLabel'),
            style: tokens.typography.styles.subtitle.subtitle2.copyWith(
              color: ai.accent,
            ),
          ),
        ],
      ),
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
  @override
  DateTime get nextWakeAt => widget.nextWakeAt;

  @override
  void didUpdateWidget(covariant _CountdownControl oldWidget) {
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
    final label = context.messages.taskAgentNextUpdateIn(
      formatCountdown(countdownSeconds),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
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
            labelWidget: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tokens.typography.styles.others.caption.copyWith(
                color: ai.metaText,
                fontFeatures: const [FontFeature.tabularFigures()],
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
                borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
                child: SizedBox(
                  key: const ValueKey('taskAgentCancelCountdownTarget'),
                  width: tokens.spacing.step8,
                  height: tokens.spacing.step8,
                  child: Center(
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
      ],
    );
  }
}
