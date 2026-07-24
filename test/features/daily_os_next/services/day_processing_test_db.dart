import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/database/day_processing_db.dart';
import 'package:lotti/features/daily_os_next/database/day_processing_job_row.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_job.dart';

/// In-memory processing outbox database with teardown already registered.
///
/// Every suite that builds a `DayProcessingOutboxRepository` needs one, and a
/// leaked connection breaks later tests in the same shard — CI runs the suite
/// in a single thread — so closing it is not left to each call site.
DayProcessingDb createTestDayProcessingDb() {
  final db = DayProcessingDb(inMemoryDatabase: true);
  addTearDown(db.close);
  return db;
}

/// Whole-table read for assertions.
///
/// `getAll()` is deliberately absent from `DayProcessingOutboxRepository`
/// (ADR 0044) so no production caller can reintroduce a ledger scan. Tests
/// that genuinely want every row reach past the repository to the table.
Future<List<DayProcessingJob>> allDayProcessingJobs(DayProcessingDb db) async {
  final rows = await db
      .customSelect(
        'SELECT $dayProcessingJobColumns FROM day_processing_jobs '
        'ORDER BY created_at, id',
      )
      .get();
  return rows.map(dayProcessingJobFromRow).toList();
}
