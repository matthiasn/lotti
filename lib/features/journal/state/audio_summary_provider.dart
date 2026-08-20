import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/journal/state/linked_ai_responses_controller.dart';

/// The newest audio-summary response linked to [entryId], or null.
///
/// "Newest wins" is the whole contract: re-running the skill against a task
/// that has moved on produces a second summary, and both are kept — the
/// earlier one stays as a record of what the recording meant at that time,
/// while every reader shows the latest. [linkedAiResponsesControllerProvider]
/// already sorts newest-first, so this is a filter, not a sort.
///
/// Returns null while the underlying responses are still loading, which is
/// what keeps the collapsed card on its transcript fallback instead of
/// flashing an empty line on first build.
AiResponseEntry? latestAudioSummaryFor(WidgetRef ref, String entryId) {
  final responses = ref
      .watch(linkedAiResponsesControllerProvider(entryId))
      .value;
  if (responses == null) return null;
  return responses
      .where((response) => response.data.type == AiResponseType.audioSummary)
      .firstOrNull;
}

/// One-line label for the collapsed audio card, from the newest summary.
///
/// Null when there is no summary yet, or when the summary predates the typed
/// tiers (synced from an older client). Callers fall back to the transcript
/// preview rather than showing nothing — a recording that has not been
/// summarized still needs a label.
String? audioSummaryOneLiner(WidgetRef ref, String entryId) {
  final oneLiner = latestAudioSummaryFor(ref, entryId)?.data.oneLiner?.trim();
  return (oneLiner == null || oneLiner.isEmpty) ? null : oneLiner;
}
