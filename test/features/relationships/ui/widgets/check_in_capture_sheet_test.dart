import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_error_controller.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/captions/ds_tiered_text.dart';
import 'package:lotti/features/design_system/components/chips/design_system_chip.dart';
import 'package:lotti/features/design_system/components/time_pickers/design_system_picker_wheels.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/service/check_in_transcription_service.dart';
import 'package:lotti/features/relationships/state/check_in_duration_suggestions_controller.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_capture_sheet.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_composer_header.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../test_utils/screenshot_harness.dart' show loadAppFonts;
import '../../../../widget_test_utils.dart';
import '../../helpers/check_in_speech_fakes.dart';

/// Serves a fixed duration ranking, so a sheet test names the chip it taps
/// instead of standing up a database.
class _FixedDurationSuggestions extends CheckInDurationSuggestionsController {
  _FixedDurationSuggestions(this.values);
  final List<Duration> values;

  @override
  Future<List<Duration>> build() async => values;
}

void main() {
  // The form is a full scroll: give the scaffold a viewport that holds it,
  // the way the modal page does, so nothing overflows or lands off-screen.
  const tallForm = MediaQueryData(size: Size(1000, 2400));

  final testDate = DateTime(2026, 8, 13, 10, 30);

  late MockRelationshipRepository mockRepository;
  late StubCheckInTranscriptionService stubTranscription;
  late FakeAudioRecorderController recorder;
  final openedSettings = <int>[];

  CheckInEntry createdEntry(CheckInData data) => CheckInEntry(
    meta: Metadata(
      id: 'check-created',
      createdAt: testDate,
      updatedAt: testDate,
      dateFrom: testDate,
      dateTo: testDate,
    ),
    data: data,
  );

  // Pinned fonts: the bar's rects are asserted to the pixel, and the CI
  // bundle shares fonts loaded by any earlier file (test/README.md).
  setUpAll(loadAppFonts);
  setUpAll(registerAllFallbackValues);

  setUp(() {
    // The redesigned form is a full scroll — the field, the chips, More —
    // and the default 800x600 surface leaves its lower half unbuilt, where
    // a tap lands on nothing.
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.single
      ..physicalSize = const Size(1000, 2400)
      ..devicePixelRatio = 1;
    addTearDown(
      TestWidgetsFlutterBinding.instance.platformDispatcher.views.single.reset,
    );
    openedSettings.clear();
    mockRepository = MockRelationshipRepository();
    // The speak flow reads the person to scope the recording to their
    // category; every other flow ignores it.
    when(
      () => mockRepository.getRelationshipById(any()),
    ).thenAnswer((_) async => testRelationship);
    when(
      () => mockRepository.createCheckIn(
        data: any(named: 'data'),
        entryText: any(named: 'entryText'),
        dateFrom: any(named: 'dateFrom'),
        dateTo: any(named: 'dateTo'),
      ),
    ).thenAnswer(
      (invocation) async => createdEntry(
        invocation.namedArguments[#data] as CheckInData,
      ),
    );
    when(
      () => mockRepository.attachEntriesToCheckIn(
        checkInId: any(named: 'checkInId'),
        entryIds: any(named: 'entryIds'),
      ),
    ).thenAnswer((_) async => true);
    stubTranscription = StubCheckInTranscriptionService(
      transcript: 'Spoken.',
    );
    recorder = FakeAudioRecorderController();
  });

  /// The tracked person, filed under [categoryId] — the category whose
  /// profile and speech dictionary the recording will be transcribed with.
  RelationshipEntry relationshipIn(String? categoryId) =>
      testRelationship.copyWith(
        meta: testRelationship.meta.copyWith(categoryId: categoryId),
      );

  /// Opens the folded *More* section so topics, next time and avoid exist.
  Future<void> openMore(WidgetTester tester) async {
    if (find.byKey(const ValueKey('check-in-topics')).evaluate().isNotEmpty) {
      return;
    }
    await tester.ensureVisible(find.byKey(const ValueKey('check-in-more')));
    await tester.tap(find.byKey(const ValueKey('check-in-more')));
    await tester.pumpAndSettle();
  }

  final narrative = find.byKey(const ValueKey('check-in-narrative'));
  final save = find.byKey(const ValueKey('check-in-save'));
  final dictate = find.byKey(const ValueKey('check-in-dictate'));
  final inlineRecorder = find.byKey(const ValueKey('check-in-inline-recorder'));
  final stop = find.byKey(const ValueKey('check-in-recorder-stop'));

  String narrativeText(WidgetTester tester) =>
      tester.widget<TextField>(narrative).controller!.text;

  /// One recording's row under the note.
  Finder take(String audioEntryId) =>
      find.byKey(ValueKey('check-in-take-$audioEntryId'));

  /// Types into the narrative and drops the keyboard again, the way a
  /// phone user does before reaching for the bar — focus slims the bar to
  /// the summary and a short Save, and these tests read the full one.
  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(narrative, text);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
  }

  Future<void> tapSave(WidgetTester tester) async {
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
  }

  /// The harness prefers twelve hours, so a chip reads `2:05 PM`.
  String clock12(DateTime t) {
    final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final minute = t.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${t.hour < 12 ? 'AM' : 'PM'}';
  }

  bool saveEnabled(WidgetTester tester) =>
      tester.widget<DesignSystemButton>(save).onPressed != null;

  String? saveReason(WidgetTester tester) {
    final reason = find.byKey(const ValueKey('check-in-save-reason'));
    if (reason.evaluate().isEmpty) return null;
    return tester.widget<Text>(reason).data;
  }

  /// The form the way the modal hosts it: scrolling, with the pinned bar it
  /// publishes to underneath — the form itself carries no actions.
  Widget withBar(CheckInCaptureForm Function(CheckInFormHandle handle) form) {
    final handle = CheckInFormHandle();
    return SingleChildScrollView(
      child: Column(
        children: [
          form(handle),
          CheckInStickyActions(handle: handle),
        ],
      ),
    );
  }

  List<Override> speechOverrides() => [
    relationshipRepositoryProvider.overrideWithValue(mockRepository),
    audioRecorderControllerProvider.overrideWith(() => recorder),
    checkInTranscriptionServiceProvider.overrideWithValue(stubTranscription),
    checkInSettingsOpenerProvider.overrideWithValue(() async {
      openedSettings.add(1);
      return true;
    }),
  ];

  Widget buildForm({
    bool startSpeaking = false,
    CheckInInteractionType? prefilledInteractionType,
    DateTime? prefilledTime,
    Duration? prefilledDuration,
    List<Override> overrides = const [],
  }) => makeTestableWidgetWithScaffold(
    withBar(
      (handle) => CheckInCaptureForm(
        relationshipId: 'rel-001',
        handle: handle,
        startSpeaking: startSpeaking,
        prefilledInteractionType: prefilledInteractionType,
        prefilledTime: prefilledTime,
        prefilledDuration: prefilledDuration,
      ),
    ),
    mediaQueryData: tallForm,
    overrides: [...speechOverrides(), ...overrides],
  );

  ({CheckInData data, EntryText? entryText, DateTime? dateFrom})
  capturedSave() {
    final captured = verify(
      () => mockRepository.createCheckIn(
        data: captureAny(named: 'data'),
        entryText: captureAny(named: 'entryText'),
        dateFrom: captureAny(named: 'dateFrom'),
        dateTo: any(named: 'dateTo'),
      ),
    ).captured;
    return (
      data: captured[0] as CheckInData,
      entryText: captured[1] as EntryText?,
      dateFrom: captured[2] as DateTime?,
    );
  }

  void verifyNoSave() => verifyNever(
    () => mockRepository.createCheckIn(
      data: any(named: 'data'),
      entryText: any(named: 'entryText'),
      dateFrom: any(named: 'dateFrom'),
      dateTo: any(named: 'dateTo'),
    ),
  );

  final interactionTime = DateTime(2026, 8, 10, 19, 45);

  CheckInEntry existing() => CheckInEntry(
    meta: Metadata(
      id: 'check-1',
      createdAt: testDate,
      updatedAt: testDate,
      dateFrom: interactionTime,
      dateTo: interactionTime,
    ),
    data: const CheckInData(
      relationshipId: 'rel-001',
      interactionType: CheckInInteractionType.call,
      sentiment: CheckInSentiment.good,
      topics: ['travel', 'work'],
      payAttentionTo: 'Job interview',
    ),
    entryText: const EntryText(plainText: 'Planned the trip.'),
  );

  Widget buildEditForm({CheckInEntry? entry}) => makeTestableWidgetWithScaffold(
    withBar(
      (handle) => CheckInCaptureForm(
        relationshipId: 'rel-001',
        initial: entry ?? existing(),
        handle: handle,
      ),
    ),
    mediaQueryData: tallForm,
    overrides: speechOverrides(),
  );

  /// Presses *Dictate* and settles the preflight: the recorder is up.
  Future<void> startDictation(WidgetTester tester) async {
    await tester.ensureVisible(dictate);
    await tester.tap(dictate);
    await tester.pumpAndSettle();
  }

  /// Presses *Stop* on the inline recorder and pumps what follows by hand:
  /// the transcript skeleton breathes for as long as the wait is open, so
  /// nothing "settles" until the words land.
  Future<void> stopRecording(WidgetTester tester) async {
    await tester.tap(stop);
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  group('CheckInFormHandle.reportBarHeight', () {
    test('exposes the measured height and notifies once per change', () {
      final handle = CheckInFormHandle();
      var notified = 0;
      handle.addListener(() => notified++);
      expect(handle.barHeight, isNull);
      handle.reportBarHeight(124);
      expect(handle.barHeight, 124);
      expect(notified, 1);
      handle.reportBarHeight(124);
      expect(notified, 1, reason: 'the same height is not news');
      handle.reportBarHeight(161);
      expect(handle.barHeight, 161);
      expect(notified, 2);
    });
  });

  group('CheckInStickyActions.height', () {
    const tokens = dsTokensDark;
    double line(TextStyle style, double scale) =>
        (style.fontSize! * (style.height ?? 1) * scale).ceilToDouble();
    double button(double scale) =>
        line(tokens.typography.styles.subtitle.subtitle1, scale) +
        tokens.spacing.step4 * 2;
    double reason(double scale) =>
        line(tokens.typography.styles.others.caption, scale) +
        tokens.spacing.step3;
    final inset = tokens.spacing.step5 * 2;

    test('the dialog reserves its one row; the phone adds the reason line', () {
      expect(
        CheckInStickyActions.height(
          tokens,
          TextScaler.noScaling,
          dialog: true,
        ),
        inset + button(1),
      );
      expect(
        CheckInStickyActions.height(
          tokens,
          TextScaler.noScaling,
          dialog: false,
        ),
        inset + button(1) + reason(1),
      );
    });

    test('above the large-text bar both layouts stack the two actions and '
        'carry the reason on its own line', () {
      const scaler = TextScaler.linear(1.6);
      // Stacked bars give the reason two lines.
      final stacked =
          button(1.6) * 2 +
          tokens.spacing.step3 +
          line(tokens.typography.styles.others.caption, 1.6) * 2 +
          tokens.spacing.step3;
      expect(
        CheckInStickyActions.height(tokens, scaler, dialog: true),
        inset + stacked,
      );
      expect(
        CheckInStickyActions.height(tokens, scaler, dialog: false),
        inset + stacked,
      );
    });

    testWidgets("the phone bar puts Cancel's label on the content column — "
        'except when it stacks, where Cancel is centred under Save and keeps '
        'both insets', (tester) async {
      Future<bool> alignsLeading(TextScaler scaler) async {
        final handle = CheckInFormHandle();
        addTearDown(handle.dispose);
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            CheckInStickyActions(handle: handle),
            mediaQueryData: MediaQueryData(
              size: const Size(402, 874),
              textScaler: scaler,
            ),
          ),
        );
        return tester
            .widget<DesignSystemButton>(
              find.byKey(const ValueKey('check-in-cancel')),
            )
            .alignsLabelToLeadingEdge;
      }

      expect(await alignsLeading(TextScaler.noScaling), isTrue);
      expect(await alignsLeading(const TextScaler.linear(1.6)), isFalse);
    });
  });

  group('the composer at rest', () {
    testWidgets('the folded More row says what is set, not the field names', (
      tester,
    ) async {
      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();
      List<String> caption() => tester
          .widget<DsTieredText>(
            find.descendant(
              of: find.byKey(const ValueKey('check-in-more')),
              matching: find.byType(DsTieredText),
            ),
          )
          .tiers;
      expect(caption().first, 'Feeling · topics · next time');

      await openMore(tester);
      await tester.tap(find.byKey(const ValueKey('check-in-sentiment-good')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('check-in-topics')),
        'launch window, krill',
      );
      await tester.pump();
      await tester.ensureVisible(find.byKey(const ValueKey('check-in-more')));
      await tester.tap(find.byKey(const ValueKey('check-in-more')));
      await tester.pumpAndSettle();
      expect(caption().first, 'Good · 2 topics · next time');

      await openMore(tester);
      await tester.enterText(
        find.byKey(const ValueKey('check-in-pay-attention')),
        'the freeze',
      );
      await tester.pump();
      await tester.ensureVisible(find.byKey(const ValueKey('check-in-more')));
      await tester.tap(find.byKey(const ValueKey('check-in-more')));
      await tester.pumpAndSettle();
      expect(caption().first, 'Good · 2 topics · next time noted');
    });

    testWidgets('the narrative leads, the chips follow, More starts folded, '
        'and Save waits for words and says so', (tester) async {
      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(narrative).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const ValueKey('check-in-type'))).dy,
        ),
      );
      expect(find.text('Delightful'), findsNothing);
      expect(saveEnabled(tester), isFalse);
      expect(saveReason(tester), 'Add a few words to save');
      // The reason is the one save-related line while Save is held: the
      // shortcut waits for words, and the held button says why it waits.
      expect(find.text('Ctrl+Enter to save'), findsNothing);
      expect(tester.getSemantics(save).hint, 'Add a few words to save');
      final barBefore = tester.getRect(save);

      await type(tester, 'One line.');
      expect(saveEnabled(tester), isTrue);
      // The reason slot stays laid out, empty: Save does not jump.
      expect(saveReason(tester), '');
      expect(tester.getRect(save), barBefore);
      expect(find.text('2 words · Ctrl+Enter to save'), findsOneWidget);
      expect(tester.getSemantics(save).hint, isEmpty);

      await openMore(tester);
      expect(find.text('Delightful'), findsOne);
      expect(find.text('Optional. Never filled in by the agent.'), findsOne);
    });

    testWidgets('saves type, sentiment, parsed topics and narrative', (
      tester,
    ) async {
      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('check-in-type')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('check-in-type-call')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DesignSystemChip>(
              find.byKey(const ValueKey('check-in-type')),
            )
            .label,
        'Call',
      );

      await openMore(tester);
      await tester.ensureVisible(find.text('Good'));
      await tester.tap(find.text('Good'));
      await tester.pumpAndSettle();

      await type(tester, 'Talked about the interview.');
      await openMore(tester);
      await tester.enterText(
        find.byKey(const ValueKey('check-in-topics')),
        ' job search ,vacation , ',
      );
      await tester.enterText(
        find.byKey(const ValueKey('check-in-pay-attention')),
        'Interview result',
      );
      await tester.enterText(
        find.byKey(const ValueKey('check-in-avoid')),
        'Inheritance',
      );
      await tapSave(tester);

      final saved = capturedSave();
      expect(saved.data.relationshipId, 'rel-001');
      expect(saved.data.interactionType, CheckInInteractionType.call);
      expect(saved.data.sentiment, CheckInSentiment.good);
      expect(saved.data.topics, ['job search', 'vacation']);
      expect(saved.data.payAttentionTo, 'Interview result');
      expect(saved.data.avoid, 'Inheritance');
      expect(saved.entryText?.plainText, 'Talked about the interview.');
    });

    testWidgets('dismissing the type picker keeps the type', (tester) async {
      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('check-in-type')));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DesignSystemChip>(
              find.byKey(const ValueKey('check-in-type')),
            )
            .label,
        'In person',
      );
    });

    testWidgets('sentiment stays unset unless the user picks one, and '
        'tapping the chosen one clears it again', (tester) async {
      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();
      await type(tester, 'Words.');

      await openMore(tester);
      await tester.ensureVisible(find.text('Good'));
      await tester.tap(find.text('Good'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Good'));
      await tester.pumpAndSettle();
      await tapSave(tester);

      final saved = capturedSave();
      expect(saved.data.sentiment, isNull);
      expect(saved.data.interactionType, CheckInInteractionType.inPerson);
      expect(saved.data.topics, isEmpty);
    });

    testWidgets('create mode defaults the interaction time to NOW, to the '
        'minute — not midnight, not createdAt', (tester) async {
      final fixedNow = DateTime(2026, 8, 13, 10, 30);
      await withClock(Clock.fixed(fixedNow), () async {
        await tester.pumpWidget(buildForm());
        await tester.pumpAndSettle();
        // The device's clock format: the test harness prefers twelve hours.
        expect(find.text('Now · 10:30 AM'), findsOneWidget);
        await type(tester, 'Words.');
        await tapSave(tester);
      });

      expect(capturedSave().dateFrom, fixedNow);
    });

    testWidgets('a refused save keeps the sheet open and reports it', (
      tester,
    ) async {
      when(
        () => mockRepository.createCheckIn(
          data: any(named: 'data'),
          entryText: any(named: 'entryText'),
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
        ),
      ).thenAnswer((_) async => null);

      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();
      await type(tester, 'Words.');
      await tapSave(tester);

      expect(
        find.text('Could not save the check-in. Please try again.'),
        findsOneWidget,
      );
      // Still editable, and Save is armed again — a retry does not need the
      // sheet reopened.
      expect(narrativeText(tester), 'Words.');
      expect(saveEnabled(tester), isTrue);
    });

    testWidgets('a save that throws reports the failure too', (tester) async {
      when(
        () => mockRepository.createCheckIn(
          data: any(named: 'data'),
          entryText: any(named: 'entryText'),
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
        ),
      ).thenThrow(Exception('db gone'));

      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();
      await type(tester, 'Words.');
      await tapSave(tester);

      expect(
        find.text('Could not save the check-in. Please try again.'),
        findsOneWidget,
      );
      expect(saveEnabled(tester), isTrue);
    });

    testWidgets('Cancel with words in the field asks first, and Discard '
        'leaves without saving', (tester) async {
      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();

      await type(tester, 'Typed but discarded');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(
        find.text('Discard this check-in? Nothing has been saved.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      verifyNoSave();
    });

    testWidgets('Cancel on an untouched composer leaves without a question', (
      tester,
    ) async {
      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Discard this check-in?'), findsNothing);
      verifyNoSave();
    });

    testWidgets('the save shortcut saves once there are words, and not '
        'before', (tester) async {
      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();
      await tester.tap(narrative);
      await tester.pump();

      Future<void> press() async {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();
      }

      await press();
      verifyNoSave();

      await type(tester, 'Words.');
      await tester.tap(narrative);
      await tester.pump();
      await press();
      expect(capturedSave().entryText?.plainText, 'Words.');
    });

    testWidgets('a prefilled post-call check-in says where the chips came '
        'from', (tester) async {
      await tester.pumpWidget(
        buildForm(
          prefilledInteractionType: CheckInInteractionType.call,
          prefilledTime: DateTime(2026, 8, 13, 12, 33),
          prefilledDuration: const Duration(minutes: 11),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'From the call you placed from this page. Everything is editable.',
        ),
        findsOneWidget,
      );
      expect(find.text('11 min'), findsOneWidget);
      expect(find.text('Call'), findsOneWidget);
    });
  });

  group('edit mode', () {
    setUp(() {
      when(
        () => mockRepository.updateCheckIn(any()),
      ).thenAnswer((_) async => true);
    });

    testWidgets('prefills every field and preserves the interaction time on '
        'save', (tester) async {
      await tester.pumpWidget(buildEditForm());
      await tester.pumpAndSettle();

      expect(narrativeText(tester), 'Planned the trip.');
      expect(find.widgetWithText(TextField, 'travel, work'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Job interview'), findsOneWidget);
      expect(find.textContaining('10 Aug'), findsOneWidget);
      expect(saveEnabled(tester), isTrue);

      await openMore(tester);
      await tester.ensureVisible(find.text('Neutral'));
      await tester.tap(find.text('Neutral'));
      await tester.pumpAndSettle();
      await tapSave(tester);

      final updated =
          verify(
                () => mockRepository.updateCheckIn(captureAny()),
              ).captured.single
              as CheckInEntry;
      expect(updated.id, 'check-1');
      expect(updated.data.sentiment, CheckInSentiment.neutral);
      expect(updated.data.topics, ['travel', 'work']);
      // Untouched date: the original interaction time survives, to the
      // minute.
      expect(updated.meta.dateFrom, interactionTime);
      expect(updated.meta.dateTo, interactionTime);
      expect(updated.entryText?.plainText, 'Planned the trip.');
    });

    testWidgets('clearing the narrative holds Save again', (tester) async {
      await tester.pumpWidget(buildEditForm());
      await tester.pumpAndSettle();
      await type(tester, '   ');
      expect(saveEnabled(tester), isFalse);
      expect(saveReason(tester), 'Add a few words to save');
    });

    testWidgets('the time picker moves the time of day and keeps the day', (
      tester,
    ) async {
      await tester.pumpWidget(buildEditForm());
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.textContaining('10 Aug'));
      await tester.tap(find.textContaining('10 Aug'));
      await tester.pumpAndSettle();
      // Confirm the day as it is; the time picker follows.
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      final wheel = tester.widget<DesignSystemTimeWheel>(
        find.byKey(const ValueKey('check-in-time-picker')),
      );
      expect(wheel.initialDateTime, interactionTime);
      expect(wheel.semanticsLabel, 'Started');
      expect(
        wheel.use24hFormat,
        isFalse,
        reason: 'follows the same device preference as the journal editor',
      );
      wheel.onDateTimeChanged(DateTime(2026, 8, 10, 8, 15));
      await tester.tap(find.byKey(const ValueKey('check-in-time-done')));
      await tester.pumpAndSettle();

      expect(find.textContaining('8:15 AM'), findsOneWidget);
      await tapSave(tester);

      final updated =
          verify(
                () => mockRepository.updateCheckIn(captureAny()),
              ).captured.single
              as CheckInEntry;
      expect(updated.meta.dateFrom, DateTime(2026, 8, 10, 8, 15));
    });

    testWidgets("a time later than now on today's date is clamped to the "
        'current minute — a check-in cannot start in the future', (
      tester,
    ) async {
      final fixedNow = DateTime(2026, 8, 13, 10, 30);
      await withClock(Clock.fixed(fixedNow), () async {
        await tester.pumpWidget(buildForm());
        await tester.pumpAndSettle();
        expect(find.textContaining('10:30'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('check-in-started')));
        await tester.pumpAndSettle();
        // Keep today; then ask for a quarter to midnight.
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();
        tester
            .widget<DesignSystemTimeWheel>(
              find.byKey(const ValueKey('check-in-time-picker')),
            )
            .onDateTimeChanged(DateTime(2026, 8, 13, 23, 45));
        await tester.tap(find.byKey(const ValueKey('check-in-time-done')));
        await tester.pumpAndSettle();

        expect(find.textContaining('23:45'), findsNothing);
        expect(find.textContaining('10:30'), findsOneWidget);

        await type(tester, 'Words.');
        await tapSave(tester);
      });

      expect(capturedSave().dateFrom, fixedNow);
    });

    testWidgets('tapping the Started chip opens the date picker', (
      tester,
    ) async {
      await tester.pumpWidget(buildEditForm());
      await tester.pumpAndSettle();

      expect(find.text('Started'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('check-in-started')));
      await tester.pumpAndSettle();
      expect(find.text('Started'), findsOneWidget);
    });

    testWidgets('delete asks for confirmation, then deletes and closes', (
      tester,
    ) async {
      when(
        () => mockRepository.deleteCheckIn('check-1'),
      ).thenAnswer((_) async => true);

      await tester.pumpWidget(buildEditForm());
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byIcon(LottiIcons.delete));
      await tester.tap(find.byIcon(LottiIcons.delete));
      await tester.pumpAndSettle();

      expect(
        find.text('Delete this check-in? This cannot be undone.'),
        findsOneWidget,
      );
      verifyNever(() => mockRepository.deleteCheckIn(any()));

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      verify(() => mockRepository.deleteCheckIn('check-1')).called(1);
    });

    testWidgets('create mode carries no delete affordance', (tester) async {
      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();

      expect(find.byIcon(LottiIcons.delete), findsNothing);
    });

    testWidgets('a refused delete, or one that throws, keeps the check-in '
        'and reports it', (tester) async {
      when(
        () => mockRepository.deleteCheckIn('check-1'),
      ).thenAnswer((_) async => false);

      await tester.pumpWidget(buildEditForm());
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(LottiIcons.delete));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(
        find.text('Could not delete the check-in. Please try again.'),
        findsOneWidget,
      );
      expect(narrativeText(tester), 'Planned the trip.');

      when(
        () => mockRepository.deleteCheckIn('check-1'),
      ).thenThrow(Exception('db gone'));
      await tester.pumpWidget(buildEditForm());
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(LottiIcons.delete));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(
        find.text('Could not delete the check-in. Please try again.'),
        findsOneWidget,
      );
      expect(narrativeText(tester), 'Planned the trip.');
    });

    testWidgets('a refused update reports it and keeps the edits', (
      tester,
    ) async {
      when(
        () => mockRepository.updateCheckIn(any()),
      ).thenAnswer((_) async => false);

      await tester.pumpWidget(buildEditForm());
      await tester.pumpAndSettle();
      await type(tester, 'Edited narrative');
      await tapSave(tester);

      expect(
        find.text('Could not save the check-in. Please try again.'),
        findsOneWidget,
      );
      expect(narrativeText(tester), 'Edited narrative');
    });

    testWidgets('the date picker moves the day and keeps the time of day', (
      tester,
    ) async {
      await tester.pumpWidget(buildEditForm());
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('10 Aug'));
      await tester.pumpAndSettle();

      // Pick the 6th in the open month grid, then confirm; the time picker
      // follows, and Done keeps the time it opened on.
      await tester.tap(find.text('6'));
      await tester.pump();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('check-in-time-done')));
      await tester.pumpAndSettle();

      expect(find.textContaining('6 Aug'), findsOneWidget);
      await tapSave(tester);

      final updated =
          verify(
                () => mockRepository.updateCheckIn(captureAny()),
              ).captured.single
              as CheckInEntry;
      // The day moved; 19:45 survived: the time picker was confirmed as is.
      expect(updated.meta.dateFrom, DateTime(2026, 8, 6, 19, 45));
      expect(updated.meta.dateTo, DateTime(2026, 8, 6, 19, 45));
    });

    // A saved check-in is added to from its timeline, where a recording
    // becomes its entry at once; the edit sheet edits its own fields.
    for (final saved in ['Planned the trip.', '  ']) {
      testWidgets('editing never offers Dictate (saved text: "$saved")', (
        tester,
      ) async {
        final entry = existing();
        await tester.pumpWidget(
          buildEditForm(
            entry: CheckInEntry(
              meta: entry.meta,
              data: entry.data,
              entryText: EntryText(plainText: saved),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(dictate, findsNothing);

        await tester.enterText(narrative, '');
        await tester.pumpAndSettle();
        expect(dictate, findsNothing, reason: 'never flickers under typing');
      });
    }
  });

  group('dictation', () {
    // The bug this guards: with no audio model — or a person filed under no
    // category, which can never pass the automatic-inference gate — the
    // sheet used to record and then sit on "Transcribing…" for the full
    // five-minute timeout before admitting no run was ever started.
    testWidgets('refuses before recording when nothing can transcribe', (
      tester,
    ) async {
      stubTranscription = StubCheckInTranscriptionService(
        canTranscribeResult: false,
      );
      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();
      await startDictation(tester);

      expect(recorder.recordCalls, isEmpty, reason: 'no recording wasted');
      expect(inlineRecorder, findsNothing);
      expect(find.text('No transcription model set up'), findsOneWidget);
      expect(
        find.textContaining('Choose a default inference profile'),
        findsOneWidget,
      );
      // The field is still there to type into, and Save follows the words.
      await type(tester, 'Typed instead.');
      expect(saveEnabled(tester), isTrue);
    });

    testWidgets('Type instead on a failure card puts the card away and the '
        'keyboard in the field', (tester) async {
      stubTranscription = StubCheckInTranscriptionService(
        canTranscribeResult: false,
      );
      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();
      await startDictation(tester);
      final card = find.byKey(const ValueKey('check-in-speech-failure'));
      expect(card, findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('check-in-dismiss-failure')));
      await tester.pumpAndSettle();

      expect(card, findsNothing);
      expect(tester.widget<TextField>(narrative).focusNode!.hasFocus, isTrue);
    });

    testWidgets('a preflight that throws is a failed start, not a hang', (
      tester,
    ) async {
      when(
        () => mockRepository.getRelationshipById('rel-001'),
      ).thenAnswer((_) async => throw StateError('database unavailable'));
      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();
      await startDictation(tester);

      expect(find.text("Recording didn't start"), findsOneWidget);
      expect(inlineRecorder, findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Dictate puts the recorder in the field, linked to the '
        'person and filed under their category, with the chips quiet', (
      tester,
    ) async {
      when(() => mockRepository.getRelationshipById('rel-001')).thenAnswer(
        (_) async => relationshipIn('category-7'),
      );
      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();
      await startDictation(tester);

      expect(inlineRecorder, findsOneWidget);
      expect(narrative, findsNothing);
      expect(recorder.recordCalls, [
        (linkedId: 'rel-001', handledByCaller: true),
      ]);
      expect(recorder.categoryIds, ['category-7']);
      expect(saveEnabled(tester), isFalse);
      expect(saveReason(tester), 'Stop recording to save');
      expect(
        tester
            .widget<DesignSystemChip>(
              find.byKey(const ValueKey('check-in-type')),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('startSpeaking opens the recorder after the first frame '
        'without a tap', (tester) async {
      await tester.pumpWidget(buildForm(startSpeaking: true));
      await tester.pumpAndSettle();
      expect(inlineRecorder, findsOneWidget);
      expect(recorder.recordCalls, hasLength(1));
    });

    testWidgets('a form opened the ordinary way launches nothing on its own', (
      tester,
    ) async {
      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();
      expect(inlineRecorder, findsNothing);
      expect(recorder.recordCalls, isEmpty);
    });

    // The session's reported failure: a transcript that never finished held
    // Save, and the check-in was lost. A recording is the check-in's entry
    // (ADR 0062): Save goes at once, and the words land on the recording.
    testWidgets('Stop → the recording is a take under the note, Save is '
        "released at once, and saving makes it the check-in's entry", (
      tester,
    ) async {
      final gate = Completer<String?>();
      stubTranscription = StubCheckInTranscriptionService(gate: gate);
      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();
      await startDictation(tester);
      recorder.tick(progress: const Duration(seconds: 23));
      await tester.pump();
      await stopRecording(tester);

      expect(take('audio-1'), findsOneWidget);
      expect(
        find.text('0:23 · Transcribing… · Whisper large v3 · via Groq'),
        findsOneWidget,
      );
      expect(
        find.text('You can save now — the words follow.'),
        findsOneWidget,
      );
      expect(saveEnabled(tester), isTrue);
      expect(stubTranscription.transcribeCalls, ['audio-1']);
      expect(
        stubTranscription.transcribePeople,
        ['rel-001'],
        reason: "the words are corrected against this person's names",
      );

      await tapSave(tester);

      expect(capturedSave().entryText?.plainText, '');
      verify(
        () => mockRepository.attachEntriesToCheckIn(
          checkInId: 'check-created',
          entryIds: ['audio-1'],
        ),
      ).called(1);
    });

    testWidgets('words that land show on their take and never in the note', (
      tester,
    ) async {
      final gate = Completer<String?>();
      stubTranscription = StubCheckInTranscriptionService(gate: gate);
      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();
      await type(tester, 'Called on the way home.');
      await startDictation(tester);
      await stopRecording(tester);

      gate.complete('She got the job.');
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Text>(
              find.descendant(
                of: take('audio-1'),
                matching: find.byKey(
                  const ValueKey('check-in-take-transcript'),
                ),
              ),
            )
            .data,
        'She got the job.',
      );
      expect(narrativeText(tester), 'Called on the way home.');
      expect(find.text('Duration'), findsOneWidget);

      await tapSave(tester);
      expect(capturedSave().entryText?.plainText, 'Called on the way home.');
    });

    testWidgets('every take is its own entry, in the order they were made', (
      tester,
    ) async {
      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();
      await startDictation(tester);
      await stopRecording(tester);
      recorder.stopResult = 'audio-2';
      await tester.tap(dictate);
      await tester.pumpAndSettle();
      await stopRecording(tester);

      expect(take('audio-1'), findsOneWidget);
      expect(take('audio-2'), findsOneWidget);
      expect(recorder.recordCalls, hasLength(2));

      await tapSave(tester);
      verify(
        () => mockRepository.attachEntriesToCheckIn(
          checkInId: 'check-created',
          entryIds: ['audio-1', 'audio-2'],
        ),
      ).called(1);
    });

    testWidgets('a check-in that could not be saved attaches nothing', (
      tester,
    ) async {
      when(
        () => mockRepository.createCheckIn(
          data: any(named: 'data'),
          entryText: any(named: 'entryText'),
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
        ),
      ).thenAnswer((_) async => null);
      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();
      await startDictation(tester);
      await stopRecording(tester);

      await tapSave(tester);

      verifyNever(
        () => mockRepository.attachEntriesToCheckIn(
          checkInId: any(named: 'checkInId'),
          entryIds: any(named: 'entryIds'),
        ),
      );
      expect(take('audio-1'), findsOneWidget, reason: 'nothing is lost');
    });

    testWidgets('a discarded recording leaves the narrative alone', (
      tester,
    ) async {
      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();
      await type(tester, 'Typed only.');
      await startDictation(tester);
      await tester.tap(find.byKey(const ValueKey('check-in-recorder-discard')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard').last);
      await tester.pumpAndSettle();

      expect(inlineRecorder, findsNothing);
      expect(narrativeText(tester), 'Typed only.');
      expect(stubTranscription.transcribeCalls, isEmpty);
      expect(saveEnabled(tester), isTrue);
    });

    testWidgets('a denied microphone: the card in the field, Open settings '
        'through the seam, and typing a word hands the field back', (
      tester,
    ) async {
      recorder.recordFailure = AudioRecordingFailure.permissionDenied;
      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();
      await startDictation(tester);

      expect(inlineRecorder, findsNothing);
      expect(find.text('Allow microphone access'), findsOneWidget);
      expect(saveReason(tester), 'Add a few words to save');
      expect(
        recorder.modalVisibleLog,
        [true, false],
        reason: 'the floating indicator is given back on a failed start',
      );

      await tester.tap(find.byKey(const ValueKey('check-in-open-settings')));
      await tester.pump();
      expect(openedSettings, hasLength(1));
      // The field's own Dictate is the retry; the card carries typing and
      // the settings door, like every other card carries two.
      expect(dictate, findsOneWidget);
      expect(find.byKey(const ValueKey('check-in-retry-audio')), findsNothing);
      expect(
        find.byKey(const ValueKey('check-in-type-instead-denied')),
        findsOneWidget,
      );

      // Typing is choosing to type instead: the card goes on its own, and
      // the field's Dictate comes back with it.
      await tester.enterText(narrative, 'Typed it instead');
      await tester.pumpAndSettle();
      expect(find.text('Allow microphone access'), findsNothing);
      expect(dictate, findsOneWidget);
      expect(saveEnabled(tester), isTrue);
    });

    testWidgets('a stop that saves nothing is a recording not saved', (
      tester,
    ) async {
      recorder.stopResult = null;
      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();
      await startDictation(tester);
      await stopRecording(tester);

      expect(find.text("Recording couldn't be saved"), findsOneWidget);
      expect(stubTranscription.transcribeCalls, isEmpty);
    });

    // A take can outlive its sheet — a route change can pop the composer
    // around the discard guard — so reopening and pressing Dictate must
    // attach to it: `record()` would toggle it off, saving the take
    // wordless and never starting a new one.
    testWidgets("this person's recording still running is adopted, not "
        'toggled off', (tester) async {
      recorder = FakeAudioRecorderController(runningFor: 'rel-001');
      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();
      await startDictation(tester);

      expect(inlineRecorder, findsOneWidget);
      expect(recorder.recordCalls, isEmpty);
      expect(recorder.modalVisibleLog, [true]);
      await stopRecording(tester);
      expect(take('audio-1'), findsOneWidget);
      expect(find.text('Spoken.'), findsOneWidget);
    });

    testWidgets("someone else's recording running is refused with the busy "
        'card, and nothing is touched', (tester) async {
      recorder = FakeAudioRecorderController(runningFor: 'task-9');
      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();
      await startDictation(tester);

      expect(inlineRecorder, findsNothing);
      expect(find.text('A recording is already running'), findsOneWidget);
      expect(recorder.recordCalls, isEmpty);
      expect(recorder.stopCalls, 0);
      expect(recorder.modalVisibleLog, isEmpty);
    });

    testWidgets('a route lookup that throws never touches the wait', (
      tester,
    ) async {
      final gate = Completer<String?>();
      stubTranscription = StubCheckInTranscriptionService(
        gate: gate,
        routeThrows: true,
      );
      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();
      await startDictation(tester);
      recorder.tick(progress: const Duration(seconds: 5));
      await tester.pump();
      await stopRecording(tester);
      expect(find.text('0:05 · Transcribing…'), findsOneWidget);
      expect(tester.takeException(), isNull);

      gate.complete('Landed anyway.');
      await tester.pumpAndSettle();
      expect(find.text('Landed anyway.'), findsOneWidget);
    });

    // No profile, no model, or a run that never finished: the take says so
    // and keeps its retry — and the check-in can be saved all the same.
    testWidgets('no transcript: the take says so, Try again asks for the '
        "same recording's words, and Save never waited", (tester) async {
      stubTranscription = StubCheckInTranscriptionService();
      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();
      await startDictation(tester);
      recorder.tick(progress: const Duration(seconds: 23));
      await tester.pump();
      await stopRecording(tester);

      expect(
        find.textContaining('0:23 · Transcript not received'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Your 0:23 recording is saved in the journal'),
        findsOneWidget,
      );
      expect(saveEnabled(tester), isTrue);

      await tester.tap(
        find.byKey(const ValueKey('check-in-retry-transcript')),
      );
      await tester.pumpAndSettle();
      expect(
        stubTranscription.transcribeCalls,
        ['audio-1', 'audio-1'],
        reason: 'the same recording, asked for again',
      );
      expect(recorder.recordCalls, hasLength(1), reason: 'never re-records');
    });

    // The HTTP 503 case. A failed run writes no transcript, so the wait
    // alone cannot tell a provider outage from a slow model, and
    // `runTranscription` reports the failure through its status controllers
    // rather than throwing. The form also observes the error controller so
    // it can display the provider's specific failure detail.
    testWidgets('a reported inference failure ends the wait and names it', (
      tester,
    ) async {
      final gate = Completer<String?>();
      stubTranscription = StubCheckInTranscriptionService(gate: gate);
      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();
      await type(tester, 'Typed only.');
      await startDictation(tester);
      await stopRecording(tester);
      expect(find.textContaining('0:00 · Transcribing…'), findsOneWidget);

      ProviderScope.containerOf(tester.element(find.byType(CheckInCaptureForm)))
          .read(
            inferenceErrorControllerProvider((
              id: 'audio-1',
              aiResponseType: AiResponseType.audioTranscription,
            )).notifier,
          )
          .setError('HTTP 503 · Transcription service unavailable');
      await tester.pumpAndSettle();

      expect(
        find.textContaining('0:00 · Transcript not received'),
        findsOneWidget,
        reason: 'must not run out the five-minute timeout',
      );
      expect(stubTranscription.cancelCount, 1);
      expect(
        find.text('HTTP 503 · Transcription service unavailable'),
        findsOneWidget,
        reason: "the provider's own reason, not a generic failure",
      );
      expect(narrativeText(tester), 'Typed only.');
    });

    // The error is keyed by the newly created audio entry. Automatic
    // inference can fail before the recorder has handed the entry back.
    testWidgets('a failure recorded before the wait opened ends processing', (
      tester,
    ) async {
      final gate = Completer<String?>();
      stubTranscription = StubCheckInTranscriptionService(gate: gate);
      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();

      ProviderScope.containerOf(tester.element(find.byType(CheckInCaptureForm)))
          .read(
            inferenceErrorControllerProvider((
              id: 'audio-1',
              aiResponseType: AiResponseType.audioTranscription,
            )).notifier,
          )
          .setError('cloud request failed while recorder closed');

      await startDictation(tester);
      await stopRecording(tester);

      expect(
        find.textContaining('0:00 · Transcript not received'),
        findsOneWidget,
      );
      expect(stubTranscription.cancelCount, 1);
      expect(
        find.text('cloud request failed while recorder closed'),
        findsOneWidget,
      );
      expect(narrativeText(tester), isEmpty);
    });

    testWidgets('removing a take abandons its wait, leaves it out of the '
        'check-in, and a late transcript lands nowhere', (tester) async {
      final gate = Completer<String?>();
      stubTranscription = StubCheckInTranscriptionService(gate: gate);
      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();
      await startDictation(tester);
      await stopRecording(tester);
      expect(saveEnabled(tester), isTrue);

      await tester.tap(find.byKey(const ValueKey('check-in-take-remove')));
      await tester.pumpAndSettle();

      expect(stubTranscription.cancelCount, 1);
      expect(take('audio-1'), findsNothing);
      expect(
        saveReason(tester),
        'Add a few words to save',
        reason: 'nothing is left to save',
      );
      // The abandoned wait was completed by its own cancel; whatever the
      // provider still sends lands nowhere.
      await tester.pumpAndSettle();
      expect(gate.isCompleted, isTrue);
      expect(take('audio-1'), findsNothing);

      await type(tester, 'Typed instead.');
      await tapSave(tester);
      verifyNever(
        () => mockRepository.attachEntriesToCheckIn(
          checkInId: any(named: 'checkInId'),
          entryIds: any(named: 'entryIds'),
        ),
      );
    });

    testWidgets('the preflight holds Save and says so', (tester) async {
      final preflight = Completer<void>();
      stubTranscription = StubCheckInTranscriptionService(
        preflightGate: preflight,
      );
      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();
      await type(tester, 'Words.');
      await tester.tap(dictate);
      await tester.pump();
      await tester.pump();

      expect(saveEnabled(tester), isFalse);
      expect(saveReason(tester), 'Preparing audio…');
      expect(find.byKey(const ValueKey('check-in-preparing')), findsOneWidget);

      preflight.complete();
      await tester.pumpAndSettle();
      expect(inlineRecorder, findsOneWidget);
    });

    // A dismissed sheet must stop the wait rather than leave it re-reading
    // the database on every write until the timeout expires.
    testWidgets('cancels the wait when the sheet goes away', (tester) async {
      final gate = Completer<String?>();
      stubTranscription = StubCheckInTranscriptionService(gate: gate);
      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();
      await startDictation(tester);
      await stopRecording(tester);
      expect(stubTranscription.cancelCount, 0);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      expect(stubTranscription.cancelCount, 1);
    });

    testWidgets('the route is a courtesy: a transcription with no route '
        'still shows the length and the wait', (tester) async {
      final gate = Completer<String?>();
      stubTranscription = StubCheckInTranscriptionService(
        gate: gate,
        routeResult: null,
      );
      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();
      await startDictation(tester);
      recorder.tick(progress: const Duration(seconds: 5));
      await tester.pump();
      await stopRecording(tester);
      expect(find.text('0:05 · Transcribing…'), findsOneWidget);
      gate.complete('x');
      await tester.pumpAndSettle();
    });
  });

  // Every other test in this file pumps `CheckInCaptureForm` bare, which is
  // why an earlier defect survived: the form was fine, and the modal it
  // lives in was not. These open the real sheet.
  group('inside the real modal', () {
    Future<void> openSheet(
      WidgetTester tester, {
      Size physicalSize = const Size(1206, 2622),
      double devicePixelRatio = 3,
    }) async {
      tester.view
        ..physicalSize = physicalSize
        ..devicePixelRatio = devicePixelRatio;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      when(
        () => mockRepository.getEntriesForCheckIns(any()),
      ).thenAnswer((_) async => const {});
      when(
        () => mockRepository.getCheckInsForRelationship(any()),
      ).thenAnswer((_) async => const []);
      when(
        () => mockRepository.getLinkedTasks(any()),
      ).thenAnswer((_) async => const []);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showCheckInCaptureSheet(
                context: context,
                relationshipId: 'rel-001',
              ),
              child: const Text('Open'),
            ),
          ),
          // The window the modal picks its shape by — the same size the
          // view was given, or the phone default would hide the dialog.
          mediaQueryData: MediaQueryData(
            size: physicalSize / devicePixelRatio,
          ),
          overrides: speechOverrides(),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    }

    setUp(() async {
      await setUpTestGetIt();
    });

    tearDown(tearDownTestGetIt);

    testWidgets('opens straight onto the composer under its own header — '
        'no choice sheet first', (tester) async {
      await openSheet(tester);
      expect(find.byType(CheckInComposerHeader), findsOneWidget);
      expect(find.text('Log check-in'), findsOneWidget);
      // The status tiers its wording by width; the wide test font keeps
      // only the name.
      expect(find.textContaining('Anna'), findsOneWidget);
      expect(narrative, findsOneWidget);
      expect(dictate, findsOneWidget);
    });

    // The design pins Save: it lives in the modal's sticky action bar,
    // reachable before any scrolling — and an earlier bug, a form capping
    // itself at 90% of the screen so the action row sat below the fold
    // with no way to reach it, cannot come back through this path.
    testWidgets('Save is pinned, reachable without scrolling, and says why '
        'it waits', (tester) async {
      await openSheet(tester);
      final viewportBottom =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      expect(save, findsOneWidget);
      expect(
        tester.getBottomLeft(save).dy,
        lessThanOrEqualTo(viewportBottom),
        reason: 'the pinned bar sits inside the viewport from the start',
      );
      expect(find.text('Add a few words to save'), findsOneWidget);

      await type(tester, 'Words.');
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(capturedSave().entryText?.plainText, 'Words.');
      expect(find.byType(CheckInCaptureForm), findsNothing);
    });

    testWidgets('the header follows the recorder', (tester) async {
      await openSheet(tester);
      await startDictation(tester);
      expect(find.text('Recording'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('check-in-recorder-pause')));
      await tester.pumpAndSettle();
      expect(find.text('Paused'), findsOneWidget);
    });

    testWidgets("Cancel, and the header's close, dismiss an untouched "
        'composer without saving or asking', (tester) async {
      await openSheet(tester);
      // On the phone Cancel's label sits on the content column.
      expect(
        tester
            .widget<DesignSystemButton>(
              find.byKey(const ValueKey('check-in-cancel')),
            )
            .alignsLabelToLeadingEdge,
        isTrue,
      );
      await tester.tap(find.byKey(const ValueKey('check-in-cancel')));
      await tester.pumpAndSettle();
      expect(find.byType(CheckInCaptureForm), findsNothing);

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('check-in-close')));
      await tester.pumpAndSettle();
      expect(find.byType(CheckInCaptureForm), findsNothing);
      verifyNoSave();
    });

    testWidgets('a draft guards every way out: the close asks, keeping the '
        'draft on Keep and leaving on Discard; a recording names itself', (
      tester,
    ) async {
      await openSheet(tester);
      await type(tester, 'Half a thought');
      await tester.tap(find.byKey(const ValueKey('check-in-close')));
      await tester.pumpAndSettle();
      expect(
        find.text('Discard this check-in? Nothing has been saved.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      expect(find.byType(CheckInCaptureForm), findsOneWidget);
      expect(narrativeText(tester), 'Half a thought');

      await startDictation(tester);
      await tester.tap(find.byKey(const ValueKey('check-in-close')));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Discard this check-in and the recording? The recording will be '
          'deleted.',
        ),
        findsOneWidget,
      );
      // The dialog's confirm, not the recorder's own Discard beneath it.
      await tester.tap(find.text('Discard').last);
      await tester.pumpAndSettle();
      expect(find.byType(CheckInCaptureForm), findsNothing);
      // Discard discards: the take is cancelled, never stopped and saved.
      expect(recorder.cancelCalls, 1);
      expect(recorder.stopCalls, 0);
      verifyNoSave();
    });

    testWidgets('with a recording already in the journal, the question says '
        'it stays', (tester) async {
      // No transcript comes back, so the take is saved and waiting.
      stubTranscription = StubCheckInTranscriptionService();
      await openSheet(tester);
      await startDictation(tester);
      recorder.tick(progress: const Duration(seconds: 23));
      await tester.pump();
      await stopRecording(tester);
      expect(find.text('Transcript not received'), findsOneWidget);
      expect(take('audio-1'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('check-in-close')));
      await tester.pumpAndSettle();
      expect(
        find.text('Discard this check-in? The recording stays in the journal.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Discard').last);
      await tester.pumpAndSettle();
      expect(find.byType(CheckInCaptureForm), findsNothing);
      expect(recorder.cancelCalls, 0, reason: 'nothing left to cancel');
      verifyNoSave();
    });

    testWidgets('the desktop dialog focuses the field at once; the phone '
        'sheet waits for the first tap', (tester) async {
      await openSheet(tester);
      expect(
        tester.widget<TextField>(narrative).focusNode!.hasFocus,
        isFalse,
        reason: 'a phone would raise its keyboard over the sheet',
      );
      await tester.tap(find.byKey(const ValueKey('check-in-close')));
      await tester.pumpAndSettle();

      await openSheet(
        tester,
        physicalSize: const Size(2880, 1800),
        devicePixelRatio: 2,
      );
      expect(
        tester.widget<TextField>(narrative).focusNode!.hasFocus,
        isTrue,
        reason: 'open → type → Ctrl+Enter, with no dead first keystroke',
      );
    });

    testWidgets('the back gesture is guarded the same way', (tester) async {
      await openSheet(tester);
      await type(tester, 'Half a thought');
      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      await navigator.maybePop();
      await tester.pumpAndSettle();
      expect(
        find.text('Discard this check-in? Nothing has been saved.'),
        findsOneWidget,
      );
      expect(find.byType(CheckInCaptureForm), findsOneWidget);
    });

    testWidgets('a changed chip alone is a draft: the type picked, the '
        'close asks', (tester) async {
      await openSheet(tester);
      await tester.tap(find.byKey(const ValueKey('check-in-type')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('check-in-type-call')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DesignSystemChip>(
              find.byKey(const ValueKey('check-in-type')),
            )
            .label,
        'Call',
      );

      await tester.tap(find.byKey(const ValueKey('check-in-close')));
      await tester.pumpAndSettle();
      expect(
        find.text('Discard this check-in? Nothing has been saved.'),
        findsOneWidget,
      );
      expect(find.byType(CheckInCaptureForm), findsOneWidget);
    });

    testWidgets('a detail edited under More re-arms the back gesture on its '
        'own', (tester) async {
      await openSheet(tester);
      final more = find.byKey(const ValueKey('check-in-more'));
      expect(more, findsOneWidget, reason: 'More row built');
      // The pinned bar overlays the sheet's scroll, and under the wide test
      // font it stacks Cancel and Save — taller than predicted. The form
      // learns the measured height and reserves the slack, so scrolled to
      // the end the fold row clears the bar and takes the tap.
      await tester.dragFrom(tester.getCenter(narrative), const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(more).bottom,
        lessThanOrEqualTo(
          tester.getRect(find.byType(CheckInStickyActions)).top,
        ),
      );
      await tester.tap(more);
      await tester.pumpAndSettle();
      final topics = find.byKey(const ValueKey('check-in-topics'));
      expect(topics, findsOneWidget, reason: 'More unfolded');
      await tester.ensureVisible(topics);
      await tester.pumpAndSettle();
      await tester.enterText(topics, 'krill');
      await tester.pumpAndSettle();

      // Nothing else changed, so only the detail field's own listener can
      // have told the pop guard.
      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      await navigator.maybePop();
      await tester.pumpAndSettle();
      expect(
        find.text('Discard this check-in? Nothing has been saved.'),
        findsOneWidget,
      );
      expect(find.byType(CheckInCaptureForm), findsOneWidget);
    });

    // The shape that caused it: the form adding a second scroll view inside
    // the page's own. The inner one wins the drag, so the page can never be
    // scrolled to whatever the form put below it.
    testWidgets('the form adds no scroll view of its own', (tester) async {
      await openSheet(tester);
      expect(
        find.descendant(
          of: find.byType(CheckInCaptureForm),
          matching: find.byType(SingleChildScrollView),
        ),
        findsNothing,
      );
    });

    testWidgets('discarded mid-recording, the sheet cancels the take and '
        'gives the floating indicator back', (tester) async {
      await openSheet(tester);
      await startDictation(tester);
      expect(recorder.modalVisibleLog, [true]);

      await tester.tap(find.byKey(const ValueKey('check-in-close')));
      await tester.pumpAndSettle();
      // A recording is a draft: the guard asks first.
      await tester.tap(find.text('Discard').last);
      await tester.pumpAndSettle();

      expect(recorder.modalVisibleLog, [true, false]);
      expect(recorder.stopCalls, 0);
      expect(recorder.cancelCalls, 1);
    });

    // The sheet removes the keyboard inset from what the pinned bar can
    // see, so the field's focus — which on a phone is the keyboard — is
    // what slims the bar.
    testWidgets('with the keyboard up the bar slims to the summary and a '
        'short Save; the summary drops the keyboard', (tester) async {
      // Pinned: "Now" is the current minute, and a real clock can tick
      // over between opening the sheet and reading the chip.
      final now = DateTime(2026, 8, 13, 10, 30);
      await withClock(Clock.fixed(now), () async {
        await openSheet(tester);
        final summary = find.byKey(const ValueKey('check-in-context-summary'));
        expect(summary, findsNothing);
        expect(find.text('Save check-in'), findsOneWidget);

        await tester.tap(narrative);
        await tester.pumpAndSettle();

        expect(summary, findsOneWidget);
        expect(
          tester.widget<DesignSystemChip>(summary).label,
          'In person · Now · ${clock12(clock.now())} · No duration',
        );
        expect(find.text('Save'), findsOneWidget);
        expect(find.text('Save check-in'), findsNothing);
        expect(
          tester.widget<TextField>(narrative).focusNode!.hasFocus,
          isTrue,
        );

        await tester.tap(summary);
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(narrative).focusNode!.hasFocus,
          isFalse,
        );
        expect(summary, findsNothing);
        expect(find.text('Save check-in'), findsOneWidget);
      });
    });

    testWidgets('on a desktop-wide window the footer puts the reason on the '
        'leading edge and Cancel beside Save', (tester) async {
      await openSheet(
        tester,
        physicalSize: const Size(2880, 1800),
        devicePixelRatio: 2,
      );
      final reason = find.byKey(const ValueKey('check-in-save-reason'));
      final cancel = find.byKey(const ValueKey('check-in-cancel'));
      expect(reason, findsOneWidget);
      // In the dialog Cancel trails beside Save, an ordinary button.
      expect(
        tester.widget<DesignSystemButton>(cancel).alignsLabelToLeadingEdge,
        isFalse,
      );
      // And the empty field rests two lines tall beside a working keyboard.
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('check-in-narrative')))
            .minLines,
        2,
      );
      expect(
        tester.getCenter(reason).dx,
        lessThan(tester.getCenter(cancel).dx),
      );
      expect(
        tester.getCenter(cancel).dx,
        lessThan(tester.getCenter(save).dx),
      );
      expect(
        (tester.getCenter(cancel).dy - tester.getCenter(save).dy).abs(),
        lessThan(1),
        reason: 'one row',
      );
    });
  });

  group('duration', () {
    Widget buildFormWithRanking() => buildForm(
      overrides: [
        checkInDurationSuggestionsControllerProvider.overrideWith(
          () => _FixedDurationSuggestions(const [
            Duration(minutes: 11),
            Duration(minutes: 45),
          ]),
        ),
      ],
    );

    testWidgets('the Duration chip opens the picker, and a pick sets the '
        'length that is then persisted as the end time', (tester) async {
      await tester.pumpWidget(buildFormWithRanking());
      await tester.pumpAndSettle();
      expect(find.text('Duration'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('check-in-duration')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('check-in-duration-pick-45')),
      );
      await tester.pumpAndSettle();

      expect(find.text('45 min'), findsOneWidget);
      expect(find.text('Duration'), findsNothing);

      await type(tester, 'Words.');
      await tapSave(tester);

      final captured = verify(
        () => mockRepository.createCheckIn(
          data: any(named: 'data'),
          entryText: any(named: 'entryText'),
          dateFrom: captureAny(named: 'dateFrom'),
          dateTo: captureAny(named: 'dateTo'),
        ),
      ).captured;
      expect(
        captured[1],
        (captured[0] as DateTime).add(const Duration(minutes: 45)),
      );
    });

    testWidgets('backing out of the picker with Done keeps the length as it '
        'was', (tester) async {
      await tester.pumpWidget(buildFormWithRanking());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('check-in-duration')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.text('Duration'), findsOneWidget);
    });

    testWidgets('a prefilled duration is persisted as the end time, so the '
        'log shows what the post-call offer promised', (tester) async {
      final startedAt = DateTime(2026, 8, 13, 12, 33);
      await tester.pumpWidget(
        buildForm(
          prefilledTime: startedAt,
          prefilledDuration: const Duration(minutes: 11),
        ),
      );
      await tester.pumpAndSettle();
      await type(tester, 'Words.');
      await tapSave(tester);

      final captured = verify(
        () => mockRepository.createCheckIn(
          data: any(named: 'data'),
          entryText: any(named: 'entryText'),
          dateFrom: captureAny(named: 'dateFrom'),
          dateTo: captureAny(named: 'dateTo'),
        ),
      ).captured;
      expect(captured[0], startedAt);
      expect(captured[1], startedAt.add(const Duration(minutes: 11)));
    });

    testWidgets('a check-in with no known duration saves a zero-length one', (
      tester,
    ) async {
      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();
      await type(tester, 'Words.');
      await tapSave(tester);

      final captured = verify(
        () => mockRepository.createCheckIn(
          data: any(named: 'data'),
          entryText: any(named: 'entryText'),
          dateFrom: captureAny(named: 'dateFrom'),
          dateTo: captureAny(named: 'dateTo'),
        ),
      ).captured;
      expect(captured[1], captured[0]);
    });

    testWidgets('editing keeps the existing length when nothing about the '
        'time changes', (tester) async {
      final from = DateTime(2026, 8, 13, 12, 33);
      final entry = CheckInEntry(
        meta: Metadata(
          id: 'check-1',
          createdAt: from,
          updatedAt: from,
          dateFrom: from,
          dateTo: from.add(const Duration(minutes: 35)),
        ),
        data: const CheckInData(
          relationshipId: 'rel-001',
          interactionType: CheckInInteractionType.videoCall,
        ),
        entryText: const EntryText(plainText: 'Kept.'),
      );
      when(
        () => mockRepository.updateCheckIn(any()),
      ).thenAnswer((_) async => true);
      await tester.pumpWidget(buildEditForm(entry: entry));
      await tester.pumpAndSettle();
      expect(find.text('35 min'), findsOneWidget);
      await tapSave(tester);

      final updated =
          verify(
                () => mockRepository.updateCheckIn(captureAny()),
              ).captured.single
              as CheckInEntry;
      expect(updated.meta.dateFrom, from);
      expect(updated.meta.dateTo, from.add(const Duration(minutes: 35)));
    });
  });
}
