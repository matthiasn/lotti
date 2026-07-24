import 'package:flutter/material.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/features/design_system/components/buttons/ds_segmented_toggle.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// The 6 relationship types offered by [RelationshipTypeSelector], in display
/// order. `rating`/`project` are excluded — they're not user-facing task
/// relationships.
const List<EntryLinkType> relationshipSelectorTypes = [
  EntryLinkType.basic,
  EntryLinkType.blocks,
  EntryLinkType.followsUp,
  EntryLinkType.duplicates,
  EntryLinkType.fixes,
  EntryLinkType.supersedes,
];

/// Compact chip label for a relationship type (the picker's primary row).
String relationshipTypeOptionLabel(BuildContext context, EntryLinkType type) {
  switch (type) {
    case EntryLinkType.basic:
      return context.messages.linkTypeBasicOption;
    case EntryLinkType.blocks:
      return context.messages.linkTypeBlocksOption;
    case EntryLinkType.followsUp:
      return context.messages.linkTypeFollowsUpOption;
    case EntryLinkType.duplicates:
      return context.messages.linkTypeDuplicatesOption;
    case EntryLinkType.fixes:
      return context.messages.linkTypeFixesOption;
    case EntryLinkType.supersedes:
      return context.messages.linkTypeSupersedesOption;
    case EntryLinkType.rating:
    case EntryLinkType.project:
      throw StateError('$type is not a task-relationship option');
  }
}

/// The (primary, inverse) phrasing pair for a directional relationship type,
/// or null for `basic` (symmetric — no phrasing choice). Shared by the
/// picker's phrasing toggle and the grouped-section row captions, so the same
/// words describe a relationship whether read off a toggle or a row.
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

/// The relationship-type + direction picker shared by `LinkTaskModal` (linking
/// an existing task) and the "Create new linked task…" flow: 6 primary chips
/// (Link/Blocks/Follows up/Duplicates/Fixes/Supersedes), defaulting to "Link"
/// (today's plain-link behavior, unchanged when untouched). Selecting a
/// directional type reveals a second toggle for the two phrasings (e.g.
/// "Blocks" vs "Is blocked by") — picking the inverse phrasing means the
/// caller should swap `fromId`/`toId` before persisting the canonical
/// direction (`EntryLinkType.blocks`'s `fromId` is always the blocker).
class RelationshipTypeSelector extends StatelessWidget {
  const RelationshipTypeSelector({
    required this.selectedType,
    required this.inverse,
    required this.onTypeChanged,
    required this.onInverseChanged,
    super.key,
  });

  final EntryLinkType selectedType;
  final bool inverse;
  final ValueChanged<EntryLinkType> onTypeChanged;
  final ValueChanged<bool> onInverseChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final phrasePair = relationshipPhrasePair(context, selectedType);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: tokens.spacing.step2,
          runSpacing: tokens.spacing.step2,
          children: [
            for (final type in relationshipSelectorTypes)
              DsPill(
                variant: DsPillVariant.filled,
                bordered: true,
                selected: type == selectedType,
                label: relationshipTypeOptionLabel(context, type),
                onTap: () => onTypeChanged(type),
              ),
          ],
        ),
        if (phrasePair != null) ...[
          SizedBox(height: tokens.spacing.step2),
          DsSegmentedToggle<bool>(
            segments: [
              DsSegment(false, phrasePair.$1),
              DsSegment(true, phrasePair.$2),
            ],
            selected: inverse,
            onChanged: onInverseChanged,
          ),
        ],
      ],
    );
  }
}
