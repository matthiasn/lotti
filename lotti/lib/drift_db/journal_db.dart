import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'journal_db.g.dart';

@DriftDatabase(
  include: {'journal_tables.drift'},
)
class JournalDb extends _$JournalDb {
  JournalDb() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  Future<int> addJournalEntry(JournalEntry entry) {
    return into(journal).insert(entry);
  }

  Future<int> updateJournalEntry(JournalCompanion entry) {
    return (update(journal)..where((t) => t.id.equals(entry.id.value)))
        .write(entry);
  }

  Future<List<JournalEntry>> latestEntries(int limit) {
    return (select(journal)
          ..orderBy([(t) => OrderingTerm(expression: t.dateFrom)])
          ..limit(limit))
        .get();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'db.sqlite'));
    return NativeDatabase(file);
  });
}
