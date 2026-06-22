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
    AgentTemplateKind.dayAgent => messages.agentTemplateKindDayAgent,
    AgentTemplateKind.templateImprover => messages.agentTemplateKindImprover,
    AgentTemplateKind.projectAgent => messages.agentTemplateKindProjectAgent,
    AgentTemplateKind.eventAgent => messages.agentTemplateKindEventAgent,
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
/// pending-review set.
///
/// Per-template version lookups are watched synchronously via `.value`
/// rather than awaited, so the list renders as soon as the templates
/// themselves are loaded. Each version pill then appears reactively
/// when its provider resolves, and a single slow / failing lookup
/// can't block or fail the whole listing.
final Provider<AsyncValue<List<TemplateVm>>> agentTemplateRowVmsProvider =
    Provider.autoDispose<AsyncValue<List<TemplateVm>>>((ref) {
      final templatesAsync = ref.watch(agentTemplatesProvider);
      return templatesAsync.whenData((templatesRaw) {
        // `templatesPendingReviewProvider` is best-effort decoration —
        // treat loading / error / not-overridden as "nothing pending"
        // rather than failing the whole listing. Mirrors the legacy
        // `_TemplateListTile`'s `.value?.contains(...) ?? false`.
        final pending =
            ref.watch(templatesPendingReviewProvider).value ?? const <String>{};

        final templates = templatesRaw
            .whereType<AgentTemplateEntity>()
            .toList();
        return [
          for (final t in templates)
            _toVm(
              t,
              ref.watch(activeTemplateVersionProvider(t.id)).value,
              pending,
            ),
        ];
      });
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
