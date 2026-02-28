import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';

import '../../agents/test_utils.dart';

void main() {
  group('ResolvedProfile', () {
    final provider1 = testInferenceProvider(id: 'p1');
    final provider2 = testInferenceProvider(id: 'p2');

    test('equal instances are equal', () {
      final a = ResolvedProfile(
        thinkingModelId: 'model-a',
        thinkingProvider: provider1,
      );
      final b = ResolvedProfile(
        thinkingModelId: 'model-a',
        thinkingProvider: provider1,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('different thinkingModelId are not equal', () {
      final a = ResolvedProfile(
        thinkingModelId: 'model-a',
        thinkingProvider: provider1,
      );
      final b = ResolvedProfile(
        thinkingModelId: 'model-b',
        thinkingProvider: provider1,
      );

      expect(a, isNot(equals(b)));
    });

    test('different thinkingProvider are not equal', () {
      final a = ResolvedProfile(
        thinkingModelId: 'model-a',
        thinkingProvider: provider1,
      );
      final b = ResolvedProfile(
        thinkingModelId: 'model-a',
        thinkingProvider: provider2,
      );

      expect(a, isNot(equals(b)));
    });

    test('profiles with all slots populated are equal', () {
      final a = ResolvedProfile(
        thinkingModelId: 'thinking',
        thinkingProvider: provider1,
        imageRecognitionModelId: 'vision',
        imageRecognitionProvider: provider2,
        transcriptionModelId: 'audio',
        transcriptionProvider: provider1,
        imageGenerationModelId: 'image',
        imageGenerationProvider: provider2,
      );
      final b = ResolvedProfile(
        thinkingModelId: 'thinking',
        thinkingProvider: provider1,
        imageRecognitionModelId: 'vision',
        imageRecognitionProvider: provider2,
        transcriptionModelId: 'audio',
        transcriptionProvider: provider1,
        imageGenerationModelId: 'image',
        imageGenerationProvider: provider2,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('optional slot difference makes profiles unequal', () {
      final a = ResolvedProfile(
        thinkingModelId: 'thinking',
        thinkingProvider: provider1,
        imageRecognitionModelId: 'vision',
      );
      final b = ResolvedProfile(
        thinkingModelId: 'thinking',
        thinkingProvider: provider1,
      );

      expect(a, isNot(equals(b)));
    });

    test('is not equal to a non-ResolvedProfile object', () {
      final profile = ResolvedProfile(
        thinkingModelId: 'model-a',
        thinkingProvider: provider1,
      );

      // ignore: unrelated_type_equality_checks
      expect(profile == 'not a profile', isFalse);
    });
  });
}
