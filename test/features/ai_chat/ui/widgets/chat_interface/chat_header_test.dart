import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai_chat/ui/providers/chat_model_providers.dart';
import 'package:lotti/features/ai_chat/ui/widgets/chat_interface/assistant_settings_sheet.dart';
import 'package:lotti/features/ai_chat/ui/widgets/chat_interface/chat_header.dart';

import '../../../../../widget_test_utils.dart';

void main() {
  testWidgets('ChatHeader displays title + sessionTitle and opens settings', (
    tester,
  ) async {
    // Minimal logging service stub so ChatSessionController can construct
    ensureDomainLoggerRegistered();

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
          eligibleChatModelsForCategoryProvider(
            'cat',
          ).overrideWith((ref) async => [testModel]),
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

  Future<void> pumpHeader(
    WidgetTester tester, {
    bool canClearChat = false,
    VoidCallback? onClearChat,
    VoidCallback? onNewSession,
  }) async {
    ensureDomainLoggerRegistered();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          eligibleChatModelsForCategoryProvider(
            'cat',
          ).overrideWith((ref) async => const []),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ChatHeader(
              sessionTitle: 'My Session',
              canClearChat: canClearChat,
              onClearChat: onClearChat ?? () {},
              onNewSession: onNewSession ?? () {},
              categoryId: 'cat',
              selectedModelId: null,
              isStreaming: false,
              onSelectModel: (_) {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('clear button only renders when canClearChat and invokes '
      'onClearChat', (tester) async {
    await pumpHeader(tester);
    expect(find.byIcon(Icons.clear_all), findsNothing);

    var cleared = 0;
    await pumpHeader(
      tester,
      canClearChat: true,
      onClearChat: () => cleared++,
    );
    expect(find.byIcon(Icons.clear_all), findsOneWidget);

    await tester.tap(find.byIcon(Icons.clear_all));
    await tester.pump();
    expect(cleared, 1);
  });

  testWidgets('new-chat button invokes onNewSession', (tester) async {
    var newSessions = 0;
    await pumpHeader(tester, onNewSession: () => newSessions++);

    await tester.tap(find.byIcon(Icons.add_comment_outlined));
    await tester.pump();
    expect(newSessions, 1);
  });
}
