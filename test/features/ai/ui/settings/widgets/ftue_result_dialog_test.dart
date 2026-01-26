import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/ui/settings/services/provider_prompt_setup_service.dart';
import 'package:lotti/features/ai/ui/settings/widgets/ftue_result_dialog.dart';

void main() {
  group('FtueResultDialog', () {
    testWidgets('displays success state when no errors', (tester) async {
      const result = FtueResultData(
        modelsCreated: 3,
        modelsVerified: 0,
        promptsCreated: 18,
        promptsSkipped: 0,
        categoryCreated: true,
        categoryUpdated: false,
        categoryName: 'Test Category Gemini Enabled',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FtueResultDialog(result: result),
          ),
        ),
      );

      expect(find.text('Setup Complete'), findsOneWidget);
      expect(find.text('3 created'), findsOneWidget);
      expect(find.text('18 created'), findsOneWidget);
      expect(
        find.text('Test Category Gemini Enabled (created)'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('displays warning state when errors present', (tester) async {
      const result = FtueResultData(
        modelsCreated: 2,
        modelsVerified: 1,
        promptsCreated: 15,
        promptsSkipped: 3,
        categoryCreated: true,
        categoryUpdated: false,
        categoryName: 'Test Category',
        errors: ['Failed to create prompt: Audio Transcription'],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FtueResultDialog(result: result),
          ),
        ),
      );

      expect(find.text('Setup Completed with Warnings'), findsOneWidget);
      expect(find.text('2 created, 1 verified'), findsOneWidget);
      expect(find.text('15 created, 3 skipped'), findsOneWidget);
      expect(find.text('Warnings:'), findsOneWidget);
      expect(
        find.text('Failed to create prompt: Audio Transcription'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.warning), findsOneWidget);
    });

    testWidgets('shows None when no models created or verified',
        (tester) async {
      const result = FtueResultData(
        modelsCreated: 0,
        modelsVerified: 0,
        promptsCreated: 18,
        promptsSkipped: 0,
        categoryCreated: true,
        categoryUpdated: false,
        categoryName: 'Test Category',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FtueResultDialog(result: result),
          ),
        ),
      );

      // Models should show "None"
      expect(find.text('None'), findsOneWidget);
    });

    testWidgets('shows category as updated when categoryUpdated is true',
        (tester) async {
      const result = FtueResultData(
        modelsCreated: 0,
        modelsVerified: 3,
        promptsCreated: 0,
        promptsSkipped: 18,
        categoryCreated: false,
        categoryUpdated: true,
        categoryName: 'Test Category',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FtueResultDialog(result: result),
          ),
        ),
      );

      expect(find.text('Test Category (updated)'), findsOneWidget);
      expect(find.byIcon(Icons.folder_outlined), findsOneWidget);
    });

    testWidgets('does not show category section when not created',
        (tester) async {
      const result = FtueResultData(
        modelsCreated: 3,
        modelsVerified: 0,
        promptsCreated: 18,
        promptsSkipped: 0,
        categoryCreated: false,
        categoryUpdated: false,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FtueResultDialog(result: result),
          ),
        ),
      );

      expect(find.byIcon(Icons.folder_outlined), findsNothing);
    });

    testWidgets('Done button closes dialog', (tester) async {
      const result = GeminiFtueResult(
        modelsCreated: 3,
        modelsVerified: 0,
        promptsCreated: 18,
        promptsSkipped: 0,
        categoryCreated: true,
        categoryName: 'Test Category',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                await FtueResultDialog.show(context, result: result);
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Setup Complete'), findsOneWidget);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.text('Setup Complete'), findsNothing);
    });

    testWidgets('showMistral displays Mistral results correctly',
        (tester) async {
      const result = MistralFtueResult(
        modelsCreated: 3,
        modelsVerified: 0,
        promptsCreated: 8,
        promptsSkipped: 0,
        categoryCreated: true,
        categoryName: 'Test Category Mistral Enabled',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                await FtueResultDialog.showMistral(context, result: result);
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Setup Complete'), findsOneWidget);
      expect(find.text('3 created'), findsOneWidget);
      expect(find.text('8 created'), findsOneWidget);
      expect(
        find.text('Test Category Mistral Enabled (created)'),
        findsOneWidget,
      );
    });
  });

  group('FtueResultData - Mistral', () {
    test('fromMistral creates correct data from MistralFtueResult', () {
      const result = MistralFtueResult(
        modelsCreated: 3,
        modelsVerified: 0,
        promptsCreated: 8,
        promptsSkipped: 0,
        categoryCreated: true,
        categoryName: 'Test Category Mistral Enabled',
        errors: ['Test error'],
      );

      final data = FtueResultData.fromMistral(result);

      expect(data.modelsCreated, equals(3));
      expect(data.modelsVerified, equals(0));
      expect(data.promptsCreated, equals(8));
      expect(data.promptsSkipped, equals(0));
      expect(data.categoryCreated, isTrue);
      expect(data.categoryUpdated, isFalse);
      expect(data.categoryName, equals('Test Category Mistral Enabled'));
      expect(data.errors, contains('Test error'));
    });
  });
}
