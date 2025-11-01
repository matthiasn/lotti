import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';

final showPrivateEntriesProvider = StreamProvider<bool>(
    (ref) => getIt<JournalDb>().watchConfigFlag('private'));

final labelUsageStatsProvider = StreamProvider<Map<String, int>>(
  (ref) => getIt<JournalDb>().watchLabelUsageCounts(),
);

List<LabelDefinition> _visibleLabels(
  List<LabelDefinition> labels,
  bool showPrivate,
) {
  if (showPrivate) {
    return labels;
  }
  return labels.where((label) => !(label.private ?? false)).toList();
}

final labelsStreamProvider = StreamProvider<List<LabelDefinition>>((ref) {
  final repository = ref.watch(labelsRepositoryProvider);
  final showPrivate = ref.watch(showPrivateEntriesProvider).maybeWhen(
        data: (value) => value,
        orElse: () => false,
      );
  return repository.watchLabels().map(
        (labels) => _visibleLabels(labels, showPrivate),
      );
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
    final showPrivate = ref.watch(showPrivateEntriesProvider).maybeWhen(
          data: (value) => value,
          orElse: () => false,
        );

    _subscription?.cancel();
    _subscription = _repository.watchLabels().listen(
      (labels) {
        state = AsyncValue.data(_visibleLabels(labels, showPrivate));
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

/// Reactive provider that computes the category-scoped set of available labels
/// (global ∪ scoped-to-category) while preserving Riverpod reactivity.
final ProviderFamily<List<LabelDefinition>, String?>
    availableLabelsForCategoryProvider =
    Provider.family<List<LabelDefinition>, String?>((ref, categoryId) {
  final cache = getIt<EntitiesCacheService>();
  return cache.filterLabelsForCategory(
    ref.watch(labelsStreamProvider).maybeWhen(
          data: (value) => value,
          orElse: () => const <LabelDefinition>[],
        ),
    categoryId,
    includePrivate: cache.showPrivateEntries,
  );
});
