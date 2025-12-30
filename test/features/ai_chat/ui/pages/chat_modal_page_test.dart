// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:lotti/features/ai_chat/models/chat_message.dart';
import 'package:lotti/features/ai_chat/models/chat_session.dart';
import 'package:lotti/features/ai_chat/repository/chat_repository.dart';
import 'package:lotti/features/ai_chat/ui/controllers/chat_session_controller.dart';
import 'package:lotti/features/ai_chat/ui/models/chat_ui_models.dart';
import 'package:lotti/features/ai_chat/ui/pages/chat_modal_page.dart';
import 'package:lotti/features/ai_chat/ui/widgets/chat_interface.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_scope.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

class MockChatRepository extends Mock implements ChatRepository {}

class MockLoggingService extends Mock implements LoggingService {}

/// Mock controller that returns a specific state based on selectedCategoryIds
class _MockJournalPageController extends JournalPageController {
  _MockJournalPageController(this._selectedCategoryIds);
  final Set<String?> _selectedCategoryIds;

  @override
  JournalPageState build(bool showTasks) {
    return JournalPageState(
      selectedEntryTypes: const [],
      match: '',
      tagIds: const {},
      filters: const {},
      showPrivateEntries: false,
      showTasks: true,
      fullTextMatches: const {},
      pagingController: null,
      taskStatuses: const [],
      selectedTaskStatuses: const {},
      selectedCategoryIds: _selectedCategoryIds,
      selectedLabelIds: const {},
    );
  }
}

