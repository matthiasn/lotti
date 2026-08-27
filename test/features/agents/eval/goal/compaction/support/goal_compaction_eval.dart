/// Runner for the check-in compaction evaluation.
///
/// For every (fixture × strategy × sample) it renders the production FACTS
/// block with that strategy's `userVoice`, runs one wake through the
/// production prompt and tool contract, then asks the fact-recall probes as
/// a follow-up turn. Everything the judge needs — the FACTS the agent saw,
/// its report and reply, its probe answers, the answer key, and the
/// provider-reported tokens — lands in one JSON **judging packet**.
///
/// The packet is deliberately the seam: grading is a separate step (a model
/// reading the packet against `docs/evaluations/goal_agent_models/compaction.md`)
/// that writes a scores file in the schema `tool/goal_compaction_eval_report.dart`
/// merges. The deterministic metrics — status accuracy, tool-set agreement,
/// tokens, the growth curve — need no judge and are computed from the packet
/// alone.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';
import 'package:lotti/features/ai/repository/inference_repository_interface.dart';
import 'package:lotti/features/goals/logic/goal_checkin_compaction_strategy.dart';
import 'package:lotti/features/goals/workflow/goal_agent_contract.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../../../../../tool/goal_compaction_eval_report.dart';
import '../../support/goal_agent_eval_runner.dart';
import 'goal_compaction_facts.dart';
import 'goal_compaction_fixtures.dart';

/// The packet kind, shared with the report tool so the two cannot drift.
const String goalCompactionEvalPacketKind = goalCompactionPacketKind;

/// The horizons of the token growth curve, in months from the goal's start.
const goalCompactionEvalHorizons = [3, 6, 12, 18, 24];

// ── Digest writer ────────────────────────────────────────────────────────

const _digestSystemMessage =
    "You condense a span of a person's spoken check-ins about one personal "
    'goal into a faithful digest that a coach will read months or years '
    'later instead of the originals. Preserve, with dates where they were '
    'given: what actually happened to the numbers over the span; every '
    'commitment made and whether it was kept; setbacks, injuries, medical '
    'advice, and life changes; anything that changed about the goal itself; '
    "how the person's mood related to their results. Drop routine "
    'repetition. Write in plain prose within the word limit given. Never '
    'infer, advise or judge — record.';

/// Writes span digests with one inference call each, cached on disk by
/// content so a re-run of the evaluation (or a later horizon that folds
/// the same span) costs nothing.
class CachedLlmDigestWriter implements GoalCheckInDigestWriter {
  CachedLlmDigestWriter({
    required this.provider,
    required this.modelId,
    required this.conversationRepository,
    required this.inferenceRepository,
    required this.cacheDirectory,
    this.temperature = 0,
  });

  final AiConfigInferenceProvider provider;
  final String modelId;
  final ConversationRepository conversationRepository;
  final InferenceRepositoryInterface inferenceRepository;
  final Directory cacheDirectory;
  final double temperature;

  int calls = 0;
  int cacheHits = 0;
  InferenceUsage? usage;

  Map<String, Object?> get usageJson => {
    'calls': calls,
    'cacheHits': cacheHits,
    'inputTokens': usage?.inputTokens,
    'outputTokens': usage?.outputTokens,
  };

