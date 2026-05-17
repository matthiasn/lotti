import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';

void main() {
  group('AiConfigInferenceProfile.pinnedHostId', () {
    final createdAt = DateTime.utc(2026, 3, 15, 12);

    test('round-trips when set', () {
      final profile =
          AiConfig.inferenceProfile(
                id: 'profile-1',
                name: 'Local Mac',
                createdAt: createdAt,
                thinkingModelId: 'qwen3:latest',
                pinnedHostId: 'host-uuid-abc',
              )
              as AiConfigInferenceProfile;

      final decoded =
          AiConfig.fromJson(
                jsonDecode(jsonEncode(profile.toJson()))
                    as Map<String, dynamic>,
              )
              as AiConfigInferenceProfile;

      expect(decoded.pinnedHostId, 'host-uuid-abc');
    });

    test('defaults to null when omitted', () {
      final profile =
          AiConfig.inferenceProfile(
                id: 'profile-2',
                name: 'Default',
                createdAt: createdAt,
                thinkingModelId: 'qwen3:latest',
              )
              as AiConfigInferenceProfile;

      expect(profile.pinnedHostId, isNull);

      final decoded =
          AiConfig.fromJson(
                jsonDecode(jsonEncode(profile.toJson()))
                    as Map<String, dynamic>,
              )
              as AiConfigInferenceProfile;

      expect(decoded.pinnedHostId, isNull);
    });

    test('deserializes legacy JSON (without the field) as null', () {
      // Simulates a profile written by an older client that doesn't know
      // about pinnedHostId. The new field must default to null, not crash.
      final json = <String, dynamic>{
        'runtimeType': 'inferenceProfile',
        'id': 'profile-3',
        'name': 'Legacy',
        'createdAt': createdAt.toIso8601String(),
        'thinkingModelId': 'qwen3:latest',
        'isDefault': false,
        'desktopOnly': false,
        'skillAssignments': <Map<String, dynamic>>[],
      };

      final decoded = AiConfig.fromJson(json) as AiConfigInferenceProfile;

      expect(decoded.pinnedHostId, isNull);
      expect(decoded.id, 'profile-3');
      expect(decoded.thinkingModelId, 'qwen3:latest');
    });

    test('clearing the pin via copyWith persists as null', () {
      final pinned =
          AiConfig.inferenceProfile(
                id: 'profile-4',
                name: 'Pinned',
                createdAt: createdAt,
                thinkingModelId: 'qwen3:latest',
                pinnedHostId: 'host-uuid-xyz',
              )
              as AiConfigInferenceProfile;

      final cleared = pinned.copyWith(pinnedHostId: null);
      final decoded =
          AiConfig.fromJson(
                jsonDecode(jsonEncode(cleared.toJson()))
                    as Map<String, dynamic>,
              )
              as AiConfigInferenceProfile;

      expect(decoded.pinnedHostId, isNull);
    });
  });
}
