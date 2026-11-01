import 'dart:convert';

import 'package:lotti/classes/agents/query_chat_models.dart';
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

  /// Nothing takes this kind of segment: a question about today's plan,
  /// or anything about it while the Daily OS is off.
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
          fromJournal: map['fromJournal'] == true,
          private: map['private'] == true,
          evidence: _decoded(map['evidence'], QueryEvidence.fromJson),
          dependencies: _decoded(map['dependencies'], QuerySourceRef.fromJson),
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
        final generation = map['generation'];
        return FrontDoorProposal(
          ownerId: ownerId,
          generation: generation is int ? generation : 0,
        );
      case 'filed':
        final entryId = map['entryId'];
        if (entryId is! String) return null;
        final ownerId = map['ownerId'];
        final generation = map['generation'];
        return FrontDoorFiled(
          entryId: entryId,
          ownerId: ownerId is String ? ownerId : null,
          newKind: FrontNewKind.fromName(map['newKind']),
          generation: generation is int ? generation : 0,
        );
      case 'declined':
        final ownerId = map['ownerId'];
        final generation = map['generation'];
        return FrontDoorDeclined(
          ownerId: ownerId is String ? ownerId : null,
          newKind: FrontNewKind.fromName(map['newKind']),
          generation: generation is int ? generation : 0,
        );
      case 'inbox':
        final ownerId = map['ownerId'];
        final generation = map['generation'];
        return FrontDoorInbox(
          newKind: FrontNewKind.fromName(map['newKind']),
          ownerId: ownerId is String ? ownerId : null,
          generation: generation is int ? generation : 0,
        );
      case 'day':
        return const FrontDoorDay();
      case 'dayPlanned':
        final day = DateTime.tryParse('${map['day']}');
        return day == null ? null : FrontDoorDayPlanned(day: day);
      case 'projectCreated':
        final projectId = map['projectId'];
        if (projectId is! String) return null;
        return FrontDoorProjectCreated(projectId: projectId);
      case 'taskCreated':
        final taskId = map['taskId'];
        if (taskId is! String) return null;
        final generation = map['generation'];
        return FrontDoorTaskCreated(
          taskId: taskId,
          newKind: FrontNewKind.fromName(map['newKind']),
          generation: generation is int ? generation : 0,
        );
      default:
        return null;
    }
  }
}

/// A statement or instruction under a task, waiting for the user's one tap
/// before anything is written (decision 1).
///
/// [generation] counts how often the proposal was filed and taken back out:
/// it is part of the filed entry's deterministic id, so a tap that is
/// retried after an interrupted write lands on the entry it already wrote,
/// while a proposal filed again after an unfile gets a fresh entry rather
/// than the soft-deleted one.
class FrontDoorProposal extends FrontDoorOutcome {
  const FrontDoorProposal({required this.ownerId, this.generation = 0});

  final String ownerId;
  final int generation;

  /// Whether the user had filed this once and took the entry back out.
  bool get unfiled => generation > 0;

  @override
  Map<String, Object?> toJson() => {
    'type': 'proposal',
    'ownerId': ownerId,
    if (generation > 0) 'generation': generation,
  };
}

/// The user's words were written as a text entry: under [ownerId] when it
/// was filed under a task, on their own when saved as a note. [generation]
/// is the proposal's or the inbox item's at the time of writing, so a
/// take-back can hand the next proposal or inbox item the one after it.
/// [newKind] is the inbox item's, kept so a take-back leads with the same
/// chip again.
class FrontDoorFiled extends FrontDoorOutcome {
  const FrontDoorFiled({
    required this.entryId,
    this.ownerId,
    this.newKind,
    this.generation = 0,
  });

  final String entryId;
  final String? ownerId;
  final FrontNewKind? newKind;
  final int generation;

  @override
  Map<String, Object?> toJson() => {
    'type': 'filed',
    'entryId': entryId,
    if (ownerId != null) 'ownerId': ownerId,
    if (newKind != null) 'newKind': newKind!.name,
    if (generation > 0) 'generation': generation,
  };
}

/// The user left this where it is. Nothing was written, and nothing waits.
/// What it was before is kept — [ownerId] and [generation] of the proposal
/// it came from, [newKind] of the inbox item — so an undo brings that back.
class FrontDoorDeclined extends FrontDoorOutcome {
  const FrontDoorDeclined({this.ownerId, this.newKind, this.generation = 0});

  final String? ownerId;
  final FrontNewKind? newKind;
  final int generation;

  @override
  Map<String, Object?> toJson() => {
    'type': 'declined',
    if (ownerId != null) 'ownerId': ownerId,
    if (newKind != null) 'newKind': newKind!.name,
    if (generation > 0) 'generation': generation,
  };
}

/// Nothing owns this yet: the segment waits in the inbox with the ways
/// that make it a task, start a goal or project, save it as a note, or
/// leave it. [newKind] is what the router thought it would become, if
/// anything; [ownerId] the task it was proposed under before the user said
/// not to file it there, so the item asks where it should go *instead*;
/// [generation] counts how often the item was written and taken back.
class FrontDoorInbox extends FrontDoorOutcome {
  const FrontDoorInbox({this.newKind, this.ownerId, this.generation = 0});

