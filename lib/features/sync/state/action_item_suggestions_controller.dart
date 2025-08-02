import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/maintenance.dart';
import 'package:lotti/get_it.dart';

final actionItemSuggestionsControllerProvider = StateNotifierProvider<
    ActionItemSuggestionsController, ActionItemSuggestionsState>((ref) {
  return ActionItemSuggestionsController(getIt<Maintenance>());
});

class ActionItemSuggestionsState {
  const ActionItemSuggestionsState({
    this.progress = 0,
    this.isRemoving = false,
    this.error,
  });

  final double progress;
  final bool isRemoving;
  final String? error;

  ActionItemSuggestionsState copyWith({
    double? progress,
    bool? isRemoving,
    String? error,
    bool clearError = false,
  }) {
    return ActionItemSuggestionsState(
      progress: progress ?? this.progress,
      isRemoving: isRemoving ?? this.isRemoving,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class ActionItemSuggestionsController
    extends StateNotifier<ActionItemSuggestionsState> {
  ActionItemSuggestionsController(this._maintenance)
      : super(const ActionItemSuggestionsState());
  final Maintenance _maintenance;

  Future<void> removeActionItemSuggestions() async {
    state = state.copyWith(isRemoving: true, progress: 0, clearError: true);

    try {
      await _maintenance.removeActionItemSuggestions(
        triggeredAtAppStart: false,
        onProgress: (progress) {
          state = state.copyWith(progress: progress);
        },
      );
    } catch (e) {
      state = state.copyWith(
        isRemoving: false,
        progress: 0,
        error: e.toString(),
      );
      return;
    }
    state = state.copyWith(isRemoving: false);
  }
}
