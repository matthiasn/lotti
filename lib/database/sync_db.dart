import 'package:drift/drift.dart';
import 'package:lotti/blocs/sync/outbox_state.dart';
import 'package:lotti/database/common.dart';

part 'sync_db.g.dart';

const syncDbFileName = 'sync.sqlite';

@DataClassName('OutboxItem')
class Outbox extends Table {
  IntColumn get id => integer().autoIncrement()();

  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(Constant(DateTime.now()))();

  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').withDefault(Constant(DateTime.now()))();

  IntColumn get status =>
      integer().withDefault(Constant(OutboxStatus.pending.index))();

  IntColumn get retries => integer().withDefault(const Constant(0))();
  TextColumn get message => text()();
  TextColumn get subject => text()();
  TextColumn get filePath => text().named('file_path').nullable()();
}

@DriftDatabase(tables: [Outbox])
class SyncDatabase extends _$SyncDatabase {
  SyncDatabase({this.inMemoryDatabase = false})
      : super(
          openDbConnection(
            syncDbFileName,
            inMemoryDatabase: inMemoryDatabase,
          ),
        );

  SyncDatabase.connect(super.c) : super.connect();

  bool inMemoryDatabase = false;

  Future<int> updateOutboxItem(OutboxCompanion item) {
    return (update(outbox)..where((t) => t.id.equals(item.id.value)))
        .write(item);
  }

  Future<int> addOutboxItem(OutboxCompanion entry) {
    return into(outbox).insert(entry);
  }

  Future<List<OutboxItem>> get allOutboxItems => select(outbox).get();

  Future<List<OutboxItem>> oldestOutboxItems(int limit) {
    return (select(outbox)
          ..where((t) => t.status.equals(OutboxStatus.pending.index))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)])
          ..limit(limit))
        .get();
  }

  Stream<List<OutboxItem>> watchOutboxItems({
    int limit = 1000,
    List<OutboxStatus> statuses = const [
      OutboxStatus.pending,
      OutboxStatus.error,
      OutboxStatus.sent,
    ],
  }) {
    return (select(outbox)
          ..where(
            (t) => t.status
                .isIn(statuses.map((OutboxStatus status) => status.index)),
          )
          ..orderBy([
            (t) => OrderingTerm(
                  expression: t.createdAt,
                  mode: OrderingMode.desc,
                ),
          ])
          ..limit(limit))
        .watch();
  }

  Stream<int> watchOutboxCount() {
    return (select(outbox)
          ..where(
            (t) => t.status.equals(OutboxStatus.pending.index),
          ))
        .watch()
        .map((res) => res.length);
  }

  Future<int> deleteOutboxItems() {
    return delete(outbox).go();
  }

  @override
  int get schemaVersion => 1;
}
