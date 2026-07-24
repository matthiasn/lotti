import 'package:flutter/material.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/features/design_system/components/dropdowns/design_system_dropdown.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

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
@immutable
class DirectedRelation {
  const DirectedRelation(this.type, {this.inverse = false});

  final EntryLinkType type;

  /// True when the *other* task is the subject — i.e. the caller must swap
  /// `fromId`/`toId` before persisting the canonical direction.
  final bool inverse;

  /// Stable identity for [DesignSystemDropdownItem.id].
  String get id => '${type.name}.${inverse ? 'inverse' : 'primary'}';

  @override
  bool operator ==(Object other) =>
      other is DirectedRelation &&
      other.type == type &&
      other.inverse == inverse;

  @override
  int get hashCode => Object.hash(type, inverse);
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

/// The (primary, inverse) phrasing pair for a directional relationship type,
/// or null for `basic` (symmetric — no phrasing choice). Shared by the
/// picker's option list and the grouped-section headers, so the same words
/// describe a relationship whether read off the picker or off the card.
(String primary, String inverse)? relationshipPhrasePair(
  BuildContext context,
  EntryLinkType type,
) {
  switch (type) {
    case EntryLinkType.blocks:
      return (
        context.messages.linkPhraseBlocksPrimary,
        context.messages.linkPhraseBlocksInverse,
      );
    case EntryLinkType.followsUp:
      return (
        context.messages.linkPhraseFollowsUpPrimary,
        context.messages.linkPhraseFollowsUpInverse,
      );
    case EntryLinkType.duplicates:
      return (
        context.messages.linkPhraseDuplicatesPrimary,
        context.messages.linkPhraseDuplicatesInverse,
      );
    case EntryLinkType.fixes:
      return (
        context.messages.linkPhraseFixesPrimary,
        context.messages.linkPhraseFixesInverse,
      );
    case EntryLinkType.supersedes:
      return (
        context.messages.linkPhraseSupersedesPrimary,
        context.messages.linkPhraseSupersedesInverse,
      );
    case EntryLinkType.basic:
    case EntryLinkType.rating:
    case EntryLinkType.project:
      return null;
  }
}

/// The phrase for one directed relation, e.g. "Blocks" vs "Is blocked by".
/// The symmetric plain link reads "Relates to" so every option in the list
/// completes the same sentence stem.
String directedRelationLabel(BuildContext context, DirectedRelation relation) {
  final pair = relationshipPhrasePair(context, relation.type);
  if (pair == null) return context.messages.linkPhraseBasic;
  return relation.inverse ? pair.$2 : pair.$1;
}

/// The relationship picker shared by `LinkTaskModal` (linking an existing
/// task), `EditLinkTypeModal` (retyping one in place), and the "Create new
/// linked task…" flow.
///
/// A single dropdown completing the sentence "This task… ⟨Blocks⟩", listing
/// every relationship in both directions. Picking "Is blocked by" means the
/// caller swaps `fromId`/`toId` before persisting, since a `blocks` link's
/// `fromId` is always the blocker.
class RelationshipTypeSelector extends StatelessWidget {
  const RelationshipTypeSelector({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final DirectedRelation selected;
  final ValueChanged<DirectedRelation> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = relationshipDirectedOptions;
    return DesignSystemDropdown(
      label: context.messages.linkDirectionLabel,
      inputLabel: directedRelationLabel(context, selected),
      items: [
        for (final option in options)
          DesignSystemDropdownItem(
            id: option.id,
            label: directedRelationLabel(context, option),
            selected: option == selected,
          ),
      ],
      onItemPressed: (item) => onChanged(
        options.firstWhere((option) => option.id == item.id),
      ),
    );
  }
}
