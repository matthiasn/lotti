import 'package:flutter/material.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/features/design_system/components/dropdowns/design_system_dropdown.dart';
import 'package:lotti/features/tasks/model/directed_relation.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

export 'package:lotti/features/tasks/model/directed_relation.dart';

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
    case EntryLinkType.relationship:
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
      // Paired with the task picker's small search field directly below it in
      // the link modal, so it takes that variant's corner radius.
      size: DesignSystemDropdownSize.small,
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
