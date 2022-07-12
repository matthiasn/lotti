import 'dart:async';

import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/foundation.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_links.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/sync_message.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/sync_config_service.dart';
import 'package:lotti/sync/inbox/read_decrypt.dart';
import 'package:lotti/sync/inbox/save_attachments.dart';
import 'package:lotti/sync/utils.dart';
import 'package:lotti/utils/file_utils.dart';

Future<void> processMessage(MimeMessage message) async {
  final _syncConfigService = getIt<SyncConfigService>();
  final persistenceLogic = getIt<PersistenceLogic>();
  final _journalDb = getIt<JournalDb>();
  final _loggingDb = getIt<LoggingDb>();

  try {
    final encryptedMessage = readMessage(message);
    final syncConfig = await _syncConfigService.getSyncConfig();

    if (syncConfig != null) {
      final b64Secret = syncConfig.sharedSecret;

      final syncMessage =
          await decryptMessage(encryptedMessage, message, b64Secret);

      await syncMessage?.when(
        journalEntity:
            (JournalEntity journalEntity, SyncEntryStatus status) async {
          await saveJournalEntityJson(journalEntity);

          await journalEntity.maybeMap(
            journalAudio: (JournalAudio journalAudio) async {
              if (syncMessage.status == SyncEntryStatus.initial) {
                await saveAudioAttachment(message, journalAudio, b64Secret);
              }
            },
            journalImage: (JournalImage journalImage) async {
              if (syncMessage.status == SyncEntryStatus.initial) {
                await saveImageAttachment(message, journalImage, b64Secret);
              }
            },
            orElse: () {},
          );

          if (status == SyncEntryStatus.update) {
            await persistenceLogic.updateDbEntity(journalEntity);
          } else {
            await persistenceLogic.createDbEntity(journalEntity);
          }
        },
        entryLink: (EntryLink entryLink, SyncEntryStatus _) {
          _journalDb.upsertEntryLink(entryLink);
        },
        entityDefinition: (
          EntityDefinition entityDefinition,
          SyncEntryStatus status,
        ) {
          _journalDb.upsertEntityDefinition(entityDefinition);
        },
        tagEntity: (
          TagEntity tagEntity,
          SyncEntryStatus status,
        ) {
          _journalDb.upsertTagEntity(tagEntity);
        },
      );
    } else {
      throw Exception('missing IMAP config');
    }
  } catch (e, stackTrace) {
    _loggingDb.captureException(
      e,
      domain: 'INBOX_SERVICE',
      subDomain: 'processMessage',
      stackTrace: stackTrace,
    );
  }
}

Future<void> fetchByUid({
  int? uid,
  ImapClient? imapClient,
}) async {
  if (uid != null) {
    final _loggingDb = getIt<LoggingDb>();

    try {
      if (imapClient != null) {
        // odd workaround, prevents intermittent failures on macOS
        await imapClient.uidFetchMessage(uid, 'BODY.PEEK[]');
        final res = await imapClient.uidFetchMessage(uid, 'BODY.PEEK[]');

        for (final message in res.messages) {
          await processMessage(message);
        }
        await setLastReadUid(uid);
      }
    } on MailException catch (e) {
      debugPrint('High level API failed with $e');
      _loggingDb.captureException(
        e,
        domain: 'INBOX_SERVICE',
        subDomain: '_fetchByUid',
      );
    } catch (e, stackTrace) {
      _loggingDb.captureException(
        e,
        domain: 'INBOX_SERVICE',
        subDomain: '_fetchByUid',
        stackTrace: stackTrace,
      );
    }
  }
}
