import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_link.dart';
import 'package:meta/meta.dart';

/// A slot that shows at most one live link: a template's soul
/// (`soul_assignment`, keyed by the template in `fromId`) or a template's
/// improver (`improver_target`, keyed by the template in `toId`).
///
/// Each assignment is written under a fresh link id, so two devices that
/// reassign one slot concurrently leave two live links in it. Every replica
/// keeps both as they arrived and shows the one [AgentLinkSelection] ranks
/// first — newest `createdAt`, then the greater id — so all of them show the
/// same assignment whatever order the versions arrived in. A writer stamps a
/// new assignment's `createdAt` above every link of the slot it has seen, so
/// a reassignment outranks what it replaced (ADR 0099,
/// `specs/tla/AgentLinks.tla`).
@immutable
class AgentLinkSlot {
  const AgentLinkSlot._({
    required this.type,
    required this.keyId,
    required this.keyedByFromId,
  });

  /// The soul slot of the template [templateId].
  const AgentLinkSlot.soul(String templateId)
    : this._(
        type: AgentLinkTypes.soulAssignment,
        keyId: templateId,
        keyedByFromId: true,
      );

  /// The improver slot of the template [templateId].
  const AgentLinkSlot.improver(String templateId)
    : this._(
        type: AgentLinkTypes.improverTarget,
        keyId: templateId,
        keyedByFromId: false,
      );

  /// The slot [link] fills, or `null` when its type has no slot.
  static AgentLinkSlot? of(AgentLink link) => switch (link) {
    SoulAssignmentLink(:final fromId) => AgentLinkSlot.soul(fromId),
    ImproverTargetLink(:final toId) => AgentLinkSlot.improver(toId),
    _ => null,
  };

  /// The `agent_links.type` of the slot's links.
  final String type;

  /// The template the slot belongs to.
  final String keyId;

  /// Whether [keyId] is the links' `fromId` (soul) or their `toId` (improver).
  final bool keyedByFromId;

  @override
  bool operator ==(Object other) =>
      other is AgentLinkSlot &&
      other.type == type &&
      other.keyId == keyId &&
      other.keyedByFromId == keyedByFromId;

  @override
  int get hashCode => Object.hash(type, keyId, keyedByFromId);
}
