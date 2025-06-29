import 'dart:convert';

import 'package:lotti/classes/audio_note.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/consts.dart';

class SpeechRepository {
  static Future<JournalAudio?> createAudioEntry(
    AudioNote audioNote, {
    required String? language,
    String? linkedId,
    String? categoryId,
  }) async {
    try {
      final persistenceLogic = getIt<PersistenceLogic>();

      final autoTranscribe = await getIt<JournalDb>().getConfigFlag(
        autoTranscribeFlag,
      );

      final audioData = AudioData(
        audioDirectory: audioNote.audioDirectory,
        duration: audioNote.duration,
        audioFile: audioNote.audioFile,
        dateTo: audioNote.createdAt.add(audioNote.duration),
        dateFrom: audioNote.createdAt,
        autoTranscribeWasActive: autoTranscribe,
        language: language,
      );

      final dateFrom = audioData.dateFrom;
      final dateTo = audioData.dateTo;

      final journalEntity = JournalAudio(
        data: audioData,
        meta: await persistenceLogic.createMetadata(
          dateFrom: dateFrom,
          dateTo: dateTo,
          uuidV5Input: json.encode(audioData),
          flag: EntryFlag.import,
          categoryId: categoryId,
        ),
      );
      await persistenceLogic.createDbEntity(journalEntity, linkedId: linkedId);

      return journalEntity;
    } catch (exception, stackTrace) {
      getIt<LoggingService>().captureException(
        exception,
        domain: 'persistence_logic',
        subDomain: 'createAudioEntry',
        stackTrace: stackTrace,
      );
    }

    return null;
  }

  static Future<void> updateLanguage({
    required String journalEntityId,
    required String language,
  }) async {
    try {
      final persistenceLogic = getIt<PersistenceLogic>();
      final journalEntity =
          await getIt<JournalDb>().journalEntityById(journalEntityId);

      await journalEntity?.maybeMap(
        journalAudio: (JournalAudio item) async {
          await persistenceLogic.updateDbEntity(
            item.copyWith(
              meta: await persistenceLogic.updateMetadata(journalEntity.meta),
              data: item.data.copyWith(language: language),
            ),
          );
        },
        orElse: () async => getIt<LoggingService>().captureException(
          'not an audio entry',
          domain: 'persistence_logic',
          subDomain: 'updateLanguage',
        ),
      );
    } catch (exception, stackTrace) {
      getIt<LoggingService>().captureException(
        exception,
        domain: 'persistence_logic',
        subDomain: 'updateLanguage',
        stackTrace: stackTrace,
      );
    }
  }

  static Future<bool> addAudioTranscript({
    required String journalEntityId,
    required AudioTranscript transcript,
  }) async {
    try {
      final persistenceLogic = getIt<PersistenceLogic>();

      final journalEntity =
          await getIt<JournalDb>().journalEntityById(journalEntityId);

      if (journalEntity == null) {
        return false;
      }

      await journalEntity.maybeMap(
        journalAudio: (JournalAudio journalAudio) async {
          final data = journalAudio.data;
          final updatedData = journalAudio.data.copyWith(
            transcripts: [
              ...?data.transcripts,
              transcript,
            ],
          );

          final entryText = journalAudio.entryText;

          final newEntryText = EntryText(
            plainText: transcript.transcript,
            markdown: transcript.transcript,
          );

          final replaceEntryText = entryText == null ||
              entryText.plainText.isEmpty ||
              '${entryText.markdown}'.trim().isEmpty;

          await persistenceLogic.updateDbEntity(
            journalAudio.copyWith(
              meta: await persistenceLogic.updateMetadata(journalEntity.meta),
              entryText: replaceEntryText ? newEntryText : entryText,
              data: updatedData,
            ),
          );
        },
        orElse: () async => getIt<LoggingService>().captureException(
          'not an audio entry',
          domain: 'persistence_logic',
          subDomain: 'addAudioTranscript',
        ),
      );
    } catch (exception, stackTrace) {
      getIt<LoggingService>().captureException(
        exception,
        domain: 'persistence_logic',
        subDomain: 'addAudioTranscript',
        stackTrace: stackTrace,
      );
    }
    return true;
  }

  static Future<bool> removeAudioTranscript({
    required String journalEntityId,
    required AudioTranscript transcript,
  }) async {
    try {
      final persistenceLogic = getIt<PersistenceLogic>();

      final journalEntity =
          await getIt<JournalDb>().journalEntityById(journalEntityId);

      if (journalEntity == null) {
        return false;
      }

      await journalEntity.maybeMap(
        journalAudio: (JournalAudio journalAudio) async {
          final data = journalAudio.data;
          final updatedData = journalAudio.data.copyWith(
            transcripts: data.transcripts
                ?.where((element) => element.created != transcript.created)
                .toList(),
          );

          await persistenceLogic.updateDbEntity(
            journalAudio.copyWith(
              meta: await persistenceLogic.updateMetadata(journalEntity.meta),
              data: updatedData,
            ),
          );
        },
        orElse: () async => getIt<LoggingService>().captureException(
          'not an audio entry',
          domain: 'persistence_logic',
          subDomain: 'removeAudioTranscript',
        ),
      );
    } catch (exception, stackTrace) {
      getIt<LoggingService>().captureException(
        exception,
        domain: 'persistence_logic',
        subDomain: 'removeAudioTranscript',
        stackTrace: stackTrace,
      );
    }
    return true;
  }
}
