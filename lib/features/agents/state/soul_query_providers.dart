import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/ritual_summary.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'soul_query_providers.g.dart';

/// List all non-deleted soul documents.
///
/// Each element is a [SoulDocumentEntity].
/// Relies on manual `ref.invalidate()` at mutation sites (create, delete)
/// rather than watching the global notification stream.
@riverpod
Future<List<AgentDomainEntity>> allSoulDocuments(Ref ref) async {
  final service = ref.watch(soulDocumentServiceProvider);
  return service.getAllSouls();
}

/// Fetch a single soul document by [soulId].
///
/// The returned entity is a [SoulDocumentEntity] (or `null`).
@riverpod
Future<AgentDomainEntity?> soulDocument(
  Ref ref,
  String soulId,
) async {
  ref.watch(agentUpdateStreamProvider(soulId));
  final service = ref.watch(soulDocumentServiceProvider);
  return service.getSoul(soulId);
}

/// Fetch the active version for a soul document by [soulId].
///
/// The returned entity is a [SoulDocumentVersionEntity] (or `null`).
@riverpod
Future<AgentDomainEntity?> activeSoulVersion(
  Ref ref,
  String soulId,
) async {
  ref.watch(agentUpdateStreamProvider(soulId));
  final service = ref.watch(soulDocumentServiceProvider);
  return service.getActiveSoulVersion(soulId);
}

/// Fetch the version history for a soul document by [soulId].
///
/// Each element is a [SoulDocumentVersionEntity].
@riverpod
Future<List<AgentDomainEntity>> soulVersionHistory(
  Ref ref,
  String soulId,
) async {
  ref.watch(agentUpdateStreamProvider(soulId));
  final service = ref.watch(soulDocumentServiceProvider);
  return service.getVersionHistory(soulId, limit: -1);
}

/// Resolve the active soul version assigned to a template by [templateId].
///
/// The returned entity is a [SoulDocumentVersionEntity] (or `null`).
@riverpod
Future<AgentDomainEntity?> soulForTemplate(
  Ref ref,
  String templateId,
) async {
  ref.watch(agentUpdateStreamProvider(templateId));
  final service = ref.watch(soulDocumentServiceProvider);
  return service.resolveActiveSoulForTemplate(templateId);
}

/// Reverse lookup: find template IDs that use a given soul by [soulId].
@riverpod
Future<List<String>> templatesUsingSoul(
  Ref ref,
  String soulId,
) async {
  ref.watch(agentUpdateStreamProvider(soulId));
  final service = ref.watch(soulDocumentServiceProvider);
  return service.getTemplatesUsingSoul(soulId);
}

/// All evolution sessions for a soul (newest first).
@riverpod
Future<List<AgentDomainEntity>> soulEvolutionSessions(
  Ref ref,
  String soulId,
) async {
  ref.watch(agentUpdateStreamProvider(soulId));
  final templateService = ref.watch(agentTemplateServiceProvider);
  return templateService.getEvolutionSessions(soulId, limit: 100);
}

/// Active (pending) evolution session for a soul, or `null`.
@riverpod
Future<AgentDomainEntity?> pendingSoulEvolution(
  Ref ref,
  String soulId,
) async {
  final sessions = await ref.watch(
    soulEvolutionSessionsProvider(soulId).future,
  );
  final typed = sessions.whereType<EvolutionSessionEntity>().toList();
  final newest = typed.firstOrNull;
  if (newest != null && newest.status == EvolutionSessionStatus.active) {
    return newest;
  }
  return null;
}

/// History entries for past soul evolution sessions.
@riverpod
Future<List<RitualSessionHistoryEntry>> soulEvolutionSessionHistory(
  Ref ref,
  String soulId,
) async {
  ref.watch(agentUpdateStreamProvider(soulId));
  final templateService = ref.watch(agentTemplateServiceProvider);
  final (sessions, recaps) = await (
    ref.watch(soulEvolutionSessionsProvider(soulId).future),
    templateService.getEvolutionSessionRecaps(soulId),
  ).wait;

  final recapBySessionId = {
    for (final recap in recaps) recap.sessionId: recap,
  };

  return sessions
      .whereType<EvolutionSessionEntity>()
      .where((s) => s.status != EvolutionSessionStatus.active)
      .map(
        (s) => RitualSessionHistoryEntry(
          session: s,
          recap: recapBySessionId[s.id],
        ),
      )
      .toList();
}
