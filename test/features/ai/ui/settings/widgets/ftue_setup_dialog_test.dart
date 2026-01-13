import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
      expect(find.text('9 Prompts'), findsOneWidget);
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
          find.text('Flash, Pro, and Nano Banana Pro (image)'), findsOneWidget);
      expect(
        find.text('Optimized: Pro for complex tasks, Flash for speed'),
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
    testWidgets('displays correct title and provider name for OpenAI',
        (tester) async {
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

    testWidgets('shows OpenAI-specific preview of what will be created',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FtueSetupDialog(config: FtueSetupConfig.openAi),
          ),
        ),
      );

      expect(find.text('What will be created:'), findsOneWidget);
      expect(find.text('4 Models'), findsOneWidget);
      expect(find.text('9 Prompts'), findsOneWidget);
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

      expect(find.text('o3 (reasoning), o4-mini (fast), Audio, and Image'),
          findsOneWidget);
      expect(
        find.text('Optimized: o3 for reasoning, o4-mini for speed'),
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
}
