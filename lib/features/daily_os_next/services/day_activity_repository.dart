import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_job.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_outbox_repository.dart';
import 'package:path/path.dart' as path;

enum DayActivityEntryKind { recording, checkIn, plan, summary, agentJob }

/// Agent-job statuses that earn an Activity row.
///
/// These are the states where the day is waiting on work that will not
/// progress on its own: a deterministic failure, a missing prerequisite the
/// user must supply, or an attempt parked until the network returns. `queued`
/// and `running` are in-flight and already visible through the plan surface's
/// own progress affordance, so surfacing them here would be noise.
const Set<DayProcessingJobStatus> stalledAgentJobStatuses = {
  DayProcessingJobStatus.failed,
  DayProcessingJobStatus.waitingForUser,
  DayProcessingJobStatus.waitingForNetwork,
};

/// The agent job kinds Activity can surface (everything but transcription,
/// which joins to its recording card instead).
const Set<DayProcessingJobKind> agentJobKinds = {
  DayProcessingJobKind.parseCapture,
  DayProcessingJobKind.draftPlan,
  DayProcessingJobKind.refinePlan,
};

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

/// Builds the offline Activity projection from journal rows, the device
/// outbox, and agent captures.
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
  }) async {
    final dayAudio = await journalDb.getDayAudioEntries(dayId);
    final audioByActivity = <String, JournalAudio>{
      for (final audio in dayAudio)
        if (audio.data.dayContext case final context?)
          context.activityEntryId: audio,
    };

    // Only transcription jobs join to a recording card by activityEntryId.
    // Agent jobs (parseCapture/draftPlan/refinePlan, ADR 0032 phase 1) carry
    // none, so they cannot join to a card and are projected as rows of their
    // own below, keyed by the job id — which the outbox already derives
    // deterministically per day (`draft_<dayId>`) or per capture
    // (`parse_<captureId>`), so a row is stable across retries rather than
    // accumulating one card per attempt.
    //
    // Both filters are pushed into the day-scoped query (ADR 0044) so
    // Activity's cost tracks this day rather than every job ever recorded.
    final jobs = await outbox.getForDay(
      dayId,
      kinds: const {DayProcessingJobKind.transcribeAudio},
    );
    final stalledAgentJobs = [
      for (final job in await outbox.getForDay(dayId, kinds: agentJobKinds))
        if (stalledAgentJobStatuses.contains(job.status)) job,
    ];
    final jobsByActivity = <String, DayProcessingJob>{
      for (final job in jobs) ?job.activityEntryId: job,
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

    // A live journal recording always earns a row. A job alone only does so
    // while it still represents pending work: once it is terminal (cancelled
    // by a delete, or succeeded for a since-deleted recording) the job file
    // is just the device-local ledger and must not resurrect a card.
    final activityIds = <String>{
      ...audioByActivity.keys,
      for (final entry in jobsByActivity.entries)
        if (!entry.value.isTerminal) entry.key,
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
          if (plan != null && plan.deletedAt == null && plan.dayId == dayId)
            DayActivityEntry(
              id: plan.id,
              kind: DayActivityEntryKind.plan,
              createdAt: plan.createdAt,
              activityEntryId: plan.id,
              plan: plan,
            ),
          for (final job in stalledAgentJobs)
            DayActivityEntry(
              id: job.id,
              kind: DayActivityEntryKind.agentJob,
              activityEntryId: job.id,
              // The moment the work stalled, not the moment it was first
              // requested: the row belongs where the failure happened in the
              // day's narrative, and it moves forward with each new attempt.
              createdAt: job.updatedAt,
              processingJob: job,
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
}
