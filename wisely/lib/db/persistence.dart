import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:wisely/db/entry.dart';

class Persistence {
  late final database;

  Persistence() {
    openDb();
  }

  void openDb() async {
    String createDbStatement =
        await rootBundle.loadString('assets/sqlite/create_db.sql');

    String dbPath = join(await getDatabasesPath(), 'wisely.db');
    print('DB Path: ${dbPath}');

    database = openDatabase(
      dbPath,
      onCreate: (db, version) async {
        List<String> scripts = createDbStatement.split(";");
        scripts.forEach((v) {
          if (v.isNotEmpty) {
            print(v.trim());
            db.execute(v.trim());
          }
        });
      },
      version: 1,
    );
  }

  Future<void> insertEntry(Entry entry) async {
    final db = await database;

    await db.insert(
      'entries',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Entry>> entries() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('entries');

    return List.generate(maps.length, (i) {
      return Entry(
        id: maps[i]['id'],
        timestamp: maps[i]['timestamp'],
        plainText: maps[i]['plainText'],
        latitude: maps[i]['latitude'],
        longitude: maps[i]['longitude'],
      );
    });
  }
}
