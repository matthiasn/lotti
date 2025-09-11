import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/util/provider_type_utils.dart';

void main() {
  group('normalizeProviderType', () {
    test('returns the same for all valid enum names', () {
      for (final t in InferenceProviderType.values) {
        expect(normalizeProviderType(t.name), t.name,
            reason: 'Should keep valid provider type name: ${t.name}');
      }
    });

    test("maps 'unknown' to genericOpenAi", () {
      expect(normalizeProviderType('unknown'),
          InferenceProviderType.genericOpenAi.name);
    });

    test('defaults invalid strings to genericOpenAi', () {
      expect(
          normalizeProviderType(''), InferenceProviderType.genericOpenAi.name);
      expect(normalizeProviderType('not-a-real-type'),
          InferenceProviderType.genericOpenAi.name);
      // Case-sensitive check: enum names are lowerCamelCase; uppercase should not match
      expect(normalizeProviderType('OPENAI'),
          InferenceProviderType.genericOpenAi.name);
    });
  });
}
