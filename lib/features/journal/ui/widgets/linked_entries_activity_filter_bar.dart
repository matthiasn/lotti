import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/linked_entries_activity_filter.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/features/journal/ui/widgets/linked_entries_filter_modal.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Activity-filter pill row above the linked entries list.
///
/// Implements the Figma "Activity Filter" treatment as a single
/// horizontally-centered pill row that's always visible on every
/// breakpoint.
///
/// Every control uses the same compact [DsPill] shell as the task header.
/// Active activity kinds keep their own accent on the leading icon while the
/// shared filled surface and accent-matched border provide one consistent pill
/// shape. Inactive kinds fall back to the task header's quiet neutral border.
/// Timer's accent comes from `alert.warning`; Audio, Images, and Code retain
/// the colors from the Figma activity-filter spec because the token set does
/// not expose semantic equivalents yet.
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

    final radius = BorderRadius.circular(tokens.radii.badgesPills);
    return Semantics(
      key: const ValueKey('linked-entries-sort-trigger'),
      button: true,
      label: semanticsLabel,
      onTap: () => showLinkedEntriesFilterModal(
        context: context,
        entryId: entryId,
      ),
      excludeSemantics: true,
      child: DsPill(
        key: const ValueKey('linked-entries-sort-trigger-visual'),
        variant: DsPillVariant.filled,
        bordered: true,
        label: label,
        labelColor: tokens.colors.text.mediumEmphasis,
        leading: Icon(
          Icons.filter_list_rounded,
          size: tokens.spacing.step4,
          color: tokens.colors.interactive.enabled,
        ),
        trailing: activeLabels.isEmpty
            ? null
            : Container(
                key: const ValueKey(
                  'linked-entries-sort-trigger-active-count',
                ),
                constraints: BoxConstraints(minWidth: tokens.spacing.step5),
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.spacing.step2,
                ),
                decoration: BoxDecoration(
                  color: tokens.colors.surface.active,
                  borderRadius: radius,
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
        onTap: () => showLinkedEntriesFilterModal(
          context: context,
          entryId: entryId,
        ),
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
    final tokens = context.designTokens;
    final spec = _ActivityPillSpec.of(context, kind);
    final iconColor = active ? spec.accent : tokens.colors.text.lowEmphasis;

    return Semantics(
      button: true,
      toggled: active,
      label: spec.label,
      onTap: onTap,
      excludeSemantics: true,
      child: DsPill(
        key: ValueKey('linked-entries-activity-${kind.name}-visual'),
        variant: DsPillVariant.filled,
        bordered: true,
        borderColor: active
            ? spec.accent.withValues(alpha: spec.borderAlpha)
            : null,
        label: spec.label,
        labelColor: tokens.colors.text.mediumEmphasis,
        leading: Icon(
          spec.icon,
          size: tokens.spacing.step4,
          color: iconColor,
        ),
        onTap: onTap,
      ),
    );
  }
}

class _ActivityPillSpec {
  const _ActivityPillSpec({
    required this.label,
    required this.icon,
    required this.accent,
    required this.borderAlpha,
  });

  factory _ActivityPillSpec.of(
    BuildContext context,
    LinkedEntryActivityFilter kind,
  ) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return switch (kind) {
      LinkedEntryActivityFilter.timer => _ActivityPillSpec(
        label: messages.journalLinkedEntriesActivityFilterTimer,
        icon: Icons.timer_outlined,
        accent: tokens.colors.alert.warning.defaultColor,
        borderAlpha: 1,
      ),
      LinkedEntryActivityFilter.audio => _ActivityPillSpec(
        label: messages.journalLinkedEntriesActivityFilterAudio,
        icon: Icons.mic_none_outlined,
        accent: const Color(0xFF9966E5),
        borderAlpha: 0.7,
      ),
      LinkedEntryActivityFilter.images => _ActivityPillSpec(
        label: messages.journalLinkedEntriesActivityFilterImages,
        icon: Icons.photo_outlined,
        accent: const Color(0xFF619EFF),
        borderAlpha: 0.7,
      ),
      LinkedEntryActivityFilter.code => _ActivityPillSpec(
        label: messages.journalLinkedEntriesActivityFilterCode,
        icon: Icons.code,
        accent: const Color(0xFF34C759),
        borderAlpha: 0.7,
      ),
    };
  }

  final String label;
  final IconData icon;
  final Color accent;
  final double borderAlpha;
}
