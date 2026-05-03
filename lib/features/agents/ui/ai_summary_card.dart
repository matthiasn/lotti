import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/proposal_ledger.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/change_set_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/agents/state/unified_suggestion_providers.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/agents/ui/agent_creation_modal.dart';
import 'package:lotti/features/agents/ui/agent_internals_panel.dart';
import 'package:lotti/features/agents/ui/wake_countdown_state.dart';
import 'package:lotti/features/agents/ui/widgets/agent_markdown_view.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/projects/ui/widgets/shared_widgets.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/consts.dart';

/// Unified AI summary card for the task details column.
///
/// Replaces the separate "AI Summary" + "Decision Activity" stack with a
/// single deep-teal-tinted-navy surface that exposes the agent's TLDR,
/// an expandable inline report, the actionable proposals list, the
/// resolved-proposal history, and a recent-activity footer. Also
/// surfaces the wake-cycle affordances (countdown / run-now / cancel)
/// directly in the header. Uses the same data sources as the prior
/// prior `AgentSuggestionsPanel` (proposal ledger, agent report, wake
/// state).
class AiSummaryCard extends ConsumerWidget {
  const AiSummaryCard({required this.taskId, super.key});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enableAgents =
        ref.watch(configFlagProvider(enableAgentsFlag)).value ?? false;
    if (!enableAgents) return const SizedBox.shrink();

    final taskAgentAsync = ref.watch(taskAgentProvider(taskId));

    return taskAgentAsync.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: SizedBox.shrink,
      error: (_, _) => const SizedBox.shrink(),
      data: (agentEntity) {
        final identity = agentEntity?.mapOrNull(agent: (e) => e);
        if (identity == null) return _AssignAgentCta(taskId: taskId);
        return _AiSummaryShell(taskId: taskId, identity: identity);
      },
    );
  }
}

class _AssignAgentCta extends ConsumerWidget {
  const _AssignAgentCta({required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ai = context.designTokens.colors.aiCard;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Center(
        child: TextButton.icon(
          onPressed: () => _createTaskAgent(context, ref, taskId),
          icon: Icon(Icons.auto_awesome_rounded, size: 18, color: ai.accent),
          label: Text(context.messages.taskAgentCreateChipLabel),
          style: TextButton.styleFrom(foregroundColor: ai.accent),
        ),
      ),
    );
  }
}

class _AiSummaryShell extends ConsumerStatefulWidget {
  const _AiSummaryShell({required this.taskId, required this.identity});

  final String taskId;
  final AgentIdentityEntity identity;

  @override
  ConsumerState<_AiSummaryShell> createState() => _AiSummaryShellState();
}

class _AiSummaryShellState extends ConsumerState<_AiSummaryShell> {
  bool _expanded = false;
  bool _activityOpen = false;
  bool _historyOpen = false;
  bool _confirmAllBusy = false;
  bool _cancelledManually = false;

  int _computeRemainingSeconds(DateTime? nextWakeAt) {
    if (nextWakeAt == null) return 0;
    final remaining = nextWakeAt.difference(clock.now()).inSeconds;
    return remaining.clamp(0, WakeOrchestrator.throttleWindow.inSeconds);
  }

  void _openInternals() {
    Navigator.of(context).push(
      AgentInternalsPanel.route(
        agentId: widget.identity.agentId,
        agentName: widget.identity.displayName,
      ),
    );
  }

