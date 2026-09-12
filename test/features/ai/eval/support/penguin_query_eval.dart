import 'dart:convert';
import 'dart:ui';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/query_chat_models.dart';
import 'package:lotti/features/agents/query/query_answer_builder.dart';
import 'package:lotti/features/agents/query/query_journal_crawler.dart';
import 'package:lotti/features/agents/query/query_source_access.dart';
import 'package:lotti/features/agents/query/query_text_inference.dart';
import 'package:lotti/features/demo/seed/demo_seed_text.dart';
import 'package:lotti/features/demo/seed/demo_world.dart';
import 'package:lotti/features/lockdown/domain/lockdown_state.dart';

/// The unmodified, shipped English demo world. No invented meeting notes,
/// preselected task, personal database, or synthetic model answers.
class PenguinQueryCorpus {
  PenguinQueryCorpus()
    : world = ManualDemoWorld.penguinLogistics(
        translate: demoSeedTextForLocale(const Locale('en')),
        now: manualDemoNow,
      ) {
    rankedTasks = [...world.tasks]
      ..sort((a, b) {
        final byCount = linkedIds(b).length.compareTo(linkedIds(a).length);
        return byCount != 0 ? byCount : a.meta.id.compareTo(b.meta.id);
      });
  }

  final ManualDemoWorld world;
  late final List<Task> rankedTasks;
  Task get task => rankedTasks.first;
  QueryScope get scope =>
      QueryScope(kind: QueryScopeKind.task, id: task.meta.id);

  /// Counts unique visible direct neighbors in either direction, not depth-two
  /// graph expansion, checklist ownership, or the task itself.
  Set<String> linkedIds(Task task) => {
    for (final link in world.links)
      if (link.hidden != true && link.deletedAt == null) ...[
        if (link.fromId == task.meta.id) link.toId,
        if (link.toId == task.meta.id) link.fromId,
      ],
  }..remove(task.meta.id);

  List<QuerySourceDocument> get homeDocuments {
    final ids = {task.meta.id, ...linkedIds(task)};
    return [
      for (final entry in world.journalEntities)
        if (ids.contains(entry.meta.id) &&
            entry.meta.categoryId == task.meta.categoryId &&
            entry.meta.private != true &&
            entry.meta.deletedAt == null)
          ?QuerySourceDocument.fromEntry(entry),
    ];
  }

  Map<String, Object?> get inventory => {
    'fixture': 'ManualDemoWorld.penguinLogistics / English / manualDemoNow',
    'taskId': task.meta.id,
    'taskTitle': task.data.title,
    'categoryId': task.meta.categoryId,
    'directNeighbors': linkedIds(task).length,
    'readableHomeDocumentsIncludingTask': homeDocuments.length,
    'homeSourceCharacters': homeDocuments.fold<int>(
      0,
      (n, d) => n + d.text.length,
    ),
    'ranking': [
      for (final task in rankedTasks)
        {
          'title': task.data.title,
          'id': task.meta.id,
          'directNeighbors': linkedIds(task).length,
        },
    ],
  };
}

/// Real journal and FTS queries over the canonical demo world, kept entirely in
/// memory. Low-level seed writes deliberately skip sync and filesystem media.
class PenguinQueryDatabase {
  PenguinQueryDatabase(this.corpus);

  final PenguinQueryCorpus corpus;
  final journal = JournalDb(inMemoryDatabase: true);
  final fts = Fts5Db(inMemoryDatabase: true);
  final searches = <String>[];

  late final access = QuerySourceAccess(
    journal: journal,
    readLockdown: () => LockdownState.inactive,
  );
  late final crawler = QueryJournalCrawler(
    journal: journal,
    access: access,
    search: (query) async {
      searches.add(query);
      return fts.findMatching(query).get();
    },
  );

  Future<void> seed() async {
    await journal.insertFlagIfNotExists(
      const ConfigFlag(
        name: 'private',
        description: 'Show private entries?',
        status: false,
      ),
    );
    for (final category in corpus.world.categories) {
      await journal.upsertEntityDefinition(category);
    }
    for (final entry in corpus.world.journalEntities) {
      await journal.upsertJournalDbEntity(toDbEntity(entry));
      await fts.insertText(entry);
    }
    for (final link in corpus.world.links) {
      await journal.upsertEntryLink(link);
    }
  }

  Future<void> close() async {
    await journal.close();
    await fts.close();
  }
}

