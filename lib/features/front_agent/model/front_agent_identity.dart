import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';

/// The one front agent per user, under a fixed id so every device creates
/// and addresses the same row (the `daily_os_planner` convergence rule).
const frontAgentId = 'front_agent';

/// The front agent behind [identity] if a turn can actually be sent to it,
/// else null: only an ACTIVE `front_agent` takes a message, the way
/// `usableRelationshipAgent` gates the person chat.
AgentIdentityEntity? usableFrontAgent(AgentDomainEntity? identity) =>
    identity is AgentIdentityEntity &&
        identity.kind == AgentKinds.frontAgent &&
        identity.lifecycle == AgentLifecycle.active
    ? identity
    : null;
