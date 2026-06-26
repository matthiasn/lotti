import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/providers/gemini_thinking_providers.dart';
import 'package:lotti/features/ai_chat/models/chat_message.dart';
import 'package:lotti/features/ai_chat/ui/controllers/chat_session_controller.dart';
import 'package:lotti/features/ai_chat/ui/models/chat_ui_models.dart';
import 'package:lotti/features/ai_chat/ui/providers/chat_model_providers.dart';
import 'package:lotti/features/ai_chat/ui/widgets/chat_interface/assistant_settings_sheet.dart';

import '../../../../../widget_test_utils.dart';

class _StaticChatController extends ChatSessionController {
  @override
  ChatSessionUiModel build() {
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
  ChatSessionUiModel build() {
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

/// Pumps the sheet wrapped in the standard testable scaffold.
///
/// [extraOverrides] lets a test swap the eligible-models provider or chat
/// controller. Returns once the eligible-models future has resolved.
Future<void> _pumpSheet(
  WidgetTester tester, {
  List<Override> extraOverrides = const [],
}) async {
  ensureDomainLoggerRegistered();
  await tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      const AssistantSettingsSheet(categoryId: 'cat'),
      overrides: extraOverrides,
    ),
  );
  await tester.pumpAndSettle();
}

/// Pumps the sheet inside a Scaffold using an explicit [container] so a test
/// can read provider state directly. The scaffold + scroll view give the sheet
/// a Material ancestor and bounded height so all controls are hittable.
Future<void> _pumpSheetWithContainer(
  WidgetTester tester,
  ProviderContainer container,
) async {
  ensureDomainLoggerRegistered();
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: resolveTestTheme(),
        home: const Scaffold(
          body: SingleChildScrollView(
            child: AssistantSettingsSheet(categoryId: 'cat'),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('AssistantSettingsSheet lists models and toggles reasoning', (
    tester,
  ) async {
    final models = [_model('m1', 'A-Model'), _model('m2', 'B-Model')];

    await _pumpSheet(
      tester,
      extraOverrides: [
        eligibleChatModelsForCategoryProvider('cat').overrideWith(
          (ref) async => models,
        ),
      ],
    );

    // The sheet renders header and the reasoning toggle.
    expect(find.text('Assistant Settings'), findsOneWidget);
    expect(find.text('Show reasoning'), findsOneWidget);

    // With the default (empty) session there is no selected model, so the
    // dropdown hint is shown and the control is enabled.
    final dd = tester.widget<DropdownButtonFormField<String>>(
      find.byType(DropdownButtonFormField<String>),
    );
    expect(dd.initialValue, isNull);
    expect(dd.onChanged, isNotNull);
    expect(find.text('Select model'), findsOneWidget);

    // Opening the dropdown surfaces both eligible models as menu items.
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    expect(find.text('A-Model'), findsWidgets);
    expect(find.text('B-Model'), findsWidgets);
  });

  testWidgets('renders empty-state text when no eligible models', (
    tester,
  ) async {
    await _pumpSheet(
      tester,
      extraOverrides: [
        eligibleChatModelsForCategoryProvider('cat').overrideWith(
          (ref) async => <AiConfigModel>[],
        ),
      ],
    );

    expect(find.text('No eligible models'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
  });

  testWidgets(
    'dropdown shows null when previously selected model is ineligible',
    (tester) async {
      final models = [
        _model('m1', 'A-Model'),
      ]; // Does not include 'missing-model'

      await _pumpSheet(
        tester,
        extraOverrides: [
          chatSessionControllerProvider('cat').overrideWith(
            _StaticChatController.new,
          ),
          eligibleChatModelsForCategoryProvider('cat').overrideWith(
            (ref) async => models,
          ),
        ],
      );

      // Dropdown is present and enabled.
      final ddFinder = find.byType(DropdownButtonFormField<String>);
      final ddWidget = tester.widget<DropdownButtonFormField<String>>(ddFinder);
      expect(ddWidget.onChanged, isNotNull);

      // Since selectedModelId is not in models, initialValue should be null.
      expect(ddWidget.initialValue, isNull);

      // Hint should be visible.
      expect(find.text('Select model'), findsOneWidget);
    },
  );

  testWidgets('renders error branch when eligible-models load fails', (
    tester,
  ) async {
    await _pumpSheet(
      tester,
      extraOverrides: [
        eligibleChatModelsForCategoryProvider('cat').overrideWith(
          (ref) async => throw Exception('boom'),
        ),
      ],
    );

    // The error branch renders the headline and the formatted error string.
    expect(find.text('Failed to load models'), findsOneWidget);
    expect(find.text('Exception: boom'), findsOneWidget);
    // No dropdown is shown in the error branch.
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
  });

  testWidgets('reasoning toggle flips geminiIncludeThoughts state on tap', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        eligibleChatModelsForCategoryProvider(
          'cat',
        ).overrideWith((ref) async => <AiConfigModel>[]),
      ],
    );
    addTearDown(container.dispose);

    await _pumpSheetWithContainer(tester, container);

    // Starts disabled (provider default is false).
    expect(container.read(geminiIncludeThoughtsProvider), isFalse);

    // Tapping the toggle row invokes onChanged(!value) -> sets true.
    await tester.tap(find.text('Show reasoning'));
    await tester.pumpAndSettle();
    expect(container.read(geminiIncludeThoughtsProvider), isTrue);

    // Tapping again flips it back to false.
    await tester.tap(find.text('Show reasoning'));
    await tester.pumpAndSettle();
    expect(container.read(geminiIncludeThoughtsProvider), isFalse);
  });

  testWidgets('dropdown and reasoning toggle disabled while streaming', (
    tester,
  ) async {
    final models = [_model('m1', 'A-Model'), _model('m2', 'B-Model')];
    final container = ProviderContainer(
      overrides: [
        chatSessionControllerProvider('cat').overrideWith(
          _StreamingChatController.new,
        ),
        eligibleChatModelsForCategoryProvider('cat').overrideWith(
          (ref) async => models,
        ),
      ],
    );
    addTearDown(container.dispose);

    await _pumpSheetWithContainer(tester, container);

    // Dropdown is present but disabled.
    final ddWidget = tester.widget<DropdownButtonFormField<String>>(
      find.byType(DropdownButtonFormField<String>),
    );
    expect(ddWidget.onChanged, isNull);

    // Tapping the toggle while streaming must not change provider state.
    expect(container.read(geminiIncludeThoughtsProvider), isFalse);
    await tester.tap(find.text('Show reasoning'));
    await tester.pumpAndSettle();
    expect(container.read(geminiIncludeThoughtsProvider), isFalse);
  });

  testWidgets('close button pops the surrounding route', (tester) async {
    ensureDomainLoggerRegistered();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          eligibleChatModelsForCategoryProvider(
            'cat',
          ).overrideWith((ref) async => <AiConfigModel>[]),
        ],
        child: MaterialApp(
          theme: resolveTestTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const Scaffold(
                        body: AssistantSettingsSheet(categoryId: 'cat'),
                      ),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // Push the sheet route.
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Assistant Settings'), findsOneWidget);

    // Tapping close invokes Navigator.of(context).pop(), removing the route.
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Assistant Settings'), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });
}
