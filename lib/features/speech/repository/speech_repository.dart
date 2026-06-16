import 'dart:async';
import 'dart:convert';

import 'package:lotti/classes/audio_note.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/domain_logging.dart';

/// Static persistence helpers for audio journal entries — a thin namespace over
/// [PersistenceLogic].
///
/// [createAudioEntry] persists a recorded `AudioNote` as a `JournalAudio` entry
/// (optionally linked to another entry and category-scoped), [updateLanguage]
/// sets the detected/selected transcription language on an entry, and
/// [removeAudioTranscript] drops a transcript from an existing entry.
class SpeechRepository {
  /// Persists [audioNote] as a `JournalAudio` entry.
  ///
  /// Derives the entry's `dateFrom`/`dateTo` from the note's creation time and
  /// duration, stamps it with import-flag metadata (with a deterministic UUIDv5
  /// keyed on the encoded audio data), and stores it via [PersistenceLogic].
  /// When [linkedId] is given the new entry is linked to that parent (e.g. a
  /// task); [categoryId] scopes it to a category. Returns the created entry, or
  /// `null` if persistence fails.
  static Future<JournalAudio?> createAudioEntry(
    AudioNote audioNote, {
    String? linkedId,
    String? categoryId,
  }) async {
    try {
      final persistenceLogic = getIt<PersistenceLogic>();

      final audioData = AudioData(
        audioDirectory: audioNote.audioDirectory,
        duration: audioNote.duration,
        audioFile: audioNote.audioFile,
        dateTo: audioNote.createdAt.add(audioNote.duration),
        dateFrom: audioNote.createdAt,
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
      getIt<DomainLogger>().error(
        LogDomain.persistence,
        exception,
        stackTrace: stackTrace,
        subDomain: 'createAudioEntry',
      );
    }

    return null;
  }

  /// Sets the transcription [language] on the audio entry with
  /// [journalEntityId].
  ///
  /// Looks the entry up, and only mutates it when it is a `JournalAudio`
  /// (logging otherwise). The language is the user/auto-detected code used by
  /// downstream transcription; a no-op for non-audio entries.
  static Future<void> updateLanguage({
    required String journalEntityId,
    required String language,
  }) async {
    try {
      final persistenceLogic = getIt<PersistenceLogic>();
      final journalEntity = await getIt<JournalDb>().journalEntityById(
        journalEntityId,
      );

      await journalEntity?.maybeMap(
        journalAudio: (JournalAudio item) async {
          await persistenceLogic.updateDbEntity(
            item.copyWith(
              meta: await persistenceLogic.updateMetadata(journalEntity.meta),
              data: item.data.copyWith(language: language),
            ),
          );
        },
        orElse: () async {
          getIt<DomainLogger>().error(
            LogDomain.persistence,
            'not an audio entry',
            subDomain: 'updateLanguage',
          );
        },
      );
    } catch (exception, stackTrace) {
      getIt<DomainLogger>().error(
        LogDomain.persistence,
        exception,
        stackTrace: stackTrace,
        subDomain: 'updateLanguage',
      );
    }
  }

  /// Removes [transcript] from the audio entry with [journalEntityId].
  ///
  /// Matches the transcript to drop by its `created` timestamp and rewrites the
  /// entry's transcript list without it. Returns `false` only when the entry
  /// does not exist; otherwise returns `true` (including the no-op case where
  /// the entry is not a `JournalAudio`, which is logged).
  static Future<bool> removeAudioTranscript({
    required String journalEntityId,
    required AudioTranscript transcript,
  }) async {
    try {
      final persistenceLogic = getIt<PersistenceLogic>();

      final journalEntity = await getIt<JournalDb>().journalEntityById(
        journalEntityId,
      );

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
        orElse: () async {
          getIt<DomainLogger>().error(
            LogDomain.persistence,
            'not an audio entry',
            subDomain: 'removeAudioTranscript',
          );
        },
      );
    } catch (exception, stackTrace) {
      getIt<DomainLogger>().error(
        LogDomain.persistence,
        exception,
        stackTrace: stackTrace,
        subDomain: 'removeAudioTranscript',
      );
    }
    return true;
  }
}
