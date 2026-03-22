import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/widgets/ftue_setup_dialog.dart';

void main() {
  group('FtueSetupDialog', () {
    testWidgets('displays correct title and provider name', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FtueSetupDialog(config: FtueSetupConfig.gemini),
          ),
        ),
      );

      expect(find.text('Set Up AI Features?'), findsOneWidget);
      expect(find.text('Get started quickly with Gemini'), findsOneWidget);
    });

    testWidgets('shows preview of what will be created', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FtueSetupDialog(config: FtueSetupConfig.gemini),
          ),
        ),
      );

      expect(find.text('What will be created:'), findsOneWidget);
      expect(find.text('3 Models'), findsOneWidget);
      expect(find.text('1 Category'), findsOneWidget);
    });

    testWidgets('shows model descriptions', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FtueSetupDialog(config: FtueSetupConfig.gemini),
          ),
        ),
      );

      expect(
        find.text('Flash, Pro, and Nano Banana Pro (image)'),
        findsOneWidget,
      );
      expect(find.text('Test Category Gemini Enabled'), findsOneWidget);
    });

    testWidgets('Set Up button returns true', (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await FtueSetupDialog.show(
                  context,
                  providerName: 'Gemini',
                );
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Set Up AI Features?'), findsOneWidget);

      await tester.tap(find.text('Set Up'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });

    testWidgets('No Thanks button returns false', (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await FtueSetupDialog.show(
                  context,
                  providerName: 'Gemini',
                );
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Set Up AI Features?'), findsOneWidget);

      await tester.tap(find.text('No Thanks'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });
  });

  group('FtueSetupDialog - OpenAI', () {
    testWidgets('displays correct title and provider name for OpenAI', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FtueSetupDialog(config: FtueSetupConfig.openAi),
          ),
        ),
      );

      expect(find.text('Set Up AI Features?'), findsOneWidget);
      expect(find.text('Get started quickly with OpenAI'), findsOneWidget);
    });

    testWidgets('shows OpenAI-specific preview of what will be created', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FtueSetupDialog(config: FtueSetupConfig.openAi),
          ),
        ),
      );

      expect(find.text('What will be created:'), findsOneWidget);
      expect(find.text('4 Models'), findsOneWidget);
      expect(find.text('1 Category'), findsOneWidget);
    });

    testWidgets('shows OpenAI model descriptions', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FtueSetupDialog(config: FtueSetupConfig.openAi),
          ),
        ),
      );

      expect(
        find.text('GPT-5.2 (reasoning), GPT-5 Nano (fast), Audio, and Image'),
        findsOneWidget,
      );
      expect(find.text('Test Category OpenAI Enabled'), findsOneWidget);
    });

    testWidgets('Set Up button returns true for OpenAI', (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await FtueSetupDialog.show(
                  context,
                  providerName: 'OpenAI',
                );
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Get started quickly with OpenAI'), findsOneWidget);

      await tester.tap(find.text('Set Up'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });
  });

  group('FtueSetupDialog - Mistral', () {
    testWidgets('displays correct title and provider name for Mistral', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FtueSetupDialog(config: FtueSetupConfig.mistral),
          ),
        ),
      );

      expect(find.text('Set Up AI Features?'), findsOneWidget);
      expect(find.text('Get started quickly with Mistral'), findsOneWidget);
    });

    testWidgets('shows Mistral-specific preview of what will be created', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FtueSetupDialog(config: FtueSetupConfig.mistral),
          ),
        ),
      );

      expect(find.text('What will be created:'), findsOneWidget);
      expect(find.text('3 Models'), findsOneWidget);
      expect(find.text('1 Category'), findsOneWidget);
    });

    testWidgets('shows Mistral model descriptions', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FtueSetupDialog(config: FtueSetupConfig.mistral),
          ),
        ),
      );

      expect(
        find.text(
          'Magistral Medium (reasoning), Mistral Small (fast), '
          'Voxtral Mini (audio)',
        ),
        findsOneWidget,
      );
      expect(find.text('Test Category Mistral Enabled'), findsOneWidget);
    });

    testWidgets('Set Up button returns true for Mistral', (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await FtueSetupDialog.show(
                  context,
                  providerName: 'Mistral',
                );
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Get started quickly with Mistral'), findsOneWidget);

      await tester.tap(find.text('Set Up'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });
  });

  group('FtueSetupDialog - Alibaba', () {
    testWidgets('displays correct title and provider name for Alibaba', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FtueSetupDialog(config: FtueSetupConfig.alibaba),
          ),
        ),
      );

      expect(find.text('Set Up AI Features?'), findsOneWidget);
      expect(
        find.text('Get started quickly with Alibaba Cloud (Qwen)'),
        findsOneWidget,
      );
    });

    testWidgets('shows Alibaba-specific preview of what will be created', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FtueSetupDialog(config: FtueSetupConfig.alibaba),
          ),
        ),
      );

      expect(find.text('What will be created:'), findsOneWidget);
      expect(find.text('5 Models'), findsOneWidget);
      expect(find.text('1 Category'), findsOneWidget);
    });

    testWidgets('shows Alibaba model descriptions', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FtueSetupDialog(config: FtueSetupConfig.alibaba),
          ),
        ),
      );

      expect(
        find.text(
          'Qwen 3.5 Plus (reasoning), Qwen Flash, VL Flash (vision), '
          'Omni Flash (audio), Wan 2.6 (image)',
        ),
        findsOneWidget,
      );
      expect(find.text('Test Category Alibaba Enabled'), findsOneWidget);
    });

    testWidgets('Set Up button returns true for Alibaba', (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await FtueSetupDialog.show(
                  context,
                  providerName: 'Alibaba Cloud (Qwen)',
                );
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(
        find.text('Get started quickly with Alibaba Cloud (Qwen)'),
        findsOneWidget,
      );

      await tester.tap(find.text('Set Up'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });
  });

  group('FtueSetupConfig.forProviderType', () {
    test('returns alibaba for Alibaba type', () {
      final config = FtueSetupConfig.forProviderType(
        InferenceProviderType.alibaba,
      );
      expect(config.providerName, 'Alibaba Cloud (Qwen)');
      expect(config.modelCount, 5);
    });

    test('returns gemini for Gemini type', () {
      final config = FtueSetupConfig.forProviderType(
        InferenceProviderType.gemini,
      );
      expect(config.providerName, 'Gemini');
      expect(config.modelCount, 3);
    });

    test('returns openAi for OpenAI type', () {
      final config = FtueSetupConfig.forProviderType(
        InferenceProviderType.openAi,
      );
      expect(config.providerName, 'OpenAI');
      expect(config.modelCount, 4);
    });

    test('returns mistral for Mistral type', () {
      final config = FtueSetupConfig.forProviderType(
        InferenceProviderType.mistral,
      );
      expect(config.providerName, 'Mistral');
      expect(config.modelCount, 3);
    });
  });
}
