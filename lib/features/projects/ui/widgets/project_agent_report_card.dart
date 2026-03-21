import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/project_accepted_recommendation.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/change_set_providers.dart';
import 'package:lotti/features/agents/state/project_agent_providers.dart';
import 'package:lotti/features/agents/ui/agent_report_section.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/form/form_widgets.dart';

/// Renders project-agent context on the project detail page.
///
/// Shows the provisioned agent's display name, latest report, and any
/// accepted `recommend_next_steps` decisions that have been confirmed by the
/// user.
class ProjectAgentReportCard extends ConsumerWidget {
  const ProjectAgentReportCard({
    required this.projectId,
    super.key,
  });

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agentAsync = ref.watch(projectAgentProvider(projectId));
    final acceptedRecommendations =
        ref
            .watch(projectAcceptedRecommendationsProvider(projectId))
            .asData
            ?.value ??
        const [];

    return agentAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (agent) {
        if (agent is! AgentIdentityEntity) return const SizedBox.shrink();
        final report = ref
            .watch(agentReportProvider(agent.agentId))
            .value
            ?.mapOrNull(agentReport: (report) => report);

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
                ],
              ),
            ),
            if (report != null &&
                (report.content.trim().isNotEmpty ||
                    (report.tldr?.trim().isNotEmpty ?? false))) ...[
              const SizedBox(height: 4),
              AgentReportSection(content: report.content, tldr: report.tldr),
            ],
            if (acceptedRecommendations.isNotEmpty) ...[
              const Divider(height: 24),
              Text(
                context.messages.projectAcceptedNextStepsTitle,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              for (final recommendation in acceptedRecommendations)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _AcceptedRecommendationTile(
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

class _AcceptedRecommendationTile extends StatelessWidget {
  const _AcceptedRecommendationTile({required this.recommendation});

  final ProjectAcceptedRecommendation recommendation;

  @override
  Widget build(BuildContext context) {
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
              if (_localizedPriority(context, recommendation.priority)
                  case final label?)
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
                    label,
                    style: context.textTheme.labelSmall?.copyWith(
                      color: context.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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

  static String? _localizedPriority(BuildContext context, String? raw) {
    if (raw == null) return null;
    return switch (raw.toUpperCase()) {
      'CRITICAL' => context.messages.projectPriorityCritical,
      'HIGH' => context.messages.projectPriorityHigh,
      'MEDIUM' => context.messages.projectPriorityMedium,
      'LOW' => context.messages.projectPriorityLow,
      _ => raw,
    };
  }
}
