import 'package:flutter/widgets.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/tag_type_definitions.dart';

part 'habit_settings_state.freezed.dart';

@freezed
abstract class HabitSettingsState with _$HabitSettingsState {
  factory HabitSettingsState({
    required HabitDefinition habitDefinition,
    required bool dirty,
    required GlobalKey<FormBuilderState> formKey,
    required List<StoryTag> storyTags,
    required AutoCompleteRule? autoCompleteRule,
    StoryTag? defaultStory,
  }) = _HabitSettingsStateSaved;
}
