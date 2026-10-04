import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/state/skill_entity_provider.dart';

import '../../../test_data/test_data.dart';

void main() {
  group('skillEntityProvider', () {
    test('has no entity until the composition root wires one', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(skillEntityProvider(testTask.meta.id)), isNull);
    });

    test('serves the entity an override supplies, per entity id', () {
      final container = ProviderContainer(
        overrides: [
          skillEntityProvider.overrideWith(
            (ref, entityId) => entityId == testTask.meta.id ? testTask : null,
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(skillEntityProvider(testTask.meta.id)), testTask);
      expect(container.read(skillEntityProvider('other-id')), isNull);
    });
  });
}
