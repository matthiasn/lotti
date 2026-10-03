import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/pull_request_data.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/github/domain/pull_request_ref.dart';
import 'package:lotti/features/github/domain/pull_request_summary_input.dart';
import 'package:lotti/features/github/service/pull_request_summarizer.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../pull_request_fixtures.dart';

void main() {
  const ref = PullRequestRef(owner: 'matthiasn', repo: 'lotti', number: 42);
  const entryId = 'pull-request-entry';

  final provider =
      AiConfig.inferenceProvider(
            id: 'provider',
            name: 'Cloud',
            baseUrl: 'https://example.invalid',
            inferenceProviderType: InferenceProviderType.openAi,
            apiKey: 'key',
            createdAt: DateTime(2026, 3, 15),
          )
          as AiConfigInferenceProvider;

  final mergedSnapshot = prSnapshot(
    status: PullRequestStatus.merged,
  ).copyWith(body: 'Adds pull request tracking.');
  // In a category of its own: a pull request can serve tasks in several
  // categories, and the call is the consenting task's, not the entry's.
  final linked = prEntry(clock: {'a': 1}, snapshot: mergedSnapshot);
  final merged = linked.copyWith(
    meta: linked.meta.copyWith(categoryId: 'category-of-the-entry'),
  );
  final input = pullRequestSummaryInput(ref, mergedSnapshot);

  late MockPullRequestRepository repository;
  late MockDomainLogger logger;
  late Set<String> allowedTasks;
  late Map<String, PullRequestSummaryModel> models;
  late List<Map<String, Object?>> asked;
  late Future<String> Function() answer;
  late PullRequestSummarizer summarizer;

  setUpAll(() {
    registerAllFallbackValues();
    registerFallbackValue(merged);
    registerFallbackValue(
      const AiResponseData(
        model: '',
        systemMessage: '',
        prompt: '',
        thoughts: '',
        response: '',
      ),
    );
  });

  setUp(() {
    repository = MockPullRequestRepository();
    logger = MockDomainLogger();
    allowedTasks = {'task-a', 'task-b'};
    models = {
      'task-a': (modelId: 'model-a', provider: provider),
      'task-b': (modelId: 'model-b', provider: provider),
    };
    asked = [];
    answer = () async => 'Tracks pull requests on tasks.';
    summarizer = PullRequestSummarizer(
      repository: repository,
      consentingCategory: (taskId) async =>
          allowedTasks.contains(taskId) ? 'category-of-$taskId' : null,
      modelFor: (taskId) async => models[taskId],
      generate:
          ({
            required prompt,
            required systemMessage,
            required model,
            required taskId,
            required categoryId,
          }) {
            asked.add({
              'prompt': prompt,
              'systemMessage': systemMessage,
              'model': model.modelId,
              'taskId': taskId,
              'categoryId': categoryId,
            });
            return answer();
          },
      logger: logger,
    );

    when(() => repository.liveEntry(entryId)).thenAnswer((_) async => merged);
    when(
      () => repository.summaryOf(entryId, any()),
    ).thenAnswer((_) async => null);
    when(() => repository.holdersOf(any())).thenAnswer(
      (_) async => {
        ref.key: {'task-b', 'task-a'},
      },
    );
    when(
      () => repository.addSummary(any(), any(), start: any(named: 'start')),
    ).thenAnswer((_) async => true);
  });

  AiResponseData stored() =>
      verify(
            () => repository.addSummary(
              merged,
              captureAny(),
              start: any(named: 'start'),
            ),
          ).captured.single
          as AiResponseData;

  test(
    'a merged pull request with no summary is summarised from its content, '
    "with the model of the first task that allows it, in that task's "
    'category, and the summary is stored with that content as its prompt',
    () async {
      expect(await summarizer.summarize(entryId), isTrue);

      expect(asked, [
        {
          'prompt': input,
          'systemMessage': pullRequestSummarySystemMessage,
          'model': 'model-a',
          'taskId': 'task-a',
          'categoryId': 'category-of-task-a',
        },
      ]);
      expect(
        stored(),
        AiResponseData(
          model: 'model-a',
          systemMessage: pullRequestSummarySystemMessage,
          prompt: input,
          thoughts: '',
          response: 'Tracks pull requests on tasks.',
          type: AiResponseType.pullRequestSummary,
          tldr: 'Tracks pull requests on tasks.',
        ),
      );
    },
  );

  test(
    'a summary of the same content is not asked for again — what a restamp '
    'or a change of checks leaves behind',
    () async {
      when(
        () => repository.summaryOf(entryId, input),
      ).thenAnswer((_) async => 'Already summarised.');

      expect(await summarizer.summarize(entryId), isFalse);
      expect(asked, isEmpty);
    },
  );

  test('an open pull request, or none stored, is not summarised', () async {
    for (final entry in [
      prEntry(clock: {'a': 1}, snapshot: prSnapshot()),
      prEntry(clock: {'a': 1}),
      null,
    ]) {
      when(() => repository.liveEntry(entryId)).thenAnswer((_) async => entry);
      expect(await summarizer.summarize(entryId), isFalse);
    }
    expect(asked, isEmpty);
  });

  test(
    'only a task whose category allows automatic inference, and that has '
    'a model, is summarised for',
    () async {
      allowedTasks = {'task-b'};
      expect(await summarizer.summarize(entryId), isTrue);
      expect(asked.single['taskId'], 'task-b');
      expect(asked.single['model'], 'model-b');
      expect(asked.single['categoryId'], 'category-of-task-b');

      asked.clear();
      models.remove('task-b');
      expect(await summarizer.summarize(entryId), isFalse);

      allowedTasks = {};
      models['task-b'] = (modelId: 'model-b', provider: provider);
      expect(await summarizer.summarize(entryId), isFalse);
      expect(asked, isEmpty);
    },
  );

  test('nothing is asked for a pull request no task holds', () async {
    when(() => repository.holdersOf(any())).thenAnswer((_) async => {});
    expect(await summarizer.summarize(entryId), isFalse);
    expect(asked, isEmpty);
  });

  test(
    'an answer that runs long is stored on one line, cut at the summary '
    'limit, so neither the entry nor what syncs grows with it',
    () async {
      answer = () async => 'Line one.\n\n${'z' * pullRequestSummaryLimit}';

      expect(await summarizer.summarize(entryId), isTrue);

      final data = stored();
      expect(data.tldr, hasLength(pullRequestSummaryLimit + 2));
      expect(data.tldr, startsWith('Line one. zzz'));
      expect(data.tldr, endsWith(' …'));
      expect(data.response, data.tldr);
    },
  );

  test('an empty answer is not stored', () async {
    answer = () async => '';
    expect(await summarizer.summarize(entryId), isFalse);
    verifyNever(
      () => repository.addSummary(any(), any(), start: any(named: 'start')),
    );
  });

  test(
    'a pull request unlinked, or changed, while the model wrote is not '
    'given the summary',
    () async {
      for (final after in [
        null,
        prEntry(
          clock: {'a': 2},
          snapshot: mergedSnapshot.copyWith(body: 'Rewritten after merge.'),
        ),
      ]) {
        var reads = 0;
        when(
          () => repository.liveEntry(entryId),
        ).thenAnswer((_) async => reads++ == 0 ? merged : after);

        expect(await summarizer.summarize(entryId), isFalse);
      }
      verifyNever(
        () => repository.addSummary(any(), any(), start: any(named: 'start')),
      );
    },
  );

  test(
    'a failed request is logged and reported, never thrown, and the next '
    'refresh may ask again',
    () async {
      answer = () async => throw Exception('provider down');

      expect(await summarizer.summarize(entryId), isFalse);
      verify(
        () => logger.error(
          any(),
          any(),
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'pullRequestSummary',
        ),
      ).called(1);

      answer = () async => 'Tracks pull requests on tasks.';
      expect(await summarizer.summarize(entryId), isTrue);
    },
  );

  test(
    'a second request while one runs for the same pull request is dropped',
    () async {
      final gate = Completer<String>();
      answer = () => gate.future;

      final first = summarizer.summarize(entryId);
      expect(await summarizer.summarize(entryId), isFalse);
      gate.complete('Tracks pull requests on tasks.');

      expect(await first, isTrue);
      expect(asked, hasLength(1));
    },
  );
}
