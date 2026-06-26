import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';

final AsyncNotifierProviderFamily<SaveButtonController, bool?, String>
saveButtonControllerProvider = AsyncNotifierProvider.autoDispose
    .family<SaveButtonController, bool?, String>(
      SaveButtonController.new,
      name: 'saveButtonControllerProvider',
    );

class SaveButtonController extends AsyncNotifier<bool?> {
  SaveButtonController([this.id = '']);

  final String id;
  String _id = '';

  @override
  Future<bool?> build() async {
    final state = ref.watch(entryControllerProvider(id)).value;
    _id = id;
    final unsaved = state?.map(
      dirty: (_) => true,
      saved: (_) => false,
    );

    return unsaved;
  }

  Future<void> save({Duration? estimate}) async {
    final state = ref.read(entryControllerProvider(_id).notifier);
    await state.save(estimate: estimate);
  }
}
