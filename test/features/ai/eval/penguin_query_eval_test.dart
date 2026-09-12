import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/query_chat_models.dart';
import 'package:lotti/features/agents/query/query_answer_builder.dart';
import 'package:lotti/features/agents/query/query_chat_projection.dart';
import 'package:lotti/features/agents/query/query_journal_crawler.dart';
import 'package:lotti/features/agents/query/query_text_inference.dart';
import 'package:lotti/features/demo/seed/demo_world.dart';

import '../../../widget_test_utils.dart';
import 'support/penguin_query_eval.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);

  test('eval credentials require HTTPS except on explicit loopback hosts', () {
    for (final endpoint in [
      'https://inference.example/v1',
      'http://localhost:8080/v1',
      'http://127.0.0.1:8080/v1',
      'http://[::1]:8080/v1',
    ]) {
      expect(validatePenguinQueryEndpoint(endpoint).toString(), endpoint);
    }
    for (final endpoint in [
      'http://inference.example/v1',
      'http://localhost.example/v1',
      'http://127.0.0.1.example/v1',
      'ftp://localhost/v1',
      '/v1',
    ]) {
      expect(
        () => validatePenguinQueryEndpoint(endpoint),
        throwsFormatException,
      );
    }
  });

  test(
    'a refusal cannot conceal an invented price or humidity measurement',
    () {
      final absent = penguinQueryQuestions.singleWhere((q) => q.id == 'absent');
      final boundary = penguinQueryQuestions.singleWhere(
        (q) => q.id == 'category_boundary',
      );
      for (final text in [
        'No evidence, but the price was €500.',
        'No record found; it cost five hundred euros.',
      ]) {
        expect(hasForbiddenPenguinAnswerValue(absent, text), isTrue);
      }
      for (final text in [
        'No evidence, but humidity rose by 9 points.',
        'Not established, though the increase was nine percentage points.',
      ]) {
        expect(hasForbiddenPenguinAnswerValue(boundary, text), isTrue);
      }
      expect(
        hasForbiddenPenguinAnswerValue(
          absent,
          'No agreed price found in 57 checked sources.',
        ),
        isFalse,
      );
      expect(
        hasForbiddenPenguinAnswerValue(
          boundary,
          'The three-day change is unknown; 58 sources were checked.',
        ),
        isFalse,
      );
      expect(
        hasForbiddenPenguinAnswerValue(
          penguinQueryQuestions.first,
          '101.3 kPa',
        ),
        isFalse,
      );
    },
  );

  test('question timing excludes checkpoint I/O and post-build validation', () {
    var micros = 100;
    final timer = QueryEvalTimer(readMicroseconds: () => micros);
    micros += 20;
    timer.checkpoint(() => micros += 1000);
    micros += 30;
    expect(timer.elapsedMicroseconds, 50);
    expect(timer.checkpointMicroseconds, 1000);
    expect(
      () => timer.checkpoint(() {
        micros += 500;
        throw StateError('synthetic checkpoint failure');
      }),
      throwsStateError,
    );
    timer.stop();
    micros += 200;
    expect(timer.elapsedMicroseconds, 50);
    expect(timer.wallMicroseconds, 1550);
    expect(timer.checkpointMicroseconds, 1500);
  });

  test('follow-up retains actual outputs before the retry memory cutoff', () {
    final first = makePenguinQueryTurn(penguinQueryQuestions.first);
    const actual = QueryBuiltAnswer(
      answer: QueryChatAnswer(
        questionId: 'local',
        text: 'Actual prior response',
        coverage: QueryCoverage(),
      ),
      memory: QueryChatMemory(
        questionId: 'local',
        text: 'Actual prior conclusion',
      ),
    );
    final follow = makePenguinQueryTurn(
      penguinQueryQuestions[1],
      previousQuestion: first.question,
      previousAnswer: actual,
    );
    expect(follow.events[1].data, same(actual.answer));
    expect(follow.memories.single.data, same(actual.memory));
    expect(compareQueryEvents(follow.events[0], follow.events[1]), lessThan(0));
    expect(compareQueryEvents(follow.events[1], follow.question), lessThan(0));
    expect(
      compareQueryEvents(follow.memories.single, follow.question),
      lessThan(0),
    );
    expect(
      () => makePenguinQueryTurn(penguinQueryQuestions[1]),
      throwsStateError,
    );
  });

  test(
    'chooses the actual most-linked task and preserves category boundaries',
    () async {
      final corpus = PenguinQueryCorpus();
      expect(corpus.task.meta.id, manualOrbitalHabitatTaskId);
      expect(corpus.linkedIds(corpus.task), hasLength(17));
      expect(corpus.homeDocuments, hasLength(12));
      expect(corpus.inventory['homeSourceCharacters'], 1201);
      expect(
        corpus.rankedTasks
            .skip(1)
            .every((t) => corpus.linkedIds(t).length < 17),
        isTrue,
      );
      final database = PenguinQueryDatabase(corpus);
      addTearDown(database.close);
      await database.seed();
      final home = await database.crawler.discover(corpus.scope, [
        'seals',
      ], homeOnly: true);
      expect(
        home.documents.map((d) => d.entry.meta.id).toSet(),
        corpus.homeDocuments.map((d) => d.entry.meta.id).toSet(),
      );
      expect(database.searches, isEmpty);
      final wider = await database.crawler.discover(corpus.scope, [
        'rehearsal',
      ]);
      expect(
        wider.documents.any((d) => d.text.contains('nine minutes long')),
        isTrue,
      );
      expect(
        wider.documents.every(
          (d) => d.entry.meta.categoryId == corpus.task.meta.categoryId,
        ),
        isTrue,
      );
      expect(
        wider.documents.any((d) => d.entry.meta.id == demoHumiditySpikeTaskId),
        isFalse,
      );
      expect(database.searches, ['"rehearsal"']);
    },
  );

  test(
    'question ground truths come from exact shipped text in the intended scope',
    () {
      final corpus = PenguinQueryCorpus();
      final home = corpus.homeDocuments.map((d) => d.text).join('\n');
      final category = corpus.world.journalEntities
          .where((e) => e.meta.categoryId == corpus.task.meta.categoryId)
          .map(QuerySourceDocument.fromEntry)
          .whereType<QuerySourceDocument>()
          .map((d) => d.text)
          .join('\n');
      for (final question in penguinQueryQuestions.where((q) => !q.absent)) {
        final source = question.outsideHome ? category : home;
        for (final term in question.quoteTerms) {
          expect(source, contains(term), reason: question.id);
        }
      }
      expect(home, isNot(contains('nine minutes')));
      expect(category.toLowerCase(), isNot(contains('insurance')));
      final humidity = corpus.world.tasks.singleWhere(
        (t) => t.meta.id == demoHumiditySpikeTaskId,
      );
      expect(
        QuerySourceDocument.fromEntry(humidity)!.text,
        contains('Nine points in three days'),
      );
      expect(humidity.meta.categoryId, isNot(corpus.task.meta.categoryId));
    },
  );
  test(
    'measures delegated calls and refuses unbounded completion loops',
    () async {
      var delegateCalls = 0;
      final inference = MeasuredQueryInference(
        QueryTextInference(
          generate: (system, prompt) {
            delegateCalls++;
            return Stream.value('{"ids":[]}');
          },
        ),
      );
      final cancellation = QueryCancellation();
      for (var i = 0; i < 12; i++) {
        expect(
          await inference.complete(
            system: 'Shortlist sources',
            input: {
              'sources': ['penguin'],
            },
            cancellation: cancellation,
          ),
          {'ids': <String>[]},
        );
      }
      expect(inference.calls, hasLength(12));
      expect(inference.calls.first, containsPair('stage', 'shortlist'));
      expect(inference.calls.first, containsPair('candidateCount', 1));
      expect(inference.calls.first, containsPair('inputCharacters', 40));
      expect(inference.calls.first, containsPair('outputCharacters', 10));
      expect(inference.calls.first, containsPair('status', 'complete'));
      await expectLater(
        inference.complete(
          system: 'Extract passages',
          input: {},
          cancellation: cancellation,
        ),
        throwsStateError,
      );
      expect(delegateCalls, 12);
    },
  );

  test(
    'failed completion remains observable without logging response contents',
    () async {
      final snapshots = <Map<String, Object?>>[];
      late MeasuredQueryInference inference;
      inference = MeasuredQueryInference(
        QueryTextInference(
          generate: (_, _) => Stream.value('sensitive bad response'),
        ),
        onCallRecorded: () => snapshots.add({...inference.calls.last}),
      );
      await expectLater(
        inference.complete(
          system: 'Rephrase the question',
          input: {'question': 'penguin'},
          cancellation: QueryCancellation(),
        ),
        throwsFormatException,
      );
      expect(inference.calls.single['status'], 'FormatException');
      expect(inference.calls.single['stage'], 'plan');
      expect(inference.calls.single.keys, isNot(contains('outputCharacters')));
      expect(inference.calls.single.toString(), isNot(contains('sensitive')));
      expect(snapshots, hasLength(2));
      expect(snapshots.first, isNot(contains('status')));
      expect(snapshots.last['status'], 'FormatException');
      expect(snapshots.last, contains('milliseconds'));
    },
  );
}
