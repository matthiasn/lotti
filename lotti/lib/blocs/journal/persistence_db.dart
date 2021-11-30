import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:lotti/classes/geolocation.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:path/path.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

var uuid = const Uuid();
const journalTable = 'journal';

class PersistenceDb {
  late final Future<Database> _database;

  PersistenceDb() {
    _database = Future<Database>(() async {
      try {
        String createDbStatement =
            await rootBundle.loadString('assets/sqlite/create_journal_db.sql');

        String dbPath = join(await getDatabasesPath(), 'journal.db');
        debugPrint('PersistenceCubit DB Path: $dbPath');

        Database database = await openDatabase(
          dbPath,
          onCreate: (db, version) async {
            List<String> scripts = createDbStatement.split(";");
            for (String line in scripts) {
              if (line.isNotEmpty) {
                db.execute(line.trim());
              }
            }
            debugPrint('PersistenceCubit database created.');
          },
          version: 1,
        );
        debugPrint('PersistenceCubit opened: $_database');
        return database;
      } catch (exception, stackTrace) {
        await Sentry.captureException(exception, stackTrace: stackTrace);
        return Future.error(exception);
      }
    });
  }

  Future<void> openDb() async {
    await _database;
  }

  JournalRecord _journalEntityToDbRecord(JournalEntity journalEntity) {
    final DateTime createdAt = journalEntity.meta.createdAt;
    final subtype = journalEntity.maybeMap(
      quantitative: (qd) => qd.data.dataType,
      survey: (SurveyEntry surveyEntry) =>
          surveyEntry.data.taskResult.identifier,
      orElse: () => '',
    );

    Geolocation? geolocation;
    journalEntity.mapOrNull(
      journalAudio: (item) => geolocation = item.geolocation,
      journalImage: (item) => geolocation = item.geolocation,
      journalEntry: (item) => geolocation = item.geolocation,
    );

    String id = journalEntity.meta.id;
    JournalRecord dbRecord = JournalRecord(
      id: id,
      createdAt: createdAt,
      updatedAt: createdAt,
      dateFrom: journalEntity.meta.dateFrom,
      dateTo: journalEntity.meta.dateTo,
      type: journalEntity.runtimeType.toString(),
      subtype: subtype,
      serialized: json.encode(journalEntity),
      schemaVersion: 0,
      longitude: geolocation?.longitude,
      latitude: geolocation?.latitude,
      geohashString: geolocation?.geohashString,
    );

    return dbRecord;
  }

  Future<bool> insert(JournalEntity journalEntity) async {
    try {
      final db = await _database;
      JournalRecord dbRecord = _journalEntityToDbRecord(journalEntity);
      String id = dbRecord.id;

      List<Map> maps = await db.query(journalTable,
          columns: ['id'], where: 'id = ?', whereArgs: [id]);
      if (maps.isEmpty) {
        var res = await db.insert(journalTable, dbRecord.toMap());

        debugPrint('PersistenceDb inserted: $id $res');
        return true;
      } else {
        debugPrint('PersistenceDb already exists: $id');
      }
    } catch (exception, stackTrace) {
      await Sentry.captureException(exception, stackTrace: stackTrace);
    }
    return false;
  }

  Future<bool> update(JournalEntity journalEntity) async {
    try {
      final db = await _database;
      JournalRecord dbRecord = _journalEntityToDbRecord(journalEntity);
      String id = dbRecord.id;

      List<Map> maps = await db.query(journalTable,
          columns: ['id'], where: 'id = ?', whereArgs: [id]);
      if (maps.isEmpty) {
        insert(journalEntity);
      } else {
        int res = await db.update(journalTable, dbRecord.toMap(),
            where: 'id = ?', whereArgs: [id]);
        debugPrint('PersistenceDb updated: $id $res');
      }
      return true;
    } catch (exception, stackTrace) {
      await Sentry.captureException(exception, stackTrace: stackTrace);
      debugPrint('DB update exception: $exception');
    }
    return false;
  }

  Future<List<JournalRecord>> journalEntries(int n) async {
    List<Map<String, dynamic>> maps = [];
    try {
      final db = await _database;
      maps = await db.query(
        journalTable,
        orderBy: 'date_from DESC',
        limit: n,
      );
    } catch (exception, stackTrace) {
      await Sentry.captureException(exception, stackTrace: stackTrace);
    }

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