  Future<void> _confirmAll(List<PendingSuggestion> pending) async {
    if (_confirmAllBusy || pending.isEmpty) return;
    setState(() => _confirmAllBusy = true);

    final service = ref.read(changeSetConfirmationServiceProvider);
    final notifier = ref.read(updateNotificationsProvider);
    final messages = context.messages;

    final distinctSets = <String, ChangeSetEntity>{
      for (final s in pending) s.changeSet.id: s.changeSet,
    };
    final agentIds = <String>{
      for (final cs in distinctSets.values) cs.agentId,
    };

    var anyFailed = false;
    try {
      for (final cs in distinctSets.values) {
        final results = await service.confirmAll(cs);
        if (results.any((r) => !r.success)) anyFailed = true;
      }
      if (mounted) {
        context.showToast(
          tone: anyFailed
              ? DesignSystemToastTone.error
              : DesignSystemToastTone.success,
          title: anyFailed
              ? messages.changeSetConfirmError
              : messages.changeSetItemConfirmed,
          clearQueue: true,
        );
      }
    } catch (e, stackTrace) {
      developer.log(
        'confirmAll failed',
        name: 'AiSummaryCard',
        error: e,
        stackTrace: stackTrace,
      );
      if (mounted) {
        context.showToast(
          tone: DesignSystemToastTone.error,
          title: messages.changeSetConfirmError,
          clearQueue: true,
        );
      }
    } finally {
      notifier.notify(agentIds);
      if (mounted) setState(() => _confirmAllBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    final agentId = widget.identity.agentId;

    final reportAsync = ref.watch(agentReportProvider(agentId));
    final report = reportAsync.value?.mapOrNull(agentReport: (r) => r);
    final listAsync = ref.watch(unifiedSuggestionListProvider(widget.taskId));
    final list = listAsync.value ?? const UnifiedSuggestionList.empty();

    final tldr = _resolveTldr(report);
    final additionalReport = _resolveAdditionalReport(report);

    final isRunning = ref.watch(agentIsRunningProvider(agentId)).value ?? false;
    final agentStateAsync = ref.watch(agentStateProvider(agentId));
    final nextWakeAt = agentStateAsync.value?.mapOrNull(
      agentState: (s) => s.nextWakeAt,
    );
    final remainingSeconds = _computeRemainingSeconds(nextWakeAt);

    ref.listen(agentStateProvider(agentId), (prev, next) {
      final newNextWake = next.value?.mapOrNull(
        agentState: (s) => s.nextWakeAt,
      );
      if (_computeRemainingSeconds(newNextWake) <= 0) {
        _cancelledManually = false;
      }
    });

    final showCountdown =
        !isRunning && remainingSeconds > 0 && !_cancelledManually;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: ai.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ai.border),
        boxShadow: [
          BoxShadow(
            color: ai.accent.withValues(alpha: 0.10),
            blurRadius: 24,
            spreadRadius: -6,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TldrHeader(
              agentName: widget.identity.displayName,
              hasMore: tldr.isNotEmpty || additionalReport != null,
              expanded: _expanded,
              onToggle: () => setState(() => _expanded = !_expanded),
              onAgentTap: _openInternals,
              isRunning: isRunning,
              showCountdown: showCountdown,
              nextWakeAt: nextWakeAt,
              onRunNow: () =>
                  ref.read(taskAgentServiceProvider).triggerReanalysis(agentId),
              onCancelTimer: () {
                ref.read(taskAgentServiceProvider).cancelScheduledWake(agentId);
                setState(() => _cancelledManually = true);
              },
              onCountdownExpired: () {
                if (mounted) setState(() {});
              },
            ),
            if (tldr.isNotEmpty)
              _TldrBody(
                tldr: tldr,
                expanded: _expanded,
                additionalReport: additionalReport,
                onOpenInternals: _openInternals,
              ),
            _ProposalsSection(
              open: list.open,
              resolved: list.activity,
              historyOpen: _historyOpen,
              onToggleHistory: () =>
                  setState(() => _historyOpen = !_historyOpen),
              confirmAllBusy: _confirmAllBusy,
              onConfirmAll: list.open.length > 1
                  ? () => _confirmAll(list.open)
                  : null,
            ),
            _ActivityFooter(
              count: list.activity.length,
              open: _activityOpen,
              onToggle: list.activity.isEmpty
                  ? null
                  : () => setState(() => _activityOpen = !_activityOpen),
              onOpenInternals: _openInternals,
            ),
            if (_activityOpen && list.activity.isNotEmpty)
              _ActivityList(
                activity: list.activity,
                agentName: widget.identity.displayName,
              ),
          ],
        ),
      ),
    );
  }

  String _resolveTldr(AgentReportEntity? report) {
    if (report == null) return '';
    final explicit = report.tldr?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    return report.content.trim();
  }

  String? _resolveAdditionalReport(AgentReportEntity? report) {
    if (report == null) return null;
    final content = report.content.trim();
    if (content.isEmpty) return null;
    final explicitTldr = report.tldr?.trim();
    if (explicitTldr == null || explicitTldr.isEmpty) return null;
    return content;
  }
}

