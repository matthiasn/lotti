import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/blocs/journal/journal_page_cubit.dart';
import 'package:lotti/blocs/journal/journal_page_state.dart';
import 'package:lotti/features/ai_chat/ui/pages/chat_modal_page.dart';
import 'package:lotti/features/ai_chat/ui/widgets/ai_chat_icon.dart';
import 'package:mocktail/mocktail.dart';

class _MockJournalPageCubit extends Mock implements JournalPageCubit {}

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
    late _MockJournalPageCubit mockJournalPageCubit;

    setUp(() {
      mockJournalPageCubit = _MockJournalPageCubit();
    });

    testWidgets('renders icon and tooltip', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          icon: const AiChatIcon(),
          body: const SizedBox.shrink(),
        ),
      );

      expect(find.byIcon(Icons.psychology_outlined), findsOneWidget);
      expect(find.byTooltip('AI Chat Assistant'), findsOneWidget);
    });

    testWidgets('opens modal bottom sheet with ChatModalPage on tap',
        (tester) async {
      // Provide a minimal state where no category is selected,
      // so ChatModalPage shows the selection prompt (no Riverpod needed).
      final state = JournalPageState(
        match: '',
        tagIds: <String>{},
        filters: <DisplayFilter>{},
        showPrivateEntries: false,
        showTasks: true,
        selectedEntryTypes: <String>[],
        fullTextMatches: <String>{},
        pagingController: null,
        taskStatuses: <String>[],
        selectedTaskStatuses: <String>{},
        selectedCategoryIds: <String?>{},
        selectedLabelIds: <String>{},
      );

      when(() => mockJournalPageCubit.stream)
          .thenAnswer((_) => Stream<JournalPageState>.value(state));
      when(() => mockJournalPageCubit.state).thenReturn(state);

      await tester.pumpWidget(
        BlocProvider<JournalPageCubit>.value(
          value: mockJournalPageCubit,
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
  });
}