  @override
  Future<String> write(GoalCheckInDigestRequest request) async {
    final prompt = _prompt(request);
    final key = sha256.convert(utf8.encode('$modelId\n$prompt')).toString();
    final file = File('${cacheDirectory.path}/$key.json');
    if (file.existsSync()) {
      cacheHits++;
      final cached =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      return cached['digest'] as String;
    }

    calls++;
    final conversationId = conversationRepository.createConversation(
      systemMessage: _digestSystemMessage,
      maxTurns: 2,
    );
    try {
      final turnUsage = await conversationRepository.sendMessage(
        conversationId: conversationId,
        message: prompt,
        model: modelId,
        provider: provider,
        inferenceRepo: inferenceRepository,
        temperature: temperature,
        consumptionAgentId: 'goal_agent:compaction-eval-digest',
        consumptionWakeRunKey: 'goal-compaction-digest:${request.periodLabel}',
        rethrowInferenceErrors: true,
      );
      if (turnUsage != null) {
        final current = usage;
        usage = current == null ? turnUsage : current.merge(turnUsage);
      }
      final manager = conversationRepository.getConversation(conversationId);
      final digest = assistantText(manager).trim();
      if (digest.isEmpty) {
        throw StateError('empty digest for ${request.periodLabel}');
      }
      cacheDirectory.createSync(recursive: true);
      file.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert({
          'model': modelId,
          'period': request.periodLabel,
          'checkIns': request.checkIns.length,
          'digest': digest,
        }),
      );
      return digest;
    } finally {
      conversationRepository.deleteConversation(conversationId);
    }
  }

  String _prompt(GoalCheckInDigestRequest request) {
    final buffer = StringBuffer()
      ..writeln(
        'Span: ${request.periodLabel} (${request.layer.name}; '
        '${goalCompactionDayKey(request.from)} to ${goalCompactionDayKey(request.to)}), '
        '${request.checkIns.length} check-ins, oldest first. '
        'Word limit: ${request.maxWords}.',
      )
      ..writeln();
    for (final c in request.checkIns) {
      buffer.writeln(
        '${goalCompactionDayKey(c.recordedAt)}: ${c.whatHappened}',
      );
      if (c.committedTo != null) {
        buffer.writeln('  committed to: ${c.committedTo}');
      }
      if (c.blockers != null) buffer.writeln('  blockers: ${c.blockers}');
      if (c.mood != null) buffer.writeln('  mood: ${c.mood}');
    }
    return buffer.toString();
  }
}

/// Plain assistant text across a conversation, newline-joined.
String assistantText(ConversationManager? manager) {
  if (manager == null) return '';
  return manager.messages
      .map((m) => m.mapOrNull(assistant: (a) => a.content) ?? '')
      .where((c) => c.isNotEmpty)
      .join('\n');
}

// ── Results ──────────────────────────────────────────────────────────────

/// One probe with the agent's answer alongside the key.
class GoalCompactionProbeResult {
  const GoalCompactionProbeResult({
    required this.probe,
    required this.answer,
    required this.basis,
  });

  final GoalCompactionProbe probe;

  /// Null when the agent produced no parseable answer for this probe.
  final String? answer;

  /// `history`, `notInHistory`, or null when unparseable.
  final String? basis;

  Map<String, Object?> toJson(DateTime reference) => {
    ...probe.toJson(reference),
    'answer': answer,
    'basis': basis,
  };
}

/// One (fixture × strategy × sample) run.
class GoalCompactionCaseResult {
  const GoalCompactionCaseResult({
    required this.fixture,
    required this.strategyId,
    required this.modelId,
    required this.sample,
    required this.facts,
    required this.userVoice,
    required this.toolCalls,
    required this.assistantContent,
    required this.probes,
    required this.latencyMs,
    this.wakeUsage,
    this.probeUsage,
    this.errorMessage,
  });

  final GoalCompactionFixture fixture;
  final String strategyId;
  final String modelId;
  final int sample;
  final String facts;
  final GoalUserVoiceContext userVoice;
  final List<GoalAgentEvalToolCall> toolCalls;
  final String assistantContent;
  final List<GoalCompactionProbeResult> probes;
  final int latencyMs;
  final InferenceUsage? wakeUsage;
  final InferenceUsage? probeUsage;
  final String? errorMessage;

  /// The status the wake reported, from the last `update_goal_report`.
  String? get reportedStatus {
    for (final call in toolCalls.reversed) {
      if (call.name == GoalAgentToolNames.updateGoalReport &&
          call.exchangeIndex == 0) {
        final status = call.jsonObjectArguments?['status'];
        if (status is String) return status;
      }
    }
    return null;
  }

  String? get reportOneLiner {
    for (final call in toolCalls.reversed) {
      if (call.name == GoalAgentToolNames.updateGoalReport) {
        final oneLiner = call.jsonObjectArguments?['oneLiner'];
        if (oneLiner is String) return oneLiner;
      }
    }
    return null;
  }

  /// The wake's reply to the pending user message — the recommendation.
  String? get wakeReply => _replyText(0);

  /// Names of the tools called during the wake, sorted, for set agreement.
  List<String> get wakeToolNames => ([
    for (final call in toolCalls)
      if (call.exchangeIndex == 0) call.name,
  ]..sort());

