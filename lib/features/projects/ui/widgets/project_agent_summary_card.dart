import 'dart:async';
import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_report_provenance.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/project_agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_model_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/agents/ui/agent_internals_panel.dart';
import 'package:lotti/features/agents/ui/agent_model_sheet.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/tldr_section_part.dart';
import 'package:lotti/features/agents/ui/task_agent_controls_footer.dart';
import 'package:lotti/features/agents/ui/task_agent_model_identity.dart';
import 'package:lotti/features/agents/ui/widgets/ai_card_chrome.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/projects/ui/model/project_list_detail_models.dart';
import 'package:lotti/features/projects/ui/widgets/shared_tag_widgets.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Project-agent report rendered with the exact card and automation grammar
/// used by task agents.
///
/// Project-specific health context and durable actions remain feature-owned,
/// but they live inside this one intelligence surface rather than competing
/// health, report, recommendation, and control cards.
class ProjectAgentSummaryCard extends ConsumerStatefulWidget {
  const ProjectAgentSummaryCard({
    required this.projectId,
    required this.record,
    required this.identity,
    required this.hasProjectAgent,
    required this.isMutating,
    this.onAssignAgent,
    this.onViewBlocker,
    this.onRefresh,
    this.onCancelScheduledWake,
    this.actions,
    this.isRefreshing = false,
    super.key,
  });

  final String projectId;
  final ProjectRecord record;
  final AgentIdentityEntity? identity;
  final bool hasProjectAgent;
  final bool isMutating;
  final Future<void> Function()? onAssignAgent;
  final VoidCallback? onViewBlocker;
  final VoidCallback? onRefresh;
  final VoidCallback? onCancelScheduledWake;
  final Widget? actions;
  final bool isRefreshing;

  @override
  ConsumerState<ProjectAgentSummaryCard> createState() =>
      _ProjectAgentSummaryCardState();
}

