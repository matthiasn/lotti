import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show AsyncData;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/time_pickers/design_system_picker_wheels.dart';
import 'package:lotti/features/design_system/components/toggles/design_system_toggle.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/entry_datetime_multipage_modal.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/fake_entry_controller.dart';
import '../../../../../mocks/mocks.dart';
import '../../../../../widget_test_utils.dart';

JournalEntry _entry({
  required String id,
  required DateTime from,
  required DateTime to,
}) => JournalEntry(
  meta: Metadata(
    id: id,
    createdAt: from,
    dateFrom: from,
    dateTo: to,
    updatedAt: from,
  ),
);

// All dated in 2024 so tapping the "Today" pill always changes the date,
// deterministically enabling Save without driving the Cupertino wheels.
final JournalEntry _sameDay = _entry(
  id: 'e-same',
  from: DateTime(2024, 6, 15, 14, 30),
  to: DateTime(2024, 6, 15, 15, 15),
);
final JournalEntry _futureEntry = _entry(
  id: 'e-future',
  from: DateTime(2100, 6, 15, 14, 30),
  to: DateTime(2100, 6, 15, 15, 15),
);
final JournalEntry _overnight = _entry(
  id: 'e-night',
  from: DateTime(2024, 6, 15, 23, 30),
  to: DateTime(2024, 6, 16, 0, 30),
);
final JournalEntry _multiDay = _entry(
  id: 'e-multi',
  from: DateTime(2024, 6, 14, 9),
  to: DateTime(2024, 6, 16, 11),
);

class _Launcher extends StatelessWidget {
  const _Launcher({required this.entry});
  final JournalEntity entry;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () =>
          EntryDateTimeMultiPageModal.show(context: context, entry: entry),
      child: const Text('Open'),
    );
  }
}

// A controller whose updateFromTo always throws, to exercise the Save handler's
// catch block (logs and keeps the modal open).
class _ThrowingEntryController extends EntryController {
  _ThrowingEntryController(this._entity);

  final JournalEntity _entity;

