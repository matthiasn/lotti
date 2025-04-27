import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/state/api_key_form_controller.dart';
import 'package:lotti/features/ai/ui/settings/ai_config_list_page.dart';
import 'package:mocktail/mocktail.dart';

class MockAiConfigRepository extends Mock implements AiConfigRepository {}

class MockVoidCallback extends Mock {
  void call();
}

class MockItemTapCallback extends Mock {
  void call(AiConfig config);
}

class MockFormController extends Mock implements ApiKeyFormController {
  @override
  final TextEditingController nameController = TextEditingController();

  @override
  final TextEditingController apiKeyController = TextEditingController();

  @override
  final TextEditingController baseUrlController = TextEditingController();

  @override
  final TextEditingController commentController = TextEditingController();
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
      AiConfig.apiKey(
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
      AiConfig.apiKey(
        id: 'test-id-1',
        name: 'Test API 1',
        baseUrl: 'https://api1.example.com',
        apiKey: 'test-api-key-1',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.genericOpenAi,
      ),
      AiConfig.apiKey(
        id: 'test-id-2',
        name: 'Test API 2',
        baseUrl: 'https://api2.example.com',
        apiKey: 'test-api-key-2',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.genericOpenAi,
      ),
      AiConfig.promptTemplate(
        id: 'template-id-1',
        name: 'Test Template',
        template:
            'This is a template for testing purposes with some long text that will be truncated',
        createdAt: DateTime.now(),
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
    when(() => mockRepository.watchConfigsByType('apiKey')).thenAnswer(
      (_) => testStream,
    );

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
          configType: 'apiKey',
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
      when(() => mockRepository.watchConfigsByType('apiKey')).thenAnswer(
        (_) => const Stream.empty(),
      );

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
      when(() => mockRepository.watchConfigsByType('apiKey')).thenAnswer(
        (_) => Stream.value(testConfigs),
      );

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
              configType: 'apiKey',
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
  });
}
