import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';

final labelsStreamProvider = StreamProvider<List<LabelDefinition>>((ref) {
  final repository = ref.watch(labelsRepositoryProvider);
  return repository.watchLabels();
});

final labelsListControllerProvider =
    NotifierProvider<LabelsListController, AsyncValue<List<LabelDefinition>>>(
  LabelsListController.new,
);

class LabelsListController extends Notifier<AsyncValue<List<LabelDefinition>>> {
  late final LabelsRepository _repository;
  StreamSubscription<List<LabelDefinition>>? _subscription;

  @override
  AsyncValue<List<LabelDefinition>> build() {
    _repository = ref.watch(labelsRepositoryProvider);

    _subscription?.cancel();
    _subscription = _repository.watchLabels().listen(
      (labels) {
        state = AsyncValue.data(labels);
      },
      onError: (Object error, StackTrace stackTrace) {
        state = AsyncValue.error(error, stackTrace);
      },
    );

    ref.onDispose(() {
      _subscription?.cancel();
      _subscription = null;
    });

    return const AsyncValue<List<LabelDefinition>>.loading();
  }

  Future<void> deleteLabel(String id) async {
    try {
      await _repository.deleteLabel(id);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}
