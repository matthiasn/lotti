import 'package:flutter/foundation.dart';

enum DayProcessingJobKind { transcribeAudio }

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

/// Device-local durable intent to derive text from a saved day recording.
@immutable
class DayProcessingJob {
  const DayProcessingJob({
    required this.id,
    required this.kind,
    required this.status,
    required this.dayId,
    required this.activityEntryId,
    required this.recordingSessionId,
    required this.audioId,
    required this.audioPath,
    required this.createdAt,
    required this.updatedAt,
    required this.nextAttemptAt,
    required this.attempts,
    required this.generation,
    this.claimToken,
    this.leaseUntil,
    this.retryNotBefore,
    this.lastFailureClass,
    this.lastError,
    this.resultTranscript,
    this.completedAt,
  });

  factory DayProcessingJob.fromJson(Map<String, Object?> json) =>
      DayProcessingJob(
        id: json['id']! as String,
        kind: DayProcessingJobKind.values.byName(json['kind']! as String),
        status: DayProcessingJobStatus.values.byName(
          json['status']! as String,
        ),
        dayId: json['dayId']! as String,
        activityEntryId: json['activityEntryId']! as String,
        recordingSessionId: json['recordingSessionId']! as String,
        audioId: json['audioId']! as String,
        audioPath: json['audioPath']! as String,
        createdAt: DateTime.parse(json['createdAt']! as String),
        updatedAt: DateTime.parse(json['updatedAt']! as String),
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
        completedAt: _dateOrNull(json['completedAt']),
      );

  final String id;
  final DayProcessingJobKind kind;
  final DayProcessingJobStatus status;
  final String dayId;
  final String activityEntryId;
  final String recordingSessionId;
  final String audioId;
  final String audioPath;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime nextAttemptAt;
  final int attempts;
  final int generation;
  final String? claimToken;
  final DateTime? leaseUntil;
  final DateTime? retryNotBefore;
  final DayProcessingFailureClass? lastFailureClass;
  final String? lastError;
  final String? resultTranscript;
  final DateTime? completedAt;

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
    DateTime? updatedAt,
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
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) => DayProcessingJob(
    id: id,
    kind: kind,
    status: status ?? this.status,
    dayId: dayId,
    activityEntryId: activityEntryId,
    recordingSessionId: recordingSessionId,
    audioId: audioId,
    audioPath: audioPath,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
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
    completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': 1,
    'id': id,
    'kind': kind.name,
    'status': status.name,
    'dayId': dayId,
    'activityEntryId': activityEntryId,
    'recordingSessionId': recordingSessionId,
    'audioId': audioId,
    'audioPath': audioPath,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'nextAttemptAt': nextAttemptAt.toUtc().toIso8601String(),
    'attempts': attempts,
    'generation': generation,
    'claimToken': claimToken,
    'leaseUntil': leaseUntil?.toUtc().toIso8601String(),
    'retryNotBefore': retryNotBefore?.toUtc().toIso8601String(),
    'lastFailureClass': lastFailureClass?.name,
    'lastError': lastError,
    'resultTranscript': resultTranscript,
    'completedAt': completedAt?.toUtc().toIso8601String(),
  };
}

DateTime? _dateOrNull(Object? value) =>
    value == null ? null : DateTime.parse(value as String);
