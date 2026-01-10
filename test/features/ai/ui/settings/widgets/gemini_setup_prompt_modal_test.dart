import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/ui/settings/widgets/gemini_setup_prompt_modal.dart';

void main() {
  group('GeminiSetupPromptModal', () {
    testWidgets('displays correct title and content', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GeminiSetupPromptModal(
              onSetUp: () {},
              onDismiss: () {},
            ),
          ),
        ),
      );

      expect(find.text('Set Up AI Features?'), findsOneWidget);
      expect(find.text('Would you like to set up Gemini AI?'), findsOneWidget);
      expect(
        find.text('You can always set this up later in Settings.'),
        findsOneWidget,
      );
    });

    testWidgets('shows feature list', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GeminiSetupPromptModal(
              onSetUp: () {},
              onDismiss: () {},
            ),
          ),
        ),
      );

      expect(find.text('Audio transcription'), findsOneWidget);
      expect(find.text('Image analysis'), findsOneWidget);
      expect(find.text('Smart checklists'), findsOneWidget);
      expect(find.text('Task summaries'), findsOneWidget);
    });

    testWidgets('Set Up Gemini button calls onSetUp', (tester) async {
      var setUpCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GeminiSetupPromptModal(
              onSetUp: () => setUpCalled = true,
              onDismiss: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.text('Set Up Gemini'));
      await tester.pumpAndSettle();

      expect(setUpCalled, isTrue);
    });

    testWidgets('Not Now button calls onDismiss', (tester) async {
      var dismissCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GeminiSetupPromptModal(
              onSetUp: () {},
              onDismiss: () => dismissCalled = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Not Now'));
      await tester.pumpAndSettle();

      expect(dismissCalled, isTrue);
    });

    testWidgets('static show method displays modal', (tester) async {
      var setUpCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                GeminiSetupPromptModal.show(
                  context,
                  onSetUp: () => setUpCalled = true,
                  onDismiss: () {},
                );
              },
              child: const Text('Open Modal'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      expect(find.text('Set Up AI Features?'), findsOneWidget);

      await tester.tap(find.text('Set Up Gemini'));
      await tester.pumpAndSettle();

      expect(setUpCalled, isTrue);
    });
  });
}
