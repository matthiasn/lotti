import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/state/inference_provider_form_controller.dart';
import 'package:lotti/features/ai/ui/settings/ai_config_list_page.dart';
import 'package:mocktail/mocktail.dart';

class MockAiConfigRepository extends Mock implements AiConfigRepository {}

class MockVoidCallback extends Mock {
  void call();
}

class MockItemTapCallback extends Mock {
  void call(AiConfig config);
}

class MockFormController extends Mock
    implements InferenceProviderFormController {
  @override
  final TextEditingController nameController = TextEditingController();

  @override
  final TextEditingController apiKeyController = TextEditingController();

  @override
  final TextEditingController baseUrlController = TextEditingController();

  @override
  final TextEditingController descriptionController = TextEditingController();
}

void main() {
  late MockAiConfigRepository mockRepository;
  late MockVoidCallback mockAddCallback;
  late MockItemTapCallback mockItemTapCallback;
  late List<AiConfig> testConfigs;
  // ignore: unused_local_variable
  late ProviderContainer container;

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
    mockAddCallback = MockVoidCallback();
    mockItemTapCallback = MockItemTapCallback();

    // Create test data
    testConfigs = [
      AiConfig.inferenceProvider(
        id: 'test-id-1',
        name: 'Test API 1',
        baseUrl: 'https://api1.example.com',
        apiKey: 'test-api-key-1',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.genericOpenAi,
      ),
      AiConfig.inferenceProvider(
        id: 'test-id-2',
        name: 'Test API 2',
        baseUrl: 'https://api2.example.com',
        apiKey: 'test-api-key-2',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.genericOpenAi,
      ),
      AiConfig.prompt(
        id: 'prompt-1',
        name: 'Prompt Test 1',
        template: 'Template for prompt test 1',
        defaultModelId: 'model-id-1',
        modelIds: [],
        requiredInputData: const [],
        createdAt: DateTime.now(),
        useReasoning: true,
      ),
      AiConfig.prompt(
        id: 'prompt-2',
        name: 'Prompt Test 2',
        template: 'Template for prompt test 2',
        defaultModelId: 'model-id-2',
        modelIds: [],
        requiredInputData: const [],
        createdAt: DateTime.now(),
        useReasoning: false,
      ),
    ];

    container = ProviderContainer(
      overrides: [
        aiConfigRepositoryProvider.overrideWithValue(mockRepository),
      ],
    );
  });

  // Helper function to build the widget under test
  Widget buildTestWidget({
    required AsyncValue<List<AiConfig>> initialState,
    VoidCallback? onAddPressed,
    void Function(AiConfig)? onItemTap,
  }) {
    // Create a mock stream that returns the appropriate values based on initialState
    // ignore: omit_local_variable_types
    final Stream<List<AiConfig>> testStream = switch (initialState) {
      AsyncData(value: final data) => Stream.value(data),
      AsyncError(error: final err) => Stream.error(err),
      _ => const Stream.empty(),
    };

    // Set up the repository to return our test stream when watchConfigsByType is called
    when(
      () => mockRepository.watchConfigsByType(AiConfigType.inferenceProvider),
    ).thenAnswer((_) => testStream);

    return ProviderScope(
      overrides: [
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
        home: AiConfigListPage(
          configType: AiConfigType.inferenceProvider,
          title: 'Test API Keys',
          onAddPressed: onAddPressed,
          onItemTap: onItemTap,
        ),
      ),
    );
  }

  group('AiConfigListPage Tests', () {
    testWidgets('should render loading state', (WidgetTester tester) async {
      // Set up repository to return a never-completing stream to simulate loading
      when(
        () => mockRepository.watchConfigsByType(AiConfigType.inferenceProvider),
      ).thenAnswer((_) => const Stream.empty());

      // Arrange
      await tester.pumpWidget(
        buildTestWidget(
          initialState: const AsyncLoading(),
        ),
      );

      // Use pump instead of pumpAndSettle for loading indicators that may animate continuously
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Assert
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should render error state', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        buildTestWidget(
          initialState: AsyncError('Test error', StackTrace.current),
        ),
      );

      // Need to add a pump to ensure all widgets are built
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Assert - look for partial text match since the exact error formatting may vary
      expect(
        find.textContaining('Error loading configurations'),
        findsOneWidget,
      );
    });

    testWidgets('should render empty state', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        buildTestWidget(
          initialState: const AsyncData([]),
        ),
      );

      // Need to add a pump to ensure all widgets are built
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Assert - look for partial text match
      expect(find.textContaining('No configurations found'), findsOneWidget);
    });

    testWidgets('should render list of configurations',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        buildTestWidget(
          initialState: AsyncData(testConfigs),
        ),
      );

      // Need to add a pump to ensure all widgets are built
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Assert - use byKey or other finders if text isn't found
      expect(find.textContaining('Test API 1'), findsOneWidget);
      expect(find.textContaining('Test API 2'), findsOneWidget);
    });

    testWidgets('should call onAddPressed when add button is tapped',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        buildTestWidget(
          initialState: AsyncData(testConfigs),
          onAddPressed: mockAddCallback.call,
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Act
      await tester.tap(find.byIcon(Icons.add));

      // Assert
      verify(() => mockAddCallback()).called(1);
    });

    testWidgets('should call onItemTap when list item is tapped',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        buildTestWidget(
          initialState: AsyncData(testConfigs),
          onItemTap: mockItemTapCallback.call,
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Act - find by partial text to make it more reliable
      await tester.tap(find.textContaining('Test API 1'));

      // Assert
      verify(() => mockItemTapCallback(any())).called(1);
    });

    testWidgets('should not show add button if onAddPressed is null',
        (WidgetTester tester) async {
      // Set up the stream to return our test configs
      when(
        () => mockRepository.watchConfigsByType(AiConfigType.inferenceProvider),
      ).thenAnswer((_) => Stream.value(testConfigs));

      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
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
            home: AiConfigListPage(
              configType: AiConfigType.inferenceProvider,
              title: 'Test API Keys',
              onItemTap: mockItemTapCallback.call,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Assert
      expect(find.byIcon(Icons.add), findsNothing);
    });

    group('Dismissible Tests', () {
      testWidgets('should have dismissible items', (WidgetTester tester) async {
        // Setup repository to return our test configs
        when(
          () =>
              mockRepository.watchConfigsByType(AiConfigType.inferenceProvider),
        ).thenAnswer((_) => Stream.value(testConfigs));

        // Arrange
        await tester.pumpWidget(
          buildTestWidget(
            initialState: AsyncData(testConfigs),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Assert - verify each list item is wrapped in a Dismissible
        expect(find.byType(Dismissible), findsNWidgets(testConfigs.length));
      });

      testWidgets('should show confirmation dialog when item is dismissed',
          (WidgetTester tester) async {
        // Mock API key controller for delete operations
        final formController = MockFormController();
        when(() => formController.deleteConfig(any())).thenAnswer((_) async {});

        // Setup repository to return our test configs
        when(
          () =>
              mockRepository.watchConfigsByType(AiConfigType.inferenceProvider),
        ).thenAnswer((_) => Stream.value(testConfigs));

        // Override the controller provider
        final overrides = [
          aiConfigRepositoryProvider.overrideWithValue(mockRepository),
          inferenceProviderFormControllerProvider(configId: 'test-id-1')
              .overrideWith(() => formController),
        ];

        // Arrange
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
                title: 'Test API Keys',
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Verify the test data is rendered correctly
        expect(find.byType(ListTile), findsNWidgets(testConfigs.length));
        final item = find.byType(ListTile).first;
        expect(item, findsOneWidget);

        // Act - dismiss the first item by dragging right to left
        await tester.drag(item, const Offset(-500, 0));
        await tester.pump(); // Start the dismiss animation
        await tester
            .pump(const Duration(milliseconds: 500)); // Wait for animation

        // Assert - check for dialog with correct title and message
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text('Confirm Deletion'), findsOneWidget);
        expect(
          find.textContaining('Are you sure you want to delete'),
          findsOneWidget,
        );
        expect(find.text('CANCEL'), findsOneWidget);
        expect(find.text('DELETE'), findsOneWidget);
      });

      testWidgets('should not delete item when dismissal is cancelled',
          (WidgetTester tester) async {
        // Mock the form controller
        final formController = MockFormController();
        when(() => formController.deleteConfig(any())).thenAnswer((_) async {});

        // Setup repository to return our test configs
        when(
          () =>
              mockRepository.watchConfigsByType(AiConfigType.inferenceProvider),
        ).thenAnswer((_) => Stream.value(testConfigs));

        // Override providers
        final overrides = [
          aiConfigRepositoryProvider.overrideWithValue(mockRepository),
          inferenceProviderFormControllerProvider(configId: 'test-id-1')
              .overrideWith(() => formController),
        ];

        // Arrange
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
                title: 'Test API Keys',
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Verify the test data is rendered correctly
        expect(find.byType(ListTile), findsNWidgets(testConfigs.length));

        // Find the first ListTile
        final firstItem = find.byType(ListTile).first;
        expect(firstItem, findsOneWidget);

        // Act - dismiss the first item
        await tester.drag(firstItem, const Offset(-500, 0));
        await tester.pump(); // Start the dismiss animation
        await tester
            .pump(const Duration(milliseconds: 500)); // Wait for animation

        // Find and tap the CANCEL button in the dialog
        await tester.tap(find.text('CANCEL'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Assert - verify deleteConfig was not called
        verifyNever(() => formController.deleteConfig(any()));

        // Item should still be in the list
        expect(find.byType(ListTile), findsNWidgets(testConfigs.length));
      });

      testWidgets(
          'should handle dismiss callbacks correctly when dismissing from left to right',
          (WidgetTester tester) async {
        // Mock the form controller
        final formController = MockFormController();
        when(() => formController.deleteConfig(any())).thenAnswer((_) async {});

        // Setup repository to return our test configs
        when(
          () => mockRepository.watchConfigsByType(
            AiConfigType.inferenceProvider,
          ),
        ).thenAnswer((_) => Stream.value(testConfigs));

        // Override providers
        final overrides = [
          aiConfigRepositoryProvider.overrideWithValue(mockRepository),
          inferenceProviderFormControllerProvider(configId: 'test-id-1')
              .overrideWith(() => formController),
        ];

        // Arrange
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
                title: 'Test API Keys',
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Verify the test data is rendered correctly
        expect(find.byType(ListTile), findsNWidgets(testConfigs.length));

        // Find the first ListTile
        final firstItem = find.byType(ListTile).first;
        expect(firstItem, findsOneWidget);

        // The dismissible in AiConfigListPage is configured to only work from right to left
        // So dragging from left to right should not trigger the dialog
        await tester.drag(firstItem, const Offset(500, 0));
        await tester.pump(); // Start the dismiss animation
        await tester
            .pump(const Duration(milliseconds: 500)); // Wait for animation

        // Dialog shouldn't appear for left-to-right swipe due to direction setting
        expect(find.byType(AlertDialog), findsNothing);
      });
    });
  });
}
