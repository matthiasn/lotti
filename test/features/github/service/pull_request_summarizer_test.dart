import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/ai_response_type.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/github/pull_request_ref.dart';
import 'package:lotti/classes/pull_request_data.dart';
import 'package:lotti/features/github/domain/pull_request_summary.dart';
import 'package:lotti/features/github/service/pull_request_summarizer.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../agents/test_data/ai_config_factories.dart';
import '../pull_request_fixtures.dart';

void main() {
  const ref = PullRequestRef(owner: 'matthiasn', repo: 'lotti', number: 42);
  const entryId = 'pull-request-entry';

  final provider = testInferenceProvider(apiKey: 'k-1');

  final mergedSnapshot = prSnapshot(
    status: PullRequestStatus.merged,
  ).copyWith(body: 'Adds pull request tracking.');
  // In a category of its own: a pull request can serve tasks in several
  // categories, and the call is the asking task's, not the entry's.
  final linked = prEntry(clock: {'a': 1}, snapshot: mergedSnapshot);
  final merged = linked.copyWith(
    meta: linked.meta.copyWith(categoryId: 'category-of-the-entry'),
  );
  final input = pullRequestSummaryInput(ref, mergedSnapshot);

  late MockPullRequestRepository repository;
  late MockDomainLogger logger;
  late Map<String, PullRequestSummaryTask> tasks;
  late Map<String, PullRequestSummaryModel> models;
  late List<Map<String, Object?>> asked;
  late List<Future<List<ChatCompletionMessageToolCall>> Function()> answers;
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
    tasks = {
      'task-a': (
        categoryId: 'category-a',
        automaticInference: true,
        languageCode: 'de',
      ),
      'task-b': (
        categoryId: 'category-b',
        automaticInference: true,
        languageCode: null,
      ),
    };
    models = {
      'task-a': (modelId: 'model-a', provider: provider),
      'task-b': (modelId: 'model-b', provider: provider),
    };
    asked = [];
    answers = [];
    summarizer = PullRequestSummarizer(
      repository: repository,
      taskOf: (taskId) async => tasks[taskId]!,
      modelFor: (taskId) async => models[taskId],
      generate:
          ({
            required prompt,
            required systemMessage,
            required model,
            required taskId,
            required categoryId,
            required manual,
          }) {
            asked.add({
              'prompt': prompt,
              'systemMessage': systemMessage,
              'model': model.modelId,
              'taskId': taskId,
              'categoryId': categoryId,
              'manual': manual,
            });
            return answers.isEmpty
                ? Future.value([summaryToolCall()])
                : answers.removeAt(0)();
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
          ).captured.last
          as AiResponseData;

  void neverStored() => verifyNever(
    () => repository.addSummary(any(), any(), start: any(named: 'start')),
  );

  const tldr =
      'Links pull requests to tasks and refreshes them from GitHub. Merged '
      'after one round of requested changes.';

  test(
    'a pull request with no summary is summarised from its content in two '
    "tiers, with the first allowing task's model, in that task's category, "
    'and stored with that content as its prompt',
    () async {
      expect(
        await summarizer.summarize(entryId),
        PullRequestSummaryOutcome.stored,
      );

      expect(asked, [
        {
          'prompt': input,
          'systemMessage': pullRequestSummaryInstructions('de'),
          'model': 'model-a',
          'taskId': 'task-a',
          'categoryId': 'category-a',
          'manual': false,
        },
      ]);
      expect(
        stored(),
        AiResponseData(
          model: 'model-a',
          systemMessage: pullRequestSummaryInstructions('de'),
          prompt: input,
          thoughts: '',
          response: tldr,
          type: AiResponseType.pullRequestSummary,
          oneLiner: 'Tracks pull requests on tasks.',
          tldr: tldr,
        ),
      );
    },
  );

  test('an open pull request is summarised too', () async {
    final open = prEntry(clock: {'a': 1}, snapshot: prSnapshot());
    when(() => repository.liveEntry(entryId)).thenAnswer((_) async => open);

    expect(
      await summarizer.summarize(entryId),
      PullRequestSummaryOutcome.stored,
    );
    expect(asked.single['prompt'], contains('State: open'));
  });

  test(
    'a summary of the same content is not asked for again — what a restamp '
    'or a change of checks leaves behind',
    () async {
      when(() => repository.summaryOf(entryId, input)).thenAnswer(
        (_) async => const PullRequestSummary(oneLiner: null, tldr: 'Done.'),
      );

      expect(
        await summarizer.summarize(entryId),
        PullRequestSummaryOutcome.upToDate,
      );
      expect(asked, isEmpty);
    },
  );

  test(
    'asked by the user, it summarises again even then, with no category '
    'consent, and the call is manual work',
    () async {
      when(() => repository.summaryOf(entryId, input)).thenAnswer(
        (_) async => const PullRequestSummary(oneLiner: null, tldr: 'Done.'),
      );
      tasks = {
        'task-a': (
          categoryId: 'category-a',
          automaticInference: false,
          languageCode: null,
        ),
        'task-b': (
          categoryId: null,
          automaticInference: false,
          languageCode: null,
        ),
      };

      expect(
        await summarizer.summarize(entryId, manual: true),
        PullRequestSummaryOutcome.stored,
      );
      expect(asked.single['manual'], isTrue);
      expect(asked.single['categoryId'], 'category-a');
    },
  );

  test('a pull request unlinked, or never read, is missing', () async {
    for (final entry in [
      prEntry(clock: {'a': 1}),
      null,
    ]) {
      when(() => repository.liveEntry(entryId)).thenAnswer((_) async => entry);
      expect(
        await summarizer.summarize(entryId),
        PullRequestSummaryOutcome.missing,
      );
    }
    expect(asked, isEmpty);
  });

  test(
    'automatically, only a task whose category allows it, and that has a '
    'model, is summarised for',
    () async {
      tasks['task-a'] = (
        categoryId: 'category-a',
        automaticInference: false,
        languageCode: 'de',
      );
      expect(
        await summarizer.summarize(entryId),
        PullRequestSummaryOutcome.stored,
      );
      expect(
        (asked.single['taskId'], asked.single['model']),
        (
          'task-b',
          'model-b',
        ),
      );

      asked.clear();
      models.remove('task-b');
      expect(
        await summarizer.summarize(entryId),
        PullRequestSummaryOutcome.noModel,
      );

      for (final id in ['task-a', 'task-b']) {
        tasks[id] = (
          categoryId: null,
          automaticInference: false,
          languageCode: null,
        );
      }
      expect(
        await summarizer.summarize(entryId),
        PullRequestSummaryOutcome.notAllowed,
      );
      expect(asked, isEmpty);
    },
  );

  test('nothing is asked for a pull request no task holds', () async {
    when(() => repository.holdersOf(any())).thenAnswer((_) async => {});
    expect(
      await summarizer.summarize(entryId),
      PullRequestSummaryOutcome.notAllowed,
    );
    expect(asked, isEmpty);
  });

  test(
    'a call it cannot use is asked once more, saying what was wrong, and '
    'a second one gives up',
    () async {
      answers = [
        () async => [summaryToolCall(arguments: 'not json')],
        () async => [summaryToolCall(oneLiner: 'Second try.')],
      ];
      expect(
        await summarizer.summarize(entryId),
        PullRequestSummaryOutcome.stored,
      );
      expect(asked, hasLength(2));
      expect(
        asked.last['prompt'],
        '$input\n\nYour previous answer was rejected: arguments are not '
        'JSON. Call the publish_pull_request_summary tool with both '
        'arguments and respond with nothing else.',
      );
      final data = stored();
      expect(data.oneLiner, 'Second try.');
      expect(data.prompt, input);

      asked.clear();
      answers = [() async => [], () async => []];
      clearInteractions(repository);
      expect(
        await summarizer.summarize(entryId),
        PullRequestSummaryOutcome.failed,
      );
      expect(asked, hasLength(2));
      neverStored();
    },
  );

  test(
    'a pull request unlinked, or changed, while the model wrote is not '
    'given the summary',
    () async {
      for (final (after, outcome) in [
        (null, PullRequestSummaryOutcome.missing),
        (
          prEntry(
            clock: {'a': 2},
            snapshot: mergedSnapshot.copyWith(body: 'Rewritten after merge.'),
          ),
          PullRequestSummaryOutcome.failed,
        ),
      ]) {
        var reads = 0;
        when(
          () => repository.liveEntry(entryId),
        ).thenAnswer((_) async => reads++ == 0 ? merged : after);

        expect(await summarizer.summarize(entryId), outcome);
      }
      neverStored();
    },
  );

  test('a summary the repository did not store is a failure', () async {
    when(
      () => repository.addSummary(any(), any(), start: any(named: 'start')),
    ).thenAnswer((_) async => false);
    expect(
      await summarizer.summarize(entryId),
      PullRequestSummaryOutcome.failed,
    );
  });

  test(
    'a failed request is logged and reported, never thrown — an error, not '
    'only an exception — and the user may ask again at once',
    () async {
      answers = [() async => throw Exception('provider down')];
      expect(
        await summarizer.summarize(entryId),
        PullRequestSummaryOutcome.failed,
      );

      when(() => repository.holdersOf(any())).thenThrow(TypeError());
      expect(
        await summarizer.summarize(entryId, manual: true),
        PullRequestSummaryOutcome.failed,
      );
      verify(
        () => logger.error(
          any(),
          any(),
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'pullRequestSummary',
        ),
      ).called(2);

      when(() => repository.holdersOf(any())).thenAnswer(
        (_) async => {
          ref.key: {'task-a'},
        },
      );
      expect(
        await summarizer.summarize(entryId, manual: true),
        PullRequestSummaryOutcome.stored,
      );
    },
  );

  test(
    'a second request while one runs for the same pull request is busy',
    () async {
      final gate = Completer<List<ChatCompletionMessageToolCall>>();
      answers = [() => gate.future];

      final first = summarizer.summarize(entryId);
      expect(
        await summarizer.summarize(entryId, manual: true),
        PullRequestSummaryOutcome.busy,
      );
      gate.complete([summaryToolCall()]);

      expect(await first, PullRequestSummaryOutcome.stored);
      expect(asked, hasLength(1));
    },
  );

  group('the language', () {
    test('is asked for by name, whatever the pull request is written in', () {
      expect(
        pullRequestSummaryInstructions('de'),
        '$pullRequestSummarySystemMessage Write both the one-liner and the '
        'TL;DR in German, whatever language the pull request is in.',
      );
      expect(
        pullRequestSummaryInstructions('xx'),
        endsWith(
          'in the language with code `xx`, whatever language the pull '
          'request is in.',
        ),
      );
      for (final none in [null, '']) {
        expect(
          pullRequestSummaryInstructions(none),
          pullRequestSummarySystemMessage,
        );
      }
    });

    test('a task with no language leaves it to the model', () async {
      tasks['task-a'] = (
        categoryId: 'category-a',
        automaticInference: false,
        languageCode: null,
      );

      await summarizer.summarize(entryId);

      expect(asked.single['taskId'], 'task-b');
      expect(asked.single['systemMessage'], pullRequestSummarySystemMessage);
    });
  });

  group('after a failure', () {
    final start = DateTime.utc(2026, 10, 4, 9);

    test(
      'the same content is not asked for again automatically until the '
      'cool-down passes; the user may ask at once, and a success clears it',
      () async {
        await withClock(Clock.fixed(start), () async {
          answers = [() async => [], () async => []];
          expect(
            await summarizer.summarize(entryId),
            PullRequestSummaryOutcome.failed,
          );
          expect(
            await summarizer.summarize(entryId),
            PullRequestSummaryOutcome.coolingDown,
          );
          expect(asked, hasLength(2));
        });

        await withClock(
          Clock.fixed(start.add(const Duration(minutes: 59))),
          () async => expect(
            await summarizer.summarize(entryId),
            PullRequestSummaryOutcome.coolingDown,
          ),
        );
        await withClock(
          Clock.fixed(start.add(const Duration(minutes: 30))),
          () async => expect(
            await summarizer.summarize(entryId, manual: true),
            PullRequestSummaryOutcome.stored,
          ),
        );
        await withClock(
          Clock.fixed(start.add(const Duration(minutes: 31))),
          () async => expect(
            await summarizer.automaticBlocker(entryId),
            isNull,
            reason: 'a success clears the cool-down',
          ),
        );
      },
    );

    test(
      'a failure the user asked for starts no cool-down: the next refresh '
      'may still ask',
      () async {
        await withClock(Clock.fixed(start), () async {
          answers = [() async => [], () async => []];
          expect(
            await summarizer.summarize(entryId, manual: true),
            PullRequestSummaryOutcome.failed,
          );
          expect(summarizer.coolDownEnds(entryId), isNull);
          expect(
            await summarizer.summarize(entryId),
            PullRequestSummaryOutcome.stored,
          );
        });
      },
    );

    test('tells when the cool-down ends, and none once it has', () async {
      await withClock(Clock.fixed(start), () async {
        answers = [() async => [], () async => []];
        await summarizer.summarize(entryId);
        expect(
          summarizer.coolDownEnds(entryId),
          start.add(summarizer.retryAfter),
        );
      });
      await withClock(
        Clock.fixed(start.add(summarizer.retryAfter)),
        () async => expect(summarizer.coolDownEnds(entryId), isNull),
      );
    });

    test('the cool-down passes after an hour', () async {
      await withClock(Clock.fixed(start), () async {
        answers = [() async => throw Exception('provider down')];
        expect(
          await summarizer.summarize(entryId),
          PullRequestSummaryOutcome.failed,
        );
      });
      await withClock(
        Clock.fixed(start.add(const Duration(hours: 1))),
        () async => expect(
          await summarizer.summarize(entryId),
          PullRequestSummaryOutcome.stored,
        ),
      );
    });

    test('new content is asked for at once', () async {
      await withClock(Clock.fixed(start), () async {
        answers = [() async => [], () async => []];
        await summarizer.summarize(entryId);

        when(() => repository.liveEntry(entryId)).thenAnswer(
          (_) async => merged.copyWith(
            data: merged.data.copyWith(
              snapshot: mergedSnapshot.copyWith(title: 'Retitled'),
            ),
          ),
        );
        expect(
          await summarizer.summarize(entryId),
          PullRequestSummaryOutcome.stored,
        );
      });
    });
  });

  group('automaticBlocker', () {
    test('is null when the next refresh would ask for a summary', () async {
      expect(await summarizer.automaticBlocker(entryId), isNull);
      expect(asked, isEmpty);
    });

    test('names the missing consent, model or entry', () async {
      models.clear();
      expect(
        await summarizer.automaticBlocker(entryId),
        PullRequestSummaryOutcome.noModel,
      );

      for (final id in ['task-a', 'task-b']) {
        tasks[id] = (
          categoryId: null,
          automaticInference: false,
          languageCode: null,
        );
      }
      expect(
        await summarizer.automaticBlocker(entryId),
        PullRequestSummaryOutcome.notAllowed,
      );

      when(() => repository.liveEntry(entryId)).thenAnswer((_) async => null);
      expect(
        await summarizer.automaticBlocker(entryId),
        PullRequestSummaryOutcome.missing,
      );
      expect(asked, isEmpty);
    });

    test('names a failure still cooling down', () async {
      answers = [() async => [], () async => []];
      await summarizer.summarize(entryId);

      expect(
        await summarizer.automaticBlocker(entryId),
        PullRequestSummaryOutcome.coolingDown,
      );
    });
  });

  test(
    'announces every attempt that ends, stored or not, and stops when '
    'disposed',
    () async {
      final ended = <String>[];
      final subscription = summarizer.attempts.listen(ended.add);
      addTearDown(subscription.cancel);

      await summarizer.summarize(entryId);
      when(() => repository.liveEntry(entryId)).thenAnswer((_) async => null);
      await summarizer.summarize(entryId);
      await pumpEventQueue();
      expect(ended, [entryId, entryId]);

      await summarizer.dispose();
      expect(
        await summarizer.summarize(entryId),
        PullRequestSummaryOutcome.missing,
      );
    },
  );
}
