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

import '../../../../mocks/mocks.dart';
import '../../../../test_utils/fake_journal_page_controller.dart';
import '../../../../widget_test_utils.dart';

/// Mock controller that returns a specific state based on selectedCategoryIds
/// Builds the minimal journal page state the chat modal reads, with the
/// given category selection, for the shared [FakeJournalPageController].
JournalPageState _journalStateWithCategories(Set<String> selectedCategoryIds) {
  return JournalPageState(
    selectedEntryTypes: const [],
    match: '',
    filters: const {},
    showPrivateEntries: false,
    showTasks: true,
    fullTextMatches: const {},
    pagingController: null,
    taskStatuses: const [],
    selectedTaskStatuses: const {},
    selectedCategoryIds: selectedCategoryIds,
    selectedLabelIds: const {},
  );
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
          () => FakeJournalPageController(
            _journalStateWithCategories(selectedCategoryIds),
          ),
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
  when(() => repo.createSession(categoryId: categoryId)).thenAnswer(
    (_) async => ChatSession(
      id: 'test-session',
      title: 'New Chat',
      createdAt: DateTime(2024),
      lastMessageAt: DateTime(2024),
      messages: [],
    ),
  );
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
      ensureDomainLoggerRegistered();
    });

    tearDown(() {
      GetIt.instance.reset();
    });

    testWidgets(
      'displays category selection prompt when no category selected',
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
      },
    );

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
      },
    );

    testWidgets(
      'displays RefactoredChatInterface when single category selected',
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
        await tester.pump();

        expect(find.byType(ChatInterface), findsOneWidget);
        expect(find.byIcon(Icons.category_outlined), findsNothing);
        expect(find.text('Please select a single category'), findsNothing);
      },
    );

    testWidgets('passes correct categoryId to RefactoredChatInterface', (
      tester,
    ) async {
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

    testWidgets('uses SizedBox with 85% screen height constraint', (
      tester,
    ) async {
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

    testWidgets('shows chat interface with single category selected', (
      tester,
    ) async {
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

    testWidgets('ambient pulse overlay activates when streaming is true', (
      tester,
    ) async {
      ensureDomainLoggerRegistered();

      await _pumpChatModalPage(
        tester,
        selectedCategoryIds: {'cat'},
        extraOverrides: [
          chatSessionControllerProvider(
            'cat',
          ).overrideWith(_StreamingChatController.new),
        ],
      );
      await tester.pump();

      // While streaming, the ambient border container renders an active glow
      // (non-empty boxShadow) and an overlay border.
      expect(_activeGlowContainerFinder, findsWidgets);
    });

    testWidgets(
      'didUpdateWidget starts the pulse when streaming turns on '
      'and stops it when streaming turns off',
      (tester) async {
        ensureDomainLoggerRegistered();

        // Start with streaming OFF so the animation controller is idle and the
        // _AmbientPulseBorder State exists. Toggling the provider afterwards
        // keeps the SAME widget mounted, driving didUpdateWidget.
        await _pumpChatModalPage(
          tester,
          selectedCategoryIds: {'cat'},
          extraOverrides: [
            chatSessionControllerProvider(
              'cat',
            ).overrideWith(_TogglableChatController.new),
          ],
        );
        await tester.pump();

        // Initially idle: no active glow.
        expect(_activeGlowContainerFinder, findsNothing);

        final element = tester.element(find.byType(ChatModalPage));
        final container = ProviderScope.containerOf(element);
        final notifier =
            container.read(
                  chatSessionControllerProvider('cat').notifier,
                )
                as _TogglableChatController;

        // Turn streaming ON -> didUpdateWidget hits the repeat() branch.
        // ignore: cascade_invocations
        notifier.setStreaming(isStreaming: true);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));

        expect(
          container.read(
            chatSessionControllerProvider('cat').select((s) => s.isStreaming),
          ),
          isTrue,
        );
        expect(_activeGlowContainerFinder, findsWidgets);

        // Turn streaming OFF -> didUpdateWidget hits the stop() branch and the
        // glow disappears. This also clears the repeating animation so no timer
        // leaks past the test.
        notifier.setStreaming(isStreaming: false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));

        expect(
          container.read(
            chatSessionControllerProvider('cat').select((s) => s.isStreaming),
          ),
          isFalse,
        );
        expect(_activeGlowContainerFinder, findsNothing);
      },
    );
  });
}

/// Finds an `_AmbientPulseBorder` `Container` that currently renders the active
/// glow (a non-empty `boxShadow`), which only happens while streaming.
final Finder _activeGlowContainerFinder = find.byWidgetPredicate((w) {
  if (w is Container && w.decoration is BoxDecoration) {
    final d = w.decoration! as BoxDecoration;
    return d.boxShadow != null && d.boxShadow!.isNotEmpty;
  }
  return false;
});

// ---------------------------------------------------------------------------
// Fake controllers for the ambient pulse tests
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

/// Controller whose streaming flag can be toggled on demand so a single mounted
/// [ChatModalPage] sees the `isStreaming` value change, driving
/// `_AmbientPulseBorder.didUpdateWidget`.
class _TogglableChatController extends ChatSessionController {
  @override
  ChatSessionUiModel build(String categoryId) {
    return const ChatSessionUiModel(
      id: 's',
      title: 't',
      messages: <ChatMessage>[],
      isLoading: false,
      isStreaming: false,
      selectedModelId: 'm',
    );
  }

  @override
  Future<void> initializeSession({String? sessionId}) async {}

  void setStreaming({required bool isStreaming}) {
    state = state.copyWith(isStreaming: isStreaming);
  }
}
