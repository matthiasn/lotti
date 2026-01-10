import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/ui/settings/services/provider_prompt_setup_service.dart';
import 'package:lotti/features/ai/ui/settings/widgets/ftue_result_dialog.dart';

void main() {
  group('FtueResultDialog', () {
    testWidgets('displays success state when no errors', (tester) async {
      const result = GeminiFtueResult(
        modelsCreated: 3,
        modelsVerified: 0,
        promptsCreated: 18,
        promptsSkipped: 0,
        categoryCreated: true,
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
      const result = GeminiFtueResult(
        modelsCreated: 2,
        modelsVerified: 1,
        promptsCreated: 15,
        promptsSkipped: 3,
        categoryCreated: true,
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
      const result = GeminiFtueResult(
        modelsCreated: 0,
        modelsVerified: 0,
        promptsCreated: 18,
        promptsSkipped: 0,
        categoryCreated: true,
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
      const result = GeminiFtueResult(
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
      const result = GeminiFtueResult(
        modelsCreated: 3,
        modelsVerified: 0,
        promptsCreated: 18,
        promptsSkipped: 0,
        categoryCreated: false,
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
  });
}
