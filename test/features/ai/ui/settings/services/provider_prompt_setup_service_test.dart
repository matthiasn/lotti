import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/ui/settings/services/provider_prompt_setup_service.dart';

void main() {
  // The sealed AiFtueResult base carries the shared tally contract; the
  // GeminiFtueResult subclass stands in for all six concrete results.
  group('AiFtueResult', () {
    test('totalModels sums modelsCreated and modelsVerified', () {
      const result = GeminiFtueResult(
        modelsCreated: 2,
        modelsVerified: 1,
        categoryCreated: true,
      );
      expect(result.totalModels, 3);
    });

    test('defaults: no reuse flag, no category name, no errors', () {
      const result = GeminiFtueResult(
        modelsCreated: 0,
        modelsVerified: 0,
        categoryCreated: false,
      );
      expect(result.totalModels, 0);
      expect(result.categoryReused, isFalse);
      expect(result.categoryName, isNull);
      expect(result.errors, isEmpty);
    });
  });
}
