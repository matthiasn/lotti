import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

enum DayProcessingJobKind {
  transcribeAudio,
  parseCapture,
  draftPlan,
  refinePlan,
}

enum DayProcessingJobStatus {
  queued,
  running,
  waitingForNetwork,
  waitingForUser,
  failed,
  succeeded,
  cancelled,
}

enum DayProcessingFailureClass {
  network,
  timeout,
  providerBusy,
  setupRequired,
  deterministic,
  missingAsset,
  local,
}

/// Kind-specific intent of a [DayProcessingJob] (schema v2).
///
/// The envelope (status, claims, retries) is shared across kinds; the payload
/// carries only what that kind's executor needs to (re-)run the work. Agent
/// jobs deliberately carry **no agent id** — the owning agent is resolved at
/// execution time (ADR 0032), so a job enqueued before the per-day cutover
/// still executes correctly after it.
@immutable
sealed class DayProcessingPayload {
  const DayProcessingPayload();

  static DayProcessingPayload fromJson(
    DayProcessingJobKind kind,
    Map<String, Object?> json,
  ) => switch (kind) {
    DayProcessingJobKind.transcribeAudio => TranscribeAudioPayload(
      activityEntryId: json['activityEntryId']! as String,
      recordingSessionId: json['recordingSessionId']! as String,
      audioId: json['audioId']! as String,
      audioPath: json['audioPath']! as String,
    ),
    DayProcessingJobKind.parseCapture => ParseCapturePayload(
      captureId: json['captureId']! as String,
    ),
    DayProcessingJobKind.draftPlan => DraftPlanPayload(
      captureId: json['captureId'] as String?,
      decidedTaskIds: [
        for (final id in json['decidedTaskIds']! as List<Object?>)
          id! as String,
      ],
      decidedCaptureItemIds: [
        for (final id in json['decidedCaptureItemIds']! as List<Object?>)
          id! as String,
      ],
    ),
    DayProcessingJobKind.refinePlan => RefinePlanPayload(
      transcriptCaptureId: json['transcriptCaptureId'] as String?,
    ),
  };

  DayProcessingJobKind get kind;

  Map<String, Object?> toJson();
}

/// Intent to derive text from a saved day recording.
final class TranscribeAudioPayload extends DayProcessingPayload {
  const TranscribeAudioPayload({
    required this.activityEntryId,
    required this.recordingSessionId,
    required this.audioId,
    required this.audioPath,
  });

  final String activityEntryId;
  final String recordingSessionId;
  final String audioId;
  final String audioPath;

  @override
  DayProcessingJobKind get kind => DayProcessingJobKind.transcribeAudio;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'activityEntryId': activityEntryId,
    'recordingSessionId': recordingSessionId,
    'audioId': audioId,
    'audioPath': audioPath,
  };

  @override
  bool operator ==(Object other) =>
      other is TranscribeAudioPayload &&
      other.activityEntryId == activityEntryId &&
      other.recordingSessionId == recordingSessionId &&
      other.audioId == audioId &&
      other.audioPath == audioPath;

  @override
  int get hashCode =>
      Object.hash(activityEntryId, recordingSessionId, audioId, audioPath);
}

/// Intent to parse one submitted capture into items via an agent wake.
final class ParseCapturePayload extends DayProcessingPayload {
  const ParseCapturePayload({required this.captureId});

  final String captureId;

  @override
  DayProcessingJobKind get kind => DayProcessingJobKind.parseCapture;

  @override
  Map<String, Object?> toJson() => <String, Object?>{'captureId': captureId};

  @override
  bool operator ==(Object other) =>
      other is ParseCapturePayload && other.captureId == captureId;

  @override
  int get hashCode => captureId.hashCode;
}

/// Intent to draft the day's plan via an agent wake.
///
/// Mutable-by-re-arm (documented exception to the immutable-intent rule): a
/// repeated "draft my day" for the same day coalesces onto the same job and
/// replaces this payload with the newest decided selections.
final class DraftPlanPayload extends DayProcessingPayload {
  const DraftPlanPayload({
    this.captureId,
    this.decidedTaskIds = const [],
    this.decidedCaptureItemIds = const [],
  });

  final String? captureId;
  final List<String> decidedTaskIds;
  final List<String> decidedCaptureItemIds;

