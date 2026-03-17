import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/project_agent_providers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/form/form_widgets.dart';

/// Renders the project agent identity card, showing the agent's display
/// name when a project agent has been provisioned.
class ProjectAgentReportCard extends ConsumerWidget {
  const ProjectAgentReportCard({
    required this.projectId,
    super.key,
  });

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agentAsync = ref.watch(projectAgentProvider(projectId));

    return agentAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (agent) {
        if (agent is! AgentIdentityEntity) return const SizedBox.shrink();

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
          ],
        );
      },
    );
  }
}
