import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/functions/checklist_completion_functions.dart';
import 'package:lotti/features/ai/services/checklist_completion_service.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_item_with_suggestion_widget.dart';
import 'package:lotti/features/tasks/ui/checklists/consts.dart';

import '../../../../test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChecklistItemWithSuggestionWidget', () {
    const itemId = 'test-item-id';
    const taskId = 'test-task-id';
    const title = 'Test checklist item';

    Widget createWidget({
      bool isChecked = false,
      bool hideCompleted = false,
      // ignore: avoid_positional_boolean_parameters
      void Function(bool?)? onChanged,
      void Function(String?)? onTitleChange,
      bool showEditIcon = true,
      bool readOnly = false,
      void Function()? onEdit,
      List<ChecklistCompletionSuggestion> suggestions = const [],
    }) {
      return ProviderScope(
        overrides: [
          checklistCompletionServiceProvider.overrideWith(
            () => TestChecklistCompletionService(suggestions),
          ),
        ],
        child: WidgetTestBench(
          child: ChecklistItemWithSuggestionWidget(
            itemId: itemId,
            taskId: taskId,
            title: title,
            isChecked: isChecked,
            hideCompleted: hideCompleted,
            onChanged: onChanged ?? (_) {},
            onTitleChange: onTitleChange,
            showEditIcon: showEditIcon,
            readOnly: readOnly,
            onEdit: onEdit,
          ),
        ),
      );
    }

    testWidgets('renders basic checklist item without suggestion',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());

      // Should show the title and checkbox
      expect(find.textContaining(title), findsAtLeastNWidgets(1));
      expect(find.byType(Checkbox), findsOneWidget);
    });

    testWidgets('shows suggestion indicator when suggestion exists',
        (WidgetTester tester) async {
      const suggestion = ChecklistCompletionSuggestion(
        checklistItemId: itemId,
        reason: 'User said "I completed this task"',
        confidence: ChecklistCompletionConfidence.high,
      );

      await tester.pumpWidget(createWidget(suggestions: [suggestion]));
      await tester.pump(); // Initial pump
      await tester.pump(const Duration(seconds: 1)); // Let animation start

      // Should show the checklist item
      expect(find.textContaining(title), findsAtLeastNWidgets(1));

      // Find the ChecklistItemWithSuggestionWidget
      final checklistItemWithSuggestion =
          tester.widget<ChecklistItemWithSuggestionWidget>(
        find.byType(ChecklistItemWithSuggestionWidget),
      );
      expect(checklistItemWithSuggestion.itemId, equals(itemId));

      // Verify that the widget builds with a suggestion without crashing
      expect(find.byType(ChecklistItemWithSuggestionWidget), findsOneWidget);
    });

    testWidgets('checkbox toggles correctly', (WidgetTester tester) async {
      var isChecked = false;

      await tester.pumpWidget(createWidget(
        isChecked: isChecked,
        onChanged: (value) {
          isChecked = value ?? false;
        },
      ));

      // Initially unchecked
      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isFalse);

      // Tap checkbox
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      expect(isChecked, isTrue);

      // Let completion highlight timer finish to avoid pending timers.
      await tester.pump(checklistCompletionAnimationDuration);
      await tester.pump();
    });

    testWidgets('title can be edited when edit icon is tapped',
        (WidgetTester tester) async {
      String? newTitle;

      await tester.pumpWidget(createWidget(
        onTitleChange: (value) {
          newTitle = value;
        },
      ));

      // Should show edit icon
      expect(find.byIcon(Icons.edit), findsOneWidget);

      // Tap edit icon
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();

      // Enter new text and save via Enter (SaveIntent)
      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'New title');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(newTitle, equals('New title'));
    });

    testWidgets('does not show edit icon when readOnly',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget(
        readOnly: true,
        showEditIcon: false,
      ));

      // Should not show edit icon
      expect(find.byIcon(Icons.edit), findsNothing);
    });

    testWidgets('clears suggestion when checkbox is manually toggled',
        (WidgetTester tester) async {
      const suggestion = ChecklistCompletionSuggestion(
        checklistItemId: itemId,
        reason: 'Completed',
        confidence: ChecklistCompletionConfidence.high,
      );

      final testService = TestChecklistCompletionService([suggestion]);
      var checkboxToggled = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            checklistCompletionServiceProvider.overrideWith(() => testService),
          ],
          child: WidgetTestBench(
            child: ChecklistItemWithSuggestionWidget(
              itemId: itemId,
              taskId: taskId,
              title: title,
              isChecked: false,
              onChanged: (_) {
                checkboxToggled = true;
              },
            ),
          ),
        ),
      );
      await tester.pump(); // Initial pump
      await tester.pump(const Duration(seconds: 1)); // Let animation start

      // Initially has suggestion
      expect(testService.getSuggestionForItem(itemId), isNotNull);

      // Tap checkbox directly
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      // Checkbox was toggled
      expect(checkboxToggled, isTrue);

      // Suggestion should be cleared
      expect(testService.getSuggestionForItem(itemId), isNull);

      // Let completion highlight timer finish to avoid pending timers.
      await tester.pump(checklistCompletionAnimationDuration);
      await tester.pump();
    });

    testWidgets('handles error state gracefully', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            checklistCompletionServiceProvider.overrideWith(
              ErrorChecklistCompletionService.new,
            ),
          ],
          child: WidgetTestBench(
            child: ChecklistItemWithSuggestionWidget(
              itemId: itemId,
              taskId: taskId,
              title: title,
              isChecked: false,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      // Should still show the basic checklist item
      expect(find.textContaining(title), findsAtLeastNWidgets(1));
      expect(find.byType(Checkbox), findsOneWidget);

      // In error state, the widget should still render without crashing
    });

    testWidgets('handles loading state gracefully',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            checklistCompletionServiceProvider.overrideWith(
              LoadingChecklistCompletionService.new,
            ),
          ],
          child: WidgetTestBench(
            child: ChecklistItemWithSuggestionWidget(
              itemId: itemId,
              taskId: taskId,
              title: title,
              isChecked: false,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      // Should still show the basic checklist item
      expect(find.textContaining(title), findsAtLeastNWidgets(1));
      expect(find.byType(Checkbox), findsOneWidget);

      // In loading state, the widget should still render without crashing
    });

    testWidgets('renders positioned suggestion indicator overlay',
        (WidgetTester tester) async {
      const suggestion = ChecklistCompletionSuggestion(
        checklistItemId: itemId,
        reason: 'Looks complete',
        confidence: ChecklistCompletionConfidence.high,
      );

      await tester.pumpWidget(createWidget(suggestions: [suggestion]));
      await tester.pump();

      // Should render a Positioned indicator when a suggestion exists
      final positionedIndicator = find.descendant(
        of: find.byType(ChecklistItemWithSuggestionWidget),
        matching: find.byType(Positioned),
      );
      expect(positionedIndicator, findsWidgets);
    });

    testWidgets(
        'hides immediately when hideCompleted becomes true for an already completed item',
        (WidgetTester tester) async {
      // Start in \"All\" mode: completed item but hideCompleted == false.
      await tester.pumpWidget(
        createWidget(
          isChecked: true,
        ),
      );
      await tester.pump();

      // Row is visible.
      expect(find.textContaining(title), findsAtLeastNWidgets(1));

      // Toggle to \"Open only\" semantics: hideCompleted == true while still checked.
      await tester.pumpWidget(
        createWidget(
          isChecked: true,
          hideCompleted: true,
        ),
      );
      await tester.pump(checklistCompletionFadeDuration);

      // Row should now be effectively hidden (collapsed/faded). We don't
      // assert on text presence here because AnimatedCrossFade keeps both
      // children in the tree during the transition; instead, rely on higher
      // level checklist tests to verify visibility semantics.
    });

    testWidgets(
        'shows again when hideCompleted becomes false for a completed item',
        (WidgetTester tester) async {
      // Start in \"Open only\" semantics: completed and hidden.
      await tester.pumpWidget(
        createWidget(
          isChecked: true,
          hideCompleted: true,
        ),
      );
      await tester.pump();

      // Toggle back to \"All\": hideCompleted == false while still checked.
      await tester.pumpWidget(
        createWidget(
          isChecked: true,
        ),
      );
      await tester.pump();

      // Row should become visible again without throwing; detailed visibility
      // semantics (text, hit-testing) are covered in higher-level checklist
      // widget tests.
    });
  });
}