  @override
  DayProcessingJobKind get kind => DayProcessingJobKind.draftPlan;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'captureId': captureId,
    'decidedTaskIds': decidedTaskIds,
    'decidedCaptureItemIds': decidedCaptureItemIds,
  };

  @override
  bool operator ==(Object other) =>
      other is DraftPlanPayload &&
      other.captureId == captureId &&
      const ListEquality<String>().equals(
        other.decidedTaskIds,
        decidedTaskIds,
      ) &&
      const ListEquality<String>().equals(
        other.decidedCaptureItemIds,
        decidedCaptureItemIds,
      );

  @override
  int get hashCode => Object.hash(
    captureId,
    const ListEquality<String>().hash(decidedTaskIds),
    const ListEquality<String>().hash(decidedCaptureItemIds),
  );
}

/// Intent to propose a plan diff for the day via an agent wake.
///
/// The refine transcript is persisted as a `CaptureEntity` at **enqueue**
/// time and referenced here, so a re-run after a crash reuses the same
/// capture instead of writing duplicates.
final class RefinePlanPayload extends DayProcessingPayload {
  const RefinePlanPayload({this.transcriptCaptureId});

  final String? transcriptCaptureId;

  @override
  DayProcessingJobKind get kind => DayProcessingJobKind.refinePlan;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'transcriptCaptureId': transcriptCaptureId,
  };

  @override
  bool operator ==(Object other) =>
      other is RefinePlanPayload &&
      other.transcriptCaptureId == transcriptCaptureId;

  @override
  int get hashCode => transcriptCaptureId.hashCode;
}

/// Device-local durable processing intent for one day (schema v2).
///
/// One file per job in the processing outbox; the payload determines what the
/// processor executes (transcription or an agent wake, ADR 0031/0032).
@immutable
class DayProcessingJob {
  const DayProcessingJob({
    required this.id,
    required this.status,
    required this.dayId,
    required this.payload,
    required this.createdAt,
    required this.updatedAt,
    required this.requestedAt,
    required this.nextAttemptAt,
    required this.attempts,
    required this.generation,
    this.claimToken,
    this.leaseUntil,
    this.retryNotBefore,
    this.lastFailureClass,
    this.lastError,
    this.resultTranscript,
    this.resultEntityId,
    this.completedAt,
  });

  factory DayProcessingJob.fromJson(Map<String, Object?> json) {
    final kind = DayProcessingJobKind.values.byName(json['kind']! as String);
    // v1 files predate the payload envelope and are always transcription
    // jobs with the payload fields at the top level; synthesize the payload
    // from those keys so an upgrade never quarantines existing intents.
    final payloadJson = switch (json['payload']) {
      final Map<String, Object?> nested => nested,
      _ => json,
    };
    final createdAt = DateTime.parse(json['createdAt']! as String);
    return DayProcessingJob(
      id: json['id']! as String,
      status: DayProcessingJobStatus.values.byName(json['status']! as String),
      dayId: json['dayId']! as String,
      payload: DayProcessingPayload.fromJson(kind, payloadJson),
      createdAt: createdAt,
      updatedAt: DateTime.parse(json['updatedAt']! as String),
      // v1 files carry no requestedAt; the enqueue time is the request time.
      requestedAt: _dateOrNull(json['requestedAt']) ?? createdAt,
      nextAttemptAt: DateTime.parse(json['nextAttemptAt']! as String),
      attempts: json['attempts']! as int,
      generation: json['generation']! as int,
      claimToken: json['claimToken'] as String?,
      leaseUntil: _dateOrNull(json['leaseUntil']),
      retryNotBefore: _dateOrNull(json['retryNotBefore']),
      lastFailureClass: json['lastFailureClass'] == null
          ? null
          : DayProcessingFailureClass.values.byName(
              json['lastFailureClass']! as String,
            ),
      lastError: json['lastError'] as String?,
      resultTranscript: json['resultTranscript'] as String?,
      resultEntityId: json['resultEntityId'] as String?,
      completedAt: _dateOrNull(json['completedAt']),
    );
  }

  final String id;
  final DayProcessingJobStatus status;
  final String dayId;
  final DayProcessingPayload payload;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// When the work this job currently represents was requested.
  ///
  /// Equals [createdAt] for a fresh job and moves forward when a terminal
  /// draft job is re-armed. Agent-job executors use it as the artifact
  /// baseline: an artifact updated at/after this instant satisfies the job
  /// without re-inference.
  final DateTime requestedAt;

  final DateTime nextAttemptAt;
  final int attempts;
  final int generation;
  final String? claimToken;
  final DateTime? leaseUntil;
  final DateTime? retryNotBefore;
  final DayProcessingFailureClass? lastFailureClass;
  final String? lastError;

