import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/action_modal/ds_action_toggle_chip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/header/entry_toggle_chips.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/editor_state_service.dart';

import '../../../../../../helpers/fake_entry_controller.dart';
import '../../../../../../mocks/mocks.dart';
import '../../../../../../test_helper.dart';
import '../../../../../../widget_test_utils.dart';

const _entryId = 'entry-1';

JournalEntry _entry({
  bool? starred,
  bool? private,
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

/// A controller that applies the *writer* contract `EntryController` holds for
/// the flag — flagged means `EntryFlag.import`, and clearing it writes
/// `EntryFlag.none` rather than null — and pushes the result back into state.
///
/// It exists so one test can drive the whole loop the user reported: tap on,
/// tap off, then read the chip. The transition it encodes is pinned
/// independently by `entry_controller_test.dart` ("toggle flagged" and
/// "toggling a flagged entry clears it to EntryFlag.none"), so this double
/// cannot quietly drift into agreeing with a reader that is wrong.
class _FlagRoundTripController extends EntryController {
  _FlagRoundTripController(this._entity);

  JournalEntry _entity;

  @override
  Future<EntryState?> build() async {
    final value = EntryState.saved(
      entryId: id,
      entry: _entity,
      showMap: false,
      isFocused: false,
      shouldShowEditorToolBar: false,
    );
    state = AsyncData(value);
    return value;
  }

  @override
  Future<void> toggleFlagged() async {
    _entity = _entity.copyWith(
      meta: _entity.meta.copyWith(
        flag: _entity.meta.flag == EntryFlag.import
            ? EntryFlag.none
            : EntryFlag.import,
      ),
    );
    final current = state.value;
    if (current != null) {
      state = AsyncData(current.copyWith(entry: _entity));
    }
  }
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

  Future<void> pump(
    WidgetTester tester, {
    required List<Override> overrides,
    String entryId = _entryId,
  }) async {
    await tester.pumpWidget(
      RiverpodWidgetTestBench(
        overrides: overrides,
        child: EntryToggleChips(entryId: entryId),
      ),
    );
    await tester.pump();
  }

  Future<void> pumpEntry(WidgetTester tester, JournalEntity entry) =>
      pump(tester, overrides: [createEntryControllerOverride(entry)]);

  AppLocalizations messagesOf(WidgetTester tester) =>
      tester.element(find.byType(EntryToggleChips)).messages;

  DsActionToggleChip chip(WidgetTester tester, String label) {
    return tester.widget<DsActionToggleChip>(
      find.ancestor(
        of: find.text(label),
        matching: find.byType(DsActionToggleChip),
      ),
    );
  }

  DsActionToggleChip starredChip(WidgetTester tester) =>
      chip(tester, messagesOf(tester).journalToggleStarredTitle);

  DsActionToggleChip privateChip(WidgetTester tester) =>
      chip(tester, messagesOf(tester).journalTogglePrivateTitle);

  DsActionToggleChip flaggedChip(WidgetTester tester) =>
      chip(tester, messagesOf(tester).journalToggleFlaggedTitle);

  group('EntryToggleChips gating', () {
    testWidgets('renders nothing when there is no entry to describe', (
      tester,
    ) async {
      await pump(tester, overrides: const [], entryId: 'missing-entry');

      expect(find.byType(DsActionToggleChip), findsNothing);
    });

    testWidgets('offers exactly the three states the entry owns', (
      tester,
    ) async {
      await pumpEntry(tester, _entry());

      final messages = messagesOf(tester);
      expect(
        tester
            .widgetList<DsActionToggleChip>(find.byType(DsActionToggleChip))
            .map((c) => c.label),
        [
          messages.journalToggleStarredTitle,
          messages.journalTogglePrivateTitle,
          messages.journalToggleFlaggedTitle,
        ],
      );
    });
  });

  group('starred chip', () {
    testWidgets('an unset star reads as off, with the outlined glyph', (
      tester,
    ) async {
      await pumpEntry(tester, _entry());

      expect(starredChip(tester).selected, isFalse);
      expect(find.byIcon(LottiIcons.star), findsOneWidget);
      expect(find.byIcon(LottiIconsFilled.star), findsNothing);
    });

    testWidgets('an explicit false reads as off', (tester) async {
      await pumpEntry(tester, _entry(starred: false));

      expect(starredChip(tester).selected, isFalse);
    });

    testWidgets('a starred entry lights the chip and fills the glyph', (
      tester,
    ) async {
      await pumpEntry(tester, _entry(starred: true));

      expect(starredChip(tester).selected, isTrue);
      expect(find.byIcon(LottiIconsFilled.star), findsOneWidget);
      expect(find.byIcon(LottiIcons.star), findsNothing);
    });

    testWidgets('the star does not leak into the other two chips', (
      tester,
    ) async {
      await pumpEntry(tester, _entry(starred: true));

      expect(privateChip(tester).selected, isFalse);
      expect(flaggedChip(tester).selected, isFalse);
    });
  });

  group('private chip', () {
    testWidgets('an unset private bit reads as off, padlock open', (
      tester,
    ) async {
      await pumpEntry(tester, _entry());

      expect(privateChip(tester).selected, isFalse);
      expect(find.byIcon(LottiIcons.unlocked), findsOneWidget);
      expect(find.byIcon(LottiIcons.lock), findsNothing);
    });

    testWidgets('an explicit false reads as off', (tester) async {
      await pumpEntry(tester, _entry(private: false));

      expect(privateChip(tester).selected, isFalse);
    });

    testWidgets('a private entry lights the chip and closes the padlock', (
      tester,
    ) async {
      await pumpEntry(tester, _entry(private: true));

      expect(privateChip(tester).selected, isTrue);
      expect(find.byIcon(LottiIcons.lock), findsOneWidget);
      expect(find.byIcon(LottiIcons.unlocked), findsNothing);
    });

    testWidgets('the private bit does not leak into the other two chips', (
      tester,
    ) async {
      await pumpEntry(tester, _entry(private: true));

      expect(starredChip(tester).selected, isFalse);
      expect(flaggedChip(tester).selected, isFalse);
    });
  });

  group('flagged chip', () {
    testWidgets('a never-flagged entry reads as off, with the outlined flag', (
      tester,
    ) async {
      await pumpEntry(tester, _entry());

      expect(flaggedChip(tester).selected, isFalse);
      expect(find.byIcon(LottiIcons.flag), findsOneWidget);
      expect(find.byIcon(LottiIconsFilled.flag), findsNothing);
    });

    testWidgets('EntryFlag.import lights the chip and fills the glyph', (
      tester,
    ) async {
      await pumpEntry(tester, _entry(flag: EntryFlag.import));

      expect(flaggedChip(tester).selected, isTrue);
      expect(find.byIcon(LottiIconsFilled.flag), findsOneWidget);
      expect(find.byIcon(LottiIcons.flag), findsNothing);
    });

    // The regression. `toggleFlagged` clears the flag by writing
    // `EntryFlag.none`, never null, so a chip that tested `flag != null`
    // stayed lit for the rest of the entry's life once flagged even once.
    testWidgets('EntryFlag.none reads as off — the flag was cleared, not '
        'merely never set', (tester) async {
      await pumpEntry(tester, _entry(flag: EntryFlag.none));

      expect(flaggedChip(tester).selected, isFalse);
      expect(find.byIcon(LottiIcons.flag), findsOneWidget);
      expect(find.byIcon(LottiIconsFilled.flag), findsNothing);
    });

    // The chip sets and clears exactly one flag value, and every other reader
    // of `meta.flag` in the app — the header glyph, both list cards, the
    // linked-entries filter — treats `import` as the flagged state. A
    // different member is some other feature's business, not this chip's.
    testWidgets('EntryFlag.followUpNeeded reads as off', (tester) async {
      await pumpEntry(tester, _entry(flag: EntryFlag.followUpNeeded));

      expect(flaggedChip(tester).selected, isFalse);
    });

    testWidgets('the flag does not leak into the other two chips', (
      tester,
    ) async {
      await pumpEntry(tester, _entry(flag: EntryFlag.import));

      expect(starredChip(tester).selected, isFalse);
      expect(privateChip(tester).selected, isFalse);
    });

    testWidgets('goes dark again when the flag is toggled back off', (
      tester,
    ) async {
      final entry = _entry();
      await pump(
        tester,
        overrides: [
          entryControllerProvider(_entryId).overrideWith(
            () => _FlagRoundTripController(entry),
          ),
        ],
      );

      final label = messagesOf(tester).journalToggleFlaggedTitle;
      expect(flaggedChip(tester).selected, isFalse);

      await tester.tap(find.text(label));
      await tester.pump();
      expect(flaggedChip(tester).selected, isTrue);

      await tester.tap(find.text(label));
      await tester.pump();
      expect(
        flaggedChip(tester).selected,
        isFalse,
        reason:
            'clearing the flag writes EntryFlag.none, which must read as '
            'unflagged',
      );
      expect(find.byIcon(LottiIcons.flag), findsOneWidget);
    });
  });

  group('write-through', () {
    testWidgets('each chip calls its own toggle', (tester) async {
      final (override, tracker) = createEntryControllerOverrideWithTracker(
        _entry(),
      );
      await pump(tester, overrides: [override]);

      final messages = messagesOf(tester);
      await tester.tap(find.text(messages.journalToggleStarredTitle));
      await tester.pump();
      expect(tracker.toggleStarredCalls, [_entryId]);
      expect(tracker.togglePrivateCalls, isEmpty);
      expect(tracker.toggleFlaggedCalls, isEmpty);

      await tester.tap(find.text(messages.journalTogglePrivateTitle));
      await tester.pump();
      expect(tracker.togglePrivateCalls, [_entryId]);
      expect(tracker.toggleFlaggedCalls, isEmpty);

      await tester.tap(find.text(messages.journalToggleFlaggedTitle));
      await tester.pump();
      expect(tracker.toggleFlaggedCalls, [_entryId]);
    });

    testWidgets('three settings cost one visit — the chips do not dismiss '
        'the sheet', (tester) async {
      final (override, tracker) = createEntryControllerOverrideWithTracker(
        _entry(),
      );
      await pump(tester, overrides: [override]);

      final messages = messagesOf(tester);
      for (final label in [
        messages.journalToggleStarredTitle,
        messages.journalTogglePrivateTitle,
        messages.journalToggleFlaggedTitle,
      ]) {
        await tester.tap(find.text(label));
        await tester.pump();
      }

      expect(tracker.toggleStarredCalls, isNotEmpty);
      expect(tracker.togglePrivateCalls, isNotEmpty);
      expect(tracker.toggleFlaggedCalls, isNotEmpty);
      expect(find.byType(DsActionToggleChip), findsNWidgets(3));
    });
  });
}
