import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:wisely/db/entry.dart';

class Persistence {
  late final database;

  Persistence() {
    openDb();
  }

  void openDb() async {
    database = openDatabase(
      join(await getDatabasesPath(), 'wisely.db'),
      onCreate: (db, version) {
        return db.execute(
          '''CREATE TABLE entries(
               id INTEGER PRIMARY KEY,
               timestamp Integer,
               plainText TEXT,
               latitude REAL,
               longitude REAL
             )''',
        );
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
