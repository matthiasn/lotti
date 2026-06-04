import 'package:flutter/material.dart';
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
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showLinkedEntriesFilterModal(
                context: context,
                entryId: entryId,
              ),
              child: const Text('open'),
            ),
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
  });

  testWidgets('tapping "Oldest first" updates the sort controller', (
    tester,
  ) async {
    final (_, container, messages) = await pumpAndOpenModal(tester);

    expect(
      container.read(linkedEntriesSortControllerProvider(id: entryId)),
      LinkedEntriesSortOrder.newestFirst,
    );

    await tester.tap(
      find.text(messages.journalLinkedEntriesSortOldestFirst),
    );
    await tester.pumpAndSettle();

    expect(
      container.read(linkedEntriesSortControllerProvider(id: entryId)),
      LinkedEntriesSortOrder.oldestFirst,
    );
  });

  testWidgets('tapping the show-hidden row flips the include-hidden state', (
    tester,
  ) async {
    final (_, container, messages) = await pumpAndOpenModal(tester);

    expect(
      container.read(includeHiddenControllerProvider(id: entryId)),
      isFalse,
    );

    await tester.tap(find.text(messages.journalLinkedEntriesShowHidden));
    await tester.pumpAndSettle();

    expect(
      container.read(includeHiddenControllerProvider(id: entryId)),
      isTrue,
    );
  });

  testWidgets(
    'tapping the flagged-only row flips the show-flagged-only state',
    (tester) async {
      final (_, container, messages) = await pumpAndOpenModal(tester);

      expect(
        container.read(showFlaggedOnlyControllerProvider(id: entryId)),
        isFalse,
      );

      await tester.tap(
        find.text(messages.journalLinkedEntriesShowFlaggedOnly),
      );
      await tester.pumpAndSettle();

      expect(
        container.read(showFlaggedOnlyControllerProvider(id: entryId)),
        isTrue,
      );

      // Toggling again restores the default.
      await tester.tap(
        find.text(messages.journalLinkedEntriesShowFlaggedOnly),
      );
      await tester.pumpAndSettle();

      expect(
        container.read(showFlaggedOnlyControllerProvider(id: entryId)),
        isFalse,
      );
    },
  );
}
