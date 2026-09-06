import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/speech/sherpa_installed_models_provider.dart';
import 'package:lotti/features/ai/ui/inference_profile_slot_field.dart';
import 'package:lotti/widgets/settings/settings_picker_field.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../test_utils.dart' show AiTestDataFactory;

void main() {
  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);

  testWidgets(
    'waits for provider identity and verified files before allowing selection',
    (tester) async {
      final configs = MockAiConfigRepository();
      final providerLoaded = Completer<List<AiConfig>>();
      final model = AiTestDataFactory.createTestModel(
        id: 'saved-medium',
        name: 'Whisper Medium',
        providerModelId: 'medium',
        inferenceProviderId: 'sherpa',
        inputModalities: [Modality.audio],
      );
      when(
        () => configs.watchConfigsByType(AiConfigType.model),
      ).thenAnswer((_) => Stream.value([model]));
      when(
        () => configs.watchConfigsByType(AiConfigType.inferenceProvider),
      ).thenAnswer((_) => Stream.fromFuture(providerLoaded.future));
      var installed = <String>{};
      final selections = <String?>[];
      await tester.pumpWidget(
        makeTestableWidget(
          Material(
            child: ModelSlotField(
              label: 'Transcription',
              modelId: model.id,
              onModelSelected: selections.add,
              filter: (model) => model.inputModalities.contains(Modality.audio),
            ),
          ),
          overrides: [
            aiConfigRepositoryProvider.overrideWithValue(configs),
            sherpaInstalledModelIdsProvider.overrideWith(
              (ref) async => installed,
            ),
          ],
        ),
      );
      await tester.pump();
      SettingsPickerField field() =>
          tester.widget<SettingsPickerField>(find.byType(SettingsPickerField));
      expect(field().valueText, isNot(model.name));
      field().onTap();
      await tester.pump();
      expect(selections, isEmpty);
      providerLoaded.complete([
        AiTestDataFactory.createTestProvider(
          id: 'sherpa',
          type: InferenceProviderType.sherpa,
        ),
      ]);
      await tester.pump();
      await tester.pump();
      expect(field().valueText, isNot(model.name));
      field().onTap();
      await tester.pump();
      expect(selections, isEmpty);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ModelSlotField)),
      );
      installed = {'medium'};
      container.invalidate(sherpaInstalledModelIdsProvider);
      await tester.pump();
      await tester.pump();
      expect(field().valueText, model.name);
      field().onTap();
      await tester.pump();
      expect(selections, [model.id]);
      installed = {};
      container.invalidate(sherpaInstalledModelIdsProvider);
      await tester.pump();
      await tester.pump();
      expect(field().valueText, isNot(model.name));
      expect(
        tester.widget<ModelSlotField>(find.byType(ModelSlotField)).modelId,
        model.id,
      );
    },
  );
}