  /// Provider output staged before the journal side effect (transcription
  /// jobs only), so a DB failure can retry without re-inferring.
  final String? resultTranscript;

  /// Id of the agent entity the job produced (agent jobs only): the
  /// `DayPlanEntity` id for drafts, the ChangeSet id for refines.
  final String? resultEntityId;

  final DateTime? completedAt;

  DayProcessingJobKind get kind => payload.kind;

  /// The transcription payload's activity entry id, `null` for agent jobs.
  String? get activityEntryId => switch (payload) {
    TranscribeAudioPayload(:final activityEntryId) => activityEntryId,
    _ => null,
  };

  /// The transcription payload's recording session id, `null` otherwise.
  String? get recordingSessionId => switch (payload) {
    TranscribeAudioPayload(:final recordingSessionId) => recordingSessionId,
    _ => null,
  };

  /// The transcription payload's audio entity id, `null` for agent jobs.
  String? get audioId => switch (payload) {
    TranscribeAudioPayload(:final audioId) => audioId,
    _ => null,
  };

  /// The transcription payload's audio file path, `null` for agent jobs.
  String? get audioPath => switch (payload) {
    TranscribeAudioPayload(:final audioPath) => audioPath,
    _ => null,
  };

  bool get isTerminal => switch (status) {
    DayProcessingJobStatus.succeeded ||
    DayProcessingJobStatus.cancelled => true,
    _ => false,
  };

  bool isDue(DateTime now) {
    if (isTerminal ||
        status == DayProcessingJobStatus.waitingForUser ||
        status == DayProcessingJobStatus.failed) {
      return false;
    }
    final hardBoundary = retryNotBefore;
    if (hardBoundary != null && now.isBefore(hardBoundary)) return false;
    if (status == DayProcessingJobStatus.running) {
      return leaseUntil != null && !now.isBefore(leaseUntil!);
    }
    return !now.isBefore(nextAttemptAt);
  }

  DayProcessingJob copyWith({
    DayProcessingJobStatus? status,
    DayProcessingPayload? payload,
    DateTime? updatedAt,
    DateTime? requestedAt,
    DateTime? nextAttemptAt,
    int? attempts,
    int? generation,
    String? claimToken,
    bool clearClaimToken = false,
    DateTime? leaseUntil,
    bool clearLeaseUntil = false,
    DateTime? retryNotBefore,
    bool clearRetryNotBefore = false,
    DayProcessingFailureClass? lastFailureClass,
    bool clearLastFailureClass = false,
    String? lastError,
    bool clearLastError = false,
    String? resultTranscript,
    bool clearResultTranscript = false,
    String? resultEntityId,
    bool clearResultEntityId = false,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) => DayProcessingJob(
    id: id,
    status: status ?? this.status,
    dayId: dayId,
    payload: payload ?? this.payload,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    requestedAt: requestedAt ?? this.requestedAt,
    nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
    attempts: attempts ?? this.attempts,
    generation: generation ?? this.generation,
    claimToken: clearClaimToken ? null : claimToken ?? this.claimToken,
    leaseUntil: clearLeaseUntil ? null : leaseUntil ?? this.leaseUntil,
    retryNotBefore: clearRetryNotBefore
        ? null
        : retryNotBefore ?? this.retryNotBefore,
    lastFailureClass: clearLastFailureClass
        ? null
        : lastFailureClass ?? this.lastFailureClass,
    lastError: clearLastError ? null : lastError ?? this.lastError,
    resultTranscript: clearResultTranscript
        ? null
        : resultTranscript ?? this.resultTranscript,
    resultEntityId: clearResultEntityId
        ? null
        : resultEntityId ?? this.resultEntityId,
    completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': 2,
    'id': id,
    'kind': kind.name,
    'status': status.name,
    'dayId': dayId,
    'payload': payload.toJson(),
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'requestedAt': requestedAt.toUtc().toIso8601String(),
    'nextAttemptAt': nextAttemptAt.toUtc().toIso8601String(),
    'attempts': attempts,
    'generation': generation,
    'claimToken': claimToken,
    'leaseUntil': leaseUntil?.toUtc().toIso8601String(),
    'retryNotBefore': retryNotBefore?.toUtc().toIso8601String(),
    'lastFailureClass': lastFailureClass?.name,
    'lastError': lastError,
    'resultTranscript': resultTranscript,
    'resultEntityId': resultEntityId,
    'completedAt': completedAt?.toUtc().toIso8601String(),
  };
}

DateTime? _dateOrNull(Object? value) =>
    value == null ? null : DateTime.parse(value as String);
