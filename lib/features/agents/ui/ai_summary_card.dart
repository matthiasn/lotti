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

part 'ai_summary_card/activity_section_part.dart';
part 'ai_summary_card/assign_agent_cta_part.dart';
part 'ai_summary_card/proposal_kind_part.dart';
part 'ai_summary_card/proposals_section_part.dart';
part 'ai_summary_card/tldr_section_part.dart';

/// Unified AI summary card for the task details column.
///
/// Replaces the separate "AI Summary" + "Decision Activity" stack with
/// a single deep-teal-tinted-navy surface that exposes the agent's
/// TLDR, an expandable inline report, the actionable proposals list,
/// the resolved-proposal history, and a recent-activity footer. Also
/// surfaces the wake-cycle affordances (countdown / run-now / cancel)
/// directly in the header. Uses the same data sources as the prior
/// `AgentSuggestionsPanel` (proposal ledger, agent report, wake
/// state).
///
/// The card is a library split across part files in the
/// `ai_summary_card/` directory:
/// * `tldr_section_part.dart` — header, badge, pills, countdown,
///   TLDR body
/// * `proposals_section_part.dart` — section, row, kind chip, row
///   actions, history toggle, resolved tag
/// * `activity_section_part.dart` — footer, list, row, relative-time
///   helpers
/// * `proposal_kind_part.dart` — kind enum + tool-name mapping +
///   token lookup
/// * `assign_agent_cta_part.dart` — fallback CTA + create flow
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
        context: context,
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
