import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/calendar_pickers/design_system_date_picker_modal.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/components/time_pickers/design_system_picker_wheels.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/pages/create/create_measurement_dialog.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fallbacks.dart';
import '../../mocks/mocks.dart';
import '../../test_data/test_data.dart';
import '../../widget_test_utils.dart';
import 'test_utils.dart';

const _openKey = ValueKey<String>('open-measurement-capture');
const _observedAtKey = Key('measurement_observed_at');
const _valueKey = Key('measurement_value_field');
const _commentKey = Key('measurement_comment_field');
const _saveKey = Key('measurement_save');
const _doneKey = ValueKey<String>('measurement-date-time-done');
const _nowKey = ValueKey<String>('measurement-observed-at-now');
const _timeSectionKey = ValueKey<String>('measurement-time-section');

final _fixedNow = DateTime.utc(2024, 3, 15, 14, 30, 15, 16, 17);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockJournalDb mockJournalDb;
  late MockPersistenceLogic mockPersistenceLogic;

  setUpAll(registerAllFallbackValues);

  setUp(() async {
    mockJournalDb = mockJournalDbWithMeasurableTypes([measurableWater]);
    mockPersistenceLogic = MockPersistenceLogic();

    await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..unregister<JournalDb>()
          ..registerSingleton<JournalDb>(mockJournalDb)
          ..registerSingleton<PersistenceLogic>(mockPersistenceLogic);
      },
    );

    when(
      () => mockJournalDb.getMeasurementsByType(
        rangeStart: any(named: 'rangeStart'),
        rangeEnd: any(named: 'rangeEnd'),
        type: measurableWater.id,
      ),
    ).thenAnswer((_) async => []);
    when(
      () => mockPersistenceLogic.createMeasurementEntry(
        data: any(named: 'data'),
        comment: any(named: 'comment'),
        private: any(named: 'private'),
      ),
    ).thenAnswer((_) async => measurementSuggestionFixture().first);
  });

  tearDown(tearDownTestGetIt);

  Future<void> pumpLauncher(
    WidgetTester tester, {
    DateTime? now,
    MeasurableDataType? dataType,
    MediaQueryData mediaQueryData = const MediaQueryData(
      size: Size(402, 874),
      padding: EdgeInsets.only(bottom: 24),
    ),
  }) async {
    tester.view
      ..physicalSize = mediaQueryData.size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: DesignSystemButton(
                key: _openKey,
                label: 'Open measurement capture',
                onPressed: () {
                  unawaited(
                    withClock(
                      Clock.fixed(now ?? _fixedNow),
                      () => MeasurementCaptureModal.show(
                        context: context,
                        measurableDataType: dataType ?? measurableWater,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        mediaQueryData: mediaQueryData,
      ),
    );
  }

  Future<void> openCapture(WidgetTester tester) async {
    await tester.tap(find.byKey(_openKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    expect(find.byKey(_valueKey), findsOneWidget);
  }

  Future<void> openObservedAt(WidgetTester tester) async {
    await tester.tap(find.byKey(_observedAtKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    expect(find.byType(DesignSystemCalendarPicker), findsOneWidget);
    expect(find.byType(DesignSystemTimeWheel), findsOneWidget);
  }

  Future<void> setPickerDateTime(
    WidgetTester tester, {
    required DateTime date,
    required DateTime time,
  }) async {
    tester
        .widget<DesignSystemCalendarPicker>(
          find.byType(DesignSystemCalendarPicker),
        )
        .onDateChanged(date);
    await tester.pump();
    tester
        .widget<DesignSystemTimeWheel>(find.byType(DesignSystemTimeWheel))
        .onDateTimeChanged(time);
    await tester.pump();
  }

  Future<void> tapDone(WidgetTester tester) async {
    await tester.tap(find.byKey(_doneKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump();
    await tester.pump();
    expect(find.byType(DesignSystemCalendarPicker), findsNothing);
  }

  MeasurementData capturedData(Invocation invocation) {
    return invocation.namedArguments[const Symbol('data')] as MeasurementData;
  }

  testWidgets('disposes the draft when route construction fails', (
    tester,
  ) async {
    late BuildContext contextWithoutNavigator;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(
          builder: (context) {
            contextWithoutNavigator = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    await expectLater(
      MeasurementCaptureModal.show(
        context: contextWithoutNavigator,
        measurableDataType: measurableWater,
      ),
      throwsA(isA<FlutterError>()),
    );
  });

  testWidgets(
    'renders localized, accessible editor with a sticky Save action',
    (
      tester,
    ) async {
      await pumpLauncher(tester);
      await openCapture(tester);

      expect(find.text('Water'), findsOneWidget);
      expect(find.text('H₂O, with or without bubbles'), findsOneWidget);
      expect(find.text('ml'), findsOneWidget);
      expect(find.byType(DesignSystemGlassActionFooter), findsOneWidget);

      final save = tester.widget<DesignSystemButton>(find.byKey(_saveKey));
      expect(save.onPressed, isNull);
      expect(save.fullWidth, isTrue);

      expect(
        tester.getSemantics(find.byKey(_valueKey)).label,
        contains('Value for Water, ml'),
      );
      expect(
        tester.getSemantics(find.byKey(_observedAtKey)).label,
        allOf(contains('Observed at'), contains('Change date and time')),
      );
      expect(
        tester.getSemantics(find.byKey(_commentKey)).label,
        contains('Comment, optional'),
      );
    },
  );

  testWidgets('value semantics omit the separator when there is no unit', (
    tester,
  ) async {
    await pumpLauncher(
      tester,
      dataType: measurableWater.copyWith(unitName: ''),
    );
    await openCapture(tester);

    final label = tester.getSemantics(find.byKey(_valueKey)).label;
    expect(label, contains('Value for Water'));
    expect(label, isNot(contains('Water,')));
  });

  testWidgets(
    'one route preserves the value and comment, Done commits, and Save '
    'persists the exact measurement',
    (tester) async {
      MeasurementData? savedData;
      String? savedComment;
      bool? savedPrivate;
      when(
        () => mockPersistenceLogic.createMeasurementEntry(
          data: any(named: 'data'),
          comment: any(named: 'comment'),
          private: any(named: 'private'),
        ),
      ).thenAnswer((invocation) async {
        savedData = capturedData(invocation);
        savedComment =
            invocation.namedArguments[const Symbol('comment')] as String;
        savedPrivate =
            invocation.namedArguments[const Symbol('private')] as bool;
        return measurementSuggestionFixture().first;
      });

      await pumpLauncher(tester);
      await openCapture(tester);
      await tester.enterText(find.byKey(_valueKey), '750,5');
      await tester.enterText(find.byKey(_commentKey), 'After the long run');
      await tester.pump();

      final barrierCount = find.byType(ModalBarrier).evaluate().length;
      await openObservedAt(tester);
      expect(find.byType(ModalBarrier), findsNWidgets(barrierCount));

      await setPickerDateTime(
        tester,
        date: DateTime.utc(2024, 3, 20),
        time: DateTime.utc(2024, 3, 20, 9, 45),
      );
      await tapDone(tester);

      expect(find.text('750,5'), findsOneWidget);
      expect(find.text('After the long run'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byKey(_valueKey)).autofocus,
        isFalse,
      );
      final observedAtInkWell = tester.widget<InkWell>(
        find.descendant(
          of: find.byKey(_observedAtKey),
          matching: find.byType(InkWell),
        ),
      );
      expect(observedAtInkWell.autofocus, isTrue);
      expect(observedAtInkWell.focusNode?.canRequestFocus, isTrue);
      expect(
        observedAtInkWell.focusNode?.hasFocus,
        isTrue,
        reason: 'primary focus: ${FocusManager.instance.primaryFocus}',
      );

      await tester.tap(find.byKey(_saveKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pump();
      await tester.pump();

      expect(savedData?.dataTypeId, measurableWater.id);
      expect(savedData?.value, 750.5);
      expect(savedData?.dateFrom, savedData?.dateTo);
      expect(
        savedData?.dateFrom,
        DateTime.utc(2024, 3, 20, 9, 45, 15, 16, 17),
      );
      expect(savedData?.dateFrom.isUtc, isTrue);
      expect(savedComment, 'After the long run');
      expect(savedPrivate, isFalse);
      expect(find.byKey(_valueKey), findsNothing);
    },
  );

  testWidgets('Back, system Back, and Escape discard picker drafts', (
    tester,
  ) async {
    await pumpLauncher(tester);
    await openCapture(tester);
    await tester.enterText(find.byKey(_valueKey), '500');
    await tester.enterText(find.byKey(_commentKey), 'Keep this draft');

    Future<void> changeDraft() => setPickerDateTime(
      tester,
      date: DateTime.utc(2024, 4, 2),
      time: DateTime.utc(2024, 4, 2, 8, 5),
    );

    Future<void> assertDiscarded() async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      expect(find.byType(DesignSystemCalendarPicker), findsNothing);
      expect(find.text('500'), findsOneWidget);
      expect(find.text('Keep this draft'), findsOneWidget);
      expect(
        tester.getSemantics(find.byKey(_observedAtKey)).label,
        contains('March 15, 2024'),
      );
      final observedAtInkWell = tester.widget<InkWell>(
        find.descendant(
          of: find.byKey(_observedAtKey),
          matching: find.byType(InkWell),
        ),
      );
      expect(observedAtInkWell.focusNode?.hasFocus, isTrue);
    }

    await openObservedAt(tester);
    await changeDraft();
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await assertDiscarded();

    await openObservedAt(tester);
    await changeDraft();
    await tester.binding.handlePopRoute();
    await assertDiscarded();

    await openObservedAt(tester);
    await changeDraft();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await assertDiscarded();
  });

  testWidgets('Now resets the picker exactly and reseeds the time wheel', (
    tester,
  ) async {
    MeasurementData? savedData;
    when(
      () => mockPersistenceLogic.createMeasurementEntry(
        data: any(named: 'data'),
        comment: any(named: 'comment'),
        private: any(named: 'private'),
      ),
    ).thenAnswer((invocation) async {
      savedData = capturedData(invocation);
      return measurementSuggestionFixture().first;
    });

    await pumpLauncher(tester);
    await openCapture(tester);
    await tester.enterText(find.byKey(_valueKey), '1');
    await openObservedAt(tester);
    final oldWheelKey = tester
        .widget<DesignSystemTimeWheel>(
          find.byType(DesignSystemTimeWheel),
        )
        .key;

    tester.widget<DesignSystemButton>(find.byKey(_nowKey)).onPressed!.call();
    await tester.pump();
    final reseededWheel = tester.widget<DesignSystemTimeWheel>(
      find.byType(DesignSystemTimeWheel),
    );
    expect(reseededWheel.key, isNot(oldWheelKey));
    expect(reseededWheel.initialDateTime, _fixedNow);

    await tapDone(tester);
    await tester.tap(find.byKey(_saveKey));
    await tester.pump();
    await tester.pump();
    expect(savedData?.dateFrom, _fixedNow);
  });

  testWidgets('local picker edits preserve date-time precision when saved', (
    tester,
  ) async {
    final localNow = DateTime(2024, 3, 15, 14, 30, 15, 16, 17);
    MeasurementData? savedData;
    when(
      () => mockPersistenceLogic.createMeasurementEntry(
        data: any(named: 'data'),
        comment: any(named: 'comment'),
        private: any(named: 'private'),
      ),
    ).thenAnswer((invocation) async {
      savedData = capturedData(invocation);
      return measurementSuggestionFixture().first;
    });

    await pumpLauncher(tester, now: localNow);
    await openCapture(tester);
    await tester.enterText(find.byKey(_valueKey), '3');
    await openObservedAt(tester);
    await setPickerDateTime(
      tester,
      date: DateTime(2025, 1, 2),
      time: DateTime(2000, 1, 1, 18, 45),
    );
    await tapDone(tester);
    await tester.tap(find.byKey(_saveKey));
    await tester.pump();
    await tester.pump();

    final expected = DateTime(2025, 1, 2, 18, 45, 15, 16, 17);
    expect(savedData?.dateFrom, expected);
    expect(savedData?.dateTo, expected);
    expect(savedData?.dateFrom.isUtc, isFalse);
  });

  testWidgets(
    'quick log uses the committed timestamp and comment and closes after save',
    (tester) async {
      final measurements = measurementSuggestionFixture();
      when(
        () => mockJournalDb.getMeasurementsByType(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
          type: measurableWater.id,
        ),
      ).thenAnswer((_) async => measurements);

      MeasurementData? savedData;
      String? savedComment;
      when(
        () => mockPersistenceLogic.createMeasurementEntry(
          data: any(named: 'data'),
          comment: any(named: 'comment'),
          private: any(named: 'private'),
        ),
      ).thenAnswer((invocation) async {
        savedData = capturedData(invocation);
        savedComment =
            invocation.namedArguments[const Symbol('comment')] as String;
        return measurementSuggestionFixture().first;
      });

      await pumpLauncher(tester);
      await openCapture(tester);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Quick log'), findsOneWidget);
      final chip = find.text('500 ml');
      expect(chip, findsOneWidget);

      await tester.enterText(find.byKey(_commentKey), 'Hydration break');
      await openObservedAt(tester);
      await setPickerDateTime(
        tester,
        date: DateTime.utc(2024, 3, 18),
        time: DateTime.utc(2024, 3, 18, 16, 10),
      );
      await tapDone(tester);

      await tester.tap(chip);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));

      expect(savedData?.value, 500);
      expect(
        savedData?.dateFrom,
        DateTime.utc(2024, 3, 18, 16, 10, 15, 16, 17),
      );
      expect(savedComment, 'Hydration break');
      expect(find.byKey(_valueKey), findsNothing);
    },
  );

  testWidgets(
    'keyboard submission ignores invalid input and saves valid input',
    (
      tester,
    ) async {
      await pumpLauncher(tester);
      await openCapture(tester);

      await tester.enterText(find.byKey(_valueKey), '1..2');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      verifyNever(
        () => mockPersistenceLogic.createMeasurementEntry(
          data: any(named: 'data'),
          comment: any(named: 'comment'),
          private: any(named: 'private'),
        ),
      );
      expect(
        tester.widget<DesignSystemButton>(find.byKey(_saveKey)).onPressed,
        isNull,
      );

      await tester.enterText(find.byKey(_valueKey), '-2,5');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      verify(
        () => mockPersistenceLogic.createMeasurementEntry(
          data: any(named: 'data'),
          comment: any(named: 'comment'),
          private: any(named: 'private'),
        ),
      ).called(1);
    },
  );

  testWidgets('null persistence result keeps the editor open with an error', (
    tester,
  ) async {
    when(
      () => mockPersistenceLogic.createMeasurementEntry(
        data: any(named: 'data'),
        comment: any(named: 'comment'),
        private: any(named: 'private'),
      ),
    ).thenAnswer((_) async => null);

    await pumpLauncher(tester);
    await openCapture(tester);
    await tester.enterText(find.byKey(_valueKey), '42');
    await tester.pump();
    tester.widget<DesignSystemButton>(find.byKey(_saveKey)).onPressed!.call();
    await tester.pump();
    await tester.pump();

    expect(find.byKey(_valueKey), findsOneWidget);
    expect(
      find.text('Couldn’t save this measurement. Try again.'),
      findsOneWidget,
    );
    expect(
      tester.widget<DesignSystemButton>(find.byKey(_saveKey)).isLoading,
      isFalse,
    );
  });

  testWidgets('save blocks duplicates and dismissal, then announces failure', (
    tester,
  ) async {
    final completer = Completer<MeasurementEntry?>();
    when(
      () => mockPersistenceLogic.createMeasurementEntry(
        data: any(named: 'data'),
        comment: any(named: 'comment'),
        private: any(named: 'private'),
      ),
    ).thenAnswer((_) => completer.future);

    await pumpLauncher(tester);
    await openCapture(tester);
    await tester.enterText(find.byKey(_valueKey), '42');
    await tester.pump();

    tester.widget<DesignSystemButton>(find.byKey(_saveKey)).onPressed!.call();
    await tester.pump();
    final loadingButton = tester.widget<DesignSystemButton>(
      find.byKey(_saveKey),
    );
    expect(loadingButton.isLoading, isTrue);
    expect(find.byKey(_saveKey), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pump();
    expect(find.byKey(_valueKey), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byKey(_valueKey), findsOneWidget);

    expect(
      tester.widget<DesignSystemButton>(find.byKey(_saveKey)).onPressed,
      isNull,
    );
    verify(
      () => mockPersistenceLogic.createMeasurementEntry(
        data: any(named: 'data'),
        comment: any(named: 'comment'),
        private: any(named: 'private'),
      ),
    ).called(1);

    completer.completeError(StateError('database unavailable'));
    await tester.pump();
    await tester.pump();

    final errorFinder = find.byKey(
      const ValueKey<String>('measurement-save-error'),
    );
    expect(errorFinder, findsOneWidget);
    expect(
      find.text('Couldn’t save this measurement. Try again.'),
      findsOneWidget,
    );
    expect(
      tester.getSemantics(errorFinder).flagsCollection.isLiveRegion,
      isTrue,
    );
    expect(find.byKey(_saveKey), findsOneWidget);
  });

  final pickerLayouts = <({String name, MediaQueryData mediaQueryData})>[
    (
      name: 'compact phone',
      mediaQueryData: const MediaQueryData(
        size: Size(320, 568),
        padding: EdgeInsets.only(bottom: 20),
      ),
    ),
    (
      name: 'landscape',
      mediaQueryData: const MediaQueryData(size: Size(640, 360)),
    ),
    (
      name: 'desktop',
      mediaQueryData: const MediaQueryData(size: Size(1024, 600)),
    ),
    (
      name: 'large-text phone',
      mediaQueryData: const MediaQueryData(
        size: Size(402, 874),
        padding: EdgeInsets.only(bottom: 34),
        textScaler: TextScaler.linear(2),
      ),
    ),
  ];
  for (final layout in pickerLayouts) {
    testWidgets(
      '${layout.name} scrolls final picker content above the footer',
      (tester) async {
        await pumpLauncher(tester, mediaQueryData: layout.mediaQueryData);
        await openCapture(tester);
        await openObservedAt(tester);

        final modalScrollView = find.byType(CustomScrollView);
        expect(modalScrollView, findsOneWidget);
        final scrollable = find.descendant(
          of: modalScrollView,
          matching: find.byType(Scrollable),
        );
        final scrollableState = tester.state<ScrollableState>(
          scrollable.first,
        );
        scrollableState.position.jumpTo(
          scrollableState.position.maxScrollExtent,
        );
        await tester.pump();

        final sectionBottom = tester
            .getBottomLeft(find.byKey(_timeSectionKey))
            .dy;
        final footerTop = tester
            .getTopLeft(find.byType(DesignSystemGlassActionFooter))
            .dy;
        expect(sectionBottom, lessThanOrEqualTo(footerTop));
        expect(find.byKey(_doneKey), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('close dismisses the complete route without saving', (
    tester,
  ) async {
    await pumpLauncher(tester);
    await openCapture(tester);
    await openObservedAt(tester);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));

    expect(find.byKey(_valueKey), findsNothing);
    verifyNever(
      () => mockPersistenceLogic.createMeasurementEntry(
        data: any(named: 'data'),
        comment: any(named: 'comment'),
        private: any(named: 'private'),
      ),
    );
  });
}
