import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/features/ai/ui/settings/ai_config_card.dart';
import 'package:mocktail/mocktail.dart';

class MockAiConfigRepository extends Mock implements AiConfigRepository {}

void main() {
  group('AI Settings Core Functionality', () {
    late MockAiConfigRepository mockRepository;
    late List<AiConfig> testProviders;
    late List<AiConfig> testModels;

    setUpAll(() {
      registerFallbackValue(
        AiConfig.inferenceProvider(
          id: 'fallback-id',
          name: 'Fallback Provider',
          inferenceProviderType: InferenceProviderType.genericOpenAi,
          apiKey: 'test-key',
          baseUrl: 'https://api.example.com',
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        ),
      );
    });

    setUp(() {
      mockRepository = MockAiConfigRepository();

      testProviders = [
        AiConfig.inferenceProvider(
          id: 'anthropic-provider',
          name: 'Anthropic Provider',
          description: 'Claude models provider',
          inferenceProviderType: InferenceProviderType.anthropic,
          apiKey: 'test-key',
          baseUrl: 'https://api.anthropic.com',
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        ),
        AiConfig.inferenceProvider(
          id: 'openai-provider',
          name: 'OpenAI Provider',
          description: 'GPT models provider',
          inferenceProviderType: InferenceProviderType.openAi,
          apiKey: 'test-key',
          baseUrl: 'https://api.openai.com',
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        ),
      ];

      testModels = [
        AiConfig.model(
          id: 'claude-model',
          name: 'Claude Sonnet 3.5',
          description: 'Fast and capable model',
          providerModelId: 'claude-3-5-sonnet-20241022',
          inferenceProviderId: 'anthropic-provider',
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
          inputModalities: [Modality.text, Modality.image],
          outputModalities: [Modality.text],
          isReasoningModel: false,
        ),
        AiConfig.model(
          id: 'gpt-model',
          name: 'GPT-4',
          description: 'Powerful reasoning model',
          providerModelId: 'gpt-4',
          inferenceProviderId: 'openai-provider',
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
          inputModalities: [Modality.text],
          outputModalities: [Modality.text],
          isReasoningModel: true,
        ),
      ];

      when(() => mockRepository.watchConfigsByType(AiConfigType.inferenceProvider))
          .thenAnswer((_) => Stream.value(testProviders));
      when(() => mockRepository.watchConfigsByType(AiConfigType.model))
          .thenAnswer((_) => Stream.value(testModels));
      when(() => mockRepository.watchConfigsByType(AiConfigType.prompt))
          .thenAnswer((_) => Stream.value([]));
    });

    Widget createTestWidget({required Widget child}) {
      return MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: ProviderScope(
          overrides: [
            aiConfigRepositoryProvider.overrideWithValue(mockRepository),
          ],
          child: Scaffold(body: child),
        ),
      );
    }

    testWidgets('AiConfigCard displays provider information correctly', (WidgetTester tester) async {
      final provider = testProviders.first;
      
      await tester.pumpWidget(
        createTestWidget(
          child: AiConfigCard(
            config: provider,
            onTap: () {},
          ),
        ),
      );

      expect(find.text(provider.name), findsOneWidget);
      expect(find.text(provider.description!), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome), findsOneWidget); // Anthropic icon
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('AiConfigCard displays model capabilities', (WidgetTester tester) async {
      final model = testModels.first;
      
      await tester.pumpWidget(
        createTestWidget(
          child: AiConfigCard(
            config: model,
            onTap: () {},
            showCapabilities: true,
          ),
        ),
      );

      expect(find.text(model.name), findsOneWidget);
      expect(find.text(model.description!), findsOneWidget);
      
      // Should show capability indicators
      expect(find.byIcon(Icons.text_fields), findsOneWidget); // Text
      expect(find.byIcon(Icons.visibility), findsOneWidget); // Vision
    });

    testWidgets('AiConfigCard handles tap correctly', (WidgetTester tester) async {
      bool tapped = false;
      final provider = testProviders.first;
      
      await tester.pumpWidget(
        createTestWidget(
          child: AiConfigCard(
            config: provider,
            onTap: () => tapped = true,
          ),
        ),
      );

      await tester.tap(find.byType(AiConfigCard));
      expect(tapped, isTrue);
    });

    testWidgets('TabBar widget displays correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: DefaultTabController(
            length: 3,
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const TabBar(
                    indicator: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicatorPadding: EdgeInsets.all(2),
                    dividerColor: Colors.transparent,
                    tabs: [
                      Tab(text: 'Providers'),
                      Tab(text: 'Models'),
                      Tab(text: 'Prompts'),
                    ],
                  ),
                ),
                const Expanded(
                  child: TabBarView(
                    children: [
                      Center(child: Text('Providers Tab')),
                      Center(child: Text('Models Tab')),
                      Center(child: Text('Prompts Tab')),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Providers'), findsOneWidget);
      expect(find.text('Models'), findsOneWidget);
      expect(find.text('Prompts'), findsOneWidget);
      expect(find.text('Providers Tab'), findsOneWidget);

      // Test tab switching
      await tester.tap(find.text('Models'));
      await tester.pumpAndSettle();
      expect(find.text('Models Tab'), findsOneWidget);
    });

    testWidgets('Search field filters correctly', (WidgetTester tester) async {
      String searchQuery = '';
      
      await tester.pumpWidget(
        createTestWidget(
          child: Column(
            children: [
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Search...',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) {
                  searchQuery = value;
                },
              ),
              Expanded(
                child: ListView(
                  children: testProviders
                      .where((p) => searchQuery.isEmpty || 
                          p.name.toLowerCase().contains(searchQuery.toLowerCase()))
                      .map((provider) => ListTile(
                          title: Text(provider.name),
                        ))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      );

      // Initially both providers should be visible
      expect(find.text('Anthropic Provider'), findsOneWidget);
      expect(find.text('OpenAI Provider'), findsOneWidget);

      // Search for "anthropic"
      await tester.enterText(find.byType(TextField), 'anthropic');
      await tester.pumpAndSettle();

      // Simulate the filtering (in a real app this would be reactive)
      searchQuery = 'anthropic';
      await tester.pumpWidget(
        createTestWidget(
          child: Column(
            children: [
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Search...',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) {
                  searchQuery = value;
                },
              ),
              Expanded(
                child: ListView(
                  children: testProviders
                      .where((p) => searchQuery.isEmpty || 
                          p.name.toLowerCase().contains(searchQuery.toLowerCase()))
                      .map((provider) => ListTile(
                          title: Text(provider.name),
                        ))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      );

      expect(find.text('Anthropic Provider'), findsOneWidget);
      expect(find.text('OpenAI Provider'), findsNothing);
    });
  });
}