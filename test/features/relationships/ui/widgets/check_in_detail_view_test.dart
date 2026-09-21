import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/design_system/components/time_pickers/design_system_picker_wheels.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/features/journal/ui/widgets/entry_detail_linked.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/service/check_in_transcription_service.dart';
import 'package:lotti/features/relationships/state/check_in_duration_suggestions_controller.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_capture_sheet.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_detail_view.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_speech_state.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/link_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../widget_test_utils.dart';
import '../../helpers/check_in_speech_fakes.dart';

class _FixedDurationSuggestions extends CheckInDurationSuggestionsController {
  _FixedDurationSuggestions(this.values);
  final List<Duration> values;

  @override
  Future<List<Duration>> build() async => values;
}

void main() {
  final now = DateTime(2026, 8, 14, 21);
  final at = DateTime(2026, 8, 14, 20);

  late MockRelationshipRepository repository;
  late StubCheckInTranscriptionService transcription;
  late FakeAudioRecorderController recorder;
  late List<String> photoImports;

  /// What the timeline's list renders; empty unless a test needs a card.
  var links = <EntryLink>[];

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
    links = [];
    when(() => repository.touchCheckIn(any())).thenAnswer((_) async => true);
    when(
      () => repository.discardCommentIfBlank(any()),
    ).thenAnswer((_) async => false);
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
            sortedLinkedEntriesProvider('c-1').overrideWith((ref) => links),
            checkInDurationSuggestionsControllerProvider.overrideWith(
              () => _FixedDurationSuggestions(const [Duration(minutes: 45)]),
            ),
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

  testWidgets('names the check-in and carries how it went as chips, then '
      'what to keep in mind next time', (tester) async {
    stubDetail(checkIn());
    await pump(tester);

    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('check-in-detail-title')))
          .data,
      'Check-in with Commander Pip Frostbeak',
    );
    expect(find.text('Call'), findsOneWidget);
    expect(find.text('11 min'), findsOneWidget);
    expect(find.text('Good'), findsOneWidget);
    expect(find.text('krill contract'), findsOneWidget);
    expect(find.text('Next time'), findsOneWidget);
    expect(find.text('The launch nerves.'), findsOneWidget);
    expect(find.text('Budget talk.'), findsOneWidget);
  });

  testWidgets('the text a check-in was logged with is the first card of its '
      'timeline, stamped at its start', (tester) async {
    stubDetail(checkIn(note: 'Called about the launch.'));
    await pump(tester);

    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('check-in-detail-note-stamp')),
          )
          .data,
      // The device's numeric date and its own clock: 8/14/2026 on a US
      // phone, 14.8.2026 on a German one.
      allOf(contains('8/14/2026'), endsWith('Noted when it was logged')),
    );
    expect(find.text('Called about the launch.'), findsOneWidget);
    expect(find.byKey(const ValueKey('check-in-detail-empty')), findsNothing);
  });

  testWidgets('a check-in with no note and nothing added invites the first '
      'entry', (tester) async {
    stubDetail(checkIn());
    await pump(tester);

    expect(find.byKey(const ValueKey('check-in-detail-empty')), findsOneWidget);
    expect(find.byType(LinkedEntriesWidget), findsNothing);
  });

  // A short timeline has nothing to filter: the Timer/Audio/Images pills
  // come with the fifth entry.
  for (final (count, filters) in [(1, false), (5, true)]) {
    testWidgets('$count entries: filters shown is $filters', (tester) async {
      stubDetail(
        checkIn(),
        entries: List.filled(count, testTextEntry),
      );
      await pump(tester);

      expect(
        tester
            .widget<LinkedEntriesWidget>(find.byType(LinkedEntriesWidget))
            .showActivityFilters,
        filters,
      );
    });
  }

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

  // Codex review on #4348: a failed first load must not spin forever.
  testWidgets('a detail that fails to load says so', (tester) async {
    stubDetail(checkIn());
    when(
      () => repository.getRelationshipById('rel-001'),
    ).thenAnswer((_) async => throw StateError('database closed'));
    await pump(tester);

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('check-in-detail-gone')))
          .data,
      'Error',
    );
  });

  testWidgets('back leads to the person', (tester) async {
    stubDetail(checkIn());
    final backs = await pump(tester);

    await tester.tap(find.byKey(const ValueKey('check-in-detail-back')));

    expect(backs, hasLength(1));
  });

  group('adding to the check-in', () {
    // The comment starts the way a task's text entry does: an empty card
    // in the timeline, written in place.
    testWidgets('Comment starts an empty comment on the check-in', (
      tester,
    ) async {
      final held = checkIn();
      stubDetail(held);
      when(
        () => repository.startCommentOnCheckIn(held),
      ).thenAnswer((_) async => testTextEntry);
      await pump(tester);

      await tester.tap(find.byKey(const ValueKey('check-in-detail-comment')));
      await tester.pumpAndSettle();

      verify(() => repository.startCommentOnCheckIn(held)).called(1);
      expect(
        find.text('Could not save the changes. Please try again.'),
        findsNothing,
      );
    });

    testWidgets('the new comment is brought into view with its editor '
        'focused', (tester) async {
      final held = checkIn();
      final comment = testTextEntry.copyWith(
        entryText: const EntryText(plainText: ''),
      );
      stubDetail(held, entries: [comment]);
      when(
        () => getIt<JournalDb>().journalEntityById(comment.meta.id),
      ).thenAnswer((_) async => comment);
      // The comment renders as the journal's own entry card, with its editor.
      final editorState = MockEditorStateService();
      when(
        () => editorState.getUnsavedStream(any(), any()),
      ).thenAnswer((_) => Stream.value(false));
      final timeService = MockTimeService();
      when(timeService.getStream).thenAnswer((_) => const Stream.empty());
      if (!getIt.isRegistered<EditorStateService>()) {
        getIt.registerSingleton<EditorStateService>(editorState);
      }
      if (!getIt.isRegistered<TimeService>()) {
        getIt.registerSingleton<TimeService>(timeService);
      }
      if (!getIt.isRegistered<LinkService>()) {
        getIt.registerSingleton<LinkService>(MockLinkService());
      }
      if (!getIt.isRegistered<PersistenceLogic>()) {
        getIt.registerSingleton<PersistenceLogic>(MockPersistenceLogic());
      }
      // The list already holds the new card by the time the frame after the
      // tap is laid out — in the app the link's notification rebuilds it.
      links = [
        EntryLink.basic(
          id: 'c-1->${comment.meta.id}',
          fromId: 'c-1',
          toId: comment.meta.id,
          createdAt: at,
          updatedAt: at,
          vectorClock: null,
        ),
      ];
      when(
        () => repository.startCommentOnCheckIn(held),
      ).thenAnswer((_) async => comment);
      await pump(tester);

      await tester.tap(find.byKey(const ValueKey('check-in-detail-comment')));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(CheckInDetailView)),
      );
      expect(
        container
            .read(entryControllerProvider(comment.meta.id).notifier)
            .focusNode
            .hasFocus,
        isTrue,
      );
    });

    // Codex review on #4354: a stray tap on Comment leaves nothing behind.
    testWidgets('a comment started here and left blank is discarded when '
        'the check-in closes', (tester) async {
      final held = checkIn();
      stubDetail(held);
      when(
        () => repository.startCommentOnCheckIn(held),
      ).thenAnswer((_) async => testTextEntry);
      await pump(tester);

      await tester.tap(find.byKey(const ValueKey('check-in-detail-comment')));
      await tester.pumpAndSettle();
      verifyNever(() => repository.discardCommentIfBlank(any()));

      await tester.pumpWidget(const SizedBox());
      verify(
        () => repository.discardCommentIfBlank(testTextEntry.meta.id),
      ).called(1);
    });

    testWidgets('a comment that could not be started says so', (tester) async {
      stubDetail(checkIn());
      when(
        () => repository.startCommentOnCheckIn(any()),
      ).thenAnswer((_) async => null);
      await pump(tester);

      await tester.tap(find.byKey(const ValueKey('check-in-detail-comment')));
      await tester.pumpAndSettle();

      expect(
        find.text('Could not save the changes. Please try again.'),
        findsOneWidget,
      );
    });

    // The importer links each photo as it creates it; the stub below
    // stands in for that, holding the photo once the import ran.
    void stubHeld({required bool imports}) {
      when(() => repository.getAllEntriesForCheckIns({'c-1'})).thenAnswer(
        (_) async => {
          'c-1': [
            if (imports && photoImports.isNotEmpty) testImageEntry,
          ],
        },
      );
    }

    testWidgets('photos are added to the check-in, which then changes', (
      tester,
    ) async {
      stubDetail(checkIn());
      stubHeld(imports: true);
      await pump(tester);

      await tester.tap(find.byKey(const ValueKey('check-in-detail-photo')));
      await tester.pumpAndSettle();

      expect(photoImports, ['c-1 in crew']);
      verify(() => repository.touchCheckIn('c-1')).called(1);
    });

    // Codex review on #4348: the check-in's updatedAt is the agent's
    // "evidence changed" signal, and a cancelled picker changed nothing.
    testWidgets('a picker that adds nothing leaves the check-in alone', (
      tester,
    ) async {
      stubDetail(checkIn());
      stubHeld(imports: false);
      await pump(tester);

      await tester.tap(find.byKey(const ValueKey('check-in-detail-photo')));
      await tester.pumpAndSettle();

      expect(photoImports, ['c-1 in crew']);
      verifyNever(() => repository.touchCheckIn(any()));
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

  testWidgets('More → Edit check-in opens the composer for the fields no '
      'chip carries', (tester) async {
    stubDetail(checkIn());
    await pump(tester);

    await tester.tap(find.byKey(const ValueKey('check-in-detail-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('check-in-detail-edit')));
    await tester.pumpAndSettle();

    expect(find.byType(CheckInCaptureForm), findsOneWidget);
  });

  // An empty comment is no evidence; only its words are.
  testWidgets('an empty comment newer than the check-in changes nothing', (
    tester,
  ) async {
    stubDetail(
      checkIn(),
      entries: [
        testTextEntry.copyWith(
          entryText: const EntryText(plainText: '  '),
          meta: testTextEntry.meta.copyWith(
            updatedAt: at.add(const Duration(minutes: 5)),
          ),
        ),
      ],
    );
    await pump(tester);

    verifyNever(() => repository.touchCheckIn(any()));
  });

  // Codex review on #4354: at large text on a narrow phone the bar wraps
  // instead of overflowing.
  testWidgets('the action bar wraps at large text on a narrow phone', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(200, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    stubDetail(checkIn());
    await withClock(Clock.fixed(now), () async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const Scaffold(
            body: CheckInDetailView(
              relationshipId: 'rel-001',
              checkInId: 'c-1',
            ),
          ),
          mediaQueryData: const MediaQueryData(
            // Narrow enough, and large enough, that the pill and the two
            // 48pt buttons cannot share a line in any font the test runs
            // with — CI's differs from a developer machine's.
            size: Size(200, 800),
            textScaler: TextScaler.linear(3),
          ),
          overrides: [
            relationshipRepositoryProvider.overrideWithValue(repository),
            checkInTranscriptionServiceProvider.overrideWithValue(
              transcription,
            ),
            audioRecorderControllerProvider.overrideWith(() => recorder),
            sortedLinkedEntriesProvider('c-1').overrideWith((ref) => links),
          ],
        ),
      );
      await tester.pumpAndSettle();
    });

    expect(tester.takeException(), isNull);
    final dictate = tester.getRect(
      find.byKey(const ValueKey('check-in-detail-dictate')),
    );
    final photo = tester.getRect(
      find.byKey(const ValueKey('check-in-detail-photo')),
    );
    expect(photo.top, greaterThan(dictate.top), reason: 'a second line');
  });

  group('the header chips edit in place', () {
    late CheckInEntry held;

    setUp(() {
      held = checkIn();
      when(() => repository.updateCheckIn(any())).thenAnswer((_) async => true);
    });

    CheckInEntry saved() =>
        verify(() => repository.updateCheckIn(captureAny())).captured.single
            as CheckInEntry;

    testWidgets('the type', (tester) async {
      stubDetail(held);
      await pump(tester);

      await tester.tap(find.byKey(const ValueKey('check-in-type')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('check-in-type-message')));
      await tester.pumpAndSettle();

      expect(saved().data.interactionType, CheckInInteractionType.message);
    });

    testWidgets('the same type again saves nothing', (tester) async {
      stubDetail(held);
      await pump(tester);

      await tester.tap(find.byKey(const ValueKey('check-in-type')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('check-in-type-call')));
      await tester.pumpAndSettle();

      verifyNever(() => repository.updateCheckIn(any()));
    });

    testWidgets('the feeling, and clearing it', (tester) async {
      stubDetail(held);
      await pump(tester);

      await tester.tap(find.byKey(const ValueKey('check-in-sentiment-chip')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('check-in-sentiment-option-delightful')),
      );
      await tester.pumpAndSettle();
      expect(saved().data.sentiment, CheckInSentiment.delightful);

      await tester.tap(find.byKey(const ValueKey('check-in-sentiment-chip')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('check-in-sentiment-clear')));
      await tester.pumpAndSettle();
      expect(saved().data.sentiment, isNull);
    });

    testWidgets('the length, kept from the start', (tester) async {
      stubDetail(held);
      await pump(tester);

      await tester.tap(find.byKey(const ValueKey('check-in-duration')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('check-in-duration-pick-45')));
      await tester.pumpAndSettle();

      final meta = saved().meta;
      expect(meta.dateFrom, held.meta.dateFrom);
      expect(meta.dateTo, held.meta.dateFrom.add(const Duration(minutes: 45)));
    });

    testWidgets('the start, keeping the length', (tester) async {
      stubDetail(held);
      await pump(tester);

      await withClock(Clock.fixed(now), () async {
        await tester.tap(find.byKey(const ValueKey('check-in-started')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();
        tester
            .widget<DesignSystemTimeWheel>(
              find.byKey(const ValueKey('check-in-time-picker')),
            )
            .onDateTimeChanged(DateTime(2026, 8, 14, 9, 30));
        await tester.tap(find.byKey(const ValueKey('check-in-time-done')));
        await tester.pumpAndSettle();
      });

      final meta = saved().meta;
      expect(meta.dateFrom, DateTime(2026, 8, 14, 9, 30));
      expect(
        meta.dateTo.difference(meta.dateFrom),
        const Duration(minutes: 11),
      );
    });

    testWidgets('a check-in with no length asks for one', (tester) async {
      stubDetail(
        held.copyWith(meta: held.meta.copyWith(dateTo: held.meta.dateFrom)),
      );
      await pump(tester);

      expect(find.text('Duration'), findsOneWidget);
    });

    testWidgets('a change that could not be saved says so', (tester) async {
      when(
        () => repository.updateCheckIn(any()),
      ).thenAnswer((_) async => false);
      stubDetail(held);
      await pump(tester);

      await tester.tap(find.byKey(const ValueKey('check-in-type')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('check-in-type-message')));
      await tester.pumpAndSettle();

      expect(
        find.text('Could not save the changes. Please try again.'),
        findsOneWidget,
      );
    });
  });
}
