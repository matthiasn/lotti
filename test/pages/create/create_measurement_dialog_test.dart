import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/calendar_pickers/design_system_date_picker_modal.dart';
import 'package:lotti/features/design_system/components/chips/design_system_chip.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/components/time_pickers/design_system_picker_wheels.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
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
    await tester.tap(find.byIcon(LottiIcons.back));
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

  group('the box around a field', () {
    // The hero value input is a centred [IntrinsicWidth] barely wider than the
    // digits it holds, so before the fix the bordered box read as the field
    // while only a ~40px strip in its middle accepted a tap — unmissable with
    // a pointer, unhittable with a thumb.
    /// The bordered box drawn around [fieldKey] — anchored on the box the user
    /// sees, not on the gesture detector this fix adds, so a revert fails these
    /// tests on behaviour rather than on a finder that no longer resolves.
    Finder shellOf(Key fieldKey) => find
        .ancestor(of: find.byKey(fieldKey), matching: find.byType(DecoratedBox))
        .first;

    FocusNode focusNodeOf(WidgetTester tester, Key fieldKey) =>
        tester.widget<TextField>(find.byKey(fieldKey)).focusNode!;

    /// A point on [fieldKey]'s box that the input itself does not cover, so a
    /// tap there can only be answered by the box.
    Offset deadZone(WidgetTester tester, Key fieldKey, {required bool left}) {
      final shell = tester.getRect(shellOf(fieldKey));
      final input = tester.getRect(find.byKey(fieldKey));
      final point = Offset(
        left ? shell.left + 8 : shell.right - 8,
        shell.center.dy,
      );
      expect(
        shell.contains(point),
        isTrue,
        reason: 'the sample point must sit on the box',
      );
      expect(
        input.contains(point),
        isFalse,
        reason: 'the sample point must miss the input, or it proves nothing',
      );
      return point;
    }

    Future<void> blur(WidgetTester tester) async {
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
    }

    testWidgets('a tap left of the digits focuses the value field', (
      tester,
    ) async {
      await pumpLauncher(tester);
      await openCapture(tester);
      await blur(tester);
      expect(focusNodeOf(tester, _valueKey).hasFocus, isFalse);
      expect(tester.testTextInput.isVisible, isFalse);

      await tester.tapAt(deadZone(tester, _valueKey, left: true));
      await tester.pump();

      expect(focusNodeOf(tester, _valueKey).hasFocus, isTrue);
      expect(
        tester.testTextInput.isVisible,
        isTrue,
        reason: 'focusing the field must also raise the soft keyboard',
      );
    });

    testWidgets('a tap right of the unit focuses the value field', (
      tester,
    ) async {
      await pumpLauncher(tester);
      await openCapture(tester);
      await blur(tester);

      await tester.tapAt(deadZone(tester, _valueKey, left: false));
      await tester.pump();

      expect(focusNodeOf(tester, _valueKey).hasFocus, isTrue);
    });

    testWidgets('every point across the value box is a target', (tester) async {
      await pumpLauncher(tester);
      await openCapture(tester);
      final shell = tester.getRect(shellOf(_valueKey));
      final focusNode = focusNodeOf(tester, _valueKey);

      for (final fraction in const [0.02, 0.2, 0.5, 0.8, 0.98]) {
        await blur(tester);
        expect(focusNode.hasFocus, isFalse);

        await tester.tapAt(
          Offset(shell.left + shell.width * fraction, shell.center.dy),
        );
        await tester.pump();

        expect(
          focusNode.hasFocus,
          isTrue,
          reason: 'tap ${(fraction * 100).round()}% across the box',
        );
      }
    });

    testWidgets('a tap on the digits still places the caret there', (
      tester,
    ) async {
      await pumpLauncher(tester);
      await openCapture(tester);
      await tester.enterText(find.byKey(_valueKey), '250');
      await tester.pump();
      final controller = tester
          .widget<TextField>(find.byKey(_valueKey))
          .controller!;
      final input = tester.getRect(find.byKey(_valueKey));

      await blur(tester);
      await tester.tapAt(Offset(input.left + 2, input.center.dy));
      await tester.pump();

      expect(
        controller.selection.baseOffset,
        0,
        reason: 'the box must not swallow taps meant for the input',
      );

      await tester.tapAt(Offset(input.right - 2, input.center.dy));
      await tester.pump();

      expect(controller.selection.baseOffset, '250'.length);
    });

    testWidgets(
      'a dead-zone tap on a focused field restores the keyboard and keeps '
      'the caret',
      (tester) async {
        await pumpLauncher(tester);
        await openCapture(tester);
        await tester.enterText(find.byKey(_valueKey), '250');
        await tester.pump();
        // A correction mid-number, the caret parked between the 2 and the 5.
        final controller =
            tester.widget<TextField>(find.byKey(_valueKey)).controller!
              ..selection = const TextSelection.collapsed(offset: 1);
        await tester.pump();

        // The user swipes the keyboard away; focus stays on the field.
        tester.testTextInput.hide();
        expect(focusNodeOf(tester, _valueKey).hasFocus, isTrue);
        expect(tester.testTextInput.isVisible, isFalse);

        await tester.tapAt(deadZone(tester, _valueKey, left: true));
        await tester.pump();

        expect(tester.testTextInput.isVisible, isTrue);
        expect(controller.selection, const TextSelection.collapsed(offset: 1));
        expect(controller.text, '250');
      },
    );

    testWidgets('a tap beside the comment focuses the comment field', (
      tester,
    ) async {
      await pumpLauncher(tester);
      await openCapture(tester);
      await blur(tester);

      await tester.tapAt(deadZone(tester, _commentKey, left: true));
      await tester.pump();

      expect(focusNodeOf(tester, _commentKey).hasFocus, isTrue);
      expect(focusNodeOf(tester, _valueKey).hasFocus, isFalse);
    });

    testWidgets('the box points like a text field and clears 48dp', (
      tester,
    ) async {
      await pumpLauncher(tester);
      await openCapture(tester);

      final shell = tester.getRect(shellOf(_valueKey));
      final input = tester.getRect(find.byKey(_valueKey));
      expect(
        input.width,
        lessThan(shell.width / 4),
        reason: 'the digits alone can never be the target',
      );
      expect(shell.height, greaterThanOrEqualTo(48));

      final region = tester.widget<MouseRegion>(
        find
            .ancestor(
              of: shellOf(_valueKey),
              matching: find.byType(MouseRegion),
            )
            .first,
      );
      expect(region.cursor, SystemMouseCursors.text);
    });

    testWidgets('the box ramps its border under the pointer', (tester) async {
      await pumpLauncher(tester);
      await openCapture(tester);
      await blur(tester);

      final tokens = tester.element(find.byKey(_valueKey)).designTokens;
      Color borderColor() {
        final box = tester.widget<DecoratedBox>(shellOf(_valueKey));
        return ((box.decoration as BoxDecoration).border! as Border).top.color;
      }

      expect(borderColor(), tokens.colors.decorative.level01);

      final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await pointer.addPointer(location: Offset.zero);
      addTearDown(pointer.removePointer);
      await pointer.moveTo(tester.getCenter(shellOf(_valueKey)));
      await tester.pump();

      expect(borderColor(), tokens.colors.text.mediumEmphasis);

      await pointer.moveTo(Offset.zero);
      await tester.pump();

      expect(borderColor(), tokens.colors.decorative.level01);
    });

    testWidgets('neither box adds an unlabelled node to the semantics tree', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpLauncher(tester);
      await openCapture(tester);

      // Scoped to the two boxes rather than the whole tree: the nearest
      // semantics node enclosing a box must never be a bare tap node the box
      // introduced, and an unlabelled tappable somewhere else on screen is a
      // different bug than this one.
      final offenders = <SemanticsNode>[];
      for (final key in const [_valueKey, _commentKey]) {
        final node = tester.getSemantics(shellOf(key));
        if (node.getSemanticsData().hasAction(SemanticsAction.tap) &&
            node.label.isEmpty &&
            node.tooltip.isEmpty &&
            node.hint.isEmpty) {
          offenders.add(node);
        }
      }

      handle.dispose();
      expect(
        offenders,
        isEmpty,
        reason: 'the input already exposes its own label and focus action',
      );
    });

    /// Runs [body] as though the app were on macOS, where a tap outside a text
    /// field drops its focus and `selectAllOnFocus` defaults to true. Reset
    /// inside the body: a tearDown runs after the binding's debug-variable
    /// invariant check and would fail the whole file.
    Future<void> onDesktop(Future<void> Function() body) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        await body();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    }

    testWidgets('pressing on the box is not a tap outside the field', (
      tester,
    ) async {
      await onDesktop(() async {
        await pumpLauncher(tester);
        await openCapture(tester);
        await tester.enterText(find.byKey(_valueKey), '250');
        await tester.pump();

        // Focus is dropped on pointer *down*, so the press has to be held to
        // observe it — by pointer-up the box would have taken focus back and
        // hidden the churn.
        final press = await tester.startGesture(
          deadZone(tester, _valueKey, left: true),
        );
        await tester.pump();

        expect(
          focusNodeOf(tester, _valueKey).hasFocus,
          isTrue,
          reason: 'the box belongs to the field, so focus never leaves it',
        );

        await press.up();
        await tester.pump();
      });
    });

    testWidgets('a tap on the box does not select the whole value', (
      tester,
    ) async {
      await onDesktop(() async {
        await pumpLauncher(tester);
        await openCapture(tester);
        await tester.enterText(find.byKey(_valueKey), '250');
        await tester.pump();
        final controller = tester
            .widget<TextField>(find.byKey(_valueKey))
            .controller!;
        await blur(tester);

        await tester.tapAt(deadZone(tester, _valueKey, left: true));
        await tester.pump();

        // A field gaining focus from *outside* itself selects all its text
        // where selectAllOnFocus defaults to true. A tap two pixels further
        // right merely puts a caret in, so this one must too.
        expect(focusNodeOf(tester, _valueKey).hasFocus, isTrue);
        expect(
          controller.selection.isCollapsed,
          isTrue,
          reason: 'selection was ${controller.selection}',
        );
        expect(controller.selection.baseOffset, '250'.length);
      });
    });
  });

  testWidgets('close dismisses the complete route without saving', (
    tester,
  ) async {
    await pumpLauncher(tester);
    await openCapture(tester);
    await openObservedAt(tester);

    await tester.tap(find.byIcon(LottiIcons.close));
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

  group('choice measurable', () {
    const choiceFieldKey = Key('measurement_choice_field');
    Finder chip(MeasurableChoice choice) =>
        find.byKey(ValueKey('measurement-choice-${choice.id}'));
    bool chipSelected(WidgetTester tester, MeasurableChoice choice) =>
        tester.widget<DesignSystemChip>(chip(choice)).selected;

    Future<void> openChoiceCapture(WidgetTester tester) async {
      await tester.tap(find.byKey(_openKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      expect(find.byKey(choiceFieldKey), findsOneWidget);
    }

    testWidgets(
      'offers one chip per active choice instead of a number field, with '
      'Save held until a choice is picked',
      (tester) async {
        await pumpLauncher(tester, dataType: measurableHydration);
        await openChoiceCapture(tester);

        expect(find.byKey(_valueKey), findsNothing);
        expect(find.text('Quick log'), findsNothing);
        expect(find.text('Pick one'), findsOneWidget);
        expect(chip(hydrationClear), findsOneWidget);
        expect(chip(hydrationPale), findsOneWidget);
        expect(chip(hydrationDark), findsOneWidget);
        // Archived choices are not on offer.
        expect(chip(hydrationBrown), findsNothing);
        expect(find.text('Brown'), findsNothing);
        expect(
          tester.widget<DesignSystemChip>(chip(hydrationClear)).semanticsLabel,
          'Select Clear',
        );

        final save = tester.widget<DesignSystemButton>(find.byKey(_saveKey));
        expect(save.onPressed, isNull);
        for (final choice in [hydrationClear, hydrationPale, hydrationDark]) {
          expect(chipSelected(tester, choice), isFalse);
        }
      },
    );

    testWidgets('picking a chip selects it exclusively and arms Save', (
      tester,
    ) async {
      await pumpLauncher(tester, dataType: measurableHydration);
      await openChoiceCapture(tester);

      await tester.tap(chip(hydrationPale));
      await tester.pump();
      expect(chipSelected(tester, hydrationPale), isTrue);
      expect(chipSelected(tester, hydrationClear), isFalse);
      expect(
        tester.widget<DesignSystemButton>(find.byKey(_saveKey)).onPressed,
        isNotNull,
      );

      await tester.tap(chip(hydrationDark));
      await tester.pump();
      expect(chipSelected(tester, hydrationDark), isTrue);
      expect(chipSelected(tester, hydrationPale), isFalse);
    });

    testWidgets(
      'Save persists the choice as one occurrence at the observed time, '
      'with the comment, and closes the sheet',
      (tester) async {
        MeasurementData? saved;
        String? savedComment;
        bool? savedPrivate;
        when(
          () => mockPersistenceLogic.createMeasurementEntry(
            data: any(named: 'data'),
            comment: any(named: 'comment'),
            private: any(named: 'private'),
          ),
        ).thenAnswer((invocation) async {
          saved = capturedData(invocation);
          savedComment =
              invocation.namedArguments[const Symbol('comment')] as String?;
          savedPrivate =
              invocation.namedArguments[const Symbol('private')] as bool?;
          return testMeasurementHydrationEntry;
        });

        await pumpLauncher(
          tester,
          dataType: measurableHydration.copyWith(private: true),
        );
        await openChoiceCapture(tester);

        await tester.tap(chip(hydrationPale));
        await tester.pump();
        await tester.enterText(find.byKey(_commentKey), 'After the run');
        await tester.pump();

        await tester.tap(find.byKey(_saveKey));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 450));

        expect(saved, isNotNull);
        expect(saved!.dataTypeId, measurableHydration.id);
        expect(saved!.choiceId, hydrationPale.id);
        expect(saved!.value, 1);
        expect(saved!.dateFrom, _fixedNow);
        expect(saved!.dateTo, _fixedNow);
        expect(savedComment, 'After the run');
        expect(savedPrivate, isTrue);
        expect(find.byKey(choiceFieldKey), findsNothing);
      },
    );

    testWidgets('the picked choice survives the observed-at round trip', (
      tester,
    ) async {
      await pumpLauncher(tester, dataType: measurableHydration);
      await openChoiceCapture(tester);

      await tester.tap(chip(hydrationDark));
      await tester.pump();

      await openObservedAt(tester);
      await tapDone(tester);

      expect(chipSelected(tester, hydrationDark), isTrue);
      expect(
        tester.widget<DesignSystemButton>(find.byKey(_saveKey)).onPressed,
        isNotNull,
      );
    });

    testWidgets('chips go inert while the save is in flight', (tester) async {
      final pending = Completer<MeasurementEntry?>();
      when(
        () => mockPersistenceLogic.createMeasurementEntry(
          data: any(named: 'data'),
          comment: any(named: 'comment'),
          private: any(named: 'private'),
        ),
      ).thenAnswer((_) => pending.future);

      await pumpLauncher(tester, dataType: measurableHydration);
      await openChoiceCapture(tester);
      await tester.tap(chip(hydrationClear));
      await tester.pump();
      await tester.tap(find.byKey(_saveKey));
      await tester.pump();

      expect(
        tester.widget<DesignSystemChip>(chip(hydrationPale)).onPressed,
        isNull,
      );
      expect(
        tester.widget<DesignSystemButton>(find.byKey(_saveKey)).isLoading,
        isTrue,
      );

      pending.complete(testMeasurementHydrationEntry);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      expect(find.byKey(choiceFieldKey), findsNothing);
    });
  });
}
