// ignore_for_file: specify_nonobvious_property_types

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/features/habits/repository/habits_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/habits/autocomplete_update.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/tags_service.dart';

part 'habit_settings_controller.freezed.dart';

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
        autoCompleteRule: null,
      );
}

/// Stream provider for watching a habit by ID.
/// Uses the repository for data access.
final habitByIdProvider =
    StreamProvider.autoDispose.family<HabitDefinition?, String>(
  (ref, habitId) {
    final repository = ref.watch(habitsRepositoryProvider);
    return repository.watchHabitById(habitId);
  },
);

/// Stream provider for dashboards used in habit settings.
/// Uses the repository for data access.
final habitDashboardsProvider =
    StreamProvider.autoDispose<List<DashboardDefinition>>((ref) {
  final repository = ref.watch(habitsRepositoryProvider);
  return repository.watchDashboards();
});

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
final habitSettingsControllerProvider = NotifierProvider.autoDispose
    .family<HabitSettingsController, HabitSettingsState, String>(
  HabitSettingsController.new,
);

/// Stream provider for story tags.
final storyTagsStreamProvider =
    StreamProvider.autoDispose<List<TagEntity>>((ref) {
  return getIt<TagsService>().watchTags();
});

/// Controller for managing habit settings form state.
/// Uses habitId as family key - works for both create (new ID) and edit (existing ID).
class HabitSettingsController extends Notifier<HabitSettingsState> {
  HabitSettingsController(this._habitId);

  final String _habitId;
  ProviderSubscription<AsyncValue<HabitDefinition?>>? _habitSubscription;
  ProviderSubscription<AsyncValue<List<TagEntity>>>? _tagsSubscription;

  @override
  HabitSettingsState build() {
    ref.onDispose(() {
      _habitSubscription?.close();
      _tagsSubscription?.close();
    });

    final initialState = HabitSettingsState.initial(_habitId);

    // Check if habit data is already available (for edit case)
    final habitAsync = ref.read(habitByIdProvider(_habitId));
    final existingHabit = habitAsync.value;

    // Watch for future habit updates from DB
    _habitSubscription = ref.listen<AsyncValue<HabitDefinition?>>(
      habitByIdProvider(_habitId),
      (_, next) {
        next.whenData((habit) {
          if (habit != null && !state.dirty) {
            // Only update from DB if user hasn't made changes
            state = state.copyWith(habitDefinition: habit);
            _updateDefaultStory();
          }
        });
      },
    );

    // Watch for story tags updates
    _tagsSubscription = ref.listen<AsyncValue<List<TagEntity>>>(
      storyTagsStreamProvider,
      (_, next) {
        next.whenData((tags) {
          final storyTags = tags.whereType<StoryTag>().toList();
          state = state.copyWith(storyTags: storyTags);
          _updateDefaultStory();
        });
      },
    );

    if (existingHabit != null) {
      return initialState.copyWith(habitDefinition: existingHabit);
    }
    return initialState;
  }

  void _updateDefaultStory() {
    final defaultStoryId = state.habitDefinition.defaultStoryId;
    final defaultStory = defaultStoryId != null
        ? state.storyTags.where((tag) => tag.id == defaultStoryId).firstOrNull
        : null;

    if (state.defaultStory != defaultStory) {
      state = state.copyWith(defaultStory: defaultStory);
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
    final currentState = state.formKey.currentState;
    if (currentState == null) {
      return false;
    }

    currentState.save();
    if (!currentState.validate()) {
      return false;
    }

    final formData = currentState.value;
    final name = formData['name'] as String?;
    final description = formData['description'] as String?;

    if (name == null || name.trim().isEmpty) {
      return false;
    }

    final private = formData['private'] as bool? ?? false;
    final active = !(formData['archived'] as bool? ?? false);
    final priority = formData['priority'] as bool? ?? false;
    final defaultStory = formData['default_story_id'] as StoryTag?;

    final dataType = state.habitDefinition.copyWith(
      name: name.trim(),
      description: (description ?? '').trim(),
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
