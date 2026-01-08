import 'dart:async';

import 'package:collection/collection.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/utils/cache_extension.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'linked_entries_controller.g.dart';

@riverpod
class LinkedEntriesController extends _$LinkedEntriesController {
  StreamSubscription<Set<String>>? _updateSubscription;
  final UpdateNotifications _updateNotifications = getIt<UpdateNotifications>();
  final watchedIds = <String>{};

  void listen() {
    _updateSubscription =
        _updateNotifications.updateStream.listen((affectedIds) {
      if (affectedIds.intersection(watchedIds).isNotEmpty) {
        final includeHidden = ref.read(includeHiddenControllerProvider(id: id));

        _fetch(includeHidden: includeHidden).then((latest) {
          if (latest != state.value) {
            state = AsyncData(latest);
          }
        });
      }
    });
  }

  @override
  Future<List<EntryLink>> build({
    required String id,
  }) async {
    ref
      ..onDispose(() => _updateSubscription?.cancel())
      ..cacheFor(entryCacheDuration);

    final includeHidden = ref.watch(includeHiddenControllerProvider(id: id));
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
    final res = await ref.read(journalRepositoryProvider).getLinksFromId(
          id,
          includeHidden: includeHidden,
        );
    watchedIds.addAll(res.map((link) => link.toId));
    return res;
  }

  Future<void> removeLink({required String toId}) async {
    await ref.read(journalRepositoryProvider).removeLink(
          fromId: id,
          toId: toId,
        );
  }

  Future<void> updateLink(EntryLink link) async {
    await ref.read(journalRepositoryProvider).updateLink(link);
  }
}

@riverpod
class IncludeHiddenController extends _$IncludeHiddenController {
  @override
  bool build({required String id}) {
    return false;
  }

  set includeHidden(bool value) {
    state = value;
  }

  bool get includeHidden => state;
}

@riverpod
class IncludeAiEntriesController extends _$IncludeAiEntriesController {
  @override
  bool build({required String id}) {
    return false;
  }

  set includeAiEntries(bool value) {
    state = value;
  }

  bool get includeAiEntries => state;
}

@riverpod
class NewestLinkedIdController extends _$NewestLinkedIdController {
  @override
  Future<String?> build({required String? id}) async {
    if (id == null) {
      return null;
    }

    final provider = linkedEntriesControllerProvider(id: id);
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
@riverpod
List<JournalEntity> resolvedOutgoingLinkedEntries(
  Ref ref,
  String id,
) {
  final linksAsync = ref.watch(linkedEntriesControllerProvider(id: id));
  final links = linksAsync.value ?? [];

  final entities = <JournalEntity>[];
  for (final link in links) {
    final entryAsync = ref.watch(entryControllerProvider(id: link.toId));
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
@riverpod
bool hasNonTaskLinkedEntries(
  Ref ref,
  String id,
) {
  final entities = ref.watch(resolvedOutgoingLinkedEntriesProvider(id));
  return entities.any((entity) => entity is! Task);
}
