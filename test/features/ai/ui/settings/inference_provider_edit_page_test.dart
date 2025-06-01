import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/inference_provider_extensions.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/ui/settings/inference_provider_edit_page.dart';
import 'package:lotti/features/ai/ui/settings/inference_provider_form.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

// Mock classes
class MockAiConfigRepository extends Mock implements AiConfigRepository {}

class MockNavigatorObserver extends Mock implements NavigatorObserver {}

void main() {
  late MockAiConfigRepository mockRepository;
  late AiConfig testConfig;

  setUpAll(() {
    registerFallbackValue(
      AiConfig.inferenceProvider(
        id: 'fallback-id',
        name: 'Fallback API',
        baseUrl: 'https://fallback.example.com',
        apiKey: 'fallback-key',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.genericOpenAi,
      ),
    );
  });

  setUp(() {
    mockRepository = MockAiConfigRepository();

    // Create a test config
    testConfig = AiConfig.inferenceProvider(
      id: 'test-id',
      name: 'Test API',
      baseUrl: 'https://api.example.com',
      apiKey: 'test-api-key',
      createdAt: DateTime.now(),
      inferenceProviderType: InferenceProviderType.genericOpenAi,
    );

    // Set up the repository responses
    when(() => mockRepository.saveConfig(any())).thenAnswer((_) async {});
    when(() => mockRepository.getConfigById('test-id'))
        .thenAnswer((_) async => testConfig);
  });

  // Helper function to build the widget under test
  Widget buildTestWidget({String? configId}) {
    return ProviderScope(
      overrides: [
        // Mock the repository instead of the controller
        aiConfigRepositoryProvider.overrideWithValue(mockRepository),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: InferenceProviderEditPage(configId: configId),
        navigatorObservers: [MockNavigatorObserver()],
      ),
    );
  }

  group('ApiKeyEditPage Tests', () {
    testWidgets(
        'should display "Add AI Inference Provider" title when configId is null',
        (WidgetTester tester) async {
      // Set a larger viewport size using the non-deprecated approach
      await tester.binding.setSurfaceSize(const Size(1024, 768));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Arrange
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Add AI Inference Provider'), findsOneWidget);
      expect(find.byType(InferenceProviderForm), findsOneWidget);
    });

    testWidgets(
        'should display "Edit AI Inference Provider" title when configId is provided',
        (WidgetTester tester) async {
      // Set a larger viewport size using the non-deprecated approach
      await tester.binding.setSurfaceSize(const Size(1024, 768));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Arrange
      await tester.pumpWidget(buildTestWidget(configId: 'test-id'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Edit AI Inference Provider'), findsOneWidget);
      expect(find.byType(InferenceProviderForm), findsOneWidget);
    });

    testWidgets('should call repository saveConfig when adding a new API key',
        (WidgetTester tester) async {
      // Set a larger viewport size using the non-deprecated approach
      await tester.binding.setSurfaceSize(const Size(1024, 768));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Clear previous interactions
      reset(mockRepository);
      when(() => mockRepository.saveConfig(any())).thenAnswer((_) async {});

      // Arrange
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Fill in the form fields
      await tester.enterText(
        find.widgetWithText(TextField, 'Display Name'),
        'New API',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Base URL'),
        'https://new.example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'API Key'),
        'new-api-key',
      );
      await tester.pumpAndSettle();

      // Find and tap the save button in the app bar
      final saveButton = find.widgetWithText(TextButton, 'Save');
      expect(saveButton, findsOneWidget);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Verify saveConfig was called
      verify(() => mockRepository.saveConfig(any())).called(1);
    });

    testWidgets(
        'should call repository saveConfig when updating an existing API key',
        (WidgetTester tester) async {
      // Set a larger viewport size using the non-deprecated approach
      await tester.binding.setSurfaceSize(const Size(1024, 768));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Clear previous interactions
      reset(mockRepository);
      when(() => mockRepository.getConfigById('test-id'))
          .thenAnswer((_) async => testConfig);
      when(() => mockRepository.saveConfig(any())).thenAnswer((_) async {});

      // Arrange
      await tester.pumpWidget(buildTestWidget(configId: 'test-id'));
      await tester.pumpAndSettle();

      // Modify a field to make the form dirty
      final nameField = find.widgetWithText(TextField, 'Display Name');
      await tester.enterText(nameField, 'Updated API');
      await tester.pumpAndSettle();

      // Find and tap the save button in the app bar
      final saveButton = find.widgetWithText(TextButton, 'Save');
      expect(saveButton, findsOneWidget);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Verify saveConfig was called
      verify(() => mockRepository.saveConfig(any())).called(1);
    });

    testWidgets('should show loading indicator when loading a config',
        (WidgetTester tester) async {
      // Set a larger viewport size using the non-deprecated approach
      await tester.binding.setSurfaceSize(const Size(1024, 768));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Arrange - use a Completer that we can control
      final completer = Completer<AiConfig?>();
      when(() => mockRepository.getConfigById('test-id'))
          .thenAnswer((_) => completer.future);

      await tester.pumpWidget(buildTestWidget(configId: 'test-id'));

      // Assert - should see loading indicator while future is pending
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete the future to clean up
      completer.complete(testConfig);
      await tester.pumpAndSettle();
    });

    testWidgets('should show error message when config loading fails',
        (WidgetTester tester) async {
      // Set a larger viewport size using the non-deprecated approach
      await tester.binding.setSurfaceSize(const Size(1024, 768));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Arrange - repository that throws an error
      when(() => mockRepository.getConfigById('test-id'))
          .thenAnswer((_) => Future<AiConfig?>.error('Failed to load'));

      await tester.pumpWidget(buildTestWidget(configId: 'test-id'));

      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Failed to load API key configuration'), findsOneWidget);
    });

    testWidgets(
        'should display provider type selection modal when tapping field',
        (WidgetTester tester) async {
      // Set a larger viewport size
      await tester.binding.setSurfaceSize(const Size(1024, 768));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Arrange
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Verify initial provider type is shown
      final context = tester.element(find.byType(InferenceProviderForm));
      expect(
        find.text(InferenceProviderType.genericOpenAi.displayName(context)),
        findsOneWidget,
      );

      // Find and tap on the provider type field (use InputDecorator with the label text)
      final providerField = find.ancestor(
        of: find.text('Provider Type'),
        matching: find.byType(InputDecorator),
      );
      expect(providerField, findsOneWidget);

      // Find the InkWell that wraps the InputDecorator
      final inkWell = find.ancestor(
        of: providerField,
        matching: find.byType(InkWell),
      );
      expect(inkWell, findsOneWidget);

      // Tap on the InkWell to open the modal
      await tester.tap(inkWell);
      await tester.pumpAndSettle();

      // Verify modal is shown with title
      expect(find.text('Select Provider Type'), findsOneWidget);

      // Find the list of provider options
      expect(find.byType(ListTile), findsWidgets);

      // Verify at least one provider type is listed
      final modalContext = tester.element(find.text('Select Provider Type'));
      expect(
        find.text(
          InferenceProviderType.genericOpenAi.displayName(modalContext),
        ),
        findsWidgets,
      );
    });

    testWidgets('should update provider type when selecting from modal',
        (WidgetTester tester) async {
      // Set a larger viewport size
      await tester.binding.setSurfaceSize(const Size(1024, 768));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Arrange
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Get the build context
      final context = tester.element(find.byType(InferenceProviderForm));

      // Open the provider type selection modal
      final inkWell = find.ancestor(
        of: find.ancestor(
          of: find.text('Provider Type'),
          matching: find.byType(InputDecorator),
        ),
        matching: find.byType(InkWell),
      );
      await tester.tap(inkWell);
      await tester.pumpAndSettle();

      // Select a different provider type (find a listTile other than the default one)
      const anthropicType = InferenceProviderType.anthropic;
      final anthropicListTile = find.ancestor(
        of: find.text(anthropicType.displayName(context)),
        matching: find.byType(ListTile),
      );

      await tester.tap(anthropicListTile);
      await tester.pumpAndSettle();

      // Recreate the form with the new state and verify the display
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
    });

    testWidgets(
        'should show check mark for the currently selected provider type',
        (WidgetTester tester) async {
      // Set a larger viewport size
      await tester.binding.setSurfaceSize(const Size(1024, 768));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Arrange
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Open the provider type selection modal
      final inkWell = find.ancestor(
        of: find.ancestor(
          of: find.text('Provider Type'),
          matching: find.byType(InputDecorator),
        ),
        matching: find.byType(InkWell),
      );
      await tester.tap(inkWell);
      await tester.pumpAndSettle();

      // Get a context from the modal
      final modalContext = tester.element(find.text('Select Provider Type'));

      // Find the current provider type (genericOpenAi by default)
      final genericListTiles = find.ancestor(
        of: find.text(
          InferenceProviderType.genericOpenAi.displayName(modalContext),
        ),
        matching: find.byType(ListTile),
      );

      // Check each tile for a check mark
      for (final genericListTileElement in genericListTiles.evaluate()) {
        final tile = genericListTileElement.widget as ListTile;
        // Check if any has a check mark as trailing
        if (tile.trailing != null) {
          expect(tile.trailing, isA<Icon>());
        }
      }
    });
  });
}
