import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:mutex/mutex.dart';
import 'package:wisely/blocs/sync/classes.dart';
import 'package:wisely/blocs/sync/encryption_cubit.dart';
import 'package:wisely/blocs/sync/imap_cubit.dart';
import 'package:wisely/blocs/sync/vector_clock_cubit.dart';
import 'package:wisely/classes/sync_message.dart';
import 'package:wisely/sync/encryption.dart';
import 'package:wisely/sync/encryption_salsa.dart';

import 'outbound_queue_db.dart';
import 'outbound_queue_state.dart';

class OutboundQueueCubit extends Cubit<OutboundQueueState> {
  late final EncryptionCubit _encryptionCubit;
  late final ImapCubit _imapCubit;
  late final VectorClockCubit _vectorClockCubit;

  final sendMutex = Mutex();

  late final OutboundQueueDb _db;
  late String? _b64Secret;

  OutboundQueueCubit({
    required EncryptionCubit encryptionCubit,
    required ImapCubit imapCubit,
    required VectorClockCubit vectorClockCubit,
  }) : super(OutboundQueueState.initial()) {
    _encryptionCubit = encryptionCubit;
    _imapCubit = imapCubit;
    _vectorClockCubit = vectorClockCubit;
    _db = OutboundQueueDb();
    init();
  }

  Future<void> init() async {
    await _db.openDb();
    SyncConfig? syncConfig = await _encryptionCubit.loadSyncConfig();

    if (syncConfig != null) {
      _b64Secret = syncConfig.sharedSecret;
    }
    emit(OutboundQueueState.online());
    _startPolling();
  }

  void sendNext() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult != ConnectivityResult.none && !sendMutex.isLocked) {
      List<OutboundQueueRecord> unprocessed = await _db.oldestEntries();
      if (unprocessed.isNotEmpty) {
        sendMutex.acquire();
        OutboundQueueRecord nextPending = unprocessed.first;
        bool saveSuccess = await _imapCubit.saveImap(
          nextPending.encryptedMessage,
          nextPending.subject,
          encryptedFilePath: nextPending.encryptedFilePath,
        );
        if (saveSuccess) {
          _db.update(
            nextPending,
            OutboundMessageStatus.sent,
            nextPending.retries,
          );
        } else {
          _db.update(
            nextPending,
            nextPending.retries < 10
                ? OutboundMessageStatus.pending
                : OutboundMessageStatus.error,
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

  Future<void> enqueueMessage(
    SyncMessage syncMessage, {
    File? attachment,
  }) async {
    String jsonString = json.encode(syncMessage);
    String subject = syncMessage.map(
      journalEntity: (SyncJournalEntity message) =>
          message.vectorClock.toString(),
      journalDbEntity: (SyncJournalDbEntities message) =>
          message.journalEntity.vectorClock.toString(),
    );

    if (_b64Secret != null) {
      String encryptedMessage = encryptSalsa(jsonString, _b64Secret);
      if (attachment != null) {
        int fileLength = attachment.lengthSync();
        if (fileLength > 0) {
          File encryptedFile = File('${attachment.path}.aes');
          await encryptFile(attachment, encryptedFile, _b64Secret!);
          await _db.insert(encryptedMessage, subject,
              encryptedFilePath: encryptedFile.path);
        }
      } else {
        await _db.insert(encryptedMessage, subject);
      }
    }
    sendNext();
  }
}
