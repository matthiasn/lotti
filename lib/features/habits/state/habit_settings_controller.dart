import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/settings/ui/widgets/habits/habit_autocomplete_widget.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/habits/autocomplete_update.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:riverpod/riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'habit_settings_controller.freezed.dart';
part 'habit_settings_controller.g.dart';

/// Immutable state for the habit settings form.
@freezed
abstract class HabitSettingsState with _$HabitSettingsState {
  const factory HabitSettingsState({
    required HabitDefinition habitDefinition,
    required bool dirty,
    required GlobalKey<FormBuilderState> formKey,
    required List<StoryTag> storyTags,
    required AutoCompleteRule? autoCompleteRule,
    StoryTag? defaultStory,
  }) = _HabitSettingsState;

  factory HabitSettingsState.initial(String habitId) => HabitSettingsState(
        habitDefinition: _createEmptyHabitDefinition(habitId),
        dirty: false,
        formKey: GlobalKey<FormBuilderState>(),
        storyTags: const [],
        autoCompleteRule: testAutoComplete,
      );
}

/// Stream provider for watching a habit by ID.
@riverpod
Stream<HabitDefinition?> habitById(Ref ref, String habitId) {
  return getIt<JournalDb>().watchHabitById(habitId);
}

/// Stream provider for dashboards used in habit settings.
@riverpod
Stream<List<DashboardDefinition>> habitDashboards(Ref ref) {
  return getIt<JournalDb>().watchDashboards();
}

/// Creates a new empty HabitDefinition for the create flow.
HabitDefinition _createEmptyHabitDefinition(String habitId) {
  return HabitDefinition(
    id: habitId,
    name: '',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    description: '',
    private: false,
    vectorClock: null,
    habitSchedule: const HabitSchedule.daily(requiredCompletions: 1),
    version: '',
    active: true,
  );
}

/// Provider for the habit settings controller, using habitId as family key.
final AutoDisposeNotifierProviderFamily<HabitSettingsController,
        HabitSettingsState, String> habitSettingsControllerProvider =
    AutoDisposeNotifierProvider.family<HabitSettingsController,
        HabitSettingsState, String>(
  HabitSettingsController.new,
);

