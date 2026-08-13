import 'package:lotti/classes/entry_link.dart';
import 'package:meta/meta.dart';

/// The 6 task-relationship types, in display order. `rating`/`project` are
/// excluded — they're not user-facing task relationships.
const List<EntryLinkType> relationshipSelectorTypes = [
  EntryLinkType.basic,
  EntryLinkType.blocks,
  EntryLinkType.followsUp,
  EntryLinkType.duplicates,
  EntryLinkType.fixes,
  EntryLinkType.supersedes,
];

/// A relationship exactly as a user picks it: the type *and* which of the two
/// tasks is its subject.
///
/// Type and direction are one choice, not two. Every established
/// task/issue tracker presents relations as a single flat list of directed
/// phrases — "Blocks", "Is blocked by", "Duplicates", "Is duplicated by" —
/// rather than a type control plus a separate direction switch. Splitting them
/// forced the same word to appear twice on screen ("Blocks" selected above a
/// toggle whose first segment also read "Blocks"), which reviewers and test
/// users repeatedly read as a duplicated or contradictory control.
///
/// The same directed phrases are the task agent's tool vocabulary: [wireName]
/// is the machine-readable id a tool schema enumerates, [fromWireName] parses
/// it back, and [canonicalEndpoints] resolves which task is `fromId` — so the
/// voice path and the picker can never disagree about what "is blocked by"
/// means.
@immutable
class DirectedRelation {
  const DirectedRelation(this.type, {this.inverse = false});

  final EntryLinkType type;

  /// True when the *other* task is the subject — i.e. the caller must swap
  /// `fromId`/`toId` before persisting the canonical direction.
  final bool inverse;

  /// Whether the relation reads the same from either end. A plain link says
  /// only that two tasks are related, so it has no primary/inverse phrasing
  /// and the picker offers exactly one option for it.
  bool get isSymmetric => type == EntryLinkType.basic;

  /// [inverse] normalised: meaningless on a symmetric relation, so it must not
  /// take part in identity. It once did, which meant an existing *incoming*
  /// plain link never matched the plain link the picker offers — so the picker
  /// re-offered a task the card already listed, and taking it produced two
  /// identical rows, an inflated count, and two confirmations to undo one
  /// relationship.
  bool get directed => !isSymmetric && inverse;

  /// Stable identity for `DesignSystemDropdownItem.id`.
  String get id => '${type.name}.${directed ? 'inverse' : 'primary'}';

  /// The machine-readable directed phrase, e.g. `blocks` vs `is_blocked_by`.
  ///
  /// This is the value agent tool schemas enumerate and LLM tool calls carry;
  /// it must stay stable because persisted change-set proposals reference it.
  /// Throws [StateError] for `rating`/`project`, which are not task
  /// relationships and never appear in [relationshipDirectedOptions].
  String get wireName {
    switch (type) {
      case EntryLinkType.basic:
        return 'relates_to';
      case EntryLinkType.blocks:
        return directed ? 'is_blocked_by' : 'blocks';
      case EntryLinkType.followsUp:
        return directed ? 'has_follow_up' : 'follows_up_on';
      case EntryLinkType.duplicates:
        return directed ? 'is_duplicated_by' : 'duplicates';
      case EntryLinkType.fixes:
        return directed ? 'is_fixed_by' : 'fixes';
      case EntryLinkType.supersedes:
        return directed ? 'is_superseded_by' : 'supersedes';
      case EntryLinkType.rating:
      case EntryLinkType.project:
      case EntryLinkType.relationship:
        throw StateError('$type is not a task relationship');
    }
  }

  /// The English directed phrase completing "This task …", e.g. `blocks` vs
  /// `is blocked by`.
  ///
  /// Used where no `BuildContext` exists — persisted proposal summaries and
  /// tool outputs, which are English by convention (like every other
  /// `humanSummary`). UI surfaces use the localized phrases in
  /// `relationship_type_selector.dart` instead.
  String get englishPhrase {
    switch (type) {
      case EntryLinkType.basic:
        return 'relates to';
      case EntryLinkType.blocks:
        return directed ? 'is blocked by' : 'blocks';
      case EntryLinkType.followsUp:
        return directed ? 'has follow-up' : 'follows up on';
      case EntryLinkType.duplicates:
        return directed ? 'is duplicated by' : 'duplicates';
      case EntryLinkType.fixes:
        return directed ? 'is fixed by' : 'fixes';
      case EntryLinkType.supersedes:
        return directed ? 'is superseded by' : 'supersedes';
      case EntryLinkType.rating:
      case EntryLinkType.project:
      case EntryLinkType.relationship:
        throw StateError('$type is not a task relationship');
    }
  }

  /// Resolves the canonical stored `fromId`/`toId` for this relation between
  /// [anchorId] (the sentence subject, "this task") and [otherId].
  ///
  /// A primary phrase keeps the anchor as `fromId`; an inverse phrase swaps,
  /// so the canonical direction is always the one the primary phrase reads —
  /// a `blocks` link's `fromId` is always the blocker.
  ({String fromId, String toId}) canonicalEndpoints({
    required String anchorId,
    required String otherId,
  }) => directed
      ? (fromId: otherId, toId: anchorId)
      : (fromId: anchorId, toId: otherId);

  /// Parses a [wireName] back into its relation, tolerating surrounding
  /// whitespace and case. Returns `null` for anything outside the vocabulary.
  static DirectedRelation? fromWireName(String name) {
    final normalized = name.trim().toLowerCase();
    for (final option in relationshipDirectedOptions) {
      if (option.wireName == normalized) return option;
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is DirectedRelation &&
      other.type == type &&
      other.directed == directed;

  @override
  int get hashCode => Object.hash(type, directed);

  @override
  String toString() => 'DirectedRelation(${type.name}, inverse: $directed)';
}

/// One relationship that already exists between the anchor task and another
/// task.
///
/// Exclusion from the link picker is per-relation, not per-task: the schema's
/// `UNIQUE(from_id, to_id, type)` lets one pair of tasks hold several
/// different relationships, so excluding every task the anchor already touches
/// made a legitimate second relationship impossible to create — and reported
/// it as "No tasks found".
@immutable
class ExistingRelation {
  const ExistingRelation({required this.taskId, required this.relation});

  final String taskId;
  final DirectedRelation relation;

  @override
  bool operator ==(Object other) =>
      other is ExistingRelation &&
      other.taskId == taskId &&
      other.relation == relation;

  @override
  int get hashCode => Object.hash(taskId, relation);
}

/// Every relationship a user can pick, in display order: the symmetric plain
/// link first (today's default, unchanged when untouched), then each
/// directional type in both directions.
List<DirectedRelation> get relationshipDirectedOptions => [
  const DirectedRelation(EntryLinkType.basic),
  for (final type in relationshipSelectorTypes)
    if (type != EntryLinkType.basic) ...[
      DirectedRelation(type),
      DirectedRelation(type, inverse: true),
    ],
];
