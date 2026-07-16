import 'dart:ui' show PointerDeviceKind, SemanticsAction, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
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

    // The code icon lives in the same pill as the Code label.
    final codePill = find.ancestor(
      of: find.text(messages.journalLinkedEntriesActivityFilterCode),
      matching: find.byType(Row),
    );
    expect(
      find.descendant(of: codePill.first, matching: find.byIcon(Icons.code)),
      findsOneWidget,
    );
    final codeVisual = find.byKey(
      const ValueKey('linked-entries-activity-code-visual'),
    );
    final codeBorder = const Color(0xFF34C759).withValues(alpha: 0.7);
    expect(tester.widget<DsPill>(codeVisual).borderColor, codeBorder);
    expect(
      (_pillDecoration(tester, codeVisual).border! as Border).top.color,
      codeBorder,
    );
  });

  testWidgets('filter-modal trigger matches activity and task-header height', (
    tester,
  ) async {
    await pumpBar(tester);

    final messages = await AppLocalizations.delegate.load(
      const Locale('en'),
    );

    expect(
      find.text(messages.journalLinkedEntriesSortNewestFirst),
      findsOneWidget,
    );

    final timerChip = find.byKey(
      const ValueKey('linked-entries-activity-timer-visual'),
    );
    final sortChip = find.byKey(
      const ValueKey('linked-entries-sort-trigger-visual'),
    );
    expect(tester.getSize(sortChip).height, tester.getSize(timerChip).height);
    expect(tester.getTopLeft(sortChip).dy, tester.getTopLeft(timerChip).dy);

    final timerTarget = find.byKey(
      const ValueKey('linked-entries-activity-timer'),
    );
    final sortTarget = find.byKey(
      const ValueKey('linked-entries-sort-trigger'),
    );
    expect(tester.getSize(timerTarget).height, DsPill.height);
    expect(tester.getSize(sortTarget).height, DsPill.height);
    expect(tester.getSize(timerChip).height, DsPill.height);
    expect(tester.getSize(sortChip).height, DsPill.height);
  });

  testWidgets('activity pills stay compact and share the first row on phone', (
    tester,
  ) async {
    await pumpBar(
      tester,
      mediaQueryData: const MediaQueryData(size: Size(402, 800)),
    );

    final timer = find.byKey(
      const ValueKey('linked-entries-activity-timer-visual'),
    );
    final audio = find.byKey(
      const ValueKey('linked-entries-activity-audio-visual'),
    );
    final images = find.byKey(
      const ValueKey('linked-entries-activity-images-visual'),
    );
    final sort = find.byKey(
      const ValueKey('linked-entries-sort-trigger-visual'),
    );

    final timerTop = tester.getTopLeft(timer).dy;
    expect(tester.getTopLeft(audio).dy, timerTop);
    expect(tester.getTopLeft(images).dy, timerTop);
    expect(tester.getTopLeft(sort).dy, timerTop);
    expect(
      tester.getTopRight(timer).dx,
      lessThan(tester.getTopLeft(audio).dx),
    );
    expect(
      tester.getTopRight(audio).dx,
      lessThan(tester.getTopLeft(images).dx),
    );
    expect(tester.getSize(timer).width, lessThan(120));
  });

  testWidgets('active pills use the task-header shell with accent outlines', (
    tester,
  ) async {
    await pumpBar(tester);

    final expectedBorders = <String, Color>{
      'timer': dsTokensLight.colors.alert.warning.defaultColor,
      'audio': const Color(0xFF9966E5).withValues(alpha: 0.7),
      'images': const Color(0xFF619EFF).withValues(alpha: 0.7),
    };
    for (final entry in expectedBorders.entries) {
      final visual = find.byKey(
        ValueKey('linked-entries-activity-${entry.key}-visual'),
      );
      expect(tester.widget<DsPill>(visual).borderColor, entry.value);
      expect(
        (_pillDecoration(tester, visual).border! as Border).top.color,
        entry.value,
      );
    }

    final visualFinder = find.byKey(
      const ValueKey('linked-entries-activity-timer-visual'),
    );
    final pill = tester.widget<DsPill>(visualFinder);
    final decoration = _pillDecoration(tester, visualFinder);

    expect(pill.variant, DsPillVariant.filled);
    expect(pill.bordered, isTrue);
    expect(pill.labelColor, dsTokensLight.colors.text.mediumEmphasis);
    expect(decoration.color, dsTokensLight.colors.surface.enabled);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.timer_outlined)).color,
      dsTokensLight.colors.alert.warning.defaultColor,
    );
  });

  testWidgets('hover stays confined to the compact shared pill', (
    tester,
  ) async {
    await pumpBar(tester);

    final visual = find.byKey(
      const ValueKey('linked-entries-activity-images-visual'),
    );
    final inkWell = find.descendant(
      of: visual,
      matching: find.byType(InkWell),
    );
    expect(inkWell, findsOneWidget);
    expect(tester.getSize(inkWell).height, DsPill.height);
    expect(tester.widget<InkWell>(inkWell).hoverColor, isNull);

    final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await pointer.addPointer();
    await pointer.moveTo(tester.getCenter(visual));
    await tester.pump();

    expect(tester.getSize(inkWell).height, DsPill.height);
    await pointer.removePointer();
  });

  testWidgets('sort trigger exposes active filters and a visible count', (
    tester,
  ) async {
    await pumpBar(tester);

    final element = tester.element(find.byType(LinkedEntriesActivityFilterBar));
    final container = ProviderScope.containerOf(element);
    container
            .read(includeHiddenControllerProvider(entryId).notifier)
            .includeHidden =
        true;
    container
            .read(showFlaggedOnlyControllerProvider(entryId).notifier)
            .showFlaggedOnly =
        true;
    await tester.pump();

    final messages = await AppLocalizations.delegate.load(const Locale('en'));
    final count = find.byKey(
      const ValueKey('linked-entries-sort-trigger-active-count'),
    );
    expect(
      find.descendant(of: count, matching: find.text('2')),
      findsOneWidget,
    );

    final semantics = tester.getSemantics(
      find.byKey(const ValueKey('linked-entries-sort-trigger')),
    );
    expect(semantics.label, contains(messages.journalLinkedEntriesShowHidden));
    expect(
      semantics.label,
      contains(messages.journalLinkedEntriesShowFlaggedOnly),
    );

    final visualFinder = find.byKey(
      const ValueKey('linked-entries-sort-trigger-visual'),
    );
    final pill = tester.widget<DsPill>(visualFinder);
    final decoration = _pillDecoration(tester, visualFinder);
    expect(pill.variant, DsPillVariant.filled);
    expect(pill.bordered, isTrue);
    expect(decoration.color, dsTokensLight.colors.surface.enabled);
    expect(
      (decoration.border! as Border).top.color,
      dsTokensLight.colors.decorative.level02,
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
    expect(
      tester
          .getSemantics(audioPill)
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isTrue,
    );
    expect(
      tester.widget<Text>(find.text(audioLabel)).style!.color,
      dsTokensLight.colors.text.mediumEmphasis,
    );

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
    final audioVisual = find.byKey(
      const ValueKey('linked-entries-activity-audio-visual'),
    );
    expect(
      (_pillDecoration(tester, audioVisual).border! as Border).top.color,
      dsTokensLight.colors.decorative.level02,
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.mic_none_outlined)).color,
      dsTokensLight.colors.text.lowEmphasis,
    );
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
      find.byKey(const ValueKey('linked-entries-sort-trigger')),
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

BoxDecoration _pillDecoration(WidgetTester tester, Finder pill) =>
    tester
            .widgetList<DecoratedBox>(
              find.descendant(of: pill, matching: find.byType(DecoratedBox)),
            )
            .first
            .decoration
        as BoxDecoration;

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
