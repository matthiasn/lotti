import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/state/linked_entries_activity_filter.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/utils/cache_extension.dart';

/// Loads and live-updates the outgoing [EntryLink]s from entry `id` (the links
/// to the entries shown in its linked-entries list).
///
/// Subscribes to [UpdateNotifications] and re-fetches whenever the source
/// entry or any currently-linked target changes (`watchedIds`), so the list
/// stays current as links are added/removed and target entries are edited.
/// Visibility of hidden links is driven by [IncludeHiddenController] for the
/// same id. Result is cached for `entryCacheDuration`. Also exposes
/// removeLink/updateLink write helpers that delegate to the repository.
final AsyncNotifierProviderFamily<
  LinkedEntriesController,
  List<EntryLink>,
  String
>
linkedEntriesControllerProvider = AsyncNotifierProvider.autoDispose
    .family<LinkedEntriesController, List<EntryLink>, String>(
      LinkedEntriesController.new,
      name: 'linkedEntriesControllerProvider',
    );

class LinkedEntriesController extends AsyncNotifier<List<EntryLink>> {
  LinkedEntriesController([this.id = '']);

  final String id;

  StreamSubscription<Set<String>>? _updateSubscription;
  final UpdateNotifications _updateNotifications = getIt<UpdateNotifications>();
  final watchedIds = <String>{};

  void listen() {
    _updateSubscription = _updateNotifications.updateStream.listen((
      affectedIds,
    ) {
      if (affectedIds.intersection(watchedIds).isNotEmpty) {
        final includeHidden = ref.read(includeHiddenControllerProvider(id));

        _fetch(includeHidden: includeHidden).then((latest) {
          if (latest != state.value) {
            state = AsyncData(latest);
          }
        });
      }
    });
  }

  @override
  Future<List<EntryLink>> build() async {
    ref
      ..onDispose(() => _updateSubscription?.cancel())
      ..cacheFor(entryCacheDuration);

    final includeHidden = ref.watch(includeHiddenControllerProvider(id));
    final res = await _fetch(
      includeHidden: includeHidden,
    );
    watchedIds.add(id);
    listen();
    return res;
  }

  Future<List<EntryLink>> _fetch({
    required bool includeHidden,
  }) async {
    final res = await ref
        .read(journalRepositoryProvider)
        .getLinksFromId(
          id,
          includeHidden: includeHidden,
        );
    watchedIds.addAll(res.map((link) => link.toId));
    return res;
  }

  Future<void> removeLink({required String toId}) async {
    await ref
        .read(journalRepositoryProvider)
        .removeLink(
          fromId: id,
          toId: toId,
        );
  }

  Future<void> updateLink(EntryLink link) async {
    await ref.read(journalRepositoryProvider).updateLink(link);
  }
}

/// Per-entry toggle controlling whether hidden links are included when
/// [LinkedEntriesController] fetches the linked-entries list. Defaults to off.
final NotifierProviderFamily<IncludeHiddenController, bool, String>
includeHiddenControllerProvider = NotifierProvider.autoDispose
    .family<IncludeHiddenController, bool, String>(
      IncludeHiddenController.new,
      name: 'includeHiddenControllerProvider',
    );

class IncludeHiddenController extends Notifier<bool> {
  IncludeHiddenController([this.id = '']);

  final String id;

  @override
  bool build() {
    return false;
  }

  set includeHidden(bool value) {
    state = value;
  }

  bool get includeHidden => state;
}

/// Per-entry toggle controlling whether [AiResponseEntry] entries are shown in
/// the linked-entries list (passed through to the entry detail widget as
/// `showAiEntry`). Defaults to off so AI responses stay collapsed under their
/// source entry unless the user opts in.
final NotifierProviderFamily<IncludeAiEntriesController, bool, String>
includeAiEntriesControllerProvider = NotifierProvider.autoDispose
    .family<IncludeAiEntriesController, bool, String>(
      IncludeAiEntriesController.new,
      name: 'includeAiEntriesControllerProvider',
    );

class IncludeAiEntriesController extends Notifier<bool> {
  IncludeAiEntriesController([this.id = '']);

