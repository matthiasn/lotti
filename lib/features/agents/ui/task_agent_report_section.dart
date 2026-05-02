import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/agents/ui/agent_creation_modal.dart';
import 'package:lotti/features/agents/ui/agent_detail_page.dart';
import 'package:lotti/features/agents/ui/agent_report_section.dart';
import 'package:lotti/features/agents/ui/wake_countdown_state.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/projects/ui/widgets/shared_widgets.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/consts.dart';

/// Displays the agent section for a task: create CTA, running controls,
/// and report content.
///
/// - When agents are disabled via config flag: renders nothing.
/// - When no agent exists for the task: shows an "Assign Agent" CTA.
/// - When an agent exists: shows a header row with running indicator,
///   play button, countdown timer, template name, and navigation chevron.
///   Below the header, displays the agent report if one exists.
class TaskAgentReportSection extends ConsumerStatefulWidget {
  const TaskAgentReportSection({
    required this.taskId,
    super.key,
  });

  final String taskId;

  @override
  ConsumerState<TaskAgentReportSection> createState() =>
      _TaskAgentReportSectionState();
}

class _TaskAgentReportSectionState
    extends ConsumerState<TaskAgentReportSection> {
  /// Guards against re-seeding the countdown after a manual cancel.
  /// Reset when the provider propagates the cleared `nextWakeAt`.
  bool _cancelledManually = false;

  int _computeRemainingSeconds(DateTime? nextWakeAt) {
    if (nextWakeAt == null) return 0;
    final remaining = nextWakeAt.difference(clock.now());
    return remaining.inSeconds.clamp(
      0,
      WakeOrchestrator.throttleWindow.inSeconds,
    );
  }

  @override
  Widget build(BuildContext context) {
    final enableAgents =
        ref.watch(configFlagProvider(enableAgentsFlag)).value ?? false;

    if (!enableAgents) {
      return const SizedBox.shrink();
    }

    final taskAgentAsync = ref.watch(taskAgentProvider(widget.taskId));

    return taskAgentAsync.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: SizedBox.shrink,
      error: (_, _) => const SizedBox.shrink(),
      data: (agentEntity) {
        if (agentEntity == null) {
          return _buildCreateAgentRow(context);
        }
        final identity = agentEntity.mapOrNull(agent: (e) => e);
        if (identity == null) return const SizedBox.shrink();
        return _buildAgentSection(context, identity);
      },
    );
  }

  Widget _buildCreateAgentRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppTheme.spacingSmall),
      child: Center(
        child: DesignSystemButton(
          label: context.messages.taskAgentCreateChipLabel,
          variant: DesignSystemButtonVariant.secondary,
          size: DesignSystemButtonSize.medium,
          leadingIcon: Icons.auto_awesome_rounded,
          onPressed: () => _createTaskAgent(context, ref),
        ),
      ),
    );
  }

  Widget _buildAgentSection(
    BuildContext context,
    AgentIdentityEntity identity,
  ) {
    final agentId = identity.agentId;
    final reportAsync = ref.watch(agentReportProvider(agentId));
    final report = reportAsync.value?.mapOrNull(agentReport: (r) => r);
    final templateAsync = ref.watch(templateForAgentProvider(agentId));
    final template = templateAsync.value?.mapOrNull(agentTemplate: (t) => t);

    final hasReport = report != null && report.content.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAgentHeader(context, identity, template),
        if (hasReport)
          AgentReportSection(content: report.content, tldr: report.tldr),
      ],
    );
  }

  Widget _buildAgentHeader(
    BuildContext context,
    AgentIdentityEntity identity,
    AgentTemplateEntity? template,
  ) {
    final agentId = identity.agentId;
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

    return Padding(
      padding: const EdgeInsets.only(
        left: AppTheme.cardPadding,
        right: AppTheme.spacingSmall,
        top: AppTheme.spacingSmall,
        bottom: AppTheme.spacingXSmall,
      ),
      child: SizedBox(
        height: 32,
        child: Row(
          children: [
            // Agent icon — always stable on the left
            Padding(
              padding: const EdgeInsets.only(right: AppTheme.spacingSmall),
              child: GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AgentDetailPage(agentId: agentId),
                  ),
                ),
                child: Icon(
                  Icons.smart_toy_outlined,
                  size: 18,
                  color: context.colorScheme.primary,
                ),
              ),
            ),
            // Title with template name — tapping navigates to agent instance
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AgentDetailPage(agentId: agentId),
                  ),
                ),
                child: Text(
                  template != null
                      ? '${context.messages.agentReportSectionTitle}'
                            ' — ${template.displayName}'
                      : context.messages.agentReportSectionTitle,
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            // Running spinner — same box as IconButton to prevent layout jump
            if (isRunning)
              SizedBox(
                width: 32,
                height: 32,
                child: Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.colorScheme.primary,
                    ),
                  ),
                ),
              ),
            // Refresh button — shown when idle with no countdown
            if (!isRunning && !showCountdown)
              IconButton(
                icon: Icon(
                  Icons.refresh_rounded,
                  size: 20,
                  color: context.colorScheme.primary,
                ),
                tooltip: context.messages.taskAgentRunNowTooltip,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () {
                  ref.read(taskAgentServiceProvider).triggerReanalysis(agentId);
                },
              ),
            // During countdown: run-now button + pill + cancel
            if (showCountdown) ...[
              IconButton(
                icon: Icon(
                  Icons.play_arrow_rounded,
                  size: 20,
                  color: context.colorScheme.primary,
                ),
                tooltip: context.messages.taskAgentRunNowTooltip,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () {
                  ref.read(taskAgentServiceProvider).triggerReanalysis(agentId);
                },
              ),
              _CountdownPill(
                nextWakeAt: nextWakeAt!,
                onExpired: () {
                  if (mounted) {
                    setState(() {});
                  }
                },
              ),
              IconButton(
                icon: Icon(
                  Icons.close,
                  size: 18,
                  color: context.colorScheme.onSurfaceVariant,
                ),
                tooltip: context.messages.taskAgentCancelTimerTooltip,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: () {
                  ref
                      .read(taskAgentServiceProvider)
                      .cancelScheduledWake(agentId);
                  _cancelledManually = true;
                  setState(() {});
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _createTaskAgent(BuildContext context, WidgetRef ref) async {
    final entryStateResult = await ref.read(
      entryControllerProvider(id: widget.taskId).future,
    );
    final entryState = entryStateResult?.entry;
    if (entryState == null || entryState is! Task) return;

    final categoryId = entryState.meta.categoryId;
    final allowedCategoryIds = categoryId != null ? {categoryId} : <String>{};

    try {
      final service = ref.read(taskAgentServiceProvider);
      final templateService = ref.read(agentTemplateServiceProvider);

      // Try category-specific templates first, then all templates.
      // Only show Task Agent templates — Template Improver agents are
      // not assignable to tasks.
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
        taskId: widget.taskId,
        templateId: result.templateId,
        profileId: result.profileId,
        allowedCategoryIds: allowedCategoryIds,
      );
      if (context.mounted) {
        ref.invalidate(taskAgentProvider(widget.taskId));
      }
    } catch (e, s) {
      developer.log(
        'Failed to create task agent',
        name: 'TaskAgentReportSection',
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
}

/// Fixed-width pill that displays the agent wake countdown timer.
class _CountdownPill extends StatefulWidget {
  const _CountdownPill({
    required this.nextWakeAt,
    required this.onExpired,
  });

  final DateTime nextWakeAt;
  final VoidCallback onExpired;

  static const double _pillWidth = 52;

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
    if (countdownSeconds <= 0) {
      return const SizedBox.shrink();
    }

    final countdownText = formatCountdown(countdownSeconds);

    return Container(
      width: _CountdownPill._pillWidth,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        countdownText,
        textAlign: TextAlign.center,
        style: context.textTheme.bodySmall?.copyWith(
          fontFeatures: [const FontFeature.tabularFigures()],
          fontWeight: FontWeight.w600,
          color: context.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
