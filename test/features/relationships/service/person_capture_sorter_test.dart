import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/agents/model/agent_report_provenance.dart';
import 'package:lotti/features/relationships/model/person_capture.dart';
import 'package:lotti/features/relationships/service/person_capture_sort_tool.dart';
import 'package:lotti/features/relationships/service/person_capture_sorter.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

ChatCompletionMessageToolCall _call(String arguments) =>
    ChatCompletionMessageToolCall(
      id: 'call-1',
      type: ChatCompletionMessageToolCallType.function,
      function: ChatCompletionMessageFunctionCall(
        name: personCaptureSortToolName,
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
  final provider = AiConfigInferenceProvider(
    id: 'provider-1',
    baseUrl: 'https://example.invalid',
    apiKey: 'key',
    name: 'Example Cloud',
    createdAt: now,
    inferenceProviderType: InferenceProviderType.gemini,
  );
  final model = (
    modelId: 'gemini-2.5-flash',
    provider: provider,
    route: const InferenceRouteSnapshot(
      providerModelId: 'gemini-2.5-flash',
      modelName: 'Gemini 2.5 Flash',
      servingProviderType: InferenceProviderType.gemini,
      servingProviderName: 'Example Cloud',
      runtimeSettings: {},
    ),
    supportsTools: true,
  );

  late List<({String prompt, String system, String? categoryId})> asked;
  late List<FutureOr<List<ChatCompletionMessageToolCall>> Function()> answers;
  late MockDomainLogger logger;

  setUpAll(registerAllFallbackValues);

  setUp(() {
    asked = [];
    answers = [];
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

  PersonCaptureSorter sorter({PersonCaptureModel? withModel}) =>
      PersonCaptureSorter(
        modelFor: (_) async => withModel,
        generate:
            ({
              required prompt,
              required systemMessage,
              required model,
              required categoryId,
            }) async {
              asked.add((
                prompt: prompt,
                system: systemMessage,
                categoryId: categoryId,
              ));
              return answers.removeAt(0)();
            },
        logger: logger,
      );

  String items(List<Map<String, Object?>> list) => jsonEncode({'items': list});

  test('the prompt carries the time with its weekday and zone and the '
      "person's names, never a contact channel", () {
    final prompt = personCaptureSortPrompt(
      person: pip,
      transcript: '  Coffee on Sunday at three.  ',
      now: now,
    );

    expect(prompt, contains('Now: Thursday 2026-08-13T14:05'));
    expect(prompt, contains('UTC'));
    expect(
      prompt,
      contains('<person_name>Commander Pip Frostbeak</person_name>'),
    );
    expect(prompt, contains('<person_nickname>Pip</person_nickname>'));
    expect(
      prompt,
      endsWith('<capture>\nCoffee on Sunday at three.\n</capture>'),
    );
    expect(prompt, isNot(contains('555')));
  });

  test('a person without a nickname is named once', () {
    final prompt = personCaptureSortPrompt(
      person: pip.copyWith(data: pip.data.copyWith(nickname: ' ')),
      transcript: 'Hi.',
      now: now,
    );
    expect(prompt, isNot(contains('person_nickname')));
  });

  test("sorts on the person's model, attributing the cost to their "
      'category', () async {
    answers.add(
      () => [
        _call(
          items([
            {'kind': 'note', 'text': 'Collects sextants.'},
          ]),
        ),
      ],
    );

    final result = await sorter(
      withModel: model,
    ).sort(person: pip, transcript: 'Collects sextants.', now: now);

    expect(result.outcome, PersonCaptureSortOutcome.sorted);
    expect(
      (result.items.single as PersonCaptureNote).text,
      'Collects sextants.',
    );
    expect(asked.single.system, personCaptureSortSystemMessage);
    expect(asked.single.categoryId, 'cat-1');
  });

  test('an unreadable first answer is retried once, telling the model '
      'why', () async {
    answers
      ..add(() => const [])
      ..add(() => [_call(items(const []))]);

    final result = await sorter(
      withModel: model,
    ).sort(person: pip, transcript: 'Nothing much.', now: now);

    expect(result.outcome, PersonCaptureSortOutcome.sorted);
    expect(result.items, isEmpty);
    expect(asked, hasLength(2));
    expect(
      asked.last.prompt,
      contains(
        'Your previous answer was rejected: no $personCaptureSortToolName '
        'call.',
      ),
    );
  });

  test('a second unreadable answer, or a failed request, is a failed sort, '
      'logged by its reason alone', () async {
    answers
      ..add(() => [_call('not json')])
      ..add(() => [_call('not json')]);
    final twice = await sorter(
      withModel: model,
    ).sort(person: pip, transcript: 'Secret words.', now: now);
    expect(twice.outcome, PersonCaptureSortOutcome.failed);
    verify(
      () => logger.error(
        LogDomain.ai,
        'arguments are not JSON',
        stackTrace: any<StackTrace?>(named: 'stackTrace'),
        subDomain: 'personCaptureSort',
        message: any<String>(named: 'message'),
      ),
    ).called(1);

    answers.add(() => throw StateError('offline'));
    final thrown = await sorter(
      withModel: model,
    ).sort(person: pip, transcript: 'Secret words.', now: now);
    expect(thrown.outcome, PersonCaptureSortOutcome.failed);
  });

  test('a call that does not come back in time is a failed sort', () {
    fakeAsync((async) {
      answers.add(
        () => Completer<List<ChatCompletionMessageToolCall>>().future,
      );
      PersonCaptureSort? result;
      unawaited(
        sorter(withModel: model)
            .sort(person: pip, transcript: 'Words.', now: now)
            .then((value) => result = value),
      );
      async.elapse(const Duration(minutes: 1));
      expect(result, isNull);
      async.elapse(const Duration(minutes: 1, seconds: 1));
      expect(result?.outcome, PersonCaptureSortOutcome.failed);
    });
  });

  test('no model, or one that cannot call a tool, asks nothing', () async {
    final none = await sorter().sort(person: pip, transcript: 'x', now: now);
    expect(none.outcome, PersonCaptureSortOutcome.noModel);

    final withoutTools = (
      modelId: model.modelId,
      provider: provider,
      route: model.route,
      supportsTools: false,
    );
    final unable = sorter(withModel: withoutTools);
    expect(await unable.modelFor(pip), isNull);
    expect(
      (await unable.sort(person: pip, transcript: 'x', now: now)).outcome,
      PersonCaptureSortOutcome.noModel,
    );
    expect(asked, isEmpty);
    expect(await sorter(withModel: model).modelFor(pip), model);
  });
}
