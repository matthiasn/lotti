import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/notification_stream.dart';

/// Streams the global "show private entries" config flag.
///
/// Gates whether private labels are included by [labelsStreamProvider] and the
/// label visibility filters in the UI. Emits `false` until the flag resolves.
final showPrivateEntriesProvider = StreamProvider<bool>(
  (ref) => getIt<JournalDb>().watchConfigFlag('private'),
);

/// Streams per-label usage counts keyed by label ID, sourced from the `labeled`
/// lookup table.
///
/// Refreshes on either a label-usage change (assignment add/remove) or a
/// label-definition change, so the list page subtitles stay accurate as labels
/// are applied or edited.
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

/// Streams all label definitions, filtered by the current private-entries
/// setting.
///
/// Watches [showPrivateEntriesProvider] (defaulting to hiding private labels
/// until it resolves) and removes private labels from the
/// [LabelsRepository.watchLabels] stream via [_visibleLabels]. This is the
/// source of truth that list and picker UIs subscribe to.
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

/// The labels assignable within a given category: global labels (no scope) plus
/// those explicitly scoped to `categoryId`.
///
/// Layered on top of [labelsStreamProvider] (so it inherits private-entry
/// filtering and reactivity) and delegates the scope intersection to
/// `EntitiesCacheService.filterLabelsForCategory`. A `null` categoryId yields
/// global labels only. Used to populate the entry label picker.
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
