import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:lotti/features/ai_chat/models/chat_session.dart';
import 'package:lotti/features/ai_chat/repository/chat_repository.dart';
import 'package:lotti/features/ai_chat/ui/pages/chat_modal_page.dart';
import 'package:lotti/features/ai_chat/ui/widgets/ai_chat_icon.dart';
import 'package:lotti/features/ai_chat/ui/widgets/chat_interface.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_scope.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../test_utils/fake_journal_page_controller.dart';

class MockChatRepository extends Mock implements ChatRepository {}

class MockLoggingService extends Mock implements LoggingService {}

void main() {
  // Helper to build a minimal app hosting the AiChatIcon in the AppBar.
  Widget buildTestApp({required Widget icon, required Widget body}) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          actions: [icon],
        ),
        body: body,
      ),
    );
  }

  group('AiChatIcon', () {
    late FakeJournalPageController fakeController;
    late MockChatRepository mockChatRepository;
    late MockLoggingService mockLoggingService;

    setUp(() {
      mockChatRepository = MockChatRepository();
      mockLoggingService = MockLoggingService();

      GetIt.instance.allowReassignment = true;
      if (!GetIt.instance.isRegistered<LoggingService>()) {
        GetIt.instance.registerSingleton<LoggingService>(mockLoggingService);
      }

      // Create a minimal state where no category is selected
      const state = JournalPageState(
        showTasks: true,
        taskStatuses: ['OPEN', 'GROOMED', 'IN PROGRESS'],
        selectedTaskStatuses: {'OPEN'},
      );
      fakeController = FakeJournalPageController(state);
    });

    tearDown(GetIt.instance.reset);

    testWidgets('renders icon and tooltip', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            journalPageScopeProvider.overrideWithValue(true),
            journalPageControllerProvider(true)
                .overrideWith(() => fakeController),
          ],
          child: buildTestApp(
            icon: const AiChatIcon(),
            body: const SizedBox.shrink(),
          ),
        ),
      );

      expect(find.byIcon(Icons.psychology_outlined), findsOneWidget);
      expect(find.byTooltip('AI Chat Assistant'), findsOneWidget);
    });

    testWidgets('opens modal bottom sheet with ChatModalPage on tap',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            journalPageScopeProvider.overrideWithValue(true),
            journalPageControllerProvider(true)
                .overrideWith(() => fakeController),
          ],
          child: buildTestApp(
            icon: const AiChatIcon(),
            body: const SizedBox.shrink(),
          ),
        ),
      );

      // Tap the icon to open the modal.
      await tester.tap(find.byIcon(Icons.psychology_outlined));
      await tester.pumpAndSettle();

      // The ChatModalPage should be rendered inside the bottom sheet.
      expect(find.byType(ChatModalPage), findsOneWidget);
      expect(find.text('Please select a single category'), findsOneWidget);

      // Validate that the modal barrier color uses ~80% black opacity.
      final barrierFinder =
          find.byWidgetPredicate((w) => w is ModalBarrier && w.color != null);
      expect(barrierFinder, findsWidgets);
      final barrier = tester.widget<ModalBarrier>(barrierFinder.first);
      final color = barrier.color;
      expect(color, isNotNull);
      expect(color!.r, 0);
      expect(color.g, 0);
      expect(color.b, 0);
      expect(color.a, closeTo(0.8, 0.01));
    });

    testWidgets('shows ChatInterface when single category is selected',
        (tester) async {
      // Set up screen size for modal
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.reset());

      const categoryId = 'test-category';
      const stateWithCategory = JournalPageState(
        showTasks: true,
        taskStatuses: ['OPEN', 'GROOMED', 'IN PROGRESS'],
        selectedTaskStatuses: {'OPEN'},
        selectedCategoryIds: {categoryId},
      );
      final controllerWithCategory =
          FakeJournalPageController(stateWithCategory);

      when(() => mockChatRepository.createSession(categoryId: categoryId))
          .thenAnswer((_) async => ChatSession(
                id: 'test-session',
                title: 'New Chat',
                createdAt: DateTime(2024),
                lastMessageAt: DateTime(2024),
                messages: [],
              ));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            journalPageScopeProvider.overrideWithValue(true),
            journalPageControllerProvider(true)
                .overrideWith(() => controllerWithCategory),
            chatRepositoryProvider.overrideWithValue(mockChatRepository),
          ],
          child: buildTestApp(
            icon: const AiChatIcon(),
            body: const SizedBox.shrink(),
          ),
        ),
      );

      // Tap the icon to open the modal.
      await tester.tap(find.byIcon(Icons.psychology_outlined));
      await tester.pumpAndSettle();

      // ChatInterface should be displayed, not the category selection prompt
      expect(find.byType(ChatInterface), findsOneWidget);
      expect(find.text('Please select a single category'), findsNothing);
    });

    testWidgets(
        'modal shares controller state with parent (via '
        'UncontrolledProviderScope)', (tester) async {
      // This test verifies that the modal uses the same controller instance
      // as the parent, not a fresh one created by a new ProviderScope.

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            journalPageScopeProvider.overrideWithValue(true),
            journalPageControllerProvider(true)
                .overrideWith(() => fakeController),
          ],
          child: buildTestApp(
            icon: const AiChatIcon(),
            body: const SizedBox.shrink(),
          ),
        ),
      );

      // Open the modal
      await tester.tap(find.byIcon(Icons.psychology_outlined));
      await tester.pumpAndSettle();

      // Verify the modal is open
      expect(find.byType(ChatModalPage), findsOneWidget);

      // The ChatModalPage reads from journalPageControllerProvider(showTasks).
      // If UncontrolledProviderScope works correctly, it should use the same
      // fakeController instance we provided, meaning any state we verify
      // comes from our fake controller's initial state.
      // The prompt "Please select a single category" confirms it read from
      // our controller with empty selectedCategoryIds.
      expect(find.text('Please select a single category'), findsOneWidget);
    });
  });
}
