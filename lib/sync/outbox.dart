import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_fgbg/flutter_fgbg.dart';
import 'package:lotti/blocs/sync/outbox_state.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/sync_message.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/sync_config_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/sync/encryption.dart';
import 'package:lotti/sync/outbox_imap.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:lotti/utils/platform.dart';
import 'package:mutex/mutex.dart';
import 'package:path_provider/path_provider.dart';

class OutboxService {
  OutboxService() {
    init();

    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      _connectivityResult = result;
      debugPrint('Connectivity onConnectivityChanged $result');
      _loggingDb.captureEvent(
        'OUTBOX: Connectivity onConnectivityChanged $result',
        domain: 'OUTBOX_CUBIT',
      );

      if (result == ConnectivityResult.none) {
        stopPolling();
      } else {
        startPolling();
      }
    });

    if (isMobile) {
      fgBgSubscription = FGBGEvents.stream.listen((event) {
        _loggingDb.captureEvent(event, domain: 'OUTBOX_CUBIT');
        if (event == FGBGType.foreground) {
          startPolling();
        }
        if (event == FGBGType.background) {
          stopPolling();
        }
      });
    }
  }

  final SyncConfigService _syncConfigService = getIt<SyncConfigService>();
  ConnectivityResult? _connectivityResult;
  final LoggingDb _loggingDb = getIt<LoggingDb>();
  final sendMutex = Mutex();
  final SyncDatabase _syncDatabase = getIt<SyncDatabase>();
  String? _b64Secret;
  bool enabled = true;
  late final StreamSubscription<FGBGType> fgBgSubscription;
  Timer? timer;

  void dispose() {
    fgBgSubscription.cancel();
  }

  Future<void> init() async {
    final syncConfig = await _syncConfigService.getSyncConfig();

    if (syncConfig != null) {
      _b64Secret = syncConfig.sharedSecret;
      await startPolling();
    }
  }

  Future<void> reportConnectivity() async {
    _loggingDb.captureEvent(
      'reportConnectivity: $_connectivityResult',
      domain: 'OUTBOX_CUBIT',
    );
  }

  // Inserts a fault 25% of the time, where an exception would
  // have to be handled, a retry intent recorded, and a retry
  // scheduled. Improper handling of the retry would become
  // very obvious and painful very soon.
  String insertFault(String path) {
    final random = Random();
    final randomNumber = random.nextDouble();
    return (randomNumber < 0.25) ? '${path}Nope' : path;
  }

  Future<List<OutboxItem>> getNextItems() async {
    return _syncDatabase.oldestOutboxItems(10);
  }

  Future<void> sendNext({ImapClient? imapClient}) async {
    _loggingDb.captureEvent('sendNext()', domain: 'OUTBOX_CUBIT');

    if (!enabled) return;

    final transaction = _loggingDb.startTransaction('sendNext()', 'task');
    try {
      _connectivityResult = await Connectivity().checkConnectivity();
      if (_connectivityResult == ConnectivityResult.none) {
        await reportConnectivity();
        await stopPolling();
        return;
      }

      if (_b64Secret != null) {
        // ignore: flutter_style_todos
        // TODO: check why not working reliably on macOS - workaround
        final isConnected = _connectivityResult != ConnectivityResult.none;

        if (isConnected && !sendMutex.isLocked) {
          final unprocessed = await getNextItems();
          if (unprocessed.isNotEmpty) {
            await sendMutex.acquire();

            final nextPending = unprocessed.first;
            try {
              final encryptedMessage = await encryptString(
                b64Secret: _b64Secret!,
                plainText: nextPending.message,
              );

              final filePath = nextPending.filePath;
              String? encryptedFilePath;

              if (filePath != null) {
                final docDir = await getApplicationDocumentsDirectory();
                final encryptedFile =
                    File('${docDir.path}${nextPending.filePath}.aes');
                final attachment = File(insertFault('${docDir.path}$filePath'));
                await encryptFile(attachment, encryptedFile, _b64Secret!);
                encryptedFilePath = encryptedFile.path;
              }

              final successfulClient = await persistImap(
                encryptedFilePath: encryptedFilePath,
                subject: nextPending.subject,
                encryptedMessage: encryptedMessage,
                prevImapClient: imapClient,
              );
              if (successfulClient != null) {
                await _syncDatabase.updateOutboxItem(
                  OutboxCompanion(
                    id: Value(nextPending.id),
                    status: Value(OutboxStatus.sent.index),
                    updatedAt: Value(DateTime.now()),
                  ),
                );
                if (unprocessed.length > 1) {
                  await sendNext(imapClient: successfulClient);
                }
              }
            } catch (e) {
              await _syncDatabase.updateOutboxItem(
                OutboxCompanion(
                  id: Value(nextPending.id),
                  status: Value(
                    nextPending.retries < 10
                        ? OutboxStatus.pending.index
                        : OutboxStatus.error.index,
                  ),
                  retries: Value(nextPending.retries + 1),
                  updatedAt: Value(DateTime.now()),
                ),
              );
              await stopPolling();
            } finally {
              if (sendMutex.isLocked) {
                sendMutex.release();
              }
            }
          } else {
            await stopPolling();
          }
        }
      } else {
        await stopPolling();
      }
    } catch (exception, stackTrace) {
      _loggingDb.captureException(
        exception,
        domain: 'OUTBOX',
        subDomain: 'sendNext',
        stackTrace: stackTrace,
      );
      if (sendMutex.isLocked) {
        sendMutex.release();
      }
    }
    await transaction.finish();
  }

  Future<void> startPolling() async {
    final syncConfig = await _syncConfigService.getSyncConfig();

    if (syncConfig == null) {
      _loggingDb.captureEvent(
        'Sync config missing -> polling not started',
        domain: 'OUTBOX_CUBIT',
      );
      return;
    }

    _loggingDb.captureEvent('startPolling()', domain: 'OUTBOX_CUBIT');

    if (timer != null && timer!.isActive) {
      return;
    }

    await sendNext();
    timer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      _connectivityResult = await Connectivity().checkConnectivity();
      _loggingDb.captureEvent(
        '_connectivityResult: $_connectivityResult',
        domain: 'OUTBOX_CUBIT',
      );

      final unprocessed = await getNextItems();

      if (_connectivityResult == ConnectivityResult.none ||
          unprocessed.isEmpty) {
        timer.cancel();
        _loggingDb.captureEvent('timer cancelled', domain: 'OUTBOX_CUBIT');
      } else {
        await sendNext();
      }
    });
  }

  Future<void> stopPolling() async {
    if (timer != null) {
      _loggingDb.captureEvent('stopPolling()', domain: 'OUTBOX_CUBIT');

      timer?.cancel();
      timer = null;
    }
  }

  Future<void> enqueueMessage(SyncMessage syncMessage) async {
    if (syncMessage is SyncJournalEntity) {
      final transaction =
          _loggingDb.startTransaction('enqueueMessage()', 'task');
      try {
        final journalEntity = syncMessage.journalEntity;
        final jsonString = json.encode(syncMessage);
        final docDir = await getApplicationDocumentsDirectory();
        final vectorClockService = getIt<VectorClockService>();

        File? attachment;
        final host = await vectorClockService.getHost();
        final hostHash = await vectorClockService.getHostHash();
        final localCounter = journalEntity.meta.vectorClock?.vclock[host];
        final subject = '$hostHash:$localCounter';

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

        final fileLength = attachment?.lengthSync() ?? 0;
        await _syncDatabase.addOutboxItem(
          OutboxCompanion(
            status: Value(OutboxStatus.pending.index),
            filePath: Value(
              (fileLength > 0) ? getRelativeAssetPath(attachment!.path) : null,
            ),
            subject: Value(subject),
            message: Value(jsonString),
            createdAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
          ),
        );

        await transaction.finish();
        await startPolling();
      } catch (exception, stackTrace) {
        _loggingDb.captureException(
          exception,
          domain: 'OUTBOX',
          subDomain: 'enqueueMessage',
          stackTrace: stackTrace,
        );
      }
    }

    if (syncMessage is SyncEntityDefinition) {
      final transaction =
          _loggingDb.startTransaction('enqueueMessage()', 'task');
      try {
        final jsonString = json.encode(syncMessage);
        final vectorClockService = getIt<VectorClockService>();
        final host = await vectorClockService.getHost();
        final hostHash = await vectorClockService.getHostHash();
        final localCounter =
            syncMessage.entityDefinition.vectorClock?.vclock[host];
        final subject = '$hostHash:$localCounter';

        await _syncDatabase.addOutboxItem(
          OutboxCompanion(
            status: Value(OutboxStatus.pending.index),
            subject: Value(subject),
            message: Value(jsonString),
            createdAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
          ),
        );

        await transaction.finish();
        await startPolling();
      } catch (exception, stackTrace) {
        _loggingDb.captureException(
          exception,
          domain: 'OUTBOX',
          subDomain: 'enqueueMessage',
          stackTrace: stackTrace,
        );
      }
    }

    if (syncMessage is SyncEntryLink) {
      final transaction =
          _loggingDb.startTransaction('enqueueMessage()', 'link');
      try {
        final jsonString = json.encode(syncMessage);
        final vectorClockService = getIt<VectorClockService>();
        final hostHash = await vectorClockService.getHostHash();
        final subject = '$hostHash:link';

        await _syncDatabase.addOutboxItem(
          OutboxCompanion(
            status: Value(OutboxStatus.pending.index),
            subject: Value(subject),
            message: Value(jsonString),
            createdAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
          ),
        );

        await transaction.finish();
        await startPolling();
      } catch (exception, stackTrace) {
        _loggingDb.captureException(
          exception,
          domain: 'OUTBOX',
          subDomain: 'enqueueMessage',
          stackTrace: stackTrace,
        );
      }
    }

    if (syncMessage is SyncTagEntity) {
      final transaction =
          _loggingDb.startTransaction('enqueueMessage()', 'tag');
      try {
        final jsonString = json.encode(syncMessage);
        final vectorClockService = getIt<VectorClockService>();
        final hostHash = await vectorClockService.getHostHash();
        final subject = '$hostHash:tag';

        await _syncDatabase.addOutboxItem(
          OutboxCompanion(
            status: Value(OutboxStatus.pending.index),
            subject: Value(subject),
            message: Value(jsonString),
            createdAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
          ),
        );

        await transaction.finish();
        await startPolling();
      } catch (exception, stackTrace) {
        _loggingDb.captureException(
          exception,
          domain: 'OUTBOX',
          subDomain: 'enqueueMessage',
          stackTrace: stackTrace,
        );
      }
    }
  }
}
