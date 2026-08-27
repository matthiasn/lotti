import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/model/ai_call_impact.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/gemini_tool_call.dart';
import 'package:lotti/features/ai/repository/inference_repository_interface.dart';
import 'package:lotti/features/goals/logic/goal_checkin_compaction_strategy.dart';
import 'package:lotti/features/goals/workflow/goal_agent_contract.dart';
import 'package:openai_dart/openai_dart.dart';

import 'support/goal_compaction_eval.dart';
import 'support/goal_compaction_fixtures.dart';

/// A scripted model: answers the wake with a report and a reply, answers
/// the probe turn with JSON, and answers a digest request with prose. The
/// user turn's text decides which; a tool-result turn ends the exchange.
class _ScriptedInference extends InferenceRepositoryInterface {
  _ScriptedInference({
    this.reportedStatus = 'offTrack',
    this.failOn,
    this.blankDigest = false,
  });

  final String reportedStatus;

  /// A substring of a user message that makes the call throw.
  final String? failOn;

  /// Answer digest requests with whitespace only.
  final bool blankDigest;

  final prompts = <String>[];

  @override
  Stream<CreateChatCompletionStreamResponse> generateTextWithMessages({
    required List<ChatCompletionMessage> messages,
    required String model,
    required double temperature,
    required AiConfigInferenceProvider provider,
    int? maxCompletionTokens,
    List<ChatCompletionTool>? tools,
    ChatCompletionToolChoiceOption? toolChoice,
    Map<String, String>? thoughtSignatures,
    ThoughtSignatureCollector? signatureCollector,
    int? turnIndex,
    InferenceImpactCollector? impactCollector,
  }) {
    final last = messages.last;
    if (last.role == ChatCompletionMessageRole.tool) {
      return Stream.value(_text('done', promptTokens: 10));
    }
    final user = last.mapOrNull(user: (m) => m.content.value)?.toString() ?? '';
    prompts.add(user);
    if (failOn != null && user.contains(failOn!)) {
      return Stream.error(Exception('scripted failure'));
    }
    if (user.startsWith('Span:')) {
      if (blankDigest) return Stream.value(_text('  \n', promptTokens: 400));
      return Stream.value(
        _text(
          'Digest of the span: numbers fell, loop block deleted.',
          promptTokens: 400,
        ),
      );
    }
    if (user.startsWith('A few questions')) {
      final ids = RegExp(
        r'^- (\w+):',
        multiLine: true,
      ).allMatches(user).map((m) => m.group(1)!).toList();
      final answers = [
        for (final (i, id) in ids.indexed)
          {
            'id': id,
            'answer': i.isEven ? 'Answer for $id.' : 'Not in what I was given.',
            'basis': i.isEven ? 'history' : 'notInHistory',
          },
      ];
      return Stream.value(
        _tools([
          (
            GoalAgentToolNames.replyToUser,
            jsonEncode({
              'message': jsonEncode({'answers': answers}),
            }),
          ),
        ], promptTokens: 700),
      );
    }
    // The wake.
    return Stream.value(
      _tools([
        (
          GoalAgentToolNames.updateGoalReport,
          jsonEncode({
            'status': reportedStatus,
            'oneLiner': 'Off track for a year.',
            'report': {
              'tldr': 'tldr',
              'currentPeriod': 'c',
              'rollingWindow': 'r',
              'latestChange': 'l',
              'coverage': 'cov',
              'now': <Object>[],
            },
          }),
        ),
        (
          GoalAgentToolNames.replyToUser,
          jsonEncode({'message': 'Restore the calendar block.'}),
        ),
      ], promptTokens: 5000),
    );
  }

  CreateChatCompletionStreamResponse _text(
    String text, {
    required int promptTokens,
  }) => CreateChatCompletionStreamResponse(
    id: 'r',
    choices: [
      ChatCompletionStreamResponseChoice(
        index: 0,
        delta: ChatCompletionStreamResponseDelta(content: text),
      ),
    ],
    object: 'chat.completion.chunk',
    created: 1,
    usage: CompletionUsage(
      promptTokens: promptTokens,
      completionTokens: 20,
      totalTokens: promptTokens + 20,
    ),
  );