class _ProjectAgentSummaryCardState
    extends ConsumerState<ProjectAgentSummaryCard> {
  bool _automationBusy = false;
  bool _assigning = false;

  Future<void> _assignAgent() async {
    final assign = widget.onAssignAgent;
    if (assign == null || _assigning || widget.isMutating) return;
    setState(() => _assigning = true);
    try {
      await assign();
    } finally {
      if (mounted) setState(() => _assigning = false);
    }
  }

  Future<void> _updateAutomaticUpdates({required bool enabled}) async {
    final identity = widget.identity;
    if (identity == null || _automationBusy || widget.isMutating) return;
    setState(() => _automationBusy = true);
    try {
      await ref
          .read(taskAgentServiceProvider)
          .updateAutomaticUpdates(
            agentId: identity.agentId,
            enabled: enabled,
          );
      ref
        ..invalidate(agentIdentityProvider(identity.agentId))
        ..invalidate(agentStateProvider(identity.agentId))
        ..invalidate(projectAgentProvider(widget.projectId));
    } catch (error, stackTrace) {
      developer.log(
        'Failed to update project-agent automation',
        name: 'ProjectAgentSummaryCard',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        context.showToast(
          tone: DesignSystemToastTone.error,
          title: context.messages.commonError,
        );
      }
    } finally {
      if (mounted) setState(() => _automationBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final identity = widget.identity;
    if (identity == null) {
      if (widget.hasProjectAgent) {
        return _ProjectReportSummary(
          record: widget.record,
          actions: widget.isMutating ? null : widget.actions,
          onViewBlocker: widget.isMutating ? null : widget.onViewBlocker,
        );
      }
      return _ProjectAssignAgentRow(
        onTap: widget.onAssignAgent == null ? null : _assignAgent,
        isBusy: _assigning,
      );
    }

    final agentId = identity.agentId;
    final report = ref
        .watch(agentReportProvider(agentId))
        .value
        ?.mapOrNull(agentReport: (value) => value);
    final state = ref
        .watch(agentStateProvider(agentId))
        .value
        ?.mapOrNull(agentState: (value) => value);
    final isRunning =
        (ref.watch(agentIsRunningProvider(agentId)).value ?? false) ||
        widget.isRefreshing;
    final setup = ref.watch(taskAgentResolvedSetupProvider(agentId)).value;
    final provenance = report == null
        ? null
        : ReportInferenceProvenance.tryRead(report.provenance);
    final identityData = TaskAgentModelIdentityViewData.fromResolution(
      setup: setup,
      reportProvenance: provenance,
      hasReport: report != null,
    );
    final inferenceAvailable =
        identityData.presentation != TaskAgentIdentityPresentation.disabled &&
        identityData.presentation != TaskAgentIdentityPresentation.broken;
    final template = ref.watch(templateForAgentProvider(agentId)).value;
    final templateName = template is AgentTemplateEntity
        ? template.displayName.trim()
        : null;
    final agentName = templateName == null || templateName.isEmpty
        ? identity.displayName
        : templateName;

    final hasReportContent =
        widget.record.aiSummary.trim().isNotEmpty ||
        widget.record.reportContent.trim().isNotEmpty;
    final automaticUpdatesEnabled =
        identity.config.automaticUpdatesEnabledEffective;
    final nextWakeAt = state?.nextWakeAt ?? state?.scheduledWakeAt;
    final remainingSeconds = nextWakeAt?.difference(clock.now()).inSeconds ?? 0;
    final showCountdown =
        inferenceAvailable &&
        automaticUpdatesEnabled &&
        !isRunning &&
        remainingSeconds > 0;

    void openInternals() {
      Navigator.of(context).push(
        AgentInternalsPanel.route(
          context: context,
          agentId: agentId,
          agentName: agentName,
        ),
      );
    }

    final footer = TaskAgentControlsFooter(
      automaticUpdatesEnabled: automaticUpdatesEnabled,
      automationBusy: _automationBusy,
      inferenceAvailable: inferenceAvailable && !widget.isMutating,
      isRunning: isRunning,
      showCountdown: showCountdown,
      nextWakeAt: nextWakeAt,
      hasReportContent: hasReportContent,
      isStale: state?.isReportStale ?? false,
      onAutomaticUpdatesChanged: (enabled) =>
          unawaited(_updateAutomaticUpdates(enabled: enabled)),
      onRunNow: widget.isMutating ? null : widget.onRefresh,
      onSkipScheduledUpdate: () {
        widget.onCancelScheduledWake?.call();
      },
      onCountdownExpired: () {
        if (mounted) setState(() {});
      },
      identityData: identityData,
      onSetupTap: () => AgentModelSheet.show(
        context: context,
        entityId: widget.projectId,
        agentId: agentId,
      ),
    );

    return _ProjectReportSummary(
      record: widget.record,
      agentName: agentName,
      onOpenInternals: openInternals,
      onViewBlocker: widget.isMutating ? null : widget.onViewBlocker,
      actions: widget.isMutating ? null : widget.actions,
      footer: footer,
    );
  }
}

class _ProjectReportSummary extends StatefulWidget {
  const _ProjectReportSummary({
    required this.record,
    required this.actions,
    required this.onViewBlocker,
    this.agentName,
    this.onOpenInternals,
    this.footer,
  });

  final ProjectRecord record;
  final Widget? actions;
  final VoidCallback? onViewBlocker;
  final String? agentName;
  final VoidCallback? onOpenInternals;
  final Widget? footer;

  @override
  State<_ProjectReportSummary> createState() => _ProjectReportSummaryState();
}

class _ProjectReportSummaryState extends State<_ProjectReportSummary> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final summary = widget.record.aiSummary.trim();
    final content = widget.record.reportContent.trim();
    final tldr = summary.isEmpty ? content : summary;
    final additionalReport = summary.isNotEmpty && content != summary
        ? content
        : null;

    return AgentSummaryCardSurface(
      children: [
        TldrHeader(
          agentName: widget.agentName,
          onAgentTap: widget.onOpenInternals,
        ),
        if (widget.record.healthMetrics != null)
          Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.spacing.cardPadding,
              0,
              tokens.spacing.cardPadding,
              tokens.spacing.step3,
            ),
            child: _ProjectHealthContext(
              record: widget.record,
              onViewBlocker: widget.onViewBlocker,
            ),
          ),
        if (widget.record.healthMetrics == null)
          Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.spacing.cardPadding,
              0,
              tokens.spacing.cardPadding,
              tokens.spacing.step3,
            ),
            child: const _ProjectEmptyAssessment(),
          ),
        if (tldr.isNotEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.spacing.cardPadding,
              0,
              tokens.spacing.cardPadding,
              tokens.spacing.step4,
            ),
            child: TldrBody(
              disclosureKey: const ValueKey('project-report-disclosure'),
              tldr: tldr,
              expanded: _expanded,
              additionalReport: additionalReport,
              onToggle: () => setState(() => _expanded = !_expanded),
              onOpenInternals: widget.onOpenInternals,
            ),
          ),
        ?widget.actions,
        ?widget.footer,
      ],
    );
  }
}

