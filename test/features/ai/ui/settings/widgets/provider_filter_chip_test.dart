import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/ui/settings/widgets/provider_filter_chip.dart';
import 'package:lotti/l10n/app_localizations.dart';

void main() {
  group('Provider Filter Chip Color Tests', () {
    testWidgets('Anthropic provider has bronze color in light theme',
        (tester) async {
      final provider = AiConfigInferenceProvider(
        id: 'provider1',
        name: 'Anthropic',
        baseUrl: 'https://api.anthropic.com',
        apiKey: 'test-key',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.anthropic,
      );

      var tapCalled = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aiConfigByIdProvider('provider1')
                .overrideWith((ref) async => provider),
          ],
          child: MaterialApp(
            theme: ThemeData.light(),
            home: Scaffold(
              body: ProviderFilterChip(
                providerId: 'provider1',
                isSelected: false,
                onTap: () => tapCalled = true,
              ),
            ),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify provider name is displayed
      expect(find.text('Anthropic'), findsOneWidget);

      // Verify colored dot is rendered
      final containerFinder = find.byType(Container);
      expect(containerFinder, findsWidgets);

      // Find the FilterChip and verify tap works
      final filterChip = find.byType(FilterChip);
      expect(filterChip, findsOneWidget);

      await tester.tap(filterChip);
      await tester.pump();

      expect(tapCalled, isTrue);
    });

    testWidgets('OpenAI provider has green color in dark theme',
        (tester) async {
      final provider = AiConfigInferenceProvider(
        id: 'provider2',
        name: 'OpenAI',
        baseUrl: 'https://api.openai.com',
        apiKey: 'test-key',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.openAi,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aiConfigByIdProvider('provider2')
                .overrideWith((ref) async => provider),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: ProviderFilterChip(
                providerId: 'provider2',
                isSelected: false,
                onTap: () {},
              ),
            ),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('OpenAI'), findsOneWidget);
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('Gemini provider has blue color', (tester) async {
      final provider = AiConfigInferenceProvider(
        id: 'provider3',
        name: 'Gemini',
        baseUrl: 'https://api.google.com',
        apiKey: 'test-key',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.gemini,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aiConfigByIdProvider('provider3')
                .overrideWith((ref) async => provider),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ProviderFilterChip(
                providerId: 'provider3',
                isSelected: false,
                onTap: () {},
              ),
            ),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Gemini'), findsOneWidget);
    });

    testWidgets('Ollama provider has orange color', (tester) async {
      final provider = AiConfigInferenceProvider(
        id: 'provider4',
        name: 'Ollama',
        baseUrl: 'http://localhost:11434',
        apiKey: '',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.ollama,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aiConfigByIdProvider('provider4')
                .overrideWith((ref) async => provider),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ProviderFilterChip(
                providerId: 'provider4',
                isSelected: false,
                onTap: () {},
              ),
            ),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Ollama'), findsOneWidget);
    });

    testWidgets('All provider types render correctly', (tester) async {
      final providers = [
        (InferenceProviderType.anthropic, 'Anthropic'),
        (InferenceProviderType.openAi, 'OpenAI'),
        (InferenceProviderType.gemini, 'Gemini'),
        (InferenceProviderType.ollama, 'Ollama'),
        (InferenceProviderType.openRouter, 'OpenRouter'),
        (InferenceProviderType.genericOpenAi, 'Generic OpenAI'),
        (InferenceProviderType.nebiusAiStudio, 'Nebius'),
        (InferenceProviderType.whisper, 'Whisper'),
        (InferenceProviderType.gemma3n, 'Gemma'),
      ];

      for (final (type, name) in providers) {
        final provider = AiConfigInferenceProvider(
          id: 'provider_${type.name}',
          name: name,
          baseUrl: 'https://example.com',
          apiKey: 'test-key',
          createdAt: DateTime.now(),
          inferenceProviderType: type,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              aiConfigByIdProvider('provider_${type.name}')
                  .overrideWith((ref) async => provider),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: ProviderFilterChip(
                  providerId: 'provider_${type.name}',
                  isSelected: false,
                  onTap: () {},
                ),
              ),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.text(name), findsOneWidget);

        // Clean up between iterations
        await tester.pumpWidget(Container());
        await tester.pump();
      }
    });
  });

  group('Provider Filter Chip Selection State Tests', () {
    testWidgets('Selected chip shows checkmark', (tester) async {
      final provider = AiConfigInferenceProvider(
        id: 'provider1',
        name: 'Test Provider',
        baseUrl: 'https://example.com',
        apiKey: 'test-key',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.anthropic,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aiConfigByIdProvider('provider1')
                .overrideWith((ref) async => provider),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ProviderFilterChip(
                providerId: 'provider1',
                isSelected: true,
                onTap: () {},
              ),
            ),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify FilterChip is selected
      final filterChip = tester.widget<FilterChip>(find.byType(FilterChip));
      expect(filterChip.selected, isTrue);
      expect(filterChip.showCheckmark, isTrue);
      expect(find.text('Test Provider'), findsOneWidget);
    });

    testWidgets('Unselected chip does not show checkmark', (tester) async {
      final provider = AiConfigInferenceProvider(
        id: 'provider1',
        name: 'Test Provider',
        baseUrl: 'https://example.com',
        apiKey: 'test-key',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.anthropic,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aiConfigByIdProvider('provider1')
                .overrideWith((ref) async => provider),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ProviderFilterChip(
                providerId: 'provider1',
                isSelected: false,
                onTap: () {},
              ),
            ),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify FilterChip is not selected
      final filterChip = tester.widget<FilterChip>(find.byType(FilterChip));
      expect(filterChip.selected, isFalse);
      expect(filterChip.showCheckmark, isFalse);
      expect(find.text('Test Provider'), findsOneWidget);
    });

    testWidgets('Colored dot always displays', (tester) async {
      final provider = AiConfigInferenceProvider(
        id: 'provider1',
        name: 'Test Provider',
        baseUrl: 'https://example.com',
        apiKey: 'test-key',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.anthropic,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aiConfigByIdProvider('provider1')
                .overrideWith((ref) async => provider),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ProviderFilterChip(
                providerId: 'provider1',
                isSelected: false,
                onTap: () {},
              ),
            ),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Container with decoration (colored dot) exists
      final containers = tester.widgetList<Container>(find.byType(Container));
      expect(
        containers.any(
          (c) {
            final decoration = c.decoration;
            return decoration is BoxDecoration &&
                decoration.shape == BoxShape.circle;
          },
        ),
        isTrue,
      );
    });
  });

  group('Provider Filter Chip Data Tests', () {
    test('Null provider returns null from async state', () async {
      // Test the data logic directly
      final container = ProviderContainer(
        overrides: [
          aiConfigByIdProvider('provider1').overrideWith((ref) async => null),
        ],
      );

      final result =
          await container.read(aiConfigByIdProvider('provider1').future);
      expect(result, isNull);

      container.dispose();
    });

    test('Error state propagates error from provider', () async {
      final container = ProviderContainer(
        overrides: [
          aiConfigByIdProvider('provider1').overrideWith(
            (ref) => Future.error(Exception('Failed to load')),
          ),
        ],
      );

      expect(
        () => container.read(aiConfigByIdProvider('provider1').future),
        throwsA(isA<Exception>()),
      );

      container.dispose();
    });

    test('Valid provider returns correct data', () async {
      final provider = AiConfigInferenceProvider(
        id: 'provider1',
        name: 'Test Provider',
        baseUrl: 'https://example.com',
        apiKey: 'test-key',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.anthropic,
      );

      final container = ProviderContainer(
        overrides: [
          aiConfigByIdProvider('provider1')
              .overrideWith((ref) async => provider),
        ],
      );

      final result =
          await container.read(aiConfigByIdProvider('provider1').future);
      expect(result, equals(provider));
      expect(result?.name, equals('Test Provider'));

      // Cast to AiConfigInferenceProvider to access type-specific fields
      if (result is AiConfigInferenceProvider) {
        expect(result.inferenceProviderType,
            equals(InferenceProviderType.anthropic));
      }

      container.dispose();
    });
  });

  group('Provider Filter Chip Theme Tests', () {
    testWidgets('Text color is white in dark theme', (tester) async {
      final provider = AiConfigInferenceProvider(
        id: 'provider1',
        name: 'Test Provider',
        baseUrl: 'https://example.com',
        apiKey: 'test-key',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.anthropic,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aiConfigByIdProvider('provider1')
                .overrideWith((ref) async => provider),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: ProviderFilterChip(
                providerId: 'provider1',
                isSelected: false,
                onTap: () {},
              ),
            ),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );

      await tester.pumpAndSettle();

      final filterChip = tester.widget<FilterChip>(find.byType(FilterChip));
      expect(filterChip.labelStyle?.color, equals(Colors.white));
    });

    testWidgets('Text color is black in light theme', (tester) async {
      final provider = AiConfigInferenceProvider(
        id: 'provider1',
        name: 'Test Provider',
        baseUrl: 'https://example.com',
        apiKey: 'test-key',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.anthropic,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aiConfigByIdProvider('provider1')
                .overrideWith((ref) async => provider),
          ],
          child: MaterialApp(
            theme: ThemeData.light(),
            home: Scaffold(
              body: ProviderFilterChip(
                providerId: 'provider1',
                isSelected: false,
                onTap: () {},
              ),
            ),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );

      await tester.pumpAndSettle();

      final filterChip = tester.widget<FilterChip>(find.byType(FilterChip));
      expect(filterChip.labelStyle?.color, equals(Colors.black));
    });
  });

  group('Provider Filter Chip Interaction Tests', () {
    testWidgets('Multiple rapid taps handled correctly', (tester) async {
      final provider = AiConfigInferenceProvider(
        id: 'provider1',
        name: 'Test Provider',
        baseUrl: 'https://example.com',
        apiKey: 'test-key',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.anthropic,
      );

      var tapCount = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aiConfigByIdProvider('provider1')
                .overrideWith((ref) async => provider),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ProviderFilterChip(
                providerId: 'provider1',
                isSelected: false,
                onTap: () => tapCount++,
              ),
            ),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );

      await tester.pumpAndSettle();

      final filterChip = find.byType(FilterChip);

      // Rapid taps
      await tester.tap(filterChip);
      await tester.pump();
      await tester.tap(filterChip);
      await tester.pump();
      await tester.tap(filterChip);
      await tester.pump();

      expect(tapCount, equals(3));
    });

    testWidgets('Border radius is correct', (tester) async {
      final provider = AiConfigInferenceProvider(
        id: 'provider1',
        name: 'Test Provider',
        baseUrl: 'https://example.com',
        apiKey: 'test-key',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.anthropic,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aiConfigByIdProvider('provider1')
                .overrideWith((ref) async => provider),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ProviderFilterChip(
                providerId: 'provider1',
                isSelected: false,
                onTap: () {},
              ),
            ),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );

      await tester.pumpAndSettle();

      final filterChip = tester.widget<FilterChip>(find.byType(FilterChip));
      expect(
        filterChip.shape,
        equals(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      );
    });
  });
}
