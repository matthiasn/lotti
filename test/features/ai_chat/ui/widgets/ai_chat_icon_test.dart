import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
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
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_utils/fake_journal_page_controller.dart';

/// Pumps an `AiChatIcon` inside a localised `MaterialApp` with an AppBar,
/// using the given [controller] and optional extra provider overrides.
Future<void> _pumpAiChatIcon(
  WidgetTester tester, {
  required FakeJournalPageController controller,
  List<Override> extraOverrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        journalPageScopeProvider.overrideWithValue(true),
        journalPageControllerProvider(true).overrideWith(() => controller),
        ...extraOverrides,
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          appBar: AppBar(
            actions: const [AiChatIcon()],
          ),
          body: const SizedBox.shrink(),
        ),
      ),
    ),
  );
}

void main() {
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

      const state = JournalPageState(
        showTasks: true,
        taskStatuses: ['OPEN', 'GROOMED', 'IN PROGRESS'],
        selectedTaskStatuses: {'OPEN'},
      );
      fakeController = FakeJournalPageController(state);
    });

    tearDown(GetIt.instance.reset);

    testWidgets('renders icon and tooltip', (tester) async {
      await _pumpAiChatIcon(tester, controller: fakeController);

      expect(find.byIcon(Icons.psychology_outlined), findsOneWidget);
      expect(find.byTooltip('AI Chat Assistant'), findsOneWidget);
    });

    testWidgets('opens modal bottom sheet with ChatModalPage on tap',
        (tester) async {
      await _pumpAiChatIcon(tester, controller: fakeController);

      await tester.tap(find.byIcon(Icons.psychology_outlined));
      await tester.pumpAndSettle();

      expect(find.byType(ChatModalPage), findsOneWidget);
      expect(find.text('Please select a single category'), findsOneWidget);

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

      await _pumpAiChatIcon(
        tester,
        controller: controllerWithCategory,
        extraOverrides: [
          chatRepositoryProvider.overrideWithValue(mockChatRepository),
        ],
      );

      await tester.tap(find.byIcon(Icons.psychology_outlined));
      await tester.pumpAndSettle();

      expect(find.byType(ChatInterface), findsOneWidget);
      expect(find.text('Please select a single category'), findsNothing);
    });

    testWidgets(
        'modal shares controller state with parent (via '
        'UncontrolledProviderScope)', (tester) async {
      await _pumpAiChatIcon(tester, controller: fakeController);

      await tester.tap(find.byIcon(Icons.psychology_outlined));
      await tester.pumpAndSettle();

      expect(find.byType(ChatModalPage), findsOneWidget);
      expect(find.text('Please select a single category'), findsOneWidget);
    });
  });
}