/// Timings around the production inference boundary. The delegate remains
/// QueryTextInference.forProfile: no alternate provider protocol or prompts.
/// Durations include transport, generation, JSON parsing and reasoning removal.
/// Separates production elapsed time from synchronous artifact checkpoints.
class QueryEvalTimer {
  QueryEvalTimer({int Function()? readMicroseconds}) {
    final clock = Stopwatch()..start();
    _read = readMicroseconds ?? () => clock.elapsedMicroseconds;
    _startedAt = _read();
  }

  late final int Function() _read;
  late final int _startedAt;
  int? _stoppedAt;
  int checkpointMicroseconds = 0;

  int get wallMicroseconds => (_stoppedAt ?? _read()) - _startedAt;
  int get elapsedMicroseconds => wallMicroseconds - checkpointMicroseconds;

  void checkpoint(void Function() persist) {
    final startedAt = _read();
    try {
      persist();
    } finally {
      checkpointMicroseconds += _read() - startedAt;
    }
  }

  void stop() => _stoppedAt ??= _read();
}

class MeasuredQueryInference implements QueryTextInference {
  MeasuredQueryInference(this.delegate, {this.onCallRecorded});
  final QueryTextInference delegate;
  final void Function()? onCallRecorded;
  final calls = <Map<String, Object?>>[];

  @override
  Future<Map<String, dynamic>> complete({
    required String system,
    required Map<String, Object?> input,
    required QueryCancellation cancellation,
    void Function(String)? onAnswerText,
    void Function()? onFirstToken,
  }) async {
    if (calls.length >= 12) {
      throw StateError('Query eval completion cap reached');
    }
    final stage = switch (system) {
      final s when s.contains('Inspect sources together') => 'batch',
      final s when s.contains('Rephrase the question') => 'plan',
      final s when s.contains('Shortlist sources') => 'shortlist',
      final s when s.contains('Extract passages') => 'extract',
      final s when s.contains('Select only remembered') => 'memory',
      final s when s.contains('Answer from the supplied') => 'answer',
      _ => 'unknown',
    };
    final record = <String, Object?>{
      'stage': stage,
      'inputCharacters': system.length + jsonEncode(input).length,
      if (input['sources'] case final List<dynamic> sources)
        'candidateCount': sources.length,
      if (input['source'] case final String source)
        'sourceCharacters': source.length,
    };
    calls.add(record);
    onCallRecorded?.call();
    final clock = Stopwatch()..start();
    try {
      final result = await delegate.complete(
        system: system,
        input: input,
        cancellation: cancellation,
        onAnswerText: onAnswerText,
        onFirstToken: () {
          record['firstTokenMs'] = clock.elapsedMicroseconds / 1000;
          onFirstToken?.call();
        },
      );
      record['outputCharacters'] = jsonEncode(result).length;
      record['status'] = 'complete';
      return result;
    } catch (error) {
      // Error messages can contain provider request/credential details.
      record['status'] = error.runtimeType.toString();
      rethrow;
    } finally {
      record['milliseconds'] = clock.elapsedMicroseconds / 1000;
      onCallRecorded?.call();
    }
  }
}

/// Credentials may use cleartext HTTP only on an explicit loopback endpoint.
Uri validatePenguinQueryEndpoint(String value) {
  final uri = Uri.parse(value);
  final loopback = const {'localhost', '127.0.0.1', '::1'}.contains(uri.host);
  if (uri.host.isEmpty ||
      (uri.scheme != 'https' && !(uri.scheme == 'http' && loopback))) {
    throw const FormatException('Query eval endpoint requires HTTPS');
  }
  return uri;
}

/// Conservative English-fixture checks supplement, rather than replace, the
/// manual review. A refusal phrase must not hide an invented price or reading.
bool hasForbiddenPenguinAnswerValue(
  PenguinQueryQuestion question,
  String text,
) {
  if (!question.absent) return false;
  const number =
      r'(?:\d+(?:[.,]\d+)?|zero|one|two|three|four|five|six|seven|eight|nine|ten|'
      'eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|'
      'nineteen|twenty|thirty|forty|fifty|sixty|seventy|eighty|ninety|'
      'hundred|thousand|million)';
  const boundary = r'\b';
  const currency = r'[€$£]\s*';
  const currencyUnit = r'\s*(?:euros?|eur|dollars?|pounds?)\b';
  const humidityUnit = r'\s*(?:percentage\s+points?|points?\b|percent\b|%)';
  const increase = r'\b(?:rose|increased?|rise)\s+(?:by\s+)?';
  final pattern = switch (question.id) {
    'absent' => '$currency$number|$boundary$number$currencyUnit',
    'category_boundary' =>
      '$boundary$number$humidityUnit|$increase$number$boundary',
    _ => null,
  };
  return pattern != null &&
      RegExp(pattern, caseSensitive: false).hasMatch(text);
}

