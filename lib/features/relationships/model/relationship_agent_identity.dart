import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';

/// The relationship agent behind [identity] if the chat can actually open
/// it, else null.
///
/// Destroying an agent deliberately preserves its identity row for audit and
/// pausing keeps it whole, so "a row exists" is not "there is an agent to
/// talk to": `RelationshipChatPane` shows its unavailable state for anything
/// but an ACTIVE `relationship_agent`. Every affordance that leads there — the
/// person hero's *Talk to agent*, the pane's own header — asks this one
/// question, so a button can never promise a chat the pane then refuses.
AgentIdentityEntity? usableRelationshipAgent(AgentDomainEntity? identity) =>
    identity is AgentIdentityEntity &&
        identity.kind == AgentKinds.relationshipAgent &&
        identity.lifecycle == AgentLifecycle.active
    ? identity
    : null;
