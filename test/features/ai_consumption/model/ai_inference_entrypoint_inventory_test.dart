import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_consumption/model/ai_attribution.dart';
import 'package:lotti/features/ai_consumption/model/ai_inference_entrypoint_inventory.dart';

void main() {
  test('inventory uniquely classifies every supported AI work type', () {
    final ids = aiInferenceEntrypoints.map((entry) => entry.id).toList();
    expect(ids.toSet(), hasLength(ids.length));

    final coveredTypes = aiInferenceEntrypoints
        .expand((entry) => entry.workTypes)
        .toSet();
    expect(coveredTypes, containsAll(AiWorkType.values));
  });

  test('strict publication sagas identify their terminal carrier', () {
    final strictEntries = aiInferenceEntrypoints.where(
      (entry) => entry.coverage == AiAttributionCoverage.strictPublicationSaga,
    );

    expect(strictEntries, isNotEmpty);
    expect(
      strictEntries.every(
        (entry) => entry.outputCarrier?.trim().isNotEmpty ?? false,
      ),
      isTrue,
    );
  });

  test('migrated funnels retain their implementation-level guarantees', () {
    final entries = {
      for (final entry in aiInferenceEntrypoints) entry.id: entry,
    };

    expect(
      entries['unified-inference']?.coverage,
      AiAttributionCoverage.strictPublicationSaga,
    );
    expect(
      entries['conversation-repository']?.coverage,
      AiAttributionCoverage.durablePartialCapture,
    );
    expect(
      entries['embedding-indexing']?.coverage,
      AiAttributionCoverage.strictPublicationSaga,
    );
    expect(entries['embedding-indexing']?.outputCarrier, contains('Embedding'));
    expect(entries, isNot(contains('legacy-unified-inference')));
  });
}
