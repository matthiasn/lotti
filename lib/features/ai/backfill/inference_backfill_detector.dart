import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/backfill/inference_backfill.dart';
import 'package:lotti/features/ai/services/profile_automation_service.dart';

/// What one scan of a task found, and what to watch for the next one.
class InferenceBackfillScan {
  const InferenceBackfillScan({
    required this.candidates,
    required this.watchedIds,
  });

  static const empty = InferenceBackfillScan(candidates: [], watchedIds: {});

  /// The task's entries that are missing inference the task's profile would
  /// run, newest first.
  final List<InferenceBackfillCandidate> candidates;

  /// The ids whose update notifications can change the outcome: the task and
  /// every media entry linked from it.
  final Set<String> watchedIds;
}

/// Finds the entries of a task whose image analysis, transcription or audio
/// summary never ran.
///
/// Mechanical: it reads what is stored and asks the same automation gate the
/// automatic triggers ask. Nothing here calls a model, and the task's agent
/// is not involved — its context and tool list stay as they are.
class InferenceBackfillDetector {
  const InferenceBackfillDetector({
    required this._db,
    required this._automation,
  });

  final JournalDb _db;
  final ProfileAutomationService _automation;

  /// Scans the media entries linked from [taskId].
  ///
  /// A kind is offered only when automation would run it for this task:
  /// the category has automatic inference switched on and a profile the task
  /// resolves to automates that skill with its model slot set
  /// ([ProfileAutomationService.hasAutomatedSkillType]). That is the consent
  /// the automatic triggers rely on; a backfill offers what they would have
  /// done, not more.
  Future<InferenceBackfillScan> scan(String taskId) async {
    final task = await _db.journalEntityById(taskId);
    if (task is! Task || task.meta.deletedAt != null) {
      return InferenceBackfillScan.empty;
    }

    final media = (await _db.getLinkedEntities(taskId))
        .where((entry) => entry is JournalImage || entry is JournalAudio)
        .toList();
    final mediaIds = {for (final entry in media) entry.meta.id};
    final watchedIds = {taskId, ...mediaIds};
    if (media.isEmpty) {
      return InferenceBackfillScan(
        candidates: const [],
        watchedIds: watchedIds,
      );
    }

    final missing = findMissingInference(
      media,
      await _responsesByEntryId(mediaIds),
    );

    final allowedKinds = <InferenceBackfillKind>{};
    for (final kind in {for (final c in missing) c.kind}) {
      if (await _automation.hasAutomatedSkillType(
        subjectId: taskId,
        skillType: kind.skillType,
      )) {
        allowedKinds.add(kind);
      }
    }

    return InferenceBackfillScan(
      candidates: [
        for (final candidate in missing)
          if (allowedKinds.contains(candidate.kind)) candidate,
      ],
      watchedIds: watchedIds,
    );
  }

  /// Whether [candidate]'s entry still misses the inference it was offered
  /// for, read fresh from the database.
  ///
  /// A suggestion can outlive its reason: an automatic run may finish, or
  /// another device's result may sync in, between the scan and the moment
  /// the user accepts it.
  Future<bool> isStillMissing(InferenceBackfillCandidate candidate) async {
    final entry = await _db.journalEntityById(candidate.entryId);
    if (entry == null) return false;
    final responses = await _responsesByEntryId({candidate.entryId});
    return missingInferenceFor(
          entry,
          responses[candidate.entryId] ?? const [],
        ) ==
        candidate.kind;
  }

  /// The AI responses linked from each of [entryIds], in one bulk read.
  Future<Map<String, List<AiResponseEntry>>> _responsesByEntryId(
    Set<String> entryIds,
  ) async {
    final linked = await _db.getBulkLinkedEntities(entryIds);
    return {
      for (final MapEntry(:key, :value) in linked.entries)
        key: value.whereType<AiResponseEntry>().toList(),
    };
  }
}
