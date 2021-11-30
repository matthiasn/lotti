import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_fgbg/flutter_fgbg.dart';
import 'package:lotti/blocs/sync/config_classes.dart';
import 'package:lotti/blocs/sync/encryption_cubit.dart';
import 'package:lotti/blocs/sync/imap/outbox_cubit.dart';
import 'package:lotti/blocs/sync/outbound_queue_db.dart';
import 'package:lotti/blocs/sync/outbound_queue_state.dart';
import 'package:lotti/blocs/sync/vector_clock_cubit.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/sync_message.dart';
import 'package:lotti/sync/encryption.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:mutex/mutex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class OutboundQueueCubit extends Cubit<OutboundQueueState> {
  late final EncryptionCubit _encryptionCubit;
  late final OutboxImapCubit _outboxImapCubit;
  ConnectivityResult? _connectivityResult;

  final sendMutex = Mutex();
  late final OutboundQueueDb _db;
  late String? _b64Secret;

  late final VectorClockCubit _vectorClockCubit;
  late final StreamSubscription<FGBGType> fgBgSubscription;
  Timer? timer;

  OutboundQueueCubit({
    required EncryptionCubit encryptionCubit,
    required OutboxImapCubit outboxImapCubit,
    required VectorClockCubit vectorClockCubit,
  }) : super(OutboundQueueState.initial()) {
    _encryptionCubit = encryptionCubit;
    _outboxImapCubit = outboxImapCubit;
    _vectorClockCubit = vectorClockCubit;
    _db = OutboundQueueDb();
    init();

    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      _connectivityResult = result;
      debugPrint('Connectivity onConnectivityChanged $result');
    });

    if (!Platform.isMacOS) {
      fgBgSubscription = FGBGEvents.stream.listen((event) {
        Sentry.captureEvent(
            SentryEvent(
              message: SentryMessage(event.toString()),
            ),
            withScope: (Scope scope) => scope.level = SentryLevel.info);
        if (event == FGBGType.foreground) {
          _startPolling();
        }
        if (event == FGBGType.background) {
          _stopPolling();
        }
      });
    }
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

  void reportConnectivity() async {
    await Sentry.captureEvent(
        SentryEvent(
          message: SentryMessage(_connectivityResult.toString()),
        ),
        withScope: (Scope scope) => scope.level = SentryLevel.warning);
  }

  void sendNext() async {
    final transaction = Sentry.startTransaction('sendNext()', 'task');
    try {
      _connectivityResult = await Connectivity().checkConnectivity();
      if (_connectivityResult == ConnectivityResult.none) {
        reportConnectivity();
      }

      if (_b64Secret != null) {
        // TODO: check why not working reliably on macOS - workaround
        bool isConnected = _connectivityResult != ConnectivityResult.none;
        if (isConnected && !sendMutex.isLocked) {
          List<OutboundQueueRecord> unprocessed = await _db.oldestEntries();
          if (unprocessed.isNotEmpty) {
            sendMutex.acquire();

            OutboundQueueRecord nextPending = unprocessed.first;
            String encryptedMessage = await encryptString(
              b64Secret: _b64Secret,
              plainText: nextPending.message,
            );

            String? filePath = nextPending.filePath;
            String? encryptedFilePath;

            if (filePath != null) {
              Directory docDir = await getApplicationDocumentsDirectory();
              File encryptedFile =
                  File('${docDir.path}${nextPending.filePath}.aes');
              File attachment = File('${docDir.path}$filePath');
              await encryptFile(attachment, encryptedFile, _b64Secret!);
              encryptedFilePath = encryptedFile.path;
            }

            bool saveSuccess = await _outboxImapCubit.saveImap(
              encryptedFilePath: encryptedFilePath,
              subject: nextPending.subject,
              encryptedMessage: encryptedMessage,
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
          } else {
            _stopPolling();
          }
        }
      }
    } catch (exception, stackTrace) {
      await Sentry.captureException(exception, stackTrace: stackTrace);
    }
    await transaction.finish();
  }

  void _startPolling() async {
    sendNext();
    timer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      sendNext();
    });
  }

  void _stopPolling() async {
    if (timer != null) {
      timer!.cancel();
    }
  }

  Future<void> enqueueMessage(SyncMessage syncMessage) async {
    if (syncMessage is SyncJournalDbEntity) {
      final transaction = Sentry.startTransaction('enqueueMessage()', 'task');
      try {
        JournalEntity journalEntity = syncMessage.journalEntity;
        String jsonString = json.encode(syncMessage);
        var docDir = await getApplicationDocumentsDirectory();

        File? attachment;
        String host = await _vectorClockCubit.getHost();
        String hostHash = await _vectorClockCubit.getHostHash();
        int? localCounter = journalEntity.meta.vectorClock?.vclock[host];
        String subject = '$hostHash:$localCounter';

        journalEntity.maybeMap(
          journalAudio: (JournalAudio journalAudio) {
            if (syncMessage.status == SyncEntryStatus.initial) {
              attachment = File(AudioUtils.getAudioPath(journalAudio, docDir));
            }
          },
          journalImage: (JournalImage journalImage) {
            if (syncMessage.status == SyncEntryStatus.initial) {
              attachment =
                  File(getFullImagePathWithDocDir(journalImage, docDir));
            }
          },
          orElse: () {},
        );

        if (attachment != null) {
          int fileLength = attachment!.lengthSync();
          if (fileLength > 0) {
            await _db.queueInsert(
              message: jsonString,
              filePath: attachment!.path,
              subject: subject,
            );
          }
        } else {
          await _db.queueInsert(message: jsonString, subject: subject);
        }

        await transaction.finish();
        _startPolling();
      } catch (exception, stackTrace) {
        await Sentry.captureException(exception, stackTrace: stackTrace);
      }
    }
  }

  @override
  Future<void> close() async {
    super.close();
    fgBgSubscription.cancel();
  }
}
