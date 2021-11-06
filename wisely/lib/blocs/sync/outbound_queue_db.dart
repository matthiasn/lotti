import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:wisely/utils/image_utils.dart';

import 'outbound_queue_state.dart';

class OutboundQueueDb {
  late final Future<Database> _database;

  OutboundQueueDb() {
    _database = Future<Database>(() async {
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
      return database;
    });
  }

  Future<void> openDb() async {
    await _database;
  }

  Future<void> insert(
    String encryptedMessage,
    String subject, {
    String? encryptedFilePath,
  }) async {
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
  }

  Future<void> update(
    OutboundQueueRecord prev,
    OutboundMessageStatus status,
    int retries,
  ) async {
    final db = await _database;

    OutboundQueueRecord dbRecord = OutboundQueueRecord(
      id: prev.id,
      encryptedMessage: prev.encryptedMessage,
      subject: prev.subject,
      status: status,
      retries: retries,
      createdAt: prev.createdAt,
      updatedAt: DateTime.now(),
    );

    await db.insert(
      'outbound',
      dbRecord.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<OutboundQueueRecord>> oldestEntries() async {
    final db = await _database;
    final List<Map<String, dynamic>> maps = await db.query(
      'outbound',
      orderBy: 'created_at',
      limit: 1,
      where: 'status = ?',
      whereArgs: [OutboundMessageStatus.pending.index],
    );

    return List.generate(maps.length, (i) {
      return OutboundQueueRecord.fromMap(maps[i]);
    });
  }
}
