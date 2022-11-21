import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:lotti/blocs/settings/habits/habit_settings_state.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/tags_service.dart';

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
          ),
        ) {
    _habitDefinition = habitDefinition;
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

  Future<void> onSavePressed() async {
    state.formKey.currentState!.save();
    if (state.formKey.currentState!.validate()) {
      final formData = state.formKey.currentState?.value;
      final private = formData?['private'] as bool? ?? false;
      final active = formData?['active'] as bool? ?? false;
      final activeFrom = formData?['active_from'] as DateTime?;
      final showFrom = formData?['show_from'] as DateTime?;
      final defaultStory = formData?['default_story_id'] as StoryTag?;

      final dataType = _habitDefinition.copyWith(
        name: '${formData!['name']}'.trim(),
        description: '${formData['description']}'.trim(),
        private: private,
        active: active,
        activeFrom: activeFrom,
        habitSchedule: HabitSchedule.daily(
          requiredCompletions: 1,
          showFrom: showFrom,
        ),
        defaultStoryId: defaultStory?.id,
      );

      await persistenceLogic.upsertEntityDefinition(dataType);
      _dirty = false;
      emitState();

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
      ),
    );
  }

  @override
  Future<void> close() async {
    await super.close();
  }
}