class _TldrHeader extends StatelessWidget {
  const _TldrHeader({
    required this.agentName,
    required this.hasMore,
    required this.expanded,
    required this.onToggle,
    required this.onAgentTap,
    required this.isRunning,
    required this.showCountdown,
    required this.nextWakeAt,
    required this.onRunNow,
    required this.onCancelTimer,
    required this.onCountdownExpired,
  });

  final String? agentName;
  final bool hasMore;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onAgentTap;
  final bool isRunning;
  final bool showCountdown;
  final DateTime? nextWakeAt;
  final VoidCallback onRunNow;
  final VoidCallback onCancelTimer;
  final VoidCallback onCountdownExpired;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    final messages = context.messages;
    final hasAgentName = agentName != null && agentName!.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 8, 10),
      child: Row(
        children: [
          _SparkleBadge(),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  messages.aiCardTitle,
                  style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                  ),
                ),
                if (hasAgentName)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: GestureDetector(
                      onTap: onAgentTap,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Text(
                          agentName!.trim(),
                          style: tokens.typography.styles.others.caption
                              .copyWith(
                                color: ai.metaText,
                                decoration: TextDecoration.underline,
                                decorationColor: ai.metaText.withValues(
                                  alpha: 0.40,
                                ),
                              ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (isRunning)
            SizedBox(
              width: 28,
              height: 28,
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: ai.accent,
                  ),
                ),
              ),
            ),
          if (!isRunning && !showCountdown)
            _IconAffordance(
              icon: Icons.refresh_rounded,
              tooltip: messages.taskAgentRunNowTooltip,
              onPressed: onRunNow,
            ),
          if (showCountdown && nextWakeAt != null) ...[
            _IconAffordance(
              icon: Icons.play_arrow_rounded,
              tooltip: messages.taskAgentRunNowTooltip,
              onPressed: onRunNow,
            ),
            _CountdownPill(
              nextWakeAt: nextWakeAt!,
              onExpired: onCountdownExpired,
            ),
            _IconAffordance(
              icon: Icons.close_rounded,
              tooltip: messages.taskAgentCancelTimerTooltip,
              onPressed: onCancelTimer,
              compact: true,
            ),
          ],
          if (hasMore) _ReadMorePill(expanded: expanded, onPressed: onToggle),
        ],
      ),
    );
  }
}

class _SparkleBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ai = context.designTokens.colors.aiCard;
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ai.accentSoft,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(Icons.auto_awesome_rounded, size: 14, color: ai.accent),
    );
  }
}

class _ReadMorePill extends StatelessWidget {
  const _ReadMorePill({required this.expanded, required this.onPressed});

