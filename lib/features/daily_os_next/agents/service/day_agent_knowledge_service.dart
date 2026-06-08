import 'package:clock/clock.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/daily_os_next/agents/domain/planner_knowledge.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_capture_service.dart'
    show DayAgentDirectToolResult;
import 'package:lotti/features/daily_os_next/agents/tools/day_agent_tool_names.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:uuid/uuid.dart';

/// Raised by the durable-knowledge service for an invalid tool/argument.
class DayAgentKnowledgeException implements Exception {
  const DayAgentKnowledgeException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Backend for durable planner knowledge — the compaction-exempt
/// "memorize what I tell you" store (ADR 0022 Decisions 9–10).
///
/// The agent proposes knowledge via `propose_knowledge`; a `userStated`
/// instruction skips straight to confirmed (the user said it). The user gates
/// agent-inferred entries (and edits/retracts) through the "What I've learned"
/// panel via [confirm] / [retract] / [editStatement]. Recency-wins supersession
/// (ADR 0022 Decision 10) is realized by the Head selection in
/// `activePlannerKnowledge`; this service just appends/updates entries.
class DayAgentKnowledgeService {
  DayAgentKnowledgeService({
    required this.agentRepository,
    required this.syncService,
    required this.domainLogger,
    this.onPersistedStateChanged,
  });

  /// Agent entity repository.
  final AgentRepository agentRepository;

  /// Sync-aware writer.
  final AgentSyncService syncService;

  /// Structured logger.
  final DomainLogger domainLogger;

  /// Callback fired when persisted state changes.
  final void Function(String id)? onPersistedStateChanged;

  static const _uuid = Uuid();
  static const int _maxHookLength = knowledgeHookMaxLength;

  /// Executes a durable-knowledge tool emitted by the agent.
  Future<DayAgentDirectToolResult> executeTool({
    required String agentId,
    required String toolName,
    required Map<String, dynamic> args,
  }) async {
    try {
      final data = switch (toolName) {
        DayAgentToolNames.proposeKnowledge => await _proposeTool(agentId, args),
        _ => throw DayAgentKnowledgeException('unknown tool "$toolName"'),
      };
      return DayAgentDirectToolResult.success(data);
    } on DayAgentKnowledgeException catch (e) {
      return DayAgentDirectToolResult.failure(e.message);
    } catch (e, s) {
      domainLogger.error(
        LogDomain.agentWorkflow,
        e,
        message: 'durable-knowledge tool failed',
        stackTrace: s,
      );
      return DayAgentDirectToolResult.failure(e.toString());
    }
  }

  Future<Map<String, Object?>> _proposeTool(
    String agentId,
    Map<String, dynamic> args,
  ) async {
    final key = _requireString(args, 'key');
    final hook = _requireString(args, 'hook');
    final statement = _requireString(args, 'statement');
    final value = _optionalString(args, 'value') ?? '';
    // Scope is validated by `propose` (the single choke point); pass it through.
    final scope = _optionalString(args, 'scope') ?? knowledgeGlobalScope;
    // `hook` and `scope` are both validated by `propose` (the single choke
    // point); pass them through.
    // Reject unknown source values rather than silently downgrading a
    // malformed payload to agentInferred.
    final sourceArg = _optionalString(args, 'source') ?? 'agentInferred';
    final source = switch (sourceArg) {
      'userStated' => KnowledgeSource.userStated,
      'agentInferred' => KnowledgeSource.agentInferred,
      _ => throw const DayAgentKnowledgeException(
        '"source" must be "userStated" or "agentInferred".',
      ),
    };

    final rawTags = args['tags'];
    final tags = rawTags is List
        ? <String>[
            for (final t in rawTags)
              if (t is String) t,
          ]
        : const <String>[];

    final entry = await propose(
      agentId: agentId,
      key: key,
      hook: hook,
      statement: statement,
      value: value,
      scope: scope,
      source: source,
      tags: tags,
    );
    return {
      'id': entry.id,
      'key': entry.key,
      'status': entry.status.name,
    };
  }

