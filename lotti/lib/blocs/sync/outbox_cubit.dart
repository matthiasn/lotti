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
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/main.dart';
import 'package:lotti/services/sync_config_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/sync/encryption.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:mutex/mutex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class OutboxCubit extends Cubit<OutboxState> {
  final SyncConfigService _syncConfigService = getIt<SyncConfigService>();
  late final OutboxImapCubit _outboxImapCubit;
  ConnectivityResult? _connectivityResult;

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
    SyncConfig? syncConfig = await _syncConfigService.getSyncConfig();

    if (syncConfig != null) {
      _b64Secret = syncConfig.sharedSecret;
    }
    emit(OutboxState.online());
    _startPolling();
  }

  void reportConnectivity() async {
    await Sentry.captureEvent(
        SentryEvent(
          message: SentryMessage(_connectivityResult.toString()),
        ),
        withScope: (Scope scope) => scope.level = SentryLevel.warning);
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
          List<OutboxItem> unprocessed =
              await _syncDatabase.oldestOutboxItems(1);
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
                    status: Value(OutboundMessageStatus.sent.index),
                  ),
                );
                if (unprocessed.length > 1) {
                  sendNext(imapClient: successfulClient);
                }
              } else {}
            } catch (e) {
              _syncDatabase.updateOutboxItem(
                OutboxCompanion(
                  id: Value(nextPending.id),
                  // status: Value(nextPending.retries < 10
                  //     ? OutboundMessageStatus.pending.index
                  //     : OutboundMessageStatus.error.index),
                  retries: Value(nextPending.retries + 1),
                ),
              );
              Timer(const Duration(seconds: 1), () => sendNext());
            } finally {
              sendMutex.release();
            }
          }
        }
      } else {
        _stopPolling();
      }
    } catch (exception, stackTrace) {
      await Sentry.captureException(exception, stackTrace: stackTrace);
      sendMutex.release();
      sendNext();
    }
    await transaction.finish();
  }

  void _startPolling() async {
    sendNext();
    timer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      sendNext();
    });
  }

  void _stopPolling() async {
    if (timer != null) {
      timer!.cancel();
    }
  }

  Future<void> enqueueMessage(SyncMessage syncMessage) async {
    if (syncMessage is SyncJournalEntity) {
      final transaction = Sentry.startTransaction('enqueueMessage()', 'task');
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
          status: Value(OutboundMessageStatus.pending.index),
          filePath: Value(
              (fileLength > 0) ? getRelativeAssetPath(attachment!.path) : null),
          subject: Value(subject),
          message: Value(jsonString),
        ));

        await transaction.finish();
        _startPolling();
      } catch (exception, stackTrace) {
        await Sentry.captureException(exception, stackTrace: stackTrace);
      }
    }

    if (syncMessage is SyncEntityDefinition) {
      final transaction = Sentry.startTransaction('enqueueMessage()', 'task');
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
          status: Value(OutboundMessageStatus.pending.index),
          subject: Value(subject),
          message: Value(jsonString),
        ));

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
