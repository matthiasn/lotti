import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/agent_model_selector.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../widget_test_utils.dart';

// ── Test data ──────────────────────────────────────────────────────────────────

final _testDate = DateTime(2024, 3, 15);

AiConfigInferenceProvider _makeProvider({
  required String id,
  required String name,
  String? description,
}) {
  return AiConfig.inferenceProvider(
    id: id,
    baseUrl: 'https://example.com',
    apiKey: 'key',
    name: name,
    createdAt: _testDate,
    inferenceProviderType: InferenceProviderType.gemini,
    description: description,
  ) as AiConfigInferenceProvider;
}

AiConfigModel _makeModel({
  required String id,
  required String name,
  required String providerModelId,
  required String inferenceProviderId,
  bool isReasoningModel = true,
  bool supportsFunctionCalling = true,
}) {
  return AiConfig.model(
    id: id,
    name: name,
    providerModelId: providerModelId,
    inferenceProviderId: inferenceProviderId,
    createdAt: _testDate,
    inputModalities: [Modality.text],
    outputModalities: [Modality.text],
    isReasoningModel: isReasoningModel,
    supportsFunctionCalling: supportsFunctionCalling,
  ) as AiConfigModel;
}

final AiConfigInferenceProvider _providerA =
    _makeProvider(id: 'prov-a', name: 'Provider Alpha');
final AiConfigInferenceProvider _providerB =
    _makeProvider(id: 'prov-b', name: 'Provider Beta');

final AiConfigModel _suitableModel = _makeModel(
  id: 'model-1',
  name: 'Gemini Pro',
  providerModelId: 'models/gemini-pro',
  inferenceProviderId: 'prov-a',
);

final AiConfigModel _suitableModelB = _makeModel(
  id: 'model-2',
  name: 'Claude Opus',
  providerModelId: 'claude-opus',
  inferenceProviderId: 'prov-b',
);

final AiConfigModel _nonReasoningModel = _makeModel(
  id: 'model-3',
  name: 'Fast Model',
  providerModelId: 'fast-model',
  inferenceProviderId: 'prov-a',
  isReasoningModel: false,
);

final AiConfigModel _noFunctionCallingModel = _makeModel(
  id: 'model-4',
  name: 'Reason Only',
  providerModelId: 'reason-only',
  inferenceProviderId: 'prov-a',
  supportsFunctionCalling: false,
);

// ── Helpers ────────────────────────────────────────────────────────────────────

Widget _buildSubject({
  String? currentModelId,
  ValueChanged<String?>? onModelSelected,
  List<AiConfig> providers = const [],
  List<AiConfig> models = const [],
}) {
  return makeTestableWidgetNoScroll(
    Scaffold(
      body: AgentModelSelector(
        currentModelId: currentModelId,
        onModelSelected: onModelSelected ?? (_) {},
      ),
    ),
    overrides: [
      aiConfigByTypeControllerProvider(
        configType: AiConfigType.inferenceProvider,
      ).overrideWithBuild(
        (ref, notifier) => Stream.value(providers),
      ),
      aiConfigByTypeControllerProvider(
        configType: AiConfigType.model,
      ).overrideWithBuild(
        (ref, notifier) => Stream.value(models),
      ),
    ],
  );
}

/// Taps the provider selector field (first dropdown icon).
Future<void> _tapProviderField(WidgetTester tester) async {
  final icons = find.byIcon(Icons.arrow_drop_down);
  await tester.tap(icons.first);
  await tester.pumpAndSettle();
}

/// Taps the model selector field (second dropdown icon).
Future<void> _tapModelField(WidgetTester tester) async {
  final icons = find.byIcon(Icons.arrow_drop_down);
  await tester.tap(icons.at(1));
  await tester.pumpAndSettle();
}

void main() {
  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);

  group('AgentModelSelector', () {
    testWidgets('shows placeholder when no model selected', (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          providers: [_providerA],
          models: [_suitableModel],
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentModelSelector));
      expect(
        find.text(context.messages.agentTemplateModelLabel),
        findsOneWidget,
      );
    });

    testWidgets('shows selected model name and providerModelId',
        (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          currentModelId: 'models/gemini-pro',
          providers: [_providerA],
          models: [_suitableModel],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Gemini Pro'), findsOneWidget);
      expect(find.text('models/gemini-pro'), findsOneWidget);
    });

    testWidgets('filters out non-reasoning models', (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          providers: [_providerA],
          models: [_suitableModel, _nonReasoningModel],
        ),
      );
      await tester.pumpAndSettle();

      await _tapModelField(tester);

      // Suitable model shown, non-reasoning filtered out
      expect(find.text('Gemini Pro'), findsOneWidget);
      expect(find.text('Fast Model'), findsNothing);
    });

    testWidgets('filters out models without function calling', (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          providers: [_providerA],
          models: [_suitableModel, _noFunctionCallingModel],
        ),
      );
      await tester.pumpAndSettle();

      await _tapModelField(tester);

      expect(find.text('Gemini Pro'), findsOneWidget);
      expect(find.text('Reason Only'), findsNothing);
    });

    testWidgets('selecting a model calls onModelSelected', (tester) async {
      String? selectedId;

      await tester.pumpWidget(
        _buildSubject(
          providers: [_providerA],
          models: [_suitableModel],
          onModelSelected: (id) => selectedId = id,
        ),
      );
      await tester.pumpAndSettle();

      await _tapModelField(tester);

      // Tap the model
      await tester.tap(find.text('Gemini Pro'));
      await tester.pumpAndSettle();

      expect(selectedId, 'models/gemini-pro');
    });

    testWidgets('provider filter narrows model list', (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          providers: [_providerA, _providerB],
          models: [_suitableModel, _suitableModelB],
        ),
      );
      await tester.pumpAndSettle();

      await _tapProviderField(tester);

      // Select Provider Alpha
      await tester.tap(find.text('Provider Alpha'));
      await tester.pumpAndSettle();

      // Now open model picker — should only show Gemini Pro
      await _tapModelField(tester);

      expect(find.text('Gemini Pro'), findsOneWidget);
      expect(find.text('Claude Opus'), findsNothing);
    });

    testWidgets('changing provider clears model selection', (tester) async {
      String? lastCallback;
      var callCount = 0;

      await tester.pumpWidget(
        _buildSubject(
          currentModelId: 'models/gemini-pro',
          providers: [_providerA, _providerB],
          models: [_suitableModel, _suitableModelB],
          onModelSelected: (id) {
            lastCallback = id;
            callCount++;
          },
        ),
      );
      await tester.pumpAndSettle();

      // Switch provider — should clear model
      await _tapProviderField(tester);
      await tester.tap(find.text('Provider Beta'));
      await tester.pumpAndSettle();

      expect(callCount, 1);
      expect(lastCallback, isNull);
    });

    testWidgets('shows requirements text when no suitable models',
        (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          providers: [_providerA],
          models: [_nonReasoningModel, _noFunctionCallingModel],
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentModelSelector));
      // Model field shows requirements text as placeholder
      expect(
        find.text(context.messages.agentTemplateModelRequirements),
        findsOneWidget,
      );
    });

    testWidgets('model picker disabled when no suitable models',
        (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          providers: [_providerA],
          models: [_nonReasoningModel],
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentModelSelector));
      expect(
        find.text(context.messages.agentTemplateModelRequirements),
        findsOneWidget,
      );

      // Tapping the disabled model field should not open a modal
      await tester.tap(
        find.text(context.messages.agentTemplateModelRequirements),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      // No modal should have opened
      expect(find.text('Fast Model'), findsNothing);
    });
  });
}
