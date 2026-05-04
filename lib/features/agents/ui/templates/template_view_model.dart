import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/ritual_review_providers.dart';
import 'package:lotti/l10n/app_localizations.dart';

/// Localized label for an [AgentTemplateKind]. Mirrors the existing
/// `_KindBadge` switch in `agent_settings_page.dart` so the new shared
/// listing can render the same human-readable kind names.
String agentTemplateKindLabel(AppLocalizations messages, AgentTemplateKind k) {
  return switch (k) {
    AgentTemplateKind.taskAgent => messages.agentTemplateKindTaskAgent,
    AgentTemplateKind.templateImprover => messages.agentTemplateKindImprover,
    AgentTemplateKind.projectAgent => messages.agentTemplateKindProjectAgent,
  };
}

/// Domain view-model for a Settings → Agents → Agent Templates row.
///
/// Hydrated up-front in [agentTemplateRowVmsProvider] so the page can
/// filter / sort / group on plain values without per-row async lookups.
class TemplateVm {
  const TemplateVm({
    required this.id,
    required this.displayName,
    required this.kind,
    required this.modelId,
    required this.updatedAt,
    required this.hasPendingReview,
    this.activeVersion,
  });

  final String id;
  final String displayName;
  final AgentTemplateKind kind;
  final String modelId;
  final DateTime updatedAt;

  /// True when this template is in `templatesPendingReviewProvider`'s set.
  /// Drives the small purple dot the original `_TemplateListTile` showed.
  final bool hasPendingReview;

  /// `AgentTemplateVersionEntity.version`, when an active version exists.
  /// `null` when the template has no published version yet.
  final int? activeVersion;
}

/// All non-deleted templates joined with their active version + the
/// pending-review set. One [Future.wait] per fetch keeps the per-template
/// version lookups parallel.
final FutureProvider<List<TemplateVm>> agentTemplateRowVmsProvider =
    FutureProvider.autoDispose<List<TemplateVm>>((ref) async {
      final templatesRaw = await ref.watch(agentTemplatesProvider.future);
      // `templatesPendingReviewProvider` is best-effort decoration —
      // treat loading / error / not-overridden as "nothing pending"
      // rather than failing the whole listing. Mirrors the legacy
      // `_TemplateListTile`'s `.value?.contains(...) ?? false`.
      final pending =
          ref.watch(templatesPendingReviewProvider).value ?? const <String>{};

      final templates = templatesRaw.whereType<AgentTemplateEntity>().toList();
      final versions = await Future.wait(
        templates.map(
          (t) => ref.watch(activeTemplateVersionProvider(t.id).future),
        ),
      );

      return [
        for (var i = 0; i < templates.length; i++)
          _toVm(templates[i], versions[i], pending),
      ];
    });

TemplateVm _toVm(
  AgentTemplateEntity t,
  AgentDomainEntity? rawVersion,
  Set<String> pending,
) {
  final version = rawVersion?.mapOrNull(agentTemplateVersion: (v) => v);
  return TemplateVm(
    id: t.id,
    displayName: t.displayName,
    kind: t.kind,
    modelId: t.modelId,
    updatedAt: t.updatedAt,
    hasPendingReview: pending.contains(t.id),
    activeVersion: version?.version,
  );
}
