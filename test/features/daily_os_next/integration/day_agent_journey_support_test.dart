import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_job.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import 'day_agent_journey_support.dart';

void main() {
  final now = DateTime.utc(2026, 7, 27, 12);

  DayProcessingJob job(DayProcessingJobStatus status) => DayProcessingJob(
    id: 'parse_capture-1',
    status: status,
    dayId: 'dayplan-2026-07-27',
    payload: const ParseCapturePayload(captureId: 'capture-1'),
    createdAt: now,
    updatedAt: now,
    requestedAt: now,
    nextAttemptAt: now,
    attempts: 1,
    generation: 0,
    lastFailureClass: status == DayProcessingJobStatus.waitingForUser
        ? DayProcessingFailureClass.setupRequired
        : DayProcessingFailureClass.deterministic,
    lastError: 'action required',
  );

  for (final status in [
    DayProcessingJobStatus.failed,
    DayProcessingJobStatus.waitingForUser,
  ]) {
    test('returns immediately when a job settles as ${status.name}', () async {
      final outbox = MockDayProcessingOutboxRepository();
      final settledJob = job(status);
      when(() => outbox.changes).thenAnswer((_) => const Stream.empty());
      when(
        () => outbox.getById(settledJob.id),
      ).thenAnswer((_) async => settledJob);

      final result = await waitForTerminalDayProcessingJob(
        outbox,
        settledJob.id,
      );

      expect(result, same(settledJob));
      expect(result.status, status);
      verify(() => outbox.getById(settledJob.id)).called(1);
    });
  }

  test('accepts a successfully settled job', () {
    expect(
      () => requireSuccessfulDayProcessingJob(
        job(DayProcessingJobStatus.succeeded),
        stage: 'Capture parse',
      ),
      returnsNormally,
    );
  });

  for (final status in [
    DayProcessingJobStatus.failed,
    DayProcessingJobStatus.waitingForUser,
    DayProcessingJobStatus.cancelled,
  ]) {
    test('rejects an unsuccessful parse job in ${status.name}', () {
      expect(
        () => requireSuccessfulDayProcessingJob(
          job(status),
          stage: 'Capture parse',
        ),
        throwsA(
          isA<StateError>()
              .having(
                (error) => error.message,
                'message',
                contains('Capture parse job parse_capture-1'),
              )
              .having(
                (error) => error.message,
                'status',
                contains(status.name),
              ),
        ),
      );
    });
  }
}
