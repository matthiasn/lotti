import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:drift/drift.dart';
import 'package:drift/isolate.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:path/path.dart' as p;

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

    final file = await getDatabaseFile(fileName);
    debugPrint('DB LazyDatabase ${file.path}');

    return NativeDatabase(file);
  });
}

Future<DriftIsolate> createDriftIsolate(String dbFileName) async {
  // this method is called from the main isolate. Since we can't use
  // getApplicationDocumentsDirectory on a background isolate, we calculate
  // the database path in the foreground isolate and then inform the
  // background isolate about the path.
  final dir = getDocumentsDirectory();
  final path = p.join(dir.path, dbFileName);
  final receivePort = ReceivePort();

  await Isolate.spawn(
    _startBackground,
    _IsolateStartRequest(receivePort.sendPort, path),
  );

  // _startBackground will send the DriftIsolate to this ReceivePort
  return await receivePort.first as DriftIsolate;
}

void _startBackground(_IsolateStartRequest request) {
  // this is the entry point from the background isolate! Let's create
  // the database from the path we received
  final executor = NativeDatabase(File(request.targetPath));
  // we're using DriftIsolate.inCurrent here as this method already runs on a
  // background isolate. If we used DriftIsolate.spawn, a third isolate would be
  // started which is not what we want!
  final driftIsolate = DriftIsolate.inCurrent(
    () => DatabaseConnection(executor),
  );
  // inform the starting isolate about this, so that it can call .connect()
  request.sendDriftIsolate.send(driftIsolate);
}

// used to bundle the SendPort and the target path, since isolate entry point
// functions can only take one parameter.
class _IsolateStartRequest {
  _IsolateStartRequest(
    this.sendDriftIsolate,
    this.targetPath,
  );

  final SendPort sendDriftIsolate;
  final String targetPath;
}

DatabaseConnection getDatabaseConnection(String dbFileName) {
  return DatabaseConnection.delayed(
    Future.sync(() async {
      final isolate = await getIt<Future<DriftIsolate>>(
        instanceName: dbFileName,
      );
      return isolate.connect();
    }),
  );
}

DatabaseConnection getDbConnFromIsolate(DriftIsolate isolate) {
  return DatabaseConnection.delayed(
    Future.sync(() async {
      return isolate.connect();
    }),
  );
}
