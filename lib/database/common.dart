import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:intl/intl.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

Future<File> getDatabaseFile(String dbFileName) async {
  final dbFolder = getDocumentsDirectory();
  return File(p.join(dbFolder.path, dbFileName));
}

Future<void> createDbBackup(String fileName) async {
  final file = await getDatabaseFile(fileName);
  final ts = DateFormat('yyyy-MM-dd_HH-mm-ss-S').format(DateTime.now());
  final backupDir =
      await Directory('${file.parent.path}/backup').create(recursive: true);
  await file.copy('${backupDir.path}/db.$ts.sqlite');
}

LazyDatabase openDbConnection(
  String fileName, {
  bool inMemoryDatabase = false,
}) {
  return LazyDatabase(() async {
    if (inMemoryDatabase) {
      return NativeDatabase.memory();
    }

    final dbFolder = await findDocumentsDirectory();
    final file = File(p.join(dbFolder.path, fileName));

    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }

    sqlite3.tempDirectory = (await getTemporaryDirectory()).path;

    final database = NativeDatabase.createInBackground(file);

    return database;
  });
}
