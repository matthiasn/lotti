import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tasks/state/checklists_sorting_controller.dart';

void main() {
  group('ChecklistsSortingController', () {
    late ProviderContainer container;
    const taskId = 'task-1';

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state has isSorting false and empty preExpansionStates', () {
      final state = container.read(checklistsSortingControllerProvider(taskId));

      expect(state.isSorting, false);
      expect(state.preExpansionStates, isEmpty);
    });

    test('enterSortingMode sets isSorting true and stores expansion states',
        () {
      final notifier =
          container.read(checklistsSortingControllerProvider(taskId).notifier);

      final expansionStates = {
        'checklist-1': true,
        'checklist-2': false,
        'checklist-3': true,
      };

      notifier.enterSortingMode(expansionStates);

      final state = container.read(checklistsSortingControllerProvider(taskId));
      expect(state.isSorting, true);
      expect(state.preExpansionStates, expansionStates);
    });

    test('exitSortingMode sets isSorting false but preserves expansion states',
        () {
      final notifier =
          container.read(checklistsSortingControllerProvider(taskId).notifier);

      final expansionStates = {
        'checklist-1': true,
        'checklist-2': false,
      };

      // Enter sorting mode first
      notifier.enterSortingMode(expansionStates);
      expect(
        container.read(checklistsSortingControllerProvider(taskId)).isSorting,
        true,
      );

      // Exit sorting mode
      notifier.exitSortingMode();

      final state = container.read(checklistsSortingControllerProvider(taskId));
      expect(state.isSorting, false);
      expect(
        state.preExpansionStates,
        expansionStates,
        reason: 'preExpansionStates should be preserved for restoration',
      );
    });

    test('clearPreExpansionStates clears the stored states', () {
      // Enter and exit sorting mode, then clear
      container.read(checklistsSortingControllerProvider(taskId).notifier)
        ..enterSortingMode({'checklist-1': true})
        ..exitSortingMode()
        ..clearPreExpansionStates();

      final state = container.read(checklistsSortingControllerProvider(taskId));
      expect(state.preExpansionStates, isEmpty);
    });

    test('preExpansionStates are preserved after exitSortingMode', () {
      // Enter and exit sorting mode
      container.read(checklistsSortingControllerProvider(taskId).notifier)
        ..enterSortingMode({'checklist-1': true})
        ..exitSortingMode();

      // Verify states are still there after exit (before clear)
      expect(
        container
            .read(checklistsSortingControllerProvider(taskId))
            .preExpansionStates,
        isNotEmpty,
      );
    });

    test('enterSortingMode makes a copy of expansion states', () {
      final notifier =
          container.read(checklistsSortingControllerProvider(taskId).notifier);

      final originalStates = <String, bool>{
        'checklist-1': true,
      };

      notifier.enterSortingMode(originalStates);

      // Modify the original map
      originalStates['checklist-2'] = false;

      // The stored state should not be affected
      final state = container.read(checklistsSortingControllerProvider(taskId));
      expect(state.preExpansionStates, {'checklist-1': true});
      expect(state.preExpansionStates.containsKey('checklist-2'), false);
    });

    test('provider is scoped to task ID', () {
      const taskId1 = 'task-1';
      const taskId2 = 'task-2';

      final notifier1 =
          container.read(checklistsSortingControllerProvider(taskId1).notifier);
      final notifier2 =
          container.read(checklistsSortingControllerProvider(taskId2).notifier);

      // Enter sorting mode only for task 1
      notifier1.enterSortingMode({'checklist-a': true});

      // Task 1 should be in sorting mode
      expect(
        container.read(checklistsSortingControllerProvider(taskId1)).isSorting,
        true,
      );

      // Task 2 should NOT be in sorting mode
      expect(
        container.read(checklistsSortingControllerProvider(taskId2)).isSorting,
        false,
      );

      // Enter sorting mode for task 2 with different states
      notifier2.enterSortingMode({'checklist-b': false});

      // Both should now be in sorting mode with their own states
      final state1 =
          container.read(checklistsSortingControllerProvider(taskId1));
      final state2 =
          container.read(checklistsSortingControllerProvider(taskId2));

      expect(state1.isSorting, true);
      expect(state1.preExpansionStates, {'checklist-a': true});

      expect(state2.isSorting, true);
      expect(state2.preExpansionStates, {'checklist-b': false});
    });
  });

  group('ChecklistsSortingState', () {
    test('default state has correct values', () {
      const state = ChecklistsSortingState();

      expect(state.isSorting, false);
      expect(state.preExpansionStates, isEmpty);
    });

    test('copyWith works correctly', () {
      const state = ChecklistsSortingState();

      final newState = state.copyWith(
        isSorting: true,
        preExpansionStates: {'id': true},
      );

      expect(newState.isSorting, true);
      expect(newState.preExpansionStates, {'id': true});

      // Original should be unchanged
      expect(state.isSorting, false);
      expect(state.preExpansionStates, isEmpty);
    });
  });
}
