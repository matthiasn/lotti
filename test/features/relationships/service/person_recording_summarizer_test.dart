import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/agents/model/agent_report_provenance.dart';
import 'package:lotti/features/relationships/service/person_capture_sort_tool.dart';
import 'package:lotti/features/relationships/service/person_capture_sorter.dart';
import 'package:lotti/features/relationships/service/person_recording_summarizer.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

ChatCompletionMessageToolCall _call(
  String arguments, {
  String name = personRecordingSummaryToolName,
}) => ChatCompletionMessageToolCall(
  id: 'call-1',
  type: ChatCompletionMessageToolCallType.function,
  function: ChatCompletionMessageFunctionCall(
    name: name,
    arguments: arguments,
  ),
);

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
      contactChannels: const [
        ContactChannel(type: ContactChannelType.phone, value: '+1 555 0100'),
      ],
    ),
  );
  final model = (
    modelId: 'glm-5.2',
    provider: AiConfigInferenceProvider(
      id: 'provider-1',
      baseUrl: 'https://example.invalid',
      apiKey: 'key',
      name: 'Melious',
      createdAt: now,
      inferenceProviderType: InferenceProviderType.melious,
    ),
    route: const InferenceRouteSnapshot(
      providerModelId: 'glm-5.2',
      modelName: 'GLM 5.2',
      servingProviderType: InferenceProviderType.melious,
      servingProviderName: 'Melious',
      runtimeSettings: {},
    ),
    supportsTools: true,
  );
  final longWords = [
    for (var i = 1; i <= 8; i++) 'Sentence $i of what Pip said on the call.',
  ].join(' ');

  late List<String> prompts;
  late List<FutureOr<List<ChatCompletionMessageToolCall>> Function()> answers;
  late List<({String audioId, String summary, String modelId, String? cat})>
  saved;
  late MockDomainLogger logger;
  late bool hasSummary;

  setUpAll(registerAllFallbackValues);

  setUp(() {
    prompts = [];
    answers = [];
    saved = [];
    hasSummary = false;
    logger = MockDomainLogger();
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

  PersonRecordingSummarizer summarizer({PersonCaptureModel? withModel}) =>
      PersonRecordingSummarizer(
        modelFor: (_) async => withModel,
        generate:
            ({
              required prompt,
              required systemMessage,
              required model,
              required categoryId,
            }) async {
              prompts.add(prompt);
              return answers.removeAt(0)();
            },
        save:
            ({
              required audioId,
              required summary,
              required modelId,
              required categoryId,
            }) async {
              saved.add((
                audioId: audioId,
                summary: summary,
                modelId: modelId,
                cat: categoryId,
              ));
              return true;
            },
        hasSummary: (_) async => hasSummary,
        logger: logger,
      );

  String line(String text) => jsonEncode({'oneLiner': text});

  test('the prompt carries the names and the words, each tagged, never a '
      'contact channel', () {
    final prompt = personRecordingSummaryPrompt(
      person: pip,
      transcript: '  Words.  ',
    );
    expect(
      prompt,
      '<person_name>Commander Pip Frostbeak</person_name>\n'
      '<person_nickname>Pip</person_nickname>\n'
      '<recording>\nWords.\n</recording>',
    );
    expect(prompt, isNot(contains('555')));
    expect(
      personRecordingSummaryPrompt(
        person: pip.copyWith(data: pip.data.copyWith(nickname: null)),
        transcript: 'Words.',
      ),
      isNot(contains('person_nickname')),
    );
  });

  test('writes the line on the briefing model and saves it as the '
      "recording's summary, in the person's category", () async {
    answers.add(() => [_call(line('  Pip is calm about the slip.  '))]);

    expect(
      await summarizer(
        withModel: model,
      ).summarize(person: pip, audioId: 'audio-1', transcript: longWords),
      isTrue,
    );
    expect(saved.single, (
      audioId: 'audio-1',
      summary: 'Pip is calm about the slip.',
      modelId: 'glm-5.2',
      cat: 'cat-1',
    ));
    expect(prompts.single, contains(longWords));
  });

  test('a recording short enough to be its own summary, or one that has '
      'one, asks nothing', () async {
    expect(
      await summarizer(
        withModel: model,
      ).summarize(person: pip, audioId: 'a', transcript: 'Short call.'),
      isFalse,
    );
    hasSummary = true;
    expect(
      await summarizer(
        withModel: model,
      ).summarize(person: pip, audioId: 'a', transcript: longWords),
      isFalse,
    );
    expect(prompts, isEmpty);
    expect(saved, isEmpty);
  });

  test('no model, or one that cannot call a tool, asks nothing', () async {
    expect(
      await summarizer().summarize(
        person: pip,
        audioId: 'a',
        transcript: longWords,
      ),
      isFalse,
    );
    final noTools = (
      modelId: model.modelId,
      provider: model.provider,
      route: model.route,
      supportsTools: false,
    );
    expect(
      await summarizer(
        withModel: noTools,
      ).summarize(person: pip, audioId: 'a', transcript: longWords),
      isFalse,
    );
    expect(prompts, isEmpty);
  });

  test('an unreadable answer is retried once, telling the model why', () async {
    answers
      ..add(() => [_call(line('   '))])
      ..add(() => [_call(line('Pip is calm.'))]);

    await summarizer(
      withModel: model,
    ).summarize(person: pip, audioId: 'a', transcript: longWords);

    expect(prompts.last, contains('oneLiner is missing or empty'));
    expect(saved.single.summary, 'Pip is calm.');
  });

  test('a second rejection, or a failed call, saves nothing and is logged '
      'by its reason alone', () async {
    answers
      ..add(() => [_call('not json')])
      ..add(() => const []);
    expect(
      await summarizer(
        withModel: model,
      ).summarize(person: pip, audioId: 'a', transcript: longWords),
      isFalse,
    );
    verify(
      () => logger.error(
        LogDomain.ai,
        'no $personRecordingSummaryToolName call',
        stackTrace: any<StackTrace?>(named: 'stackTrace'),
        subDomain: 'personRecordingSummary',
        message: any<String>(named: 'message'),
      ),
    ).called(1);
    expect(saved, isEmpty);
  });

  test('one deadline covers both attempts: a retry gets what is left of '
      'it, not a fresh one', () {
    fakeAsync((async) {
      answers
        ..add(
          () => Future<List<ChatCompletionMessageToolCall>>.delayed(
            const Duration(seconds: 90),
            () => [_call('not json')],
          ),
        )
        ..add(() => Completer<List<ChatCompletionMessageToolCall>>().future);
      bool? result;
      unawaited(
        summarizer(withModel: model)
            .summarize(person: pip, audioId: 'a', transcript: longWords)
            .then((value) => result = value),
      );
      async.elapse(const Duration(seconds: 100));
      expect(prompts, hasLength(2), reason: 'the retry was asked');
      expect(result, isNull);
      async.elapse(const Duration(seconds: 21));
      expect(result, isFalse, reason: 'two minutes in all, not four');
    });
  });

  test('a call that does not come back in time saves nothing', () {
    fakeAsync((async) {
      answers.add(
        () => Completer<List<ChatCompletionMessageToolCall>>().future,
      );
      bool? result;
      unawaited(
        summarizer(withModel: model)
            .summarize(person: pip, audioId: 'a', transcript: longWords)
            .then((value) => result = value),
      );
      async.elapse(const Duration(minutes: 2, seconds: 1));
      expect(result, isFalse);
    });
  });

  test('the line is cut to its length, and the call read by its name', () {
    expect(
      parsePersonRecordingSummaryToolCall([
        _call(line('x' * 400)),
      ]).length,
      personCaptureOneLinerMaxChars,
    );
    for (final (calls, reason) in [
      (<ChatCompletionMessageToolCall>[], 'no'),
      ([_call(line('x'), name: 'other')], 'no'),
      ([_call('[1]')], 'oneLiner'),
      (
        [
          _call(jsonEncode({'oneLiner': 7})),
        ],
        'oneLiner',
      ),
    ]) {
      expect(
        () => parsePersonRecordingSummaryToolCall(calls),
        throwsA(
          isA<PersonCaptureSortToolException>().having(
            (e) => e.reason,
            'reason',
            contains(reason),
          ),
        ),
      );
    }
    expect(personRecordingSummaryToolChoiceFor('glm-5.2'), isNotNull);
    expect(
      personRecordingSummaryTool.function.name,
      personRecordingSummaryToolName,
    );
  });
}
