import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/features/journal/ui/widgets/linked_entries_filter_modal.dart';
import 'package:lotti/l10n/app_localizations.dart';

import '../../../../widget_test_utils.dart';

void main() {
  const entryId = 'task-id-modal-test';

  Future<(WidgetTester, ProviderContainer, AppLocalizations)> pumpAndOpenModal(
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        Builder(
          builder: (context) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Consumer(
                builder: (context, ref, _) {
                  ref
                    ..watch(linkedEntriesSortControllerProvider(entryId))
                    ..watch(includeHiddenControllerProvider(entryId))
                    ..watch(showFlaggedOnlyControllerProvider(entryId));
                  return const SizedBox.shrink();
                },
              ),
              ElevatedButton(
                onPressed: () => showLinkedEntriesFilterModal(
                  context: context,
                  entryId: entryId,
                ),
                child: const Text('open'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final element = tester.element(find.byType(ElevatedButton));
    final container = ProviderScope.containerOf(element);
    final messages = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    return (tester, container, messages);
  }

  testWidgets('renders sort pills and the toggle switches', (tester) async {
    final (_, _, messages) = await pumpAndOpenModal(tester);

    expect(
      find.text(messages.journalLinkedEntriesFilterModalTitle),
      findsOneWidget,
    );
    expect(find.text(messages.journalLinkedEntriesSortLabel), findsOneWidget);
    expect(
      find.text(messages.journalLinkedEntriesSortNewestFirst),
      findsOneWidget,
    );
    expect(
      find.text(messages.journalLinkedEntriesSortOldestFirst),
      findsOneWidget,
    );
    expect(find.text(messages.journalLinkedEntriesShowHidden), findsOneWidget);
    expect(
      find.text(messages.journalLinkedEntriesShowFlaggedOnly),
      findsOneWidget,
    );
    final dismissButton = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.check_rounded),
        matching: find.byType(IconButton),
      ),
    );
    expect(dismissButton.tooltip, messages.doneButton);
  });

  testWidgets('stages all choices until Done commits them together', (
    tester,
  ) async {
    final (_, container, messages) = await pumpAndOpenModal(tester);

    expect(
      container.read(linkedEntriesSortControllerProvider(entryId)),
      LinkedEntriesSortOrder.newestFirst,
    );

    await tester.tap(
      find.text(messages.journalLinkedEntriesSortOldestFirst),
    );
    await tester.tap(find.text(messages.journalLinkedEntriesShowHidden));
    await tester.tap(
      find.text(messages.journalLinkedEntriesShowFlaggedOnly),
    );
    await tester.pumpAndSettle();

    // The modal reflects the draft, while the live list remains unchanged.
    expect(
      tester
          .getSemantics(
            find.byKey(
              const ValueKey('linked-entries-sort-oldestFirst'),
            ),
          )
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
    expect(
      tester
          .getSemantics(
            find.bySemanticsLabel(messages.journalLinkedEntriesShowHidden),
          )
          .flagsCollection
          .isToggled,
      Tristate.isTrue,
    );
    expect(
      container.read(linkedEntriesSortControllerProvider(entryId)),
      LinkedEntriesSortOrder.newestFirst,
    );
    expect(
      container.read(includeHiddenControllerProvider(entryId)),
      isFalse,
    );
    expect(
      container.read(showFlaggedOnlyControllerProvider(entryId)),
      isFalse,
    );

    await tester.tap(find.byTooltip(messages.doneButton));
    await tester.pumpAndSettle();

    expect(
      find.text(messages.journalLinkedEntriesFilterModalTitle),
      findsNothing,
    );
    expect(
      container.read(linkedEntriesSortControllerProvider(entryId)),
      LinkedEntriesSortOrder.oldestFirst,
    );
    expect(container.read(includeHiddenControllerProvider(entryId)), isTrue);
    expect(
      container.read(showFlaggedOnlyControllerProvider(entryId)),
      isTrue,
    );
  });

  testWidgets('toggling a draft choice twice restores its initial state', (
    tester,
  ) async {
    final (_, container, messages) = await pumpAndOpenModal(tester);

    final flaggedLabel = messages.journalLinkedEntriesShowFlaggedOnly;
    await tester.tap(find.text(flaggedLabel));
    await tester.pump();
    await tester.tap(find.text(flaggedLabel));
    await tester.pumpAndSettle();

    expect(
      tester
          .getSemantics(find.bySemanticsLabel(flaggedLabel))
          .flagsCollection
          .isToggled,
      Tristate.isFalse,
    );
    expect(
      container.read(showFlaggedOnlyControllerProvider(entryId)),
      isFalse,
    );
  });

  testWidgets('barrier dismissal discards the staged draft', (tester) async {
    final (_, container, messages) = await pumpAndOpenModal(tester);

    await tester.tap(
      find.text(messages.journalLinkedEntriesSortOldestFirst),
    );
    await tester.tap(find.text(messages.journalLinkedEntriesShowHidden));
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(
      find.text(messages.journalLinkedEntriesFilterModalTitle),
      findsNothing,
    );
    expect(
      container.read(linkedEntriesSortControllerProvider(entryId)),
      LinkedEntriesSortOrder.newestFirst,
    );
    expect(container.read(includeHiddenControllerProvider(entryId)), isFalse);
  });

  for (final navigation in ['Escape', 'system back']) {
    testWidgets('$navigation closes the modal and discards its draft', (
      tester,
    ) async {
      final (_, container, messages) = await pumpAndOpenModal(tester);

      await tester.tap(
        find.text(messages.journalLinkedEntriesSortOldestFirst),
      );
      await tester.tap(find.text(messages.journalLinkedEntriesShowHidden));
      await tester.pump();

      if (navigation == 'Escape') {
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      } else {
        await tester.binding.handlePopRoute();
      }
      await tester.pumpAndSettle();

      expect(
        find.text(messages.journalLinkedEntriesFilterModalTitle),
        findsNothing,
      );
      expect(
        container.read(linkedEntriesSortControllerProvider(entryId)),
        LinkedEntriesSortOrder.newestFirst,
      );
      expect(
        container.read(includeHiddenControllerProvider(entryId)),
        isFalse,
      );
    });
  }
}