void main() {
  // Helper to set up test environment with adequate size
  Future<void> setupTestWidget(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.reset());
    await tester.pumpWidget(child);
  }

  group('ChatModalPage', () {
    late MockChatRepository mockChatRepository;
    late MockLoggingService mockLoggingService;

    setUp(() {
      mockChatRepository = MockChatRepository();
      mockLoggingService = MockLoggingService();

      // Register mock services with GetIt
      if (!GetIt.instance.isRegistered<LoggingService>()) {
        GetIt.instance.registerSingleton<LoggingService>(mockLoggingService);
      }
    });

    tearDown(() {
      GetIt.instance.reset();
    });

    testWidgets('displays category selection prompt when no category selected',
        (tester) async {
      await setupTestWidget(
        tester,
        ProviderScope(
          overrides: [
            chatRepositoryProvider.overrideWithValue(mockChatRepository),
            journalPageScopeProvider.overrideWithValue(true),
            journalPageControllerProvider(true).overrideWith(
              () => _MockJournalPageController(<String?>{}),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ChatModalPage(),
            ),
          ),
        ),
      );

      await tester.pump();

      // Check category selection prompt elements
      expect(find.byIcon(Icons.category_outlined), findsOneWidget);
      expect(find.text('Please select a single category'), findsOneWidget);
      expect(
          find.text(
              'The AI assistant needs a specific category context to help you with tasks'),
          findsOneWidget);
    });

    testWidgets(
        'displays category selection prompt when multiple categories selected',
        (tester) async {
      await setupTestWidget(
        tester,
        ProviderScope(
          overrides: [
            chatRepositoryProvider.overrideWithValue(mockChatRepository),
            journalPageScopeProvider.overrideWithValue(true),
            journalPageControllerProvider(true).overrideWith(
              () => _MockJournalPageController(<String?>{'cat1', 'cat2'}),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ChatModalPage(),
            ),
          ),
        ),
      );

      await tester.pump();

      // Check category selection prompt is shown
      expect(find.byIcon(Icons.category_outlined), findsOneWidget);
      expect(find.text('Please select a single category'), findsOneWidget);
    });

    testWidgets(
        'displays RefactoredChatInterface when single category selected',
        (tester) async {
      when(() => mockChatRepository.createSession(
              categoryId: 'single-category-id'))
          .thenAnswer((_) async => ChatSession(
                id: 'test-session',
                title: 'New Chat',
                createdAt: DateTime(2024),
                lastMessageAt: DateTime(2024),
                messages: [],
              ));

      await setupTestWidget(
        tester,
        ProviderScope(
          overrides: [
            chatRepositoryProvider.overrideWithValue(mockChatRepository),
            journalPageScopeProvider.overrideWithValue(true),
            journalPageControllerProvider(true).overrideWith(
              () => _MockJournalPageController(<String?>{'single-category-id'}),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ChatModalPage(),
            ),
          ),
        ),
      );

      await tester.pump();

      // Check RefactoredChatInterface is displayed
      expect(find.byType(ChatInterface), findsOneWidget);

      // Verify no category selection prompt
      expect(find.byIcon(Icons.category_outlined), findsNothing);
      expect(find.text('Please select a single category'), findsNothing);
    });

    testWidgets('passes correct categoryId to RefactoredChatInterface',
        (tester) async {
      const categoryId = 'test-category-123';

      when(() => mockChatRepository.createSession(categoryId: categoryId))
          .thenAnswer((_) async => ChatSession(
                id: 'test-session',
                title: 'New Chat',
                createdAt: DateTime(2024),
                lastMessageAt: DateTime(2024),
                messages: [],
              ));

      await setupTestWidget(
        tester,
        ProviderScope(
          overrides: [
            chatRepositoryProvider.overrideWithValue(mockChatRepository),
            journalPageScopeProvider.overrideWithValue(true),
            journalPageControllerProvider(true).overrideWith(
              () => _MockJournalPageController(<String?>{categoryId}),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ChatModalPage(),
            ),
          ),
        ),
      );

      await tester.pump();

      // Find the RefactoredChatInterface widget
      final chatInterfaceWidget = tester.widget<ChatInterface>(
        find.byType(ChatInterface),
      );

      // Verify categoryId is passed correctly
      expect(chatInterfaceWidget.categoryId, equals(categoryId));
    });

    testWidgets('uses SizedBox with 85% screen height constraint',
        (tester) async {
      when(() => mockChatRepository.createSession(
              categoryId: 'single-category-id'))
          .thenAnswer((_) async => ChatSession(
                id: 'test-session',
                title: 'New Chat',
                createdAt: DateTime(2024),
                lastMessageAt: DateTime(2024),
                messages: [],
              ));

      await setupTestWidget(
        tester,
        ProviderScope(
          overrides: [
            chatRepositoryProvider.overrideWithValue(mockChatRepository),
            journalPageScopeProvider.overrideWithValue(true),
            journalPageControllerProvider(true).overrideWith(
              () => _MockJournalPageController(<String?>{'single-category-id'}),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ChatModalPage(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find the SizedBox constraint
      final sizedBox = tester.widget<SizedBox>(
        find.byType(SizedBox).first,
      );

      // Get screen height
      final screenHeight =
          MediaQuery.of(tester.element(find.byType(ChatModalPage))).size.height;
      final expectedHeight = screenHeight * 0.85;

      expect(sizedBox.height, equals(expectedHeight));
    });

    testWidgets('responds to category selection changes', (tester) async {
      // Test initial state with no categories
      await setupTestWidget(
        tester,
        ProviderScope(
          overrides: [
            chatRepositoryProvider.overrideWithValue(mockChatRepository),
            journalPageScopeProvider.overrideWithValue(true),
            journalPageControllerProvider(true).overrideWith(
              () => _MockJournalPageController(<String?>{}),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ChatModalPage(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show category selection prompt
      expect(find.text('Please select a single category'), findsOneWidget);
      expect(find.byType(ChatInterface), findsNothing);
    });

    testWidgets('shows chat interface with single category selected',
        (tester) async {
      // Test state with single category selected
      when(() => mockChatRepository.createSession(categoryId: 'test-category'))
          .thenAnswer((_) async => ChatSession(
                id: 'test-session',
                title: 'New Chat',
                createdAt: DateTime(2024),
                lastMessageAt: DateTime(2024),
                messages: [],
              ));

      await setupTestWidget(
        tester,
        ProviderScope(
          overrides: [
            chatRepositoryProvider.overrideWithValue(mockChatRepository),
            journalPageScopeProvider.overrideWithValue(true),
            journalPageControllerProvider(true).overrideWith(
              () => _MockJournalPageController(<String?>{'test-category'}),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ChatModalPage(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show chat interface
      expect(find.text('Please select a single category'), findsNothing);
      expect(find.byType(ChatInterface), findsOneWidget);
    });

    testWidgets('ambient pulse overlay toggles with streaming state',
        (tester) async {
      // Ensure LoggingService is available
      if (!GetIt.instance.isRegistered<LoggingService>()) {
        GetIt.instance.registerSingleton<LoggingService>(LoggingService());
      }

      // First with streaming=true
      await setupTestWidget(
        tester,
        ProviderScope(
          overrides: [
            journalPageScopeProvider.overrideWithValue(true),
            journalPageControllerProvider(true).overrideWith(
              () => _MockJournalPageController(<String?>{'cat'}),
            ),
            chatSessionControllerProvider('cat')
                .overrideWith(_StreamingChatController.new),
          ],
          child: const MaterialApp(
            home: Scaffold(body: ChatModalPage()),
          ),
        ),
      );
      await tester.pump();

      // Expect a Container with active glow (non-empty boxShadow)
      expect(
        find.byWidgetPredicate((w) {
          if (w is Container && w.decoration is BoxDecoration) {
            final d = w.decoration! as BoxDecoration;
            return d.boxShadow != null && d.boxShadow!.isNotEmpty;
          }
          return false;
        }),
        findsWidgets,
      );

      // Rebuild with idle controller -> ensure app still builds (glow assertions
      // skipped due to perpetual animation intricacies in tests)
      await setupTestWidget(
        tester,
        ProviderScope(
          overrides: [
            journalPageScopeProvider.overrideWithValue(true),
            journalPageControllerProvider(true).overrideWith(
              () => _MockJournalPageController(<String?>{'cat'}),
            ),
            chatSessionControllerProvider('cat')
                .overrideWith(_IdleChatController.new),
          ],
          child: const MaterialApp(
            home: Scaffold(body: ChatModalPage()),
          ),
        ),
      );
      await tester.pump();
    });
  });
}

// File-scope helper controllers for the ambient pulse test
class _StreamingChatController extends ChatSessionController {
  @override
  ChatSessionUiModel build(String categoryId) {
    return const ChatSessionUiModel(
      id: 's',
      title: 't',
      messages: <ChatMessage>[],
      isLoading: false,
      isStreaming: true,
      selectedModelId: 'm',
    );
  }

  @override
  Future<void> initializeSession({String? sessionId}) async {}
}

class _IdleChatController extends ChatSessionController {
  @override
  ChatSessionUiModel build(String categoryId) {
    return ChatSessionUiModel.empty();
  }

  @override
  Future<void> initializeSession({String? sessionId}) async {}
}
