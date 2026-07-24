import 'package:drift/drift.dart';
import 'package:lotti/database/logging_types.dart';
import 'package:lotti/features/daily_os_next/database/day_processing_db.dart';
import 'package:lotti/features/daily_os_next/database/day_processing_job_row.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_job.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_legacy_file_store.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';

/// One-off cutover from the ADR 0031 file-per-job outbox to the ADR 0044
/// device-local table.
///
/// Runs during app start, **before** `DayProcessingRuntime.start()` and before
/// any enqueue path is wired up. That quiescing is the write barrier the
/// cutover depends on: a database transaction cannot span filesystem changes,
/// so a job written to disk after the import but before the sentinel would
/// exist only in the old store and become invisible the moment the repository
/// switches over.
class DayProcessingOutboxMigration {
  DayProcessingOutboxMigration({
    required this.db,
    required this.legacyStore,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final DayProcessingDb db;
  final DayProcessingLegacyFileStore legacyStore;
  final DateTime Function() _now;

  /// Bound on verification passes.
  ///
  /// With writers quiesced the second pass is always clean; the bound exists
  /// so an unexpected concurrent writer degrades into "migrate next start"
  /// rather than an unbounded loop.
  static const int _maxVerificationPasses = 5;

  /// Imports the legacy directory and publishes the cutover sentinel.
  ///
  /// Idempotent: once the sentinel row exists this is a single indexed lookup,
  /// so it is safe (and expected) to call on every start. Returns the number of
  /// jobs imported, or null when the migration had already completed.
  Future<int?> run() async {
    if (await isComplete()) return null;

    // Nothing to carry over on a fresh install; record the milestone so later
    // starts skip the directory check entirely.
    if (!legacyStore.exists) {
      await _writeSentinel();
      return 0;
    }

    var imported = 0;
    for (var pass = 0; pass < _maxVerificationPasses; pass++) {
      final jobs = await legacyStore.readAll();
      final missing = await _notYetImported(jobs);
      if (missing.isEmpty) {
        // Verified: every id on disk is in the table. Publish the sentinel in
        // the same transaction as the confirming read so the import and the
        // cutover marker share one durability domain — either both are
        // durable or neither is, and a crash before the commit simply re-runs
        // the whole migration.
        await db.transaction(() async {
          final stillMissing = await _notYetImported(jobs);
          if (stillMissing.isNotEmpty) await _importAll(stillMissing);
          imported += stillMissing.length;
          await _writeSentinel();
        });
        return imported;
      }
      await db.transaction(() => _importAll(missing));
      imported += missing.length;
    }
    // Verification never stabilized, which with writers quiesced should be
    // impossible. The sentinel is withheld so the next start retries the
    // cutover, and the job files are still on disk — but be precise about what
    // that costs: the repository reads only the table, so anything not yet
    // imported is invisible for *this* session. Nothing is lost; some work may
    // be delayed by one app run.
    //
    // Deliberately not thrown: failing here would block app startup entirely
    // over a store that is already fully recoverable on the next launch, and
    // startup repair rebuilds transcription jobs from journal provenance
    // regardless.
    _logUnstable(imported);
    return imported;
  }

  void _logUnstable(int imported) {
    if (!getIt.isRegistered<DomainLogger>()) return;
    getIt<DomainLogger>().log(
      LogDomain.agentWorkflow,
      'day-processing outbox migration did not stabilize after '
      '$_maxVerificationPasses passes; imported $imported job(s), retrying '
      'next start',
      subDomain: 'dayProcessing.migration',
      level: InsightLevel.error,
    );
  }

  Future<bool> isComplete() async {
    final rows = await db
        .customSelect(
          'SELECT 1 FROM day_processing_migrations WHERE migration_key = ?1',
          variables: const [
            Variable<String>(dayProcessingFileImportMigrationKey),
          ],
        )
        .get();
    return rows.isNotEmpty;
  }

  /// Jobs from disk that the table does not have yet.
  ///
  /// Verification is deliberately one-directional. Every id on disk must reach
  /// the table, but a row in the table with no file behind it is kept, not
  /// deleted: no code path removes a job file to express intent — cancellation
  /// is a `cancelled` status written *into* the file — so a missing file never
  /// means "this job should not exist". It does happen when a file whose
  /// checksum fails is quarantined after a previous pass imported it, and in
  /// that case the imported row is the only good copy left.
  Future<List<DayProcessingJob>> _notYetImported(
    List<DayProcessingJob> jobs,
  ) async {
    if (jobs.isEmpty) return const [];
    final rows = await db
        .customSelect('SELECT id FROM day_processing_jobs')
        .get();
    final present = {for (final row in rows) row.read<String>('id')};
    return [
      for (final job in jobs)
        if (!present.contains(job.id)) job,
    ];
  }

  Future<void> _importAll(List<DayProcessingJob> jobs) async {
    for (final job in jobs) {
      // `INSERT OR IGNORE`, not an upsert: a job the live repository has
      // already advanced past its imported state must not be rewound to what
      // the stale file says.
      await db.customInsert(
        'INSERT OR IGNORE INTO day_processing_jobs '
        '($dayProcessingJobColumns) '
        'VALUES ($dayProcessingJobPlaceholders)',
        variables: dayProcessingJobVariables(job),
      );
    }
  }

  Future<void> _writeSentinel() => db.customInsert(
    'INSERT OR REPLACE INTO day_processing_migrations '
    '(migration_key, completed_at) '
    'VALUES (?1, ?2)',
    variables: [
      const Variable<String>(dayProcessingFileImportMigrationKey),
      Variable<int>(_now().millisecondsSinceEpoch),
    ],
  );
}