  String? _replyText(int exchange) {
    final replies = [
      for (final call in toolCalls)
        if (call.name == GoalAgentToolNames.replyToUser &&
            call.exchangeIndex == exchange)
          if (call.jsonObjectArguments?['message'] case final String m)
            if (m.trim().isNotEmpty) m,
    ];
    return replies.isEmpty ? null : replies.join('\n');
  }

  Map<String, Object?> toJson(DateTime reference) => {
    'fixtureId': fixture.id,
    'strategyId': strategyId,
    'modelId': modelId,
    'sample': sample,
    'facts': facts,
    'userVoice': {
      'estimatedTokens': userVoice.estimatedTokens,
      'verbatimCount': userVoice.verbatimCount,
      'digestCount': userVoice.digestCount,
      'entries': userVoice.entries,
    },
    'wake': {
      'expectedStatus': fixture.truth.expectedStatus.name,
      'reportedStatus': reportedStatus,
      'statusCorrect': reportedStatus == fixture.truth.expectedStatus.name,
      'oneLiner': reportOneLiner,
      'reply': wakeReply,
      'toolNames': wakeToolNames,
      'toolCalls': [
        for (final call in toolCalls)
          if (call.exchangeIndex == 0) call.toJson(),
      ],
      'assistantContent': assistantContent,
      'inputTokens': wakeUsage?.inputTokens,
      'outputTokens': wakeUsage?.outputTokens,
      'thoughtsTokens': wakeUsage?.thoughtsTokens,
      'cachedInputTokens': wakeUsage?.cachedInputTokens,
    },
    'probes': [for (final p in probes) p.toJson(reference)],
    'probeTurn': {
      'inputTokens': probeUsage?.inputTokens,
      'outputTokens': probeUsage?.outputTokens,
      'raw': _replyText(1) ?? '',
    },
    'latencyMs': latencyMs,
    'errorMessage': errorMessage,
  };
}

/// One point on the token growth curve.
class GoalCompactionGrowthPoint {
  const GoalCompactionGrowthPoint({
    required this.fixtureId,
    required this.strategyId,
    required this.months,
    required this.checkIns,
    required this.context,
  });

  final String fixtureId;
  final String strategyId;
  final int months;
  final int checkIns;
  final GoalUserVoiceContext context;

  Map<String, Object?> toJson() => {
    'fixtureId': fixtureId,
    'strategyId': strategyId,
    'months': months,
    'checkIns': checkIns,
    'estimatedTokens': context.estimatedTokens,
    'verbatimCount': context.verbatimCount,
    'digestCount': context.digestCount,
  };
}

/// The judging packet.
class GoalCompactionEvalPacket {
  const GoalCompactionEvalPacket({
    required this.provider,
    required this.modelId,
    required this.temperature,
    required this.reference,
    required this.strategyIds,
    required this.fixtures,
    required this.cases,
    required this.growthCurve,
    required this.digestUsage,
  });

  final AiConfigInferenceProvider provider;
  final String modelId;
  final double temperature;
  final DateTime reference;
  final List<String> strategyIds;
  final List<GoalCompactionFixture> fixtures;
  final List<GoalCompactionCaseResult> cases;
  final List<GoalCompactionGrowthPoint> growthCurve;
  final Map<String, Object?> digestUsage;

  Map<String, Object?> toJson() => {
    'kind': goalCompactionEvalPacketKind,
    'provider': {
      'id': provider.id,
      'type': provider.inferenceProviderType.name,
      'baseUrl': provider.baseUrl,
    },
    'modelId': modelId,
    'temperature': temperature,
    'reference': reference.toIso8601String(),
    'strategyIds': strategyIds,
    'fixtures': [
      for (final f in fixtures)
        {
          'id': f.id,
          'title': f.title,
          'statement': f.statement,
          'checkInCount': f.checkIns.length,
          'startDate': f.startDate.toIso8601String(),
          'transitionFrom': f.transitionFrom.name,
          'truth': f.truth.toJson(reference),
        },
    ],
    'cases': [for (final c in cases) c.toJson(reference)],
    'growthCurve': [for (final g in growthCurve) g.toJson()],
    'digestUsage': digestUsage,
  };

  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert(toJson());
}

// ── Probe turn ───────────────────────────────────────────────────────────

