import 'dart:io';

import 'package:drift/drift.dart';
import 'package:lotti/database/common.dart';

part 'day_processing_db.g.dart';

const dayProcessingDbFileName = 'day_processing.sqlite';

/// Key of the file-to-table cutover record in `day_processing_migrations`.
const dayProcessingFileImportMigrationKey = 'file_outbox_import';

/// Device-local durable store for Daily OS processing intents (ADR 0044).
///
/// Replaces the file-per-job outbox introduced by ADR 0031. Kept out of the
/// journal and agent databases because every column here describes *this*
/// device's progress — claim tokens, leases, attempt counters — and must never
/// sync. Terminal rows are retained as the Activity ledger; the partial
/// indexes in `day_processing_db.drift` keep that ledger off the drain path.
@DriftDatabase(include: {'day_processing_db.drift'})
class DayProcessingDb extends _$DayProcessingDb {
  DayProcessingDb({
    this.inMemoryDatabase = false,
    bool background = true,
    // The outbox is a small queue read on the UI path; a single read isolate
    // is sufficient and keeps the connection footprint low.
    int readPool = 1,
    Future<Directory> Function()? documentsDirectoryProvider,
    Future<Directory> Function()? tempDirectoryProvider,
  }) : super(
         openDbConnection(
           dayProcessingDbFileName,
           inMemoryDatabase: inMemoryDatabase,
           background: background,
           readPool: readPool,
           documentsDirectoryProvider: documentsDirectoryProvider,
           tempDirectoryProvider: tempDirectoryProvider,
         ),
       );

  final bool inMemoryDatabase;

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration =>
      MigrationStrategy(onCreate: (m) => m.createAll());
}
