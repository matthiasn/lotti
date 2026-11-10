import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:lotti/features/agents/state/agent_chat_projection.dart';
import 'package:lotti/features/front_agent/model/front_closed_task_card.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_door.dart';
import 'package:lotti/features/front_agent/model/front_due_section.dart';
import 'package:lotti/features/front_agent/model/front_entity_preview.dart';
import 'package:lotti/features/front_agent/model/front_logged_time_chart.dart';
import 'package:lotti/features/front_agent/model/front_pull_requests.dart';
import 'package:lotti/features/front_agent/model/front_reply_layout.dart';

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
@immutable
class FrontChatThread {
  const FrontChatThread({
    required this.messages,
    this.optionsByMessageId = const {},
    this.doorsByMessageId = const {},
    this.specialistAgentIds = const {},
    this.loggedTimeByMessageId = const {},
    this.pullRequestsByMessageId = const {},
    this.closedTasksByMessageId = const {},
    this.entityPreviewsByMessageId = const {},
    this.dueSectionsByMessageId = const {},
    this.partsByMessageId = const {},
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

  /// The chart of logged time a reply draws under her words, by the
  /// reply's id.
  final Map<String, FrontLoggedTimeChart> loggedTimeByMessageId;

  /// The charts of pull requests a reply draws under her words, by the
  /// reply's id.
  final Map<String, FrontPullRequestChart> pullRequestsByMessageId;

  /// The tasks a reply about what was completed or rejected draws as cards
  /// under her words, by the reply's id.
  final Map<String, List<FrontClosedTaskCard>> closedTasksByMessageId;

  /// The entities a reply draws as preview cards under her words, by the
  /// reply's id: what the doors it carries made — a task or an event made
  /// of a segment, the day a change to today was planned on — in segment
  /// order. Only which they are; each card reads its entity as
  /// it is now.
  final Map<String, List<FrontEntityReference>> entityPreviewsByMessageId;

  /// The window a reply's list of due tasks was read from, by the reply's
  /// id: the quiet label over that list.
  final Map<String, FrontDueSection> dueSectionsByMessageId;

  /// What a reply draws, in order, by the reply's id: her words, the cards
  /// she listed, and where the charts and closed-task cards go, as the turn
  /// validated them. Only replies stored with parts; read through
  /// [partsOf]. Never read from how her words are formatted.
  final Map<String, List<FrontReplyPart>> partsByMessageId;

  /// What reply [messageId] draws, in order: the parts its turn stored —
  /// or, for a reply stored before replies had parts, her words, then what
  /// it carries in the order of [FrontReplyAttachment].
  List<FrontReplyPart> partsOf(String messageId) {
    if (partsByMessageId[messageId] case final parts?) return parts;
    final text = messages.firstWhereOrNull((m) => m.id == messageId)?.text;
    final carried = {
      FrontReplyAttachment.closedTasks: closedTasksByMessageId,
      FrontReplyAttachment.loggedTimeChart: loggedTimeByMessageId,
      FrontReplyAttachment.pullRequestChart: pullRequestsByMessageId,
    };
    return [
      if (text != null && text.isNotEmpty) FrontReplyText(text),
      for (final attachment in FrontReplyAttachment.values)
        if (carried[attachment]!.containsKey(messageId))
          FrontReplyShow(attachment),
    ];
  }

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

  /// How many doors wait on the user, across the thread.
  int get inboxCount => [
    for (final doors in doorsByMessageId.values)
      for (final door in doors)
        if (door.awaitsUser) door,
  ].length;
}
