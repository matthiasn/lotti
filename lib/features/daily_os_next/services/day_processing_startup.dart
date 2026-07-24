import 'dart:io';

import 'package:lotti/features/daily_os_next/database/day_processing_db.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_legacy_file_store.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_outbox_migration.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_outbox_repository.dart';
import 'package:path/path.dart' as path;

/// Directory the pre-ADR-0044 file-per-job outbox wrote to.
///
/// Only the migration reads it now. It stays on disk for one release after the
/// cutover as a rollback path, then goes.
const String legacyDayProcessingOutboxDirectory = '.day_processing_outbox';

/// Prepares the day-processing outbox for use and returns its repository.
///
/// Call once during app start, **before** `DayProcessingRuntime.start()` and
/// before any enqueue path is wired up. That ordering is the write barrier the
/// ADR 0044 cutover depends on: a database transaction cannot span the
/// filesystem, so a job written to the old store after the import but before
/// the sentinel would become invisible the moment the repository switches to
/// the table.
///
/// Returns the repository rather than registering it, so the caller owns
/// service-locator concerns and this stays unit-testable.
Future<DayProcessingOutboxRepository> initializeDayProcessingOutbox({
  required DayProcessingDb db,
  required Directory documentsDirectory,
}) async {
  await DayProcessingOutboxMigration(
    db: db,
    legacyStore: DayProcessingLegacyFileStore(
      rootDirectory: Directory(
        path.join(documentsDirectory.path, legacyDayProcessingOutboxDirectory),
      ),
    ),
  ).run();
  return DayProcessingOutboxRepository(db: db);
}