  final String id;

  @override
  bool build() {
    return false;
  }

  set includeAiEntries(bool value) {
    state = value;
  }

  bool get includeAiEntries => state;
}

/// Per-entry toggle that narrows the linked entries list to flagged
/// entries only (`meta.flag == EntryFlag.import`, the flag toggled via
/// the entry header's flag icon). Defaults to off so all linked entries
/// stay visible until the user opts in.
final NotifierProviderFamily<ShowFlaggedOnlyController, bool, String>
showFlaggedOnlyControllerProvider = NotifierProvider.autoDispose
    .family<ShowFlaggedOnlyController, bool, String>(
      ShowFlaggedOnlyController.new,
      name: 'showFlaggedOnlyControllerProvider',
    );

class ShowFlaggedOnlyController extends Notifier<bool> {
  ShowFlaggedOnlyController([this.id = '']);

  final String id;

  @override
  bool build() {
    return false;
  }

  set showFlaggedOnly(bool value) {
    state = value;
  }

  bool get showFlaggedOnly => state;
}

/// Per-entry toggle state for the activity filter pills shown above the
/// linked entries list (Timer / Audio / Images / Code). Defaults to all
/// kinds active so existing behavior is preserved when the bar mounts.
final NotifierProviderFamily<
  LinkedEntriesActivityFilterController,
  Set<LinkedEntryActivityFilter>,
  String
>
linkedEntriesActivityFilterControllerProvider = NotifierProvider.autoDispose
    .family<
      LinkedEntriesActivityFilterController,
      Set<LinkedEntryActivityFilter>,
      String
    >(
      LinkedEntriesActivityFilterController.new,
      name: 'linkedEntriesActivityFilterControllerProvider',
    );

class LinkedEntriesActivityFilterController
    extends Notifier<Set<LinkedEntryActivityFilter>> {
  LinkedEntriesActivityFilterController([this.id = '']);

  final String id;

  @override
  Set<LinkedEntryActivityFilter> build() {
    return LinkedEntryActivityFilter.values.toSet();
  }

  void toggle(LinkedEntryActivityFilter kind) {
    final next = {...state};
    if (!next.add(kind)) next.remove(kind);
    state = next;
  }
}

/// Sort order applied to the linked entries list.
enum LinkedEntriesSortOrder { newestFirst, oldestFirst }

/// Per-entry sort order for the linked entries list. Defaults to newest
/// first, matching pre-filter-bar behavior.
final NotifierProviderFamily<
  LinkedEntriesSortController,
  LinkedEntriesSortOrder,
  String
>
linkedEntriesSortControllerProvider = NotifierProvider.autoDispose
    .family<LinkedEntriesSortController, LinkedEntriesSortOrder, String>(
      LinkedEntriesSortController.new,
      name: 'linkedEntriesSortControllerProvider',
    );

class LinkedEntriesSortController extends Notifier<LinkedEntriesSortOrder> {
  LinkedEntriesSortController([this.id = '']);

  final String id;

  @override
  LinkedEntriesSortOrder build() {
    return LinkedEntriesSortOrder.newestFirst;
  }

  // ignore: avoid_setters_without_getters
  set order(LinkedEntriesSortOrder value) => state = value;
}

/// Returns the linked entries for id sorted by the linked entity's
/// `meta.dateFrom`, applying the user's selected [LinkedEntriesSortOrder].
///
/// Sorting by `dateFrom` matches the timestamp shown for each linked
/// entry in the UI, so "Newest first" puts the entry with the latest
/// `dateFrom` at the top — independent of when the link was created.
/// Links whose target entity has not yet resolved fall back to
/// `link.createdAt` so the order remains stable while data loads.
final ProviderFamily<List<EntryLink>, String> sortedLinkedEntriesProvider =
    Provider.autoDispose.family<List<EntryLink>, String>(
      sortedLinkedEntries,
      name: 'sortedLinkedEntriesProvider',
    );
