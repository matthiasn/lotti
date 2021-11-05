import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:mutex/mutex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wisely/blocs/sync/classes.dart';
import 'package:wisely/blocs/sync/encryption_cubit.dart';
import 'package:wisely/blocs/sync/vector_clock_cubit.dart';
import 'package:wisely/classes/journal_db_entities.dart';
import 'package:wisely/classes/sync_message.dart';
import 'package:wisely/sync/encryption.dart';
import 'package:wisely/sync/encryption_salsa.dart';
import 'package:wisely/utils/audio_utils.dart';
import 'package:wisely/utils/image_utils.dart';

import 'imap_out_cubit.dart';
import 'outbound_queue_db.dart';
import 'outbound_queue_state.dart';

class OutboundQueueCubit extends Cubit<OutboundQueueState> {
  late final EncryptionCubit _encryptionCubit;
  late final ImapOutCubit _imapOutCubit;
  late final VectorClockCubit _vectorClockCubit;

  final sendMutex = Mutex();

  late final OutboundQueueDb _db;
  late String? _b64Secret;

  OutboundQueueCubit({
    required EncryptionCubit encryptionCubit,
    required ImapOutCubit imapOutCubit,
    required VectorClockCubit vectorClockCubit,
  }) : super(OutboundQueueState.initial()) {
    _encryptionCubit = encryptionCubit;
    _imapOutCubit = imapOutCubit;
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
        bool saveSuccess = await _imapOutCubit.saveImap(
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
    debugPrint('enqueueMessage: ${syncMessage.runtimeType}');
    String jsonString = json.encode(syncMessage);
    String subject = syncMessage.map(
      journalEntity: (SyncJournalEntity message) =>
          message.vectorClock.toString(),
      journalDbEntity: (SyncJournalDbEntity message) =>
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

  Future<void> enqueueMessage2(SyncMessage syncMessage) async {
    if (syncMessage is SyncJournalDbEntity) {
      debugPrint('enqueueMessage2: ${syncMessage.runtimeType}');
      String jsonString = json.encode(syncMessage);
      var docDir = await getApplicationDocumentsDirectory();

      File? attachment;
      String subject =
          'enqueueMessage2 ${syncMessage.journalEntity.vectorClock}';

      syncMessage.journalEntity.data.maybeMap(
        journalDbAudio: (JournalDbAudio audio) {
          attachment = File(AudioUtils.getAudioPath(audio, docDir));
        },
        journalDbImage: (JournalDbImage image) {
          attachment = File(getFullImagePathWithDocDir2(image, docDir));
        },
        orElse: () {},
      );

      if (_b64Secret != null) {
        String encryptedMessage = encryptSalsa(jsonString, _b64Secret);
        if (attachment != null) {
          int fileLength = attachment!.lengthSync();
          if (fileLength > 0) {
            File encryptedFile = File('${attachment!.path}.aes');
            await encryptFile(attachment!, encryptedFile, _b64Secret!);
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
}
