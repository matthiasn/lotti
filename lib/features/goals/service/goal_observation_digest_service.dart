import 'package:clock/clock.dart';
import 'package:lotti/classes/agents/agent_config.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/classes/ai_attribution.dart';
import 'package:lotti/database/agents/agent_repository.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/workflow/agent_observations.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/one_shot_text_generation.dart';
import 'package:lotti/features/ai/service/text_chunker.dart';
import 'package:lotti/features/ai_consumption/service/ai_interaction_capture.dart';
import 'package:lotti/features/goals/model/goal_checkin_weight.dart';
import 'package:lotti/features/goals/workflow/goal_facts_renderer.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:openai_dart/openai_dart.dart';

/// Tool name marking a stored month of observations in the agent log.
const goalObservationDigestToolName = 'goal_observation_digest';

/// How many months one wake may digest. A goal agent with a year of notes
/// digests it over a few wakes rather than in one.
const goalObservationDigestsPerWake = 2;

/// Tokens the digests may take in a wake's FACTS, newest month first.
const goalObservationDigestTokenBudget = 600;

/// The word limit a month's digest is written to.
const goalObservationDigestWords = 120;

/// Deterministic id of one month's digest — the month is the key, so a month
/// digested on two devices converges on one row.
String goalObservationDigestId(String agentId, String month) =>
    'goal_observation_digest:$agentId:$month';

/// The local calendar month [at] falls in, as `YYYY-MM`.
String goalObservationMonth(DateTime at) {
  final local = at.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  return '${local.year.toString().padLeft(4, '0')}-$month';
}

/// A stored digest of one month of the agent's observations.
class GoalObservationDigest {
  const GoalObservationDigest({
    required this.month,
    required this.noteIds,
    required this.text,
    required this.writtenAt,
  });

  /// `YYYY-MM`, as [goalObservationMonth] names it.
  final String month;

  /// Every observation the digest was written from. Grows when a note syncs
  /// in late; never shrinks, so a note pruned from the store after it was
  /// digested lives on in [text].
  final List<String> noteIds;
  final String text;
  final DateTime writtenAt;

  Map<String, Object?> toContent() => {
    'month': month,
    'noteIds': noteIds,
    'text': text,
    'writtenAt': writtenAt.toUtc().toIso8601String(),
  };

  static GoalObservationDigest? fromContent(Map<String, Object?> content) {
    final month = content['month'];
    final noteIds = content['noteIds'];
    final text = content['text'];
    final writtenAt = DateTime.tryParse(content['writtenAt'] as String? ?? '');
    if (month is! String ||
        noteIds is! List ||
        text is! String ||
        text.trim().isEmpty ||
        writtenAt == null) {
      return null;
    }
    return GoalObservationDigest(
      month: month,
      noteIds: [...noteIds.whereType<String>()],
      text: text.trim(),
      writtenAt: writtenAt,
    );
  }
}

/// The system prompt a month's digest is written under, by [weight].
String goalObservationDigestSystemMessage(GoalCheckInWeight weight) =>
    switch (weight) {
      GoalCheckInWeight.context => _contextSystemMessage,
      GoalCheckInWeight.substance => _substanceSystemMessage,
    };

const String _contextSystemMessage =
    "You condense one month of a coach's private notes about a person "
    'working on one personal goal into a faithful digest the coach will read '
    'months or years later instead of the notes. Preserve, with dates where '
    'they were given: constraints, injuries, medical advice and life '
    'changes; what the person found helps or gets in the way; how they took '
    'the coaching; patterns across the month; commitments and whether they '
    'were kept. Drop repetition and anything that only restates progress '
    'numbers. Write plain prose within the word limit given, in the language '
    'of the notes. Never add what the notes do not say.';

/// For a goal whose check-ins are its substance — a journal — where what the
/// person thinks and how it moves is the memory worth keeping.
const String _substanceSystemMessage =
    "You condense one month of a coach's private notes about a person whose "
    'goal is a journal or another reflective practice — their check-ins ARE '
    'the goal — into a faithful digest the coach will read months or years '
    'later instead of the notes. Preserve, with dates where they were given: '
    'the themes they kept returning to; insights, decisions and open '
    'questions; how their thinking or mood moved; what helps them reflect '
    'and what gets in the way; how they took the coaching; life changes and '
    'constraints. Drop repetition. Write plain prose within the word limit '
    'given, in the language of the notes. Never add what the notes do not '
    'say.';

