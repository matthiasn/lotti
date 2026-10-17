import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/agents/model/agent_report_provenance.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/relationships/model/person_capture.dart';
import 'package:lotti/features/relationships/repository/person_timeline_repository.dart';
import 'package:lotti/features/relationships/service/check_in_transcription_service.dart';
import 'package:lotti/features/relationships/service/person_capture_filer.dart';
import 'package:lotti/features/relationships/service/person_capture_sort_tool.dart';
import 'package:lotti/features/relationships/service/person_capture_sorter.dart';
import 'package:lotti/features/relationships/state/person_capture_providers.dart';
import 'package:lotti/features/relationships/ui/widgets/person_capture_sheet.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import '../../helpers/check_in_speech_fakes.dart';

/// Files nothing, records what it was asked to file, and hands back what
/// [remaining] says could not be.
class _FakeFiler implements PersonCaptureFiler {
  final calls = <({String audioId, List<PersonCaptureItem> items})>[];
  List<PersonCaptureItem> remaining = const [];
  Completer<void>? gate;
  bool throws = false;

  @override
  Future<List<PersonCaptureItem>> file({
    required RelationshipEntry person,
    required String audioId,
    required List<PersonCaptureItem> items,
    required DateTime now,
  }) async {
    calls.add((audioId: audioId, items: items));
    await gate?.future;
    if (throws) throw StateError('database locked');
    return remaining;
  }
}

/// A transcription service whose probe fails.
class _ThrowingProbe extends StubCheckInTranscriptionService {
  @override
  Future<bool> canTranscribe() async => throw StateError('profile store gone');
}

