import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/inference_provider_form_state.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/state/inference_provider_form_controller.dart';
import 'package:lotti/features/ai/ui/settings/ai_config_list_page.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class MockAiConfigRepository extends Mock implements AiConfigRepository {}

class FakeSnackbarTestFormController extends InferenceProviderFormController {
  List<String> deleteConfigCalls = [];
  CascadeDeletionResult? mockResult;
  bool shouldFail = false;

  @override
  Future<InferenceProviderFormState?> build({required String? configId}) async {
    return null;
  }

  @override
  Future<CascadeDeletionResult> deleteConfig(String id) async {
    deleteConfigCalls.add(id);
    if (shouldFail) {
      throw Exception('Deletion failed for testing');
    }
    return mockResult ??
        const CascadeDeletionResult(
          deletedModels: [],
          providerName: 'Test Provider',
        );
  }

  @override
  Future<void> addConfig(AiConfig config) async {}

  // Minimal implementation of required methods
  @override
  TextEditingController get nameController => TextEditingController();
  @override
  TextEditingController get apiKeyController => TextEditingController();
  @override
  TextEditingController get baseUrlController => TextEditingController();
  @override
  TextEditingController get descriptionController => TextEditingController();

  @override
  void nameChanged(String name) {}
  @override
  void apiKeyChanged(String apiKey) {}
  @override
  void baseUrlChanged(String baseUrl) {}
  @override
  void descriptionChanged(String description) {}
  @override
  void inferenceProviderTypeChanged(InferenceProviderType type) {}
  @override
  Future<void> updateConfig(AiConfig config) async {}
  @override
  void reset() {}
}

