import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/features/journal/ui/widgets/entry_detail_linked.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/service/check_in_transcription_service.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_capture_sheet.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_detail_view.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_speech_state.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../widget_test_utils.dart';
import '../../helpers/check_in_speech_fakes.dart';

void main() {
  final now = DateTime(2026, 8, 14, 21);
  final at = DateTime(2026, 8, 14, 20);

  late MockRelationshipRepository repository;
  late StubCheckInTranscriptionService transcription;
  late FakeAudioRecorderController recorder;
  late List<String> photoImports;

  final person = testRelationship.copyWith(
    meta: testRelationship.meta.copyWith(id: 'rel-001', categoryId: 'crew'),
    data: testRelationship.data.copyWith(
      title: 'Commander Pip Frostbeak',
      nickname: 'Pip',
    ),
  );

  CheckInEntry checkIn({String? note, DateTime? updatedAt}) => CheckInEntry(
    meta: person.meta.copyWith(
      id: 'c-1',
      dateFrom: at,
      dateTo: at.add(const Duration(minutes: 11)),
      createdAt: at,
      updatedAt: updatedAt ?? at,
    ),
    data: const CheckInData(
      relationshipId: 'rel-001',
      interactionType: CheckInInteractionType.call,
      sentiment: CheckInSentiment.good,
      topics: ['krill contract'],
      payAttentionTo: 'The launch nerves.',
      avoid: 'Budget talk.',
    ),
    entryText: note == null ? null : EntryText(plainText: note),
  );

  void stubDetail(
    CheckInEntry? held, {
    List<JournalEntity> entries = const [],
  }) {
    when(
      () => repository.getRelationshipById('rel-001'),
    ).thenAnswer((_) async => person);
    when(
      () => repository.getCheckInsForRelationship('rel-001'),
    ).thenAnswer((_) async => [?held]);
    when(() => repository.getEntriesForCheckIns(any())).thenAnswer(
      (_) async => {if (held != null) held.id: entries},
    );
    when(
      () => repository.getLinkedTasks('rel-001'),
    ).thenAnswer((_) async => []);
  }

  setUpAll(registerAllFallbackValues);

  setUp(() async {
    await setUpTestGetIt();
    repository = MockRelationshipRepository();
    transcription = StubCheckInTranscriptionService(gate: Completer());
    recorder = FakeAudioRecorderController(stopResult: 'take-1');
    photoImports = [];
    when(() => repository.touchCheckIn(any())).thenAnswer((_) async => true);
  });

  tearDown(tearDownTestGetIt);

  Future<List<VoidCallback>> pump(WidgetTester tester) async {
    final backs = <VoidCallback>[];
    await withClock(Clock.fixed(now), () async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Scaffold(
            body: CheckInDetailView(
              relationshipId: 'rel-001',
              checkInId: 'c-1',
              onBack: () => backs.add(() {}),
            ),
          ),
          overrides: [
            relationshipRepositoryProvider.overrideWithValue(repository),
            checkInTranscriptionServiceProvider.overrideWithValue(
              transcription,
            ),
            audioRecorderControllerProvider.overrideWith(() => recorder),
            sortedLinkedEntriesProvider('c-1').overrideWith((ref) => []),
            checkInPhotoImporterProvider.overrideWithValue(
              (context, {required checkInId, categoryId}) async =>
                  photoImports.add('$checkInId in $categoryId'),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
    });
    return backs;
  }

  testWidgets('says how the contact went, whose it is, and what to keep in '
      'mind next time', (tester) async {
    stubDetail(checkIn());
    await pump(tester);

    expect(find.text('Check-in'), findsOneWidget);
    expect(find.text('Pip'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('check-in-detail-meta')))
          .data,
      allOf(contains('Call'), contains('11 min')),
    );
    expect(find.text('Good'), findsOneWidget);
    expect(find.text('krill contract'), findsOneWidget);
    expect(find.text('Next time'), findsOneWidget);
    expect(find.text('The launch nerves.'), findsOneWidget);
    expect(find.text('Budget talk.'), findsOneWidget);
  });

  testWidgets('the text a check-in was saved with reads as its first note, '
      'and an empty one invites the first entry', (tester) async {
    stubDetail(checkIn(note: 'Called about the launch.'));
    await pump(tester);

    expect(find.text('Noted when it was logged'), findsOneWidget);
    expect(find.text('Called about the launch.'), findsOneWidget);
    expect(find.byKey(const ValueKey('check-in-detail-empty')), findsOneWidget);
    expect(find.byType(LinkedEntriesWidget), findsNothing);
  });

  testWidgets('what the check-in holds is the nested entry list a task shows', (
    tester,
  ) async {
    stubDetail(checkIn(), entries: [testTextEntry]);
    await pump(tester);

    expect(find.byType(LinkedEntriesWidget), findsOneWidget);
    expect(find.byKey(const ValueKey('check-in-detail-empty')), findsNothing);
  });

  testWidgets('a check-in that no longer exists says so', (tester) async {
    stubDetail(null);
    await pump(tester);

    expect(find.byKey(const ValueKey('check-in-detail-gone')), findsOneWidget);
    expect(find.byKey(const ValueKey('check-in-detail-comment')), findsNothing);
  });

  testWidgets('back leads to the person', (tester) async {
    stubDetail(checkIn());
    final backs = await pump(tester);

    await tester.tap(find.byKey(const ValueKey('check-in-detail-back')));

    expect(backs, hasLength(1));
  });

  group('adding to the check-in', () {
    testWidgets('a comment is added as its own entry and the field clears', (
      tester,
    ) async {
      final held = checkIn();
      stubDetail(held);
      when(
        () => repository.addCommentToCheckIn(held, 'Send the memo.'),
      ).thenAnswer((_) async => testTextEntry);
      await pump(tester);

      await tester.enterText(
        find.byKey(const ValueKey('check-in-detail-comment')),
        '  Send the memo. ',
      );
      await tester.tap(
        find.byKey(const ValueKey('check-in-detail-send-comment')),
      );
      await tester.pumpAndSettle();

      verify(
        () => repository.addCommentToCheckIn(held, 'Send the memo.'),
      ).called(1);
      expect(find.text('Send the memo.'), findsNothing);
    });

    testWidgets('a comment that could not be saved keeps its words and says '
        'so', (tester) async {
      final held = checkIn();
      stubDetail(held);
      when(
        () => repository.addCommentToCheckIn(any(), any()),
      ).thenAnswer((_) async => null);
      await pump(tester);

      await tester.enterText(
        find.byKey(const ValueKey('check-in-detail-comment')),
        'Lost words.',
      );
      await tester.tap(
        find.byKey(const ValueKey('check-in-detail-send-comment')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Lost words.'), findsOneWidget);
      expect(
        find.text('Could not save the changes. Please try again.'),
        findsOneWidget,
      );
    });

    testWidgets('an empty comment adds nothing', (tester) async {
      stubDetail(checkIn());
      await pump(tester);

      await tester.tap(
        find.byKey(const ValueKey('check-in-detail-send-comment')),
      );
      await tester.pumpAndSettle();

      verifyNever(() => repository.addCommentToCheckIn(any(), any()));
    });

    testWidgets('photos are added to the check-in, which then changes', (
      tester,
    ) async {
      stubDetail(checkIn());
      await pump(tester);

      await tester.tap(find.byKey(const ValueKey('check-in-detail-photo')));
      await tester.pumpAndSettle();

      expect(photoImports, ['c-1 in crew']);
      verify(() => repository.touchCheckIn('c-1')).called(1);
    });

    // The recording is the entry; its words follow in the background and
    // the check-in changes again when they land (the service's job).
    testWidgets('a dictation is recorded against the check-in and sent for '
        'its words', (tester) async {
      stubDetail(checkIn());
      await pump(tester);

      await tester.tap(find.byKey(const ValueKey('check-in-detail-dictate')));
      await tester.pumpAndSettle();
      expect(recorder.recordCalls.single.linkedId, 'c-1');

      await tester.tap(find.byKey(const ValueKey('check-in-recorder-stop')));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(transcription.transcribeCalls, ['take-1']);
      expect(transcription.transcribePeople, ['rel-001']);
      verify(() => repository.touchCheckIn('c-1')).called(1);
      expect(
        find.byKey(const ValueKey('check-in-detail-comment')),
        findsOneWidget,
        reason: 'the bar comes back once the take is saved',
      );
    });

    testWidgets('a refused microphone says why and gives the bar back', (
      tester,
    ) async {
      recorder = FakeAudioRecorderController(
        recordFailure: AudioRecordingFailure.permissionDenied,
      );
      stubDetail(checkIn());
      await pump(tester);

      await tester.tap(find.byKey(const ValueKey('check-in-detail-dictate')));
      await tester.pumpAndSettle();

      expect(find.text('Allow microphone access'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('check-in-detail-comment')),
        findsOneWidget,
      );
    });
  });

  testWidgets('a comment can be sent from the keyboard', (tester) async {
    final held = checkIn();
    stubDetail(held);
    when(
      () => repository.addCommentToCheckIn(held, 'Typed and sent.'),
    ).thenAnswer((_) async => testTextEntry);
    await pump(tester);

    await tester.enterText(
      find.byKey(const ValueKey('check-in-detail-comment')),
      'Typed and sent.',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    verify(
      () => repository.addCommentToCheckIn(held, 'Typed and sent.'),
    ).called(1);
  });

  testWidgets('a discarded dictation gives the bar back and adds nothing', (
    tester,
  ) async {
    stubDetail(checkIn());
    await pump(tester);

    await tester.tap(find.byKey(const ValueKey('check-in-detail-dictate')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('check-in-recorder-discard')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard').last);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('check-in-detail-comment')),
      findsOneWidget,
    );
    expect(transcription.transcribeCalls, isEmpty);
    verifyNever(() => repository.touchCheckIn(any()));
  });

  group('checkInRecordingFailureCopy', () {
    for (final (kind, title) in [
      (CheckInSpeechFailureKind.microphoneDenied, 'Allow microphone access'),
      (CheckInSpeechFailureKind.recorderBusy, null),
      (CheckInSpeechFailureKind.recordingNotSaved, null),
      (CheckInSpeechFailureKind.recordingFailed, null),
    ]) {
      testWidgets("names $kind in the composer's own words", (tester) async {
        late (String, String) copy;
        late AppLocalizations messages;
        await tester.pumpWidget(
          makeTestableWidgetNoScroll(
            Builder(
              builder: (context) {
                messages = context.messages;
                copy = checkInRecordingFailureCopy(messages, kind);
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        expect(copy, switch (kind) {
          CheckInSpeechFailureKind.microphoneDenied => (
            title,
            messages.checkInMicrophoneDeniedBody,
          ),
          CheckInSpeechFailureKind.recorderBusy => (
            messages.checkInRecorderBusyTitle,
            messages.checkInRecorderBusyBody,
          ),
          CheckInSpeechFailureKind.recordingNotSaved => (
            messages.checkInRecordingNotSavedTitle,
            messages.checkInRecordingNotSavedBody,
          ),
          _ => (
            messages.checkInRecordingFailedTitle,
            messages.checkInRecordingFailedBody,
          ),
        });
      });
    }
  });

  test('the photo importer defaults to the platform picker', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(checkInPhotoImporterProvider),
      isA<CheckInPhotoImporter>(),
    );
  });

  // An edit made in place — a transcript corrected, a comment reworded —
  // saves the entry, not the check-in; the view saves the check-in too, so
  // the agent reads the correction as changed evidence.
  testWidgets('an entry newer than its check-in brings the check-in up to '
      'date, once', (tester) async {
    stubDetail(
      checkIn(),
      entries: [
        testTextEntry.copyWith(
          meta: testTextEntry.meta.copyWith(
            updatedAt: at.add(const Duration(minutes: 5)),
          ),
        ),
        testAudioEntry.copyWith(
          meta: testAudioEntry.meta.copyWith(
            updatedAt: at.add(const Duration(minutes: 2)),
          ),
        ),
        testImageEntry.copyWith(
          meta: testImageEntry.meta.copyWith(
            updatedAt: at.add(const Duration(minutes: 9)),
          ),
        ),
      ],
    );
    await pump(tester);

    verify(() => repository.touchCheckIn('c-1')).called(1);
  });

  testWidgets('entries no newer than the check-in change nothing', (
    tester,
  ) async {
    stubDetail(
      checkIn(updatedAt: at.add(const Duration(hours: 1))),
      entries: [testTextEntry],
    );
    await pump(tester);

    verifyNever(() => repository.touchCheckIn(any()));
  });

  testWidgets('Edit opens the check-in in the composer', (tester) async {
    stubDetail(checkIn());
    await pump(tester);

    await tester.tap(find.byKey(const ValueKey('check-in-detail-edit')));
    await tester.pumpAndSettle();

    expect(find.byType(CheckInCaptureForm), findsOneWidget);
  });
}