void main() {
  final now = DateTime(2026, 8, 13, 14, 5);
  final pip = RelationshipEntry(
    meta: Metadata(
      id: 'pip',
      createdAt: now,
      updatedAt: now,
      dateFrom: now,
      dateTo: now,
      categoryId: 'cat-1',
    ),
    data: RelationshipData(
      title: 'Commander Pip Frostbeak',
      nickname: 'Pip',
      status: RelationshipStatus.active(id: 's', createdAt: now, utcOffset: 0),
    ),
  );
  final model = (
    modelId: 'gemini-2.5-flash',
    provider: AiConfigInferenceProvider(
      id: 'provider-1',
      baseUrl: 'https://example.invalid',
      apiKey: 'key',
      name: 'Example Cloud',
      createdAt: now,
      inferenceProviderType: InferenceProviderType.gemini,
    ),
    route: const InferenceRouteSnapshot(
      providerModelId: 'gemini-2.5-flash',
      modelName: 'Gemini 2.5 Flash',
      servingProviderType: InferenceProviderType.gemini,
      servingProviderName: 'Example Cloud',
      runtimeSettings: {},
    ),
    supportsTools: true,
  );

  late FakeAudioRecorderController recorder;
  late StubCheckInTranscriptionService transcription;
  late MockPersonTimelineRepository timeline;
  late MockDomainLogger logger;
  late _FakeFiler filer;
  late PersonCaptureModel? sortModel;
  late FutureOr<List<ChatCompletionMessageToolCall>> Function() answer;
  late List<String> prompts;

  ChatCompletionMessageToolCall call(
    List<Map<String, Object?>> items, {
    String? oneLiner,
  }) => ChatCompletionMessageToolCall(
    id: 'call-1',
    type: ChatCompletionMessageToolCallType.function,
    function: ChatCompletionMessageFunctionCall(
      name: personCaptureSortToolName,
      arguments: jsonEncode({'oneLiner': ?oneLiner, 'items': items}),
    ),
  );

  final twoItems = [
    {
      'kind': 'checkIn',
      'interactionType': 'call',
      'summary': 'Talked about the launch.',
      'bringUp': 'The krill contract.',
    },
    {'kind': 'task', 'title': 'Send the draft', 'dueDate': '2026-08-20'},
  ];

  setUpAll(registerAllFallbackValues);

  setUp(() {
    recorder = FakeAudioRecorderController();
    transcription = StubCheckInTranscriptionService(
      transcript: 'Called Pip about the launch. Send the draft by Thursday.',
    );
    timeline = MockPersonTimelineRepository();
    logger = MockDomainLogger();
    filer = _FakeFiler();
    sortModel = model;
    prompts = [];
    answer = () => [call(twoItems)];
    when(
      () => timeline.addToTimeline(
        personId: any(named: 'personId'),
        entryId: any(named: 'entryId'),
      ),
    ).thenAnswer((_) async => true);
    when(
      () => timeline.saveVoiceNoteSummary(
        audioId: any(named: 'audioId'),
        summary: any(named: 'summary'),
        modelId: any(named: 'modelId'),
        categoryId: any(named: 'categoryId'),
      ),
    ).thenAnswer((_) async => true);
    when(
      () => logger.error(
        any<LogDomain>(),
        any<Object>(),
        stackTrace: any<StackTrace?>(named: 'stackTrace'),
        subDomain: any<String>(named: 'subDomain'),
        message: any<String>(named: 'message'),
      ),
    ).thenAnswer((_) async {});
  });

  /// The recorder's level meter and the spinners animate for as long as
  /// they are up, so the tree never settles: pump a bounded while instead.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> open(
    WidgetTester tester, {
    ({String audioId, String transcript})? sortAgain,
  }) async {
    final sorter = PersonCaptureSorter(
      modelFor: (_) async => sortModel,
      generate:
          ({
            required prompt,
            required systemMessage,
            required model,
            required categoryId,
          }) async {
            prompts.add(prompt);
            return answer();
          },
    );
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        Builder(
          builder: (context) => TextButton(
            key: const ValueKey('open'),
            onPressed: () => showPersonCaptureSheet(
              context: context,
              person: pip,
              sortAgain: sortAgain,
            ),
            child: const Text('open'),
          ),
        ),
        overrides: [
          audioRecorderControllerProvider.overrideWith(() => recorder),
          checkInTranscriptionServiceProvider.overrideWithValue(transcription),
          personTimelineRepositoryProvider.overrideWithValue(timeline),
          personCaptureSorterProvider.overrideWithValue(sorter),
          personCaptureFilerProvider.overrideWithValue(filer),
          domainLoggerProvider.overrideWithValue(logger),
        ],
      ),
    );
    await withClock(Clock.fixed(now), () async {
      await tester.tap(find.byKey(const ValueKey('open')));
      await settle(tester);
    });
  }

  Future<void> stop(WidgetTester tester) => withClock(
    Clock.fixed(now),
    () async {
      await tester.tap(find.byKey(const ValueKey('check-in-recorder-stop')));
      await settle(tester);
    },
  );

  /// Taps [key], scrolled into view first: the sheet's actions sit under
  /// the review, below a test surface's fold.
  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(ValueKey(key)));
    await tester.pump();
    await tester.tap(find.byKey(ValueKey(key)));
  }

  DesignSystemButton button(WidgetTester tester, String key) =>
      tester.widget(find.byKey(ValueKey(key)));

  testWidgets('opens recording for the person, saying what a capture can be '
      'and where it will be sorted before anything is sent', (tester) async {
    await open(tester);

    expect(find.text('Speak about Pip'), findsOneWidget);
    expect(
      find.text('A conversation you had, something to remember, or a plan.'),
      findsOneWidget,
    );
    expect(
      find.text('Sorted by Gemini 2.5 Flash · via Example Cloud'),
      findsOneWidget,
    );
    expect(recorder.recordCalls.single.linkedId, 'pip');
    expect(recorder.categoryIds, contains('cat-1'));
    expect(prompts, isEmpty);
  });

  testWidgets('with no model to sort with, the caption says it stays a '
      'voice note', (tester) async {
    sortModel = null;
    await open(tester);

    expect(
      find.text('No model to sort with — it stays a voice note.'),
      findsOneWidget,
    );
  });

  testWidgets('stopping puts the recording on the timeline, then its words '
      'are sorted for review, every item accepted', (tester) async {
    await open(tester);
    await stop(tester);

    verify(
      () => timeline.addToTimeline(personId: 'pip', entryId: 'audio-1'),
    ).called(1);
    expect(transcription.transcribeCalls, ['audio-1']);
    expect(transcription.transcribePeople, ['pip']);
    expect(prompts.single, contains('Called Pip about the launch.'));
    expect(find.text("Here's what I heard"), findsOneWidget);
    expect(
      find.text('Called Pip about the launch. Send the draft by Thursday.'),
      findsOneWidget,
    );
    expect(find.text('Log as a check-in'), findsOneWidget);
    expect(find.text('Talked about the launch.'), findsOneWidget);
    expect(find.text('Add a task'), findsOneWidget);
    expect(find.text('Send the draft'), findsOneWidget);
    expect(find.text('File 2 items'), findsOneWidget);
  });

  testWidgets("the sort's one line is saved as the voice note's summary "
      'before the review opens; without one nothing is saved', (tester) async {
    answer = () => [call(twoItems, oneLiner: 'Pip called about the launch.')];
    await open(tester);
    await stop(tester);

    verify(
      () => timeline.saveVoiceNoteSummary(
        audioId: 'audio-1',
        summary: 'Pip called about the launch.',
        modelId: 'gemini-2.5-flash',
        categoryId: 'cat-1',
      ),
    ).called(1);
    expect(find.text("Here's what I heard"), findsOneWidget);
  });

  testWidgets('a summary that cannot be saved is logged, and the review '
      'still opens', (tester) async {
    answer = () => [call(twoItems, oneLiner: 'Pip called.')];
    when(
      () => timeline.saveVoiceNoteSummary(
        audioId: any(named: 'audioId'),
        summary: any(named: 'summary'),
        modelId: any(named: 'modelId'),
        categoryId: any(named: 'categoryId'),
      ),
    ).thenThrow(StateError('database locked'));
    await open(tester);
    await stop(tester);

    expect(find.text("Here's what I heard"), findsOneWidget);
    verify(
      () => logger.error(
        LogDomain.general,
        any<Object>(),
        stackTrace: any<StackTrace?>(named: 'stackTrace'),
        subDomain: 'PersonCaptureSheet',
        message: any<String>(named: 'message'),
      ),
    ).called(1);
  });

  testWidgets('Save files exactly the accepted items and closes', (
    tester,
  ) async {
    await open(tester);
    await stop(tester);

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('person-capture-item-1')),
        matching: find.byKey(const ValueKey('person-capture-item-toggle')),
      ),
    );
    await settle(tester);
    expect(find.text('File 1 item'), findsOneWidget);
    await tapKey(tester, 'person-capture-file');
    await settle(tester);

    final filed = filer.calls.single;
    expect(filed.audioId, 'audio-1');
    expect(filed.items.single, isA<PersonCaptureCheckIn>());
    expect(
      (filed.items.single as PersonCaptureCheckIn).interactionType,
      CheckInInteractionType.call,
    );
    expect(find.text("Here's what I heard"), findsNothing);
    expect(recorder.modalVisibleLog.last, isFalse);
  });

  testWidgets('an item edited in review is filed as edited', (tester) async {
    await open(tester);
    await stop(tester);

    await tapKey(tester, 'person-capture-check-in-type');
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('check-in-type-inPerson')));
    await settle(tester);
    await tapKey(tester, 'person-capture-file');
    await settle(tester);

    expect(
      (filer.calls.single.items.first as PersonCaptureCheckIn).interactionType,
      CheckInInteractionType.inPerson,
    );
  });

  testWidgets('with everything set aside there is nothing to file', (
    tester,
  ) async {
    await open(tester);
    await stop(tester);
    for (final index in [0, 1]) {
      await tester.tap(
        find.descendant(
          of: find.byKey(ValueKey('person-capture-item-$index')),
          matching: find.byKey(const ValueKey('person-capture-item-toggle')),
        ),
      );
      await settle(tester);
    }

    expect(button(tester, 'person-capture-file').onPressed, isNull);
  });

  testWidgets('what could not be filed stays in review, said so, and the '
      'sheet holds while the filing runs', (tester) async {
    filer
      ..gate = Completer<void>()
      ..remaining = const [PersonCaptureTask(title: 'Send the draft')];
    await open(tester);
    await stop(tester);

    await tapKey(tester, 'person-capture-file');
    await tester.pump();
    expect(button(tester, 'person-capture-keep').onPressed, isNull);
    await tester.tap(find.byTooltip('Close'));
    await settle(tester);
    expect(find.text("Here's what I heard"), findsOneWidget);

    filer.gate!.complete();
    await settle(tester);
    expect(
      find.text('Some items could not be filed. They are still here.'),
      findsOneWidget,
    );
    expect(find.text('Send the draft'), findsOneWidget);
    expect(find.text('Talked about the launch.'), findsNothing);
    expect(find.text('File 1 item'), findsOneWidget);
  });

  testWidgets('a filing that throws leaves the sheet usable, everything '
      'still in review', (tester) async {
    filer.throws = true;
    await open(tester);
    await stop(tester);

    await tapKey(tester, 'person-capture-file');
    await settle(tester);

    expect(
      find.text('Some items could not be filed. They are still here.'),
      findsOneWidget,
    );
    expect(find.text('File 2 items'), findsOneWidget);
    expect(button(tester, 'person-capture-file').onPressed, isNotNull);
    expect(button(tester, 'person-capture-keep').onPressed, isNotNull);
  });

  testWidgets('Keep as a voice note closes without filing', (tester) async {
    await open(tester);
    await stop(tester);

    await tapKey(tester, 'person-capture-keep');
    await settle(tester);

    expect(filer.calls, isEmpty);
    expect(find.text("Here's what I heard"), findsNothing);
  });

  for (final (name, setUpCase, copy) in <(String, void Function(), String)>[
    (
      'nothing can transcribe',
      () => transcription.canTranscribeResult = false,
      'Saved as a voice note. Nothing can transcribe it yet.',
    ),
    (
      'no words came',
      () => transcription.transcript = '  ',
      'Saved as a voice note. No words came through.',
    ),
    (
      'no model can sort',
      () => sortModel = null,
      'Saved as a voice note, with its words. No model can sort it.',
    ),
    (
      'the sort fails',
      () => answer = () => throw StateError('offline'),
      'Saved as a voice note, with its words. Sorting did not work — use '
          'Sort this on its row to try again.',
    ),
    (
      'nothing is filed separately',
      () => answer = () => [call(const [])],
      'Saved as a voice note — nothing in it to file on its own.',
    ),
  ]) {
    testWidgets('when $name, it says the capture stayed a voice note, and '
        'Done closes', (tester) async {
      setUpCase();
      await open(tester);
      await stop(tester);

      expect(find.text(copy), findsOneWidget);
      verify(
        () => timeline.addToTimeline(personId: 'pip', entryId: 'audio-1'),
      ).called(1);
      await tapKey(tester, 'person-capture-done');
      await settle(tester);
      expect(find.text(copy), findsNothing);
    });
  }

  testWidgets('while its words come it says it is listening, then sorting', (
    tester,
  ) async {
    final words = Completer<String?>();
    transcription = StubCheckInTranscriptionService(gate: words);
    final sorted = Completer<List<ChatCompletionMessageToolCall>>();
    answer = () => sorted.future;
    await open(tester);
    await stop(tester);

    expect(find.text('Listening back…'), findsOneWidget);
    words.complete('Called Pip.');
    await tester.pump();
    await tester.pump();
    expect(find.text('Sorting what you said…'), findsOneWidget);
    sorted.complete([call(twoItems)]);
    await settle(tester);
    expect(find.text("Here's what I heard"), findsOneWidget);
  });

  testWidgets('a voice note the timeline could not take stops the capture '
      'there, says where the recording is, and is logged', (tester) async {
    when(
      () => timeline.addToTimeline(
        personId: any(named: 'personId'),
        entryId: any(named: 'entryId'),
      ),
    ).thenAnswer((_) async => false);
    await open(tester);
    await stop(tester);

    expect(
      find.text(
        "The recording is saved in your journal, but it could not be put on Pip's timeline.",
      ),
      findsOneWidget,
    );
    expect(transcription.transcribeCalls, isEmpty);
    expect(prompts, isEmpty);
    await tapKey(tester, 'person-capture-done');
    await settle(tester);
    expect(find.text('Speak about Pip'), findsNothing);
    verify(
      () => logger.error(
        LogDomain.general,
        any<Object>(),
        stackTrace: any<StackTrace?>(named: 'stackTrace'),
        subDomain: 'PersonCaptureSheet',
        message: any<String>(named: 'message'),
      ),
    ).called(1);
  });

  testWidgets('a transcription probe that throws keeps the voice note', (
    tester,
  ) async {
    transcription = _ThrowingProbe();
    await open(tester);
    await stop(tester);

    expect(
      find.text('Saved as a voice note. Nothing can transcribe it yet.'),
      findsOneWidget,
    );
  });

  testWidgets('a timeline write that throws is logged too', (tester) async {
    when(
      () => timeline.addToTimeline(
        personId: any(named: 'personId'),
        entryId: any(named: 'entryId'),
      ),
    ).thenThrow(StateError('database locked'));
    await open(tester);
    await stop(tester);

    expect(
      find.text(
        "The recording is saved in your journal, but it could not be put on Pip's timeline.",
      ),
      findsOneWidget,
    );
    expect(transcription.transcribeCalls, isEmpty);
  });

  testWidgets('discarding the recording closes the sheet, writing nothing', (
    tester,
  ) async {
    await open(tester);

    await tester.tap(find.byKey(const ValueKey('check-in-recorder-discard')));
    await settle(tester);
    await tester.tap(find.text('Discard'));
    await settle(tester);

    expect(recorder.cancelCalls, 1);
    expect(find.text('Speak about Pip'), findsNothing);
    verifyNever(
      () => timeline.addToTimeline(
        personId: any(named: 'personId'),
        entryId: any(named: 'entryId'),
      ),
    );
  });

  testWidgets('while recording the sheet holds against its close', (
    tester,
  ) async {
    await open(tester);

    await tester.tap(find.byTooltip('Close'));
    await settle(tester);

    expect(find.text('Speak about Pip'), findsOneWidget);
  });

  testWidgets('a refused microphone says so, and Done closes', (tester) async {
    recorder.recordFailure = AudioRecordingFailure.permissionDenied;
    await open(tester);

    expect(find.byKey(const ValueKey('person-capture-ending')), findsOneWidget);
    await tapKey(tester, 'person-capture-done');
    await settle(tester);
    expect(find.text('Speak about Pip'), findsNothing);
  });

  testWidgets('Sort this opens straight on sorting the voice note it is on', (
    tester,
  ) async {
    await open(
      tester,
      sortAgain: (audioId: 'audio-9', transcript: 'Old words.'),
    );

    expect(recorder.recordCalls, isEmpty);
    expect(prompts.single, contains('Old words.'));
    expect(find.text("Here's what I heard"), findsOneWidget);
    await tapKey(tester, 'person-capture-file');
    await settle(tester);
    expect(filer.calls.single.audioId, 'audio-9');
  });
}
