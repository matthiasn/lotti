import 'dart:ui' show SemanticsAction;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/ai_response_type.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/chips/design_system_chip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/linked_entries_activity_filter.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/features/journal/ui/widgets/linked_entries_activity_filter_bar.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../test_utils/screenshot_harness.dart' show loadAppFonts;
import '../../../../widget_test_utils.dart';

void main() {
  // Phone-width geometry must use the shipped fonts in standalone and bundled
  // runs; the default test font gives the labels different widths.
  setUpAll(loadAppFonts);
  const entryId = 'task-id-bar-test';

  Future<void> pumpBar(
    WidgetTester tester, {
    List<Override> overrides = const [],
    MediaQueryData? mediaQueryData,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const LinkedEntriesActivityFilterBar(entryId: entryId),
        overrides: overrides,
        mediaQueryData: mediaQueryData,
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

    final codeChip = tester.widget<DesignSystemChip>(
      find.widgetWithText(
        DesignSystemChip,
        messages.journalLinkedEntriesActivityFilterCode,
      ),
    );
    expect(codeChip.leadingIcon, LottiIcons.code);
    expect(codeChip.selected, isTrue);
  });

  Finder kindChip(String label) => find.widgetWithText(DesignSystemChip, label);
  final sortChip = find.byKey(const ValueKey('linked-entries-sort-trigger'));

  testWidgets('the sort trigger is the same chip as the kinds beside it', (
    tester,
  ) async {
    await pumpBar(tester);
    final messages = await AppLocalizations.delegate.load(const Locale('en'));

    expect(
      find.descendant(
        of: sortChip,
        matching: find.text(messages.journalLinkedEntriesSortNewestFirst),
      ),
      findsOneWidget,
    );
    final timer = kindChip(messages.journalLinkedEntriesActivityFilterTimer);
    expect(tester.getSize(sortChip).height, tester.getSize(timer).height);
    expect(tester.getTopLeft(sortChip).dy, tester.getTopLeft(timer).dy);
    expect(
      tester.widget<DesignSystemChip>(sortChip).size,
      tester.widget<DesignSystemChip>(timer).size,
    );
  });

  testWidgets('kind chips and the sort trigger share the first row on phone', (
    tester,
  ) async {
    await pumpBar(
      tester,
      mediaQueryData: const MediaQueryData(size: Size(402, 800)),
    );
    final messages = await AppLocalizations.delegate.load(const Locale('en'));

    final timer = kindChip(messages.journalLinkedEntriesActivityFilterTimer);
    final audio = kindChip(messages.journalLinkedEntriesActivityFilterAudio);
    final images = kindChip(messages.journalLinkedEntriesActivityFilterImages);

    final timerTop = tester.getTopLeft(timer).dy;
    expect(tester.getTopLeft(audio).dy, timerTop);
    expect(tester.getTopLeft(images).dy, timerTop);
    expect(tester.getTopLeft(sortChip).dy, timerTop);
    expect(
      tester.getTopRight(timer).dx,
      lessThan(tester.getTopLeft(audio).dx),
    );
    expect(
      tester.getTopRight(audio).dx,
      lessThan(tester.getTopLeft(images).dx),
    );
    expect(
      tester.getTopRight(images).dx,
      lessThan(tester.getTopLeft(sortChip).dx),
    );
  });

  testWidgets('a kind carries no hue of its own: every chip is the neutral '
      'filter chip, on by default', (tester) async {
    await pumpBar(
      tester,
      overrides: [
        resolvedOutgoingLinkedEntriesProvider(entryId).overrideWith(
          (_) => [_codingPrompt()],
        ),
      ],
    );
    final messages = await AppLocalizations.delegate.load(const Locale('en'));

    final icons = <String, IconData>{
      messages.journalLinkedEntriesActivityFilterTimer: LottiIcons.timer,
      messages.journalLinkedEntriesActivityFilterAudio: LottiIcons.mic,
      messages.journalLinkedEntriesActivityFilterImages: LottiIcons.image,
      messages.journalLinkedEntriesActivityFilterCode: LottiIcons.code,
    };
    final glyphColors = <Color?>{};
    for (final entry in icons.entries) {
      final chip = tester.widget<DesignSystemChip>(kindChip(entry.key));
      expect(chip.leadingIcon, entry.value);
      expect(chip.selected, isTrue);
      // Neutral selection, never the accent or a per-kind colour.
      expect(chip.quietSelection, isTrue);
      expect(chip.outlined, isTrue);
      glyphColors.add(
        tester
            .widget<Icon>(
              find.descendant(
                of: kindChip(entry.key),
                matching: find.byIcon(entry.value),
              ),
            )
            .color,
      );
    }
    expect(glyphColors, hasLength(1));
  });

  testWidgets('sort trigger exposes active filters and a visible count', (
    tester,
  ) async {
    await pumpBar(tester);

    final element = tester.element(find.byType(LinkedEntriesActivityFilterBar));
    final container = ProviderScope.containerOf(element);
    container
        .read(includeHiddenControllerProvider(entryId).notifier)
        .setIncludeHidden(value: true);
    container
        .read(showFlaggedOnlyControllerProvider(entryId).notifier)
        .setShowFlaggedOnly(value: true);
    await tester.pump();

    final messages = await AppLocalizations.delegate.load(const Locale('en'));
    final count = find.byKey(
      const ValueKey('linked-entries-sort-trigger-active-count'),
    );
    expect(
      find.descendant(of: count, matching: find.text('2')),
      findsOneWidget,
    );

    final semanticsLabel = tester
        .widget<DesignSystemChip>(sortChip)
        .semanticsLabel;
    expect(semanticsLabel, contains(messages.journalLinkedEntriesShowHidden));
    expect(
      semanticsLabel,
      contains(messages.journalLinkedEntriesShowFlaggedOnly),
    );
    expect(find.bySemanticsLabel(semanticsLabel!), findsOneWidget);

    // It opens a sheet and is never itself "on".
    final chip = tester.widget<DesignSystemChip>(sortChip);
    expect(chip.outlined, isTrue);
    expect(chip.selected, isFalse);
  });

  testWidgets('sort trigger names the current sort order', (tester) async {
    await pumpBar(tester);
    final messages = await AppLocalizations.delegate.load(const Locale('en'));
    expect(
      tester.widget<DesignSystemChip>(sortChip).label,
      messages.journalLinkedEntriesSortNewestFirst,
    );

    ProviderScope.containerOf(
          tester.element(find.byType(LinkedEntriesActivityFilterBar)),
        ).read(linkedEntriesSortControllerProvider(entryId).notifier).order =
        LinkedEntriesSortOrder.oldestFirst;
    await tester.pump();

    final chip = tester.widget<DesignSystemChip>(sortChip);
    expect(chip.label, messages.journalLinkedEntriesSortOldestFirst);
    expect(
      chip.semanticsLabel,
      contains(messages.journalLinkedEntriesSortOldestFirst),
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

    final audioLabel = messages.journalLinkedEntriesActivityFilterAudio;
    bool audioSelected() =>
        tester.widget<DesignSystemChip>(kindChip(audioLabel)).selected;

    // Audio starts active, both in the controller and in the rendered chip.
    expect(
      container.read(
        linkedEntriesActivityFilterControllerProvider(entryId),
      ),
      contains(LinkedEntryActivityFilter.audio),
    );
    expect(audioSelected(), isTrue);

    await tester.tap(find.text(audioLabel));
    await tester.pumpAndSettle();

    // After the tap the controller drops audio and the chip re-renders off.
    expect(
      container.read(
        linkedEntriesActivityFilterControllerProvider(entryId),
      ),
      isNot(contains(LinkedEntryActivityFilter.audio)),
    );
    expect(audioSelected(), isFalse);
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

  testWidgets('sort trigger semantics action opens the filter modal', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpBar(tester);
    final messages = await AppLocalizations.delegate.load(const Locale('en'));
    final node = tester.getSemantics(
      find.bySemanticsLabel(
        tester.widget<DesignSystemChip>(sortChip).semanticsLabel!,
      ),
    );

    // ignore: deprecated_member_use
    tester.binding.pipelineOwner.semanticsOwner!.performAction(
      node.id,
      SemanticsAction.tap,
    );
    await tester.pumpAndSettle();

    expect(
      find.text(messages.journalLinkedEntriesFilterModalTitle),
      findsOneWidget,
    );
    handle.dispose();
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
