import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/chips/design_system_chip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/linked_entries_activity_filter.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/features/journal/ui/widgets/linked_entries_filter_modal.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// Activity-filter pill row above the linked entries list.
///
/// One row, always visible: a toggle chip per activity kind, then the sort
/// and filter trigger.
///
/// The kind chips are the design system's own filter chip, neutral with the
/// shared selected state: a kind is not a state and not the agent's voice, so
/// it carries no hue of its own.
class LinkedEntriesActivityFilterBar extends ConsumerWidget {
  const LinkedEntriesActivityFilterBar({required this.entryId, super.key});

  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final activeKinds = ref.watch(
      linkedEntriesActivityFilterControllerProvider(entryId),
    );
    final notifier = ref.read(
      linkedEntriesActivityFilterControllerProvider(entryId).notifier,
    );
    final hasCodingPrompt = ref.watch(
      resolvedOutgoingLinkedEntriesProvider(entryId).select(
        (entities) => entities.any(
          (entity) =>
              LinkedEntryActivityFilter.fromEntity(entity) ==
              LinkedEntryActivityFilter.code,
        ),
      ),
    );

    final sortOrder = ref.watch(
      linkedEntriesSortControllerProvider(entryId),
    );
    final includeHidden = ref.watch(includeHiddenControllerProvider(entryId));
    final showFlaggedOnly = ref.watch(
      showFlaggedOnlyControllerProvider(entryId),
    );

    return Padding(
      padding: EdgeInsets.only(
        left: tokens.spacing.step3,
        right: tokens.spacing.step3,
        bottom: tokens.spacing.step4,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Wrap(
              spacing: tokens.spacing.step3,
              runSpacing: tokens.spacing.step2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: LinkedEntryActivityFilter.values
                  .where(
                    (kind) =>
                        kind != LinkedEntryActivityFilter.code ||
                        hasCodingPrompt,
                  )
                  .map(
                    (kind) => _ActivityPill(
                      key: ValueKey('linked-entries-activity-${kind.name}'),
                      kind: kind,
                      active: activeKinds.contains(kind),
                      onTap: () => notifier.toggle(kind),
                    ),
                  )
                  .toList(),
            ),
          ),
          SizedBox(width: tokens.spacing.step3),
          _FilterTrigger(
            entryId: entryId,
            sortOrder: sortOrder,
            includeHidden: includeHidden,
            showFlaggedOnly: showFlaggedOnly,
          ),
        ],
      ),
    );
  }
}

class _FilterTrigger extends StatelessWidget {
  const _FilterTrigger({
    required this.entryId,
    required this.sortOrder,
    required this.includeHidden,
    required this.showFlaggedOnly,
  });

  final String entryId;
  final LinkedEntriesSortOrder sortOrder;
  final bool includeHidden;
  final bool showFlaggedOnly;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final label = switch (sortOrder) {
      LinkedEntriesSortOrder.newestFirst =>
        messages.journalLinkedEntriesSortNewestFirst,
      LinkedEntriesSortOrder.oldestFirst =>
        messages.journalLinkedEntriesSortOldestFirst,
    };
    final activeLabels = [
      if (includeHidden) messages.journalLinkedEntriesShowHidden,
      if (showFlaggedOnly) messages.journalLinkedEntriesShowFlaggedOnly,
    ];
    final semanticsLabel = [
      messages.journalLinkedEntriesFilterModalTitle,
      label,
      ...activeLabels,
    ].join(', ');

    // The same chip as the kinds beside it, so the row is one height and
    // one shape; it stays an outline because it opens a sheet and is never
    // itself "on".
    return DesignSystemChip(
      key: const ValueKey('linked-entries-sort-trigger'),
      label: label,
      semanticsLabel: semanticsLabel,
      leadingIcon: LottiIcons.filter,
      outlined: true,
      size: DesignSystemChipSize.compactPill,
      trailing: activeLabels.isEmpty
          ? null
          : ExcludeSemantics(
              child: Container(
                key: const ValueKey(
                  'linked-entries-sort-trigger-active-count',
                ),
                constraints: BoxConstraints(minWidth: tokens.spacing.step5),
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.spacing.step2,
                ),
                decoration: BoxDecoration(
                  color: tokens.colors.surface.active,
                  borderRadius: BorderRadius.circular(
                    tokens.radii.badgesPills,
                  ),
                ),
                child: Text(
                  '${activeLabels.length}',
                  textAlign: TextAlign.center,
                  style: tokens.typography.styles.others.caption.copyWith(
                    color: tokens.colors.text.highEmphasis,
                    fontWeight: tokens.typography.weight.semiBold,
                    height: 1,
                  ),
                ),
              ),
            ),
      onPressed: () => showLinkedEntriesFilterModal(
        context: context,
        entryId: entryId,
      ),
    );
  }
}

class _ActivityPill extends StatelessWidget {
  const _ActivityPill({
    required this.kind,
    required this.active,
    required this.onTap,
    super.key,
  });

  final LinkedEntryActivityFilter kind;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    final (label, icon) = switch (kind) {
      LinkedEntryActivityFilter.timer => (
        messages.journalLinkedEntriesActivityFilterTimer,
        LottiIcons.timer,
      ),
      LinkedEntryActivityFilter.audio => (
        messages.journalLinkedEntriesActivityFilterAudio,
        LottiIcons.mic,
      ),
      LinkedEntryActivityFilter.images => (
        messages.journalLinkedEntriesActivityFilterImages,
        LottiIcons.image,
      ),
      LinkedEntryActivityFilter.code => (
        messages.journalLinkedEntriesActivityFilterCode,
        LottiIcons.code,
      ),
    };
    return DesignSystemChip(
      label: label,
      leadingIcon: icon,
      selected: active,
      // Every kind is on by default, so "on" is the quiet neutral fill and
      // the outline is what is left when a kind is switched off.
      outlined: true,
      quietSelection: true,
      size: DesignSystemChipSize.compactPill,
      onPressed: onTap,
    );
  }
}
