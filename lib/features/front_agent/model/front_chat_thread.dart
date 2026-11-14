import 'package:flutter/foundation.dart';
import 'package:lotti/features/agents/state/agent_chat_projection.dart';
import 'package:lotti/features/front_agent/model/front_cited_answer.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_door.dart';
import 'package:lotti/features/front_agent/model/front_entity_preview.dart';
import 'package:lotti/features/front_agent/model/front_reply_surface.dart';

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
  const FrontDoorEntry({
    required this.doorId,
    required this.record,
    this.specialistReply,
  });

  /// The door record's message id — what an action on the door is keyed to.
  final String doorId;

  final FrontDoorRecord record;

  /// Whether the user still has to act on this door.
  bool get awaitsUser => frontDoorAwaitsUser(record.outcome);

  /// The specialist's reply text, mirrored by the turn it answers; null
  /// while the specialist is still replying, or for any other outcome.
  final String? specialistReply;
}

/// The front thread as the chat surface renders it: the visible messages in
/// order, and what hangs off each one — the options of a clarifying
/// question, the doors of a routed turn.
/// The id of the surface the journal answer of door [doorId] is drawn on.
String frontDoorAnswerSurfaceId(String doorId) => 'answer:$doorId';

@immutable
class FrontChatThread {
  const FrontChatThread({
    required this.messages,
    this.optionsByMessageId = const {},
    this.doorsByMessageId = const {},
    this.specialistAgentIds = const {},
    this.entityPreviewsByMessageId = const {},
    this.surfacesByMessageId = const {},
    this.runKeys = const {},
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

  /// The A2UI surface each reply is drawn as, by the reply's id: her
  /// words, the cards she listed, and the charts and closed-task cards a
  /// lookup made, with their data. A reply stored before replies had
  /// surfaces gets one made of her words and what it carried.
  final Map<String, FrontReplySurface> surfacesByMessageId;

  /// The entities a reply draws as preview cards under her words, by the
  /// reply's id: what the doors it carries made — a task or an event made
  /// of a segment, the day a change to today was planned on — in segment
  /// order. Only which they are; each card reads its entity as
  /// it is now.
  final Map<String, List<FrontEntityReference>> entityPreviewsByMessageId;

  /// The run of every reply and question of hers in the conversation, the
  /// ones older than [messages] keeps too: what the conversation has cost
  /// is summed over all of them, so it never shrinks as the window moves.
  final Set<String> runKeys;

  /// The message that carries a user turn's doors on the surface: her
  /// reply right after it, when there is one — the doors are her answer,
  /// part by part, under her own line — else the user turn itself, while
  /// she is still walking them or when no reply followed.
  String carrierOf(String userMessageId) {
    final index = messages.indexWhere((m) => m.id == userMessageId);
    if (index < 0 || index + 1 >= messages.length) return userMessageId;
    final next = messages[index + 1];
    return next.role == AgentChatRole.agent ? next.id : userMessageId;
  }

  /// The doors [messageId] carries on the surface, if any.
  List<FrontDoorEntry>? doorsCarriedBy(String messageId) {
    for (final entry in doorsByMessageId.entries) {
      if (carrierOf(entry.key) == messageId) return entry.value;
    }
    return null;
  }

  /// The turns with a door still waiting on the user, and the replies that
  /// carry those doors — the inbox is the thread filtered to these
  /// (decision 7).
  Set<String> get inboxMessageIds => {
    for (final entry in doorsByMessageId.entries)
      if (entry.value.any((door) => door.awaitsUser)) ...{
        entry.key,
        carrierOf(entry.key),
      },
  };

  /// Every surface the thread draws: [surfacesByMessageId], and the one a
  /// journal answer's door draws its points on, by
  /// [frontDoorAnswerSurfaceId]. The app composes the latter from the
  /// answer's verified evidence; the door card decides whether it shows.
  Map<String, FrontReplySurface> get surfaces => {
    ...surfacesByMessageId,
    for (final doors in doorsByMessageId.values)
      for (final door in doors)
        if (door.record.outcome case final FrontDoorAnswer answer
            when answer.fromJournal)
          if (FrontCitedPoint.fromAnswer(answer.text, answer.evidence)
              case final points when points.isNotEmpty)
            frontDoorAnswerSurfaceId(
              door.doorId,
            ): FrontReplySurface.citedAnswer(
              surfaceId: frontDoorAnswerSurfaceId(door.doorId),
              points: points,
            ),
  };

  /// How many doors wait on the user, across the thread.
  int get inboxCount => [
    for (final doors in doorsByMessageId.values)
      for (final door in doors)
        if (door.awaitsUser) door,
  ].length;
}
