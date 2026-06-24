import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/widgets/inference_provider_model_picker_modal.dart';

import '../../../../widget_test_utils.dart';

AiConfigInferenceProvider _provider({
  required String id,
  InferenceProviderType type = InferenceProviderType.openAi,
}) {
  return AiConfigInferenceProvider(
    id: id,
    name: id,
    baseUrl: 'https://api.test',
    apiKey: 'k',
    inferenceProviderType: type,
    createdAt: DateTime(2024, 3, 15),
  );
}

AiConfigModel _model({
  required String id,
  required String name,
  String providerModelId = 'wire/id',
  String inferenceProviderId = 'openai',
}) {
  return AiConfigModel(
    id: id,
    name: name,
    providerModelId: providerModelId,
    inferenceProviderId: inferenceProviderId,
    createdAt: DateTime(2024, 3, 15),
    inputModalities: const [Modality.text],
    outputModalities: const [Modality.text],
    isReasoningModel: false,
  );
}

void main() {
  group('orderModelsDefaultFirst', () {
    final a = _model(id: 'a', name: 'A');
    final b = _model(id: 'b', name: 'B');
    final c = _model(id: 'c', name: 'C');

    test('moves the default to the front, preserving the rest order', () {
      final ordered = InferenceProviderModelPickerModal.orderModelsDefaultFirst(
        [a, b, c],
        'b',
      );
      expect(ordered.map((m) => m.id), ['b', 'a', 'c']);
    });

    test('returns the list unchanged when defaultModelId is null', () {
      final ordered = InferenceProviderModelPickerModal.orderModelsDefaultFirst(
        [a, b, c],
        null,
      );
      expect(ordered.map((m) => m.id), ['a', 'b', 'c']);
    });

    test('returns the list unchanged when the default is not in the list', () {
      final ordered = InferenceProviderModelPickerModal.orderModelsDefaultFirst(
        [a, b, c],
        'missing',
      );
      expect(ordered.map((m) => m.id), ['a', 'b', 'c']);
    });
  });

  group('InferenceProviderModelPickerModal.show', () {
    Future<void> pumpHost(
      WidgetTester tester, {
      required List<AiConfigModel> models,
      required List<AiConfigInferenceProvider> providers,
      required void Function(String?) onResult,
      String? defaultModelId,
    }) async {
      await tester.pumpWidget(
        makeTestableWidget(
          Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  final picked = await InferenceProviderModelPickerModal.show(
                    context: context,
                    defaultModelId: defaultModelId,
                    models: models,
                    providers: providers,
                    title: 'Pick a model',
                    defaultBadgeLabel: 'Default',
                  );
                  onResult(picked);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('returns null and shows no modal when there are no models', (
      tester,
    ) async {
      String? result = 'sentinel';
      var called = false;
      await pumpHost(
        tester,
        models: const [],
        providers: const [],
        onResult: (r) {
          result = r;
          called = true;
        },
      );
      expect(called, isTrue);
      expect(result, isNull);
      expect(find.text('Pick a model'), findsNothing);
    });

    testWidgets('returns the only model id without showing a modal', (
      tester,
    ) async {
      String? result;
      var called = false;
      await pumpHost(
        tester,
        models: [_model(id: 'solo', name: 'Solo')],
        providers: [_provider(id: 'openai')],
        onResult: (r) {
          result = r;
          called = true;
        },
      );
      expect(called, isTrue);
      expect(result, 'solo');
      expect(find.text('Solo'), findsNothing);
    });

    testWidgets(
      'filters out models whose provider is missing, then short-circuits to '
      'the single remaining valid model',
      (tester) async {
        String? result;
        var called = false;
        await pumpHost(
          tester,
          models: [
            _model(id: 'm1', name: 'Model One', providerModelId: 'p/one'),
            _model(
              id: 'm2',
              name: 'Model Two',
              providerModelId: 'p/two',
              inferenceProviderId: 'missing-provider',
            ),
          ],
          providers: [_provider(id: 'openai')],
          onResult: (r) {
            result = r;
            called = true;
          },
        );
        // m2's provider isn't configured -> dropped -> only m1 is valid ->
        // single-model short-circuit, no modal.
        expect(called, isTrue);
        expect(result, 'm1');
        expect(find.text('Model One'), findsNothing);
        expect(find.text('Model Two'), findsNothing);
      },
    );

    testWidgets(
      'single provider: skips the provider step and selects a model directly',
      (tester) async {
        String? result;
        await pumpHost(
          tester,
          models: [
            _model(id: 'm1', name: 'Model One', providerModelId: 'p/one'),
            _model(id: 'm2', name: 'Model Two', providerModelId: 'p/two'),
          ],
          providers: [_provider(id: 'openai')],
          defaultModelId: 'm1',
          onResult: (r) => result = r,
        );

        // No provider step — straight to the model list.
        expect(find.text('Choose a provider'), findsNothing);
        expect(find.text('Model One'), findsOneWidget);
        expect(find.text('Model Two'), findsOneWidget);
        expect(find.text('p/two'), findsOneWidget); // wire id rendered

        await tester.tap(find.text('Model Two'));
        await tester.pumpAndSettle();
        expect(result, 'm2');
      },
    );

    testWidgets(
      'multi provider: drill into a provider then select one of its models',
      (tester) async {
        String? result;
        await pumpHost(
          tester,
          models: [
            _model(id: 'o1', name: 'GPT-5'),
            _model(id: 'o2', name: 'GPT-5 mini'),
            _model(id: 'l1', name: 'Llama', inferenceProviderId: 'ollama'),
          ],
          providers: [
            _provider(id: 'openai'),
            _provider(id: 'ollama', type: InferenceProviderType.ollama),
          ],
          defaultModelId: 'o1',
          onResult: (r) => result = r,
        );

        // Provider page with counts.
        expect(find.text('Choose a provider'), findsOneWidget);
        expect(find.text('OpenAI'), findsOneWidget);
        expect(find.text('Ollama'), findsOneWidget);
        expect(find.text('2 models'), findsOneWidget);
        expect(find.text('1 model'), findsOneWidget);

        await tester.tap(find.text('OpenAI'));
        await tester.pumpAndSettle();

        // Model page for OpenAI.
        expect(find.text('GPT-5'), findsOneWidget);
        expect(find.text('GPT-5 mini'), findsOneWidget);

        await tester.tap(find.text('GPT-5 mini'));
        await tester.pumpAndSettle();
        expect(result, 'o2');
      },
    );

    testWidgets('multi provider: the Current default shortcut returns it', (
      tester,
    ) async {
      String? result;
      await pumpHost(
        tester,
        models: [
          _model(id: 'o1', name: 'GPT-5', providerModelId: 'gpt-5'),
          _model(id: 'l1', name: 'Llama', inferenceProviderId: 'ollama'),
        ],
        providers: [
          _provider(id: 'openai'),
          _provider(id: 'ollama', type: InferenceProviderType.ollama),
        ],
        defaultModelId: 'o1',
        onResult: (r) => result = r,
      );

      // The default renders as a model row (name + wire id + Default marker)
      // under the "Current default" caption.
      expect(find.text('Current default'), findsOneWidget);
      expect(find.text('GPT-5'), findsOneWidget);
      expect(find.text('gpt-5'), findsOneWidget);
      expect(find.text('Default'), findsOneWidget);

      await tester.tap(find.text('GPT-5'));
      await tester.pumpAndSettle();
      expect(result, 'o1');
    });

    testWidgets('multi provider without a default omits the default zone', (
      tester,
    ) async {
      await pumpHost(
        tester,
        models: [
          _model(id: 'o1', name: 'GPT-5'),
          _model(id: 'l1', name: 'Llama', inferenceProviderId: 'ollama'),
        ],
        providers: [
          _provider(id: 'openai'),
          _provider(id: 'ollama', type: InferenceProviderType.ollama),
        ],
        onResult: (_) {},
      );

      expect(find.text('Current default'), findsNothing);
      expect(find.text('Default'), findsNothing);
      expect(find.text('OpenAI'), findsOneWidget);
    });

    testWidgets('the back arrow returns from the model page to the providers', (
      tester,
    ) async {
      await pumpHost(
        tester,
        models: [
          _model(id: 'o1', name: 'GPT-5'),
          _model(id: 'l1', name: 'Llama', inferenceProviderId: 'ollama'),
        ],
        providers: [
          _provider(id: 'openai'),
          _provider(id: 'ollama', type: InferenceProviderType.ollama),
        ],
        defaultModelId: 'o1',
        onResult: (_) {},
      );

      await tester.tap(find.text('Ollama'));
      await tester.pumpAndSettle();
      expect(find.text('Llama'), findsOneWidget);
      expect(find.text('Choose a provider'), findsNothing);

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Choose a provider'), findsOneWidget);
    });

    testWidgets('dismissing via the close button returns null', (tester) async {
      String? result = 'sentinel';
      var called = false;
      await pumpHost(
        tester,
        models: [
          _model(id: 'o1', name: 'GPT-5'),
          _model(id: 'l1', name: 'Llama', inferenceProviderId: 'ollama'),
        ],
        providers: [
          _provider(id: 'openai'),
          _provider(id: 'ollama', type: InferenceProviderType.ollama),
        ],
        defaultModelId: 'o1',
        onResult: (r) {
          result = r;
          called = true;
        },
      );

      await tester.tap(find.byIcon(Icons.close_rounded).first);
      await tester.pumpAndSettle();
      expect(called, isTrue);
      expect(result, isNull);
    });
  });
}