  @override
  Future<EntryState?> build() {
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

void main() {
  group('EntryDateTimeMultiPageModal', () {
    setUp(() async {
      final updateNotifications = MockUpdateNotifications();
      when(
        () => updateNotifications.updateStream,
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => updateNotifications.localUpdateStream,
      ).thenAnswer((_) => const Stream.empty());
      final journalDb = MockJournalDb();
      when(
        () => journalDb.journalEntityById(any()),
      ).thenAnswer((_) async => _sameDay);
      final editorStateService = MockEditorStateService();
      when(
        () => editorStateService.getUnsavedStream(any(), any()),
      ).thenAnswer((_) => const Stream.empty());

      await setUpTestGetIt(
        additionalSetup: () {
          getIt
            ..unregister<UpdateNotifications>()
            ..registerSingleton<UpdateNotifications>(updateNotifications)
            ..unregister<JournalDb>()
            ..registerSingleton<JournalDb>(journalDb)
            ..registerSingleton<EditorStateService>(editorStateService)
            ..registerSingleton<PersistenceLogic>(MockPersistenceLogic());
        },
      );
    });
    tearDown(tearDownTestGetIt);

    // Render as a centered dialog so the whole sheet (incl. the glass Save bar)
    // is on screen and hittable.
    void useWideView(WidgetTester tester) {
      tester.view
        ..physicalSize = const Size(1600, 1800)
        ..devicePixelRatio = 2;
      addTearDown(tester.view.reset);
    }

    Future<ToggleCallTracker> openModal(
      WidgetTester tester,
      JournalEntity entry, {
      Override? overrideController,
      MediaQueryData? mediaQueryData,
    }) async {
      final (
        trackedOverride,
        tracker,
      ) = createEntryControllerOverrideWithTracker(
        entry,
      );
      useWideView(tester);
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          _Launcher(entry: entry),
          overrides: [overrideController ?? trackedOverride],
          mediaQueryData: mediaQueryData,
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      return tracker;
    }

    DesignSystemButton saveButton(WidgetTester tester) =>
        tester.widget<DesignSystemButton>(
          find.widgetWithText(DesignSystemButton, 'Save'),
        );

    Finder quickAction(String semanticsLabel) => find.byWidgetPredicate(
      (widget) =>
          widget is DesignSystemButton &&
          widget.semanticsLabel == semanticsLabel,
    );

    testWidgets('renders the title and the one-date / two-times controls', (
      tester,
    ) async {
      await openModal(
        tester,
        _sameDay,
        mediaQueryData: const MediaQueryData(size: Size(800, 900)),
      );

      expect(find.text('Date & Time'), findsOneWidget);
      expect(find.text('Start time'), findsOneWidget);
      expect(find.text('End time'), findsOneWidget);
      expect(find.text('Saturday, June 15, 2024'), findsOneWidget);
      // The shared date affordance, endpoint shortcuts, and explicit-date mode.
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Now'), findsNWidgets(2));
      expect(find.text('Pick a separate end date'), findsOneWidget);
      expect(find.byType(DesignSystemToggle), findsOneWidget);
      expect(
        quickAction('Set start date and time to now'),
        findsOneWidget,
      );
      expect(quickAction('Set end date and time to now'), findsOneWidget);
      // The pinned duration and absolute endpoint readout.
      expect(find.text('Duration'), findsOneWidget);
      expect(find.text('45m'), findsOneWidget);
      expect(find.textContaining('Sat, Jun 15'), findsOneWidget);

      final pickers = find.byType(DesignSystemTimeWheel);
      expect(pickers, findsNWidgets(2));
      expect(find.byType(CalendarDatePicker), findsNothing);
      expect(find.byType(ListWheelScrollView), findsNWidgets(6));
    });

    testWidgets('date button transitions to the shared weekday calendar and '
        'back', (
      tester,
    ) async {
      await openModal(tester, _sameDay);
      final modalBarrierCount = find.byType(ModalBarrier).evaluate().length;

      await tester.tap(find.text('Saturday, June 15, 2024'));
      await tester.pumpAndSettle();

      expect(find.byType(CalendarDatePicker), findsOneWidget);
      expect(find.byType(ModalBarrier), findsNWidgets(modalBarrierCount));
      expect(find.byTooltip('Back'), findsOneWidget);
      expect(find.text('Start date'), findsOneWidget);
      expect(find.text('Saturday, June 15, 2024'), findsWidgets);
      expect(find.text('Done'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(CalendarDatePicker),
          matching: find.text('16'),
        ),
      );
      await tester.pump();
      expect(find.text('Sunday, June 16, 2024'), findsOneWidget);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.text('Date & Time'), findsOneWidget);
      expect(find.text('Sunday, June 16, 2024'), findsOneWidget);
      expect(saveButton(tester).onPressed, isNotNull);
    });

    testWidgets('the reusable calendar page edits the explicit end date', (
      tester,
    ) async {
      await openModal(tester, _sameDay);

      await tester.tap(find.byType(DesignSystemToggle));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Saturday, June 15, 2024').last);
      await tester.pumpAndSettle();

      expect(find.text('End date'), findsWidgets);
      expect(find.byType(CalendarDatePicker), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(CalendarDatePicker),
          matching: find.text('17'),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.text('Monday, June 17, 2024'), findsOneWidget);
      expect(saveButton(tester).onPressed, isNotNull);
    });

    testWidgets('calendar Back returns to the unchanged overview', (
      tester,
    ) async {
      await openModal(tester, _sameDay);
      await tester.tap(find.text('Saturday, June 15, 2024'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.text('Date & Time'), findsOneWidget);
      expect(saveButton(tester).onPressed, isNull);
    });

    testWidgets('same-day opens with the toggle off and reveals an End date '
        'when toggled on', (tester) async {
      await openModal(tester, _sameDay);

      expect(
        tester
            .widget<DesignSystemToggle>(find.byType(DesignSystemToggle))
            .value,
        isFalse,
      );
      expect(find.text('End date'), findsNothing);

      await tester.tap(find.byType(DesignSystemToggle));
      await tester.pumpAndSettle();

      // The caption relabels and the End date wheel is revealed.
      expect(find.text('Start date'), findsOneWidget);
      expect(find.text('End date'), findsOneWidget);
    });

    testWidgets('overnight entry shows the auto next-day chip and rolled '
        'duration', (tester) async {
      await openModal(tester, _overnight);

      // Toggle stays off — the +1 day roll is automatic, not the manual mode.
      expect(
        tester
            .widget<DesignSystemToggle>(find.byType(DesignSystemToggle))
            .value,
        isFalse,
      );
      expect(find.textContaining('(next day)'), findsOneWidget);
      // 23:30 -> next-day 00:30 == 1h.
      expect(find.text('1h'), findsOneWidget);
    });

    testWidgets('multi-day entry opens in different-dates mode', (
      tester,
    ) async {
      await openModal(tester, _multiDay);

      expect(
        tester
            .widget<DesignSystemToggle>(find.byType(DesignSystemToggle))
            .value,
        isTrue,
      );
      expect(find.text('Start date'), findsOneWidget);
      expect(find.text('End date'), findsOneWidget);
      // Jun 14 09:00 -> Jun 16 11:00 == 2d 2h.
      expect(find.text('2d 2h'), findsOneWidget);
    });

    testWidgets('Save is disabled until the range changes, then persists and '
        'pops', (tester) async {
      final tracker = await openModal(tester, _sameDay);

      // Unchanged on open.
      expect(saveButton(tester).onPressed, isNull);

      // Tapping Today moves the (2024) date to today — a real change.
      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();
      expect(saveButton(tester).onPressed, isNotNull);

      await tester.tap(find.widgetWithText(DesignSystemButton, 'Save'));
      await tester.pumpAndSettle();

      expect(tracker.updateFromToCalls, hasLength(1));
      // The modal popped.
      expect(find.text('Date & Time'), findsNothing);
    });

    testWidgets('a failing save logs and keeps the modal open', (tester) async {
      await openModal(
        tester,
        _sameDay,
        overrideController: entryControllerProvider(
          _sameDay.meta.id,
        ).overrideWith(() => _ThrowingEntryController(_sameDay)),
      );

      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(DesignSystemButton, 'Save'));
      await tester.pumpAndSettle();

      // updateFromTo threw → caught → the modal stays open.
      expect(find.text('Date & Time'), findsOneWidget);
    });

    testWidgets(
      'End Now preserves the start and sets a complete end endpoint',
      (
        tester,
      ) async {
        final tracker = await openModal(tester, _sameDay);

        await tester.tap(quickAction('Set end date and time to now'));
        await tester.pumpAndSettle();

        expect(
          tester
              .widget<DesignSystemToggle>(find.byType(DesignSystemToggle))
              .value,
          isTrue,
        );
        expect(find.text('End date'), findsOneWidget);
        expect(saveButton(tester).onPressed, isNotNull);

        await tester.tap(find.widgetWithText(DesignSystemButton, 'Save'));
        await tester.pumpAndSettle();

        expect(tracker.updateFromToCalls, hasLength(1));
        expect(
          tracker.updateFromToCalls.single['dateFrom'],
          _sameDay.meta.dateFrom,
        );
        expect(
          tracker.updateFromToCalls.single['dateTo']!.isAfter(
            _sameDay.meta.dateTo,
          ),
          isTrue,
        );
      },
    );

    testWidgets('Start Now changes the complete start endpoint', (
      tester,
    ) async {
      await openModal(tester, _futureEntry);

      await tester.tap(quickAction('Set start date and time to now'));
      await tester.pump();

      expect(saveButton(tester).onPressed, isNotNull);
    });

    testWidgets('Today can update an explicit end date', (tester) async {
      await openModal(tester, _multiDay);

      final endToday = quickAction('End date, Today');
      await tester.tap(endToday);
      await tester.pump();

      expect(saveButton(tester).onPressed, isNotNull);
    });

    testWidgets('end time wheel callback updates the range', (tester) async {
      await openModal(tester, _sameDay);
      final endWheel = tester.widget<DesignSystemTimeWheel>(
        find.byType(DesignSystemTimeWheel).last,
      );

      endWheel.onDateTimeChanged(DateTime(2024, 6, 15, 16));
      await tester.pump();

      expect(saveButton(tester).onPressed, isNotNull);
    });

    testWidgets('iPhone-width layout keeps paired times readable', (
      tester,
    ) async {
      await openModal(
        tester,
        _sameDay,
        mediaQueryData: const MediaQueryData(
          size: Size(402, 874),
          padding: EdgeInsets.only(top: 47, bottom: 34),
          alwaysUse24HourFormat: true,
        ),
      );

      final startCenter = tester.getCenter(find.text('Start time'));
      final endCenter = tester.getCenter(find.text('End time'));
      expect((startCenter.dy - endCenter.dy).abs(), lessThan(1));
      expect(endCenter.dx, greaterThan(startCenter.dx));
      expect(tester.takeException(), isNull);
    });

    testWidgets('large text stacks endpoint time controls on narrow screens', (
      tester,
    ) async {
      await openModal(
        tester,
        _sameDay,
        mediaQueryData: const MediaQueryData(
          size: Size(402, 874),
          padding: EdgeInsets.only(top: 47, bottom: 34),
          alwaysUse24HourFormat: true,
          textScaler: TextScaler.linear(2),
        ),
      );

      final startCenter = tester.getCenter(find.text('Start time'));
      final endCenter = tester.getCenter(find.text('End time'));
      expect(endCenter.dy, greaterThan(startCenter.dy));
      expect(tester.takeException(), isNull);
    });

    testWidgets('spinning the time wheels changes the range and '
        'enables Save', (tester) async {
      await openModal(tester, _sameDay);
      expect(saveButton(tester).onPressed, isNull);

      // Large drags cross several items so each settled-change callback fires.
      final wheels = find.byType(ListWheelScrollView);
      await tester.drag(wheels.at(0), const Offset(0, -100)); // start hour
      await tester.pumpAndSettle();

      expect(saveButton(tester).onPressed, isNotNull);
    });

    testWidgets('multi-day toggling off collapses back to a single date', (
      tester,
    ) async {
      await openModal(tester, _multiDay);
      expect(find.text('End date'), findsOneWidget);

      // Toggling off clears the override and collapses to a single shared date.
      await tester.tap(find.byType(DesignSystemToggle));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<DesignSystemToggle>(find.byType(DesignSystemToggle))
            .value,
        isFalse,
      );
      expect(find.text('End date'), findsNothing);
      expect(find.textContaining('Friday, June 14, 2024'), findsOneWidget);
    });
  });
}