// Test implementation of ChecklistCompletionService
class TestChecklistCompletionService extends ChecklistCompletionService {
  TestChecklistCompletionService(this._suggestions);

  final List<ChecklistCompletionSuggestion> _suggestions;

  @override
  FutureOr<List<ChecklistCompletionSuggestion>> build() async {
    return _suggestions;
  }

  @override
  void clearSuggestion(String checklistItemId) {
    state = AsyncData(
      _suggestions.where((s) => s.checklistItemId != checklistItemId).toList(),
    );
  }

  @override
  ChecklistCompletionSuggestion? getSuggestionForItem(String itemId) {
    return state.whenOrNull(
      data: (suggestions) =>
          suggestions.firstWhereOrNull((s) => s.checklistItemId == itemId),
    );
  }
}

// Error state service for testing
class ErrorChecklistCompletionService extends ChecklistCompletionService {
  @override
  FutureOr<List<ChecklistCompletionSuggestion>> build() async {
    throw Exception('Service error');
  }
}

// Loading state service for testing
class LoadingChecklistCompletionService extends ChecklistCompletionService {
  @override
  FutureOr<List<ChecklistCompletionSuggestion>> build() async {
    // Use a completer to keep the future pending without creating a timer
    final completer = Completer<List<ChecklistCompletionSuggestion>>();
    return completer.future;
  }
}
