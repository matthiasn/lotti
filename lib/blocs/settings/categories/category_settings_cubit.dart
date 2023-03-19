import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:lotti/blocs/settings/categories/category_settings_state.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';

class CategorySettingsCubit extends Cubit<CategorySettingsState> {
  CategorySettingsCubit(
    this.categoryDefinition, {
    this.context,
  }) : super(
          CategorySettingsState(
            formKey: GlobalKey<FormBuilderState>(),
            categoryDefinition: categoryDefinition,
            dirty: false,
          ),
        );

  final persistenceLogic = getIt<PersistenceLogic>();
  final BuildContext? context;
  CategoryDefinition categoryDefinition;
  bool _dirty = false;

  void _maybePop() {
    if (context != null) {
      Navigator.of(context!).maybePop();
    }
  }

  void setDirty() {
    _dirty = true;
    emitState();
  }

  void setColor(Color color) {
    _dirty = true;
    categoryDefinition = categoryDefinition.copyWith(color: colorToHex(color));
    emitState();
  }

  Future<void> onSavePressed() async {
    state.formKey.currentState!.save();
    if (state.formKey.currentState!.validate()) {
      final formData = state.formKey.currentState?.value;
      final private = formData?['private'] as bool? ?? false;
      final active = formData?['active'] as bool? ?? false;

      final dataType = categoryDefinition.copyWith(
        name: '${formData!['name']}'.trim(),
        private: private,
        active: active,
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
