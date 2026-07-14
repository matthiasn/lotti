import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_shared.dart';
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
/// Pill colors come from the design system where available
/// (`alert.warning` for Timer). Audio, Images, and Code are not in the
/// token set yet — their hex values come straight from the Figma
/// activity-filter spec.
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
        children: [
          Expanded(
            child: Wrap(
              spacing: tokens.spacing.step3,
              runSpacing: tokens.spacing.step2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: LinkedEntryActivityFilter.values
                  .map(
                    (kind) => _ActivityPill(
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

    return DesignSystemFilterChoicePill(
      label: label,
      semanticsLabel: semanticsLabel,
      selected: activeLabels.isNotEmpty,
      role: DesignSystemFilterChoiceRole.action,
      leading: Icon(
        Icons.filter_list_rounded,
        size: tokens.spacing.step5,
        color: tokens.colors.interactive.enabled,
      ),
      onTap: () => showLinkedEntriesFilterModal(
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
  });

  final LinkedEntryActivityFilter kind;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spec = _ActivityPillSpec.of(context, kind);
    return DesignSystemFilterChoicePill(
      label: spec.label,
      selected: active,
      role: DesignSystemFilterChoiceRole.multiSelect,
      leading: Icon(
        spec.icon,
        size: tokens.spacing.step5,
        color: tokens.colors.interactive.enabled,
      ),
      onTap: onTap,
    );
  }
}

class _ActivityPillSpec {
  const _ActivityPillSpec({
    required this.label,
    required this.icon,
  });

  factory _ActivityPillSpec.of(
    BuildContext context,
    LinkedEntryActivityFilter kind,
  ) {
    final messages = context.messages;
    return switch (kind) {
      LinkedEntryActivityFilter.timer => _ActivityPillSpec(
        label: messages.journalLinkedEntriesActivityFilterTimer,
        icon: Icons.timer_outlined,
      ),
      LinkedEntryActivityFilter.audio => _ActivityPillSpec(
        label: messages.journalLinkedEntriesActivityFilterAudio,
        icon: Icons.mic_none_outlined,
      ),
      LinkedEntryActivityFilter.images => _ActivityPillSpec(
        label: messages.journalLinkedEntriesActivityFilterImages,
        icon: Icons.photo_outlined,
      ),
      LinkedEntryActivityFilter.code => _ActivityPillSpec(
        label: messages.journalLinkedEntriesActivityFilterCode,
        icon: Icons.code,
      ),
    };
  }

  final String label;
  final IconData icon;
}
