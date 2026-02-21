import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_db_conversions.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';

void main() {
  const id = 'report-id-1';
  const agentId = 'agent-id-1';
  final createdAt = DateTime(2026, 2, 21);
  final updatedAt = DateTime(2026, 2, 21);

  AgentEntity _makeRow(Map<String, dynamic> serializedJson) {
    return AgentEntity(
      id: id,
      agentId: agentId,
      type: 'agentReport',
      createdAt: createdAt,
      updatedAt: updatedAt,
      serialized: jsonEncode(serializedJson),
      schemaVersion: 1,
    );
  }

  Map<String, dynamic> _baseReportJson({required Object content}) {
    return {
      'runtimeType': 'agentReport',
      'id': id,
      'agentId': agentId,
      'scope': 'test-scope',
      'createdAt': createdAt.toIso8601String(),
      'vectorClock': null,
      'content': content,
    };
  }

  group('AgentDbConversions.fromEntityRow — _migrateReportContent', () {
    test(
        'old-format Map content with "markdown" key is migrated to String value',
        () {
      final row = _makeRow(
        _baseReportJson(content: {'markdown': '# Report'}),
      );

      final entity = AgentDbConversions.fromEntityRow(row);

      expect(entity, isA<AgentReportEntity>());
      final report = entity as AgentReportEntity;
      expect(report.content, '# Report');
    });

    test('new-format String content passes through unchanged', () {
      const markdownString = '# Already a String';
      final row = _makeRow(
        _baseReportJson(content: markdownString),
      );

      final entity = AgentDbConversions.fromEntityRow(row);

      expect(entity, isA<AgentReportEntity>());
      final report = entity as AgentReportEntity;
      expect(report.content, markdownString);
    });

    test(
        'old-format Map content with no "markdown" key falls back to first value',
        () {
      final row = _makeRow(
        _baseReportJson(content: {'html': '<h1>Report</h1>'}),
      );

      final entity = AgentDbConversions.fromEntityRow(row);

      expect(entity, isA<AgentReportEntity>());
      final report = entity as AgentReportEntity;
      expect(report.content, '<h1>Report</h1>');
    });

    test('old-format Map content with empty map returns empty string', () {
      final row = _makeRow(
        _baseReportJson(content: <String, dynamic>{}),
      );

      final entity = AgentDbConversions.fromEntityRow(row);

      expect(entity, isA<AgentReportEntity>());
      final report = entity as AgentReportEntity;
      expect(report.content, '');
    });
  });

  group('AgentDbConversions.toEntityCompanion — thread_id population', () {
    test('populates threadId for agentMessage entities', () {
      final message = AgentDomainEntity.agentMessage(
        id: 'msg-1',
        agentId: agentId,
        threadId: 'thread-abc',
        kind: AgentMessageKind.thought,
        createdAt: createdAt,
        metadata: const AgentMessageMetadata(runKey: 'rk-1'),
        vectorClock: null,
      );

      final companion = AgentDbConversions.toEntityCompanion(message);

      expect(companion.threadId, const Value('thread-abc'));
    });

    test('leaves threadId absent for non-message entities', () {
      final report = AgentDomainEntity.agentReport(
        id: id,
        agentId: agentId,
        scope: 'test-scope',
        content: '# Report',
        createdAt: createdAt,
        vectorClock: null,
      );

      final companion = AgentDbConversions.toEntityCompanion(report);

      expect(companion.threadId, const Value<String?>.absent());
    });
  });
}