  /// Propose (or supersede) a durable-knowledge entry for [key].
  ///
  /// A `userStated` source is confirmed immediately (the user said it); an
  /// `agentInferred` source lands `proposed`, awaiting the panel gate. When a
  /// confirmed entry already exists for [key], the new entry records it via
  /// `supersedesId` (recency wins).
  Future<PlannerKnowledgeEntity> propose({
    required String agentId,
    required String key,
    required String hook,
    required String statement,
    String value = '',
    String scope = knowledgeGlobalScope,
    KnowledgeSource source = KnowledgeSource.agentInferred,
    List<String> tags = const [],
  }) async {
    // Validate at the public choke point (not just the tool wrapper): a
    // malformed scope stored here would silently never match any wake's
    // touched scopes, hiding the knowledge forever — reject it loudly instead.
    final resolvedScope = _validScope(scope);
    // The hook is the always-on index tier (ADR 0022 Decision 10) injected into
    // every system prompt; an oversized hook is bloat, so reject it here too
    // (programmatic callers bypass the tool wrapper).
    _validHook(hook);
    final now = clock.now();
    final active = await _activeFor(agentId);
    final prior = active.where((e) => e.key == key).firstOrNull;
    final confirmed = source == KnowledgeSource.userStated;
    final entry =
        AgentDomainEntity.plannerKnowledge(
              id: 'planner_knowledge_${_uuid.v4()}',
              agentId: agentId,
              key: key,
              hook: hook,
              statementText: statement,
              source: source,
              status: confirmed
                  ? KnowledgeStatus.confirmed
                  : KnowledgeStatus.proposed,
              createdAt: now,
              updatedAt: now,
              vectorClock: null,
              value: value,
              scope: resolvedScope,
              tags: _normalizeTags(tags),
              supersedesId: prior?.id,
              confirmedAt: confirmed ? now : null,
            )
            as PlannerKnowledgeEntity;
    await syncService.upsertEntity(entry);
    onPersistedStateChanged?.call(agentId);
    domainLogger.log(
      LogDomain.agentRuntime,
      'proposed knowledge ${DomainLogger.sanitizeId(key)} '
      '(${entry.status.name})',
      subDomain: 'knowledge',
    );
    return entry;
  }

  /// Confirm a proposed entry (user gate from the panel).
  Future<PlannerKnowledgeEntity?> confirm(String entryId) async {
    final entry = await _load(entryId);
    if (entry == null) return null;
    final now = clock.now();
    final updated = entry.copyWith(
      status: KnowledgeStatus.confirmed,
      confirmedAt: now,
      updatedAt: now,
    );
    await syncService.upsertEntity(updated);
    onPersistedStateChanged?.call(entry.agentId);
    return updated;
  }

  /// Retract an entry (user gate from the panel) — removes it from the active
  /// Head set without deleting history.
  Future<PlannerKnowledgeEntity?> retract(String entryId) async {
    final entry = await _load(entryId);
    if (entry == null) return null;
    final now = clock.now();
    final updated = entry.copyWith(
      status: KnowledgeStatus.retracted,
      retractedAt: now,
      updatedAt: now,
    );
    await syncService.upsertEntity(updated);
    onPersistedStateChanged?.call(entry.agentId);
    return updated;
  }

  /// Edit an entry's statement/hook in place (panel edit), re-confirming it and
  /// clearing any pending staleness review.
  Future<PlannerKnowledgeEntity?> editStatement(
    String entryId, {
    required String hook,
    required String statement,
    String? value,
  }) async {
    final entry = await _load(entryId);
    if (entry == null) return null;
    // Same always-on-index ceiling as `propose`: a panel edit must not be able
    // to grow the hook past the bound either.
    _validHook(hook);
    final now = clock.now();
    final updated = entry.copyWith(
      hook: hook,
      statementText: statement,
      value: value ?? entry.value,
      status: KnowledgeStatus.confirmed,
      confirmedAt: now,
      // A fresh edit re-confirms the entry, so clear any pending staleness
      // review (it is no longer stale).
      reviewAfter: null,
      updatedAt: now,
    );
    await syncService.upsertEntity(updated);
    onPersistedStateChanged?.call(entry.agentId);
    return updated;
  }

