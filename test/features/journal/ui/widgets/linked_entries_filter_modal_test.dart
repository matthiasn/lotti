import 'dart:ui' show Tristate;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_action_bar.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_shared.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/features/journal/ui/widgets/linked_entries_filter_modal.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../test_utils/material_ui_finders.dart';
import '../../../../widget_test_utils.dart';

const _entryId = 'task-id-modal-test';

/// The committed filter as the three per-entry controllers hold it.
typedef _CommittedFilter = ({
  LinkedEntriesSortOrder sortOrder,
  bool includeHidden,
  bool showFlaggedOnly,
});

const _CommittedFilter _defaultFilter = (
  sortOrder: LinkedEntriesSortOrder.newestFirst,
  includeHidden: false,
  showFlaggedOnly: false,
);

/// One opened modal: the page's container, the English catalog and the
/// finders every scenario reaches for.
class _OpenedModal {
  const _OpenedModal(this.tester, this.container, this.messages);

  final WidgetTester tester;
  final ProviderContainer container;
  final AppLocalizations messages;

  _CommittedFilter get committed => (
    sortOrder: container.read(linkedEntriesSortControllerProvider(_entryId)),
    includeHidden: container.read(includeHiddenControllerProvider(_entryId)),
    showFlaggedOnly: container.read(
      showFlaggedOnlyControllerProvider(_entryId),
    ),
  );

  Finder get title => find.text(messages.journalLinkedEntriesFilterModalTitle);
  Finder get oldestFirstPill =>
      find.text(messages.journalLinkedEntriesSortOldestFirst);
  Finder get showHiddenToggle =>
      find.text(messages.journalLinkedEntriesShowHidden);
  Finder get showFlaggedOnlyToggle =>
      find.text(messages.journalLinkedEntriesShowFlaggedOnly);
  Finder get apply => find.byKey(LinkedEntriesFilterModalKeys.apply);
  Finder get clear => find.byKey(LinkedEntriesFilterModalKeys.clear);
  Finder get closeButton => findMaterialTooltip(
    const DefaultMaterialLocalizations().closeButtonTooltip,
  );

  bool get clearIsEnabled =>
      tester.widget<DesignSystemButton>(clear).onPressed != null;

  Tristate pillSelected(LinkedEntriesSortOrder order) => tester
      .getSemantics(find.byKey(ValueKey('linked-entries-sort-${order.name}')))
      .flagsCollection
      .isSelected;

  Tristate toggled(String label) => tester
      .getSemantics(find.bySemanticsLabel(label))
      .flagsCollection
      .isToggled;

  /// Stages "oldest first" and "show hidden" without committing them.
  Future<void> stageOldestFirstAndHidden() async {
    await tester.tap(oldestFirstPill);
    await tester.tap(showHiddenToggle);
    await tester.pumpAndSettle();
  }

  Future<void> reopen() async {
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }
}

/// Pumps a host that keeps the three per-entry controllers alive, lets
/// [seed] preset them, then opens the filter modal from a button.
Future<_OpenedModal> _pumpAndOpenModal(
  WidgetTester tester, {
  void Function(ProviderContainer container)? seed,
  MediaQueryData? mediaQueryData,
}) async {
  await tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      Builder(
        builder: (context) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Consumer(
              builder: (context, ref, _) {
                ref
                  ..watch(linkedEntriesSortControllerProvider(_entryId))
                  ..watch(includeHiddenControllerProvider(_entryId))
                  ..watch(showFlaggedOnlyControllerProvider(_entryId));
                return const SizedBox.shrink();
              },
            ),
            ElevatedButton(
              onPressed: () => showLinkedEntriesFilterModal(
                context: context,
                entryId: _entryId,
              ),
              child: const Text('open'),
            ),
          ],
        ),
      ),
      mediaQueryData: mediaQueryData,
    ),
  );
  await tester.pumpAndSettle();

  final element = tester.element(find.byType(ElevatedButton));
  final container = ProviderScope.containerOf(element);
  seed?.call(container);
  await tester.pump();
  final messages = await AppLocalizations.delegate.load(const Locale('en'));

  final modal = _OpenedModal(tester, container, messages);
  await modal.reopen();
  return modal;
}

