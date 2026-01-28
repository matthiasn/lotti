import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_filter_state.dart';

void main() {
  group('AiSettingsFilterState Selection Mode', () {
    late AiSettingsFilterState initialState;

    setUp(() {
      initialState = AiSettingsFilterState.initial();
    });

    group('hasSelectedPrompts', () {
      test('returns false when no prompts are selected', () {
        expect(initialState.hasSelectedPrompts, isFalse);
      });

      test('returns true when prompts are selected', () {
        final state = initialState.copyWith(
          selectedPromptIds: {'prompt-1', 'prompt-2'},
        );
        expect(state.hasSelectedPrompts, isTrue);
      });

      test('returns false after clearing selection', () {
        final state = initialState
            .copyWith(selectedPromptIds: {'prompt-1'}).clearSelection();
        expect(state.hasSelectedPrompts, isFalse);
      });
    });

    group('selectedPromptCount', () {
      test('returns 0 when no prompts are selected', () {
        expect(initialState.selectedPromptCount, 0);
      });

      test('returns correct count when prompts are selected', () {
        final state = initialState.copyWith(
          selectedPromptIds: {'prompt-1', 'prompt-2', 'prompt-3'},
        );
        expect(state.selectedPromptCount, 3);
      });

      test('returns 1 when single prompt is selected', () {
        final state = initialState.copyWith(
          selectedPromptIds: {'prompt-1'},
        );
        expect(state.selectedPromptCount, 1);
      });
    });

    group('togglePromptSelection', () {
      test('adds prompt when not selected', () {
        final state = initialState.togglePromptSelection('prompt-1');
        expect(state.selectedPromptIds, contains('prompt-1'));
        expect(state.selectedPromptCount, 1);
      });

      test('removes prompt when already selected', () {
        final state = initialState.copyWith(
            selectedPromptIds: {'prompt-1'}).togglePromptSelection('prompt-1');
        expect(state.selectedPromptIds, isNot(contains('prompt-1')));
        expect(state.selectedPromptCount, 0);
      });

      test('adds to existing selection', () {
        final state = initialState.copyWith(
            selectedPromptIds: {'prompt-1'}).togglePromptSelection('prompt-2');
        expect(state.selectedPromptIds, contains('prompt-1'));
        expect(state.selectedPromptIds, contains('prompt-2'));
        expect(state.selectedPromptCount, 2);
      });

      test('removes from existing selection without affecting others', () {
        final state = initialState.copyWith(selectedPromptIds: {
          'prompt-1',
          'prompt-2',
          'prompt-3'
        }).togglePromptSelection('prompt-2');
        expect(state.selectedPromptIds, contains('prompt-1'));
        expect(state.selectedPromptIds, isNot(contains('prompt-2')));
        expect(state.selectedPromptIds, contains('prompt-3'));
        expect(state.selectedPromptCount, 2);
      });

      test('can toggle same prompt multiple times', () {
        var state = initialState.togglePromptSelection('prompt-1');
        expect(state.hasSelectedPrompts, isTrue);

        state = state.togglePromptSelection('prompt-1');
        expect(state.hasSelectedPrompts, isFalse);

        state = state.togglePromptSelection('prompt-1');
        expect(state.hasSelectedPrompts, isTrue);
      });
    });

    group('selectAllPrompts', () {
      test('selects all provided prompt IDs', () {
        final state = initialState.selectAllPrompts([
          'prompt-1',
          'prompt-2',
          'prompt-3',
        ]);
        expect(state.selectedPromptCount, 3);
        expect(state.selectedPromptIds,
            containsAll(['prompt-1', 'prompt-2', 'prompt-3']));
      });

      test('replaces existing selection', () {
        final state = initialState.copyWith(selectedPromptIds: {
          'old-prompt'
        }).selectAllPrompts(['new-prompt-1', 'new-prompt-2']);
        expect(state.selectedPromptIds, isNot(contains('old-prompt')));
        expect(state.selectedPromptIds,
            containsAll(['new-prompt-1', 'new-prompt-2']));
      });

      test('handles empty list', () {
        final state = initialState
            .copyWith(selectedPromptIds: {'prompt-1'}).selectAllPrompts([]);
        expect(state.hasSelectedPrompts, isFalse);
      });

      test('handles duplicate IDs in input', () {
        final state = initialState.selectAllPrompts([
          'prompt-1',
          'prompt-1',
          'prompt-2',
        ]);
        expect(state.selectedPromptCount, 2); // Set removes duplicates
      });
    });

    group('clearSelection', () {
      test('clears all selected prompts', () {
        final state = initialState.copyWith(
            selectedPromptIds: {'prompt-1', 'prompt-2'}).clearSelection();
        expect(state.hasSelectedPrompts, isFalse);
        expect(state.selectedPromptCount, 0);
      });

      test('does not affect selectionMode', () {
        final state = initialState.copyWith(
          selectionMode: true,
          selectedPromptIds: {'prompt-1'},
        ).clearSelection();
        expect(state.selectionMode, isTrue);
        expect(state.hasSelectedPrompts, isFalse);
      });

      test('is idempotent on empty selection', () {
        final state = initialState.clearSelection();
        expect(state.hasSelectedPrompts, isFalse);
      });
    });

    group('exitSelectionMode', () {
      test('clears selectionMode and selectedPromptIds', () {
        final state = initialState.copyWith(
          selectionMode: true,
          selectedPromptIds: {'prompt-1', 'prompt-2'},
        ).exitSelectionMode();
        expect(state.selectionMode, isFalse);
        expect(state.hasSelectedPrompts, isFalse);
      });

      test('does not affect other filter state', () {
        final state = initialState
            .copyWith(
              selectionMode: true,
              selectedPromptIds: {'prompt-1'},
              searchQuery: 'test query',
              activeTab: AiSettingsTab.prompts,
            )
            .exitSelectionMode();
        expect(state.selectionMode, isFalse);
        expect(state.hasSelectedPrompts, isFalse);
        expect(state.searchQuery, 'test query');
        expect(state.activeTab, AiSettingsTab.prompts);
      });

      test('is safe to call when not in selection mode', () {
        final state = initialState.exitSelectionMode();
        expect(state.selectionMode, isFalse);
        expect(state.hasSelectedPrompts, isFalse);
      });
    });

    group('integration scenarios', () {
      test('typical selection workflow', () {
        // Enter selection mode
        var state = initialState.copyWith(selectionMode: true);
        expect(state.selectionMode, isTrue);
        expect(state.hasSelectedPrompts, isFalse);

        // Select some prompts
        state = state.togglePromptSelection('prompt-1');
        state = state.togglePromptSelection('prompt-2');
        expect(state.selectedPromptCount, 2);

        // Unselect one
        state = state.togglePromptSelection('prompt-1');
        expect(state.selectedPromptCount, 1);

        // Exit selection mode (e.g., after delete)
        state = state.exitSelectionMode();
        expect(state.selectionMode, isFalse);
        expect(state.hasSelectedPrompts, isFalse);
      });

      test('select all then clear workflow', () {
        final state = initialState
            .copyWith(selectionMode: true)
            .selectAllPrompts(['p1', 'p2', 'p3', 'p4', 'p5']).clearSelection();
        expect(state.selectionMode, isTrue); // Mode remains
        expect(state.hasSelectedPrompts, isFalse); // Selection cleared
      });
    });
  });
}
