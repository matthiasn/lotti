import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/speech/sherpa_installed_models_provider.dart';
import 'package:lotti/features/ai/speech/sherpa_model_repository.dart';
import 'package:lotti/features/ai/ui/settings/provider/ai_provider_detail_widgets.dart';
import 'package:lotti/features/ai/ui/settings/widgets/sherpa_models_section.dart';
import 'package:lotti/features/ai/ui/settings/widgets/v2/ai_model_card.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../widget_test_utils.dart';

void main() {
  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);

  testWidgets(
    'sherpa detail shows download controls and tracks local readiness',
    (tester) async {
      final models = MockSherpaModelRepository();
      when(() => models.isInstalled(any())).thenAnswer((_) async => false);
      var installed = <String>{};
      final provider = AiConfigInferenceProvider(
        id: 'embedded',
        name: 'Local speech',
        baseUrl: '',
        apiKey: '',
        inferenceProviderType: InferenceProviderType.sherpa,
        createdAt: DateTime.utc(2026),
      );
      final model = AiConfigModel(
        id: 'tiny-model',
        name: 'Whisper Tiny',
        providerModelId: 'tiny',
        inferenceProviderId: provider.id,
        createdAt: DateTime.utc(2026),
        inputModalities: const [Modality.audio],
        outputModalities: const [Modality.text],
        isReasoningModel: false,
      );
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Material(
            child: DetailBody(
              provider: provider,
              models: [model],
              allModels: [model],
              profilesUsingProvider: const [],
              onAddModel: () {},
              onEdit: () {},
              onModelTap: (_) {},
              onDeleteModel: (_) {},
              onProfileTap: (_) {},
              onRemove: () {},
            ),
          ),
          overrides: [
            sherpaModelRepositoryProvider.overrideWithValue(models),
            sherpaInstalledModelIdsProvider.overrideWith(
              (ref) async => installed,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byType(SherpaModelsSection, skipOffstage: false),
        findsOneWidget,
      );
      expect(find.text('Download a model on this device'), findsNWidgets(2));
      expect(find.text('1 model'), findsNothing);
      expect(find.byType(AiModelCard), findsNothing);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(DetailBody)),
      );
      installed = {'tiny'};
      container.invalidate(sherpaInstalledModelIdsProvider);
      await tester.pumpAndSettle();
      expect(find.text('1 model'), findsOneWidget);
      final card = tester.widget<AiModelCard>(find.byType(AiModelCard));
      expect(card.model.id, model.id);
      expect(card.onDelete, isNull);
      expect(find.text('Download a model on this device'), findsNothing);
      installed = {};
      container.invalidate(sherpaInstalledModelIdsProvider);
      await tester.pumpAndSettle();
      expect(find.text('Download a model on this device'), findsNWidgets(2));
      expect(find.text('1 model'), findsNothing);
    },
  );
}
