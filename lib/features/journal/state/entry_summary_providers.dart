import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/features/journal/state/linked_ai_responses_controller.dart';

/// The newest AI response of [type] linked to [entryId], or null.
///
/// "Newest wins" is the whole contract: re-running a skill against a task that
/// has moved on produces a second response, and both are kept — the earlier
/// one stays as a record of what the entry meant at that time, while every
/// reader shows the latest. [linkedAiResponsesControllerProvider] already
/// sorts newest-first, so this is a filter, not a sort.
///
/// Returns null while the underlying responses are still loading, which is
/// what keeps a collapsed card on its fallback instead of flashing an empty
/// line on first build.
AiResponseEntry? _latestResponseOfType(
  WidgetRef ref,
  String entryId,
  AiResponseType type,
) {
  final responses = ref
      .watch(linkedAiResponsesControllerProvider(entryId))
      .value;
  if (responses == null) return null;
  return responses.where((r) => r.data.type == type).firstOrNull;
}

/// The one-liner tier of the newest response of [type], when it has one.
///
/// Null for a response that predates the tiers (synced from an older client)
/// or one produced by a model that could not call the publishing tool.
/// Callers fall back to something entry-specific rather than showing nothing.
String? _oneLinerOfType(
  WidgetRef ref,
  String entryId,
  AiResponseType type,
) {
  final oneLiner = _latestResponseOfType(
    ref,
    entryId,
    type,
  )?.data.oneLiner?.trim();
  return (oneLiner == null || oneLiner.isEmpty) ? null : oneLiner;
}

/// One-line label for a collapsed audio card, from the newest summary.
String? audioSummaryOneLiner(WidgetRef ref, String entryId) =>
    _oneLinerOfType(ref, entryId, AiResponseType.audioSummary);

/// One-line label for a collapsed image card, from the newest analysis.
///
/// Absent for an image analysed by a model that cannot call tools, analysed
/// before the tiers existed, or written through the legacy path that appends
/// its analysis onto the image's own `entryText` instead of creating a linked
/// response. The collapsed image row falls back to that `entryText`, and to
/// the thumbnail alone when there is no text at all.
String? imageAnalysisOneLiner(WidgetRef ref, String entryId) =>
    _oneLinerOfType(ref, entryId, AiResponseType.imageAnalysis);

/// The route that wrote the newest image analysis for [entryId], as
/// `model · via provider` — the same grammar the check-in composer uses for a
/// dictated take and the briefing footer for a report.
///
/// Null while the configs are still loading, for a model whose config has
/// since been deleted, and for an image nothing has analysed. The caller
/// shows nothing rather than a half-resolved model id: `data.model` holds an
/// id, which names no one.
String? imageAnalysisRouteLabel(
  WidgetRef ref,
  String entryId, {
  required String via,
}) {
  final response = _latestResponseOfType(
    ref,
    entryId,
    AiResponseType.imageAnalysis,
  );
  if (response == null) return null;
  final model = ref.watch(aiConfigByIdProvider(response.data.model)).value;
  if (model is! AiConfigModel) return null;
  final provider = ref
      .watch(aiConfigByIdProvider(model.inferenceProviderId))
      .value;
  if (provider is! AiConfigInferenceProvider) return null;
  return '${model.name} · $via ${provider.name}';
}
