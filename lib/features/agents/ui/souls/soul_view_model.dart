import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/soul_query_providers.dart';

/// Domain view-model for a Settings → Agents → Souls row.
///
/// Hydrated up-front in [agentSoulRowVmsProvider] so the page can
/// filter / sort on plain values without per-row async lookups.
class SoulVm {
  const SoulVm({
    required this.id,
    required this.displayName,
    required this.updatedAt,
    this.activeVersion,
  });

  final String id;
  final String displayName;
  final DateTime updatedAt;

  /// `SoulDocumentVersionEntity.version`, when an active version exists.
  /// `null` when the soul has no published version yet.
  final int? activeVersion;
}

/// All non-deleted souls joined with their active version. One
/// [Future.wait] per fetch keeps the per-soul version lookups parallel.
final FutureProvider<List<SoulVm>> agentSoulRowVmsProvider =
    FutureProvider.autoDispose<List<SoulVm>>((ref) async {
      final soulsRaw = await ref.watch(allSoulDocumentsProvider.future);
      final souls = soulsRaw.whereType<SoulDocumentEntity>().toList();
      final versions = await Future.wait(
        souls.map(
          (s) => ref.watch(activeSoulVersionProvider(s.id).future),
        ),
      );
      return [
        for (var i = 0; i < souls.length; i++) _toVm(souls[i], versions[i]),
      ];
    });

SoulVm _toVm(SoulDocumentEntity s, AgentDomainEntity? rawVersion) {
  final version = rawVersion?.mapOrNull(soulDocumentVersion: (v) => v);
  return SoulVm(
    id: s.id,
    displayName: s.displayName,
    updatedAt: s.updatedAt,
    activeVersion: version?.version,
  );
}
