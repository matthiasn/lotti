import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';

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

/// One relationship plus its check-ins, newest first.
typedef RelationshipDetail = ({
  RelationshipEntry relationship,
  List<CheckInEntry> checkIns,
});

/// Detail state for one relationship. Resolves to `null` when the id does
/// not (or no longer) point at a live relationship. Reloads when the
/// relationship or any of its check-ins change.
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

  @override
  Future<RelationshipDetail?> build() async {
    _subscription ??= getIt<UpdateNotifications>().updateStream.listen((
      affectedIds,
    ) {
      // A check-in's affectedIds carry its relationship id (the wake-token
      // delta from plan v2 D1), so this single membership test covers both
      // entity edits and check-in writes. The private toggle is separate:
      // this page's person and their check-ins are private-filtered reads,
      // so hiding private entries must resolve an open private person to
      // "no longer tracked" straight away.
      if (affectedIds.contains(_relationshipId) ||
          affectedIds.contains(privateToggleNotification) ||
          affectedIds.contains(
            relationshipEntityUpdateNotification(_relationshipId),
          )) {
        ref.invalidateSelf();
      }
    });
    ref.onDispose(() {
      unawaited(_subscription?.cancel());
      _subscription = null;
    });

    final repository = ref.read(relationshipRepositoryProvider);
    final relationship = await repository.getRelationshipById(_relationshipId);
    if (relationship == null || relationship.isDeleted) return null;
    final checkIns = await repository.getCheckInsForRelationship(
      _relationshipId,
    );
    return (relationship: relationship, checkIns: checkIns);
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
