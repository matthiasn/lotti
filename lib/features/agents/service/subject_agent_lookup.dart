import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/service/agent_service.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';

/// The agent↔subject link types, in resolution order.
///
/// A "subject" is the journal-domain entity an agent is *about* — the thing a
/// recording, an image or a transcript can be attached to. One id only ever
/// carries one of these link types (a task is never also a relationship), so
/// the order is a deterministic tiebreak for corrupt data rather than a
/// precedence rule anyone should depend on.
///
/// Deliberately excludes [AgentLinkTypes.agentDay]: a day agent's subject is a
/// date key, not an entity that can own a linked recording, and admitting it
/// here would let a date string resolve an agent for an entry that has none.
const subjectAgentLinkTypes = <String>[
  AgentLinkTypes.agentTask,
  AgentLinkTypes.agentProject,
  AgentLinkTypes.agentEvent,
  AgentLinkTypes.agentRelationship,
  // A goal's subject is its mirrored journal entry — the thing a check-in
  // recording is linked to. Leaving it out made every goal-linked recording
  // resolve to "no agent" on the recorder's stop path, so the goal agent's
  // consent switch was never even consulted.
  AgentLinkTypes.agentGoal,
];

/// Resolves "which agent is about this entity" for any subject kind.
typedef SubjectAgentLookup =
    Future<AgentIdentityEntity?> Function(String subjectId);

/// Kind-agnostic counterpart to `TaskAgentService.getTaskAgentForTask`.
///
/// Automated capabilities — transcription, image analysis, the post-work wake
/// — are properties of *an entity that has an agent*, not of tasks. Resolving
/// through the task-typed lookup silently declines for every other subject
/// kind, which is how a spoken check-in on a relationship would transcribe
/// with no profile and wake nothing.
class SubjectAgentResolver {
  const SubjectAgentResolver(this._repository, this._agentService);

  final AgentRepository _repository;
  final AgentService _agentService;

  /// The agent linked to [subjectId], or `null` when the entity has none.
  ///
  /// Walks [subjectAgentLinkTypes] and stops at the first type that has a
  /// link, resolving the identity from the winning link's `fromId`
  /// ([AgentLinkSelection.selectPrimary] breaks multi-link ties the same way
  /// the task path does). A link that points at a destroyed or missing agent
  /// resolves to `null` rather than falling through to the next type — the
  /// entity *has* an agent, it just isn't loadable, and treating that as "try
  /// the other kinds" would attach a foreign agent to it.
  Future<AgentIdentityEntity?> call(String subjectId) async {
    for (final type in subjectAgentLinkTypes) {
      final links = await _repository.getLinksTo(subjectId, type: type);
      if (links.isEmpty) continue;
      return _agentService.getAgent(links.selectPrimary().fromId);
    }
    return null;
  }
}

final subjectAgentResolverProvider = Provider<SubjectAgentResolver>(
  subjectAgentResolver,
  name: 'subjectAgentResolverProvider',
);
SubjectAgentResolver subjectAgentResolver(Ref ref) => SubjectAgentResolver(
  ref.watch(agentRepositoryProvider),
  ref.watch(agentServiceProvider),
);