/// Controller for managing habit settings form state.
/// Uses habitId as family key - works for both create (new ID) and edit (existing ID).
class HabitSettingsController
    extends AutoDisposeFamilyNotifier<HabitSettingsState, String> {
  HabitSettingsController();

  StreamSubscription<List<TagEntity>>? _tagsSubscription;
  StreamSubscription<HabitDefinition?>? _habitSubscription;

  @override
  HabitSettingsState build(String habitId) {
    _tagsSubscription?.cancel();
    _habitSubscription?.cancel();

    // Watch for habit updates from DB (for edit case)
    _habitSubscription =
        getIt<JournalDb>().watchHabitById(habitId).listen((habit) {
      if (habit != null && !state.dirty) {
        // Only update from DB if user hasn't made changes
        state = state.copyWith(habitDefinition: habit);
        _updateDefaultStory();
      }
    });

    // Watch for story tags
    _tagsSubscription = getIt<TagsService>().watchTags().listen((tags) {
      final storyTags = tags.whereType<StoryTag>().toList();
      state = state.copyWith(storyTags: storyTags);
      _updateDefaultStory();
    });

    ref.onDispose(() {
      _tagsSubscription?.cancel();
      _habitSubscription?.cancel();
    });

    return HabitSettingsState.initial(habitId);
  }

  void _updateDefaultStory() {
    final defaultStoryId = state.habitDefinition.defaultStoryId;
    if (defaultStoryId != null) {
      final defaultStory =
          state.storyTags.where((tag) => tag.id == defaultStoryId).firstOrNull;
      state = state.copyWith(
        defaultStory: defaultStory,
      );
    }
  }

  /// Marks the form as dirty (modified).
  void setDirty() {
    state = state.copyWith(dirty: true);
  }

  /// Sets the category ID for the habit.
  void setCategory(String? categoryId) {
    state = state.copyWith(
      dirty: true,
      habitDefinition: state.habitDefinition.copyWith(categoryId: categoryId),
    );
  }

  /// Sets the dashboard ID for the habit.
  void setDashboard(String? dashboardId) {
    state = state.copyWith(
      dirty: true,
      habitDefinition: state.habitDefinition.copyWith(dashboardId: dashboardId),
    );
  }

  /// Sets the active from date for the habit.
  void setActiveFrom(DateTime? activeFrom) {
    state = state.copyWith(
      dirty: true,
      habitDefinition: state.habitDefinition.copyWith(activeFrom: activeFrom),
    );
  }

  /// Sets the show from time for a daily habit schedule.
  void setShowFrom(DateTime? showFrom) {
    final currentSchedule = state.habitDefinition.habitSchedule;

    final newSchedule = currentSchedule.maybeMap(
      daily: (daily) => HabitSchedule.daily(
        requiredCompletions: daily.requiredCompletions,
        showFrom: showFrom,
        alertAtTime: daily.alertAtTime,
      ),
      orElse: () => HabitSchedule.daily(
        requiredCompletions: 1,
        showFrom: showFrom,
      ),
    );

    state = state.copyWith(
      dirty: true,
      habitDefinition:
          state.habitDefinition.copyWith(habitSchedule: newSchedule),
    );
  }

  /// Sets the alert time for a daily habit schedule.
  void setAlertAtTime(DateTime? alertAtTime) {
    final currentSchedule = state.habitDefinition.habitSchedule;

    final newSchedule = currentSchedule.maybeMap(
      daily: (daily) => HabitSchedule.daily(
        requiredCompletions: daily.requiredCompletions,
        showFrom: daily.showFrom,
        alertAtTime: alertAtTime,
      ),
      orElse: () => HabitSchedule.daily(
        requiredCompletions: 1,
        alertAtTime: alertAtTime,
      ),
    );

    state = state.copyWith(
      dirty: true,
      habitDefinition:
          state.habitDefinition.copyWith(habitSchedule: newSchedule),
    );
  }

  /// Clears the alert time for a daily habit schedule.
  void clearAlertAtTime() {
    final currentSchedule = state.habitDefinition.habitSchedule;

    final newSchedule = currentSchedule.maybeMap(
      daily: (daily) => HabitSchedule.daily(
        requiredCompletions: daily.requiredCompletions,
        showFrom: daily.showFrom,
      ),
      orElse: () => const HabitSchedule.daily(
        requiredCompletions: 1,
      ),
    );

    state = state.copyWith(
      dirty: true,
      habitDefinition:
          state.habitDefinition.copyWith(habitSchedule: newSchedule),
    );
  }

  /// Saves the habit and schedules notifications.
  /// Returns true if save was successful.
  Future<bool> onSavePressed() async {
    state.formKey.currentState!.save();
    if (state.formKey.currentState!.validate()) {
      final formData = state.formKey.currentState?.value;
      final private = formData?['private'] as bool? ?? false;
      final active = !(formData?['archived'] as bool? ?? false);
      final priority = formData?['priority'] as bool? ?? false;
      final defaultStory = formData?['default_story_id'] as StoryTag?;

      final dataType = state.habitDefinition.copyWith(
        name: '${formData!['name']}'.trim(),
        description: '${formData['description']}'.trim(),
        private: private,
        active: active,
        priority: priority,
        defaultStoryId: defaultStory?.id,
      );

      await getIt<PersistenceLogic>().upsertEntityDefinition(dataType);
      state = state.copyWith(dirty: false);

      await getIt<NotificationService>().scheduleHabitNotification(dataType);

      return true;
    }
    return false;
  }

  /// Deletes the habit by marking it with a deletedAt timestamp.
  Future<void> delete() async {
    await getIt<PersistenceLogic>().upsertEntityDefinition(
      state.habitDefinition.copyWith(deletedAt: DateTime.now()),
    );
  }

  /// Removes an autocomplete rule at the specified path.
  void removeAutoCompleteRuleAt(List<int> replaceAtPath) {
    state = state.copyWith(
      autoCompleteRule: replaceAt(
        state.autoCompleteRule,
        replaceAtPath: replaceAtPath,
        replaceWith: null,
      ),
    );
  }
}
