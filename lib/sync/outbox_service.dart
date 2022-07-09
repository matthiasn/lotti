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
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/sync_config_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/sync/client_runner.dart';
import 'package:lotti/sync/encryption.dart';
import 'package:lotti/sync/outbox_imap.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:lotti/utils/platform.dart';
import 'package:path_provider/path_provider.dart';

class OutboxService {
  OutboxService() {
    _clientRunner = ClientRunner<int>(
      callback: (event) async {
        await sendNext();
      },
    );

    init();
  }

  late final ClientRunner<int> _clientRunner;
  final SyncConfigService _syncConfigService = getIt<SyncConfigService>();
  ConnectivityResult? _connectivityResult;
  final LoggingDb _loggingDb = getIt<LoggingDb>();
  final SyncDatabase _syncDatabase = getIt<SyncDatabase>();
  String? _b64Secret;
  late final StreamSubscription<FGBGType> fgBgSubscription;
  ImapClient? prevImapClient;

  void dispose() {
    fgBgSubscription.cancel();
  }

  Future<void> init() async {
    debugPrint('OutboxService init');
    final syncConfig = await _syncConfigService.getSyncConfig();

    final enableSyncOutbox =
        await getIt<JournalDb>().getConfigFlag(enableSyncOutboxFlag);

    if (syncConfig != null && enableSyncOutbox) {
      _b64Secret = syncConfig.sharedSecret;
      await enqueueNextSendRequest();
    }

    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      _connectivityResult = result;
      debugPrint('Connectivity onConnectivityChanged $result');
      _loggingDb.captureEvent(
        'Connectivity onConnectivityChanged $result',
        domain: 'OUTBOX_v2',
      );

      if (result != ConnectivityResult.none) {
        enqueueNextSendRequest();
      }
    });

    if (isMobile) {
      fgBgSubscription = FGBGEvents.stream.listen((event) {
        if (event == FGBGType.foreground) {
          enqueueNextSendRequest();
        }
      });
    }

    Timer.periodic(const Duration(minutes: 1), (timer) async {
      final unprocessed = await getNextItems();
      if (unprocessed.isNotEmpty) {
        await enqueueNextSendRequest();
      }
    });
  }

  Future<void> reportConnectivity() async {
    _loggingDb.captureEvent(
      'reportConnectivity: $_connectivityResult',
      domain: 'OUTBOX_v2',
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

  Future<void> sendNext() async {
    final enableSyncOutbox =
        await getIt<JournalDb>().getConfigFlag(enableSyncOutboxFlag);

    if (!enableSyncOutbox) {
      return;
    }

    _loggingDb.captureEvent('sendNext() start', domain: 'OUTBOX_v2');

    try {
      _connectivityResult = await Connectivity().checkConnectivity();
      if (_connectivityResult == ConnectivityResult.none) {
        await reportConnectivity();
        await enqueueNextSendRequest(delay: const Duration(seconds: 15));
        return;
      }

      if (_b64Secret != null) {
        // ignore: flutter_style_todos
        // TODO: check why not working reliably on macOS - workaround
        final networkConnected = _connectivityResult != ConnectivityResult.none;
        final clientConnected = prevImapClient?.isConnected ?? false;

        if (!clientConnected) {
          prevImapClient = null;
        }

        if (networkConnected) {
          final unprocessed = await getNextItems();
          if (unprocessed.isNotEmpty) {
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
                prevImapClient: prevImapClient,
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
                  await enqueueNextSendRequest();
                }
              } else {
                await enqueueNextSendRequest(
                    delay: const Duration(seconds: 15));
              }
              prevImapClient = successfulClient;
              _loggingDb.captureEvent('sendNext() done', domain: 'OUTBOX_v2');
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
              await prevImapClient?.disconnect();
              // ignore: unnecessary_statements
              prevImapClient == null;
              await enqueueNextSendRequest(delay: const Duration(seconds: 15));
            }
          }
        }
      }
    } catch (exception, stackTrace) {
      _loggingDb.captureException(
        exception,
        domain: 'OUTBOX_v2',
        subDomain: 'sendNext',
        stackTrace: stackTrace,
      );
      await prevImapClient?.disconnect();
      // ignore: unnecessary_statements
      prevImapClient == null;
      await enqueueNextSendRequest(delay: const Duration(seconds: 15));
    }
  }

  Future<void> enqueueNextSendRequest({
    Duration delay = const Duration(milliseconds: 1),
  }) async {
    final syncConfig = await _syncConfigService.getSyncConfig();
    final enableSyncOutbox =
        await getIt<JournalDb>().getConfigFlag(enableSyncOutboxFlag);

    if (!enableSyncOutbox) {
      _loggingDb.captureEvent(
        'Sync not enabled -> not enqueued',
        domain: 'OUTBOX_v2',
      );
      return;
    }

    if (syncConfig == null) {
      _loggingDb.captureEvent(
        'Sync config missing -> not enqueued',
        domain: 'OUTBOX_v2',
      );
      return;
    }

    unawaited(
      Future<void>.delayed(delay).then((_) =>
          _clientRunner.enqueueRequest(DateTime.now().millisecondsSinceEpoch)),
    );

    _loggingDb.captureEvent('enqueueRequest() done', domain: 'OUTBOX_v2');
  }

  Future<void> enqueueMessage(SyncMessage syncMessage) async {
    try {
      final vectorClockService = getIt<VectorClockService>();
      final hostHash = await vectorClockService.getHostHash();
      final jsonString = json.encode(syncMessage);
      final docDir = await getApplicationDocumentsDirectory();

      final commonFields = OutboxCompanion(
        status: Value(OutboxStatus.pending.index),
        message: Value(jsonString),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      );

      if (syncMessage is SyncJournalEntity) {
        final journalEntity = syncMessage.journalEntity;
        File? attachment;
        final host = await vectorClockService.getHost();
        final localCounter = journalEntity.meta.vectorClock?.vclock[host];

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
          commonFields.copyWith(
            filePath: Value(
              (fileLength > 0) ? getRelativeAssetPath(attachment!.path) : null,
            ),
            subject: Value('$hostHash:$localCounter'),
          ),
        );
      }

      if (syncMessage is SyncEntityDefinition) {
        final host = await vectorClockService.getHost();
        final localCounter =
            syncMessage.entityDefinition.vectorClock?.vclock[host];

        await _syncDatabase.addOutboxItem(
          commonFields.copyWith(
            subject: Value('$hostHash:$localCounter'),
          ),
        );
      }

      if (syncMessage is SyncEntryLink) {
        await _syncDatabase.addOutboxItem(
          commonFields.copyWith(
            subject: Value('$hostHash:link'),
          ),
        );
      }

      if (syncMessage is SyncTagEntity) {
        await _syncDatabase.addOutboxItem(
          commonFields.copyWith(
            subject: Value('$hostHash:tag'),
          ),
        );
      }

      await enqueueNextSendRequest();
    } catch (exception, stackTrace) {
      _loggingDb.captureException(
        exception,
        domain: 'OUTBOX_v2',
        subDomain: 'enqueueMessage',
        stackTrace: stackTrace,
      );
    }
  }
}
