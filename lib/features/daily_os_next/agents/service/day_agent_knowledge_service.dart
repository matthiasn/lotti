import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/features/agents/knowledge/agent_knowledge.dart';
import 'package:lotti/features/agents/knowledge/agent_knowledge_service.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_capture_service.dart'
    show DayAgentDirectToolResult;
import 'package:lotti/features/daily_os_next/agents/tools/day_agent_tool_names.dart';
import 'package:lotti/services/domain_logging.dart';

/// The day planner's durable knowledge: the shared [AgentKnowledgeService]
/// plus the planner's `propose_knowledge` tool, whose every entry lands
/// `proposed` for the "What I've learned" panel to confirm — capture
/// transcripts reach the planner's prompt, so its model never confirms.
class DayAgentKnowledgeService extends AgentKnowledgeService {
  DayAgentKnowledgeService({
    required super.agentRepository,
    required super.syncService,
    required super.domainLogger,
    super.onPersistedStateChanged,
  });

  /// Executes a durable-knowledge tool emitted by the agent.
  Future<DayAgentDirectToolResult> executeTool({
    required String agentId,
    required String toolName,
    required Map<String, dynamic> args,
  }) async {
    try {
      final data = switch (toolName) {
        DayAgentToolNames.proposeKnowledge => await _proposeTool(agentId, args),
        _ => throw AgentKnowledgeException('unknown tool "$toolName"'),
      };
      return DayAgentDirectToolResult.success(data);
    } on AgentKnowledgeException catch (e) {
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
      _ => throw const AgentKnowledgeException(
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

  static String _requireString(Map<String, dynamic> args, String name) {
    final raw = args[name];
    if (raw is! String || raw.trim().isEmpty) {
      throw AgentKnowledgeException('"$name" must be a non-empty string.');
    }
    return raw.trim();
  }

  static String? _optionalString(Map<String, dynamic> args, String name) {
    final raw = args[name];
    if (raw is! String || raw.trim().isEmpty) return null;
    return raw.trim();
  }
}
