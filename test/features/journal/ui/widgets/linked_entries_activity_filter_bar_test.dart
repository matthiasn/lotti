import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/journal/state/linked_entries_activity_filter.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/features/journal/ui/widgets/linked_entries_activity_filter_bar.dart';
import 'package:lotti/l10n/app_localizations.dart';

import '../../../../widget_test_utils.dart';

void main() {
  const entryId = 'task-id-bar-test';

  Future<void> pumpBar(
    WidgetTester tester, {
    List<Override> overrides = const [],
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const LinkedEntriesActivityFilterBar(entryId: entryId),
        overrides: overrides,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders standard pills and hides Code without a coding prompt', (
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
    expect(
      find.text(messages.journalLinkedEntriesActivityFilterCode),
      findsNothing,
    );
  });

  testWidgets('Code pill appears only when a coding prompt is linked', (
    tester,
  ) async {
    await pumpBar(
      tester,
      overrides: [
        resolvedOutgoingLinkedEntriesProvider(entryId).overrideWith(
          (_) => [_codingPrompt()],
        ),
      ],
    );

    final messages = await AppLocalizations.delegate.load(
      const Locale('en'),
    );

    // The code icon lives in the same pill as the Code label.
    final codePill = find.ancestor(
      of: find.text(messages.journalLinkedEntriesActivityFilterCode),
      matching: find.byType(Row),
    );
    expect(
      find.descendant(of: codePill.first, matching: find.byIcon(Icons.code)),
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

    final timerChip = find.ancestor(
      of: find.text(messages.journalLinkedEntriesActivityFilterTimer),
      matching: find.byType(AnimatedContainer),
    );
    final sortChip = find.ancestor(
      of: find.text(messages.journalLinkedEntriesSortNewestFirst),
      matching: find.byType(Ink),
    );
    expect(tester.getSize(sortChip).height, tester.getSize(timerChip).height);
    expect(tester.getTopLeft(sortChip).dy, tester.getTopLeft(timerChip).dy);
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

    final audioLabel = messages.journalLinkedEntriesActivityFilterAudio;
    final audioPill = find.bySemanticsLabel(audioLabel);
    bool audioPillSelected() =>
        tester.getSemantics(audioPill).flagsCollection.isToggled ==
        Tristate.isTrue;

    // Audio starts active, both in the controller and in the rendered pill.
    expect(
      container.read(
        linkedEntriesActivityFilterControllerProvider(entryId),
      ),
      contains(LinkedEntryActivityFilter.audio),
    );
    expect(audioPillSelected(), isTrue);

    await tester.tap(
      find.text(messages.journalLinkedEntriesActivityFilterAudio),
    );
    await tester.pumpAndSettle();

    // After the tap the controller drops audio and the pill re-renders as off.
    expect(
      container.read(
        linkedEntriesActivityFilterControllerProvider(entryId),
      ),
      isNot(contains(LinkedEntryActivityFilter.audio)),
    );
    expect(audioPillSelected(), isFalse);
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

AiResponseEntry _codingPrompt() {
  final date = DateTime(2024, 3, 15);
  return AiResponseEntry(
    meta: Metadata(
      id: 'coding-prompt',
      createdAt: date,
      updatedAt: date,
      dateFrom: date,
      dateTo: date,
    ),
    data: const AiResponseData(
      model: 'test-model',
      systemMessage: 'system',
      prompt: 'prompt',
      thoughts: '',
      response: 'response',
      type: AiResponseType.promptGeneration,
    ),
  );
}
