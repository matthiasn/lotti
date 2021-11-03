import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:wisely/classes/journal_entities.dart';

var uuid = const Uuid();

class PersistenceDb {
  late final Future<Database> _database;
  PersistenceDb();

  Future<void> openDb() async {
    String createDbStatement =
        await rootBundle.loadString('assets/sqlite/create_journal_db.sql');

    String dbPath = join(await getDatabasesPath(), 'journal.db');
    debugPrint('PersistenceCubit DB Path: $dbPath');

    _database = openDatabase(
      dbPath,
      onCreate: (db, version) async {
        List<String> scripts = createDbStatement.split(";");
        for (String line in scripts) {
          if (line.isNotEmpty) {
            debugPrint(line.trim());
            db.execute(line.trim());
          }
        }
        debugPrint('PersistenceCubit database created.');
      },
      version: 1,
    );
    debugPrint('PersistenceCubit opened: $_database');
  }

  Future<void> insert(
    JournalEntity journalEntity,
  ) async {
    final db = await _database;
    final String id = uuid.v1();
    final DateTime now = DateTime.now();

    JournalRecord dbRecord = JournalRecord(
      id: id,
      createdAt: now,
      updatedAt: now,
      startTime: now,
      endTime: now,
      type: journalEntity.runtimeType.toString(),
      serialized: journalEntity.toString(),
      schemaVersion: 0,
    );

    await db.insert(
      'outbound',
      dbRecord.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<JournalRecord>> journalEntries(int n) async {
    final db = await _database;
    final List<Map<String, dynamic>> maps = await db.query(
      'outbound',
      orderBy: 'created_at',
      limit: n,
    );

    return List.generate(maps.length, (i) {
      return JournalRecord.fromMap(maps[i]);
    });
  }
}

class JournalRecord {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime startTime;
  final DateTime endTime;
  final String type;
  final String? subtype;
  final String serialized;
  final int schemaVersion;
  final String? plainText;
  final double? latitude;
  final double? longitude;
  final String? geohashString;
  final int? geohashInt;

  JournalRecord({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.startTime,
    required this.endTime,
    required this.type,
    this.subtype,
    required this.serialized,
    required this.schemaVersion,
    this.plainText,
    this.latitude,
    this.longitude,
    this.geohashString,
    this.geohashInt,
  });

  @override
  String toString() {
    return '$id $type $subtype $createdAt';
  }

  factory JournalRecord.fromMap(Map<String, dynamic> data) => JournalRecord(
        id: data['id'],
        createdAt: DateTime.fromMillisecondsSinceEpoch(data['created_at']),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(data['updated_at']),
        startTime: DateTime.fromMillisecondsSinceEpoch(data['start_time']),
        endTime: DateTime.fromMillisecondsSinceEpoch(data['end_time']),
        type: data['type'],
        subtype: data['subtype'],
        serialized: data['serialized'],
        schemaVersion: data['schema_version'],
        plainText: data['plain_text'],
        latitude: data['latitude'],
        longitude: data['longitude'],
        geohashString: data['geohash_string'],
        geohashInt: data['geohash_int'],
      );

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'start_time': startTime.millisecondsSinceEpoch,
      'end_time': endTime.millisecondsSinceEpoch,
      'type': type,
      'subtype': subtype,
      'serialized': serialized,
      'schema_version': schemaVersion,
      'plain_text': plainText,
      'latitude': latitude,
      'longitude': longitude,
      'geohash_string': geohashString,
      'geohash_int': geohashInt,
    };
  }
}
