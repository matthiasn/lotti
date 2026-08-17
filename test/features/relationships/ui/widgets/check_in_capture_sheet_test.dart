import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_error_controller.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/service/check_in_transcription_service.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_capture_sheet.dart';
import 'package:lotti/features/speech/repository/audio_recorder_repository.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/features/speech/ui/widgets/recording/audio_recording_modal.dart';
import 'package:mocktail/mocktail.dart';
import 'package:record/record.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../widget_test_utils.dart';

/// Stands in for the transcription service: answers the pre-flight probe and
/// hands back a wait the test drives directly.
class _StubTranscriptionService implements CheckInTranscriptionService {
  _StubTranscriptionService({
    required this.canTranscribeResult,
    required this.transcript,
    this.gate,
  });

  final bool canTranscribeResult;
  final String? transcript;
  final Completer<String?>? gate;
  int cancelCount = 0;

  @override
  Future<bool> canTranscribe(String subjectId) async => canTranscribeResult;

  @override
  CheckInTranscriptWait transcribe({
    required String audioEntryId,
    required String subjectId,
    Duration timeout = checkInTranscriptTimeout,
  }) {
    final completer = gate ?? (Completer<String?>()..complete(transcript));
    return CheckInTranscriptWait.forTesting(
      result: completer.future,
      onCancel: () {
        cancelCount++;
        if (!completer.isCompleted) completer.complete(null);
      },
    );
  }
}

/// Holds a fixed recorder state so the sheet can read the per-recording
/// speech-recognition choice the real modal would have left behind.
class _FixedRecorderController extends AudioRecorderController {
  _FixedRecorderController({this.enableSpeechRecognition});

  final bool? enableSpeechRecognition;

  @override
  AudioRecorderState build() => AudioRecorderState(
    status: AudioRecorderStatus.stopped,
    progress: Duration.zero,
    vu: 0,
    dBFS: -160,
    showIndicator: false,
    modalVisible: false,
    enableSpeechRecognition: enableSpeechRecognition,
  );
}

