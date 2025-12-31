import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai_chat/ui/providers/chat_model_providers.dart';
import 'package:lotti/features/ai_chat/ui/widgets/chat_interface/assistant_settings_sheet.dart';
import 'package:lotti/features/ai_chat/ui/widgets/chat_interface/chat_header.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';

void main() {
  testWidgets('ChatHeader displays title + sessionTitle and opens settings',
      (tester) async {
    // Minimal logging service stub so ChatSessionController can construct
    if (!getIt.isRegistered<LoggingService>()) {
      getIt.registerSingleton<LoggingService>(LoggingService());
    }

    // Mock models to avoid overflow from too many items
    final testModel = AiConfigModel(
      id: 'test-model',
      name: 'Test Model',
      providerModelId: 'test-model-id',
      inferenceProviderId: 'test-provider',
      inputModalities: const [Modality.text],
      outputModalities: const [Modality.text],
      isReasoningModel: false,
      supportsFunctionCalling: true,
      createdAt: DateTime(2025),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          eligibleChatModelsForCategoryProvider('cat')
              .overrideWith((ref) async => [testModel]),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ChatHeader(
              sessionTitle: 'My Session',
              canClearChat: false,
              onClearChat: () {},
              onNewSession: () {},
              categoryId: 'cat',
              selectedModelId: null,
              isStreaming: false,
              onSelectModel: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('AI Assistant'), findsOneWidget);
    expect(find.text('My Session'), findsOneWidget);

    // Open Assistant Settings via tune icon
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    expect(find.byType(AssistantSettingsSheet), findsOneWidget);
  });
}
