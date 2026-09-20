import 'dart:async';
import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_report_provenance.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/project_agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_model_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/agents/ui/agent_automation_row.dart';
import 'package:lotti/features/agents/ui/agent_model_sheet.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/tldr_section_part.dart';
import 'package:lotti/features/agents/ui/task_agent_identity_region.dart';
import 'package:lotti/features/agents/ui/task_agent_model_identity.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// Which agent kind a maintenance band is governing, and therefore which
/// service performs its three actions.
///
/// The two services expose the same pair — `triggerReanalysis` and
/// `cancelScheduledWake` — but are separate objects driving separate
/// orchestrators, so the band dispatches on the kind rather than taking
/// callbacks from whoever opened it. Callbacks would have closed over the
/// card's `Ref`: the band renders inside a pushed route, and the surface
/// underneath it is free to rebuild or go away.
enum AgentMaintenanceKind { task, project }

/// The agent whose maintenance controls a surface is offering, and the entity
/// the model sheet edits the setup for.
@immutable
class AgentMaintenanceScope {
  const AgentMaintenanceScope({required this.kind, required this.entityId});

  final AgentMaintenanceKind kind;

  /// The task or project id — what `AgentModelSheet` needs to write a setup
  /// choice back to, which is never the agent's own id.
  final String entityId;
}

/// The agent's maintenance controls: how its report refreshes, and which AI
/// writes it.
///
/// The band answers three questions, top to bottom, and nothing else:
///
///  1. *is the summary current* — the freshness word, and the manual trigger
///     beside it;
///  2. *when does it update by itself* — the automatic-updates switch, the
///     countdown to the next run, and the action that skips just that run;
///  3. *which AI is answering* — the tappable setup row, plus an attribution
///     line when the visible report was written by a different route.
///
/// Questions 1 and 2 share a line whenever they fit, which is what
/// [AgentAutomationRow] decides.
///
/// **It is plumbing, and plumbing does not belong on a reading surface.** The
/// band used to be pinned to the bottom of the task and project summary
/// cards, where six controls sat under a three-line summary and said, most of
/// the time, only that nothing needed doing. It now lives behind *Open agent
/// internals*, beside the reports, conversations and activity it belongs
/// with; the cards keep the summary, the proposals, and a freshness word that
/// appears only when the summary is actually behind.
///
/// **The band derives its own state.** Everything it shows comes from the
/// agent providers keyed by [agentId], so it stays live while the surface
/// that opened it rebuilds — or does not.
///
/// **The band is the only surface.** Its wash and hairline are the container;
/// nothing inside draws a second fill, border or radius.
///
/// **One leading edge, one trailing rail.** The band pays `spacing.step4` and
/// each row adds `spacing.step2` of its own inset, so every glyph lands on
/// `spacing.cardPadding` while interactive rows still get ink that breathes
/// around their content instead of being clipped flush against it.
class AgentMaintenanceSection extends ConsumerStatefulWidget {
  const AgentMaintenanceSection({
    required this.agentId,
    required this.scope,
    super.key,
  });

  final String agentId;
  final AgentMaintenanceScope scope;

  @override
  ConsumerState<AgentMaintenanceSection> createState() =>
      _AgentMaintenanceSectionState();
}

