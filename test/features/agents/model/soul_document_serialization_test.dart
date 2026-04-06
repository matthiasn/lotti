import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_link.dart';

import '../test_data/soul_factories.dart';

void main() {
  group('SoulDocumentEntity serialization', () {
    test('roundtrips through JSON', () {
      final entity = makeTestSoulDocument();
      final json = entity.toJson();
      final decoded = AgentDomainEntity.fromJson(json);
      expect(decoded, equals(entity));
    });

    test('runtimeType is soulDocument', () {
      final entity = makeTestSoulDocument();
      final json = entity.toJson();
      expect(json['runtimeType'], 'soulDocument');
    });

    test('roundtrips through JSON string encoding', () {
      final entity = makeTestSoulDocument(displayName: 'Laura');
      final jsonStr = jsonEncode(entity.toJson());
      final decoded = AgentDomainEntity.fromJson(
        jsonDecode(jsonStr) as Map<String, dynamic>,
      );
      expect(decoded, isA<SoulDocumentEntity>());
      expect((decoded as SoulDocumentEntity).displayName, 'Laura');
    });
  });

  group('SoulDocumentVersionEntity serialization', () {
    test('roundtrips through JSON', () {
      final entity = makeTestSoulDocumentVersion(
        voiceDirective: 'Be warm.',
        toneBounds: 'No sarcasm.',
        coachingStyle: 'Gentle nudges.',
        antiSycophancyPolicy: 'Push back on bad ideas.',
      );
      final json = entity.toJson();
      final decoded = AgentDomainEntity.fromJson(json);
      expect(decoded, equals(entity));
    });

    test('runtimeType is soulDocumentVersion', () {
      final entity = makeTestSoulDocumentVersion();
      final json = entity.toJson();
      expect(json['runtimeType'], 'soulDocumentVersion');
    });

    test('preserves all personality fields', () {
      final entity = makeTestSoulDocumentVersion(
        voiceDirective: 'voice',
        toneBounds: 'bounds',
        coachingStyle: 'style',
        antiSycophancyPolicy: 'policy',
        sourceSessionId: 'session-1',
        diffFromVersionId: 'version-0',
      );
      final json = entity.toJson();
      final decoded =
          AgentDomainEntity.fromJson(json) as SoulDocumentVersionEntity;
      expect(decoded.voiceDirective, 'voice');
      expect(decoded.toneBounds, 'bounds');
      expect(decoded.coachingStyle, 'style');
      expect(decoded.antiSycophancyPolicy, 'policy');
      expect(decoded.sourceSessionId, 'session-1');
      expect(decoded.diffFromVersionId, 'version-0');
    });

    test('defaults empty strings for optional personality fields', () {
      final entity = makeTestSoulDocumentVersion();
      expect(entity.toneBounds, '');
      expect(entity.coachingStyle, '');
      expect(entity.antiSycophancyPolicy, '');
    });
  });

  group('SoulDocumentHeadEntity serialization', () {
    test('roundtrips through JSON', () {
      final entity = makeTestSoulDocumentHead();
      final json = entity.toJson();
      final decoded = AgentDomainEntity.fromJson(json);
      expect(decoded, equals(entity));
    });

    test('runtimeType is soulDocumentHead', () {
      final entity = makeTestSoulDocumentHead();
      final json = entity.toJson();
      expect(json['runtimeType'], 'soulDocumentHead');
    });
  });

  group('SoulAssignmentLink serialization', () {
    test('roundtrips through JSON', () {
      final link = makeTestSoulAssignmentLink();
      final json = link.toJson();
      final decoded = AgentLink.fromJson(json);
      expect(decoded, equals(link));
    });

    test('runtimeType is soulAssignment', () {
      final link = makeTestSoulAssignmentLink();
      final json = link.toJson();
      expect(json['runtimeType'], 'soulAssignment');
    });
  });

  group('unknown fallback', () {
    test('unknown runtimeType deserializes to AgentUnknownEntity', () {
      final json = <String, dynamic>{
        'runtimeType': 'futureEntityType',
        'id': 'x',
        'agentId': 'y',
        'createdAt': DateTime(2024, 3, 15).toIso8601String(),
      };
      final decoded = AgentDomainEntity.fromJson(json);
      expect(decoded, isA<AgentUnknownEntity>());
    });
  });
}