/// The follow-up message that asks the probes. Answers come back through
/// `reply_to_user` as JSON so they can be matched to probe ids.
String goalCompactionProbeMessage(List<GoalCompactionProbe> probes) {
  final buffer = StringBuffer()
    ..writeln(
      'A few questions about the history of this goal. Answer each one '
      'strictly from what you were given about my own check-ins; if the '
      'history you have does not contain the answer, say so rather than '
      'guessing. Reply by calling reply_to_user exactly once, with message '
      'set to ONLY a JSON object of this shape: '
      '{"answers":[{"id":"<question id>","answer":"<one or two sentences>", '
      '"basis":"history" or "notInHistory"}]}',
    )
    ..writeln();
  for (final probe in probes) {
    buffer.writeln('- ${probe.id}: ${probe.question}');
  }
  return buffer.toString();
}

/// Parses the probe answers out of the agent's reply (or, failing that, its
/// plain text). Unparseable answers are null, never guessed.
List<GoalCompactionProbeResult> parseGoalCompactionProbeAnswers(
  List<GoalCompactionProbe> probes,
  String raw,
) {
  final answers = <String, Map<String, dynamic>>{};
  final start = raw.indexOf('{');
  final end = raw.lastIndexOf('}');
  if (start >= 0 && end > start) {
    try {
      final decoded = jsonDecode(raw.substring(start, end + 1));
      final list = decoded is Map ? decoded['answers'] : null;
      if (list is List) {
        for (final item in list) {
          if (item is Map<String, dynamic> && item['id'] is String) {
            answers[item['id'] as String] = item;
          }
        }
      }
    } on FormatException {
      // Fall through: every probe reads as unanswered.
    }
  }
  return [
    for (final probe in probes)
      GoalCompactionProbeResult(
        probe: probe,
        answer: answers[probe.id]?['answer'] is String
            ? answers[probe.id]!['answer'] as String
            : null,
        basis: answers[probe.id]?['basis'] is String
            ? answers[probe.id]!['basis'] as String
            : null,
      ),
  ];
}

// ── Runner ───────────────────────────────────────────────────────────────

class GoalCompactionEvalRunner {
  GoalCompactionEvalRunner({
    required this.provider,
    required this.modelId,
    required this.conversationRepository,
    required this.inferenceRepository,
    this.temperature = 0,
    this.maxTurnsPerExchange = 6,
    this.reference,
    this.log,
  });

  final AiConfigInferenceProvider provider;
  final String modelId;
  final ConversationRepository conversationRepository;
  final InferenceRepositoryInterface inferenceRepository;
  final double temperature;
  final int maxTurnsPerExchange;
  final DateTime? reference;
  final void Function(String)? log;

  DateTime get _reference => reference ?? goalCompactionEvalReference;

  Future<GoalCompactionEvalPacket> run({
    required List<GoalCompactionFixture> fixtures,
    required List<GoalCheckInCompactionStrategy> strategies,
    required int samples,
    // Read AFTER the run: the digest writer's counters only exist then.
    Map<String, Object?> Function()? digestUsage,
    List<int> horizons = goalCompactionEvalHorizons,
  }) async {
    final cases = <GoalCompactionCaseResult>[];
    final growth = <GoalCompactionGrowthPoint>[];

    for (final fixture in fixtures) {
      final derivation = deriveGoalCompactionFacts(
        fixture,
        reference: _reference,
      );
      for (final strategy in strategies) {
        // Growth curve first: it needs no agent call, and it warms the
        // digest cache for the spans the full-horizon wake will fold.
        for (final months in horizons) {
          final prefix = fixture.upTo(months);
          final context = await strategy.build(prefix, reference: _reference);
          growth.add(
            GoalCompactionGrowthPoint(
              fixtureId: fixture.id,
              strategyId: strategy.id,
              months: months,
              checkIns: prefix.length,
              context: context,
            ),
          );
        }

        final context = await strategy.build(
          fixture.checkIns,
          reference: _reference,
        );
        final facts = renderGoalCompactionFacts(
          fixture,
          derivation,
          userVoice: context.entries,
          reference: _reference,
        );
        for (var sample = 1; sample <= samples; sample++) {
          log?.call('${fixture.id} × ${strategy.id} × s$sample');
          cases.add(
            await _runCase(fixture, strategy.id, sample, facts, context),
          );
        }
      }
    }

    return GoalCompactionEvalPacket(
      provider: provider,
      modelId: modelId,
      temperature: temperature,
      reference: _reference,
      strategyIds: [for (final s in strategies) s.id],
      fixtures: fixtures,
      cases: cases,
      growthCurve: growth,
      digestUsage: digestUsage?.call() ?? const {},
    );
  }