void main() {
  late MockAiConfigRepository mockRepository;

  setUp(() {
    mockRepository = MockAiConfigRepository();
  });

  group('AiConfigListPage Snackbar Tests', () {
    testWidgets(
        'should show success snackbar with provider name only when no models deleted',
        (WidgetTester tester) async {
      final providerConfig = AiConfig.inferenceProvider(
        id: 'provider-1',
        name: 'OpenAI Provider',
        baseUrl: 'https://api.openai.com',
        apiKey: 'test-key',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.openAi,
      );

      final fakeFormController = FakeSnackbarTestFormController()
        ..mockResult = const CascadeDeletionResult(
          deletedModels: [],
          providerName: 'OpenAI Provider',
        );

      when(() =>
              mockRepository.watchConfigsByType(AiConfigType.inferenceProvider))
          .thenAnswer((_) => Stream.value([providerConfig]));

      final overrides = [
        aiConfigRepositoryProvider.overrideWithValue(mockRepository),
        inferenceProviderFormControllerProvider(configId: 'provider-1')
            .overrideWith(() => fakeFormController),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: const MaterialApp(
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: [Locale('en', '')],
            home: AiConfigListPage(
              configType: AiConfigType.inferenceProvider,
              title: 'Test Providers',
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Trigger deletion
      final item = find.byType(ListTile).first;
      await tester.drag(item, const Offset(-500, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Confirm deletion
      await tester.tap(find.text('DELETE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Wait for snackbar to appear
      await tester.pump(const Duration(milliseconds: 100));

      // Verify snackbar appears with correct content
      expect(find.byType(SnackBar), findsOneWidget);
      expect(
          find.descendant(
            of: find.byType(SnackBar),
            matching: find.text('OpenAI Provider'),
          ),
          findsOneWidget);
      expect(find.text('Provider deleted successfully'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      expect(find.text('UNDO'), findsOneWidget);

      // Should NOT show models section since no models were deleted
      expect(find.byIcon(Icons.analytics_outlined), findsNothing);
    });

    testWidgets(
        'should show success snackbar with individual model names when ≤4 models deleted',
        (WidgetTester tester) async {
      final providerConfig = AiConfig.inferenceProvider(
        id: 'provider-1',
        name: 'Gemini Provider',
        baseUrl: 'https://api.gemini.com',
        apiKey: 'test-key',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.gemini,
      );

      final deletedModels = [
        AiConfigModel(
          id: 'model-1',
          name: 'gemini-pro',
          providerModelId: 'gemini-pro',
          inferenceProviderId: 'provider-1',
          createdAt: DateTime.now(),
          inputModalities: [Modality.text],
          outputModalities: [Modality.text],
          isReasoningModel: false,
        ),
        AiConfigModel(
          id: 'model-2',
          name: 'gemini-pro-vision',
          providerModelId: 'gemini-pro-vision',
          inferenceProviderId: 'provider-1',
          createdAt: DateTime.now(),
          inputModalities: [Modality.text, Modality.image],
          outputModalities: [Modality.text],
          isReasoningModel: false,
        ),
      ];

      final fakeFormController = FakeSnackbarTestFormController()
        ..mockResult = CascadeDeletionResult(
          deletedModels: deletedModels,
          providerName: 'Gemini Provider',
        );

      when(() =>
              mockRepository.watchConfigsByType(AiConfigType.inferenceProvider))
          .thenAnswer((_) => Stream.value([providerConfig]));

      final overrides = [
        aiConfigRepositoryProvider.overrideWithValue(mockRepository),
        inferenceProviderFormControllerProvider(configId: 'provider-1')
            .overrideWith(() => fakeFormController),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: const MaterialApp(
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: [Locale('en', '')],
            home: AiConfigListPage(
              configType: AiConfigType.inferenceProvider,
              title: 'Test Providers',
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Trigger deletion
      final item = find.byType(ListTile).first;
      await tester.drag(item, const Offset(-500, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Confirm deletion
      await tester.tap(find.text('DELETE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Wait for snackbar to appear
      await tester.pump(const Duration(milliseconds: 100));

      // Verify snackbar appears with correct content
      expect(find.byType(SnackBar), findsOneWidget);
      expect(
          find.descendant(
            of: find.byType(SnackBar),
            matching: find.text('Gemini Provider'),
          ),
          findsOneWidget);
      expect(find.text('Provider deleted successfully'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);

      // Should show models section with individual model names
      expect(find.byIcon(Icons.analytics_outlined), findsOneWidget);
      expect(find.text('2 associated models removed'), findsOneWidget);
      expect(find.text('gemini-pro'), findsOneWidget);
      expect(find.text('gemini-pro-vision'), findsOneWidget);
    });

    testWidgets(
        'should show success snackbar with summary when >4 models deleted',
        (WidgetTester tester) async {
      final providerConfig = AiConfig.inferenceProvider(
        id: 'provider-1',
        name: 'Large Provider',
        baseUrl: 'https://api.large.com',
        apiKey: 'test-key',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.genericOpenAi,
      );

      final deletedModels = List.generate(
        6,
        (i) => AiConfigModel(
          id: 'model-$i',
          name: 'model-name-$i',
          providerModelId: 'provider-model-$i',
          inferenceProviderId: 'provider-1',
          createdAt: DateTime.now(),
          inputModalities: [Modality.text],
          outputModalities: [Modality.text],
          isReasoningModel: false,
        ),
      );

      final fakeFormController = FakeSnackbarTestFormController()
        ..mockResult = CascadeDeletionResult(
          deletedModels: deletedModels,
          providerName: 'Large Provider',
        );

      when(() =>
              mockRepository.watchConfigsByType(AiConfigType.inferenceProvider))
          .thenAnswer((_) => Stream.value([providerConfig]));

      final overrides = [
        aiConfigRepositoryProvider.overrideWithValue(mockRepository),
        inferenceProviderFormControllerProvider(configId: 'provider-1')
            .overrideWith(() => fakeFormController),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: const MaterialApp(
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: [Locale('en', '')],
            home: AiConfigListPage(
              configType: AiConfigType.inferenceProvider,
              title: 'Test Providers',
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Trigger deletion
      final item = find.byType(ListTile).first;
      await tester.drag(item, const Offset(-500, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Confirm deletion
      await tester.tap(find.text('DELETE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Wait for snackbar to appear
      await tester.pump(const Duration(milliseconds: 100));

      // Verify snackbar appears with correct content
      expect(find.byType(SnackBar), findsOneWidget);
      expect(
          find.descendant(
            of: find.byType(SnackBar),
            matching: find.text('Large Provider'),
          ),
          findsOneWidget);
      expect(find.text('Provider deleted successfully'), findsOneWidget);

      // Should show models section with summary
      expect(find.byIcon(Icons.analytics_outlined), findsOneWidget);
      expect(find.text('6 associated models removed'), findsOneWidget);

      // Should show summary text instead of individual names
      expect(
          find.textContaining(
              'Including: model-name-0, model-name-1, and 4 more'),
          findsOneWidget);

      // Should NOT show individual model names beyond the first 2
      expect(find.text('model-name-2'), findsNothing);
      expect(find.text('model-name-3'), findsNothing);
    });

    testWidgets('should show error snackbar when deletion fails',
        (WidgetTester tester) async {
      final providerConfig = AiConfig.inferenceProvider(
        id: 'provider-1',
        name: 'Failed Provider',
        baseUrl: 'https://api.failed.com',
        apiKey: 'test-key',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.openAi,
      );

      final fakeFormController = FakeSnackbarTestFormController()
        ..shouldFail = true;

      when(() =>
              mockRepository.watchConfigsByType(AiConfigType.inferenceProvider))
          .thenAnswer((_) => Stream.value([providerConfig]));

      final overrides = [
        aiConfigRepositoryProvider.overrideWithValue(mockRepository),
        inferenceProviderFormControllerProvider(configId: 'provider-1')
            .overrideWith(() => fakeFormController),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: const MaterialApp(
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: [Locale('en', '')],
            home: AiConfigListPage(
              configType: AiConfigType.inferenceProvider,
              title: 'Test Providers',
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Trigger deletion
      final item = find.byType(ListTile).first;
      await tester.drag(item, const Offset(-500, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Confirm deletion
      await tester.tap(find.text('DELETE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Wait for snackbar to appear
      await tester.pump(const Duration(milliseconds: 100));

      // Verify error snackbar appears
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('Error deleting Failed Provider'),
          findsOneWidget);
      expect(
          find.textContaining('Deletion failed for testing'), findsOneWidget);
    });

    testWidgets('should test pluralization for single model',
        (WidgetTester tester) async {
      final providerConfig = AiConfig.inferenceProvider(
        id: 'provider-1',
        name: 'Single Model Provider',
        baseUrl: 'https://api.single.com',
        apiKey: 'test-key',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.openAi,
      );

      final deletedModels = [
        AiConfigModel(
          id: 'model-1',
          name: 'single-model',
          providerModelId: 'single-model',
          inferenceProviderId: 'provider-1',
          createdAt: DateTime.now(),
          inputModalities: [Modality.text],
          outputModalities: [Modality.text],
          isReasoningModel: false,
        ),
      ];

      final fakeFormController = FakeSnackbarTestFormController()
        ..mockResult = CascadeDeletionResult(
          deletedModels: deletedModels,
          providerName: 'Single Model Provider',
        );

      when(() =>
              mockRepository.watchConfigsByType(AiConfigType.inferenceProvider))
          .thenAnswer((_) => Stream.value([providerConfig]));

      final overrides = [
        aiConfigRepositoryProvider.overrideWithValue(mockRepository),
        inferenceProviderFormControllerProvider(configId: 'provider-1')
            .overrideWith(() => fakeFormController),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: const MaterialApp(
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: [Locale('en', '')],
            home: AiConfigListPage(
              configType: AiConfigType.inferenceProvider,
              title: 'Test Providers',
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Trigger deletion
      final item = find.byType(ListTile).first;
      await tester.drag(item, const Offset(-500, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Confirm deletion
      await tester.tap(find.text('DELETE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Wait for snackbar to appear
      await tester.pump(const Duration(milliseconds: 100));

      // Verify correct pluralization for single model
      expect(find.text('1 associated model removed'), findsOneWidget);
      expect(find.text('single-model'), findsOneWidget);
    });
  });
}
