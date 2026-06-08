import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/journal/state/linked_entries_activity_filter.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/features/journal/ui/widgets/linked_entries_activity_filter_bar.dart';
import 'package:lotti/l10n/app_localizations.dart';

import '../../../../widget_test_utils.dart';

void main() {
  const entryId = 'task-id-bar-test';

  Future<void> pumpBar(WidgetTester tester) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const LinkedEntriesActivityFilterBar(entryId: entryId),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders one pill per LinkedEntryActivityFilter value', (
    tester,
  ) async {
    await pumpBar(tester);

    final messages = await AppLocalizations.delegate.load(
      const Locale('en'),
    );

    expect(
      find.text(messages.journalLinkedEntriesActivityFilterTimer),
      findsOneWidget,
    );
    expect(
      find.text(messages.journalLinkedEntriesActivityFilterAudio),
      findsOneWidget,
    );
    expect(
      find.text(messages.journalLinkedEntriesActivityFilterImages),
      findsOneWidget,
    );
  });

  testWidgets('trailing trigger shows current sort label', (tester) async {
    await pumpBar(tester);

    final messages = await AppLocalizations.delegate.load(
      const Locale('en'),
    );

    expect(
      find.text(messages.journalLinkedEntriesSortNewestFirst),
      findsOneWidget,
    );
  });

  testWidgets('tapping a pill toggles its active kind in the controller', (
    tester,
  ) async {
    await pumpBar(tester);

    final messages = await AppLocalizations.delegate.load(
      const Locale('en'),
    );

    // Locate the ProviderScope to read state.
    final element = tester.element(find.byType(LinkedEntriesActivityFilterBar));
    final container = ProviderScope.containerOf(element);

    // The audio pill's Semantics node reflects its active state via `toggled`.
    // Find the explicit toggle Semantics (the only one with `toggled` set and
    // the audio label) wrapping the pill.
    final audioLabel = messages.journalLinkedEntriesActivityFilterAudio;
    final audioPillSemantics = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.toggled != null &&
          widget.properties.label == audioLabel,
    );
    bool? audioPillToggled() =>
        tester.widget<Semantics>(audioPillSemantics).properties.toggled;

    // Audio starts active, both in the controller and in the rendered pill.
    expect(
      container.read(
        linkedEntriesActivityFilterControllerProvider(id: entryId),
      ),
      contains(LinkedEntryActivityFilter.audio),
    );
    expect(audioPillToggled(), isTrue);

    await tester.tap(
      find.text(messages.journalLinkedEntriesActivityFilterAudio),
    );
    await tester.pumpAndSettle();

    // After the tap the controller drops audio and the pill re-renders as off.
    expect(
      container.read(
        linkedEntriesActivityFilterControllerProvider(id: entryId),
      ),
      isNot(contains(LinkedEntryActivityFilter.audio)),
    );
    expect(audioPillToggled(), isFalse);
  });

  testWidgets('tapping the sort trigger opens the filter modal', (
    tester,
  ) async {
    await pumpBar(tester);

    final messages = await AppLocalizations.delegate.load(
      const Locale('en'),
    );

    await tester.tap(
      find.text(messages.journalLinkedEntriesSortNewestFirst),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(messages.journalLinkedEntriesFilterModalTitle),
      findsOneWidget,
    );
  });
}
