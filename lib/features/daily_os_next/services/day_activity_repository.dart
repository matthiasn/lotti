import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_job.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_outbox_repository.dart';
import 'package:lotti/features/speech/services/durable_audio_spool.dart';
import 'package:path/path.dart' as path;

enum DayActivityEntryKind { recording, checkIn, recovery, plan, summary }

/// One coalesced, local-first row in a day's Activity timeline.
@immutable
class DayActivityEntry {
  const DayActivityEntry({
    required this.id,
    required this.kind,
    required this.createdAt,
    required this.activityEntryId,
    this.audio,
    this.audioPath,
    this.processingJob,
    this.capture,
    this.recoveryManifest,
    this.plan,
    this.summary,
  });

  final String id;
  final DayActivityEntryKind kind;
  final DateTime createdAt;
  final String activityEntryId;
  final JournalAudio? audio;
  final String? audioPath;
  final DayProcessingJob? processingJob;
  final CaptureEntity? capture;
  final DurableAudioSpoolManifest? recoveryManifest;
  final DayPlanEntity? plan;
  final DaySummaryEntity? summary;

  String? get transcript {
    final captureText = capture?.transcript.trim();
    if (captureText != null && captureText.isNotEmpty) return captureText;
    final journalText = audio?.entryText?.plainText.trim();
    if (journalText != null && journalText.isNotEmpty) return journalText;
    final result = processingJob?.resultTranscript?.trim();
    if (result != null && result.isNotEmpty) return result;
    final transcripts = audio?.data.transcripts;
    if (transcripts == null || transcripts.isEmpty) return null;
    final value = transcripts.last.transcript.trim();
    return value.isEmpty ? null : value;
  }

  bool get isSubmitted => capture != null;

  bool? get audioAvailableLocally =>
      audioPath == null ? null : File(audioPath!).existsSync();
}

/// Builds the offline Activity projection from journal rows, the device outbox,
/// agent captures, and uncommitted durable-spool sessions.
class DayActivityRepository {
  DayActivityRepository({
    required this.journalDb,
    required this.outbox,
    required this.assetRoot,
  });

  final JournalDb journalDb;
  final DayProcessingOutboxRepository outbox;
  final Directory assetRoot;

