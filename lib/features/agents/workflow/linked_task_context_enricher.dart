import 'dart:convert';
import 'dart:developer' as developer;

import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/ai/repository/ai_input_repository.dart'
    show AiInputRepository;

/// Rewrites linked-task JSON context for task-agent prompt assembly.
///
/// Input is the JSON produced by [AiInputRepository.buildLinkedTasksJson].
/// Output removes legacy `latestSummary` fields and injects linked task-agent
/// report snapshots when available.
class LinkedTaskContextEnricher {
  const LinkedTaskContextEnricher({
    required this.agentRepository,
  });

  final AgentRepository agentRepository;

  /// Enriches [rawJson] with linked task-agent report context.
  Future<String> enrich(String rawJson) async {
    if (rawJson.isEmpty || rawJson == '{}') {
      return rawJson;
    }

    Map<String, dynamic> decoded;
    try {
      final parsed = jsonDecode(rawJson);
      if (parsed is! Map<String, dynamic>) {
        return rawJson;
      }
      decoded = parsed;
    } catch (e) {
      developer.log(
        'Failed to decode linked task context JSON: $e',
        name: 'LinkedTaskContextEnricher',
      );
      return rawJson;
    }

    final taskRows = _extractLinkedTaskRows(decoded);
    if (taskRows.isEmpty) {
      return rawJson;
    }

    final taskIds = taskRows
        .map((row) => row['id'])
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();

    final reportByTaskId = <String, _LinkedTaskAgentReport?>{};
    await Future.wait(
      taskIds.map((id) async {
        reportByTaskId[id] = await _resolveLatestTaskAgentReport(id);
      }),
    );

    for (final row in taskRows) {
      row.remove('latestSummary');

      final linkedTaskId = row['id'];
      if (linkedTaskId is! String || linkedTaskId.isEmpty) {
        continue;
      }

      final linkedReport = reportByTaskId[linkedTaskId];
      if (linkedReport == null) {
        continue;
      }

      row['taskAgentId'] = linkedReport.agentId;
      row['latestTaskAgentReport'] = linkedReport.content;
      row['latestTaskAgentReportCreatedAt'] =
          linkedReport.createdAt.toIso8601String();
    }

    return const JsonEncoder.withIndent('    ').convert(decoded);
  }

  List<Map<String, dynamic>> _extractLinkedTaskRows(Map<String, dynamic> json) {
    const sections = <String>['linked_from', 'linked_to', 'linked'];
    final rows = <Map<String, dynamic>>[];
    for (final section in sections) {
      final value = json[section];
      if (value is List) {
        rows.addAll(value.whereType<Map<String, dynamic>>());
      }
    }
    return rows;
  }

  Future<_LinkedTaskAgentReport?> _resolveLatestTaskAgentReport(
    String linkedTaskId,
  ) async {
    try {
      final links = await agentRepository.getLinksTo(
        linkedTaskId,
        type: AgentLinkTypes.agentTask,
      );
      if (links.isEmpty) {
        return null;
      }

      final sortedLinks = links.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      for (final link in sortedLinks) {
        final report = await agentRepository.getLatestReport(
          link.fromId,
          AgentReportScopes.current,
        );
        if (report == null) {
          continue;
        }
        final content = report.content.trim();
        if (content.isEmpty) {
          continue;
        }
        return _LinkedTaskAgentReport(
          agentId: link.fromId,
          content: content,
          createdAt: report.createdAt,
        );
      }
      return null;
    } catch (e) {
      developer.log(
        'Failed to resolve linked task-agent report for task $linkedTaskId: $e',
        name: 'LinkedTaskContextEnricher',
      );
      return null;
    }
  }
}

class _LinkedTaskAgentReport {
  const _LinkedTaskAgentReport({
    required this.agentId,
    required this.content,
    required this.createdAt,
  });

  final String agentId;
  final String content;
  final DateTime createdAt;
}
