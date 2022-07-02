import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<File> getDatabaseFile(String dbFileName) async {
  final dbFolder = await getApplicationDocumentsDirectory();
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

    final file = await getDatabaseFile('db.sqlite');
    debugPrint('DB LazyDatabase ${file.path}');

    return NativeDatabase(file);
  });
}