class _ProjectEmptyAssessment extends StatelessWidget {
  const _ProjectEmptyAssessment();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.messages.projectHealthEmptyTitle,
          style: tokens.typography.styles.body.bodyMedium.copyWith(
            color: ai.bodyText,
          ),
        ),
        SizedBox(height: tokens.spacing.step1),
        Text(
          context.messages.projectHealthEmptyBody,
          style: tokens.typography.styles.body.bodySmall.copyWith(
            color: ai.metaText,
          ),
        ),
      ],
    );
  }
}

class _ProjectHealthContext extends StatelessWidget {
  const _ProjectHealthContext({
    required this.record,
    required this.onViewBlocker,
  });

  final ProjectRecord record;
  final VoidCallback? onViewBlocker;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    final metrics = record.healthMetrics!;
    final confidence = metrics.confidence;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.messages.projectHealthSectionTitle,
                style: tokens.typography.styles.others.caption.copyWith(
                  color: ai.metaText,
                ),
              ),
            ),
            ProjectHealthBandTag(band: metrics.band),
          ],
        ),
        SizedBox(height: tokens.spacing.step2),
        Text(
          metrics.rationale,
          style: tokens.typography.styles.body.bodySmall.copyWith(
            color: ai.bodyText,
          ),
        ),
        if (confidence != null || record.blockedTaskCount > 0) ...[
          SizedBox(height: tokens.spacing.step2),
          Wrap(
            spacing: tokens.spacing.step4,
            runSpacing: tokens.spacing.step2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (confidence != null)
                Text(
                  context.messages.projectHealthConfidence(
                    (confidence * 100).round(),
                  ),
                  style: tokens.typography.styles.others.caption.copyWith(
                    color: ai.metaText,
                  ),
                ),
              if (record.blockedTaskCount > 0)
                InkWell(
                  onTap: onViewBlocker,
                  child: Text(
                    context.messages.projectShowcaseBlockedTaskCount(
                      record.blockedTaskCount,
                    ),
                    style: tokens.typography.styles.others.caption.copyWith(
                      color: onViewBlocker == null
                          ? ai.metaText
                          : tokens.colors.interactive.enabled,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ProjectAssignAgentRow extends StatelessWidget {
  const _ProjectAssignAgentRow({required this.onTap, required this.isBusy});

  final VoidCallback? onTap;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final radius = BorderRadius.circular(tokens.radii.l);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        borderRadius: radius,
        border: Border.all(color: tokens.colors.decorative.level01),
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: DesignSystemListItem(
          onTap: isBusy ? null : onTap,
          title: context.messages.taskFirstRunAssignAgent,
          titleMaxLines: 2,
          subtitle: context.messages.projectAgentNotProvisioned,
          subtitleMaxLines: 2,
          subtitleEmphasis: tokens.colors.text.lowEmphasis,
          size: DesignSystemListItemSize.small,
          leading: isBusy
              ? SizedBox.square(
                  dimension: tokens.spacing.step5,
                  child: const CircularProgressIndicator.adaptive(),
                )
              : Icon(
                  LottiIcons.aiSpark,
                  size: tokens.spacing.step5,
                  color: tokens.colors.aiCard.accent,
                ),
          trailingExtra: Icon(
            LottiIcons.chevronRight,
            size: tokens.spacing.step4,
            color: tokens.colors.text.lowEmphasis,
          ),
        ),
      ),
    );
  }
}
