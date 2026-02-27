import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/agents/ui/agent_report_section.dart';

/// Displays the agent report for a task, if one exists.
///
/// Watches [taskAgentProvider] to find the agent associated with [taskId],
/// then watches [agentReportProvider] to fetch and display the report using
/// [AgentReportSection] (expandable TLDR).
///
/// Renders nothing when the task has no agent or no report.
class TaskAgentReportSection extends ConsumerWidget {
  const TaskAgentReportSection({
    required this.taskId,
    super.key,
  });

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agentAsync = ref.watch(taskAgentProvider(taskId));
    final agent = agentAsync.value?.mapOrNull(agent: (a) => a);

    if (agent == null) return const SizedBox.shrink();

    final reportAsync = ref.watch(agentReportProvider(agent.agentId));
    final report = reportAsync.value?.mapOrNull(agentReport: (r) => r);

    if (report == null || report.content.isEmpty) {
      return const SizedBox.shrink();
    }

    return AgentReportSection(content: report.content);
  }
}
