import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:lotti/blocs/settings/habits/habit_settings_state.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/habits/autocomplete_update.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/widgets/settings/habits/habit_autocomplete_widget.dart';

class HabitSettingsCubit extends Cubit<HabitSettingsState> {
  HabitSettingsCubit(
    HabitDefinition habitDefinition, {
    BuildContext? context,
  }) : super(
          HabitSettingsState(
            habitDefinition: habitDefinition,
            dirty: false,
            formKey: GlobalKey<FormBuilderState>(),
            storyTags: [],
            autoCompleteRule: testAutoComplete,
          ),
        ) {
    _habitDefinition = habitDefinition;
    _autoCompleteRule = testAutoComplete;
    _context = context;

    getIt<TagsService>().watchTags().forEach((tags) {
      _storyTags = tags.whereType<StoryTag>().toList();
      _defaultStory = _habitDefinition.defaultStoryId != null
          ? _storyTags
              .where((tag) => tag.id == _habitDefinition.defaultStoryId)
              .first
          : null;

      emitState();
    });
  }
  final PersistenceLogic persistenceLogic = getIt<PersistenceLogic>();

  late HabitDefinition _habitDefinition;
  late AutoCompleteRule? _autoCompleteRule;
  bool _dirty = false;
  late BuildContext? _context;
  List<StoryTag> _storyTags = [];
  StoryTag? _defaultStory;

  void _maybePop() {
    if (_context != null) {
      Navigator.of(_context!).maybePop();
    }
  }

  void setDirty() {
    _dirty = true;
    emitState();
  }

  void setCategory(String? categoryId) {
    _dirty = true;
    _habitDefinition = _habitDefinition.copyWith(categoryId: categoryId);
    emitState();
  }

  void setDashboard(String? dashboardId) {
    _dirty = true;
    _habitDefinition = _habitDefinition.copyWith(dashboardId: dashboardId);
    emitState();
  }

  void setActiveFrom(DateTime? activeFrom) {
    _dirty = true;
    _habitDefinition = _habitDefinition.copyWith(activeFrom: activeFrom);
    emitState();
  }

   void setShowFrom(DateTime? showFrom) {
    _dirty = true;

    final currentSchedule = _habitDefinition.habitSchedule;

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
     _habitDefinition = _habitDefinition.copyWith(habitSchedule: newSchedule);
    emitState();
  }

  void setAlertAtTime(DateTime? alertAtTime) {
    _dirty = true;

    final currentSchedule = _habitDefinition.habitSchedule;
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
    _habitDefinition = _habitDefinition.copyWith(
      habitSchedule: newSchedule,
    );
    emitState();
  }

  void clearAlertAtTime() {
    _dirty = true;

    final currentSchedule = _habitDefinition.habitSchedule;
    
    final newSchedule = currentSchedule.maybeMap(
      daily: (daily) => HabitSchedule.daily(
        requiredCompletions: daily.requiredCompletions,
        alertAtTime: daily.showFrom,
      ),

      orElse: () => const HabitSchedule.daily(
        requiredCompletions: 1,
      ),
    );
    _habitDefinition = _habitDefinition.copyWith(
      habitSchedule: newSchedule,
    );
    emitState();
  }

  Future<void> onSavePressed() async {
    state.formKey.currentState!.save();
    if (state.formKey.currentState!.validate()) {
      final formData = state.formKey.currentState?.value;
      final private = formData?['private'] as bool? ?? false;
      final active = !(formData?['archived'] as bool? ?? false);
      final priority = formData?['priority'] as bool? ?? false;
      final defaultStory = formData?['default_story_id'] as StoryTag?;

      final dataType = _habitDefinition.copyWith(
        name: '${formData!['name']}'.trim(),
        description: '${formData['description']}'.trim(),
        private: private,
        active: active,
        priority: priority,
        defaultStoryId: defaultStory?.id,
      );

      await persistenceLogic.upsertEntityDefinition(dataType);
      _dirty = false;
      emitState();

      await getIt<NotificationService>().scheduleHabitNotification(dataType);

      _maybePop();
    }
  }

  Future<void> delete() async {
    await persistenceLogic.upsertEntityDefinition(
      _habitDefinition.copyWith(deletedAt: DateTime.now()),
    );
    _maybePop();
  }

  void emitState() {
    emit(
      HabitSettingsState(
        habitDefinition: _habitDefinition,
        dirty: _dirty,
        formKey: state.formKey,
        storyTags: _storyTags,
        defaultStory: _defaultStory,
        autoCompleteRule: _autoCompleteRule,
      ),
    );
  }

  void replaceAutoCompleteRuleAt(
    List<int> replaceAtPath,
    AutoCompleteRule? replaceWith,
  ) {
    _autoCompleteRule = replaceAt(
      _autoCompleteRule,
      replaceAtPath: replaceAtPath,
      replaceWith: replaceWith,
    );
    emitState();
  }

  void removeAutoCompleteRuleAt(List<int> replaceAtPath) {
    _autoCompleteRule = replaceAt(
      _autoCompleteRule,
      replaceAtPath: replaceAtPath,
      replaceWith: null,
    );
    emitState();
  }

  @override
  Future<void> close() async {
    await super.close();
  }
}
