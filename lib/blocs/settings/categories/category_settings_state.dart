import 'package:flutter/widgets.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/classes/entity_definitions.dart';

part 'category_settings_state.freezed.dart';

@freezed
class CategorySettingsState with _$CategorySettingsState {
  factory CategorySettingsState({
    required CategoryDefinition categoryDefinition,
    required bool dirty,
    required GlobalKey<FormBuilderState> formKey,
  }) = _CategorySettingsState;
}
