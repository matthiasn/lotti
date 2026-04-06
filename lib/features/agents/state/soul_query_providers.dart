import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'soul_query_providers.g.dart';

/// List all non-deleted soul documents.
///
/// Each element is a [SoulDocumentEntity].
@riverpod
Future<List<AgentDomainEntity>> allSoulDocuments(Ref ref) async {
  ref.watch(agentUpdateStreamProvider(agentNotification));
  final service = ref.watch(soulDocumentServiceProvider);
  final souls = await service.getAllSouls();
  return souls.cast<AgentDomainEntity>();
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
  final versions = await service.getVersionHistory(soulId, limit: -1);
  return versions.cast<AgentDomainEntity>();
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
