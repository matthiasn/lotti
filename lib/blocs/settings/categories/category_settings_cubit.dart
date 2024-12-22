import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:lotti/blocs/settings/categories/category_settings_state.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/utils/color.dart';

class CategorySettingsCubit extends Cubit<CategorySettingsState> {
  CategorySettingsCubit(
    this.categoryDefinition, {
    this.context,
  }) : super(
          CategorySettingsState(
            formKey: GlobalKey<FormBuilderState>(),
            categoryDefinition: categoryDefinition,
            dirty: false,
            valid: false,
          ),
        );

  final persistenceLogic = getIt<PersistenceLogic>();
  final BuildContext? context;
  CategoryDefinition categoryDefinition;
  bool _dirty = false;
  bool _valid = false;

  void _maybePop() {
    if (context != null) {
      Navigator.of(context!).maybePop();
    }
  }

  void setDirty() {
    _dirty = true;
    _valid = state.formKey.currentState!.validate();
    emitState();
  }

  void setColor(Color color) {
    categoryDefinition =
        categoryDefinition.copyWith(color: colorToCssHex(color));
    setDirty();
  }

  Future<void> onSavePressed() async {
    state.formKey.currentState!.save();
    if (state.formKey.currentState!.validate()) {
      final formData = state.formKey.currentState?.value;
      final private = formData?['private'] as bool? ?? false;
      final active = formData?['active'] as bool? ?? false;
      final favorite = formData?['favorite'] as bool? ?? false;

      final dataType = categoryDefinition.copyWith(
        name: '${formData!['name']}'.trim(),
        private: private,
        active: active,
        favorite: favorite,
      );

      await persistenceLogic.upsertEntityDefinition(dataType);
      categoryDefinition = dataType;
      _dirty = false;

      emitState();
      _maybePop();
    }
  }

  Future<void> delete() async {
    await persistenceLogic.upsertEntityDefinition(
      categoryDefinition.copyWith(deletedAt: DateTime.now()),
    );
    _maybePop();
  }

  void emitState() {
    emit(
      CategorySettingsState(
        dirty: _dirty,
        valid: _valid,
        formKey: state.formKey,
        categoryDefinition: categoryDefinition,
      ),
    );
  }

  @override
  Future<void> close() async {
    await super.close();
  }
}