void main() {
  group('mergeCheckInNarrative', () {
    test('uses the transcript when the field is empty', () {
      expect(
        mergeCheckInNarrative(existing: '', transcript: 'She got the job.'),
        'She got the job.',
      );
    });

    test('appends below text the user already typed', () {
      expect(
        mergeCheckInNarrative(
          existing: 'Called on the way home.',
          transcript: 'She got the job.',
        ),
        'Called on the way home.\n\nShe got the job.',
      );
    });

    // A second recording adds to the account; nothing typed is ever lost.
    test('keeps appending across repeated recordings', () {
      final once = mergeCheckInNarrative(
        existing: '',
        transcript: 'First take.',
      );

      expect(
        mergeCheckInNarrative(existing: once, transcript: 'Second take.'),
        'First take.\n\nSecond take.',
      );
    });

    test('leaves the field untouched for a blank transcript', () {
      expect(
        mergeCheckInNarrative(existing: 'Typed.', transcript: '   '),
        'Typed.',
      );
    });

    test('trims both sides before joining', () {
      expect(
        mergeCheckInNarrative(
          existing: '  Typed.  \n',
          transcript: '\n  Spoken.  ',
        ),
        'Typed.\n\nSpoken.',
      );
    });
  });

  final testDate = DateTime(2026, 8, 13, 10, 30);

  late MockRelationshipRepository mockRepository;
  late _StubTranscriptionService stubTranscription;

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

  setUpAll(registerAllFallbackValues);

  setUp(() {
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
      ),
    ).thenAnswer(
      (invocation) async => createdEntry(
        invocation.namedArguments[#data] as CheckInData,
      ),
    );
  });

  /// The tracked person, filed under [categoryId] — the category whose
  /// profile and speech dictionary the recording will be transcribed with.
  RelationshipEntry relationshipIn(String? categoryId) =>
      testRelationship.copyWith(
        meta: testRelationship.meta.copyWith(categoryId: categoryId),
      );

  Widget buildForm() => makeTestableWidgetWithScaffold(
    const CheckInCaptureForm(relationshipId: 'rel-001'),
    overrides: [
      relationshipRepositoryProvider.overrideWithValue(mockRepository),
    ],
  );

  /// The form with both voice seams stubbed: [recordedEntryId] is what the
  /// recorder sheet resolves to, [transcript] what the wait yields.
  Widget buildSpeakableForm({
    required String? recordedEntryId,
    required String? transcript,
    Completer<String?>? transcriptGate,
    void Function(String? categoryId)? onLaunch,
    bool canTranscribe = true,
    bool? enableSpeechRecognition,
  }) => makeTestableWidgetWithScaffold(
    const CheckInCaptureForm(relationshipId: 'rel-001'),
    overrides: [
      relationshipRepositoryProvider.overrideWithValue(mockRepository),

      checkInRecorderLauncherProvider.overrideWithValue(
        ({
          required BuildContext context,
          required String relationshipId,
          String? categoryId,
        }) async {
          onLaunch?.call(categoryId);
          return recordedEntryId;
        },
      ),
      audioRecorderControllerProvider.overrideWith(
        () => _FixedRecorderController(
          enableSpeechRecognition: enableSpeechRecognition,
        ),
      ),
      checkInTranscriptionServiceProvider.overrideWithValue(
        stubTranscription = _StubTranscriptionService(
          canTranscribeResult: canTranscribe,
          transcript: transcript,
          gate: transcriptGate,
        ),
      ),
    ],
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

  Widget buildEditForm() => makeTestableWidgetWithScaffold(
    CheckInCaptureForm(
      relationshipId: 'rel-001',
      initial: existing(),
    ),
    overrides: [
      relationshipRepositoryProvider.overrideWithValue(mockRepository),
    ],
  );

  ({CheckInData data, EntryText? entryText, DateTime? dateFrom})
  capturedSave() {
    final captured = verify(
      () => mockRepository.createCheckIn(
        data: captureAny(named: 'data'),
        entryText: captureAny(named: 'entryText'),
        dateFrom: captureAny(named: 'dateFrom'),
      ),
    ).captured;
    return (
      data: captured[0] as CheckInData,
      entryText: captured[1] as EntryText?,
      dateFrom: captured[2] as DateTime?,
    );
  }

  testWidgets(
    'saves interaction type, sentiment, parsed topics, and narrative',
    (tester) async {
      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Call'));
      await tester.tap(find.text('Call'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Good'));
      await tester.tap(find.text('Good'));
      await tester.pumpAndSettle();

      // Field order: narrative, topics, pay attention, avoid.
      await tester.enterText(
        find.byType(TextField).at(0),
        'Talked about the interview.',
      );
      await tester.enterText(
        find.byType(TextField).at(1),
        ' job search ,vacation , ',
      );
      await tester.enterText(find.byType(TextField).at(2), 'Interview result');
      await tester.enterText(find.byType(TextField).at(3), 'Inheritance');

      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final saved = capturedSave();
      expect(saved.data.relationshipId, 'rel-001');
      expect(saved.data.interactionType, CheckInInteractionType.call);
      expect(saved.data.sentiment, CheckInSentiment.good);
      expect(saved.data.topics, ['job search', 'vacation']);
      expect(saved.data.payAttentionTo, 'Interview result');
      expect(saved.data.avoid, 'Inheritance');
      expect(saved.entryText?.plainText, 'Talked about the interview.');
    },
  );

  testWidgets('sentiment stays unset unless the user picks one', (
    tester,
  ) async {
    await tester.pumpWidget(buildForm());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = capturedSave();
    expect(saved.data.sentiment, isNull);
    expect(saved.data.interactionType, CheckInInteractionType.inPerson);
    expect(saved.data.topics, isEmpty);
    expect(saved.entryText, isNull);
  });

  testWidgets('tapping the selected sentiment clears it again', (
    tester,
  ) async {
    await tester.pumpWidget(buildForm());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Good'));
    await tester.tap(find.text('Good'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Good'));
    await tester.tap(find.text('Good'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(capturedSave().data.sentiment, isNull);
  });

  testWidgets('create mode defaults the interaction time to NOW, to the '
      'minute — not midnight, not createdAt', (tester) async {
    final fixedNow = DateTime(2026, 8, 13, 10, 30);
    await withClock(Clock.fixed(fixedNow), () async {
      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
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
      ),
    ).thenAnswer((_) async => null);

    await tester.pumpWidget(buildForm());
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      find.text('Could not save the check-in. Please try again.'),
      findsOneWidget,
    );
    // Still editable, and Save is armed again — a retry does not need the
    // sheet reopened.
    expect(find.text('How did you connect?'), findsOneWidget);
    expect(
      tester
          .widget<DesignSystemButton>(
            find.widgetWithText(DesignSystemButton, 'Save'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('a save that throws reports the failure too', (tester) async {
    when(
      () => mockRepository.createCheckIn(
        data: any(named: 'data'),
        entryText: any(named: 'entryText'),
        dateFrom: any(named: 'dateFrom'),
      ),
    ).thenThrow(Exception('db gone'));

    await tester.pumpWidget(buildForm());
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      find.text('Could not save the check-in. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('How did you connect?'), findsOneWidget);
  });

  testWidgets('Cancel closes without saving anything', (tester) async {
    await tester.pumpWidget(buildForm());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Typed but discarded');
    await tester.ensureVisible(find.text('Cancel'));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    verifyNever(
      () => mockRepository.createCheckIn(
        data: any(named: 'data'),
        entryText: any(named: 'entryText'),
        dateFrom: any(named: 'dateFrom'),
      ),
    );
  });

  group('edit mode', () {
    setUp(() {
      when(
        () => mockRepository.updateCheckIn(any()),
      ).thenAnswer((_) async => true);
    });

    testWidgets(
      'prefills every field and preserves the interaction time on save',
      (tester) async {
        await tester.pumpWidget(buildEditForm());
        await tester.pumpAndSettle();

        // Prefilled: narrative, joined topics, guidance, and the date field.
        expect(
          find.widgetWithText(TextField, 'Planned the trip.'),
          findsOneWidget,
        );
        expect(find.widgetWithText(TextField, 'travel, work'), findsOneWidget);
        expect(
          find.widgetWithText(TextField, 'Job interview'),
          findsOneWidget,
        );
        expect(find.text('2026-08-10'), findsOneWidget);

        await tester.ensureVisible(find.text('Neutral'));
        await tester.tap(find.text('Neutral'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Save'));
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

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
      },
    );

    testWidgets('tapping the date field opens the date picker', (
      tester,
    ) async {
      await tester.pumpWidget(buildEditForm());
      await tester.pumpAndSettle();

      // One 'When?' before (the field label)…
      expect(find.text('When?'), findsOneWidget);
      await tester.ensureVisible(find.text('2026-08-10'));
      await tester.tap(find.text('2026-08-10'));
      await tester.pumpAndSettle();

      // …and a second one as the picker modal's title once it is open.
      expect(find.text('When?'), findsNWidgets(2));
    });

    testWidgets('delete asks for confirmation, then deletes and closes', (
      tester,
    ) async {
      when(
        () => mockRepository.deleteCheckIn('check-1'),
      ).thenAnswer((_) async => true);

      await tester.pumpWidget(buildEditForm());
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byIcon(Icons.delete_outline_rounded));
      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();

      expect(
        find.text('Delete this check-in? This cannot be undone.'),
        findsOneWidget,
      );
      verifyNever(() => mockRepository.deleteCheckIn(any()));

      await tester.ensureVisible(find.text('Delete'));
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      verify(() => mockRepository.deleteCheckIn('check-1')).called(1);
    });

    testWidgets('create mode carries no delete affordance', (tester) async {
      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
    });

    testWidgets('a refused delete keeps the check-in and reports it', (
      tester,
    ) async {
      when(
        () => mockRepository.deleteCheckIn('check-1'),
      ).thenAnswer((_) async => false);

      await tester.pumpWidget(buildEditForm());
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byIcon(Icons.delete_outline_rounded));
      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(
        find.text('Could not delete the check-in. Please try again.'),
        findsOneWidget,
      );
      // The sheet stays up on its still-live check-in.
      expect(
        find.widgetWithText(TextField, 'Planned the trip.'),
        findsOneWidget,
      );
    });

    testWidgets('a delete that throws reports the failure too', (tester) async {
      when(
        () => mockRepository.deleteCheckIn('check-1'),
      ).thenThrow(Exception('db gone'));

      await tester.pumpWidget(buildEditForm());
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byIcon(Icons.delete_outline_rounded));
      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(
        find.text('Could not delete the check-in. Please try again.'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(TextField, 'Planned the trip.'),
        findsOneWidget,
      );
    });

    testWidgets('a refused update reports it and keeps the edits', (
      tester,
    ) async {
      when(
        () => mockRepository.updateCheckIn(any()),
      ).thenAnswer((_) async => false);

      await tester.pumpWidget(buildEditForm());
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'Edited narrative');
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(
        find.text('Could not save the check-in. Please try again.'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(TextField, 'Edited narrative'),
        findsOneWidget,
      );
    });

    testWidgets('the date picker moves the day and keeps the time of day', (
      tester,
    ) async {
      await tester.pumpWidget(buildEditForm());
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('2026-08-10'));
      await tester.tap(find.text('2026-08-10'));
      await tester.pumpAndSettle();

      // Pick the 6th in the open month grid, then confirm.
      await tester.tap(find.text('6'));
      await tester.pump();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.text('2026-08-06'), findsOneWidget);

      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final updated =
          verify(
                () => mockRepository.updateCheckIn(captureAny()),
              ).captured.single
              as CheckInEntry;
      // The day moved; 19:45 survived, because the picker is date-only.
      expect(updated.meta.dateFrom, DateTime(2026, 8, 6, 19, 45));
      expect(updated.meta.dateTo, DateTime(2026, 8, 6, 19, 45));
    });
  });

  group('error toasts', () {
    testWidgets('shows a toast when create returns null', (tester) async {
      when(
        () => mockRepository.createCheckIn(
          data: any(named: 'data'),
          entryText: any(named: 'entryText'),
          dateFrom: any(named: 'dateFrom'),
        ),
      ).thenAnswer((_) async => null);

      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(
        find.text('Could not save the check-in. Please try again.'),
        findsOne,
      );
    });

    testWidgets('shows a toast when create throws', (tester) async {
      when(
        () => mockRepository.createCheckIn(
          data: any(named: 'data'),
          entryText: any(named: 'entryText'),
          dateFrom: any(named: 'dateFrom'),
        ),
      ).thenThrow(Exception('db locked'));

      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(
        find.text('Could not save the check-in. Please try again.'),
        findsOne,
      );
    });

    testWidgets('shows a toast when update returns false', (tester) async {
      when(() => mockRepository.updateCheckIn(any())).thenAnswer(
        (_) async => false,
      );

      await tester.pumpWidget(buildEditForm());
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(
        find.text('Could not save the check-in. Please try again.'),
        findsOne,
      );
    });

    testWidgets('shows a toast when delete returns false', (tester) async {
      when(
        () => mockRepository.deleteCheckIn('check-1'),
      ).thenAnswer((_) async => false);

      await tester.pumpWidget(buildEditForm());
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byIcon(Icons.delete_outline_rounded));
      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Delete'));
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(
        find.text('Could not delete the check-in. Please try again.'),
        findsOne,
      );
    });

    testWidgets('shows a toast when delete throws', (tester) async {
      when(
        () => mockRepository.deleteCheckIn('check-1'),
      ).thenThrow(Exception('db locked'));

      await tester.pumpWidget(buildEditForm());
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byIcon(Icons.delete_outline_rounded));
      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Delete'));
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(
        find.text('Could not delete the check-in. Please try again.'),
        findsOne,
      );
    });
  });

  group('speak check-in', () {
    Finder speakButton() => find.byKey(const Key('check_in_speak_button'));
    Finder narrativeField() => find.ancestor(
      of: find.text('What did you talk about?'),
      matching: find.byType(TextField),
    );

    String narrativeText(WidgetTester tester) =>
        tester.widget<TextField>(narrativeField()).controller!.text;

    testWidgets('offers the button on a fresh check-in', (tester) async {
      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();

      expect(speakButton(), findsOne);
      expect(find.text('Speak check-in'), findsOne);
    });

    // The bug this guards: with no audio model — or a person filed under no
    // category, which can never pass the automatic-inference gate — the sheet
    // used to record and then sit on "Transcribing…" for the full five-minute
    // timeout before admitting no run was ever started.
    testWidgets('refuses before recording when nothing can transcribe', (
      tester,
    ) async {
      var launches = 0;
      await tester.pumpWidget(
        buildSpeakableForm(
          recordedEntryId: 'audio-1',
          transcript: 'never reached',
          canTranscribe: false,
          onLaunch: (_) => launches++,
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(speakButton());
      await tester.tap(speakButton());
      await tester.pumpAndSettle();

      expect(launches, 0, reason: 'no recording should be wasted');
      expect(find.text('Transcribing…'), findsNothing);
      expect(
        find.textContaining('Transcription is not set up'),
        findsOne,
      );
    });

    testWidgets('prefills the empty narrative with the transcript', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSpeakableForm(
          recordedEntryId: 'audio-1',
          transcript: 'She got the job.',
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(speakButton());
      await tester.tap(speakButton());
      await tester.pumpAndSettle();

      expect(narrativeText(tester), 'She got the job.');
    });

    // Speaking never destroys typing — the account grows, it is not replaced.
    testWidgets('appends below text the user already typed', (tester) async {
      await tester.pumpWidget(
        buildSpeakableForm(
          recordedEntryId: 'audio-1',
          transcript: 'She got the job.',
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(narrativeField(), 'Called on the way home.');
      await tester.ensureVisible(speakButton());
      await tester.tap(speakButton());
      await tester.pumpAndSettle();

      expect(
        narrativeText(tester),
        'Called on the way home.\n\nShe got the job.',
      );
    });

    testWidgets('scopes the recording to the person and their category', (
      tester,
    ) async {
      String? launchedCategoryId;
      var launches = 0;
      when(() => mockRepository.getRelationshipById('rel-001')).thenAnswer(
        (_) async => relationshipIn('category-7'),
      );

      await tester.pumpWidget(
        buildSpeakableForm(
          recordedEntryId: 'audio-1',
          transcript: 'Spoken.',
          onLaunch: (categoryId) {
            launches++;
            launchedCategoryId = categoryId;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(speakButton());
      await tester.tap(speakButton());
      await tester.pumpAndSettle();

      expect(launches, 1);
      expect(launchedCategoryId, 'category-7');
    });

    testWidgets('shows the transcribing state while the wait is open', (
      tester,
    ) async {
      final gate = Completer<String?>();
      await tester.pumpWidget(
        buildSpeakableForm(
          recordedEntryId: 'audio-1',
          transcript: null,
          transcriptGate: gate,
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(speakButton());
      await tester.tap(speakButton());
      await tester.pump();

      expect(find.text('Transcribing…'), findsOne);
      expect(find.text('Speak check-in'), findsNothing);

      gate.complete('Arrived at last.');
      await tester.pumpAndSettle();

      expect(find.text('Speak check-in'), findsOne);
      expect(narrativeText(tester), 'Arrived at last.');
    });

    testWidgets('a dismissed recording leaves the narrative alone', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSpeakableForm(recordedEntryId: null, transcript: 'never used'),
      );
      await tester.pumpAndSettle();

      await tester.enterText(narrativeField(), 'Typed only.');
      await tester.ensureVisible(speakButton());
      await tester.tap(speakButton());
      await tester.pumpAndSettle();

      expect(narrativeText(tester), 'Typed only.');
      expect(find.text('Transcribing…'), findsNothing);
    });

    // No profile, no model, or a run that never finished: the user is told
    // once and keeps a usable field rather than an empty spinner.
    testWidgets('says so when no transcript came back', (tester) async {
      await tester.pumpWidget(
        buildSpeakableForm(recordedEntryId: 'audio-1', transcript: null),
      );
      await tester.pumpAndSettle();

      await tester.enterText(narrativeField(), 'Typed only.');
      await tester.ensureVisible(speakButton());
      await tester.tap(speakButton());
      await tester.pumpAndSettle();

      expect(
        find.text('No transcript came back. You can type it instead.'),
        findsOne,
      );
      expect(narrativeText(tester), 'Typed only.');
      expect(find.text('Speak check-in'), findsOne);
    });

    // The HTTP 503 case. A failed run writes no transcript, so the wait alone
    // cannot tell a provider outage from a slow model, and `runTranscription`
    // reports the failure through its status controllers rather than
    // throwing. When the recorder's automatic path owns the run the service's
    // own failure hook never fires either — the error controller is the one
    // signal set by whichever path ran, which is why the sheet watches it.
    testWidgets('a reported inference failure ends the wait and names it', (
      tester,
    ) async {
      final gate = Completer<String?>();
      await tester.pumpWidget(
        buildSpeakableForm(
          recordedEntryId: 'audio-1',
          transcript: null,
          transcriptGate: gate,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(narrativeField(), 'Typed only.');
      await tester.ensureVisible(speakButton());
      await tester.tap(speakButton());
      await tester.pump();

      expect(find.text('Transcribing…'), findsOne, reason: 'wait is open');

      ProviderScope.containerOf(tester.element(find.byType(CheckInCaptureForm)))
          .read(
            inferenceErrorControllerProvider((
              id: 'audio-1',
              aiResponseType: AiResponseType.audioTranscription,
            )).notifier,
          )
          .setError('HTTP 503 · Melious · All Voxtral providers failed');
      await tester.pumpAndSettle();

      expect(
        find.text('Transcribing…'),
        findsNothing,
        reason: 'must not run out the five-minute timeout',
      );
      expect(stubTranscription.cancelCount, 1);
      expect(
        find.text('No transcript came back. You can type it instead.'),
        findsOne,
      );
      expect(
        find.text('HTTP 503 · Melious · All Voxtral providers failed'),
        findsOne,
        reason: "the provider's own reason, not a generic failure",
      );
      expect(narrativeText(tester), 'Typed only.');
    });

    // A stale detail from an earlier recording must not abort the run the
    // user just started: only a failure reported *after* the wait opens is
    // this recording's.
    testWidgets('a failure recorded before the wait opened is ignored', (
      tester,
    ) async {
      final gate = Completer<String?>();
      await tester.pumpWidget(
        buildSpeakableForm(
          recordedEntryId: 'audio-1',
          transcript: null,
          transcriptGate: gate,
        ),
      );
      await tester.pumpAndSettle();

      ProviderScope.containerOf(tester.element(find.byType(CheckInCaptureForm)))
          .read(
            inferenceErrorControllerProvider((
              id: 'audio-1',
              aiResponseType: AiResponseType.audioTranscription,
            )).notifier,
          )
          .setError('a failure from the previous take');

      await tester.ensureVisible(speakButton());
      await tester.tap(speakButton());
      await tester.pump();

      expect(find.text('Transcribing…'), findsOne);
      expect(stubTranscription.cancelCount, 0);

      gate.complete('Arrived at last.');
      await tester.pumpAndSettle();

      expect(narrativeText(tester), 'Arrived at last.');
    });

    testWidgets('ignores a second tap while a transcript is in flight', (
      tester,
    ) async {
      final gate = Completer<String?>();
      var launches = 0;
      await tester.pumpWidget(
        buildSpeakableForm(
          recordedEntryId: 'audio-1',
          transcript: null,
          transcriptGate: gate,
          onLaunch: (_) => launches++,
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(speakButton());
      await tester.tap(speakButton());
      await tester.pump();
      await tester.tap(speakButton(), warnIfMissed: false);
      await tester.pump();

      expect(launches, 1);

      gate.complete('Done.');
      await tester.pumpAndSettle();
    });

    // Saving mid-wait used to pop the sheet and silently drop the words the
    // user was still waiting for, leaving the check-in with no narrative.

    // The recording sheet has its own speech opt-out. Unchecking it means
    // "not this one" — before this the sheet held "Transcribing…" for the
    // whole five-minute timeout to arrive at exactly that answer.
    testWidgets('does not wait when speech recognition was switched off', (
      tester,
    ) async {
      final gate = Completer<String?>();
      await tester.pumpWidget(
        buildSpeakableForm(
          recordedEntryId: 'audio-1',
          transcript: null,
          transcriptGate: gate,
          enableSpeechRecognition: false,
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(speakButton());
      await tester.tap(speakButton());
      await tester.pumpAndSettle();

      expect(find.text('Transcribing…'), findsNothing);
      expect(
        find.text('No transcript came back. You can type it instead.'),
        findsOne,
      );
      expect(gate.isCompleted, isFalse, reason: 'the wait never started');
    });

    // The default (never touched) must still transcribe.
    testWidgets('waits normally when the opt-out was left alone', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSpeakableForm(
          recordedEntryId: 'audio-1',
          transcript: 'Spoken.',
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(speakButton());
      await tester.tap(speakButton());
      await tester.pumpAndSettle();

      expect(narrativeText(tester), 'Spoken.');
    });

    testWidgets('holds Save while a transcript is in flight', (tester) async {
      final gate = Completer<String?>();
      await tester.pumpWidget(
        buildSpeakableForm(
          recordedEntryId: 'audio-1',
          transcript: null,
          transcriptGate: gate,
        ),
      );
      await tester.pumpAndSettle();

      final saveButton = find.widgetWithText(DesignSystemButton, 'Save');
      expect(
        tester.widget<DesignSystemButton>(saveButton).onPressed,
        isNotNull,
        reason: 'enabled before speaking',
      );

      await tester.ensureVisible(speakButton());
      await tester.tap(speakButton());
      await tester.pump();

      expect(tester.widget<DesignSystemButton>(saveButton).onPressed, isNull);

      gate.complete('Arrived.');
      await tester.pumpAndSettle();

      expect(
        tester.widget<DesignSystemButton>(saveButton).onPressed,
        isNotNull,
      );
    });

    // A dismissed sheet must stop the wait rather than leave it re-reading the
    // database on every write until the timeout expires.
    testWidgets('cancels the wait when the sheet goes away', (tester) async {
      final gate = Completer<String?>();
      await tester.pumpWidget(
        buildSpeakableForm(
          recordedEntryId: 'audio-1',
          transcript: null,
          transcriptGate: gate,
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(speakButton());
      await tester.tap(speakButton());
      await tester.pump();
      expect(stubTranscription.cancelCount, 0);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      expect(stubTranscription.cancelCount, 1);
    });

    testWidgets('is offered when editing an existing check-in too', (
      tester,
    ) async {
      await tester.pumpWidget(buildEditForm());
      await tester.pumpAndSettle();

      expect(speakButton(), findsOne);
    });
  });

  // Every other test in this file pumps `CheckInCaptureForm` bare, which is
  // why the defect below survived: the form is fine, and the modal it lives
  // in was not. These open the real sheet at a phone's size.
  group('inside the real modal', () {
    Future<void> openSheet(WidgetTester tester) async {
      // iPhone-class viewport: tall content, little room to spare.
      tester.view
        ..physicalSize = const Size(1206, 2622)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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
          overrides: [
            relationshipRepositoryProvider.overrideWithValue(mockRepository),
          ],
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    }

    // The bug: the form capped itself at 90% of the SCREEN while the modal
    // page added a top bar, padding and the safe area on top, so the action
    // row sat below the viewport — and the form's own scroll view consumed
    // every drag, so the page's scroll never moved and Save could not be
    // reached at all. Dismissing was the only way out, which discards.
    testWidgets('dragging over the form reaches the save action', (
      tester,
    ) async {
      await openSheet(tester);

      final save = find.widgetWithText(DesignSystemButton, 'Save');
      final viewportBottom =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;

      expect(
        tester.getTopLeft(save).dy,
        greaterThan(viewportBottom),
        reason: 'precondition: the action row starts below the fold',
      );

      // Drag over the form the way a user scrolls the sheet — NOT a
      // programmatic scroll of a hand-picked Scrollable, which moves the page
      // even when a real drag cannot reach it. A form owning its own scroll
      // view consumes these, the page never moves, and Save stays off screen.
      for (var i = 0; i < 5; i++) {
        await tester.drag(
          find.byType(CheckInCaptureForm),
          const Offset(0, -400),
          warnIfMissed: false,
        );
        await tester.pumpAndSettle();
      }

      expect(
        tester.getBottomLeft(save).dy,
        lessThanOrEqualTo(viewportBottom),
        reason: 'Save is on screen once the user has scrolled to the end',
      );

      await tester.tap(save);
      await tester.pumpAndSettle();

      verify(
        () => mockRepository.createCheckIn(
          data: any(named: 'data'),
          entryText: any(named: 'entryText'),
          dateFrom: any(named: 'dateFrom'),
        ),
      ).called(1);
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
  });

  // The default launcher, exercised for real: the whole phase depends on the
  // recording being linked to the *person*, since that is what makes the
  // generalized automation resolve their profile and wake their agent.
  group('showCheckInRecorder', () {
    testWidgets('opens the recording sheet linked to the person', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(1000, 800)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      // The recorder controller resolves its logger from GetIt.
      await setUpTestGetIt();
      addTearDown(tearDownTestGetIt);

      final recorderRepository = MockAudioRecorderRepository();
      when(
        () => recorderRepository.amplitudeStream,
      ).thenAnswer((_) => const Stream<Amplitude>.empty());
      final categoryRepository = MockCategoryRepository();
      when(
        () => categoryRepository.watchCategory(any()),
      ).thenAnswer((_) => const Stream.empty());

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(
            builder: (context) => Consumer(
              builder: (context, ref, _) => ElevatedButton(
                onPressed: () => ref.read(checkInRecorderLauncherProvider)(
                  context: context,
                  relationshipId: 'rel-001',
                  categoryId: 'category-7',
                ),
                child: const Text('Speak'),
              ),
            ),
          ),
          overrides: [
            audioRecorderRepositoryProvider.overrideWithValue(
              recorderRepository,
            ),
            categoryRepositoryProvider.overrideWithValue(categoryRepository),
          ],
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Speak'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final content = tester.widget<AudioRecordingModalContent>(
        find.byType(AudioRecordingModalContent),
      );
      expect(content.linkedId, 'rel-001');
      expect(content.categoryId, 'category-7');
    });
  });
}
