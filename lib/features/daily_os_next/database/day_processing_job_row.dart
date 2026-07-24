import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_job.dart';

/// Mapping between [DayProcessingJob] and its `day_processing_jobs` row.
///
/// Shared by the outbox repository and the one-off file import so a job is
/// encoded exactly one way. The column list, the bind order in
/// [dayProcessingJobVariables], and the reads in [dayProcessingJobFromRow] all
/// move together.

/// Column list in bind order.
const String dayProcessingJobColumns =
    'id, status, kind, day_id, payload, run_keys, created_at, updated_at, '
    'requested_at, next_attempt_at, attempts, generation, claim_token, '
    'lease_until, retry_not_before, last_failure_class, last_error, '
    'result_transcript, result_entity_id, completed_at';

/// `?1 … ?20`, matching [dayProcessingJobColumns].
const String dayProcessingJobPlaceholders =
    '?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15, ?16, '
    '?17, ?18, ?19, ?20';

/// Bind values for [dayProcessingJobColumns], in order.
List<Variable<Object>> dayProcessingJobVariables(DayProcessingJob job) =>
    <Variable<Object>>[
      Variable<String>(job.id),
      Variable<String>(job.status.name),
      Variable<String>(job.kind.name),
      Variable<String>(job.dayId),
      Variable<String>(jsonEncode(job.payload.toJson())),
      Variable<String>(job.runKeys.isEmpty ? null : jsonEncode(job.runKeys)),
      Variable<int>(job.createdAt.millisecondsSinceEpoch),
      Variable<int>(job.updatedAt.millisecondsSinceEpoch),
      Variable<int>(job.requestedAt.millisecondsSinceEpoch),
      Variable<int>(job.nextAttemptAt.millisecondsSinceEpoch),
      Variable<int>(job.attempts),
      Variable<int>(job.generation),
      Variable<String>(job.claimToken),
      Variable<int>(job.leaseUntil?.millisecondsSinceEpoch),
      Variable<int>(job.retryNotBefore?.millisecondsSinceEpoch),
      Variable<String>(job.lastFailureClass?.name),
      Variable<String>(job.lastError),
      Variable<String>(job.resultTranscript),
      Variable<String>(job.resultEntityId),
      Variable<int>(job.completedAt?.millisecondsSinceEpoch),
    ];

/// Decodes one `day_processing_jobs` row.
DayProcessingJob dayProcessingJobFromRow(QueryRow row) {
  final kind = DayProcessingJobKind.values.byName(row.read<String>('kind'));
  final runKeys = row.readNullable<String>('run_keys');
  return DayProcessingJob(
    id: row.read<String>('id'),
    status: DayProcessingJobStatus.values.byName(row.read<String>('status')),
    dayId: row.read<String>('day_id'),
    payload: DayProcessingPayload.fromJson(
      kind,
      jsonDecode(row.read<String>('payload'))! as Map<String, Object?>,
    ),
    createdAt: dayProcessingTime(row.read<int>('created_at')),
    updatedAt: dayProcessingTime(row.read<int>('updated_at')),
    requestedAt: dayProcessingTime(row.read<int>('requested_at')),
    nextAttemptAt: dayProcessingTime(row.read<int>('next_attempt_at')),
    attempts: row.read<int>('attempts'),
    generation: row.read<int>('generation'),
    runKeys: runKeys == null
        ? const []
        : [for (final key in jsonDecode(runKeys)! as List) key! as String],
    claimToken: row.readNullable<String>('claim_token'),
    leaseUntil: dayProcessingTimeOrNull(row.readNullable<int>('lease_until')),
    retryNotBefore: dayProcessingTimeOrNull(
      row.readNullable<int>('retry_not_before'),
    ),
    lastFailureClass: switch (row.readNullable<String>('last_failure_class')) {
      final String name => DayProcessingFailureClass.values.byName(name),
      _ => null,
    },
    lastError: row.readNullable<String>('last_error'),
    resultTranscript: row.readNullable<String>('result_transcript'),
    resultEntityId: row.readNullable<String>('result_entity_id'),
    completedAt: dayProcessingTimeOrNull(row.readNullable<int>('completed_at')),
  );
}

/// Epoch milliseconds back to a UTC [DateTime].
///
/// UTC because the previous file encoding was ISO-8601 with a `Z` suffix, and
/// `DateTime` equality compares the time zone flag as well as the instant — so
/// reading back as local time would make round-tripped jobs compare unequal to
/// what callers wrote.
DateTime dayProcessingTime(int milliseconds) =>
    DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);

DateTime? dayProcessingTimeOrNull(int? milliseconds) =>
    milliseconds == null ? null : dayProcessingTime(milliseconds);
