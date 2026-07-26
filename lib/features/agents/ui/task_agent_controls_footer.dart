import 'package:flutter/material.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/tldr_section_part.dart';
import 'package:lotti/features/agents/ui/task_agent_automation_row.dart';
import 'package:lotti/features/agents/ui/task_agent_identity_region.dart';
import 'package:lotti/features/agents/ui/task_agent_model_identity.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// Quiet settings zone pinned to the bottom of the task-agent card.
///
/// The band answers three questions, top to bottom, and nothing else:
///
///  1. *what am I looking at* — is the summary current, and when does it
///     update next;
///  2. *when does it update* — the always-available manual trigger and the
///     automatic-updates switch;
///  3. *which AI is answering* — the tappable setup row, plus an attribution
///     line when the visible report was written by a different route.
///
/// Questions 1 and 2 share a line whenever they fit, which is what
/// [TaskAgentAutomationRow] decides.
///
/// **The band is the only surface.** Its wash and top hairline are the
/// container; nothing inside draws a second fill, border or radius. An earlier
/// revision boxed the automation controls in a nested card, which cost a
/// nesting level, two horizontal insets and a third leading edge — and in the
/// light theme its fill was the band's own fill, so it was invisible anyway.
///
/// **One leading edge, one trailing rail.** The band pays `spacing.step4` and
/// each row adds `spacing.step2` of its own inset, so every glyph lands on
/// `spacing.cardPadding` — the same column as the summary prose and the
/// proposal rows — while interactive rows still get ink that breathes around
/// their content instead of being clipped flush against it.
class TaskAgentControlsFooter extends StatelessWidget {
  const TaskAgentControlsFooter({
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
    required this.identityData,
    required this.onSetupTap,
    super.key,
  });

  final bool automaticUpdatesEnabled;
  final bool automationBusy;
  final bool inferenceAvailable;
  final bool isRunning;
  final bool showCountdown;
  final DateTime? nextWakeAt;

  /// Whether the card has a summary to describe freshness for — a blank task
  /// has nothing to be "out of date", so the status is omitted rather than
  /// shown in some default state.
  final bool hasReportContent;

  /// Whether the current report is stale. Only meaningful when
  /// [hasReportContent] is true.
  final bool isStale;
  final ValueChanged<bool> onAutomaticUpdatesChanged;
  final VoidCallback? onRunNow;

  /// Cancels the pending automatic update, leaving automatic updates on.
  final VoidCallback onSkipScheduledUpdate;
  final VoidCallback onCountdownExpired;
  final TaskAgentModelIdentityViewData identityData;
  final VoidCallback onSetupTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;

    return Container(
      key: const ValueKey('taskAgentControlsFooter'),
      decoration: BoxDecoration(
        color: ai.footerWash,
        border: Border(top: BorderSide(color: ai.borderSoft)),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step4,
        vertical: tokens.spacing.step4,
      ),
      // The wash band spans the card, but the content snaps to the same
      // reading measure as the summary and proposal rows.
      child: Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: TldrBody.maxReadingWidth),
          child: Column(
            key: const ValueKey('taskAgentFooterLayout'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The automation row has no ink of its own to inset, so it
              // carries the step2 as padding to sit on the shared edge.
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.spacing.step2,
                ),
                child: TaskAgentAutomationRow(
                  automaticUpdatesEnabled: automaticUpdatesEnabled,
                  automationBusy: automationBusy,
                  inferenceAvailable: inferenceAvailable,
                  isRunning: isRunning,
                  showCountdown: showCountdown,
                  nextWakeAt: nextWakeAt,
                  hasReportContent: hasReportContent,
                  isStale: isStale,
                  onAutomaticUpdatesChanged: onAutomaticUpdatesChanged,
                  onRunNow: onRunNow,
                  onSkipScheduledUpdate: onSkipScheduledUpdate,
                  onCountdownExpired: onCountdownExpired,
                ),
              ),
              // No declared gap: the automation row's last box and the
              // identity row below it are both `step8` minimums with smaller
              // ink inside, so ~20 logical px of air already exists between
              // the two baselines. Adding `step4` on top of that is what made
              // the band read as three widely-spaced peers rather than one
              // settings block.
              TaskAgentIdentityRegion(
                data: identityData,
                onSetupTap: onSetupTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
