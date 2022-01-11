import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:bloc/bloc.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_fgbg/flutter_fgbg.dart';
import 'package:lotti/blocs/sync/imap/outbox_cubit.dart';
import 'package:lotti/blocs/sync/outbox_state.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/sync_message.dart';
import 'package:lotti/database/insights_db.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/main.dart';
import 'package:lotti/services/sync_config_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/sync/encryption.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:mutex/mutex.dart';
import 'package:path_provider/path_provider.dart';

class OutboxCubit extends Cubit<OutboxState> {
  final SyncConfigService _syncConfigService = getIt<SyncConfigService>();
  late final OutboxImapCubit _outboxImapCubit;
  ConnectivityResult? _connectivityResult;
  final InsightsDb _insightsDb = getIt<InsightsDb>();

  final sendMutex = Mutex();
  final SyncDatabase _syncDatabase = getIt<SyncDatabase>();
  late String? _b64Secret;

  late final StreamSubscription<FGBGType> fgBgSubscription;
  Timer? timer;

  OutboxCubit({
    required OutboxImapCubit outboxImapCubit,
  }) : super(OutboxState.initial()) {
    _outboxImapCubit = outboxImapCubit;
    init();

    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      _connectivityResult = result;
      debugPrint('Connectivity onConnectivityChanged $result');
      _insightsDb
          .captureEvent('OUTBOX: Connectivity onConnectivityChanged $result');

      if (result == ConnectivityResult.none) {
        stopPolling();
      } else {
        startPolling();
      }
    });

    if (!Platform.isMacOS) {
      fgBgSubscription = FGBGEvents.stream.listen((event) {
        _insightsDb.captureEvent(event);
        if (event == FGBGType.foreground) {
          startPolling();
        }
        if (event == FGBGType.background) {
          stopPolling();
        }
      });
    }
  }

  Future<void> init() async {
    SyncConfig? syncConfig = await _syncConfigService.getSyncConfig();

    if (syncConfig != null) {
      _b64Secret = syncConfig.sharedSecret;
    }
    emit(OutboxState.online());
    startPolling();
  }

  Future<void> toggleStatus() async {
    if (state is OutboxDisabled) {
      emit(OutboxState.online());
      startPolling();
    } else {
      emit(OutboxState.disabled());
    }
  }

  void reportConnectivity() async {
    _insightsDb.captureEvent(_connectivityResult);
  }

  // Inserts a fault 25% of the time, where an exception would
  // have to be handled, a retry intent recorded, and a retry
  // scheduled. Improper handling of the retry would become
  // very obvious and painful very soon.
  String insertFault(String path) {
    Random random = Random();
    double randomNumber = random.nextDouble();
    return (randomNumber < 0.25) ? '${path}Nope' : path;
  }

  void sendNext({ImapClient? imapClient}) async {
    if (state is OutboxDisabled) return;

    final transaction = _insightsDb.startTransaction('sendNext()', 'task');
    try {
      _connectivityResult = await Connectivity().checkConnectivity();
      if (_connectivityResult == ConnectivityResult.none) {
        reportConnectivity();
      }

      if (_b64Secret != null) {
        // TODO: check why not working reliably on macOS - workaround
        bool isConnected = _connectivityResult != ConnectivityResult.none;

        if (isConnected && !sendMutex.isLocked) {
          List<OutboxItem> unprocessed =
              await _syncDatabase.oldestOutboxItems(10);
          if (unprocessed.isNotEmpty) {
            sendMutex.acquire();

            OutboxItem nextPending = unprocessed.first;
            try {
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
                File attachment = File(insertFault('${docDir.path}$filePath'));
                await encryptFile(attachment, encryptedFile, _b64Secret!);
                encryptedFilePath = encryptedFile.path;
              }

              ImapClient? successfulClient = await _outboxImapCubit.saveImap(
                encryptedFilePath: encryptedFilePath,
                subject: nextPending.subject,
                encryptedMessage: encryptedMessage,
                prevImapClient: imapClient,
              );
              if (successfulClient != null) {
                _syncDatabase.updateOutboxItem(
                  OutboxCompanion(
                    id: Value(nextPending.id),
                    status: Value(OutboxStatus.sent.index),
                    updatedAt: Value(DateTime.now()),
                  ),
                );
                if (unprocessed.length > 1) {
                  sendNext(imapClient: successfulClient);
                }
              }
            } catch (e) {
              _syncDatabase.updateOutboxItem(
                OutboxCompanion(
                  id: Value(nextPending.id),
                  status: Value(nextPending.retries < 10
                      ? OutboxStatus.pending.index
                      : OutboxStatus.error.index),
                  retries: Value(nextPending.retries + 1),
                  updatedAt: Value(DateTime.now()),
                ),
              );
              Timer(const Duration(seconds: 1), () => sendNext());
            } finally {
              sendMutex.release();
            }
          }
        }
      } else {
        stopPolling();
      }
    } catch (exception, stackTrace) {
      await _insightsDb.captureException(exception, stackTrace: stackTrace);
      sendMutex.release();
      sendNext();
    }
    await transaction.finish();
  }

  void startPolling() async {
    sendNext();
    timer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      sendNext();
    });
  }

  void stopPolling() async {
    if (timer != null) {
      timer!.cancel();
    }
  }

  Future<void> enqueueMessage(SyncMessage syncMessage) async {
    if (syncMessage is SyncJournalEntity) {
      final transaction =
          _insightsDb.startTransaction('enqueueMessage()', 'task');
      try {
        JournalEntity journalEntity = syncMessage.journalEntity;
        String jsonString = json.encode(syncMessage);
        var docDir = await getApplicationDocumentsDirectory();
        final VectorClockService vectorClockService =
            getIt<VectorClockService>();

        File? attachment;
        String host = await vectorClockService.getHost();
        String hostHash = await vectorClockService.getHostHash();
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

        int fileLength = attachment?.lengthSync() ?? 0;
        await _syncDatabase.addOutboxItem(OutboxCompanion(
          status: Value(OutboxStatus.pending.index),
          filePath: Value(
              (fileLength > 0) ? getRelativeAssetPath(attachment!.path) : null),
          subject: Value(subject),
          message: Value(jsonString),
          createdAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ));

        await transaction.finish();
        startPolling();
      } catch (exception, stackTrace) {
        await _insightsDb.captureException(exception, stackTrace: stackTrace);
      }
    }

    if (syncMessage is SyncEntityDefinition) {
      final transaction =
          _insightsDb.startTransaction('enqueueMessage()', 'task');
      try {
        String jsonString = json.encode(syncMessage);
        final VectorClockService vectorClockService =
            getIt<VectorClockService>();

        String host = await vectorClockService.getHost();
        String hostHash = await vectorClockService.getHostHash();
        int? localCounter =
            syncMessage.entityDefinition.vectorClock?.vclock[host];
        String subject = '$hostHash:$localCounter';

        await _syncDatabase.addOutboxItem(OutboxCompanion(
          status: Value(OutboxStatus.pending.index),
          subject: Value(subject),
          message: Value(jsonString),
          createdAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ));

        await transaction.finish();
        startPolling();
      } catch (exception, stackTrace) {
        await _insightsDb.captureException(exception, stackTrace: stackTrace);
      }
    }
  }

  @override
  Future<void> close() async {
    super.close();
    fgBgSubscription.cancel();
  }
}
