import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show AsyncData;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/entry_datetime_multipage_modal.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/dev_logger.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/fake_entry_controller.dart';
import '../../../../../mocks/mocks.dart';
import '../../../../../test_data/test_data.dart';
import '../../../../../widget_test_utils.dart';

// The id shared by testTextEntry and the modal launchers in this file.
const _testEntryId = '32ea936e-dfc6-43bd-8722-d816c35eb489';

// A minimal button widget that opens the modal on tap so tests can trigger it.
class _ModalLauncher extends StatelessWidget {
  const _ModalLauncher({required this.entryId});
  final String entryId;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        // We look up the entry via the provider; but for test simplicity we
        // use testTextEntry / testTextEntryNoGeo directly below because the
        // provider is overridden.
        EntryDateTimeMultiPageModal.show(
          context: context,
          entry: testTextEntry,
        );
      },
      child: const Text('Open'),
    );
  }
}

// A launcher that opens the modal with a custom entry.
class _ModalLauncherWithEntry extends StatelessWidget {
  const _ModalLauncherWithEntry({required this.entry});
  final JournalEntity entry;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        EntryDateTimeMultiPageModal.show(context: context, entry: entry);
      },
      child: const Text('Open'),
    );
  }
}

// A controller whose updateFromTo always throws, to exercise the Save
// handler's catch block (which logs via DevLogger and keeps the modal open).
class _ThrowingEntryController extends EntryController {
  _ThrowingEntryController(this._entity);

  final JournalEntity _entity;

  @override
  Future<EntryState?> build({required String id}) {
    final value = EntryState.saved(
      entryId: id,
      entry: _entity,
      showMap: false,
      isFocused: false,
      shouldShowEditorToolBar: false,
      formKey: GlobalKey<FormBuilderState>(),
    );
    state = AsyncData(value);
    return SynchronousFuture(value);
  }

  @override
  Future<bool> updateFromTo({
    required DateTime dateFrom,
    required DateTime dateTo,
  }) async {
    throw Exception('boom');
  }
}

// An entry whose dateTo is before dateFrom (invalid range).
final _invalidRangeEntry = JournalEntry(
  meta: Metadata(
    id: _testEntryId,
    createdAt: DateTime(2022, 7, 7, 14),
    dateFrom: DateTime(2022, 7, 7, 14),
    dateTo: DateTime(2022, 7, 7, 13), // before dateFrom → invalid
    updatedAt: DateTime(2022, 7, 7, 14),
  ),
);

/// Widens the test view so the modal renders as a centered dialog (rather than
/// a bottom sheet), keeping the sticky action bar and nav bar fully hittable.
void _useWideModalView(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(1600, 1800)
    ..devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

/// Pumps the launcher, taps 'Open', and settles the modal's entrance.
///
/// Tests pass only the parts that vary: the [override] for the entry
/// controller, an optional custom [launcher] (defaults to [_ModalLauncher]),
/// the [mediaQueryData] (set for wide-screen/dialog tests), and the [settle]
/// duration to pump after opening.
Future<void> _openModal(
  WidgetTester tester, {
  required Override override,
  Widget launcher = const _ModalLauncher(entryId: _testEntryId),
  MediaQueryData? mediaQueryData,
  Duration settle = const Duration(milliseconds: 300),
}) async {
  await tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      launcher,
      overrides: [override],
      mediaQueryData: mediaQueryData,
    ),
  );
  await tester.pump();
  await tester.tap(find.text('Open'));
  await tester.pump();
  await tester.pump(settle);
}