  final bool expanded;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    final messages = context.messages;
    final label = expanded ? messages.aiCardShowLess : messages.aiCardReadMore;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(13),
          child: Container(
            height: 26,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: ai.accentSoft,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: ai.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: tokens.typography.styles.others.caption.copyWith(
                    color: ai.accent,
                    fontWeight: FontWeight.w500,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  size: 14,
                  color: ai.accent,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IconAffordance extends StatelessWidget {
  const _IconAffordance({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.compact = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ai = context.designTokens.colors.aiCard;
    return IconButton(
      icon: Icon(icon, size: compact ? 16 : 18, color: ai.metaText),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints(
        minWidth: compact ? 24 : 28,
        minHeight: compact ? 24 : 28,
      ),
      onPressed: onPressed,
    );
  }
}

class _CountdownPill extends StatefulWidget {
  const _CountdownPill({required this.nextWakeAt, required this.onExpired});

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
    if (oldWidget.nextWakeAt != widget.nextWakeAt) {
      resyncCountdown();
    }
  }

  @override
  void onCountdownExpired() => widget.onExpired();

  @override
  Widget build(BuildContext context) {
    if (countdownSeconds <= 0) return const SizedBox.shrink();
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Container(
        width: 52,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: ai.accentSoft,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ai.border),
        ),
        child: Text(
          formatCountdown(countdownSeconds),
          textAlign: TextAlign.center,
          style: tokens.typography.styles.others.caption.copyWith(
            color: ai.accent,
            fontFeatures: const [FontFeature.tabularFigures()],
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _TldrBody extends StatelessWidget {
  const _TldrBody({
    required this.tldr,
    required this.expanded,
    required this.additionalReport,
    required this.onOpenInternals,
  });

  final String tldr;
  final bool expanded;
  final String? additionalReport;
  final VoidCallback onOpenInternals;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    final bodyStyle = tokens.typography.styles.body.bodySmall.copyWith(
      color: ai.bodyText,
      height: 1.55,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectionArea(child: AgentMarkdownView(tldr, style: bodyStyle)),
          if (expanded && additionalReport != null) ...[
            const SizedBox(height: 14),
            SelectionArea(
              child: AgentMarkdownView(additionalReport!, style: bodyStyle),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: _OpenInternalsPill(onPressed: onOpenInternals),
            ),
          ],
        ],
      ),
    );
  }
}

class _OpenInternalsPill extends StatelessWidget {
  const _OpenInternalsPill({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          height: 26,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: ai.accentSoft,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: ai.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.tune_rounded, size: 14, color: ai.accent),
              const SizedBox(width: 6),
              Text(
                context.messages.aiCardOpenAgentInternals,
                style: tokens.typography.styles.others.caption.copyWith(
                  color: ai.accent,
                  fontWeight: FontWeight.w500,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProposalsSection extends StatelessWidget {
  const _ProposalsSection({
    required this.open,
    required this.resolved,
    required this.historyOpen,
    required this.onToggleHistory,
    required this.confirmAllBusy,
    required this.onConfirmAll,
  });

  final List<PendingSuggestion> open;
  final List<LedgerEntry> resolved;
  final bool historyOpen;
  final VoidCallback onToggleHistory;
  final bool confirmAllBusy;
  final Future<void> Function()? onConfirmAll;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    final messages = context.messages;

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: ai.borderSoft)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.fact_check_outlined, size: 16, color: ai.accent),
              const SizedBox(width: 8),
              Text(
                messages.changeSetCardTitle,
                style: tokens.typography.styles.body.bodySmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
              ),
              const SizedBox(width: 8),
              _PendingPill(count: open.length),
              const Spacer(),
              if (onConfirmAll != null)
                _ConfirmAllButton(
                  busy: confirmAllBusy,
                  onPressed: onConfirmAll!,
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (open.isEmpty)
            const _EmptyProposalsRow()
          else
            for (var i = 0; i < open.length; i++)
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
                child: _ProposalRow(suggestion: open[i]),
              ),
          if (resolved.isNotEmpty) ...[
            const SizedBox(height: 10),
            _HistoryToggle(
              open: historyOpen,
              count: resolved.length,
              onPressed: onToggleHistory,
            ),
            if (historyOpen) ...[
              const SizedBox(height: 8),
              for (var i = 0; i < resolved.length; i++)
                Padding(
                  padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
                  child: _ProposalRow.fromLedger(entry: resolved[i]),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

class _PendingPill extends StatelessWidget {
  const _PendingPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    final hasItems = count > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: hasItems
            ? ai.accent.withValues(alpha: 0.10)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        context.messages.changeSetPendingCount(count),
        style: tokens.typography.styles.others.caption.copyWith(
          color: hasItems ? ai.accent : ai.metaText,
          fontWeight: FontWeight.w600,
          height: 1.1,
        ),
      ),
    );
  }
}

class _ConfirmAllButton extends StatelessWidget {
  const _ConfirmAllButton({required this.busy, required this.onPressed});

  final bool busy;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    return TextButton.icon(
      onPressed: busy ? null : onPressed.call,
      icon: busy
          ? SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: ai.accent,
              ),
            )
          : Icon(Icons.done_all_rounded, size: 16, color: ai.accent),
      label: Text(
        context.messages.changeSetConfirmAll,
        style: tokens.typography.styles.others.caption.copyWith(
          color: ai.accent,
          fontWeight: FontWeight.w600,
          height: 1.1,
        ),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: ai.accent,
      ),
    );
  }
}

class _EmptyProposalsRow extends StatelessWidget {
  const _EmptyProposalsRow();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Center(
        child: Text(
          context.messages.aiCardEmptyProposals,
          style: tokens.typography.styles.others.caption.copyWith(
            color: ai.metaText,
            fontWeight: FontWeight.w400,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

class _HistoryToggle extends StatelessWidget {
  const _HistoryToggle({
    required this.open,
    required this.count,
    required this.onPressed,
  });

  final bool open;
  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                open ? Icons.keyboard_arrow_down : Icons.chevron_right,
                size: 14,
                color: ai.metaText,
              ),
              const SizedBox(width: 4),
              Text(
                context.messages.aiCardHistoryToggle(count),
                style: tokens.typography.styles.others.caption.copyWith(
                  color: ai.metaText,
                  fontWeight: FontWeight.w500,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProposalRow extends ConsumerStatefulWidget {
  const _ProposalRow({required PendingSuggestion this.suggestion})
    : entry = null;

  const _ProposalRow.fromLedger({required LedgerEntry this.entry})
    : suggestion = null;

  final PendingSuggestion? suggestion;
  final LedgerEntry? entry;

  bool get isResolved => entry != null;

  @override
  ConsumerState<_ProposalRow> createState() => _ProposalRowState();
}

class _ProposalRowState extends ConsumerState<_ProposalRow> {
  static const double _swipeTrigger = 70;

  double _dx = 0;
  bool _animating = false;
  bool _busy = false;

  String get _toolName =>
      widget.suggestion?.item.toolName ?? widget.entry!.toolName;
  Map<String, dynamic> get _args =>
      widget.suggestion?.item.args ?? widget.entry!.args;
  String get _humanSummary =>
      widget.suggestion?.item.humanSummary ?? widget.entry!.humanSummary;
  ChangeItemStatus? get _resolvedStatus => widget.entry?.status;

  void _onPointerDown(PointerDownEvent event) {
    if (widget.isResolved || _busy) return;
    setState(() => _animating = false);
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (widget.isResolved || _busy) return;
    setState(() => _dx += event.delta.dx);
  }

  Future<void> _onPointerUp(PointerUpEvent event) async {
    if (widget.isResolved || _busy) return;
    setState(() => _animating = true);
    if (_dx > _swipeTrigger) {
      await _confirm();
    } else if (_dx < -_swipeTrigger) {
      await _reject();
    }
    if (mounted) setState(() => _dx = 0);
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
      developer.log('confirmItem failed: $e', name: 'AiSummaryCard');
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
      developer.log('rejectItem failed: $e', name: 'AiSummaryCard');
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
    final kind = _resolveKind(_toolName, _args);
    final kindMeta = _kindMeta(context, kind);
    final cleanText = _cleanText(_humanSummary, kindMeta.label);

    final dx = _dx;
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

    return ClipRRect(
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
              alignment: dx > 0 ? Alignment.centerLeft : Alignment.centerRight,
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
              color: widget.isResolved
                  ? Colors.white.withValues(alpha: 0.02)
                  : ai.row,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ai.rowBorder),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Listener(
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
              onPointerUp: _onPointerUp,
              behavior: HitTestBehavior.opaque,
              child: Opacity(
                opacity: dimmed ? 0.45 : 1,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _KindChip(meta: kindMeta),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        cleanText,
                        style: tokens.typography.styles.body.bodySmall.copyWith(
                          color: Colors.white.withValues(alpha: 0.88),
                          height: 1.5,
                          decoration: lineThrough
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (widget.isResolved)
                      _ResolvedTag(status: _resolvedStatus)
                    else
                      _RowActions(
                        busy: _busy,
                        onReject: _reject,
                        onConfirm: _confirm,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _cleanText(String summary, String kindLabel) {
    final pattern = RegExp(
      '^\\s*${RegExp.escape(kindLabel)}\\b[\\s:]*',
      caseSensitive: false,
    );
    return summary.replaceFirst(pattern, '').trim();
  }
}

enum _ProposalKind {
  add,
  update,
  remove,
  priority,
  estimate,
  status,
  label,
  due,
}

class _KindMeta {
  const _KindMeta({
    required this.color,
    required this.surface,
    required this.label,
  });

  final Color color;
  final Color surface;
  final String label;
}

_ProposalKind _resolveKind(String toolName, Map<String, dynamic> args) {
  switch (toolName) {
    case TaskAgentToolNames.addMultipleChecklistItems:
    case TaskAgentToolNames.addChecklistItem:
    case TaskAgentToolNames.createFollowUpTask:
    case TaskAgentToolNames.createTimeEntry:
    case TaskAgentToolNames.migrateChecklistItems:
    case TaskAgentToolNames.migrateChecklistItem:
      return _ProposalKind.add;
    case TaskAgentToolNames.updateChecklistItems:
    case TaskAgentToolNames.updateChecklistItem:
    case TaskAgentToolNames.updateTimeEntry:
    case TaskAgentToolNames.updateRunningTimer:
    case TaskAgentToolNames.setTaskTitle:
      return _ProposalKind.update;
    case TaskAgentToolNames.updateTaskPriority:
      return _ProposalKind.priority;
    case TaskAgentToolNames.updateTaskEstimate:
      return _ProposalKind.estimate;
    case TaskAgentToolNames.setTaskStatus:
      return _ProposalKind.status;
    case TaskAgentToolNames.assignTaskLabels:
    case TaskAgentToolNames.assignTaskLabel:
      return _ProposalKind.label;
    case TaskAgentToolNames.updateTaskDueDate:
      return _ProposalKind.due;
    default:
      return _ProposalKind.update;
  }
}

_KindMeta _kindMeta(BuildContext context, _ProposalKind kind) {
  final palette = context.designTokens.colors.proposalKind;
  final messages = context.messages;
  switch (kind) {
    case _ProposalKind.add:
      return _KindMeta(
        color: palette.add.color,
        surface: palette.add.surface,
        label: messages.aiCardProposalKindAdd,
      );
    case _ProposalKind.update:
      return _KindMeta(
        color: palette.update.color,
        surface: palette.update.surface,
        label: messages.aiCardProposalKindUpdate,
      );
    case _ProposalKind.remove:
      return _KindMeta(
        color: palette.remove.color,
        surface: palette.remove.surface,
        label: messages.aiCardProposalKindRemove,
      );
    case _ProposalKind.priority:
      return _KindMeta(
        color: palette.priority.color,
        surface: palette.priority.surface,
        label: messages.aiCardProposalKindPriority,
      );
    case _ProposalKind.estimate:
      return _KindMeta(
        color: palette.estimate.color,
        surface: palette.estimate.surface,
        label: messages.aiCardProposalKindEstimate,
      );
    case _ProposalKind.status:
      return _KindMeta(
        color: palette.status.color,
        surface: palette.status.surface,
        label: messages.aiCardProposalKindStatus,
      );
    case _ProposalKind.label:
      return _KindMeta(
        color: palette.label.color,
        surface: palette.label.surface,
        label: messages.aiCardProposalKindLabel,
      );
    case _ProposalKind.due:
      return _KindMeta(
        color: palette.due.color,
        surface: palette.due.surface,
        label: messages.aiCardProposalKindDue,
      );
  }
}

class _KindChip extends StatelessWidget {
  const _KindChip({required this.meta});

  final _KindMeta meta;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      margin: const EdgeInsets.only(top: 1),
      decoration: BoxDecoration(
        color: meta.surface,
        borderRadius: BorderRadius.circular(5),
      ),
      alignment: Alignment.center,
      child: Text(
        meta.label,
        style: tokens.typography.styles.others.caption.copyWith(
          color: meta.color,
          fontWeight: FontWeight.w600,
          height: 1,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _RowActions extends StatelessWidget {
  const _RowActions({
    required this.busy,
    required this.onReject,
    required this.onConfirm,
  });

  final bool busy;
  final Future<void> Function() onReject;
  final Future<void> Function() onConfirm;

  @override
  Widget build(BuildContext context) {
    if (busy) {
      return SizedBox(
        width: 26,
        height: 26,
        child: Center(
          child: SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: context.designTokens.colors.aiCard.accent,
            ),
          ),
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SquareIconButton(
          icon: Icons.close_rounded,
          tooltip: context.messages.changeSetSwipeReject,
          onPressed: onReject,
          variant: _SquareIconVariant.outline,
        ),
        const SizedBox(width: 4),
        _SquareIconButton(
          icon: Icons.check_rounded,
          tooltip: context.messages.changeSetSwipeConfirm,
          onPressed: onConfirm,
          variant: _SquareIconVariant.accent,
        ),
      ],
    );
  }
}

enum _SquareIconVariant { outline, accent }

class _SquareIconButton extends StatelessWidget {
  const _SquareIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.variant,
  });

  final IconData icon;
  final String tooltip;
  final Future<void> Function() onPressed;
  final _SquareIconVariant variant;

  @override
  Widget build(BuildContext context) {
    final ai = context.designTokens.colors.aiCard;
    final isAccent = variant == _SquareIconVariant.accent;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed.call,
          borderRadius: BorderRadius.circular(7),
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: isAccent ? ai.accent.withValues(alpha: 0.13) : null,
              border: Border.all(
                color: isAccent
                    ? ai.accent.withValues(alpha: 0.33)
                    : ai.rowBorderStrong,
              ),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(
              icon,
              size: 14,
              color: isAccent ? ai.accent : ai.metaText,
            ),
          ),
        ),
      ),
    );
  }
}

class _ResolvedTag extends StatelessWidget {
  const _ResolvedTag({required this.status});

  final ChangeItemStatus? status;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    final messages = context.messages;
    final isConfirmed = status == ChangeItemStatus.confirmed;
    final color = isConfirmed ? ai.accent : ai.faintMeta;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isConfirmed) ...[
            Icon(Icons.check, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            isConfirmed
                ? messages.aiCardProposalConfirmed
                : messages.aiCardProposalDismissed,
            style: tokens.typography.styles.others.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityFooter extends StatelessWidget {
  const _ActivityFooter({
    required this.count,
    required this.open,
    required this.onToggle,
    required this.onOpenInternals,
  });

  final int count;
  final bool open;
  final VoidCallback? onToggle;
  final VoidCallback onOpenInternals;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    final messages = context.messages;
    return Container(
      decoration: BoxDecoration(
        color: ai.footerWash,
        border: Border(top: BorderSide(color: ai.rowBorder)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        children: [
          Tooltip(
            message: messages.aiCardAgentNameTooltip,
            child: GestureDetector(
              onTap: onOpenInternals,
              child: Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      ai.accent.withValues(alpha: 0.6),
                      ai.accent.withValues(alpha: 0.25),
                    ],
                  ),
                ),
                child: Icon(
                  Icons.smart_toy_outlined,
                  size: 12,
                  color: ai.background,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              messages.aiCardRecentActions(count),
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: ai.bodyText,
                height: 1.2,
              ),
            ),
          ),
          if (onToggle != null)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onToggle,
                borderRadius: BorderRadius.circular(13),
                child: Container(
                  height: 26,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: ai.rowBorderStrong),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        open
                            ? messages.aiCardHideActivity
                            : messages.aiCardSeeActivity,
                        style: tokens.typography.styles.others.caption.copyWith(
                          color: ai.metaText,
                          fontWeight: FontWeight.w500,
                          height: 1,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        open ? Icons.expand_less : Icons.expand_more,
                        size: 14,
                        color: ai.metaText,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActivityList extends StatelessWidget {
  const _ActivityList({required this.activity, required this.agentName});

  final List<LedgerEntry> activity;
  final String? agentName;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    final messages = context.messages;
    final visible = activity.take(6).toList(growable: false);
    return Container(
      decoration: BoxDecoration(
        color: ai.footerWashOpen,
        border: Border(top: BorderSide(color: ai.rowBorder)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              messages.aiCardActivitySectionLabel,
              style: tokens.typography.styles.others.caption.copyWith(
                color: ai.faintMeta,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                height: 1,
              ),
            ),
          ),
          for (final entry in visible)
            _ActivityRow(entry: entry, agentName: agentName),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.entry, required this.agentName});

  final LedgerEntry entry;
  final String? agentName;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    final kind = _resolveKind(entry.toolName, entry.args);
    final iconData = _activityIcon(kind);
    final color = _activityColor(context, kind);
    final time = _relativeTime(entry.resolvedAt ?? entry.createdAt);
    final agent = agentName?.trim().isNotEmpty == true
        ? agentName!.trim()
        : null;
    final meta = agent != null ? '$time · $agent' : time;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 14,
            height: 18,
            child: Center(child: Icon(iconData, size: 12, color: color)),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.humanSummary,
                  style: tokens.typography.styles.body.bodySmall.copyWith(
                    color: Colors.white.withValues(alpha: 0.82),
                    height: 1.35,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(
                    meta,
                    style: tokens.typography.styles.others.caption.copyWith(
                      color: ai.faintMeta,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _activityIcon(_ProposalKind kind) {
    switch (kind) {
      case _ProposalKind.add:
        return Icons.add;
      case _ProposalKind.status:
        return Icons.check_circle_outline;
      case _ProposalKind.label:
        return Icons.label_outline;
      case _ProposalKind.priority:
        return Icons.flag_outlined;
      case _ProposalKind.estimate:
        return Icons.timer_outlined;
      case _ProposalKind.due:
        return Icons.calendar_today_outlined;
      case _ProposalKind.remove:
        return Icons.remove;
      case _ProposalKind.update:
        return Icons.edit_outlined;
    }
  }

  Color _activityColor(BuildContext context, _ProposalKind kind) {
    final palette = context.designTokens.colors.proposalKind;
    switch (kind) {
      case _ProposalKind.add:
        return palette.add.color;
      case _ProposalKind.status:
        return palette.estimate.color;
      case _ProposalKind.label:
        return palette.label.color;
      case _ProposalKind.priority:
        return palette.priority.color;
      case _ProposalKind.estimate:
        return palette.estimate.color;
      case _ProposalKind.due:
        return palette.due.color;
      case _ProposalKind.remove:
        return palette.remove.color;
      case _ProposalKind.update:
        return palette.update.color;
    }
  }

  String _relativeTime(DateTime when) {
    final now = clock.now();
    final diff = now.difference(when);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    final weeks = math.max(1, diff.inDays ~/ 7);
    return '${weeks}w ago';
  }
}

Future<void> _createTaskAgent(
  BuildContext context,
  WidgetRef ref,
  String taskId,
) async {
  final entryStateResult = await ref.read(
    entryControllerProvider(id: taskId).future,
  );
  final entryState = entryStateResult?.entry;
  if (entryState == null || entryState is! Task) return;

  final categoryId = entryState.meta.categoryId;
  final allowedCategoryIds = categoryId != null ? {categoryId} : <String>{};

  try {
    final service = ref.read(taskAgentServiceProvider);
    final templateService = ref.read(agentTemplateServiceProvider);

    var templates = categoryId != null
        ? await templateService.listTemplatesForCategory(categoryId)
        : <AgentTemplateEntity>[];
    if (templates.isEmpty) {
      templates = await templateService.listTemplates();
    }
    templates = templates
        .where((t) => t.kind == AgentTemplateKind.taskAgent)
        .toList();

    if (templates.isEmpty) {
      if (!context.mounted) return;
      context.showToast(
        tone: DesignSystemToastTone.warning,
        title: context.messages.agentTemplateNoTemplates,
      );
      return;
    }

    if (!context.mounted) return;

    final result = await AgentCreationModal.show(
      context: context,
      templates: templates,
    );

    if (result == null) return;

    await service.createTaskAgent(
      taskId: taskId,
      templateId: result.templateId,
      profileId: result.profileId,
      allowedCategoryIds: allowedCategoryIds,
    );
    if (context.mounted) {
      ref.invalidate(taskAgentProvider(taskId));
    }
  } catch (e, s) {
    developer.log(
      'Failed to create task agent',
      name: 'AiSummaryCard',
      error: e,
      stackTrace: s,
    );
    if (context.mounted) {
      context.showToast(
        tone: DesignSystemToastTone.error,
        title: context.messages.taskAgentCreateError(e.toString()),
      );
    }
  }
}
