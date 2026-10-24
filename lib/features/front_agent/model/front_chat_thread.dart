import 'package:flutter/foundation.dart';
import 'package:lotti/features/agents/state/agent_chat_projection.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_door.dart';

/// One choice the front agent offered with a clarifying question: an owner
/// the segment could belong to, by kind and id, labelled as the model
/// labelled it.
@immutable
class FrontAskOption {
  const FrontAskOption({
    required this.kind,
    required this.id,
    required this.label,
  });

  final FrontDestinationKind kind;
  final String id;
  final String label;

  /// Reads an option the ask record stored; null for a shape this build
  /// does not know.
  static FrontAskOption? fromJson(Object? json) {
    if (json is! Map) return null;
    final kind = FrontDestinationKind.fromWireName(json['kind']);
    final id = json['id'];
    final label = json['label'];
    if (kind == null || id is! String || label is! String) return null;
    return FrontAskOption(kind: kind, id: id, label: label);
  }
}

/// A walked door as the thread shows it: the record, and — for a segment a
/// goal or person agent took as its own turn — that agent's reply once it
/// has landed in the agent's thread.
@immutable
class FrontDoorEntry {
  const FrontDoorEntry({required this.record, this.specialistReply});

  final FrontDoorRecord record;

  /// The specialist's reply text, mirrored by the turn it answers; null
  /// while the specialist is still replying, or for any other outcome.
  final String? specialistReply;
}

/// The front thread as the chat surface renders it: the visible messages in
/// order, and what hangs off each one — the options of a clarifying
/// question, the doors of a routed turn.
@immutable
class FrontChatThread {
  const FrontChatThread({
    required this.messages,
    this.optionsByMessageId = const {},
    this.doorsByMessageId = const {},
    this.specialistAgentIds = const {},
  });

  static const empty = FrontChatThread(messages: []);

  /// The user's turns, the front agent's replies and its questions, oldest
  /// first.
  final List<AgentChatMessage> messages;

  /// The choices a clarifying question offered, by that question's id.
  final Map<String, List<FrontAskOption>> optionsByMessageId;

  /// The doors a turn's dispatch walked, by the user turn's id, in segment
  /// order.
  final Map<String, List<FrontDoorEntry>> doorsByMessageId;

  /// Every goal or person agent a door handed a turn to: their replies land
  /// in their own threads, so the surface refreshes when one of them
  /// finishes a wake.
  final Set<String> specialistAgentIds;
}