  Future<List<DayActivityEntry>> load({
    required String dayId,
    Iterable<CaptureEntity> captures = const <CaptureEntity>[],
    Iterable<DaySummaryEntity> summaries = const <DaySummaryEntity>[],
    DayPlanEntity? plan,
    int pageSize = 64,
  }) async {
    final audioByActivity = <String, JournalAudio>{};
    var offset = 0;
    while (true) {
      final page = await journalDb.getJournalEntities(
        types: const <String>['JournalAudio'],
        starredStatuses: const <bool>[true, false],
        privateStatuses: const <bool>[true, false],
        flaggedStatuses: const <int>[1, 0],
        ids: null,
        limit: pageSize,
        offset: offset,
      );
      for (final audio in page.whereType<JournalAudio>()) {
        final context = audio.data.dayContext;
        if (audio.meta.deletedAt == null && context?.dayId == dayId) {
          audioByActivity[context!.activityEntryId] = audio;
        }
      }
      if (page.length < pageSize) break;
      offset += pageSize;
    }

    final jobs = await outbox.getAll();
    final jobsByActivity = <String, DayProcessingJob>{
      for (final job in jobs.where((job) => job.dayId == dayId))
        job.activityEntryId: job,
    };
    final capturesByAudio = <String, CaptureEntity>{};
    final standaloneCaptures = <CaptureEntity>[];
    for (final capture in captures) {
      final audioRef = capture.audioRef;
      if (capture.deletedAt == null && audioRef != null) {
        capturesByAudio[audioRef] = capture;
      } else if (capture.deletedAt == null) {
        standaloneCaptures.add(capture);
      }
    }

    final activityIds = <String>{
      ...audioByActivity.keys,
      ...jobsByActivity.keys,
    };
    final entries =
        <DayActivityEntry>[
          for (final activityId in activityIds)
            DayActivityEntry(
              id: activityId,
              kind: DayActivityEntryKind.recording,
              activityEntryId: activityId,
              createdAt:
                  audioByActivity[activityId]?.data.dayContext?.capturedAt ??
                  jobsByActivity[activityId]!.createdAt,
              audio: audioByActivity[activityId],
              audioPath: audioByActivity[activityId] == null
                  ? jobsByActivity[activityId]?.audioPath
                  : path.join(
                      assetRoot.path,
                      audioByActivity[activityId]!.data.audioDirectory
                          .replaceFirst(RegExp('^/+'), ''),
                      audioByActivity[activityId]!.data.audioFile,
                    ),
              processingJob: jobsByActivity[activityId],
              capture: audioByActivity[activityId] == null
                  ? null
                  : capturesByAudio[audioByActivity[activityId]!.meta.id],
            ),
          for (final capture in standaloneCaptures)
            DayActivityEntry(
              id: capture.id,
              kind: DayActivityEntryKind.checkIn,
              activityEntryId: capture.id,
              createdAt: capture.capturedAt,
              capture: capture,
            ),
          for (final capture in capturesByAudio.values.where(
            (capture) => !audioByActivity.values.any(
              (audio) => audio.meta.id == capture.audioRef,
            ),
          ))
            DayActivityEntry(
              id: capture.id,
              kind: DayActivityEntryKind.checkIn,
              activityEntryId: capture.id,
              createdAt: capture.capturedAt,
              capture: capture,
            ),
          ...await _loadRecoveryEntries(
            dayId: dayId,
            knownActivityIds: activityIds,
          ),
          if (plan != null && plan.deletedAt == null && plan.dayId == dayId)
            DayActivityEntry(
              id: plan.id,
              kind: DayActivityEntryKind.plan,
              createdAt: plan.createdAt,
              activityEntryId: plan.id,
              plan: plan,
            ),
          for (final summary in summaries.where(
            (summary) => summary.deletedAt == null && summary.dayId == dayId,
          ))
            DayActivityEntry(
              id: summary.id,
              kind: DayActivityEntryKind.summary,
              createdAt: summary.createdAt,
              activityEntryId: summary.id,
              summary: summary,
            ),
        ]..sort((a, b) {
          final byTime = a.createdAt.compareTo(b.createdAt);
          return byTime != 0 ? byTime : a.id.compareTo(b.id);
        });
    return List<DayActivityEntry>.unmodifiable(entries);
  }

  Future<List<DayActivityEntry>> _loadRecoveryEntries({
    required String dayId,
    required Set<String> knownActivityIds,
  }) async {
    final root = Directory(path.join(assetRoot.path, '.audio_spool'));
    if (!root.existsSync()) return const <DayActivityEntry>[];
    final entries = <DayActivityEntry>[];
    for (final directory in root.listSync().whereType<Directory>()) {
      try {
        final recovery = await DurableAudioSpool.recover(
          sessionDirectory: directory,
        );
        final manifest = recovery.manifest;
        final context = manifest.context;
        if (context.origin != AudioCaptureOrigin.dailyOs ||
            context.dayId != dayId ||
            knownActivityIds.contains(context.activityEntryId) ||
            manifest.state == DurableAudioSpoolState.discarded) {
          continue;
        }
        entries.add(
          DayActivityEntry(
            id: 'recovery:${context.recordingSessionId}',
            kind: DayActivityEntryKind.recovery,
            createdAt: context.createdAt,
            activityEntryId: context.activityEntryId,
            recoveryManifest: manifest,
          ),
        );
      } catch (_) {
        // An unreadable session is preserved on disk for diagnostics. Without
        // trustworthy day provenance it cannot safely appear in one day.
      }
    }
    return entries;
  }
}
