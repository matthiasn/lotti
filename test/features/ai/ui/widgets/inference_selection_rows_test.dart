import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/util/ai_provider_visual.dart';
import 'package:lotti/features/ai/ui/widgets/inference_selection_rows.dart';
import 'package:lotti/features/design_system/components/selection/design_system_selection_row.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../../widget_test_utils.dart';

void main() {
  final provider = AiConfigInferenceProvider(
    id: 'provider-1',
    name: 'Configured OpenAI',
    baseUrl: 'https://example.invalid',
    apiKey: 'test-key',
    inferenceProviderType: InferenceProviderType.openAi,
    createdAt: DateTime(2024, 3, 15),
  );
  final defaultModel = _model(
    id: 'default-model',
    name: 'Default model',
    providerModelId: 'openai/default',
  );
  final overrideModel = _model(
    id: 'override-model',
    name: 'Override model',
    providerModelId: 'openai/override',
  );

  testWidgets('provider row keeps branded navigation anatomy and activates', (
    tester,
  ) async {
    var taps = 0;
    await _pump(
      tester,
      InferenceProviderSelectionRow(
        key: const ValueKey('provider-row'),
        provider: provider,
        modelCount: 2,
        onTap: () => taps++,
      ),
    );

    final row = tester.widget<DesignSystemSelectionRow>(
      find.descendant(
        of: find.byKey(const ValueKey('provider-row')),
        matching: find.byType(DesignSystemSelectionRow),
      ),
    );
    expect(row.title, 'OpenAI');
    expect(row.subtitle, '2 models');
    expect(row.type, DesignSystemSelectionRowType.navigation);
    final providerIcon = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(const ValueKey('provider-row')),
        matching: find.byIcon(aiProviderIcon(InferenceProviderType.openAi)),
      ),
    );
    expect(
      providerIcon.color,
      aiProviderAccent(
        type: InferenceProviderType.openAi,
        tokens: dsTokensLight,
      ),
    );
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('provider-row')));
    expect(taps, 1);
  });

  testWidgets('model rows distinguish default and selected override states', (
    tester,
  ) async {
    final selected = <String>[];
    await _pump(
      tester,
      Column(
        children: [
          InferenceModelSelectionRow(
            key: const ValueKey('default-row'),
            model: defaultModel,
            providerType: provider.inferenceProviderType,
            isDefault: true,
            isSelected: false,
            defaultBadgeLabel: 'Default',
            onTap: () => selected.add(defaultModel.id),
          ),
          InferenceModelSelectionRow(
            key: const ValueKey('override-row'),
            model: overrideModel,
            providerType: provider.inferenceProviderType,
            isDefault: false,
            isSelected: true,
            defaultBadgeLabel: 'Default',
            onTap: () => selected.add(overrideModel.id),
          ),
        ],
      ),
    );

    final rows = tester.widgetList<DesignSystemSelectionRow>(
      find.byType(DesignSystemSelectionRow),
    );
    final defaultRow = rows.singleWhere((row) => row.title == 'Default model');
    final overrideRow = rows.singleWhere(
      (row) => row.title == 'Override model',
    );
    expect(defaultRow.selected, isFalse);
    expect(defaultRow.trailing, isNotNull);
    expect(overrideRow.selected, isTrue);
    expect(overrideRow.selectedLabel, 'Selected');
    expect(find.text('Default'), findsOneWidget);
    expect(find.text('Selected'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('default-row')));
    await tester.tap(find.byKey(const ValueKey('override-row')));
    expect(selected, ['default-model', 'override-model']);
  });

  testWidgets('selected profile default uses the supplied default badge', (
    tester,
  ) async {
    await _pump(
      tester,
      InferenceModelSelectionRow(
        model: _model(
          id: 'empty-wire-id',
          name: 'Profile default',
          providerModelId: '',
        ),
        providerType: null,
        isDefault: true,
        isSelected: true,
        defaultBadgeLabel: 'Profile default',
        onTap: null,
      ),
    );

    final row = tester.widget<DesignSystemSelectionRow>(
      find.byType(DesignSystemSelectionRow),
    );
    expect(row.subtitle, isNull);
    expect(row.selectedLabel, 'Profile default');
    expect(find.text('Profile default'), findsNWidgets(2));
  });
}

AiConfigModel _model({
  required String id,
  required String name,
  required String providerModelId,
}) {
  return AiConfigModel(
    id: id,
    name: name,
    providerModelId: providerModelId,
    inferenceProviderId: 'provider-1',
    createdAt: DateTime(2024, 3, 15),
    inputModalities: const [Modality.text],
    outputModalities: const [Modality.text],
    isReasoningModel: false,
  );
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      SizedBox(width: dsTokensLight.spacing.step13 * 2, child: child),
    ),
  );
}
