import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:wisely/classes/journal_db_entities.dart';

var uuid = const Uuid();
const journalTable = 'journal';

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

  Future<bool> insert(JournalDbEntity journalDbEntity) async {
    final db = await _database;
    final DateTime createdAt = journalDbEntity.createdAt;
    final JournalDbEntityData data = journalDbEntity.data;
    final type = data.runtimeType.toString();
    final subtype = data.maybeMap(
      cumulativeQuantity: (CumulativeQuantity v) => v.dataType,
      discreteQuantity: (DiscreteQuantity v) => v.dataType,
      orElse: () => '',
    );

    if (journalDbEntity is JournalDbEntry) {
      String id = journalDbEntity.id;
      JournalRecord dbRecord = JournalRecord(
        id: id,
        createdAt: createdAt,
        updatedAt: createdAt,
        dateFrom: journalDbEntity.dateFrom,
        dateTo: journalDbEntity.dateTo,
        type: type,
        subtype: subtype,
        serialized: json.encode(journalDbEntity),
        schemaVersion: 0,
        longitude: journalDbEntity.geolocation?.longitude,
        latitude: journalDbEntity.geolocation?.latitude,
        geohashString: journalDbEntity.geolocation?.geohashString,
      );

      List<Map> maps = await db.query(journalTable,
          columns: ['id'], where: 'id = ?', whereArgs: [id]);
      if (maps.isEmpty) {
        var res = await db.insert(journalTable, dbRecord.toMap());
        debugPrint('PersistenceDb inserted: $id $res');
        return true;
      } else {
        debugPrint('PersistenceDb already exists: $id');
      }
    }
    return false;
  }

  Future<List<JournalRecord>> journalEntries(int n) async {
    final db = await _database;
    final List<Map<String, dynamic>> maps = await db.query(
      journalTable,
      orderBy: 'date_from DESC',
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
  final DateTime dateFrom;
  final DateTime dateTo;
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
    required this.dateFrom,
    required this.dateTo,
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
        dateFrom: DateTime.fromMillisecondsSinceEpoch(data['date_from']),
        dateTo: DateTime.fromMillisecondsSinceEpoch(data['date_to']),
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
      'date_from': dateFrom.millisecondsSinceEpoch,
      'date_to': dateTo.millisecondsSinceEpoch,
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
