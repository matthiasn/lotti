import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';

/// Registration helpers for the Daily OS day-agent kind.
abstract final class DayAgentKind {
  /// Persisted identity discriminator for day-agent instances.
  static const String agentKind = AgentKinds.dayAgent;

  /// Template kind used by the shared template evolution machinery.
  static const AgentTemplateKind templateKind = AgentTemplateKind.dayAgent;

  /// Whether [identity] is a Daily OS day-agent instance.
  static bool matches(AgentIdentityEntity identity) =>
      identity.kind == agentKind;
}
