import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/change_set_providers.dart';
import 'package:lotti/features/agents/state/project_agent_providers.dart';
import 'package:lotti/features/agents/ui/agent_creation_modal.dart';
import 'package:lotti/features/agents/ui/agent_report_section.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/form/form_widgets.dart';

/// Renders project-agent context on the project detail page.
///
/// Shows the provisioned agent's display name, current report, and active
/// project recommendations that the user can resolve or dismiss.
class ProjectAgentReportCard extends ConsumerWidget {
  const ProjectAgentReportCard({
    required this.projectId,
    required this.projectTitle,
    this.categoryId,
    super.key,
  });

  final String projectId;
  final String projectTitle;
  final String? categoryId;

  Future<void> _createProjectAgent(BuildContext context, WidgetRef ref) async {
    try {
      final service = ref.read(projectAgentServiceProvider);
      final templateService = ref.read(agentTemplateServiceProvider);

      var templates = categoryId != null
          ? await templateService.listTemplatesForCategory(categoryId!)
          : <AgentTemplateEntity>[];
      if (templates.isEmpty) {
        templates = await templateService.listTemplates();
      }
      templates = templates
          .where((t) => t.kind == AgentTemplateKind.projectAgent)
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

      await service.createProjectAgent(
        projectId: projectId,
        templateId: result.templateId,
        displayName: projectTitle,
        allowedCategoryIds: categoryId == null ? const {} : {categoryId!},
        profileId: result.profileId,
      );

      ref
        ..invalidate(projectAgentProvider(projectId))
        ..invalidate(projectAgentSummaryProvider(projectId));
    } catch (e, s) {
      developer.log(
        'Failed to create project agent',
        name: 'ProjectAgentReportCard',
        error: e,
        stackTrace: s,
      );
      if (!context.mounted) return;
      context.showToast(
        tone: DesignSystemToastTone.error,
        title: context.messages.taskAgentCreateError(e.toString()),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agentAsync = ref.watch(projectAgentProvider(projectId));

    return agentAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (agent) {
        if (agent is! AgentIdentityEntity) {
          return LottiFormSection(
            title: context.messages.projectAgentSectionTitle,
            icon: Icons.smart_toy_outlined,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  context.messages.projectAgentNotProvisioned,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: ActionChip(
                  avatar: Icon(
                    Icons.add,
                    size: 16,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                  label: Text(context.messages.taskAgentCreateChipLabel),
                  onPressed: () => _createProjectAgent(context, ref),
                ),
              ),
            ],
          );
        }

        final reportAsync = ref.watch(agentReportProvider(agent.agentId));
        final report = reportAsync.value?.mapOrNull(agentReport: (r) => r);
        final isRunning =
            ref.watch(agentIsRunningProvider(agent.agentId)).value ?? false;
        final recommendations =
            ref
                .watch(projectRecommendationsProvider(projectId))
                .asData
                ?.value ??
            const <ProjectRecommendationEntity>[];
        final hasReport = report != null && report.content.trim().isNotEmpty;

        return LottiFormSection(
          title: context.messages.projectAgentSectionTitle,
          icon: Icons.smart_toy_outlined,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.smart_toy_outlined,
                    size: 20,
                    color: context.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      agent.displayName,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  if (isRunning)
                    Tooltip(
                      message: context.messages.agentRunningIndicator,
                      child: SizedBox(
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
                    )
                  else
                    IconButton(
                      icon: Icon(
                        Icons.refresh_rounded,
                        size: 20,
                        color: context.colorScheme.primary,
                      ),
                      tooltip: context.messages.taskAgentRunNowTooltip,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      onPressed: () {
                        ref
                            .read(projectAgentServiceProvider)
                            .triggerReanalysis(agent.agentId);
                      },
                    ),
                ],
              ),
            ),
            if (reportAsync.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (hasReport)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: AgentReportSection(
                  content: report.content,
                  tldr: report.tldr,
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  context.messages.agentReportNone,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            if (recommendations.isNotEmpty) ...[
              const Divider(height: 24),
              Text(
                context.messages.projectRecommendationsTitle,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              for (final recommendation in recommendations)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ProjectRecommendationTile(
                    recommendation: recommendation,
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _ProjectRecommendationTile extends ConsumerWidget {
  const _ProjectRecommendationTile({required this.recommendation});

  final ProjectRecommendationEntity recommendation;

  Future<void> _handleResolve(BuildContext context, WidgetRef ref) async {
    final success = await ref
        .read(projectRecommendationServiceProvider)
        .markResolved(recommendation.id);
    if (!success && context.mounted) {
      context.showToast(
        tone: DesignSystemToastTone.error,
        title: context.messages.projectRecommendationUpdateError,
      );
    }
  }

  Future<void> _handleDismiss(BuildContext context, WidgetRef ref) async {
    final success = await ref
        .read(projectRecommendationServiceProvider)
        .dismissRecommendation(recommendation.id);
    if (!success && context.mounted) {
      context.showToast(
        tone: DesignSystemToastTone.error,
        title: context.messages.projectRecommendationUpdateError,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.45,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  recommendation.title,
                  style: context.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (recommendation.priority case final priority?)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: context.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    priority,
                    style: context.textTheme.labelSmall?.copyWith(
                      color: context.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              IconButton(
                icon: Icon(
                  Icons.check_circle_outline_rounded,
                  color: context.colorScheme.primary,
                ),
                tooltip: context.messages.projectRecommendationResolveTooltip,
                visualDensity: VisualDensity.compact,
                onPressed: () => _handleResolve(context, ref),
              ),
              IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  color: context.colorScheme.onSurfaceVariant,
                ),
                tooltip: context.messages.projectRecommendationDismissTooltip,
                visualDensity: VisualDensity.compact,
                onPressed: () => _handleDismiss(context, ref),
              ),
            ],
          ),
          if (recommendation.rationale case final rationale?) ...[
            const SizedBox(height: 6),
            Text(
              rationale,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
