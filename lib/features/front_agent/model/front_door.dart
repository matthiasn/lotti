import 'package:lotti/features/front_agent/model/front_dispatch.dart';

/// The tool name under which a walked door is recorded in the front
/// thread: an `action` row per dispatch segment, keyed to the dispatch, so
/// a second walker — a retry, another device — finds the claim and moves on.
const String frontDoorToolName = 'front_door';

/// How long a claim stands before another walker may take the segment
/// over: a door that has not finished in this time belongs to a walker
/// that died.
const Duration frontDoorClaimGrace = Duration(minutes: 30);

/// The deterministic id of segment [index]'s door record under the dispatch
/// record [dispatchMessageId] — the idempotency key the plan names.
String frontDoorRecordId(String dispatchMessageId, int index) =>
    '$dispatchMessageId:door:$index';

/// Where a walked segment ended up.
enum FrontDoorStatus {
  /// A walker holds the segment; the door is being walked.
  claimed,

  /// The door was walked and its outcome recorded.
  done;

  static FrontDoorStatus? fromName(Object? name) =>
      values.where((v) => v.name == name).firstOrNull;
}

/// Why a segment was not walked through a door.
enum FrontDoorSkipReason {
  /// The owner has no agent to take the turn (a task without one, a
  /// retired goal or person agent).
  noAgent,

  /// The owner's inference setup resolves to nothing.
  inferenceUnavailable,

  /// The segment is about today's plan — the Daily OS door comes with a
  /// later slice.
  noDoor;

  static FrontDoorSkipReason? fromName(Object? name) =>
      values.where((v) => v.name == name).firstOrNull;
}

/// What a door produced.
sealed class FrontDoorOutcome {
  const FrontDoorOutcome();

  Map<String, Object?> toJson();

  /// Reads an outcome a record stored; null for a shape this build does
  /// not know, so an old record degrades to "no outcome" rather than a
  /// crash.
  static FrontDoorOutcome? fromJson(Object? json) {
    if (json is! Map) return null;
    final map = Map<String, Object?>.from(json);
    switch (map['type']) {
      case 'answer':
        final text = map['text'];
        if (text is! String) return null;
        final owners = map['ownerIds'];
        return FrontDoorAnswer(
          text: text,
          summaryBased: map['summaryBased'] == true,
          incomplete: map['incomplete'] == true,
          ownerIds: [
            if (owners is List)
              for (final id in owners)
                if (id is String) id,
          ],
        );
      case 'chat':
        final agentId = map['specialistAgentId'];
        final messageId = map['specialistMessageId'];
        if (agentId is! String || messageId is! String) return null;
        return FrontDoorChatTurn(
          specialistAgentId: agentId,
          specialistMessageId: messageId,
        );
      case 'skipped':
        final reason = FrontDoorSkipReason.fromName(map['reason']);
        return reason == null ? null : FrontDoorSkipped(reason);
      case 'failed':
        final error = map['errorType'];
        return FrontDoorFailed(error is String ? error : 'unknown');
      case 'proposal':
        final ownerId = map['ownerId'];
        if (ownerId is! String) return null;
        return FrontDoorProposal(
          ownerId: ownerId,
          unfiled: map['unfiled'] == true,
        );
      case 'filed':
        final entryId = map['entryId'];
        if (entryId is! String) return null;
        final ownerId = map['ownerId'];
        return FrontDoorFiled(
          entryId: entryId,
          ownerId: ownerId is String ? ownerId : null,
        );
      case 'declined':
        return const FrontDoorDeclined();
      case 'inbox':
        return FrontDoorInbox(newKind: FrontNewKind.fromName(map['newKind']));
      case 'taskCreated':
        final taskId = map['taskId'];
        return taskId is String ? FrontDoorTaskCreated(taskId: taskId) : null;
      default:
        return null;
    }
  }
}

/// A statement or instruction under a task, waiting for the user's one tap
/// before anything is written (decision 1). [unfiled] when it had been
/// filed and the user took the entry back out.
class FrontDoorProposal extends FrontDoorOutcome {
  const FrontDoorProposal({required this.ownerId, this.unfiled = false});

  final String ownerId;
  final bool unfiled;

  @override
  Map<String, Object?> toJson() => {
    'type': 'proposal',
    'ownerId': ownerId,
    if (unfiled) 'unfiled': true,
  };
}

/// The user's words were written as a text entry: under [ownerId] when it
/// was filed under a task, on their own when saved as a note.
class FrontDoorFiled extends FrontDoorOutcome {
  const FrontDoorFiled({required this.entryId, this.ownerId});

  final String entryId;
  final String? ownerId;

  @override
  Map<String, Object?> toJson() => {
    'type': 'filed',
    'entryId': entryId,
    if (ownerId != null) 'ownerId': ownerId,
  };
}

/// The user said not to file this. Nothing was written.
class FrontDoorDeclined extends FrontDoorOutcome {
  const FrontDoorDeclined();

  @override
  Map<String, Object?> toJson() => const {'type': 'declined'};
}

/// Nothing owns this yet: the segment waits in the inbox with the chips
/// that make it a task, start a goal or project, or save it as a note.
/// [newKind] is what the router thought it would become, if anything.
class FrontDoorInbox extends FrontDoorOutcome {
  const FrontDoorInbox({this.newKind});

  final FrontNewKind? newKind;

