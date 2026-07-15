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
}) async {
  final container = ProviderScope.containerOf(context);
  final draft = ValueNotifier(
    _LinkedEntriesFilterDraft(
      sortOrder: container.read(linkedEntriesSortControllerProvider(entryId)),
      includeHidden: container.read(includeHiddenControllerProvider(entryId)),
      showFlaggedOnly: container.read(
        showFlaggedOnlyControllerProvider(entryId),
      ),
    ),
  );
  final spacing = context.designTokens.spacing;
  await ModalUtils.showSinglePageModal<void>(
    context: context,
    title: context.messages.journalLinkedEntriesFilterModalTitle,
    closeButtonIcon: Icons.check_rounded,
    closeButtonTooltip: context.messages.doneButton,
    onClosePressed: () {
      final value = draft.value;
      container
              .read(linkedEntriesSortControllerProvider(entryId).notifier)
              .order =
          value.sortOrder;
      container
              .read(includeHiddenControllerProvider(entryId).notifier)
              .includeHidden =
          value.includeHidden;
      container
              .read(showFlaggedOnlyControllerProvider(entryId).notifier)
              .showFlaggedOnly =
          value.showFlaggedOnly;
    },
    modalDecorator: (child) => _DraftLifetime(draft: draft, child: child),
    padding: EdgeInsets.fromLTRB(
      spacing.step5,
      spacing.step2,
      spacing.step5,
      spacing.step6,
    ),
    builder: (modalContext) => _LinkedEntriesFilterModalBody(draft: draft),
  );
}

class _DraftLifetime extends StatefulWidget {
  const _DraftLifetime({required this.draft, required this.child});

  final ValueNotifier<_LinkedEntriesFilterDraft> draft;
  final Widget child;

  @override
  State<_DraftLifetime> createState() => _DraftLifetimeState();
}

class _DraftLifetimeState extends State<_DraftLifetime> {
  @override
  void dispose() {
    widget.draft.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

@immutable
class _LinkedEntriesFilterDraft {
  const _LinkedEntriesFilterDraft({
    required this.sortOrder,
    required this.includeHidden,
    required this.showFlaggedOnly,
  });

  final LinkedEntriesSortOrder sortOrder;
  final bool includeHidden;
  final bool showFlaggedOnly;

  _LinkedEntriesFilterDraft copyWith({
    LinkedEntriesSortOrder? sortOrder,
    bool? includeHidden,
    bool? showFlaggedOnly,
  }) => _LinkedEntriesFilterDraft(
    sortOrder: sortOrder ?? this.sortOrder,
    includeHidden: includeHidden ?? this.includeHidden,
    showFlaggedOnly: showFlaggedOnly ?? this.showFlaggedOnly,
  );
}

class _LinkedEntriesFilterModalBody extends StatelessWidget {
  const _LinkedEntriesFilterModalBody({required this.draft});

  final ValueNotifier<_LinkedEntriesFilterDraft> draft;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final spacing = tokens.spacing;

    String sortLabel(LinkedEntriesSortOrder option) => switch (option) {
      LinkedEntriesSortOrder.newestFirst =>
        messages.journalLinkedEntriesSortNewestFirst,
      LinkedEntriesSortOrder.oldestFirst =>
        messages.journalLinkedEntriesSortOldestFirst,
    };

    return ValueListenableBuilder<_LinkedEntriesFilterDraft>(
      valueListenable: draft,
      builder: (context, value, _) => Column(
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
                  selected: value.sortOrder == option,
                  role: DesignSystemFilterChoiceRole.singleSelect,
                  onTap: () => draft.value = draft.value.copyWith(
                    sortOrder: option,
                  ),
                ),
            ],
          ),
          SizedBox(height: spacing.step6),
          _SectionLabel(text: messages.journalFilterShowTitle),
          SizedBox(height: spacing.step4),
          DesignSystemFilterToggleRow(
            label: messages.journalLinkedEntriesShowHidden,
            value: value.includeHidden,
            onChanged: (next) => draft.value = draft.value.copyWith(
              includeHidden: next,
            ),
          ),
          SizedBox(height: spacing.step1),
          DesignSystemFilterToggleRow(
            label: messages.journalLinkedEntriesShowFlaggedOnly,
            value: value.showFlaggedOnly,
            onChanged: (next) => draft.value = draft.value.copyWith(
              showFlaggedOnly: next,
            ),
          ),
          SizedBox(height: spacing.step4),
        ],
      ),
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
