import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_shared.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

/// Single-page modal that lets the user pick the sort order for linked
/// entries, toggle visibility of hidden entries, and narrow the list to
/// flagged entries only. Reuses the same exclusive-choice pill
/// (`DesignSystemFilterChoicePill`) and palette as the task list filter
/// modal.
Future<void> showLinkedEntriesFilterModal({
  required BuildContext context,
  required String entryId,
}) {
  return ModalUtils.showSinglePageModal<void>(
    context: context,
    title: context.messages.journalLinkedEntriesFilterModalTitle,
    padding: const EdgeInsets.only(left: 20, top: 8, right: 20, bottom: 20),
    builder: (modalContext) => _LinkedEntriesFilterModalBody(entryId: entryId),
  );
}

class _LinkedEntriesFilterModalBody extends ConsumerWidget {
  const _LinkedEntriesFilterModalBody({required this.entryId});

  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final palette = DesignSystemFilterPalette.fromTokens(tokens);
    final messages = context.messages;
    final spacing = tokens.spacing;

    final sortOrder = ref.watch(
      linkedEntriesSortControllerProvider(entryId),
    );
    final sortNotifier = ref.read(
      linkedEntriesSortControllerProvider(entryId).notifier,
    );

    final includeHidden = ref.watch(
      includeHiddenControllerProvider(entryId),
    );
    final includeHiddenNotifier = ref.read(
      includeHiddenControllerProvider(entryId).notifier,
    );

    final showFlaggedOnly = ref.watch(
      showFlaggedOnlyControllerProvider(entryId),
    );
    final showFlaggedOnlyNotifier = ref.read(
      showFlaggedOnlyControllerProvider(entryId).notifier,
    );

    String sortLabel(LinkedEntriesSortOrder option) => switch (option) {
      LinkedEntriesSortOrder.newestFirst =>
        messages.journalLinkedEntriesSortNewestFirst,
      LinkedEntriesSortOrder.oldestFirst =>
        messages.journalLinkedEntriesSortOldestFirst,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SectionLabel(
          text: messages.journalLinkedEntriesSortLabel,
          palette: palette,
          tokens: tokens,
        ),
        SizedBox(height: spacing.step4),
        Wrap(
          spacing: spacing.step3,
          runSpacing: spacing.step3,
          children: [
            for (final option in LinkedEntriesSortOrder.values)
              DesignSystemFilterChoicePill(
                key: ValueKey('linked-entries-sort-${option.name}'),
                label: sortLabel(option),
                selected: sortOrder == option,
                palette: palette,
                textStyle: tokens.typography.styles.subtitle.subtitle2,
                onTap: () => sortNotifier.order = option,
              ),
          ],
        ),
        SizedBox(height: spacing.step6),
        _ToggleRow(
          label: messages.journalLinkedEntriesShowHidden,
          value: includeHidden,
          palette: palette,
          tokens: tokens,
          onChanged: () => includeHiddenNotifier.includeHidden = !includeHidden,
        ),
        _ToggleRow(
          label: messages.journalLinkedEntriesShowFlaggedOnly,
          value: showFlaggedOnly,
          palette: palette,
          tokens: tokens,
          onChanged: () =>
              showFlaggedOnlyNotifier.showFlaggedOnly = !showFlaggedOnly,
        ),
        SizedBox(height: spacing.step8),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.text,
    required this.palette,
    required this.tokens,
  });

  final String text;
  final DesignSystemFilterPalette palette;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: tokens.typography.styles.others.caption.copyWith(
        color: palette.secondaryText,
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.palette,
    required this.tokens,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final DesignSystemFilterPalette palette;
  final DsTokens tokens;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(tokens.radii.m),
          onTap: onChanged,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: tokens.spacing.step3),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                      color: palette.primaryText,
                    ),
                  ),
                ),
                SizedBox(
                  height: tokens.spacing.step6,
                  width: tokens.spacing.step8,
                  child: FittedBox(
                    child: ExcludeSemantics(
                      child: IgnorePointer(
                        child: Switch.adaptive(
                          value: value,
                          activeTrackColor: palette.accent,
                          onChanged: (_) {},
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