  Future<GoalCompactionCaseResult> _runCase(
    GoalCompactionFixture fixture,
    String strategyId,
    int sample,
    String facts,
    GoalUserVoiceContext context,
  ) async {
    final stopwatch = Stopwatch()..start();
    final strategy = GoalAgentEvalStrategy();
    final conversationId = conversationRepository.createConversation(
      systemMessage: goalAgentSystemPrompt,
      maxTurns: maxTurnsPerExchange * 2,
    );
    final manager = conversationRepository.getConversation(conversationId);
    final tools = [
      for (final tool in goalAgentTools)
        // Mirrors the runtime: a wake whose status rules out a banner is not
        // offered the ad tools. Off-track is the only fixture status that
        // would be; keeping the surface uniform across arms is what makes
        // the tool-set comparison meaningful.
        if (tool.name != GoalAgentToolNames.createGoalAd &&
            tool.name != GoalAgentToolNames.rerunGoalAd)
          ChatCompletionTool(
            type: ChatCompletionToolType.function,
            function: FunctionObject(
              name: tool.name,
              description: tool.description,
              parameters: tool.parameters,
            ),
          ),
    ];

    Future<InferenceUsage?> exchange(int index, String message) {
      strategy.beginExchange(index);
      return conversationRepository.sendMessage(
        conversationId: conversationId,
        message: message,
        model: modelId,
        provider: provider,
        inferenceRepo: inferenceRepository,
        tools: tools,
        temperature: temperature,
        strategy: strategy,
        consumptionAgentId: 'goal_agent:compaction-eval',
        consumptionWakeRunKey:
            'goal-compaction:${fixture.id}:$strategyId:$sample',
        consumptionThreadId: fixture.id,
        rethrowInferenceErrors: true,
      );
    }

    InferenceUsage? wakeUsage;
    InferenceUsage? probeUsage;
    try {
      wakeUsage = await exchange(0, facts);
      probeUsage = await exchange(
        1,
        goalCompactionProbeMessage(fixture.truth.probes),
      );
      final probeRaw = [
        for (final call in strategy.toolCalls)
          if (call.exchangeIndex == 1 &&
              call.name == GoalAgentToolNames.replyToUser)
            if (call.jsonObjectArguments?['message'] case final String m) m,
      ].join('\n');
      final content = assistantText(manager);
      return GoalCompactionCaseResult(
        fixture: fixture,
        strategyId: strategyId,
        modelId: modelId,
        sample: sample,
        facts: facts,
        userVoice: context,
        toolCalls: strategy.toolCalls,
        assistantContent: content,
        probes: parseGoalCompactionProbeAnswers(
          fixture.truth.probes,
          probeRaw.isEmpty ? content : probeRaw,
        ),
        latencyMs: stopwatch.elapsedMilliseconds,
        wakeUsage: wakeUsage,
        probeUsage: probeUsage,
      );
    } catch (error) {
      return GoalCompactionCaseResult(
        fixture: fixture,
        strategyId: strategyId,
        modelId: modelId,
        sample: sample,
        facts: facts,
        userVoice: context,
        toolCalls: strategy.toolCalls,
        assistantContent: assistantText(manager),
        probes: parseGoalCompactionProbeAnswers(fixture.truth.probes, ''),
        latencyMs: stopwatch.elapsedMilliseconds,
        wakeUsage: wakeUsage,
        probeUsage: probeUsage,
        errorMessage: error.toString(),
      );
    } finally {
      conversationRepository.deleteConversation(conversationId);
    }
  }
}

/// Convenience for tests and the live driver: the three arms.
List<GoalCheckInCompactionStrategy> goalCompactionEvalArms(
  GoalCheckInDigestWriter digestWriter,
) => [
  const FullContextCheckInCompaction(),
  const TruncatingCheckInCompaction(),
  HierarchicalCheckInCompaction(digestWriter: digestWriter),
];
