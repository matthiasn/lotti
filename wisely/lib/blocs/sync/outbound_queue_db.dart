import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sqflite/sqflite.dart';
import 'package:wisely/utils/image_utils.dart';

import 'outbound_queue_state.dart';

class OutboundQueueDb {
  late final Future<Database> _database;

  OutboundQueueDb() {
    _database = Future<Database>(() async {
      final transaction = Sentry.startTransaction('OutboundQueueDb()', 'task');
      try {
        String createDbStatement =
            await rootBundle.loadString('assets/sqlite/create_outbound_db.sql');
        String dbPath = join(await getDatabasesPath(), 'outbound.db');
        debugPrint('OutboundQueueCubit DB Path: $dbPath');

        Database database = await openDatabase(
          dbPath,
          onCreate: (db, version) async {
            List<String> scripts = createDbStatement.split(";");
            for (String line in scripts) {
              if (line.isNotEmpty) {
                debugPrint(line.trim());
                db.execute(line.trim());
              }
            }
          },
          version: 1,
        );
        debugPrint('OutboundQueueCubit opened: $_database');
        await transaction.finish();

        return database;
      } catch (exception, stackTrace) {
        await Sentry.captureException(exception, stackTrace: stackTrace);
        await transaction.finish();
        return Future.error(exception);
      }
    });
  }

  Future<void> openDb() async {
    await _database;
  }

  Future<void> queueInsert(
    String encryptedMessage,
    String subject, {
    String? encryptedFilePath,
  }) async {
    final transaction = Sentry.startTransaction('insert()', 'task');
    try {
      final db = await _database;

      OutboundQueueRecord dbRecord = OutboundQueueRecord(
        encryptedMessage: encryptedMessage,
        encryptedFilePath: getRelativeAssetPath(encryptedFilePath),
        subject: subject,
        status: OutboundMessageStatus.pending,
        retries: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await db.insert(
        'outbound',
        dbRecord.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (exception, stackTrace) {
      await Sentry.captureException(exception, stackTrace: stackTrace);
    }
    await transaction.finish();
  }

  Future<void> update(
    OutboundQueueRecord prev,
    OutboundMessageStatus status,
    int retries,
  ) async {
    final transaction = Sentry.startTransaction('update()', 'task');
    try {
      final db = await _database;

      OutboundQueueRecord dbRecord = OutboundQueueRecord(
        id: prev.id,
        encryptedMessage: prev.encryptedMessage,
        subject: prev.subject,
        status: status,
        retries: retries,
        createdAt: prev.createdAt,
        updatedAt: DateTime.now(),
        encryptedFilePath: prev.encryptedFilePath,
      );

      await db.insert(
        'outbound',
        dbRecord.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (exception, stackTrace) {
      await Sentry.captureException(exception, stackTrace: stackTrace);
    }
    await transaction.finish();
  }

  Future<List<OutboundQueueRecord>> oldestEntries() async {
    final transaction = Sentry.startTransaction('oldestEntries()', 'task');
    List<Map<String, dynamic>> maps = [];
    try {
      final db = await _database;
      maps = await db.query(
        'outbound',
        orderBy: 'created_at',
        limit: 1,
        where: 'status = ?',
        whereArgs: [OutboundMessageStatus.pending.index],
      );
    } catch (exception, stackTrace) {
      await Sentry.captureException(exception, stackTrace: stackTrace);
    }
    await transaction.finish();

    return List.generate(maps.length, (i) {
      return OutboundQueueRecord.fromMap(maps[i]);
    });
  }
}