  final FrontNewKind? newKind;
  final String? ownerId;
  final int generation;

  @override
  Map<String, Object?> toJson() => {
    'type': 'inbox',
    if (newKind != null) 'newKind': newKind!.name,
    if (ownerId != null) 'ownerId': ownerId,
    if (generation > 0) 'generation': generation,
  };
}

/// The user made a task of the segment; its title is the user's words.
/// [newKind] and [generation] are the inbox item's, kept for a take-back.
class FrontDoorTaskCreated extends FrontDoorOutcome {
  const FrontDoorTaskCreated({
    required this.taskId,
    this.newKind,
    this.generation = 0,
  });

  final String taskId;
  final FrontNewKind? newKind;
  final int generation;

  @override
  Map<String, Object?> toJson() => {
    'type': 'taskCreated',
    'taskId': taskId,
    if (newKind != null) 'newKind': newKind!.name,
    if (generation > 0) 'generation': generation,
  };
}

/// Something to change in today's plan, waiting for the user's tap: the
/// tap opens the Daily OS planning with the words already given — refining
/// today's plan, or planning the day when there is none yet — and the plan
/// changes only when the user accepts there (decision 1).
class FrontDoorDay extends FrontDoorOutcome {
  const FrontDoorDay();

  @override
  Map<String, Object?> toJson() => {'type': 'day'};
}

/// The user took the words into the plan of [day] — today at the time —
/// and accepted a plan there. Undoing it is the Daily OS's own revert, on
/// the day itself.
class FrontDoorDayPlanned extends FrontDoorOutcome {
  const FrontDoorDayPlanned({required this.day});

  /// The calendar day that was planned, at local midnight.
  final DateTime day;

  @override
  Map<String, Object?> toJson() => {
    'type': 'dayPlanned',
    'day': DateTime(
      day.year,
      day.month,
      day.day,
    ).toIso8601String().substring(0, 10),
  };
}

/// The user made a project of the segment, through the project form opened
/// with their words as its title. The form wrote it, so the door only
/// records it; removing it is the project's own business.
class FrontDoorProjectCreated extends FrontDoorOutcome {
  const FrontDoorProjectCreated({required this.projectId});

  final String projectId;

  @override
  Map<String, Object?> toJson() => {
    'type': 'projectCreated',
    'projectId': projectId,
  };
}

/// Whether the user still has to act on this door: a proposal or a change
/// to today waiting for its tap, or an inbox item nobody has taken anywhere.
bool frontDoorAwaitsUser(FrontDoorOutcome? outcome) =>
    outcome is FrontDoorProposal ||
    outcome is FrontDoorDay ||
    outcome is FrontDoorInbox;

/// The query pipeline answered a question; the text is shown in the front
/// thread — a task or project question attributed to its owner, a journal
/// question ([fromJournal]) to the front agent herself, with the passages it
/// rests on.
class FrontDoorAnswer extends FrontDoorOutcome {
  const FrontDoorAnswer({
    required this.text,
    required this.summaryBased,
    required this.incomplete,
    this.ownerIds = const [],
    this.fromJournal = false,
    this.private = false,
    this.evidence = const [],
    this.dependencies = const [],
  });

  final String text;
  final bool summaryBased;
  final bool incomplete;
  final List<String> ownerIds;

  /// She answered from the journal herself, rather than an owner.
  final bool fromJournal;

  /// Asked while private entries were shown: the answer is shown only while
  /// they are.
  final bool private;

  /// The verified passages a journal answer cites, numbered as its text
  /// cites them.
  final List<QueryEvidence> evidence;

  /// Every source the answer depends on. The surface shows the answer only
  /// while all of them are still visible, as query chat does.
  final List<QuerySourceRef> dependencies;

  @override
  Map<String, Object?> toJson() => {
    'type': 'answer',
    'text': text,
    'summaryBased': summaryBased,
    'incomplete': incomplete,
    'ownerIds': ownerIds,
    if (fromJournal) 'fromJournal': true,
    if (private) 'private': true,
    // Plain maps all the way down, as the record is stored, so a record
    // read back before it is stored decodes the same.
    if (evidence.isNotEmpty) 'evidence': _plain(evidence),
    if (dependencies.isNotEmpty) 'dependencies': _plain(dependencies),
  };
}

Object? _plain(Object value) => jsonDecode(jsonEncode(value));

/// The items of a stored list that still decode; a malformed one is left
/// out rather than failing the whole record.
List<T> _decoded<T>(Object? json, T Function(Map<String, dynamic>) fromJson) =>
    [
      if (json is List)
        for (final item in json)
          if (item is Map)
            ?_tryDecode(() => fromJson(Map<String, dynamic>.from(item))),
    ];

T? _tryDecode<T>(T Function() decode) {
  try {
    return decode();
  } on Object {
    return null;
  }
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
