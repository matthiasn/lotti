import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';

/// Pure selection + rendering helpers for durable planner knowledge
/// (ADR 0022 Decisions 9–10). Kept free of I/O so the Head selection and the
/// prompt blocks are deterministic and unit-testable.

/// Scope prefix for a category-scoped knowledge entry.
const knowledgeCategoryScopePrefix = 'category:';

/// Scope prefix for a project-scoped knowledge entry.
const knowledgeProjectScopePrefix = 'project:';

/// The always-present global scope.
const knowledgeGlobalScope = 'global';

/// Max length of a knowledge entry's `hook` — the always-on index line
/// (ADR 0022 Decision 10). The hook is injected into every system prompt, so a
/// multi-KB hook would defeat the bounded-prompt premise. Shared by the service
/// validation and the panel's edit field so both enforce the same ceiling.
const knowledgeHookMaxLength = 120;

/// Builds a category scope string for [categoryId].
String knowledgeCategoryScope(String categoryId) =>
    '$knowledgeCategoryScopePrefix$categoryId';

/// Builds a project scope string for [projectId].
String knowledgeProjectScope(String projectId) =>
    '$knowledgeProjectScopePrefix$projectId';

/// The active Head set of durable knowledge: the most recent **confirmed**,
/// non-deleted entry per [PlannerKnowledgeEntity.key].
///
/// Recency wins (ADR 0022 Decision 10): a Friday "not-X" cleanly supersedes a
/// Monday "X" for the same key, and retracting the Friday head correctly
/// re-exposes the Monday one (only `confirmed`, non-retracted entries are
/// considered, so the next-most-recent confirmed entry resurfaces). Selection
/// is driven purely by status + recency; `PlannerKnowledgeEntity.supersedesId`
/// is provenance metadata only, not read here. This is a pure projection over
/// the full entry set, so it converges across devices without a separate Head
/// entity. Returned sorted by key for a stable, prefix-cache-friendly order.
List<PlannerKnowledgeEntity> activePlannerKnowledge(
  Iterable<PlannerKnowledgeEntity> entries,
) {
  final byKey = <String, PlannerKnowledgeEntity>{};
  for (final entry in entries) {
    if (entry.deletedAt != null) continue;
    if (entry.status != KnowledgeStatus.confirmed) continue;
    final current = byKey[entry.key];
    if (current == null || _isMoreRecent(entry, current)) {
      byKey[entry.key] = entry;
    }
  }
  final active = byKey.values.toList()..sort((a, b) => a.key.compareTo(b.key));
  return active;
}

/// Recency comparison: later `updatedAt` wins; ties break by id for
/// determinism (so two devices pick the same winner).
bool _isMoreRecent(PlannerKnowledgeEntity a, PlannerKnowledgeEntity b) {
  final byTime = a.updatedAt.compareTo(b.updatedAt);
  if (byTime != 0) return byTime > 0;
  return a.id.compareTo(b.id) > 0;
}

/// Whether [scope] is in-scope for a wake touching [touchedScopes].
///
/// `global` is always in scope. A `category:`/`project:` entry is in scope only
/// when the wake touches that exact scope — the two-tier retrieval that keeps
/// the prompt bounded as the planner ages.
bool knowledgeInScope(String scope, Set<String> touchedScopes) {
  if (scope == knowledgeGlobalScope) return true;
  return touchedScopes.contains(scope);
}

/// The always-present compact **hook index** block (Claude Code memory-index
/// pattern). One line per active key — the cheap, bounded tier that is always
/// in the prompt. Full statements are pulled in on demand via
/// [renderKnowledgeStatements].
///
/// Returns an empty string when there is no active knowledge, so callers can
/// omit the block entirely (and keep the prompt prefix byte-stable).
String renderKnowledgeHookIndex(List<PlannerKnowledgeEntity> active) {
  if (active.isEmpty) return '';
  final lines = [
    for (final entry in active)
      '- [${entry.key}] ${entry.hook} (scope: ${entry.scope})',
  ];
  return lines.join('\n');
}

/// The on-demand, scope-filtered full statements for the active knowledge the
/// current wake touches (`global` always; `category:`/`project:` when
/// [touchedScopes] includes them). Entries past their `reviewAfter` are flagged
/// for re-confirmation rather than silently trusted.
///
/// Returns an empty string when nothing is in scope.
String renderKnowledgeStatements(
  List<PlannerKnowledgeEntity> active,
  Set<String> touchedScopes, {
  required DateTime now,
}) {
  final inScope = [
    for (final entry in active)
      if (knowledgeInScope(entry.scope, touchedScopes)) entry,
  ];
  if (inScope.isEmpty) return '';
  final lines = [
    for (final entry in inScope) _statementLine(entry, now: now),
  ];
  return lines.join('\n');
}

String _statementLine(PlannerKnowledgeEntity entry, {required DateTime now}) {
  final reviewAfter = entry.reviewAfter;
  final stale = reviewAfter != null && !reviewAfter.isAfter(now);
  final suffix = stale ? ' (please re-confirm — this may be stale)' : '';
  return '- [${entry.key}] ${entry.statementText}$suffix';
}
