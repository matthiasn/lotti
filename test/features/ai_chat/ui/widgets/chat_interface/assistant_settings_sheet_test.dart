import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/providers/gemini_thinking_providers.dart';
import 'package:lotti/features/ai_chat/ui/providers/chat_model_providers.dart';
import 'package:lotti/features/ai_chat/ui/widgets/chat_interface/assistant_settings_sheet.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';

AiConfigModel _model(String id, String name) => AiConfigModel(
      id: id,
      name: name,
      providerModelId: name,
      inferenceProviderId: 'prov',
      createdAt: DateTime(2024),
      inputModalities: const [Modality.text],
      outputModalities: const [Modality.text],
      isReasoningModel: false,
      supportsFunctionCalling: true,
    );

void main() {
  testWidgets('AssistantSettingsSheet lists models and toggles reasoning',
      (tester) async {
    if (!getIt.isRegistered<LoggingService>()) {
      getIt.registerSingleton<LoggingService>(LoggingService());
    }
    final models = [_model('m1', 'A-Model'), _model('m2', 'B-Model')];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          eligibleChatModelsForCategoryProvider('cat').overrideWith(
            (ref) async => models,
          ),
          geminiIncludeThoughtsProvider.overrideWith((ref) => false),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: AssistantSettingsSheet(categoryId: 'cat'),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // The sheet renders header and the reasoning toggle
    expect(find.text('Assistant Settings'), findsOneWidget);
    expect(find.text('Show reasoning'), findsOneWidget);
  });
}
