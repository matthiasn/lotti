import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'save_button_controller2.g.dart';

@riverpod
class SaveButtonController2 extends _$SaveButtonController2 {
  SaveButtonController2();
  String _id = '';
  final childIds = <String>{};
  bool _isEntryDirty = false;

  @override
  Future<bool?> build({
    required String id,
    String? linkedFromId,
  }) async {
    final state = ref.watch(entryControllerProvider(id: id)).value;
    _id = id;
    final isEntryDirty = state?.map(
          dirty: (_) => true,
          saved: (_) => false,
        ) ??
        false;

    if (isEntryDirty != _isEntryDirty) {
      _isEntryDirty = isEntryDirty;

      if (isEntryDirty && linkedFromId != null) {
        final notifier = ref.read(
          SaveButtonController2Provider(
            id: linkedFromId,
          ).notifier,
        );
        await notifier.setDirtyChild(id);
      }
    }

    return isEntryDirty;
  }

  Future<void> save({Duration? estimate}) async {
    if (_isEntryDirty) {
      final state = ref.read(entryControllerProvider(id: _id).notifier);
      await state.save(estimate: estimate);
    }
  }

  Future<void> setDirtyChild(String childEntryId) async {
    debugPrint('setDirtyChild: $_id $childEntryId');
    childIds.add(childEntryId);
    state = const AsyncValue.data(true);
  }
}
