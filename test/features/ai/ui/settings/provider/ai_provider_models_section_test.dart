import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/provider/ai_provider_detail_widgets.dart';
import 'package:lotti/features/ai/ui/settings/provider/ai_provider_models_section.dart';
import 'package:lotti/features/ai/ui/settings/widgets/v2/ai_settings_cards.dart';

import '../../../../../widget_test_utils.dart';
import '../widgets/v2/ai_settings_cards_test_helpers.dart';

void main() {
  group('ModelsSection', () {
    testWidgets(
      'every model row carries a delete action, and tapping one forwards '
      "exactly that row's model to onDeleteModel",
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final provider = hProvider(type: InferenceProviderType.anthropic);
        final first = hModel(
          providerId: provider.id,
          id: 'm-first',
          name: 'First Model',
          providerModelId: 'first-model',
        );
        final second = hModel(
          providerId: provider.id,
          id: 'm-second',
          name: 'Second Model',
          providerModelId: 'second-model',
        );
        final deleted = <AiConfigModel>[];
        final tapped = <AiConfigModel>[];

        await tester.pumpWidget(
          makeTestableWidget(
            ModelsSection(
              provider: provider,
              models: [first, second],
              onAddModel: () {},
              onModelTap: tapped.add,
              onDeleteModel: deleted.add,
            ),
          ),
        );
        await tester.pump();

        final trashIcons = find.byTooltip('Delete model');
        expect(
          trashIcons,
          findsNWidgets(2),
          reason: 'One visible delete affordance per model row.',
        );

        // The trash inside the second card must forward the second model —
        // not the first, and not a stale closure.
        await tester.tap(
          find.descendant(
            of: find.ancestor(
              of: find.text('Second Model'),
              matching: find.byType(AiModelCard),
            ),
            matching: trashIcons,
          ),
        );
        await tester.pump();

        expect(deleted, [second]);
        expect(
          tapped,
          isEmpty,
          reason: 'Deleting must not also open the model edit page.',
        );
      },
    );

    testWidgets(
      'an empty section renders the empty-state card and no delete '
      'affordances',
      (tester) async {
        var deleteCalls = 0;

        await tester.pumpWidget(
          makeTestableWidget(
            ModelsSection(
              provider: hProvider(type: InferenceProviderType.anthropic),
              models: const [],
              onAddModel: () {},
              onModelTap: (_) {},
              onDeleteModel: (_) => deleteCalls++,
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(EmptySectionCard), findsOneWidget);
        expect(find.byTooltip('Delete model'), findsNothing);
        expect(deleteCalls, 0);
      },
    );

    testWidgets(
      'row taps still forward to onModelTap — the delete affordance does '
      'not swallow the card tap target',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final provider = hProvider(type: InferenceProviderType.anthropic);
        final model = hModel(
          providerId: provider.id,
          id: 'm-tap',
          name: 'Tappable Model',
          providerModelId: 'tappable-model',
        );
        final tapped = <AiConfigModel>[];
        final deleted = <AiConfigModel>[];

        await tester.pumpWidget(
          makeTestableWidget(
            ModelsSection(
              provider: provider,
              models: [model],
              onAddModel: () {},
              onModelTap: tapped.add,
              onDeleteModel: deleted.add,
            ),
          ),
        );
        await tester.pump();

        await tester.tap(find.text('Tappable Model'));
        await tester.pump();

        expect(tapped, [model]);
        expect(deleted, isEmpty);
      },
    );
  });
}
