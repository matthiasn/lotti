import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_db_conversions.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart' as model;

void main() {
  const id = 'report-id-1';
  const agentId = 'agent-id-1';
  final createdAt = DateTime(2026, 2, 21);
  final updatedAt = DateTime(2026, 2, 21);

  AgentEntity makeRow(Map<String, dynamic> serializedJson) {
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

  Map<String, dynamic> baseReportJson({required Object content}) {
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
      final row = makeRow(
        baseReportJson(content: {'markdown': '# Report'}),
      );

      final entity = AgentDbConversions.fromEntityRow(row);

      expect(entity, isA<AgentReportEntity>());
      final report = entity as AgentReportEntity;
      expect(report.content, '# Report');
    });

    test('new-format String content passes through unchanged', () {
      const markdownString = '# Already a String';
      final row = makeRow(
        baseReportJson(content: markdownString),
      );

      final entity = AgentDbConversions.fromEntityRow(row);

      expect(entity, isA<AgentReportEntity>());
      final report = entity as AgentReportEntity;
      expect(report.content, markdownString);
    });

    test(
        'old-format Map content with no "markdown" key falls back to first value',
        () {
      final row = makeRow(
        baseReportJson(content: {'html': '<h1>Report</h1>'}),
      );

      final entity = AgentDbConversions.fromEntityRow(row);

      expect(entity, isA<AgentReportEntity>());
      final report = entity as AgentReportEntity;
      expect(report.content, '<h1>Report</h1>');
    });

    test('old-format Map content with empty map returns empty string', () {
      final row = makeRow(
        baseReportJson(content: <String, dynamic>{}),
      );

      final entity = AgentDbConversions.fromEntityRow(row);

      expect(entity, isA<AgentReportEntity>());
      final report = entity as AgentReportEntity;
      expect(report.content, '');
    });
  });

  group('AgentDbConversions — unknown entity variant', () {
    test('toEntityCompanion handles unknown variant correctly', () {
      final entity = AgentDomainEntity.unknown(
        id: 'unknown-001',
        agentId: agentId,
        createdAt: createdAt,
      );

      final companion = AgentDbConversions.toEntityCompanion(entity);

      expect(companion.id, const Value('unknown-001'));
      expect(companion.agentId, const Value(agentId));
      expect(companion.type, const Value('unknown'));
      expect(companion.createdAt, Value(createdAt));
      expect(companion.updatedAt, Value(createdAt));
      expect(companion.deletedAt, const Value<DateTime?>(null));
    });

    test('fromEntityRow roundtrips unknown variant', () {
      final entity = AgentDomainEntity.unknown(
        id: 'unknown-002',
        agentId: agentId,
        createdAt: createdAt,
      );
      final companion = AgentDbConversions.toEntityCompanion(entity);

      final row = AgentEntity(
        id: companion.id.value,
        agentId: agentId,
        type: 'unknown',
        createdAt: createdAt,
        updatedAt: createdAt,
        serialized: companion.serialized.value,
        schemaVersion: 1,
      );

      final result = AgentDbConversions.fromEntityRow(row);
      expect(result, isA<AgentUnknownEntity>());
      expect(result.id, 'unknown-002');
      expect(result.agentId, agentId);
    });
  });

  group('AgentDbConversions — messagePayload link variant', () {
    test('toLinkCompanion handles messagePayload link correctly', () {
      final link = model.AgentLink.messagePayload(
        id: 'link-mp-001',
        fromId: 'msg-001',
        toId: 'payload-001',
        createdAt: createdAt,
        updatedAt: updatedAt,
        vectorClock: null,
      );

      final companion = AgentDbConversions.toLinkCompanion(link);

      expect(companion.id, const Value('link-mp-001'));
      expect(companion.fromId, const Value('msg-001'));
      expect(companion.toId, const Value('payload-001'));
      expect(companion.type, const Value('message_payload'));
    });
  });

  group('AgentDbConversions.toEntityCompanion — subtype population', () {
    test('populates subtype with kind for agent entities', () {
      final entity = AgentDomainEntity.agent(
        id: 'agent-1',
        agentId: agentId,
        kind: 'task_agent',
        displayName: 'Test',
        lifecycle: AgentLifecycle.active,
        mode: AgentInteractionMode.autonomous,
        allowedCategoryIds: const {},
        currentStateId: 'state-1',
        config: const AgentConfig(),
        createdAt: createdAt,
        updatedAt: updatedAt,
        vectorClock: null,
      );

      final companion = AgentDbConversions.toEntityCompanion(entity);

      expect(companion.subtype, const Value('task_agent'));
    });

    test('populates subtype with kind name for agentMessage entities', () {
      final entity = AgentDomainEntity.agentMessage(
        id: 'msg-1',
        agentId: agentId,
        threadId: 'thread-1',
        kind: AgentMessageKind.observation,
        createdAt: createdAt,
        metadata: const AgentMessageMetadata(runKey: 'rk-1'),
        vectorClock: null,
      );

      final companion = AgentDbConversions.toEntityCompanion(entity);

      expect(companion.subtype, const Value('observation'));
    });

    test('populates subtype with scope for agentReport entities', () {
      final entity = AgentDomainEntity.agentReport(
        id: 'report-1',
        agentId: agentId,
        scope: 'weekly',
        createdAt: createdAt,
        vectorClock: null,
      );

      final companion = AgentDbConversions.toEntityCompanion(entity);

      expect(companion.subtype, const Value('weekly'));
    });

    test('populates subtype with scope for agentReportHead entities', () {
      final entity = AgentDomainEntity.agentReportHead(
        id: 'head-1',
        agentId: agentId,
        scope: 'daily',
        reportId: 'report-1',
        updatedAt: updatedAt,
        vectorClock: null,
      );

      final companion = AgentDbConversions.toEntityCompanion(entity);

      expect(companion.subtype, const Value('daily'));
    });

    test('leaves subtype absent for agentState entities', () {
      final entity = AgentDomainEntity.agentState(
        id: 'state-1',
        agentId: agentId,
        revision: 1,
        slots: const AgentSlots(),
        updatedAt: updatedAt,
        vectorClock: null,
      );

      final companion = AgentDbConversions.toEntityCompanion(entity);

      expect(companion.subtype, const Value<String?>.absent());
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
