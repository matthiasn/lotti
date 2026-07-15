import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_shared.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

/// Compact single-page filter for linked-entry sort and visibility settings.
Future<void> showLinkedEntriesFilterModal({
  required BuildContext context,
  required String entryId,
}) {
  final spacing = context.designTokens.spacing;
  return ModalUtils.showSinglePageModal<void>(
    context: context,
    title: context.messages.journalLinkedEntriesFilterModalTitle,
    closeButtonIcon: Icons.check_rounded,
    closeButtonTooltip: context.messages.doneButton,
    padding: EdgeInsets.fromLTRB(
      spacing.step5,
      spacing.step2,
      spacing.step5,
      spacing.step6,
    ),
    builder: (modalContext) => _LinkedEntriesFilterModalBody(entryId: entryId),
  );
}

class _LinkedEntriesFilterModalBody extends ConsumerWidget {
  const _LinkedEntriesFilterModalBody({required this.entryId});

  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final spacing = tokens.spacing;
    final sortOrder = ref.watch(linkedEntriesSortControllerProvider(entryId));
    final sortNotifier = ref.read(
      linkedEntriesSortControllerProvider(entryId).notifier,
    );
    final includeHidden = ref.watch(includeHiddenControllerProvider(entryId));
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SectionLabel(text: messages.journalLinkedEntriesSortLabel),
        SizedBox(height: spacing.step3),
        Wrap(
          spacing: spacing.step3,
          runSpacing: spacing.step2,
          children: [
            for (final option in LinkedEntriesSortOrder.values)
              DesignSystemFilterChoicePill(
                key: ValueKey('linked-entries-sort-${option.name}'),
                label: sortLabel(option),
                selected: sortOrder == option,
                role: DesignSystemFilterChoiceRole.singleSelect,
                onTap: () => sortNotifier.order = option,
              ),
          ],
        ),
        SizedBox(height: spacing.step6),
        _SectionLabel(text: messages.journalFilterShowTitle),
        SizedBox(height: spacing.step4),
        DesignSystemFilterToggleRow(
          label: messages.journalLinkedEntriesShowHidden,
          value: includeHidden,
          onChanged: (value) {
            includeHiddenNotifier.includeHidden = value;
          },
        ),
        SizedBox(height: spacing.step1),
        DesignSystemFilterToggleRow(
          label: messages.journalLinkedEntriesShowFlaggedOnly,
          value: showFlaggedOnly,
          onChanged: (value) {
            showFlaggedOnlyNotifier.showFlaggedOnly = value;
          },
        ),
        SizedBox(height: spacing.step4),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Text(
      text,
      style: tokens.typography.styles.subtitle.subtitle2.copyWith(
        color: tokens.colors.text.mediumEmphasis,
      ),
    );
  }
}
