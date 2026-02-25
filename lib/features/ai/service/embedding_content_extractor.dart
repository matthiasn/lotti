import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';

/// Minimum text length required for generating an embedding.
///
/// Entries with fewer characters are too short to produce meaningful vectors.
const kMinEmbeddingTextLength = 20;

/// Entity type strings stored in the embeddings database metadata.
///
/// These identify what kind of journal entity an embedding was generated from.
const kEntityTypeJournalText = 'journal_text';
const kEntityTypeTask = 'task';
const kEntityTypeAudio = 'audio';
const kEntityTypeAiResponse = 'ai_response';

/// Pure utility for extracting embeddable text from journal entities.
///
/// Determines which entity types are eligible for embedding and how to
/// extract their text content. Also provides content hashing for
/// change detection (skip re-embedding unchanged content).
class EmbeddingContentExtractor {
  EmbeddingContentExtractor._();

  /// Extracts embeddable plain text from a [JournalEntity].
  ///
  /// Returns `null` if:
  /// - The entity type is not eligible for embedding
  /// - The entity has no meaningful text content
  /// - The extracted text is shorter than [kMinEmbeddingTextLength]
  static String? extractText(JournalEntity entity) {
    final raw = switch (entity) {
      JournalEntry(:final entryText) => entryText?.plainText,
      Task(:final data, :final entryText) => _taskText(data, entryText),
      JournalAudio(:final data, :final entryText) =>
        entryText?.plainText ?? _firstTranscript(data),
      AiResponseEntry(:final entryText) => entryText?.plainText,
      _ => null,
    };

    if (raw == null || raw.trim().length < kMinEmbeddingTextLength) {
      return null;
    }

    return raw.trim();
  }

  /// Returns the entity type string for the embeddings DB, or `null` if
  /// the entity type is not eligible for embedding.
  static String? entityType(JournalEntity entity) {
    return switch (entity) {
      JournalEntry() => kEntityTypeJournalText,
      Task() => kEntityTypeTask,
      JournalAudio() => kEntityTypeAudio,
      AiResponseEntry() => kEntityTypeAiResponse,
      _ => null,
    };
  }

  /// Computes a SHA-256 content hash of the given [text].
  ///
  /// Used to detect whether entry content has changed since the last
  /// embedding was generated. If the hash matches, re-embedding is skipped.
  static String contentHash(String text) {
    return sha256.convert(utf8.encode(text)).toString();
  }

  /// Combines task title and body text into a single embeddable string.
  static String? _taskText(TaskData data, EntryText? entryText) {
    final body = entryText?.plainText;
    if (body != null && body.isNotEmpty) {
      return '${data.title}\n$body';
    }
    return data.title;
  }

  /// Returns the first transcript text from audio data, or `null`.
  static String? _firstTranscript(AudioData data) {
    final transcripts = data.transcripts;
    if (transcripts == null || transcripts.isEmpty) return null;
    return transcripts.first.transcript;
  }
}