List<EntryLink> sortedLinkedEntries(Ref ref, String id) {
  final links =
      ref.watch(linkedEntriesControllerProvider(id)).value ?? const [];
  if (links.isEmpty) {
    return const [];
  }

  final sortOrder = ref.watch(linkedEntriesSortControllerProvider(id));

  // Pre-resolve sort keys in a single pass. Watching inside the sort
  // comparator would (a) re-watch O(N log N) times and (b) miss
  // dependencies for any pair the algorithm happens to skip, leaving
  // the provider stale when those entries' dateFrom values change.
  final sortKeys = <String, DateTime>{
    for (final link in links)
      link.id:
          ref
              .watch(entryControllerProvider(link.toId))
              .value
              ?.entry
              ?.meta
              .dateFrom ??
          link.createdAt,
  };

  // Tie-breakers (link.createdAt, then link.id) keep the order stable
  // across rebuilds when two entries share the same dateFrom. Without
  // them the row order can jitter on every sort.
  final sign = sortOrder == LinkedEntriesSortOrder.newestFirst ? -1 : 1;
  final sorted = [...links]
    ..sort((a, b) {
      final primary = sortKeys[a.id]!.compareTo(sortKeys[b.id]!);
      if (primary != 0) return sign * primary;
      final secondary = a.createdAt.compareTo(b.createdAt);
      if (secondary != 0) return sign * secondary;
      return a.id.compareTo(b.id);
    });
  return sorted;
}

/// Resolves the `toId` of the most recently *created* outgoing link from
/// entry `id` (by `EntryLink.createdAt`), or null when `id` is null or has no
/// links. Used by the duration widget to decide which linked timer entry shows
/// the record button.
final AsyncNotifierProviderFamily<NewestLinkedIdController, String?, String?>
newestLinkedIdControllerProvider = AsyncNotifierProvider.autoDispose
    .family<NewestLinkedIdController, String?, String?>(
      NewestLinkedIdController.new,
      name: 'newestLinkedIdControllerProvider',
    );

class NewestLinkedIdController extends AsyncNotifier<String?> {
  NewestLinkedIdController([this.id]);

  final String? id;

  @override
  Future<String?> build() async {
    final id = this.id;
    if (id == null) {
      return null;
    }

    final provider = linkedEntriesControllerProvider(id);
    final entryLinks = ref.watch(provider).value;

    final newestLinkedId = entryLinks
        ?.sortedBy((entryLink) => entryLink.createdAt)
        .reversed
        .firstOrNull
        ?.toId;

    return newestLinkedId;
  }
}

/// Provider that resolves outgoing entry links to their actual JournalEntity objects.
///
/// This centralizes the resolution logic so that downstream providers can
/// filter/process the resolved entities without needing to watch individual
/// entryControllerProviders in loops.
final ProviderFamily<List<JournalEntity>, String>
resolvedOutgoingLinkedEntriesProvider = Provider.autoDispose
    .family<List<JournalEntity>, String>(
      resolvedOutgoingLinkedEntries,
      name: 'resolvedOutgoingLinkedEntriesProvider',
    );
List<JournalEntity> resolvedOutgoingLinkedEntries(
  Ref ref,
  String id,
) {
  final linksAsync = ref.watch(linkedEntriesControllerProvider(id));
  final links = linksAsync.value ?? [];

  final entities = <JournalEntity>[];
  for (final link in links) {
    final entryAsync = ref.watch(entryControllerProvider(link.toId));
    final entry = entryAsync.value?.entry;
    if (entry != null) {
      entities.add(entry);
    }
  }

  return entities;
}

/// Provider that checks if there are any non-Task entries in the linked entries.
///
/// Used by LinkedEntriesWidget to determine whether to show the "Linked Entries"
/// section when hideTaskEntries is true.
final ProviderFamily<bool, String> hasNonTaskLinkedEntriesProvider = Provider
    .autoDispose
    .family<bool, String>(
      hasNonTaskLinkedEntries,
      name: 'hasNonTaskLinkedEntriesProvider',
    );
bool hasNonTaskLinkedEntries(
  Ref ref,
  String id,
) {
  final entities = ref.watch(resolvedOutgoingLinkedEntriesProvider(id));
  return entities.any((entity) => entity is! Task);
}
