import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/soul_query_providers.dart';
import 'package:lotti/features/agents/ui/instances/instance_filter_state.dart'
    show InstancesGroupKey;

/// Type axis used by both the type filter and the type group key.
///
/// `taskAgent`, `templateImprover`, and `projectAgent` come straight off
/// [AgentTemplateKind] so a future kind can be added in one enum and the
/// instances page picks it up. `evolution` is the synthetic type used for
/// [EvolutionSessionEntity]s, which don't have a template kind.
enum InstanceType { taskAgent, projectAgent, templateImprover, evolution }

InstanceType? instanceTypeFromAgentKind(String kind) {
  return switch (kind) {
    AgentKinds.taskAgent => InstanceType.taskAgent,
    AgentKinds.projectAgent => InstanceType.projectAgent,
    AgentKinds.templateImprover => InstanceType.templateImprover,
    _ => null,
  };
}

/// View-model row consumed by the instances page.
///
/// Hydrated up-front (in [agentInstanceVmsProvider]) so the page can
/// filter, sort, and group on plain values without per-row async lookups.
class InstanceVm {
  const InstanceVm({
    required this.id,
    required this.displayName,
    required this.type,
    required this.status,
    required this.updatedAt,
    required this.searchKey,
    this.sessionNumber,
    this.soulName,
    this.soulId,
    this.templateId,
    this.templateName,
  });

  /// Stable id used as a map / list key. For task agents this is the
  /// `agentId` (matches `/settings/agents/instances/{agentId}` deep-links);
  /// for evolution sessions this is the session entity id.
  final String id;

  /// Primary line of text on the row. For task agents this is
  /// `agent.displayName`; for evolution sessions the row widget builds a
  /// localized title from [sessionNumber] instead and ignores this value.
  final String displayName;

  /// Set only for [InstanceType.evolution]; lets the row widget render
  /// "Evolution #N" through `context.messages.agentEvolutionSessionTitle`.
  final int? sessionNumber;

  final InstanceType type;
  final AgentLifecycle status;
  final DateTime updatedAt;

  /// Resolved soul (via `templateForAgentProvider` → `soulForTemplateProvider`).
  /// `null` when no soul is assigned.
  final String? soulName;
  final String? soulId;

  /// Template the instance was spawned from. `null` for evolution sessions
  /// or when the template lookup hasn't resolved yet.
  final String? templateId;
  final String? templateName;

  /// Lower-cased blob used by the search input.
  final String searchKey;

  /// Group label / id for [InstancesGroupKey.soul]. Falls back to the
  /// template name (so instances of a templated-but-soulless agent still
  /// cluster together) and finally to a sentinel id so unassigned rows
  /// land in their own bucket.
  String soulGroupId() => soulId ?? templateId ?? '__no_soul__';
  String soulGroupLabel(String fallbackUnassigned) =>
      soulName ?? templateName ?? fallbackUnassigned;
}

/// All instances (task agents + evolution sessions), enriched with their
/// resolved template + soul.
///
/// Resolves per-agent template + soul lookups in parallel via
/// [Future.wait]; the page treats this provider's result as a single
/// [AsyncValue] so the toolbar and grouped list render together.
final FutureProvider<List<InstanceVm>> agentInstanceVmsProvider =
    FutureProvider.autoDispose<List<InstanceVm>>((
      ref,
    ) async {
      final agentsFuture = ref.watch(allAgentInstancesProvider.future);
      final evolutionsFuture = ref.watch(allEvolutionSessionsProvider.future);
      final agents = await agentsFuture;
      final evolutions = await evolutionsFuture;

      final identityEntities = agents.whereType<AgentIdentityEntity>().toList();
      final evolutionEntities = evolutions
          .whereType<EvolutionSessionEntity>()
          .toList();

      final templateFutures = identityEntities.map(
        (a) => ref.watch(templateForAgentProvider(a.agentId).future),
      );
      final templates = await Future.wait(templateFutures);

      final soulFutures = templates.map<Future<AgentDomainEntity?>>((t) {
        final templateEntity = t?.mapOrNull(agentTemplate: (e) => e);
        if (templateEntity == null) return Future<AgentDomainEntity?>.value();
        return ref.watch(soulForTemplateProvider(templateEntity.id).future);
      });
      final souls = await Future.wait(soulFutures);

      final soulNameById = <String, String>{};
      if (souls.isNotEmpty) {
        final allSouls = await ref.watch(allSoulDocumentsProvider.future);
        for (final entity in allSouls) {
          final soul = entity.mapOrNull(soulDocument: (e) => e);
          if (soul != null) {
            soulNameById[soul.id] = soul.displayName;
          }
        }
      }

      final taskRows = <InstanceVm>[];
      for (var i = 0; i < identityEntities.length; i++) {
        final agent = identityEntities[i];
        final template = templates[i]?.mapOrNull(agentTemplate: (e) => e);
        final soulVersion = souls[i]?.mapOrNull(soulDocumentVersion: (e) => e);
        final soulId = soulVersion?.agentId;
        final soulName = soulId == null ? null : soulNameById[soulId];

        final type = instanceTypeFromAgentKind(agent.kind);
        if (type == null) continue;

        taskRows.add(
          InstanceVm(
            id: agent.agentId,
            displayName: agent.displayName,
            type: type,
            status: agent.lifecycle,
            updatedAt: agent.updatedAt,
            soulName: soulName,
            soulId: soulId,
            templateId: template?.id,
            templateName: template?.displayName,
            searchKey: [
              agent.displayName,
              agent.agentId,
              template?.displayName ?? '',
              soulName ?? '',
            ].join(' ').toLowerCase(),
          ),
        );
      }

      final evolutionRows = evolutionEntities.map((session) {
        return InstanceVm(
          id: session.id,
          // Placeholder — the row widget renders the localized
          // "Evolution #N" title from `sessionNumber` instead.
          displayName: '',
          sessionNumber: session.sessionNumber,
          type: InstanceType.evolution,
          // Map evolution-session statuses onto the lifecycle axis used for
          // status filtering / grouping. `active` is the only "live" state;
          // completed and abandoned both end up under `destroyed` so the same
          // green/red/grey pill palette covers them.
          status: switch (session.status) {
            EvolutionSessionStatus.active => AgentLifecycle.active,
            EvolutionSessionStatus.completed => AgentLifecycle.dormant,
            EvolutionSessionStatus.abandoned => AgentLifecycle.destroyed,
          },
          updatedAt: session.updatedAt,
          templateId: session.templateId,
          searchKey: 'evolution ${session.sessionNumber} ${session.id}'
              .toLowerCase(),
        );
      });

      return [...taskRows, ...evolutionRows];
    });