class _AgentMaintenanceSectionState
    extends ConsumerState<AgentMaintenanceSection> {
  bool _automationBusy = false;

  /// The deadline *Skip once* was tapped against, so the countdown withdraws
  /// on the tap rather than on the round trip.
  ///
  /// The deadline rather than a bare flag: a wake rescheduled while the band
  /// is open carries a new timestamp, and a boolean would have kept its
  /// countdown hidden behind a cancellation of the run before it.
  DateTime? _skippedWakeAt;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    final agentId = widget.agentId;

    final report = ref
        .watch(agentReportProvider(agentId))
        .value
        ?.mapOrNull(agentReport: (value) => value);
    final identity = ref
        .watch(agentIdentityProvider(agentId))
        .value
        ?.mapOrNull(agent: (value) => value);
    final state = ref
        .watch(agentStateProvider(agentId))
        .value
        ?.mapOrNull(agentState: (value) => value);
    final isRunning = ref.watch(agentIsRunningProvider(agentId)).value ?? false;
    final setup = ref.watch(taskAgentResolvedSetupProvider(agentId)).value;

    final identityData = TaskAgentModelIdentityViewData.fromResolution(
      setup: setup,
      reportProvenance: report == null
          ? null
          : ReportInferenceProvenance.tryRead(report.provenance),
      hasReport: report != null,
    );
    final inferenceAvailable =
        identityData.presentation != TaskAgentIdentityPresentation.disabled &&
        identityData.presentation != TaskAgentIdentityPresentation.broken;
    final automaticUpdatesEnabled =
        identity?.config.automaticUpdatesEnabledEffective ?? false;

    // The live deadline, then the persisted one: a project agent's pending
    // wake is recorded in `scheduledWakeAt` while the runtime holds
    // `nextWakeAt`, and a band that read only one of the two would promise
    // nothing about a run that is genuinely queued.
    final nextWakeAt = state?.nextWakeAt ?? state?.scheduledWakeAt;
    final remaining = nextWakeAt == null
        ? Duration.zero
        : nextWakeAt.difference(clock.now());
    final showCountdown =
        inferenceAvailable &&
        automaticUpdatesEnabled &&
        !isRunning &&
        remaining > Duration.zero &&
        nextWakeAt != _skippedWakeAt;

    return Container(
      key: const ValueKey('agentMaintenanceSection'),
      decoration: BoxDecoration(
        color: ai.footerWash,
        border: Border(bottom: BorderSide(color: ai.borderSoft)),
      ),
      // Vertical inset deliberately smaller than the horizontal: the rows
      // inside are minimum-height boxes taller than their ink, so they bring
      // their own air.
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step4,
        vertical: tokens.spacing.step2,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: TldrBody.maxReadingWidth),
          child: Column(
            key: const ValueKey('agentMaintenanceLayout'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The automation row has no ink of its own to inset, so it
              // carries the step2 as padding to sit on the shared edge.
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.spacing.step2,
                ),
                child: AgentAutomationRow(
                  automaticUpdatesEnabled: automaticUpdatesEnabled,
                  automationBusy: _automationBusy,
                  inferenceAvailable: inferenceAvailable,
                  isRunning: isRunning,
                  showCountdown: showCountdown,
                  nextWakeAt: nextWakeAt,
                  hasReportContent: resolveReportTldr(report).isNotEmpty,
                  isStale: state?.isReportStale ?? false,
                  onAutomaticUpdatesChanged: (enabled) =>
                      unawaited(_updateAutomaticUpdates(enabled: enabled)),
                  onRunNow: inferenceAvailable ? _runNow : null,
                  onSkipScheduledUpdate: () =>
                      unawaited(_skipScheduledUpdate(nextWakeAt)),
                  onCountdownExpired: () {
                    if (mounted) setState(() {});
                  },
                ),
              ),
              // No declared gap: the automation row's last box (`step7`) and
              // the identity row below it (`step6`) are minimums with smaller
              // ink inside, so air already exists between the two baselines.
              TaskAgentIdentityRegion(
                data: identityData,
                onSetupTap: () => AgentModelSheet.show(
                  context: context,
                  entityId: widget.scope.entityId,
                  agentId: agentId,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _runNow() {
    switch (widget.scope.kind) {
      case AgentMaintenanceKind.task:
        ref.read(taskAgentServiceProvider).triggerReanalysis(widget.agentId);
      case AgentMaintenanceKind.project:
        ref.read(projectAgentServiceProvider).triggerReanalysis(widget.agentId);
    }
  }

  Future<void> _skipScheduledUpdate(DateTime? wakeAt) async {
    setState(() => _skippedWakeAt = wakeAt);
    final cancelled = await _guarded(
      'Failed to cancel scheduled wake',
      () async {
        switch (widget.scope.kind) {
          case AgentMaintenanceKind.task:
            ref
                .read(taskAgentServiceProvider)
                .cancelScheduledWake(widget.agentId);
          case AgentMaintenanceKind.project:
            await ref
                .read(projectAgentServiceProvider)
                .cancelScheduledWake(widget.agentId);
        }
      },
    );
    // The latch is optimistic — it hides the countdown on the tap rather than
    // on the round trip. A cancellation that did not happen leaves the wake
    // scheduled and about to fire, so the countdown and its Skip action have
    // to come back; otherwise the band reads "Updates on changes" over a
    // pending run and the user is left with a toast and no way to retry.
    if (!cancelled && mounted) {
      setState(() => _skippedWakeAt = null);
    }
  }

  Future<void> _updateAutomaticUpdates({required bool enabled}) async {
    if (_automationBusy) return;
    setState(() => _automationBusy = true);
    try {
      await _guarded('Failed to update automatic updates', () async {
        // Not dispatched on the kind: the switch writes `AgentConfig`, which
        // is the same record whoever owns the agent, and `TaskAgentService`
        // is where that write lives. The project card wrote it through the
        // same service before the band moved here.
        await ref
            .read(taskAgentServiceProvider)
            .updateAutomaticUpdates(
              agentId: widget.agentId,
              enabled: enabled,
            );
        ref.invalidate(agentIdentityProvider(widget.agentId));
      });
    } finally {
      if (mounted) setState(() => _automationBusy = false);
    }
  }

  /// Runs [action], reporting a failure once — in the log for the developer
  /// and as a toast for the user — rather than letting it surface as an
  /// unhandled error from a fire-and-forget tap.
  ///
  /// Returns whether the action completed, so a caller that moved the UI
  /// ahead of the round trip can put it back.
  Future<bool> _guarded(String what, Future<void> Function() action) async {
    try {
      await action();
      return true;
    } catch (error, stackTrace) {
      developer.log(
        what,
        name: 'AgentMaintenanceSection',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        context.showToast(
          tone: DesignSystemToastTone.error,
          title: context.messages.commonError,
        );
      }
      return false;
    }
  }
}
