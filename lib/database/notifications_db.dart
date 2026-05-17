import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:lotti/classes/notification_entity.dart';
import 'package:lotti/database/common.dart';
import 'package:lotti/features/notifications/model/notification_merge.dart';
import 'package:lotti/features/sync/vector_clock.dart';

part 'notifications_db.g.dart';

const notificationsDbFileName = 'notifications.sqlite';

@DriftDatabase(include: {'notifications_db.drift'})
class NotificationsDb extends _$NotificationsDb {
  NotificationsDb({
    this.inMemoryDatabase = false,
    bool background = true,
    int readPool = 2,
    Future<Directory> Function()? documentsDirectoryProvider,
    Future<Directory> Function()? tempDirectoryProvider,
  }) : super(
         openDbConnection(
           notificationsDbFileName,
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
  MigrationStrategy get migration {
    return MigrationStrategy(onCreate: (m) => m.createAll());
  }

  Future<NotificationEntity?> notificationById(String id) async {
    final row = await notificationRowById(id).getSingleOrNull();
    if (row == null) return null;
    return notificationFromDbEntity(row);
  }

  Future<List<NotificationEntity>> dueNow(DateTime now) async {
    final rows = await dueNotificationRows(now).get();
    return rows.map(notificationFromDbEntity).toList();
  }

  Future<List<NotificationEntity>> upcoming(DateTime now) async {
    final rows = await upcomingNotificationRows(now).get();
    return rows.map(notificationFromDbEntity).toList();
  }

  Future<List<NotificationEntity>> forLinkedEntity(String id) async {
    final rows = await notificationRowsForLinkedEntity(id).get();
    return rows.map(notificationFromDbEntity).toList();
  }

  Future<int> unseenCount(DateTime now) async {
    final row = await customSelect(
      '''
          SELECT COUNT(*) AS amount
          FROM notifications
          WHERE scheduled_for <= ?
            AND seen_at IS NULL
            AND acted_on_at IS NULL
            AND deleted_at IS NULL
          ''',
      variables: [Variable<DateTime>(now)],
      readsFrom: {notifications},
    ).getSingle();
    return row.read<int>('amount');
  }

  // Read-modify-write under a Drift transaction so concurrent callers cannot
  // interleave and overwrite each other's vector-clock or lifecycle updates.
  Future<NotificationEntity?> upsertNotification(
    NotificationEntity incoming,
  ) {
    return transaction(() async {
      final existing = await notificationById(incoming.id);
      final merged = existing == null
          ? incoming
          : NotificationMerge.mergeFull(existing, incoming);

      if (existing != null && NotificationMerge.same(existing, merged)) {
        return null;
      }

      await into(
        notifications,
      ).insertOnConflictUpdate(notificationToDbEntity(merged));
      return merged;
    });
  }

  Future<NotificationStateMergeResult> mergeState({
    required String id,
    DateTime? seenAt,
    DateTime? actedOnAt,
    DateTime? deletedAt,
    VectorClock? vectorClock,
    String? originatingHostId,
  }) {
    return transaction(() async {
      final existing = await notificationById(id);
      if (existing == null) {
        return const NotificationStateMergeResult.missing();
      }

      final merged = NotificationMerge.mergeState(
        existing,
        seenAt: seenAt,
        actedOnAt: actedOnAt,
        deletedAt: deletedAt,
        vectorClock: vectorClock,
        originatingHostId: originatingHostId,
      );
      if (NotificationMerge.same(existing, merged)) {
        return NotificationStateMergeResult(entity: existing, changed: false);
      }

      await into(
        notifications,
      ).insertOnConflictUpdate(notificationToDbEntity(merged));
      return NotificationStateMergeResult(entity: merged, changed: true);
    });
  }

  // Keyset pagination over the `id` primary key. `LIMIT/OFFSET` would re-scan
  // the first N rows on every page (quadratic for large tables); seeking by
  // `id > :lastId` keeps each page O(batchSize) using the PK index.
  Stream<List<({String id, Map<String, int>? vectorClock})>>
  streamNotificationsWithVectorClock({int batchSize = 1000}) async* {
    String? lastId;

    while (true) {
      final rows = await customSelect(
        lastId == null
            ? 'SELECT id, vector_clock FROM notifications '
                  'ORDER BY id LIMIT ?'
            : 'SELECT id, vector_clock FROM notifications '
                  'WHERE id > ? ORDER BY id LIMIT ?',
        variables: lastId == null
            ? [Variable<int>(batchSize)]
            : [Variable<String>(lastId), Variable<int>(batchSize)],
        readsFrom: {notifications},
      ).get();

      if (rows.isEmpty) break;

      final batch = rows
          .map(
            (row) => (
              id: row.read<String>('id'),
              vectorClock: _decodeVectorClockMap(
                row.read<String>('vector_clock'),
              ),
            ),
          )
          .toList();
      yield batch;
      lastId = batch.last.id;
      if (batch.length < batchSize) break;
    }
  }

  Future<int> countAllNotifications() async {
    final row = await customSelect(
      'SELECT COUNT(*) AS cnt FROM notifications',
      readsFrom: {notifications},
    ).getSingle();
    return row.read<int>('cnt');
  }

  static NotificationDbEntity notificationToDbEntity(
    NotificationEntity entity,
  ) {
    final meta = entity.meta;
    return NotificationDbEntity(
      id: meta.id,
      createdAt: meta.createdAt,
      updatedAt: meta.updatedAt,
      scheduledFor: meta.scheduledFor,
      seenAt: meta.seenAt,
      actedOnAt: meta.actedOnAt,
      deletedAt: meta.deletedAt,
      linkedEntityId: entity.linkedEntityId,
      type: entity.type,
      category: meta.category,
      vectorClock: jsonEncode(meta.vectorClock.toJson()),
      originatingHostId: meta.originatingHostId,
      serialized: jsonEncode(entity.toJson()),
    );
  }

  static NotificationEntity notificationFromDbEntity(
    NotificationDbEntity row,
  ) {
    return NotificationEntity.fromJson(
      jsonDecode(row.serialized) as Map<String, dynamic>,
    );
  }

  static Map<String, int>? _decodeVectorClockMap(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return Map<String, int>.from(decoded);
    } catch (_) {
      return null;
    }
  }
}

class NotificationStateMergeResult {
  const NotificationStateMergeResult({
    required this.entity,
    required this.changed,
  });

  const NotificationStateMergeResult.missing() : entity = null, changed = false;

  final NotificationEntity? entity;
  final bool changed;

  bool get isMissing => entity == null;
}
