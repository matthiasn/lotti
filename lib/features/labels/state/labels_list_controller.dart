import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/notification_stream.dart';

final showPrivateEntriesProvider = StreamProvider<bool>(
  (ref) => getIt<JournalDb>().watchConfigFlag('private'),
);

final labelUsageStatsProvider = StreamProvider<Map<String, int>>(
  (ref) => notificationDrivenMapStream(
    notifications: getIt<UpdateNotifications>(),
    notificationKeys: {labelUsageNotification, labelsNotification},
    fetcher: getIt<JournalDb>().getLabelUsageCounts,
  ),
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
  final showPrivate = ref
      .watch(showPrivateEntriesProvider)
      .maybeWhen(
        data: (value) => value,
        orElse: () => false,
      );
  return repository.watchLabels().map(
    (labels) => _visibleLabels(labels, showPrivate),
  );
});

/// Reactive provider that computes the category-scoped set of available labels
/// (global ∪ scoped-to-category) while preserving Riverpod reactivity.
final ProviderFamily<List<LabelDefinition>, String?>
availableLabelsForCategoryProvider =
    Provider.family<List<LabelDefinition>, String?>((ref, categoryId) {
      final cache = getIt<EntitiesCacheService>();
      return cache.filterLabelsForCategory(
        ref
            .watch(labelsStreamProvider)
            .maybeWhen(
              data: (value) => value,
              orElse: () => const <LabelDefinition>[],
            ),
        categoryId,
      );
    });
