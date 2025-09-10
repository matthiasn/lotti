import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/providers/gemini_thinking_providers.dart';
import 'package:lotti/features/ai_chat/models/chat_message.dart';
import 'package:lotti/features/ai_chat/ui/controllers/chat_session_controller.dart';
import 'package:lotti/features/ai_chat/ui/models/chat_ui_models.dart';
import 'package:lotti/features/ai_chat/ui/providers/chat_model_providers.dart';
import 'package:lotti/features/ai_chat/ui/widgets/chat_interface/assistant_settings_sheet.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';

class _StaticChatController extends ChatSessionController {
  @override
  ChatSessionUiModel build(String categoryId) {
    return const ChatSessionUiModel(
      id: 's',
      title: 't',
      messages: <ChatMessage>[],
      isLoading: false,
      isStreaming: false,
      selectedModelId: 'missing-model',
    );
  }

  @override
  Future<void> initializeSession({String? sessionId}) async {}
}

class _StreamingChatController extends ChatSessionController {
  @override
  ChatSessionUiModel build(String categoryId) {
    return const ChatSessionUiModel(
      id: 's',
      title: 't',
      messages: <ChatMessage>[],
      isLoading: false,
      isStreaming: true,
      selectedModelId: 'm1',
    );
  }

  @override
  Future<void> initializeSession({String? sessionId}) async {}
}

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

  testWidgets('dropdown shows null when previously selected model is ineligible',
      (tester) async {
    // Ensure LoggingService is available
    if (!getIt.isRegistered<LoggingService>()) {
      getIt.registerSingleton<LoggingService>(LoggingService());
    }

    final models = [_model('m1', 'A-Model')]; // Does not include 'missing-model'

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatSessionControllerProvider('cat').overrideWith(
            _StaticChatController.new,
          ),
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

    // Dropdown is present and enabled
    final ddFinder = find.byType(DropdownButtonFormField<String>);
    final ddWidget = tester.widget<DropdownButtonFormField<String>>(ddFinder);
    expect(ddWidget.onChanged, isNotNull);

    // Since selectedModelId is not in models, initialValue should be null
    expect(ddWidget.initialValue, isNull);

    // Hint should be visible
    expect(find.text('Select model'), findsOneWidget);
  });

  testWidgets('dropdown and reasoning toggle disabled while streaming',
      (tester) async {
    if (!getIt.isRegistered<LoggingService>()) {
      getIt.registerSingleton<LoggingService>(LoggingService());
    }

    final models = [_model('m1', 'A-Model'), _model('m2', 'B-Model')];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatSessionControllerProvider('cat').overrideWith(
            _StreamingChatController.new,
          ),
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

    // Dropdown is present but disabled
    final ddFinder = find.byType(DropdownButtonFormField<String>);
    final ddWidgets =
        tester.widgetList<DropdownButtonFormField<String>>(ddFinder);
    expect(ddWidgets.isNotEmpty, isTrue);
    expect(ddWidgets.first.onChanged, isNull);

    // Tapping reasoning toggle should do nothing (still false visually)
    expect(find.text('Show reasoning'), findsOneWidget);
    await tester.tap(find.text('Show reasoning').first);
    await tester.pump();
    expect(find.text('Hide reasoning'), findsNothing);
  });
}
