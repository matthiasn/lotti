import 'dart:async';

import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/foundation.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_links.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/sync_message.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/sync/inbox/read_decrypt.dart';
import 'package:lotti/sync/inbox/save_attachments.dart';
import 'package:lotti/utils/file_utils.dart';

Future<SyncMessage?> decodeMessage(
  MimeMessage message,
  String b64Secret,
) async {
  final encryptedMessage = readMessage(message);
  return decryptMessage(encryptedMessage, message, b64Secret);
}

Future<void> processMessage(SyncConfig? syncConfig, MimeMessage message) async {
  final journalDb = getIt<JournalDb>();
  final loggingDb = getIt<LoggingDb>();

  try {
    if (syncConfig != null) {
      final b64Secret = syncConfig.sharedSecret;
      final syncMessage = await decodeMessage(message, b64Secret);

      await syncMessage?.when(
        journalEntity: (
          JournalEntity journalEntity,
          SyncEntryStatus status,
        ) async {
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
            await journalDb.updateJournalEntity(journalEntity);
          } else {
            await journalDb.addJournalEntity(journalEntity);
          }
        },
        entryLink: (EntryLink entryLink, SyncEntryStatus _) {
          journalDb.upsertEntryLink(entryLink);
        },
        entityDefinition: (
          EntityDefinition entityDefinition,
          SyncEntryStatus status,
        ) {
          journalDb.upsertEntityDefinition(entityDefinition);
        },
        tagEntity: (
          TagEntity tagEntity,
          SyncEntryStatus status,
        ) {
          journalDb.upsertTagEntity(tagEntity);
        },
      );
    } else {
      throw Exception('missing IMAP config');
    }
  } catch (e, stackTrace) {
    loggingDb.captureException(
      e,
      domain: 'INBOX_SERVICE',
      subDomain: 'processMessage',
      stackTrace: stackTrace,
    );
    rethrow;
  }
}

Future<void> fetchByUid({
  required int uid,
  required Future<void> Function(int) setLastReadUid,
  ImapClient? imapClient,
  SyncConfig? syncConfig,
}) async {
  final loggingDb = getIt<LoggingDb>();

  try {
    if (imapClient != null) {
      // odd workaround, prevents intermittent failures on macOS
      await imapClient.uidFetchMessage(uid, 'BODY.PEEK[]');
      final res = await imapClient.uidFetchMessage(uid, 'BODY.PEEK[]');

      for (final message in res.messages) {
        await processMessage(syncConfig, message);
      }
      await setLastReadUid(uid);
    }
  } on MailException catch (e) {
    debugPrint('High level API failed with $e');
    loggingDb.captureException(
      e,
      domain: 'INBOX_SERVICE',
      subDomain: '_fetchByUid',
    );
    rethrow;
  } catch (e, stackTrace) {
    loggingDb.captureException(
      e,
      domain: 'INBOX_SERVICE',
      subDomain: '_fetchByUid',
      stackTrace: stackTrace,
    );
    rethrow;
  }
}
