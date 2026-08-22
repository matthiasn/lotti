import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/action_modal/ds_action_toggle_chip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/header/entry_toggle_chips.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/editor_state_service.dart';

import '../../../../../../helpers/fake_entry_controller.dart';
import '../../../../../../mocks/mocks.dart';
import '../../../../../../test_helper.dart';
import '../../../../../../widget_test_utils.dart';

const _entryId = 'entry-1';

JournalEntry _entry({
  bool starred = false,
  bool private = false,
  EntryFlag? flag,
}) {
  final now = DateTime(2026, 8, 21);
  return JournalEntry(
    meta: Metadata(
      id: _entryId,
      createdAt: now,
      updatedAt: now,
      dateFrom: now,
      dateTo: now,
      starred: starred,
      private: private,
      flag: flag,
    ),
  );
}

DsActionToggleChip _chipWithLabel(WidgetTester tester, String label) {
  return tester.widget<DsActionToggleChip>(
    find.ancestor(
      of: find.text(label),
      matching: find.byType(DsActionToggleChip),
    ),
  );
}

void main() {
  setUpAll(() async {
    await setUpTestGetIt(
      additionalSetup: () {
        getIt.registerSingleton<EditorStateService>(MockEditorStateService());
      },
    );
  });

  tearDownAll(tearDownTestGetIt);

  group('EntryToggleChips', () {
    testWidgets("offers the entry's three states, all off", (tester) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [createEntryControllerOverride(_entry())],
          child: const EntryToggleChips(entryId: _entryId),
        ),
      );
      await tester.pump();

      expect(find.byType(DsActionToggleChip), findsNWidgets(3));
      for (final chip in tester.widgetList<DsActionToggleChip>(
        find.byType(DsActionToggleChip),
      )) {
        expect(chip.selected, isFalse, reason: chip.label);
      }
      // Off states are the outlined glyphs — an open padlock, not a closed one.
      expect(find.byIcon(LottiIcons.star), findsOneWidget);
      expect(find.byIcon(LottiIcons.unlocked), findsOneWidget);
      expect(find.byIcon(LottiIcons.flag), findsOneWidget);
    });

    testWidgets('each chip reflects its own bit of the entry', (tester) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            createEntryControllerOverride(
              _entry(starred: true, flag: EntryFlag.import),
            ),
          ],
          child: const EntryToggleChips(entryId: _entryId),
        ),
      );
      await tester.pump();

      final context = tester.element(find.byType(EntryToggleChips));
      final messages = context.messages;
      expect(
        _chipWithLabel(tester, messages.journalToggleStarredTitle).selected,
        isTrue,
      );
      expect(
        _chipWithLabel(tester, messages.journalTogglePrivateTitle).selected,
        isFalse,
      );
      expect(
        _chipWithLabel(tester, messages.journalToggleFlaggedTitle).selected,
        isTrue,
      );
      expect(find.byIcon(LottiIconsFilled.star), findsOneWidget);
      expect(find.byIcon(LottiIconsFilled.flag), findsOneWidget);
      expect(find.byIcon(LottiIcons.unlocked), findsOneWidget);
    });

    testWidgets('a private entry shows the closed padlock', (tester) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [createEntryControllerOverride(_entry(private: true))],
          child: const EntryToggleChips(entryId: _entryId),
        ),
      );
      await tester.pump();

      expect(find.byIcon(LottiIcons.lock), findsOneWidget);
      expect(find.byIcon(LottiIcons.unlocked), findsNothing);
    });

    testWidgets('each chip writes through its own toggle and leaves the '
        'sheet standing', (tester) async {
      final (override, tracker) = createEntryControllerOverrideWithTracker(
        _entry(),
      );

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [override],
          child: const EntryToggleChips(entryId: _entryId),
        ),
      );
      await tester.pump();

      final messages = tester.element(find.byType(EntryToggleChips)).messages;
      for (final label in [
        messages.journalToggleStarredTitle,
        messages.journalTogglePrivateTitle,
        messages.journalToggleFlaggedTitle,
      ]) {
        await tester.tap(find.text(label));
        await tester.pump();
      }

      expect(tracker.toggleStarredCalls, contains(_entryId));
      expect(tracker.togglePrivateCalls, contains(_entryId));
      expect(tracker.toggleFlaggedCalls, contains(_entryId));
      // Three settings, one visit: the chips do not dismiss the sheet the way
      // the three menu rows they replaced each did.
      expect(find.byType(DsActionToggleChip), findsNWidgets(3));
    });

    testWidgets('renders nothing until the entry has loaded', (tester) async {
      await tester.pumpWidget(
        const RiverpodWidgetTestBench(
          child: EntryToggleChips(entryId: 'missing-entry'),
        ),
      );
      await tester.pump();

      expect(find.byType(DsActionToggleChip), findsNothing);
    });
  });
}
