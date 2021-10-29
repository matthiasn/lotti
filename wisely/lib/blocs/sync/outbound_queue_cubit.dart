import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:mutex/mutex.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:wisely/blocs/sync/classes.dart';
import 'package:wisely/blocs/sync/encryption_cubit.dart';
import 'package:wisely/blocs/sync/imap_cubit.dart';
import 'package:wisely/classes/sync_message.dart';
import 'package:wisely/sync/encryption.dart';
import 'package:wisely/sync/encryption_salsa.dart';
import 'package:wisely/utils/image_utils.dart';

import 'outbound_queue_state.dart';

class OutboundQueueCubit extends Cubit<OutboundQueueState> {
  late final EncryptionCubit _encryptionCubit;
  late final ImapCubit _imapCubit;
  final sendMutex = Mutex();

  late final Future<Database> _database;
  late String? _b64Secret;

  OutboundQueueCubit({
    required EncryptionCubit encryptionCubit,
    required ImapCubit imapCubit,
  }) : super(OutboundQueueState.initial()) {
    _encryptionCubit = encryptionCubit;
    _imapCubit = imapCubit;
    openDb();
  }

  Future<void> openDb() async {
    String createDbStatement =
        await rootBundle.loadString('assets/sqlite/create_outbound_db.sql');
    emit(OutboundQueueState.loading());

    String dbPath = join(await getDatabasesPath(), 'outbound.db');
    print('OutboundQueueCubit DB Path: ${dbPath}');

    _database = openDatabase(
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
    SyncConfig? syncConfig = await _encryptionCubit.loadSyncConfig();

    if (syncConfig != null) {
      _b64Secret = syncConfig.sharedSecret;
    }
    emit(OutboundQueueState.online());
    _startPolling();
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
    print('update $dbRecord');

    await db.insert(
      'outbound',
      dbRecord.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  void sendNext() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult != ConnectivityResult.none && !sendMutex.isLocked) {
      List<OutboundQueueRecord> unprocessed = await oldestEntries();
      if (unprocessed.isNotEmpty) {
        sendMutex.acquire();
        OutboundQueueRecord nextPending = unprocessed.first;
        bool saveSuccess = await _imapCubit.saveImap(
          nextPending.encryptedMessage,
          nextPending.subject,
          encryptedFilePath: nextPending.encryptedFilePath,
        );
        if (saveSuccess) {
          update(
            nextPending,
            OutboundMessageStatus.sent,
            nextPending.retries,
          );
        } else {
          update(
            nextPending,
            OutboundMessageStatus.pending,
            nextPending.retries + 1,
          );
        }
        sendMutex.release();
        sendNext();
      }
    }
  }

  void _startPolling() async {
    Timer.periodic(const Duration(seconds: 10), (timer) async {
      sendNext();
    });
  }

  Future<List<OutboundQueueRecord>> entries() async {
    final db = await _database;
    final List<Map<String, dynamic>> maps = await db.query('outbound');

    return List.generate(maps.length, (i) {
      return OutboundQueueRecord.fromMap(maps[i]);
    });
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

  Future<void> enqueueMessage(
    SyncMessage syncMessage, {
    File? attachment,
  }) async {
    String jsonString = json.encode(syncMessage);
    String subject = syncMessage.vectorClock.toString();

    if (_b64Secret != null) {
      String encryptedMessage = encryptSalsa(jsonString, _b64Secret);
      if (attachment != null) {
        int fileLength = attachment.lengthSync();
        if (fileLength > 0) {
          File encryptedFile = File('${attachment.path}.aes');
          await encryptFile(attachment, encryptedFile, _b64Secret!);
          await insert(encryptedMessage, subject,
              encryptedFilePath: encryptedFile.path);
        }
      } else {
        await insert(encryptedMessage, subject);
      }
    }
    sendNext();
  }
}