void _seedNonDefault(ProviderContainer container) {
  container.read(linkedEntriesSortControllerProvider(_entryId).notifier).order =
      LinkedEntriesSortOrder.oldestFirst;
  container
      .read(showFlaggedOnlyControllerProvider(_entryId).notifier)
      .setShowFlaggedOnly(value: true);
}

void main() {
  group('layout', () {
    testWidgets('renders the sort pills, the toggles and the footer', (
      tester,
    ) async {
      final modal = await _pumpAndOpenModal(tester);
      final messages = modal.messages;

      expect(modal.title, findsOneWidget);
      expect(find.text(messages.journalLinkedEntriesSortLabel), findsOneWidget);
      expect(
        find.text(messages.journalLinkedEntriesSortNewestFirst),
        findsOneWidget,
      );
      expect(modal.oldestFirstPill, findsOneWidget);
      expect(modal.showHiddenToggle, findsOneWidget);
      expect(modal.showFlaggedOnlyToggle, findsOneWidget);
      expect(find.text(messages.clearButton), findsOneWidget);
      expect(find.text(messages.tasksLabelsSheetApply), findsOneWidget);
    });

    testWidgets('the top bar closes with a plain X, not a checkmark', (
      tester,
    ) async {
      final modal = await _pumpAndOpenModal(tester);

      expect(modal.closeButton, findsOneWidget);
      expect(
        find.descendant(
          of: modal.closeButton,
          matching: find.byIcon(LottiIcons.close),
        ),
        findsOneWidget,
      );
      // The only confirm glyph on the sheet belongs to Apply.
      expect(find.byIcon(LottiIcons.confirm), findsOneWidget);
      expect(
        find.descendant(
          of: modal.apply,
          matching: find.byIcon(LottiIcons.confirm),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the last toggle clears the sticky footer on a phone', (
      tester,
    ) async {
      final modal = await _pumpAndOpenModal(
        tester,
        mediaQueryData: phoneMediaQueryData,
      );

      final lastRow = find.ancestor(
        of: modal.showFlaggedOnlyToggle,
        matching: find.byType(DesignSystemFilterToggleRow),
      );
      final footer = find.byType(DesignSystemFilterActionBar);
      expect(
        tester.getRect(lastRow).bottom,
        lessThanOrEqualTo(tester.getRect(footer).top),
      );
    });
  });

  group('staging', () {
    testWidgets('staged choices show on the sheet but stay out of the'
        ' controllers', (tester) async {
      final modal = await _pumpAndOpenModal(tester);

      await modal.stageOldestFirstAndHidden();
      await tester.tap(modal.showFlaggedOnlyToggle);
      await tester.pumpAndSettle();

      expect(
        modal.pillSelected(LinkedEntriesSortOrder.oldestFirst),
        Tristate.isTrue,
      );
      expect(
        modal.toggled(modal.messages.journalLinkedEntriesShowHidden),
        Tristate.isTrue,
      );
      expect(
        modal.toggled(modal.messages.journalLinkedEntriesShowFlaggedOnly),
        Tristate.isTrue,
      );
      expect(modal.committed, _defaultFilter);
    });

    testWidgets('toggling a draft choice twice restores its initial state', (
      tester,
    ) async {
      final modal = await _pumpAndOpenModal(tester);
      final flaggedLabel = modal.messages.journalLinkedEntriesShowFlaggedOnly;

      await tester.tap(modal.showFlaggedOnlyToggle);
      await tester.pump();
      await tester.tap(modal.showFlaggedOnlyToggle);
      await tester.pumpAndSettle();

      expect(modal.toggled(flaggedLabel), Tristate.isFalse);
      expect(modal.committed, _defaultFilter);
    });
  });

  group('Apply', () {
    testWidgets('commits sort, hidden and flagged together and closes', (
      tester,
    ) async {
      final modal = await _pumpAndOpenModal(tester);

      await modal.stageOldestFirstAndHidden();
      await tester.tap(modal.showFlaggedOnlyToggle);
      await tester.pump();
      await tester.tap(modal.apply);
      await tester.pumpAndSettle();

      expect(modal.title, findsNothing);
      expect(modal.committed, (
        sortOrder: LinkedEntriesSortOrder.oldestFirst,
        includeHidden: true,
        showFlaggedOnly: true,
      ));
    });

    testWidgets('reopening after Apply starts from the committed filter', (
      tester,
    ) async {
      final modal = await _pumpAndOpenModal(tester);

      await tester.tap(modal.oldestFirstPill);
      await tester.pump();
      await tester.tap(modal.apply);
      await tester.pumpAndSettle();
      await modal.reopen();

      expect(
        modal.pillSelected(LinkedEntriesSortOrder.oldestFirst),
        Tristate.isTrue,
      );
      expect(modal.clearIsEnabled, isTrue);
    });
  });

  group('Clear', () {
    testWidgets('is inert while the draft already matches the defaults', (
      tester,
    ) async {
      final modal = await _pumpAndOpenModal(tester);

      expect(modal.clearIsEnabled, isFalse);
    });

    testWidgets('becomes available as soon as a choice is staged', (
      tester,
    ) async {
      final modal = await _pumpAndOpenModal(tester);

      await tester.tap(modal.showHiddenToggle);
      await tester.pumpAndSettle();

      expect(modal.clearIsEnabled, isTrue);
    });

    testWidgets('resets a staged draft to the defaults without committing', (
      tester,
    ) async {
      final modal = await _pumpAndOpenModal(tester);
      await modal.stageOldestFirstAndHidden();

      await tester.tap(modal.clear);
      await tester.pumpAndSettle();

      expect(modal.title, findsOneWidget);
      expect(
        modal.pillSelected(LinkedEntriesSortOrder.newestFirst),
        Tristate.isTrue,
      );
      expect(
        modal.toggled(modal.messages.journalLinkedEntriesShowHidden),
        Tristate.isFalse,
      );
      expect(modal.clearIsEnabled, isFalse);
      expect(modal.committed, _defaultFilter);
    });

    testWidgets('is available when the sheet opens on a non-default filter', (
      tester,
    ) async {
      final modal = await _pumpAndOpenModal(tester, seed: _seedNonDefault);

      expect(
        modal.pillSelected(LinkedEntriesSortOrder.oldestFirst),
        Tristate.isTrue,
      );
      expect(modal.clearIsEnabled, isTrue);
    });

    testWidgets('followed by Apply restores the default filter', (
      tester,
    ) async {
      final modal = await _pumpAndOpenModal(tester, seed: _seedNonDefault);
      expect(modal.committed, isNot(_defaultFilter));

      await tester.tap(modal.clear);
      await tester.pump();
      await tester.tap(modal.apply);
      await tester.pumpAndSettle();

      expect(modal.title, findsNothing);
      expect(modal.committed, _defaultFilter);
    });
  });

  group('discarding', () {
    testWidgets('the close button drops the staged draft', (tester) async {
      final modal = await _pumpAndOpenModal(tester);
      await modal.stageOldestFirstAndHidden();

      await tester.tap(modal.closeButton);
      await tester.pumpAndSettle();

      expect(modal.title, findsNothing);
      expect(modal.committed, _defaultFilter);
    });

    testWidgets('barrier dismissal drops the staged draft', (tester) async {
      final modal = await _pumpAndOpenModal(tester);
      await modal.stageOldestFirstAndHidden();

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(modal.title, findsNothing);
      expect(modal.committed, _defaultFilter);
    });

    for (final navigation in ['Escape', 'system back']) {
      testWidgets('$navigation closes the modal and drops its draft', (
        tester,
      ) async {
        final modal = await _pumpAndOpenModal(tester);
        await modal.stageOldestFirstAndHidden();

        if (navigation == 'Escape') {
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        } else {
          await tester.binding.handlePopRoute();
        }
        await tester.pumpAndSettle();

        expect(modal.title, findsNothing);
        expect(modal.committed, _defaultFilter);
      });
    }

    testWidgets('a discarded draft is not shown again on reopen', (
      tester,
    ) async {
      final modal = await _pumpAndOpenModal(tester);
      await modal.stageOldestFirstAndHidden();

      await tester.tap(modal.closeButton);
      await tester.pumpAndSettle();
      await modal.reopen();

      expect(
        modal.pillSelected(LinkedEntriesSortOrder.newestFirst),
        Tristate.isTrue,
      );
      expect(
        modal.toggled(modal.messages.journalLinkedEntriesShowHidden),
        Tristate.isFalse,
      );
      expect(modal.clearIsEnabled, isFalse);
    });
  });
}
