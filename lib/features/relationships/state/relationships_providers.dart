import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/utils/cache_extension.dart';

/// The tokens that mean "the relationships list may have changed": any
/// relationship write, any check-in write (a check-in changes the list's
/// recency ordering and subtitle), the per-entity update token prefix, and
/// a flip of the private-entries flag.
///
/// The private toggle matters because every relationship read is
/// private-filtered: without it, a list loaded while private entries were
/// shown would keep rendering those names until the next write or restart.
bool _touchesRelationships(Set<String> affectedIds) =>
    affectedIds.contains(relationshipNotification) ||
    affectedIds.contains(checkInNotification) ||
    affectedIds.contains(privateToggleNotification) ||
    affectedIds.any((id) => id.startsWith(relationshipEntityUpdatePrefix));

/// All non-deleted relationships with their latest check-in time, most
/// recently interacted-with first. Reloads on relationship and check-in
/// writes (local or synced) without flashing the established list —
/// `AsyncNotifier` keeps the previous value while the refetch runs.
class RelationshipsListController
    extends AsyncNotifier<List<RelationshipListItem>> {
  StreamSubscription<Set<String>>? _subscription;

  @override
  Future<List<RelationshipListItem>> build() {
    _subscription ??= getIt<UpdateNotifications>().updateStream.listen((
      affectedIds,
    ) {
      if (_touchesRelationships(affectedIds)) {
        ref.invalidateSelf();
      }
    });
    ref.onDispose(() {
      unawaited(_subscription?.cancel());
      _subscription = null;
    });
    return ref.read(relationshipRepositoryProvider).getRelationshipsByRecency();
  }
}

final relationshipsListControllerProvider =
    AsyncNotifierProvider<
      RelationshipsListController,
      List<RelationshipListItem>
    >(
      RelationshipsListController.new,
      name: 'relationshipsListControllerProvider',
    );

/// One relationship plus its check-ins (newest first) and linked tasks.
typedef RelationshipDetail = ({
  RelationshipEntry relationship,
  List<CheckInEntry> checkIns,
  List<Task> linkedTasks,
});

/// Detail state for one relationship. Resolves to `null` when the id does
/// not (or no longer) point at a live relationship. Reloads when the
/// relationship, any of its check-ins, or any currently linked task changes.
///
/// Auto-disposes with the page that watches it: one instance exists per
/// person id, and each keeps an `UpdateNotifications` subscription alive, so
/// a session that browsed many people would otherwise accumulate a listener
/// per visited id.
class RelationshipDetailController extends AsyncNotifier<RelationshipDetail?> {
  RelationshipDetailController([String? relationshipId])
    : _relationshipId = relationshipId ?? '';

  final String _relationshipId;
  StreamSubscription<Set<String>>? _subscription;

  /// Ids of the tasks the last build saw as linked, so a status or title
  /// edit on the task side refreshes the section without a relationship
  /// write. Link/unlink writes notify the relationship id itself.
  var _linkedTaskIds = const <String>{};

  @override
  Future<RelationshipDetail?> build() async {
    ref
      ..onDispose(() {
        unawaited(_subscription?.cancel());
        _subscription = null;
      })
      ..cacheFor(entryCacheDuration);

    _subscription ??= getIt<UpdateNotifications>().updateStream.listen((
      affectedIds,
    ) {
      // A check-in's affectedIds carry its relationship id (the wake-token
      // delta from plan v2 D1), and every entity's affectedIds carry its own
      // id, so the membership tests cover relationship edits, check-in
      // writes, link writes and linked-task edits — local or synced. The
      // private toggle is separate:
      // this page's person and their check-ins are private-filtered reads,
      // so hiding private entries must resolve an open private person to
      // "no longer tracked" straight away.
      if (affectedIds.contains(_relationshipId) ||
          affectedIds.contains(privateToggleNotification) ||
          affectedIds.contains(
            relationshipEntityUpdateNotification(_relationshipId),
          ) ||
          affectedIds.any(_linkedTaskIds.contains)) {
        ref.invalidateSelf();
      }
    });

    final repository = ref.read(relationshipRepositoryProvider);
    final relationship = await repository.getRelationshipById(_relationshipId);
    if (relationship == null || relationship.isDeleted) return null;
    final checkIns = await repository.getCheckInsForRelationship(
      _relationshipId,
    );
    final linkedTasks = await repository.getLinkedTasks(_relationshipId);
    _linkedTaskIds = {for (final task in linkedTasks) task.id};
    return (
      relationship: relationship,
      checkIns: checkIns,
      linkedTasks: linkedTasks,
    );
  }
}

final AsyncNotifierProviderFamily<
  RelationshipDetailController,
  RelationshipDetail?,
  String
>
relationshipDetailControllerProvider = AsyncNotifierProvider.autoDispose
    .family<RelationshipDetailController, RelationshipDetail?, String>(
      RelationshipDetailController.new,
      name: 'relationshipDetailControllerProvider',
    );
