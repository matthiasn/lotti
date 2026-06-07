import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
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

    // The two example fixtures above pin specific tallies; this property
    // closes the rest of the (created, verified) grid: totalModels is
    // exactly the sum for any non-negative model counts the setup helpers
    // can report.
    glados.Glados2(
      glados.IntAnys(glados.any).intInRange(0, 1 << 12),
      glados.IntAnys(glados.any).intInRange(0, 1 << 12),
      glados.ExploreConfig(numRuns: 120),
    ).test('totalModels == modelsCreated + modelsVerified', (created, verified) {
      final result = GeminiFtueResult(
        modelsCreated: created,
        modelsVerified: verified,
        categoryCreated: false,
      );
      expect(
        result.totalModels,
        created + verified,
        reason: 'created=$created verified=$verified',
      );
    }, tags: 'glados');
  });
}
