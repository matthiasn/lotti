import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';

@immutable
class DayAudioEntryContext {
  const DayAudioEntryContext({
    required this.audioId,
    required this.activityEntryId,
    required this.capturedAt,
    required this.processingState,
    this.audioAvailableLocally,
    this.transcript,
  });

  final String audioId;
  final String activityEntryId;
  final DateTime capturedAt;
  final String processingState;
  final bool? audioAvailableLocally;
  final String? transcript;

  Map<String, Object?> toJson() => <String, Object?>{
    'audioId': audioId,
    'activityEntryId': activityEntryId,
    'capturedAt': capturedAt.toIso8601String(),
    'processingState': processingState,
    'audioAvailableLocally': audioAvailableLocally,
    'transcript': transcript,
  };
}

/// Loads all persisted day recordings directly from the local journal.
///
/// This is deliberately independent of `CaptureEntity`: a recording becomes
/// available to later wakes as soon as its durable transcription receipt is
/// attached, even if the user has not opened Reconcile yet.
class DayAudioEntryContextService {
  const DayAudioEntryContextService({required this.journalDb, this.assetRoot});

  final JournalDb journalDb;
  final Directory? assetRoot;

  Future<List<DayAudioEntryContext>> loadForDay(
    String dayId, {
    int maxTranscriptCharacters = 600,
  }) async {
    final audios = await journalDb.getDayAudioEntries(dayId);
    final entries = <DayAudioEntryContext>[];
    for (final audio in audios) {
      final context = audio.data.dayContext;
      if (context == null) continue;
      final transcript = _discoverableTranscript(
        audio,
        context.processingJobId,
      );
      entries.add(
        DayAudioEntryContext(
          audioId: audio.meta.id,
          activityEntryId: context.activityEntryId,
          capturedAt: context.capturedAt,
          processingState: transcript == null ? 'pending' : 'ready',
          audioAvailableLocally: _audioAvailableLocally(audio),
          transcript: transcript == null
              ? null
              : _bounded(transcript, maxTranscriptCharacters),
        ),
      );
    }
    entries.sort((a, b) => a.capturedAt.compareTo(b.capturedAt));
    return List<DayAudioEntryContext>.unmodifiable(entries);
  }

  String? _discoverableTranscript(
    JournalAudio audio,
    String processingJobId,
  ) {
    final reviewed = audio.entryText?.plainText.trim();
    if (reviewed != null && reviewed.isNotEmpty) return reviewed;
    final receipts = audio.data.transcripts ?? const <AudioTranscript>[];
    for (final receipt in receipts.reversed) {
      if (receipt.processingJobId != processingJobId) continue;
      final value = receipt.transcript.trim();
      if (value.isNotEmpty) return value;
    }
    return null;
  }

  String _bounded(String value, int maxCharacters) {
    if (maxCharacters <= 0 || value.length <= maxCharacters) return value;
    return '${value.substring(0, maxCharacters)}…';
  }

  bool? _audioAvailableLocally(JournalAudio audio) {
    final root = assetRoot;
    if (root == null) return null;
    final relativeDirectory = audio.data.audioDirectory.replaceFirst(
      RegExp('^/+'),
      '',
    );
    return File(
      '${root.path}/$relativeDirectory${audio.data.audioFile}',
    ).existsSync();
  }
}