  @override
  Map<String, Object?> toJson() => {
    'type': 'inbox',
    if (newKind != null) 'newKind': newKind!.name,
  };
}

/// The user made a task of the segment; its title is the user's words.
class FrontDoorTaskCreated extends FrontDoorOutcome {
  const FrontDoorTaskCreated({required this.taskId});

  final String taskId;

  @override
  Map<String, Object?> toJson() => {'type': 'taskCreated', 'taskId': taskId};
}

/// Whether the user still has to act on this door: a proposal waiting for
/// its tap, or an inbox item nobody has taken anywhere.
bool frontDoorAwaitsUser(FrontDoorOutcome? outcome) =>
    outcome is FrontDoorProposal || outcome is FrontDoorInbox;

/// The query pipeline answered a task or project question; the text is
/// shown in the front thread, attributed to its owner.
class FrontDoorAnswer extends FrontDoorOutcome {
  const FrontDoorAnswer({
    required this.text,
    required this.summaryBased,
    required this.incomplete,
    this.ownerIds = const [],
  });

  final String text;
  final bool summaryBased;
  final bool incomplete;
  final List<String> ownerIds;

  @override
  Map<String, Object?> toJson() => {
    'type': 'answer',
    'text': text,
    'summaryBased': summaryBased,
    'incomplete': incomplete,
    'ownerIds': ownerIds,
  };
}

/// A goal or person agent received the segment as its own chat turn; its
/// reply arrives in that agent's thread under this message id.
class FrontDoorChatTurn extends FrontDoorOutcome {
  const FrontDoorChatTurn({
    required this.specialistAgentId,
    required this.specialistMessageId,
  });

  final String specialistAgentId;
  final String specialistMessageId;

  @override
  Map<String, Object?> toJson() => {
    'type': 'chat',
    'specialistAgentId': specialistAgentId,
    'specialistMessageId': specialistMessageId,
  };
}

/// The segment has no door in this slice, or its owner cannot take it.
class FrontDoorSkipped extends FrontDoorOutcome {
  const FrontDoorSkipped(this.reason);

  final FrontDoorSkipReason reason;

  @override
  Map<String, Object?> toJson() => {'type': 'skipped', 'reason': reason.name};
}

/// The door threw; [errorType] is the exception's type, never its text.
class FrontDoorFailed extends FrontDoorOutcome {
  const FrontDoorFailed(this.errorType);

  final String errorType;

  @override
  Map<String, Object?> toJson() => {'type': 'failed', 'errorType': errorType};
}

/// One walked (or claimed) segment, as its record's payload stores it.
class FrontDoorRecord {
  const FrontDoorRecord({
    required this.segmentIndex,
    required this.text,
    required this.kind,
    required this.status,
    required this.claimedAt,
    this.destinationId,
    this.ownerTitle,
    this.outcome,
  });

  final int segmentIndex;

  /// The segment's verbatim span of the user's words.
  final String text;
  final FrontDestinationKind kind;
  final String? destinationId;

  /// The owner's title at the time of walking — a task's title, a goal's
  /// statement, a person's name — so the thread can say where a segment
  /// went without a lookup.
  final String? ownerTitle;
  final FrontDoorStatus status;
  final DateTime claimedAt;
  final FrontDoorOutcome? outcome;

  /// Whether another walker may take this segment: never when done, and
  /// only after [frontDoorClaimGrace] when claimed.
  bool isStaleClaimAt(DateTime now) =>
      status == FrontDoorStatus.claimed &&
      now.difference(claimedAt) >= frontDoorClaimGrace;

  FrontDoorRecord done(FrontDoorOutcome outcome) => FrontDoorRecord(
    segmentIndex: segmentIndex,
    text: text,
    kind: kind,
    destinationId: destinationId,
    ownerTitle: ownerTitle,
    status: FrontDoorStatus.done,
    claimedAt: claimedAt,
    outcome: outcome,
  );

  Map<String, Object?> toJson() => {
    'segmentIndex': segmentIndex,
    'text': text,
    'kind': kind.wireName,
    if (destinationId != null) 'destinationId': destinationId,
    if (ownerTitle != null) 'ownerTitle': ownerTitle,
    'status': status.name,
    'claimedAt': claimedAt.toUtc().toIso8601String(),
    if (outcome != null) 'outcome': outcome!.toJson(),
  };

  /// Reads a stored record; null when it is not one this build wrote.
  static FrontDoorRecord? fromJson(Map<String, Object?> json) {
    final index = json['segmentIndex'];
    final text = json['text'];
    final kind = FrontDestinationKind.fromWireName(json['kind']);
    final status = FrontDoorStatus.fromName(json['status']);
    final claimedAt = switch (json['claimedAt']) {
      final String iso => DateTime.tryParse(iso),
      _ => null,
    };
    if (index is! int ||
        text is! String ||
        kind == null ||
        status == null ||
        claimedAt == null) {
      return null;
    }
    return FrontDoorRecord(
      segmentIndex: index,
      text: text,
      kind: kind,
      destinationId: switch (json['destinationId']) {
        final String id => id,
        _ => null,
      },
      ownerTitle: switch (json['ownerTitle']) {
        final String title => title,
        _ => null,
      },
      status: status,
      claimedAt: claimedAt,
      outcome: FrontDoorOutcome.fromJson(json['outcome']),
    );
  }
}