class PenguinQueryQuestion {
  const PenguinQueryQuestion({
    required this.id,
    required this.question,
    required this.answerTerms,
    required this.quoteTerms,
    this.followUpTo,
    this.outsideHome = false,
    this.absent = false,
  });
  final String id;
  final String question;
  final List<List<String>> answerTerms;
  final List<String> quoteTerms;
  final String? followUpTo;
  final bool outsideHome;
  final bool absent;
}

/// Uses actual preceding outputs with realistic deterministic event ordering.
/// Equal timestamps would let the retry cutoff exclude `memory-local` merely
/// because its ID sorts after `follow_up`, silently bypassing memory recall.
({
  AgentQueryChatEventEntity question,
  List<AgentQueryChatEventEntity> events,
  List<AgentQueryChatEventEntity> memories,
})
makePenguinQueryTurn(
  PenguinQueryQuestion scenario, {
  AgentQueryChatEventEntity? previousQuestion,
  QueryBuiltAnswer? previousAnswer,
}) {
  if (scenario.followUpTo != null &&
      (previousQuestion?.id != scenario.followUpTo || previousAnswer == null)) {
    throw StateError('Follow-up requires its actual preceding answer');
  }
  final at = previousQuestion == null
      ? manualDemoNow
      : previousQuestion.createdAt.add(const Duration(seconds: 2));
  final question = AgentQueryChatEventEntity(
    id: scenario.id,
    agentId: 'agent',
    chatId: 'chat',
    data: QueryChatQuestion(text: scenario.question),
    createdAt: at,
    vectorClock: null,
  );
  return (
    question: question,
    events: [
      if (previousQuestion != null && previousAnswer != null) ...[
        previousQuestion,
        AgentQueryChatEventEntity(
          id: 'answer-${previousQuestion.id}',
          agentId: 'agent',
          chatId: 'chat',
          data: previousAnswer.answer,
          createdAt: at.subtract(const Duration(seconds: 1)),
          vectorClock: null,
        ),
      ],
      question,
    ],
    memories: [
      if (previousAnswer?.memory case final memory?)
        AgentQueryChatEventEntity(
          id: 'memory-${scenario.followUpTo}',
          agentId: 'agent',
          chatId: 'chat',
          data: memory,
          createdAt: at.subtract(const Duration(seconds: 1)),
          vectorClock: null,
        ),
    ],
  );
}

/// Ground truth appears verbatim in the shipped fixture. Follow-up context is
/// the preceding live answer, never a hand-authored perfect conversation.
const penguinQueryQuestions = [
  PenguinQueryQuestion(
    id: 'local',
    question:
        'What pressure did the seals hold overnight, and how many penguins did roll call confirm?',
    answerTerms: [
      ['101.3'],
      ['37'],
    ],
    quoteTerms: ['101.3', '37'],
  ),
  PenguinQueryQuestion(
    id: 'follow_up',
    question: 'Where was the sleeping one?',
    answerTerms: [
      ['cargo netting', 'cargo net'],
    ],
    quoteTerms: ['cargo netting'],
    followUpTo: 'local',
  ),
  PenguinQueryQuestion(
    id: 'wider_category',
    question:
        'Search the other notes in this category: how far did the launch rehearsal overrun, and at which step?',
    answerTerms: [
      ['nine', '9'],
      ['boarding'],
    ],
    quoteTerms: ['nine minutes', 'boarding'],
    outsideHome: true,
  ),
  PenguinQueryQuestion(
    id: 'absent',
    question:
        'What price in euros did we agree to pay for the habitat insurance?',
    answerTerms: [
      [
        'cannot',
        "can't",
        'not establish',
        'no evidence',
        'not specified',
        'not recorded',
        'not found',
        'no information',
        'do not',
        "don't",
      ],
    ],
    quoteTerms: [],
    absent: true,
  ),
  PenguinQueryQuestion(
    id: 'category_boundary',
    question: 'By how many humidity points did Bay C rise in three days?',
    answerTerms: [
      [
        'cannot',
        "can't",
        'not establish',
        'no evidence',
        'not specified',
        'not recorded',
        'not found',
        'no information',
        'do not',
        "don't",
      ],
    ],
    quoteTerms: [],
    absent: true,
  ),
];
