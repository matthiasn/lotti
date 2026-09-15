import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_action_bar.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_shared.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:material_ui/material_ui.dart';

/// Stable keys for the linked-entries filter's Clear / Apply footer.
@visibleForTesting
abstract final class LinkedEntriesFilterModalKeys {
  static const Key clear = ValueKey('linked-entries-filter-clear');
  static const Key apply = ValueKey('linked-entries-filter-apply');
}

/// Compact single-page filter for linked-entry sort and visibility settings.
///
/// Every choice is staged in a draft and reaches the per-entry controllers
/// only through the sticky Apply footer — the same Clear / Apply bar the task
/// list filter commits with. Closing the sheet by any other route (the close
/// button, the barrier, Escape, system back) discards the draft.
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
    modalDecorator: (child) => _DraftLifetime(draft: draft, child: child),
    padding: EdgeInsets.fromLTRB(
      spacing.step5,
      spacing.step2,
      spacing.step5,
      spacing.step5,
    ),
    stickyActionBarBuilder: (modalContext) => _LinkedEntriesFilterActionBar(
      draft: draft,
      onApply: (value) => _commitDraft(
        container,
        entryId: entryId,
        value: value,
      ),
    ),
    builder: (modalContext) => _LinkedEntriesFilterModalBody(draft: draft),
  );
}

/// Writes one staged draft into the three per-entry controllers at once.
void _commitDraft(
  ProviderContainer container, {
  required String entryId,
  required _LinkedEntriesFilterDraft value,
}) {
  container.read(linkedEntriesSortControllerProvider(entryId).notifier).order =
      value.sortOrder;
  container
      .read(includeHiddenControllerProvider(entryId).notifier)
      .setIncludeHidden(value: value.includeHidden);
  container
      .read(showFlaggedOnlyControllerProvider(entryId).notifier)
      .setShowFlaggedOnly(value: value.showFlaggedOnly);
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

  /// What Clear resets to: the controllers' own initial state.
  static const defaults = _LinkedEntriesFilterDraft(
    sortOrder: LinkedEntriesSortOrder.newestFirst,
    includeHidden: false,
    showFlaggedOnly: false,
  );

  final LinkedEntriesSortOrder sortOrder;
  final bool includeHidden;
  final bool showFlaggedOnly;

  bool get isDefault =>
      sortOrder == defaults.sortOrder &&
      includeHidden == defaults.includeHidden &&
      showFlaggedOnly == defaults.showFlaggedOnly;

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

/// The sticky footer: Clear is inert while the draft already sits at the
/// defaults; Apply commits the draft and closes the sheet.
class _LinkedEntriesFilterActionBar extends StatelessWidget {
  const _LinkedEntriesFilterActionBar({
    required this.draft,
    required this.onApply,
  });

  final ValueNotifier<_LinkedEntriesFilterDraft> draft;
  final ValueChanged<_LinkedEntriesFilterDraft> onApply;

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    return ValueListenableBuilder<_LinkedEntriesFilterDraft>(
      valueListenable: draft,
      builder: (context, value, _) => DesignSystemFilterActionBar(
        clearKey: LinkedEntriesFilterModalKeys.clear,
        applyKey: LinkedEntriesFilterModalKeys.apply,
        clearLabel: messages.clearButton,
        applyLabel: messages.tasksLabelsSheetApply,
        onClearPressed: value.isDefault
            ? null
            : () => draft.value = _LinkedEntriesFilterDraft.defaults,
        onApplyPressed: () {
          onApply(value);
          Navigator.of(context).pop();
        },
      ),
    );
  }
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
          // Lets the last toggle scroll fully above the sticky footer.
          SizedBox(
            height: DesignSystemFilterActionBar.stickyClearance(context),
          ),
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
