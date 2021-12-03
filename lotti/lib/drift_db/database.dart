import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

@DataClassName('JournalEntry')
class Journal extends Table {
  TextColumn get id => text()();

  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(Constant(DateTime.now()))();

  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').withDefault(Constant(DateTime.now()))();

  DateTimeColumn get dateFrom => dateTime().named('date_from')();
  DateTimeColumn get dateTo => dateTime().named('date_to')();

  TextColumn get serialized => text()();
  TextColumn get plainText => text().named('plain_text').nullable()();

  TextColumn get type => text()();
  TextColumn get subType => text()();

  IntColumn get schemaVersion => integer().withDefault(const Constant(0))();

  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  IntColumn get geohashInt => integer().named('geohash_int').nullable()();
  TextColumn get geohashString => text().named('geohash_string')();

  @override
  Set<Column> get primaryKey => {id};
}

class Conflicts extends Table {
  TextColumn get id => text()();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();
  TextColumn get serialized => text()();
  IntColumn get status => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'drift.sqlite'));
    return NativeDatabase(file);
  });
}

@DriftDatabase(tables: [Conflicts])
class MyDriftDatabase extends _$MyDriftDatabase {
  MyDriftDatabase() : super(_openConnection());

  Future<int> addConflict(Conflict conflict) {
    return into(conflicts).insert(conflict);
  }

  @override
  int get schemaVersion => 1;
}
