import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/ui/settings/inference_model_form.dart';
import 'package:mocktail/mocktail.dart';

class MockAiConfigRepository extends Mock implements AiConfigRepository {}

// Helper to build a testable widget
Widget buildTestWidget({
  required void Function(AiConfig) onSave,
  AiConfig? config,
}) {
  return ProviderScope(
    overrides: [
      aiConfigRepositoryProvider.overrideWithValue(MockAiConfigRepository()),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: InferenceModelForm(
          onSave: onSave,
          config: config,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('should render form fields', (WidgetTester tester) async {
    var onSaveCalled = false;

    await tester.pumpWidget(
      buildTestWidget(
        onSave: (_) {
          onSaveCalled = true;
        },
      ),
    );

    // Wait for initial load
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verify form fields are visible
    expect(find.byType(TextField), findsAtLeast(2)); // Name and description
    expect(find.byType(SwitchListTile), findsOneWidget); // Reasoning capability
    expect(find.byType(FilledButton), findsOneWidget); // Save button
    // The save button is initially disabled, so onSaveCalled would be false
    expect(onSaveCalled, isFalse);
  });
}
