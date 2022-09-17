import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

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
import 'package:lotti/sync/connectivity.dart';
import 'package:lotti/sync/encryption.dart';
import 'package:lotti/sync/fg_bg.dart';
import 'package:lotti/sync/outbox_imap.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:path_provider/path_provider.dart';

class OutboxService {
  OutboxService() {
    startRunner();
    init();
  }

  late ClientRunner<int> _clientRunner;
  final ConnectivityService _connectivityService = getIt<ConnectivityService>();
  final FgBgService _fgBgService = getIt<FgBgService>();
  final SyncConfigService _syncConfigService = getIt<SyncConfigService>();
  final LoggingDb _loggingDb = getIt<LoggingDb>();
  final SyncDatabase _syncDatabase = getIt<SyncDatabase>();
  late final StreamSubscription<FGBGType> fgBgSubscription;
  ImapClient? prevImapClient;

  void dispose() {
    fgBgSubscription.cancel();
  }

  void startRunner() {
    _clientRunner = ClientRunner<int>(
      callback: (event) async {
        await sendNext();
      },
    );
  }

  Future<void> init() async {
    final syncConfig = await _syncConfigService.getSyncConfig();

    final enableSyncOutbox =
        await getIt<JournalDb>().getConfigFlag(enableSyncOutboxFlag);

    if (syncConfig != null && enableSyncOutbox) {
      await enqueueNextSendRequest();
    }
    debugPrint('OutboxService init $enableSyncOutbox');

    _connectivityService.connectedStream.listen((connected) {
      if (connected) {
        startRunner();
        enqueueNextSendRequest();
      }
    });

    _fgBgService.fgBgStream.listen((foreground) {
      if (foreground) {
        startRunner();
        enqueueNextSendRequest();
      }
    });

    Timer.periodic(const Duration(minutes: 1), (timer) async {
      final unprocessed = await getNextItems();
      if (unprocessed.isNotEmpty) {
        await enqueueNextSendRequest();
      }
    });
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
    _loggingDb.captureEvent(
      'start',
      domain: 'OUTBOX',
      subDomain: 'sendNext()',
    );

    final syncConfig = await _syncConfigService.getSyncConfig();
    final b64Secret = syncConfig?.sharedSecret;

    final enableSyncOutbox =
        await getIt<JournalDb>().getConfigFlag(enableSyncOutboxFlag);

    if (!enableSyncOutbox) {
      _loggingDb.captureEvent(
        'sync not enabled',
        domain: 'OUTBOX',
        subDomain: 'sendNext()',
      );
      return;
    }

    if (b64Secret == null) {
      _loggingDb.captureEvent(
        'sync config does not exist',
        domain: 'OUTBOX',
        subDomain: 'sendNext()',
      );
      return;
    }

    _loggingDb.captureEvent('sendNext() start', domain: 'OUTBOX');

    try {
      final networkConnected = await _connectivityService.isConnected();
      final clientConnected = prevImapClient?.isConnected ?? false;

      _loggingDb
        ..captureEvent(
          'sendNext() networkConnected: $networkConnected ',
          domain: 'OUTBOX',
        )
        ..captureEvent(
          'sendNext() clientConnected: $clientConnected ',
          domain: 'OUTBOX',
        );

      if (!clientConnected) {
        prevImapClient = null;
      }

      if (networkConnected) {
        final unprocessed = await getNextItems();
        if (unprocessed.isNotEmpty) {
          final nextPending = unprocessed.first;
          try {
            final encryptedMessage = await encryptString(
              b64Secret: b64Secret,
              plainText: nextPending.message,
            );

            final filePath = nextPending.filePath;
            String? encryptedFilePath;

            if (filePath != null) {
              final docDir = await getApplicationDocumentsDirectory();
              final encryptedFile =
                  File('${docDir.path}${nextPending.filePath}.aes');
              final attachment = File(insertFault('${docDir.path}$filePath'));
              await encryptFile(attachment, encryptedFile, b64Secret);
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
                delay: const Duration(seconds: 15),
              );
            }
            prevImapClient = successfulClient;
            _loggingDb.captureEvent('sendNext() done', domain: 'OUTBOX');
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
    } catch (exception, stackTrace) {
      _loggingDb.captureException(
        exception,
        domain: 'OUTBOX',
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
        domain: 'OUTBOX',
      );
      return;
    }

    if (syncConfig == null) {
      _loggingDb.captureEvent(
        'Sync config missing -> not enqueued',
        domain: 'OUTBOX',
      );
      return;
    }

    unawaited(
      Future<void>.delayed(delay).then((_) {
        _clientRunner.enqueueRequest(DateTime.now().millisecondsSinceEpoch);
        _loggingDb.captureEvent('enqueueRequest() done', domain: 'OUTBOX');
      }),
    );
  }

  Future<void> enqueueMessage(SyncMessage syncMessage) async {
    try {
      final vectorClockService = getIt<VectorClockService>();
      final hostHash = await vectorClockService.getHostHash();
      final host = await vectorClockService.getHost();
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
          commonFields.copyWith(subject: Value('$hostHash:link')),
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
      debugPrint('enqueueMessage $exception \n$stackTrace');
      _loggingDb.captureException(
        exception,
        domain: 'OUTBOX',
        subDomain: 'enqueueMessage',
        stackTrace: stackTrace,
      );
    }
  }
}
