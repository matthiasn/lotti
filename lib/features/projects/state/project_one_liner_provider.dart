import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/project_agent_providers.dart';

/// Fetches the AI-generated one-liner subtitle for a project from its agent
/// report.
///
/// Chains `projectAgentProvider` to resolve the project's agent, then watches
/// `agentReportProvider` for the latest report and extracts the `oneLiner`
/// field. Auto-disposes when the project card scrolls off-screen.
final FutureProviderFamily<String?, String> projectOneLinerProvider =
    FutureProvider.autoDispose.family<String?, String>(
      projectOneLiner,
      name: 'projectOneLinerProvider',
    );
Future<String?> projectOneLiner(Ref ref, String projectId) async {
  final agentEntity = await ref.watch(
    projectAgentProvider(projectId).future,
  );
  final identity = agentEntity?.mapOrNull(agent: (agent) => agent);
  if (identity == null) return null;

  final reportEntity = await ref.watch(
    agentReportProvider(identity.agentId).future,
  );
  final report = reportEntity?.mapOrNull(agentReport: (r) => r);
  final oneLiner = report?.oneLiner?.trim();
  if (oneLiner != null && oneLiner.isNotEmpty) {
    return oneLiner;
  }
  return null;
}
