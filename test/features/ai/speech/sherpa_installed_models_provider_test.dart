import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/speech/sherpa_installed_models_provider.dart';
import 'package:lotti/features/ai/speech/sherpa_model_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  test(
    'readiness follows verified device files and refreshes after removal',
    () async {
      final models = MockSherpaModelRepository();
      when(() => models.models).thenReturn(sherpaModels);
      var installed = {'tiny'};
      when(() => models.isAvailable(any())).thenAnswer(
        (call) async => installed.contains(call.positionalArguments.single),
      );
      final container = ProviderContainer(
        overrides: [
          sherpaModelRepositoryProvider.overrideWithValue(models),
        ],
      );
      addTearDown(container.dispose);
      expect(await container.read(sherpaInstalledModelIdsProvider.future), {
        'tiny',
      });
      installed = {};
      container.invalidate(sherpaInstalledModelIdsProvider);
      expect(
        await container.read(sherpaInstalledModelIdsProvider.future),
        isEmpty,
      );
      verify(() => models.isAvailable('tiny')).called(2);
      verify(() => models.isAvailable('base')).called(2);
    },
  );
}