  /// All durable-knowledge entries for [agentId] (every status/version).
  Future<List<PlannerKnowledgeEntity>> allFor(String agentId) async {
    final rows = await agentRepository.getEntitiesByAgentId(
      agentId,
      type: AgentEntityTypes.plannerKnowledge,
    );
    return rows.whereType<PlannerKnowledgeEntity>().toList();
  }

  /// The active Head set of confirmed knowledge for [agentId].
  Future<List<PlannerKnowledgeEntity>> activeFor(String agentId) =>
      _activeFor(agentId);

  Future<List<PlannerKnowledgeEntity>> _activeFor(String agentId) async {
    return activePlannerKnowledge(await allFor(agentId));
  }

  Future<PlannerKnowledgeEntity?> _load(String entryId) async {
    final entity = await agentRepository.getEntity(entryId);
    return entity?.mapOrNull(plannerKnowledge: (e) => e);
  }

  static String _requireString(Map<String, dynamic> args, String name) {
    final raw = args[name];
    if (raw is! String || raw.trim().isEmpty) {
      throw DayAgentKnowledgeException('"$name" must be a non-empty string.');
    }
    return raw.trim();
  }

  static String? _optionalString(Map<String, dynamic> args, String name) {
    final raw = args[name];
    if (raw is! String || raw.trim().isEmpty) return null;
    return raw.trim();
  }

  /// Validates a scope string: `global` (default), or
  /// `category:<nonempty>` / `project:<nonempty>`. A malformed scope (missing
  /// prefix, empty id) would silently never match any wake's touched scopes,
  /// hiding the knowledge forever — reject it loudly instead.
  static String _validScope(String? raw) {
    if (raw == null || raw == knowledgeGlobalScope) return knowledgeGlobalScope;
    for (final prefix in const [
      knowledgeCategoryScopePrefix,
      knowledgeProjectScopePrefix,
    ]) {
      if (raw.startsWith(prefix)) {
        // Trim the id portion and require it to be non-empty: a whitespace-only
        // id (e.g. "category: ") has length > prefix yet would never match a
        // wake's trimmed touched scopes, silently hiding the knowledge forever.
        // Returning the normalized `$prefix$id` also drops stray surrounding
        // whitespace so it matches the trimmed scope keys.
        final id = raw.substring(prefix.length).trim();
        if (id.isNotEmpty) return '$prefix$id';
      }
    }
    throw const DayAgentKnowledgeException(
      '"scope" must be "global", "category:<id>", or "project:<id>".',
    );
  }

  /// Normalizes author-time [tags]: trim, drop empties, cap each tag's length,
  /// de-duplicate case-insensitively (keeping first-seen casing/order), and
  /// bound the count — so a runaway tag list can never bloat the panel or a
  /// future prompt rendering.
  static List<String> _normalizeTags(List<String> tags) {
    const maxTags = 8;
    const maxTagLength = 40;
    final seen = <String>{};
    final result = <String>[];
    for (final raw in tags) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) continue;
      final capped = trimmed.length > maxTagLength
          ? trimmed.substring(0, maxTagLength)
          : trimmed;
      if (seen.add(capped.toLowerCase())) {
        result.add(capped);
        if (result.length >= maxTags) break;
      }
    }
    return result;
  }

  /// Rejects a `hook` longer than [_maxHookLength]. The hook is the always-on
  /// index line injected into every system prompt (ADR 0022 Decision 10), so a
  /// multi-KB hook would defeat the bounded-prompt premise.
  static void _validHook(String hook) {
    if (hook.length > _maxHookLength) {
      throw const DayAgentKnowledgeException(
        '"hook" must be at most $_maxHookLength characters '
        '(it is the always-on index line).',
      );
    }
  }
}