  CreateChatCompletionStreamResponse _tools(
    List<(String, String)> calls, {
    required int promptTokens,
  }) => CreateChatCompletionStreamResponse(
    id: 'r',
    choices: [
      ChatCompletionStreamResponseChoice(
        index: 0,
        delta: ChatCompletionStreamResponseDelta(
          toolCalls: [
            for (final (i, call) in calls.indexed)
              ChatCompletionStreamMessageToolCallChunk(
                index: i,
                id: 'call-$i',
                type: ChatCompletionStreamMessageToolCallChunkType.function,
                function: ChatCompletionStreamMessageFunctionCall(
                  name: call.$1,
                  arguments: call.$2,
                ),
              ),
          ],
        ),
      ),
    ],
    object: 'chat.completion.chunk',
    created: 1,
    usage: CompletionUsage(
      promptTokens: promptTokens,
      completionTokens: 40,
      totalTokens: promptTokens + 40,
    ),
  );
}

class _FixedDigestWriter implements GoalCheckInDigestWriter {
  int writes = 0;
  @override
  Future<String> write(GoalCheckInDigestRequest request) async {
    writes++;
    return 'digest ${request.periodLabel}';
  }
}

void main() {
  final provider = AiConfigInferenceProvider(
    id: 'p',
    name: 'p',
    baseUrl: 'https://example.test',
    apiKey: 'k',
    inferenceProviderType: InferenceProviderType.genericOpenAi,
    createdAt: DateTime(2026),
  );
  final fixture = goalCompactionFixtures.first;

  late ProviderContainer container;
  late ConversationRepository conversations;
  setUp(() {
    container = ProviderContainer();
    conversations = container.read(conversationRepositoryProvider.notifier);
  });
  tearDown(() => container.dispose());

  group('probe message and answer parsing', () {
    test('the message lists every probe by id', () {
      final message = goalCompactionProbeMessage(fixture.truth.probes);
      for (final probe in fixture.truth.probes) {
        expect(message, contains('- ${probe.id}: ${probe.question}'));
      }
      expect(message, contains('"notInHistory"'));
    });

    test('parses answers by id, tolerating surrounding prose', () {
      final probes = fixture.truth.probes.take(2).toList();
      final results = parseGoalCompactionProbeAnswers(
        probes,
        'Here you go:\n{"answers":[{"id":"${probes[1].id}","answer":"B.", '
        '"basis":"notInHistory"},{"id":"${probes[0].id}","answer":"A.","basis":"history"}]}\nDone.',
      );
      expect(results.map((r) => r.answer), ['A.', 'B.']);
      expect(results.map((r) => r.basis), ['history', 'notInHistory']);
    });

    test('garbage yields unanswered probes, never guesses', () {
      final probes = fixture.truth.probes.take(3).toList();
      for (final raw in [
        '',
        'no json here',
        '{"answers": "nope"}',
        '{broken',
      ]) {
        final results = parseGoalCompactionProbeAnswers(probes, raw);
        expect(results.length, 3, reason: raw);
        expect(
          results.every((r) => r.answer == null && r.basis == null),
          isTrue,
          reason: raw,
        );
      }
    });

    test('a missing id is unanswered while the others parse', () {
      final probes = fixture.truth.probes.take(2).toList();
      final results = parseGoalCompactionProbeAnswers(
        probes,
        '{"answers":[{"id":"${probes[0].id}","answer":"A.","basis":"history"}]}',
      );
      expect(results[0].answer, 'A.');
      expect(results[1].answer, isNull);
    });
  });

  group('CachedLlmDigestWriter', () {
    late Directory cache;
    setUp(() {
      cache = Directory.systemTemp.createTempSync('lotti-digest-cache');
    });
    tearDown(() => cache.deleteSync(recursive: true));

    GoalCheckInDigestRequest request() => GoalCheckInDigestRequest(
      periodLabel: '2025-Q1',
      layer: GoalCheckInDigestLayer.quarter,
      from: fixture.checkIns[10].recordedAt,
      to: fixture.checkIns[30].recordedAt,
      checkIns: fixture.checkIns.sublist(10, 31),
    );

    test(
      'calls the model once and serves the second request from disk',
      () async {
        final inference = _ScriptedInference();
        final writer = CachedLlmDigestWriter(
          provider: provider,
          modelId: 'm',
          conversationRepository: conversations,
          inferenceRepository: inference,
          cacheDirectory: cache,
        );

        final first = await writer.write(request());
        final second = await writer.write(request());

        expect(first, 'Digest of the span: numbers fell, loop block deleted.');
        expect(second, first);
        expect(writer.calls, 1);
        expect(writer.cacheHits, 1);
        expect(inference.prompts.length, 1);
        expect(inference.prompts.single, startsWith('Span: 2025-Q1 (quarter;'));
        expect(inference.prompts.single, contains('Word limit: 80.'));
        expect(
          inference.prompts.single,
          contains(fixture.checkIns[10].whatHappened),
        );
        expect(cache.listSync().whereType<File>().length, 1);
        expect(writer.usageJson, {
          'calls': 1,
          'cacheHits': 1,
          'inputTokens': 400,
          'outputTokens': 20,
        });
      },
    );

    test('a different model is a different cache key', () async {
      final inference = _ScriptedInference();
      for (final model in ['m1', 'm2']) {
        await CachedLlmDigestWriter(
          provider: provider,
          modelId: model,
          conversationRepository: conversations,
          inferenceRepository: inference,
          cacheDirectory: cache,
        ).write(request());
      }
      expect(inference.prompts.length, 2);
      expect(cache.listSync().whereType<File>().length, 2);
    });

    test('an inference failure propagates and caches nothing', () async {
      final writer = CachedLlmDigestWriter(
        provider: provider,
        modelId: 'm',
        conversationRepository: conversations,
        inferenceRepository: _ScriptedInference(failOn: 'Span:'),
        cacheDirectory: cache,
      );
      await expectLater(writer.write(request()), throwsA(isA<Exception>()));
      expect(cache.listSync(), isEmpty);
      expect(writer.calls, 1);
    });

    test('a blank digest is an error, not a cached blank', () async {
      final writer = CachedLlmDigestWriter(
        provider: provider,
        modelId: 'm',
        conversationRepository: conversations,
        inferenceRepository: _ScriptedInference(blankDigest: true),
        cacheDirectory: cache,
      );
      await expectLater(
        writer.write(request()),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('2025-Q1'),
          ),
        ),
      );
      expect(cache.listSync(), isEmpty);
      // The call was made and billed even though nothing usable came back.
      expect(writer.calls, 1);
      expect(writer.usageJson['inputTokens'], 400);
    });
  });

  group('GoalCompactionEvalRunner', () {
    test(
      'produces one case per fixture × arm × sample with the growth curve',
      () async {
        final inference = _ScriptedInference();
        final writer = _FixedDigestWriter();
        final runner = GoalCompactionEvalRunner(
          provider: provider,
          modelId: 'm',
          conversationRepository: conversations,
          inferenceRepository: inference,
        );

        final packet = await runner.run(
          fixtures: [fixture],
          strategies: goalCompactionEvalArms(writer),
          samples: 2,
          digestUsage: () => {'calls': writer.writes},
        );

        expect(packet.cases.length, 3 * 2);
        expect(packet.strategyIds, ['full', 'truncate', 'hierarchical']);
        expect(
          packet.growthCurve.length,
          3 * goalCompactionEvalHorizons.length,
        );
        final fullCurve = packet.growthCurve
            .where((g) => g.strategyId == 'full')
            .map((g) => g.context.estimatedTokens)
            .toList();
        expect(fullCurve, orderedEquals([...fullCurve]..sort()));
        expect(fullCurve.last, greaterThan(fullCurve.first * 4));
        final hierarchicalCurve = packet.growthCurve
            .where((g) => g.strategyId == 'hierarchical')
            .map((g) => g.context.estimatedTokens)
            .toList();
        expect(hierarchicalCurve.last, lessThan(fullCurve.last ~/ 4));
        expect(writer.writes, greaterThan(0));
      },
    );

    test(
      'a case carries the FACTS it saw, the report status, the reply and the probes',
      () async {
        final runner = GoalCompactionEvalRunner(
          provider: provider,
          modelId: 'm',
          conversationRepository: _repo(container),
          inferenceRepository: _ScriptedInference(),
        );

        final packet = await runner.run(
          fixtures: [fixture],
          strategies: const [TruncatingCheckInCompaction()],
          samples: 1,
        );

        final c = packet.cases.single;
        expect(c.facts, contains('"userVoice"'));
        expect(c.facts, contains(fixture.checkIns.last.whatHappened));
        expect(c.facts, isNot(contains(fixture.checkIns.first.whatHappened)));
        expect(c.reportedStatus, 'offTrack');
        expect(c.reportOneLiner, 'Off track for a year.');
        expect(c.wakeReply, 'Restore the calendar block.');
        expect(c.wakeToolNames, ['reply_to_user', 'update_goal_report']);
        // Provider-reported, accumulated over the exchange's turns.
        expect(c.wakeUsage?.inputTokens, greaterThanOrEqualTo(5000));
        expect(c.probeUsage?.inputTokens, greaterThanOrEqualTo(700));
        expect(c.errorMessage, isNull);
        expect(c.probes.length, fixture.truth.probes.length);
        expect(c.probes[0].answer, 'Answer for ${fixture.truth.probes[0].id}.');
        expect(c.probes[0].basis, 'history');
        expect(c.probes[1].basis, 'notInHistory');

        final json = c.toJson(goalCompactionEvalReference);
        final wake = json['wake']! as Map<String, Object?>;
        expect(wake['statusCorrect'], isTrue);
        expect(wake['toolNames'], ['reply_to_user', 'update_goal_report']);
        expect((json['probes']! as List).length, fixture.truth.probes.length);
        expect((json['userVoice']! as Map)['verbatimCount'], greaterThan(0));
      },
    );

    test('a wrong status is recorded as incorrect, not hidden', () async {
      final runner = GoalCompactionEvalRunner(
        provider: provider,
        modelId: 'm',
        conversationRepository: _repo(container),
        inferenceRepository: _ScriptedInference(reportedStatus: 'onTrack'),
      );
      final packet = await runner.run(
        fixtures: [fixture],
        strategies: const [FullContextCheckInCompaction()],
        samples: 1,
      );
      final wake =
          packet.cases.single.toJson(goalCompactionEvalReference)['wake']!
              as Map;
      expect(wake['reportedStatus'], 'onTrack');
      expect(wake['expectedStatus'], 'offTrack');
      expect(wake['statusCorrect'], isFalse);
    });

    test(
      'an inference failure lands as an errored case with unanswered probes',
      () async {
        final runner = GoalCompactionEvalRunner(
          provider: provider,
          modelId: 'm',
          conversationRepository: _repo(container),
          inferenceRepository: _ScriptedInference(failOn: 'A few questions'),
        );
        final packet = await runner.run(
          fixtures: [fixture],
          strategies: const [FullContextCheckInCompaction()],
          samples: 1,
        );
        final c = packet.cases.single;
        expect(c.errorMessage, contains('scripted failure'));
        expect(
          c.reportedStatus,
          'offTrack',
          reason: 'the wake itself succeeded',
        );
        expect(c.probes.every((p) => p.answer == null), isTrue);
      },
    );

    test('the packet JSON is self-describing', () async {
      final runner = GoalCompactionEvalRunner(
        provider: provider,
        modelId: 'm',
        conversationRepository: _repo(container),
        inferenceRepository: _ScriptedInference(),
      );
      final packet = await runner.run(
        fixtures: [fixture],
        strategies: const [FullContextCheckInCompaction()],
        samples: 1,
        digestUsage: () => const {'calls': 3},
      );
      final json = jsonDecode(packet.toPrettyJson()) as Map<String, dynamic>;
      expect(json['kind'], goalCompactionEvalPacketKind);
      expect(json['modelId'], 'm');
      expect(json['digestUsage'], {'calls': 3});
      final f = (json['fixtures']! as List).single as Map<String, dynamic>;
      expect(f['id'], fixture.id);
      expect(f['checkInCount'], fixture.checkIns.length);
      expect((f['truth']! as Map)['expectedStatus'], 'offTrack');
      expect(
        ((f['truth'] as Map)['probes'] as List).length,
        fixture.truth.probes.length,
      );
    });
  });
}

ConversationRepository _repo(ProviderContainer container) =>
    container.read(conversationRepositoryProvider.notifier);
