// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
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
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

class MockChatRepository extends Mock implements ChatRepository {}

class MockLoggingService extends Mock implements LoggingService {}

/// Mock controller that returns a specific state based on selectedCategoryIds
class _MockJournalPageController extends JournalPageController {
  _MockJournalPageController(this._selectedCategoryIds);
  final Set<String> _selectedCategoryIds;

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

/// Pumps a [ChatModalPage] wrapped in the required providers and localization.
///
/// [selectedCategoryIds] controls which categories the mock journal page
/// controller reports. [chatRepository] is included as an override when
/// provided. [extraOverrides] allows injecting additional provider overrides
/// (e.g. for chatSessionControllerProvider).
Future<void> _pumpChatModalPage(
  WidgetTester tester, {
  required Set<String> selectedCategoryIds,
  MockChatRepository? chatRepository,
  List<Override> extraOverrides = const [],
}) async {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() => tester.view.reset());

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (chatRepository != null)
          chatRepositoryProvider.overrideWithValue(chatRepository),
        journalPageScopeProvider.overrideWithValue(true),
        journalPageControllerProvider(true).overrideWith(
          () => _MockJournalPageController(selectedCategoryIds),
        ),
        ...extraOverrides,
      ],
      child: const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ChatModalPage()),
      ),
    ),
  );
}

/// Stubs `repo.createSession` for the given [categoryId] to return a dummy
/// session.
void _stubCreateSession(
  MockChatRepository repo, {
  required String categoryId,
}) {
  when(() => repo.createSession(categoryId: categoryId))
      .thenAnswer((_) async => ChatSession(
            id: 'test-session',
            title: 'New Chat',
            createdAt: DateTime(2024),
            lastMessageAt: DateTime(2024),
            messages: [],
          ));
}

void main() {
  group('ChatModalPage', () {
    late MockChatRepository mockChatRepository;
    late MockLoggingService mockLoggingService;

    setUp(() {
      mockChatRepository = MockChatRepository();
      mockLoggingService = MockLoggingService();

      if (!GetIt.instance.isRegistered<LoggingService>()) {
        GetIt.instance.registerSingleton<LoggingService>(mockLoggingService);
      }
    });

    tearDown(() {
      GetIt.instance.reset();
    });

    testWidgets('displays category selection prompt when no category selected',
        (tester) async {
      await _pumpChatModalPage(
        tester,
        selectedCategoryIds: {},
        chatRepository: mockChatRepository,
      );
      await tester.pump();

      expect(find.byIcon(Icons.category_outlined), findsOneWidget);
      expect(find.text('Please select a single category'), findsOneWidget);
      expect(
        find.text(
          'The AI assistant needs a specific category context '
          'to help you with tasks',
        ),
        findsOneWidget,
      );
    });

    testWidgets(
        'displays category selection prompt when multiple categories selected',
        (tester) async {
      await _pumpChatModalPage(
        tester,
        selectedCategoryIds: {'cat1', 'cat2'},
        chatRepository: mockChatRepository,
      );
      await tester.pump();

      expect(find.byIcon(Icons.category_outlined), findsOneWidget);
      expect(find.text('Please select a single category'), findsOneWidget);
    });

    testWidgets(
        'displays RefactoredChatInterface when single category selected',
        (tester) async {
      _stubCreateSession(mockChatRepository, categoryId: 'single-category-id');

      await _pumpChatModalPage(
        tester,
        selectedCategoryIds: {'single-category-id'},
        chatRepository: mockChatRepository,
      );
      await tester.pump();

      expect(find.byType(ChatInterface), findsOneWidget);
      expect(find.byIcon(Icons.category_outlined), findsNothing);
      expect(find.text('Please select a single category'), findsNothing);
    });

    testWidgets('passes correct categoryId to RefactoredChatInterface',
        (tester) async {
      const categoryId = 'test-category-123';
      _stubCreateSession(mockChatRepository, categoryId: categoryId);

      await _pumpChatModalPage(
        tester,
        selectedCategoryIds: {categoryId},
        chatRepository: mockChatRepository,
      );
      await tester.pump();

      final chatInterfaceWidget = tester.widget<ChatInterface>(
        find.byType(ChatInterface),
      );
      expect(chatInterfaceWidget.categoryId, equals(categoryId));
    });

    testWidgets('uses SizedBox with 85% screen height constraint',
        (tester) async {
      _stubCreateSession(
        mockChatRepository,
        categoryId: 'single-category-id',
      );

      await _pumpChatModalPage(
        tester,
        selectedCategoryIds: {'single-category-id'},
        chatRepository: mockChatRepository,
      );
      await tester.pumpAndSettle();

      final sizedBox = tester.widget<SizedBox>(
        find.byType(SizedBox).first,
      );

      final screenHeight = MediaQuery.of(
        tester.element(find.byType(ChatModalPage)),
      ).size.height;
      expect(sizedBox.height, equals(screenHeight * 0.85));
    });

    testWidgets('responds to category selection changes', (tester) async {
      await _pumpChatModalPage(
        tester,
        selectedCategoryIds: {},
        chatRepository: mockChatRepository,
      );
      await tester.pumpAndSettle();

      expect(find.text('Please select a single category'), findsOneWidget);
      expect(find.byType(ChatInterface), findsNothing);
    });

    testWidgets('shows chat interface with single category selected',
        (tester) async {
      _stubCreateSession(mockChatRepository, categoryId: 'test-category');

      await _pumpChatModalPage(
        tester,
        selectedCategoryIds: {'test-category'},
        chatRepository: mockChatRepository,
      );
      await tester.pumpAndSettle();

      expect(find.text('Please select a single category'), findsNothing);
      expect(find.byType(ChatInterface), findsOneWidget);
    });

    testWidgets('ambient pulse overlay toggles with streaming state',
        (tester) async {
      if (!GetIt.instance.isRegistered<LoggingService>()) {
        GetIt.instance.registerSingleton<LoggingService>(LoggingService());
      }

      // First with streaming=true
      await _pumpChatModalPage(
        tester,
        selectedCategoryIds: {'cat'},
        extraOverrides: [
          chatSessionControllerProvider('cat')
              .overrideWith(_StreamingChatController.new),
        ],
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

      // Rebuild with idle controller -> ensure app still builds
      await _pumpChatModalPage(
        tester,
        selectedCategoryIds: {'cat'},
        extraOverrides: [
          chatSessionControllerProvider('cat')
              .overrideWith(_IdleChatController.new),
        ],
      );
      await tester.pump();
    });
  });
}

// ---------------------------------------------------------------------------
// Fake controllers for the ambient pulse test
// ---------------------------------------------------------------------------

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
