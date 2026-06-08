/// Author-time memory links (convergence-safe A-MEM, Phase 0).
///
/// An agent records relationships between memory entries by writing inline
/// `[[relation:entryId]]` tokens into the free-text content of an observation
/// (or any note it authors). The tokens are plain content of an append-only
/// entry: they never mutate history, never touch the cached prompt prefix, and
/// stay convergent across devices because the cited `entryId` is the synced
/// entity id the agent saw in the log. This file is the pure parse + validate
/// layer; recall (`search_memory`) resolves and surfaces the links on demand.
library;

import 'package:equatable/equatable.dart';

/// The closed vocabulary of memory-link relations. Closed so handling stays
/// deterministic and specific relations can map onto existing mechanisms
/// (e.g. `supersedes` → recency-wins recall).
enum LinkRelation {
  /// This note sharpens/clarifies an earlier one; both stay true. Also how the
  /// agent records a "new version" of a note without rewriting the old one.
  refines,

  /// This note replaces an earlier one; the earlier is no longer the live truth.
  supersedes,

  /// This note conflicts with an earlier one (surface for the user).
  contradicts,

  /// Generic association.
  relates;

  /// The lowercase wire token used inside `[[relation:id]]`.
  String get wire => name;
}

/// Resolves a wire token (case-insensitive) to its [LinkRelation], or null when
/// it is outside the closed vocabulary.
LinkRelation? linkRelationFromWire(String wire) {
  final lower = wire.toLowerCase();
  for (final relation in LinkRelation.values) {
    if (relation.wire == lower) return relation;
  }
  return null;
}

/// One author-time link parsed from note content: a [relation] to a target
/// memory [entryId].
class MemoryLink extends Equatable {
  /// Creates a link.
  const MemoryLink({required this.relation, required this.entryId});

  /// The relationship this note asserts to [entryId].
  final LinkRelation relation;

  /// The cited target entry id (a synced entity id the agent saw in the log).
  final String entryId;

  @override
  List<Object?> get props => [relation, entryId];

  @override
  String toString() => 'MemoryLink(${relation.wire}:$entryId)';
}

/// Matches `[[relation:entryId]]`. The relation is letters; the entry id is the
/// synced entity-id charset (uuids and slugs). Tolerant — anything that does
/// not match is left as ordinary prose.
final _linkPattern = RegExp(r'\[\[([A-Za-z]+):([A-Za-z0-9_\-]+)\]\]');

/// Parses every well-formed `[[relation:entryId]]` token from [content],
/// dropping tokens whose relation is outside the closed vocabulary and
/// de-duplicating while preserving first-seen order. Never throws.
List<MemoryLink> parseMemoryLinks(String content) {
  final seen = <MemoryLink>{};
  final result = <MemoryLink>[];
  for (final match in _linkPattern.allMatches(content)) {
    final relation = linkRelationFromWire(match.group(1)!);
    if (relation == null) continue;
    final link = MemoryLink(relation: relation, entryId: match.group(2)!);
    if (seen.add(link)) result.add(link);
  }
  return result;
}

/// A [MemoryLink] validated against the known memory log: whether its target
/// [exists], and — following any supersession chain — the [liveEntryId] that is
/// the current version (equal to the link's `entryId` when nothing supersedes
/// it).
class ResolvedMemoryLink extends Equatable {
  /// Creates a resolved link.
  const ResolvedMemoryLink({
    required this.link,
    required this.exists,
    required this.liveEntryId,
  });

  /// The parsed link this resolution describes.
  final MemoryLink link;

  /// True when [MemoryLink.entryId] resolves to a real entry the agent can pull
  /// up. A false value marks a dead link (typically a hallucinated id) — never
  /// followed, never fabricated.
  final bool exists;

  /// The current entry id after forward-following supersession; equals
  /// `link.entryId` when the target is live (or unknown).
  final String liveEntryId;

  /// True when the target has been superseded by a newer entry.
  bool get superseded => liveEntryId != link.entryId;

  @override
  List<Object?> get props => [link, exists, liveEntryId];
}

/// Validates [links] against the memory log. [knownIds] is the set of entry ids
/// the agent could legitimately reference (every log entry, plus any extra ids
/// the caller widens with). [supersededBy] maps an entry id to the id that
/// supersedes it; resolution follows that chain (guarding against cycles) to the
/// live id — except for `supersedes` links themselves, whose whole purpose is to
/// name the *old* entry, so they are never forward-followed. Pure — no IO.
List<ResolvedMemoryLink> resolveMemoryLinks(
  List<MemoryLink> links, {
  required Set<String> knownIds,
  Map<String, String> supersededBy = const {},
}) {
  return [
    for (final link in links)
      ResolvedMemoryLink(
        link: link,
        exists: knownIds.contains(link.entryId),
        liveEntryId: link.relation == LinkRelation.supersedes
            ? link.entryId
            : _followSupersession(link.entryId, supersededBy),
      ),
  ];
}

/// Walks the [supersededBy] chain from [entryId] to the newest live id,
/// stopping on a missing edge or a cycle.
String _followSupersession(String entryId, Map<String, String> supersededBy) {
  var current = entryId;
  final visited = <String>{current};
  while (true) {
    final next = supersededBy[current];
    if (next == null || !visited.add(next)) return current;
    current = next;
  }
}