void main() {
  group('EntryDateTimeMultiPageModal', () {
    late MockJournalDb mockJournalDb;
    late MockEditorStateService mockEditorStateService;
    late MockPersistenceLogic mockPersistenceLogic;
    late MockUpdateNotifications mockUpdateNotifications;

    setUp(() async {
      mockJournalDb = MockJournalDb();
      mockEditorStateService = MockEditorStateService();
      mockPersistenceLogic = MockPersistenceLogic();
      mockUpdateNotifications = MockUpdateNotifications();

      when(
        () => mockUpdateNotifications.updateStream,
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => mockUpdateNotifications.localUpdateStream,
      ).thenAnswer((_) => const Stream.empty());

      when(
        () => mockJournalDb.journalEntityById(any()),
      ).thenAnswer((_) async => testTextEntry);

      when(
        () => mockEditorStateService.getUnsavedStream(any(), any()),
      ).thenAnswer((_) => const Stream.empty());

      await setUpTestGetIt(
        additionalSetup: () {
          getIt
            // The modal must resolve THIS test's stubs, not the helper's
            // stock mocks.
            ..unregister<UpdateNotifications>()
            ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
            ..unregister<JournalDb>()
            ..registerSingleton<JournalDb>(mockJournalDb)
            ..registerSingleton<EditorStateService>(mockEditorStateService)
            ..registerSingleton<PersistenceLogic>(mockPersistenceLogic);
        },
      );
    });

    tearDown(tearDownTestGetIt);

    /// Opens the modal for the default [testTextEntry] with a tracked
    /// controller override — the common case across this file.
    Future<void> openDefaultModal(WidgetTester tester) async {
      final (override, _) = createEntryControllerOverrideWithTracker(
        testTextEntry,
      );
      await _openModal(tester, override: override);
    }

    testWidgets('modal shows Date & Time Range title', (tester) async {
      await openDefaultModal(tester);

      expect(find.text('Date & Time Range'), findsOneWidget);
    });

    testWidgets('modal displays dateFrom and dateTo formatted values', (
      tester,
    ) async {
      await openDefaultModal(tester);

      // Both date fields show the formatted entry dates.
      final formattedFrom = dfShorter.format(testTextEntry.meta.dateFrom);
      final formattedTo = dfShorter.format(testTextEntry.meta.dateTo);

      expect(
        find.text(formattedFrom),
        findsWidgets,
        reason: 'dateFrom field should display the formatted start datetime',
      );
      expect(
        find.text(formattedTo),
        findsOneWidget,
        reason: 'dateTo field should display the formatted end datetime',
      );
    });

    testWidgets('modal displays duration label and computed duration', (
      tester,
    ) async {
      await openDefaultModal(tester);

      // Duration label is shown.
      expect(find.text('Duration:'), findsOneWidget);

      // The computed duration between 13:00 and 14:00 is 1 hour.
      final expectedDuration = formatDuration(
        testTextEntry.meta.dateTo.difference(testTextEntry.meta.dateFrom).abs(),
      );
      expect(find.text(expectedDuration), findsOneWidget);
    });

    testWidgets(
      'Save button is disabled when dates are unchanged (not dirty)',
      (tester) async {
        final (override, _) = createEntryControllerOverrideWithTracker(
          testTextEntry,
        );

        await _openModal(tester, override: override);

        // The Save button should be present but disabled (dates unchanged).
        final saveButton = find.text('SAVE');
        expect(saveButton, findsOneWidget);

        // DesignSystemButton with null onPressed renders as disabled.
        final filledButtonWidget = tester.widget<DesignSystemButton>(
          find.ancestor(
            of: saveButton,
            matching: find.byType(DesignSystemButton),
          ),
        );
        expect(
          filledButtonWidget.onPressed,
          isNull,
          reason: 'Save should be disabled when dates are unchanged',
        );
      },
    );

    testWidgets(
      'tapping dateFrom field navigates to picker page with "Date from:" label',
      (tester) async {
        final (override, _) = createEntryControllerOverrideWithTracker(
          testTextEntry,
        );

        await _openModal(tester, override: override);

        // Tap the dateFrom text field to navigate to the picker page.
        final formattedFrom = dfShorter.format(testTextEntry.meta.dateFrom);
        await tester.tap(find.text(formattedFrom).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // The picker page header shows the "Date from:" label. Both pages may
        // exist simultaneously in the modal, so at least 2 instances of the
        // text are expected (field label on page 0 + title on page 1).
        expect(find.text('Date from:'), findsAtLeastNWidgets(2));
        // The picker-page-specific action buttons confirm we are on page 1.
        expect(find.text('Cancel'), findsOneWidget);
        expect(find.text('Now'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping dateTo field navigates to picker page with "Date to:" label',
      (tester) async {
        final (override, _) = createEntryControllerOverrideWithTracker(
          testTextEntry,
        );

        await _openModal(tester, override: override);

        // Tap the dateTo text field.
        final formattedTo = dfShorter.format(testTextEntry.meta.dateTo);
        await tester.tap(find.text(formattedTo).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Both the field label on page 0 and the picker page title on page 1
        // show "Date to:", so at least 2 instances appear simultaneously.
        expect(find.text('Date to:'), findsAtLeastNWidgets(2));
        // Picker-page action buttons confirm we are on page 1.
        expect(find.text('Cancel'), findsOneWidget);
        expect(find.text('Now'), findsOneWidget);
      },
    );

    testWidgets('picker page shows Cancel / Now / Done buttons', (
      tester,
    ) async {
      await openDefaultModal(tester);

      // Navigate to picker page.
      final formattedFrom = dfShorter.format(testTextEntry.meta.dateFrom);
      await tester.tap(find.text(formattedFrom).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Now'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets(
      'tapping back arrow on picker page returns to range selection page',
      (tester) async {
        _useWideModalView(tester);

        final (override, _) = createEntryControllerOverrideWithTracker(
          testTextEntry,
        );

        await _openModal(
          tester,
          override: override,
          mediaQueryData: const MediaQueryData(size: Size(800, 900)),
          settle: const Duration(milliseconds: 500),
        );

        final formattedFrom = dfShorter.format(testTextEntry.meta.dateFrom);
        await tester.tap(find.text(formattedFrom).first);
        await tester.pump();
        // Pump past the page transition so the picker page is no longer
        // pointer-absorbed during the WoltModalSheet pagination animation.
        await tester.pump(const Duration(milliseconds: 500));

        // The picker page nav bar deterministically renders a back arrow
        // (Icons.arrow_back_rounded, via ModalUtils.modalSheetPage's onTapBack
        // leadingNavBarWidget). Tapping it returns to the range page.
        final backButton = find.byIcon(Icons.arrow_back_rounded);
        expect(backButton, findsOneWidget);
        await tester.tap(backButton);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('Date & Time Range'), findsOneWidget);
      },
    );

    testWidgets(
      'Save button stays disabled after navigating into the picker and back '
      'without changing dates',
      (tester) async {
        _useWideModalView(tester);

        final (override, _) = createEntryControllerOverrideWithTracker(
          testTextEntry,
        );

        await _openModal(
          tester,
          override: override,
          mediaQueryData: const MediaQueryData(size: Size(800, 900)),
          settle: const Duration(milliseconds: 500),
        );

        // Navigate into the picker page via the dateFrom field, then return
        // via the back arrow without touching the picker wheel.
        final formattedFrom = dfShorter.format(testTextEntry.meta.dateFrom);
        await tester.tap(find.text(formattedFrom).first);
        await tester.pump();
        // Pump past the page transition so the back button is hittable.
        await tester.pump(const Duration(milliseconds: 500));

        await tester.tap(find.byIcon(Icons.arrow_back_rounded));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Back on the range page; dates are unchanged, so Save must remain
        // disabled even though the user interacted with the modal.
        expect(find.text('Date & Time Range'), findsOneWidget);
        final saveButton = find.text('SAVE');
        expect(saveButton, findsOneWidget);
        final btn = tester.widget<DesignSystemButton>(
          find.ancestor(
            of: saveButton,
            matching: find.byType(DesignSystemButton),
          ),
        );
        expect(
          btn.onPressed,
          isNull,
          reason: 'Save disabled when no date change has occurred',
        );
      },
    );

    testWidgets(
      'valid date range does not show the invalid-range warning',
      (tester) async {
        // testTextEntry has dateTo after dateFrom (a valid range), so the
        // "Invalid Date Range" warning must NOT be rendered. The invalid case
        // (dateTo < dateFrom) is covered by a dedicated test further below.
        final (override, _) = createEntryControllerOverrideWithTracker(
          testTextEntry,
        );

        await _openModal(tester, override: override);

        // With valid dates, error warning is NOT visible.
        expect(find.text('Invalid Date Range'), findsNothing);
      },
    );

    testWidgets('_DateTimePickerStickyActionBar renders all three buttons', (
      tester,
    ) async {
      // Navigate into the picker page and verify the sticky bar content.
      await openDefaultModal(tester);

      // Tap dateTo to enter picker page.
      final formattedTo = dfShorter.format(testTextEntry.meta.dateTo);
      await tester.tap(find.text(formattedTo));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify all three action buttons are present.
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Now'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets(
      'DateTimeFieldType.to label shows "Date to:" on picker page title',
      (tester) async {
        final (override, _) = createEntryControllerOverrideWithTracker(
          testTextEntry,
        );

        await _openModal(tester, override: override);

        // Tap the dateTo field.
        final formattedTo = dfShorter.format(testTextEntry.meta.dateTo);
        await tester.tap(find.text(formattedTo));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Both the field label on page 0 and the picker page title show "Date to:".
        expect(find.text('Date to:'), findsAtLeastNWidgets(2));
        // Picker action buttons confirm we are on the picker page (page 1).
        expect(find.text('Done'), findsOneWidget);
      },
    );

    // ----------------------------------------------------------------
    // Validation: invalid date range (dateTo before dateFrom)
    // ----------------------------------------------------------------

    testWidgets(
      'invalid range: warning widget appears when dateTo < dateFrom',
      (tester) async {
        // _invalidRangeEntry has dateFrom=14:00, dateTo=13:00 so !valid.
        final override = entryControllerProvider(
          id: _invalidRangeEntry.meta.id,
        ).overrideWith(() => FakeEntryController(_invalidRangeEntry));

        await _openModal(
          tester,
          override: override,
          launcher: _ModalLauncherWithEntry(entry: _invalidRangeEntry),
        );

        // The validation warning text must be visible.
        expect(find.text('Invalid Date Range'), findsOneWidget);
        // The warning icon is also rendered (coverage for the icon + row path).
        expect(find.byIcon(Icons.warning_rounded), findsOneWidget);
      },
    );

    // ----------------------------------------------------------------
    // Picker page: Cancel button returns to range page
    // ----------------------------------------------------------------

    testWidgets('Cancel button on picker page returns to range page', (
      tester,
    ) async {
      _useWideModalView(tester);

      final (override, _) = createEntryControllerOverrideWithTracker(
        testTextEntry,
      );

      await _openModal(
        tester,
        override: override,
        mediaQueryData: const MediaQueryData(size: Size(800, 900)),
        settle: const Duration(milliseconds: 500),
      );

      // Navigate to picker page via dateFrom field.
      final formattedFrom = dfShorter.format(testTextEntry.meta.dateFrom);
      await tester.tap(find.text(formattedFrom).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Confirm we are on the picker page.
      expect(find.text('Cancel'), findsOneWidget);

      // Tap Cancel — should navigate back to the range page.
      await tester.ensureVisible(find.text('Cancel'));
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // After Cancel, picker-page action buttons are gone; range page title
      // is visible.
      expect(find.text('Date & Time Range'), findsOneWidget);
      expect(find.text('Cancel'), findsNothing);
    });

    // ----------------------------------------------------------------
    // Picker page: Done button returns to range page
    // ----------------------------------------------------------------

    testWidgets('Done button on picker page returns to range page', (
      tester,
    ) async {
      _useWideModalView(tester);

      final (override, _) = createEntryControllerOverrideWithTracker(
        testTextEntry,
      );

      await _openModal(
        tester,
        override: override,
        mediaQueryData: const MediaQueryData(size: Size(800, 900)),
        settle: const Duration(milliseconds: 500),
      );

      // Navigate to picker page via dateFrom field.
      final formattedFrom = dfShorter.format(testTextEntry.meta.dateFrom);
      await tester.tap(find.text(formattedFrom).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Done'), findsOneWidget);

      // Tap Done — should navigate back to the range page.
      await tester.ensureVisible(find.text('Done'));
      await tester.tap(find.text('Done'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Date & Time Range'), findsOneWidget);
      expect(find.text('Done'), findsNothing);
    });

    // ----------------------------------------------------------------
    // Picker page: Now button for the "from" field
    // ----------------------------------------------------------------

    testWidgets(
      'Now button on picker page for dateFrom field returns to range page',
      (tester) async {
        _useWideModalView(tester);

        final (override, _) = createEntryControllerOverrideWithTracker(
          testTextEntry,
        );

        await _openModal(
          tester,
          override: override,
          mediaQueryData: const MediaQueryData(size: Size(800, 900)),
          settle: const Duration(milliseconds: 500),
        );

        // Open picker page for the dateFrom field.
        final formattedFrom = dfShorter.format(testTextEntry.meta.dateFrom);
        await tester.tap(find.text(formattedFrom).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Confirm we are on the picker page (Now button present).
        expect(find.text('Now'), findsOneWidget);

        // Tap Now — the onNow handler runs the DateTimeFieldType.from branch
        // (sets dateFromNotifier.value = DateTime.now()) and navigates back.
        await tester.ensureVisible(find.text('Now'));
        await tester.tap(find.text('Now'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Now back on the range page.
        expect(find.text('Date & Time Range'), findsOneWidget);
        expect(find.text('Now'), findsNothing);
      },
    );

    // ----------------------------------------------------------------
    // Picker page: Now button for the "to" field
    // ----------------------------------------------------------------

    testWidgets(
      'Now button on picker page for dateTo field returns to range page',
      (tester) async {
        _useWideModalView(tester);

        final (override, _) = createEntryControllerOverrideWithTracker(
          testTextEntry,
        );

        await _openModal(
          tester,
          override: override,
          mediaQueryData: const MediaQueryData(size: Size(800, 900)),
          settle: const Duration(milliseconds: 500),
        );

        // Open picker page for the dateTo field.
        final formattedTo = dfShorter.format(testTextEntry.meta.dateTo);
        await tester.tap(find.text(formattedTo).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('Now'), findsOneWidget);

        // Tap Now — the onNow handler runs the DateTimeFieldType.to branch
        // (sets dateToNotifier.value = DateTime.now()) and navigates back.
        await tester.ensureVisible(find.text('Now'));
        await tester.tap(find.text('Now'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('Date & Time Range'), findsOneWidget);
        expect(find.text('Now'), findsNothing);
      },
    );

    // ----------------------------------------------------------------
    // Picker: CupertinoDatePicker is rendered with correct initialDateTime
    // ----------------------------------------------------------------

    testWidgets(
      '_DateTimePickerPage shows CupertinoDatePicker initialized to dateFrom',
      (tester) async {
        _useWideModalView(tester);

        final (override, _) = createEntryControllerOverrideWithTracker(
          testTextEntry,
        );

        await _openModal(
          tester,
          override: override,
          mediaQueryData: const MediaQueryData(size: Size(800, 900)),
          settle: const Duration(milliseconds: 500),
        );

        // Navigate to the dateFrom picker page.
        final formattedFrom = dfShorter.format(testTextEntry.meta.dateFrom);
        await tester.tap(find.text(formattedFrom).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // The CupertinoDatePicker is rendered on the picker page.
        final pickerFinder = find.byType(CupertinoDatePicker);
        expect(pickerFinder, findsOneWidget);

        // The picker is initialized with the correct dateFrom value.
        final picker = tester.widget<CupertinoDatePicker>(pickerFinder);
        expect(
          picker.initialDateTime,
          testTextEntry.meta.dateFrom,
          reason: 'Picker should be initialized with entry dateFrom',
        );
        expect(picker.use24hFormat, isTrue);
        // The picker has a non-null onDateTimeChanged callback.
        expect(picker.onDateTimeChanged, isNotNull);
      },
    );

    testWidgets(
      '_DateTimePickerPage shows CupertinoDatePicker initialized to dateTo',
      (tester) async {
        _useWideModalView(tester);

        final (override, _) = createEntryControllerOverrideWithTracker(
          testTextEntry,
        );

        await _openModal(
          tester,
          override: override,
          mediaQueryData: const MediaQueryData(size: Size(800, 900)),
          settle: const Duration(milliseconds: 500),
        );

        // Navigate to the dateTo picker page.
        final formattedTo = dfShorter.format(testTextEntry.meta.dateTo);
        await tester.tap(find.text(formattedTo).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // The CupertinoDatePicker for the dateTo field is rendered.
        final pickerFinder = find.byType(CupertinoDatePicker);
        expect(pickerFinder, findsOneWidget);

        // The picker is initialized with the correct dateTo value.
        final picker = tester.widget<CupertinoDatePicker>(pickerFinder);
        expect(
          picker.initialDateTime,
          testTextEntry.meta.dateTo,
          reason: 'Picker should be initialized with entry dateTo',
        );
        // The onDateTimeChanged callback is the mechanism for updating the
        // dateToNotifier when the user scrolls the picker.
        expect(picker.onDateTimeChanged, isNotNull);
      },
    );

    // ----------------------------------------------------------------
    // Save enabled via Now TO: dateTo set to now, dateFrom original
    // ----------------------------------------------------------------

    testWidgets(
      'Save button enabled after Now button changes dateTo (valid range)',
      (tester) async {
        _useWideModalView(tester);

        final tracker = ToggleCallTracker();
        final override =
            entryControllerProvider(
              id: testTextEntry.meta.id,
            ).overrideWith(
              () => FakeEntryController(testTextEntry, tracker: tracker),
            );

        await _openModal(
          tester,
          override: override,
          mediaQueryData: const MediaQueryData(size: Size(800, 900)),
          settle: const Duration(milliseconds: 500),
        );

        // Navigate to the dateTo picker page and tap Now to set dateTo=now.
        // Since testTextEntry.dateFrom = 2022-07-07 13:00 and now > 2022,
        // the resulting range is valid (now > dateFrom) and changed.
        final formattedTo = dfShorter.format(testTextEntry.meta.dateTo);
        await tester.tap(find.text(formattedTo).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('Now'), findsOneWidget);
        await tester.ensureVisible(find.text('Now'));
        await tester.tap(find.text('Now'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // After Now is tapped for dateTo, Save should be enabled:
        // dateToNotifier.value = now (changed) AND now > 2022 (valid).
        final saveButton = find.text('SAVE');
        expect(saveButton, findsOneWidget);
        final filledBtn = tester.widget<DesignSystemButton>(
          find.ancestor(
            of: saveButton,
            matching: find.byType(DesignSystemButton),
          ),
        );
        expect(
          filledBtn.onPressed,
          isNotNull,
          reason:
              'Save should be enabled after Now changes dateTo to a future date',
        );
      },
    );

    // ----------------------------------------------------------------
    // Save button: calls updateFromTo and closes modal
    // ----------------------------------------------------------------

    testWidgets(
      'tapping Save calls updateFromTo on controller and closes modal',
      (tester) async {
        _useWideModalView(tester);

        final tracker = ToggleCallTracker();
        final override =
            entryControllerProvider(
              id: testTextEntry.meta.id,
            ).overrideWith(
              () => FakeEntryController(testTextEntry, tracker: tracker),
            );

        await _openModal(
          tester,
          override: override,
          mediaQueryData: const MediaQueryData(size: Size(800, 900)),
          settle: const Duration(milliseconds: 500),
        );

        // Navigate to the dateTo picker page and tap Now to set dateTo=now.
        // testTextEntry.dateFrom = 2022-07-07 13:00 and now > 2022 → valid + changed.
        final formattedTo = dfShorter.format(testTextEntry.meta.dateTo);
        await tester.tap(find.text(formattedTo).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        await tester.ensureVisible(find.text('Now'));
        await tester.tap(find.text('Now'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Save is now enabled (dateTo changed) — tap it.
        final saveButton = find.text('SAVE');
        expect(saveButton, findsOneWidget);
        await tester.ensureVisible(saveButton);
        await tester.tap(saveButton);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // updateFromTo was called exactly once.
        expect(
          tracker.updateFromToCalls,
          hasLength(1),
          reason: 'updateFromTo should be called once when Save is tapped',
        );
        // The call carried dateFrom = original (unchanged).
        expect(
          tracker.updateFromToCalls.first,
          containsPair('dateFrom', testTextEntry.meta.dateFrom),
        );
      },
    );

    // ----------------------------------------------------------------
    // Picker: onDateTimeChanged updates the correct notifier per field
    // ----------------------------------------------------------------

    // Drives the CupertinoDatePicker.onDateTimeChanged callback directly for a
    // given field, then taps Save and returns the DateTime forwarded to
    // updateFromTo for that field. This exercises both branches of the
    // onDateTimeChanged closure (from vs. to) through observable output: the
    // value that reaches the controller's updateFromTo call.
    Future<DateTime> changeFieldViaPickerAndSave(
      WidgetTester tester, {
      required ToggleCallTracker tracker,
      required String formattedFieldText,
      required DateTime newValue,
      required String trackerKey,
    }) async {
      // Open the picker page for the requested field.
      await tester.tap(find.text(formattedFieldText).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Invoke the picker's onDateTimeChanged with a deterministic value.
      final picker = tester.widget<CupertinoDatePicker>(
        find.byType(CupertinoDatePicker),
      );
      picker.onDateTimeChanged(newValue);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Return to the range page via Done so Save is reachable.
      await tester.ensureVisible(find.text('Done'));
      await tester.tap(find.text('Done'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Save the change.
      final saveButton = find.text('SAVE');
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        tracker.updateFromToCalls,
        hasLength(1),
        reason: 'Save should forward the picked value to updateFromTo',
      );
      return tracker.updateFromToCalls.first[trackerKey]!;
    }

    testWidgets(
      'onDateTimeChanged on the from picker updates dateFrom and is saved',
      (tester) async {
        _useWideModalView(tester);

        final tracker = ToggleCallTracker();
        final override =
            entryControllerProvider(
              id: testTextEntry.meta.id,
            ).overrideWith(
              () => FakeEntryController(testTextEntry, tracker: tracker),
            );

        await _openModal(
          tester,
          override: override,
          mediaQueryData: const MediaQueryData(size: Size(800, 900)),
          settle: const Duration(milliseconds: 500),
        );

        // New dateFrom kept strictly before the original dateTo
        // (2022-07-07 14:00) so the range stays valid and is detected as dirty.
        final newFrom = DateTime(2022, 7, 7, 9, 30);
        final saved = await changeFieldViaPickerAndSave(
          tester,
          tracker: tracker,
          formattedFieldText: dfShorter.format(testTextEntry.meta.dateFrom),
          newValue: newFrom,
          trackerKey: 'dateFrom',
        );

        // The from-branch (selectedField == from) wrote the new value into
        // dateFromNotifier, which is what reached updateFromTo.
        expect(saved, newFrom);
        // dateTo was left untouched by the from-branch.
        expect(
          tracker.updateFromToCalls.first['dateTo'],
          testTextEntry.meta.dateTo,
        );
      },
    );

    testWidgets(
      'onDateTimeChanged on the to picker updates dateTo and is saved',
      (tester) async {
        _useWideModalView(tester);

        final tracker = ToggleCallTracker();
        final override =
            entryControllerProvider(
              id: testTextEntry.meta.id,
            ).overrideWith(
              () => FakeEntryController(testTextEntry, tracker: tracker),
            );

        await _openModal(
          tester,
          override: override,
          mediaQueryData: const MediaQueryData(size: Size(800, 900)),
          settle: const Duration(milliseconds: 500),
        );

        // New dateTo kept strictly after dateFrom (13:00) so the range is valid.
        final newTo = DateTime(2024, 3, 15, 18);
        final saved = await changeFieldViaPickerAndSave(
          tester,
          tracker: tracker,
          formattedFieldText: dfShorter.format(testTextEntry.meta.dateTo),
          newValue: newTo,
          trackerKey: 'dateTo',
        );

        // The else-branch (selectedField == to) wrote the new value into
        // dateToNotifier, which is what reached updateFromTo.
        expect(saved, newTo);
        // dateFrom was left untouched by the to-branch.
        expect(
          tracker.updateFromToCalls.first['dateFrom'],
          testTextEntry.meta.dateFrom,
        );
      },
    );

    // ----------------------------------------------------------------
    // Save handler: updateFromTo throwing is caught and logged
    // ----------------------------------------------------------------

    testWidgets(
      'Save logs a warning and keeps the modal open when updateFromTo throws',
      (tester) async {
        _useWideModalView(tester);
        DevLogger.clear();
        addTearDown(DevLogger.clear);

        final override = entryControllerProvider(
          id: testTextEntry.meta.id,
        ).overrideWith(() => _ThrowingEntryController(testTextEntry));

        await _openModal(
          tester,
          override: override,
          mediaQueryData: const MediaQueryData(size: Size(800, 900)),
          settle: const Duration(milliseconds: 500),
        );

        // Make the range dirty + valid by scrolling the dateTo picker forward.
        await tester.tap(
          find.text(dfShorter.format(testTextEntry.meta.dateTo)).first,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final picker = tester.widget<CupertinoDatePicker>(
          find.byType(CupertinoDatePicker),
        );
        picker.onDateTimeChanged(DateTime(2024, 3, 15, 18));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        await tester.ensureVisible(find.text('Done'));
        await tester.tap(find.text('Done'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Tap Save — updateFromTo throws, the catch block logs and swallows.
        final saveButton = find.text('SAVE');
        await tester.ensureVisible(saveButton);
        await tester.tap(saveButton);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // The warning was logged with the modal's name and the error text.
        expect(
          DevLogger.capturedLogs,
          contains(
            allOf(
              contains('EntryDateTimeMultiPageModal'),
              contains('Error updating date range'),
              contains('boom'),
            ),
          ),
        );

        // The modal stays open because the pop only runs on success.
        expect(find.text('Date & Time Range'), findsOneWidget);
      },
    );
  });
}