/// Placeholder for a month whose digest is not yet written: the agent learns
/// a stretch of its memory exists and is not yet readable.
String goalObservationDigestPlaceholder(int notes) =>
    '($notes notes from this month are not yet digested)';

/// Compacts a goal agent's older observations into one digest per finished
/// month, and picks the digests a wake reads (ADR 0156).
///
/// A wake reads its newest observations verbatim and the older critical
/// ones (`goalObservationSelection`); everything else used to fall out of
/// view, and after 180 days out of the store. A finished month is digested
/// once, with the wake's own model, under a prompt for the goal's
/// [GoalCheckInWeight], and rewritten only when a note it has not seen syncs
/// in — folding its earlier text in, so notes pruned since are never lost.
/// Inference runs only on wakes that allow it and at most
/// [goalObservationDigestsPerWake] times per wake. Never throws: memory is
/// additive context, and a digest that could not be read or written must
/// not cost the wake.
class GoalObservationDigestService {
  GoalObservationDigestService({
    required CloudInferenceRepository inferenceRepository,
    required this._repository,
    required this._syncService,
    this._domainLogger,
    this.maxDigestTokens = 400,
  }) : _inference = inferenceRepository;

  final CloudInferenceRepository _inference;
  final AgentRepository _repository;
  final AgentSyncService _syncService;
  final DomainLogger? _domainLogger;

  /// The hard stop behind the word limit in the prompt.
  final int maxDigestTokens;

  static const double _temperature = 0.3;

  /// The month digests a wake of [agentId] reads, newest first, within
  /// [tokenBudget] — writing up to [goalObservationDigestsPerWake] missing
  /// or outdated ones first when [allowInference].
  ///
  /// [recalled] is the agent's observation window, newest first; a month is
  /// shown unless every note of it is among [shownVerbatim]. The current month
  /// is never digested: it is still being written.
  Future<List<GoalObservationDigestFact>> digests({
    required String agentId,
    required List<RecalledObservation> recalled,
    required Set<String> shownVerbatim,
    required String goalStatement,
    required String model,
    required AiConfigInferenceProvider provider,
    required bool allowInference,
    required GoalCheckInWeight weight,
    int tokenBudget = goalObservationDigestTokenBudget,
  }) async {
    try {
      final current = goalObservationMonth(clock.now());
      final byMonth = <String, List<RecalledObservation>>{};
      for (final observation in recalled) {
        final month = goalObservationMonth(observation.at);
        if (month.compareTo(current) >= 0) continue;
        (byMonth[month] ??= []).add(observation);
      }
      final stored = await _stored(agentId);
      final months = {...byMonth.keys, ...stored.keys}.toList()
        ..sort((a, b) => b.compareTo(a));

      final shown = <GoalObservationDigestFact>[];
      var written = 0;
      var spent = 0;
      for (final month in months) {
        final notes = [...?byMonth[month]].reversed.toList();
        var digest = stored[month];
        final known = {...?digest?.noteIds};
        final outdated = notes.any((note) => !known.contains(note.id));
        if (outdated &&
            allowInference &&
            written < goalObservationDigestsPerWake) {
          written++;
          digest =
              await _write(
                agentId: agentId,
                month: month,
                notes: notes,
                earlier: digest,
                goalStatement: goalStatement,
                model: model,
                provider: provider,
                weight: weight,
              ) ??
              digest;
        }
        final needed =
            notes.isEmpty ||
            notes.any((note) => !shownVerbatim.contains(note.id));
        if (!needed) continue;
        final text =
            digest?.text ?? goalObservationDigestPlaceholder(notes.length);
        final cost = TextChunker.estimateTokens(text);
        if (spent + cost > tokenBudget) continue;
        spent += cost;
        shown.add((
          month: month,
          notes: digest == null
              ? notes.length
              : {...digest.noteIds, ...notes.map((n) => n.id)}.length,
          text: text,
        ));
      }
      return shown;
    } catch (error, stackTrace) {
      _domainLogger?.error(
        LogDomain.agentWorkflow,
        error,
        subDomain: 'goalObservationDigest',
        message: 'observation digests unavailable for this wake',
        stackTrace: stackTrace,
      );
      return const [];
    }
  }

