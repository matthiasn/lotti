import 'package:lotti/features/agents/projection/content_digest.dart';
import 'package:lotti/features/agents/projection/input_capture.dart';

/// Digest of the user-owned inputs a task-agent wake reads.
///
/// Two automatic wakes with the same fingerprint would show the model the same
/// task, so the second one is skipped (see `TaskAgentExecute`). The digest
/// covers what the user changes and what the wake subscription watches:
///
/// - [taskState]: the rendered task state *without* time spent. Time spent is
///   summed from the linked entries, and saving a running timer moves it while
///   nothing the agent should react to changed. A finished entry's own
///   duration is still covered, through its source.
/// - [sources]: the rendered log entries (text, audio transcripts, image
///   analyses). A running timer's duration is already left out of these by
///   `renderTaskSources`.
/// - [linkedEntityIds]: every entity linked to or from the task, so adding or
///   removing a link — another task, a project, a new entry — counts.
/// - [categoryKnowledge], and the template version, soul version and model
///   the wake resolved, so a changed setup is never mistaken for no change.
///
/// Deliberately left out: other agents' reports shown as parent-project and
/// linked-task context, and pull request state. They change out of band, and
/// none of them wakes this agent on its own either. Order of [sources] and
/// [linkedEntityIds] does not matter.
String taskWakeInputFingerprint({
  required String taskState,
  required Iterable<RenderedSource> sources,
  required Iterable<String> linkedEntityIds,
  required String? categoryKnowledge,
  required String templateVersionId,
  required String? soulVersionId,
  required String modelId,
}) {
  final sortedSources = sources.toList()
    ..sort((a, b) => a.contentEntryId.compareTo(b.contentEntryId));
  return ContentDigest.of(<String, Object?>{
    'v': 1,
    'taskState': taskState,
    'sources': [
      for (final source in sortedSources)
        <String, Object?>{
          'id': source.contentEntryId,
          'content': source.content,
        },
    ],
    'links': linkedEntityIds.toSet().toList()..sort(),
    'categoryKnowledge': categoryKnowledge?.trim() ?? '',
    'templateVersionId': templateVersionId,
    'soulVersionId': soulVersionId,
    'modelId': modelId,
  });
}
