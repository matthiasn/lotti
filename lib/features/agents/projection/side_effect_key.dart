import 'package:lotti/features/agents/projection/content_digest.dart';

/// Domain tag for the input-frontier digest, isolating it from every other
/// content-addressed use (the join id `join-v1`, the summary coverage digest):
/// the tag is part of the hashed content, so the digests hash different shapes
/// and can never collide or be confused.
const String _inputFrontierTag = 'input-frontier-v1';

/// Domain tag for the side-effect idempotency key (ADR 0018 rule 9).
const String _sideEffectTag = 'side-effect-v1';

/// Content-addressed digest of an agent's **active input frontier** — the
/// `{contentEntryId → contentDigest}` map from `inputFrontierDigests`
/// (ADR 0020 / PR 5). Captures the exact content version a wake acted on, so a
/// later wake over *changed* content yields a different digest.
///
/// A pure function of the frontier *set*: `ContentDigest.of` sorts map keys, so
/// the digest is independent of insertion order. Domain-tagged and versioned.
/// Used as the `frontierDigest` component of [sideEffectKey].
String frontierDigest(Map<String, String> activeDigestByEntry) =>
    ContentDigest.of({
      '_tag': _inputFrontierTag,
      'frontier': activeDigestByEntry,
    });

/// The **side-effect idempotency key** (ADR 0018 rule 9): a content-addressed
/// value over `{agentId, behaviorKind, frontierDigest, triggerId, toolName}`.
///
/// Two devices executing the *same behaviour* ([behaviorKind]) over the *same
/// inputs* ([frontierDigest]) for the *same wake epoch* ([triggerId]) emitting
/// the *same tool effect* ([toolName]) compute a **byte-identical key** — so the
/// effect can be deduped (the projection suppresses duplicates; ADR 0018 rule 9
/// / ADR 0009) rather than committed twice. [triggerId] must be a stable,
/// source-derived identity (a subscription id, a scheduled-wake due-at, or a
/// synced trigger token) — never a per-run UUID — and it carries the wake-epoch
/// scoping, so a later time-sensitive wake over an unchanged frontier is *not*
/// wrongly suppressed.
///
/// A pure function of its components; each is keyed distinctly (no concatenation
/// ambiguity) and the result is domain-tagged and versioned.
String sideEffectKey({
  required String agentId,
  required String behaviorKind,
  required String frontierDigest,
  required String triggerId,
  required String toolName,
}) => ContentDigest.of({
  '_tag': _sideEffectTag,
  'agentId': agentId,
  'behaviorKind': behaviorKind,
  'frontierDigest': frontierDigest,
  'triggerId': triggerId,
  'toolName': toolName,
});