  /// Every stored month digest of [agentId], by month.
  Future<Map<String, GoalObservationDigest>> _stored(String agentId) async {
    final messages = await _repository.getMessagesByKindAndToolName(
      agentId,
      AgentMessageKind.action,
      goalObservationDigestToolName,
    );
    final digests = <String, GoalObservationDigest>{};
    for (final message in messages) {
      final payloadId = message.contentEntryId;
      if (payloadId == null) continue;
      final payload = await _repository.getEntity(payloadId);
      if (payload is! AgentMessagePayloadEntity) continue;
      final digest = GoalObservationDigest.fromContent(payload.content);
      if (digest != null) digests[digest.month] = digest;
    }
    return digests;
  }

  /// Writes and stores [month]'s digest from [notes] (oldest first) and the
  /// [earlier] digest of it, or returns null when that fails.
  Future<GoalObservationDigest?> _write({
    required String agentId,
    required String month,
    required List<RecalledObservation> notes,
    required GoalObservationDigest? earlier,
    required String goalStatement,
    required String model,
    required AiConfigInferenceProvider provider,
    required GoalCheckInWeight weight,
  }) async {
    try {
      final text = (await _inference.generateText(
        prompt: goalObservationDigestPrompt(
          goalStatement: goalStatement,
          month: month,
          notes: notes,
          earlier: earlier?.text,
        ),
        systemMessage: goalObservationDigestSystemMessage(weight),
        model: model,
        provider: provider,
        temperature: _temperature,
        maxCompletionTokens: maxDigestTokens,
        geminiThinkingMode: GeminiThinkingMode.minimal,
        reasoningEffort: ReasoningEffort.minimal,
        attribution: OneShotGenerationAttribution(
          workType: AiWorkType.internalInference,
          triggerType: AiTriggerType.automatic,
          automationId: 'automation:goal-observation-digest',
          automationDisplayName: 'Goal observation digest',
          interactionContext: AiCapturedContext(agentId: agentId),
        ),
      )).trim();
      if (text.isEmpty) {
        throw const FormatException('observation digest returned no text');
      }
      final digest = GoalObservationDigest(
        month: month,
        noteIds: {...?earlier?.noteIds, ...notes.map((n) => n.id)}.toList(),
        text: text,
        writtenAt: clock.now(),
      );
      await _persist(agentId, digest);
      return digest;
    } catch (error, stackTrace) {
      _domainLogger?.error(
        LogDomain.agentWorkflow,
        error,
        subDomain: 'goalObservationDigest',
        message: 'goal observation digest failed for $month',
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<void> _persist(String agentId, GoalObservationDigest digest) async {
    final id = goalObservationDigestId(agentId, digest.month);
    final payloadId = '$id:payload';
    await _syncService.runInTransaction(() async {
      await _syncService.upsertEntity(
        AgentDomainEntity.agentMessagePayload(
          id: payloadId,
          agentId: agentId,
          createdAt: digest.writtenAt,
          vectorClock: null,
          content: digest.toContent(),
        ),
      );
      await _syncService.upsertEntity(
        AgentDomainEntity.agentMessage(
          id: id,
          agentId: agentId,
          threadId: id,
          // An action, like the check-in digests: as an observation it would
          // count among the notes it digests, and the retention sweep, which
          // forgets observations after 180 days, would forget it too.
          kind: AgentMessageKind.action,
          createdAt: digest.writtenAt,
          vectorClock: null,
          metadata: const AgentMessageMetadata(
            toolName: goalObservationDigestToolName,
          ),
          contentEntryId: payloadId,
        ),
      );
    });
  }
}

/// The prompt one month's digest is written from: the goal, the month, the
/// [earlier] digest of it when a late note is folded in, and its [notes]
/// oldest first, critical ones marked.
String goalObservationDigestPrompt({
  required String goalStatement,
  required String month,
  required List<RecalledObservation> notes,
  String? earlier,
}) {
  final buffer = StringBuffer()
    ..writeln('Goal: $goalStatement')
    ..writeln()
    ..writeln(
      'Month: $month, ${notes.length} notes, oldest first. '
      'Word limit: $goalObservationDigestWords.',
    );
  if (earlier != null) {
    buffer
      ..writeln()
      ..writeln(
        'Your earlier digest of this month, which may cover notes no longer '
        'listed — keep what it says:',
      )
      ..writeln(earlier);
  }
  buffer.writeln();
  for (final note in notes) {
    final day = note.at.toLocal().toIso8601String().substring(0, 10);
    final mark = note.priority == ObservationPriority.critical
        ? ' (critical)'
        : '';
    buffer.writeln('$day$mark: ${note.text}');
  }
  return buffer.toString();
}
