import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/model/sync_node_profile.dart';

void main() {
  group('SyncNodeProfile JSON round-trip', () {
    final updatedAt = DateTime.utc(2026, 3, 15, 12, 30);

    test('serializes and deserializes a fully-populated profile', () {
      final profile = SyncNodeProfile(
        hostId: 'host-uuid-1',
        displayName: 'Studio Mac',
        platform: 'macos',
        osVersion: '15.2',
        cpuModel: 'Apple M4 Max',
        ramMb: 65536,
        gpuModel: 'Apple M4 Max GPU',
        appVersion: '1.0.0+1',
        capabilities: const [
          NodeCapability.mlxAudio,
          NodeCapability.ollamaLlm,
        ],
        updatedAt: updatedAt,
      );

      final encoded = jsonEncode(profile.toJson());
      final decoded = SyncNodeProfile.fromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      );

      expect(decoded.hostId, 'host-uuid-1');
      expect(decoded.displayName, 'Studio Mac');
      expect(decoded.platform, 'macos');
      expect(decoded.osVersion, '15.2');
      expect(decoded.cpuModel, 'Apple M4 Max');
      expect(decoded.ramMb, 65536);
      expect(decoded.gpuModel, 'Apple M4 Max GPU');
      expect(decoded.appVersion, '1.0.0+1');
      expect(decoded.capabilities, [
        NodeCapability.mlxAudio,
        NodeCapability.ollamaLlm,
      ]);
      expect(decoded.updatedAt, updatedAt);
    });

    test('preserves capability list order across serialization', () {
      final original = SyncNodeProfile(
        hostId: 'host-uuid-2',
        displayName: 'Linux Box',
        platform: 'linux',
        capabilities: const [
          NodeCapability.whisper,
          NodeCapability.ollamaLlm,
          NodeCapability.voxtral,
        ],
        updatedAt: updatedAt,
      );

      final decoded = SyncNodeProfile.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
      );

      expect(decoded.capabilities, [
        NodeCapability.whisper,
        NodeCapability.ollamaLlm,
        NodeCapability.voxtral,
      ]);
    });

    test('defaults optional hardware fields to null when omitted', () {
      final profile = SyncNodeProfile(
        hostId: 'host-uuid-3',
        displayName: 'Bare Mac',
        platform: 'macos',
        capabilities: const [NodeCapability.mlxAudio],
        updatedAt: updatedAt,
      );

      final decoded = SyncNodeProfile.fromJson(
        jsonDecode(jsonEncode(profile.toJson())) as Map<String, dynamic>,
      );

      expect(decoded.osVersion, isNull);
      expect(decoded.cpuModel, isNull);
      expect(decoded.ramMb, isNull);
      expect(decoded.gpuModel, isNull);
      expect(decoded.appVersion, isNull);
    });

    test('ignores unknown JSON fields (forward compatibility)', () {
      final json = {
        'hostId': 'host-uuid-4',
        'displayName': 'Future Mac',
        'platform': 'macos',
        'capabilities': <String>[],
        'updatedAt': updatedAt.toIso8601String(),
        'unknownFutureField': 'should be ignored',
      };

      final decoded = SyncNodeProfile.fromJson(json);

      expect(decoded.hostId, 'host-uuid-4');
      expect(decoded.capabilities, isEmpty);
    });
  });

  group('SyncNodeProfile value equality', () {
    final updatedAt = DateTime.utc(2026, 3, 15, 12, 30);

    test('equal profiles compare equal', () {
      final a = SyncNodeProfile(
        hostId: 'h',
        displayName: 'A',
        platform: 'macos',
        capabilities: const [NodeCapability.mlxAudio],
        updatedAt: updatedAt,
      );
      final b = SyncNodeProfile(
        hostId: 'h',
        displayName: 'A',
        platform: 'macos',
        capabilities: const [NodeCapability.mlxAudio],
        updatedAt: updatedAt,
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('differing displayName compares unequal', () {
      final a = SyncNodeProfile(
        hostId: 'h',
        displayName: 'A',
        platform: 'macos',
        capabilities: const [NodeCapability.mlxAudio],
        updatedAt: updatedAt,
      );
      final b = SyncNodeProfile(
        hostId: 'h',
        displayName: 'B',
        platform: 'macos',
        capabilities: const [NodeCapability.mlxAudio],
        updatedAt: updatedAt,
      );

      expect(a, isNot(b));
    });

    test('differing capability list compares unequal', () {
      final a = SyncNodeProfile(
        hostId: 'h',
        displayName: 'A',
        platform: 'macos',
        capabilities: const [NodeCapability.mlxAudio],
        updatedAt: updatedAt,
      );
      final b = SyncNodeProfile(
        hostId: 'h',
        displayName: 'A',
        platform: 'macos',
        capabilities: const [
          NodeCapability.mlxAudio,
          NodeCapability.ollamaLlm,
        ],
        updatedAt: updatedAt,
      );

      expect(a, isNot(b));
    });
  });
}
