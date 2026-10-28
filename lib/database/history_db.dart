import 'dart:io';

import 'package:drift/drift.dart';
import 'package:lotti/database/common.dart';

part 'history_db.g.dart';

const historyDbFileName = 'history.sqlite';

/// Device-local, append-only log of the entities the user opened, read by the
/// history page.
///
/// Separate from the SettingsDb k/v store for the reason the onboarding log
/// is: an unbounded log needs indexed, paged reads and its own migration
/// lifecycle, and SettingsDb is tuned for tiny reads on the main isolate.
///
/// Rows are never updated. [appendEntry] adds one; [deleteEntry] removes one
/// for good — there is no tombstone, because nothing syncs this file.
@DriftDatabase(include: {'history_db.drift'})
class HistoryDb extends _$HistoryDb {
  HistoryDb({
    this.inMemoryDatabase = false,
    // One small insert per navigation, never on a latency-sensitive path.
    bool background = true,
    Future<Directory> Function()? documentsDirectoryProvider,
    Future<Directory> Function()? tempDirectoryProvider,
  }) : super(
         openDbConnection(
           historyDbFileName,
           inMemoryDatabase: inMemoryDatabase,
           background: background,
           documentsDirectoryProvider: documentsDirectoryProvider,
           tempDirectoryProvider: tempDirectoryProvider,
         ),
       );

  final bool inMemoryDatabase;

  /// The schema this build writes. A restored backup may carry an
  /// older schema, which Drift migrates, but never a newer one.
  static const int currentSchemaVersion = 1;

  @override
  int get schemaVersion => currentSchemaVersion;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(onCreate: (m) => m.createAll());
  }

  /// Appends one visit and returns its row id. Ids only grow, so they order
  /// the log the way it was written.
  Future<int> appendEntry({
    required String kind,
    required String entityId,
    required String route,
    required DateTime visitedAt,
  }) => into(historyEntries).insert(
    HistoryEntriesCompanion.insert(
      kind: kind,
      entityId: entityId,
      route: route,
      visitedAt: visitedAt,
    ),
  );

  /// The most recently appended visit, or null for an empty log.
  Future<HistoryEntryRow?> latestEntry() =>
      latestHistoryEntry().getSingleOrNull();

  /// Up to [limit] visits, newest first, strictly older than the row
  /// [beforeId] when given — keyset paging, so a row deleted or appended
  /// between two pages neither repeats nor skips one.
  ///
  /// [from] is inclusive and [to] exclusive; either may be null for an open
  /// end.
  Future<List<HistoryEntryRow>> entriesPage({
    required int limit,
    int? beforeId,
    DateTime? from,
    DateTime? to,
  }) {
    final query = select(historyEntries)
      ..where((t) {
        final conditions = <Expression<bool>>[
          if (beforeId != null) t.id.isSmallerThanValue(beforeId),
          if (from != null) t.visitedAt.isBiggerOrEqualValue(from),
          if (to != null) t.visitedAt.isSmallerThanValue(to),
        ];
        return conditions.isEmpty
            ? const Constant(true)
            : Expression.and(conditions);
      })
      ..orderBy([(t) => OrderingTerm.desc(t.id)])
      ..limit(limit);
    return query.get();
  }

  /// Removes the visit [id] permanently. Returns the number of rows deleted.
  Future<int> deleteEntry(int id) =>
      (delete(historyEntries)..where((t) => t.id.equals(id))).go();
}
