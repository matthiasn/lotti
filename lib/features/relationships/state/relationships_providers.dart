import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';

/// The tokens that mean "the relationships list may have changed": any
/// relationship write, any check-in write (recency ordering), and the
/// per-entity update token prefix.
bool _touchesRelationships(Set<String> affectedIds) =>
    affectedIds.contains(relationshipNotification) ||
    affectedIds.contains(checkInNotification) ||
    affectedIds.any((id) => id.startsWith(relationshipEntityUpdatePrefix));

/// All non-deleted relationships, newest tracking start first. Reloads on
/// relationship and check-in writes (local or synced) without flashing the
/// established list — `AsyncNotifier` keeps the previous value while the
/// refetch runs.
class RelationshipsListController
    extends AsyncNotifier<List<RelationshipEntry>> {
  StreamSubscription<Set<String>>? _subscription;

  @override
  Future<List<RelationshipEntry>> build() {
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
    return ref.read(relationshipRepositoryProvider).getRelationships();
  }
}

final relationshipsListControllerProvider =
    AsyncNotifierProvider<RelationshipsListController, List<RelationshipEntry>>(
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
      // entity edits and check-in writes.
      if (affectedIds.contains(_relationshipId) ||
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
relationshipDetailControllerProvider =
    AsyncNotifierProvider.family<
      RelationshipDetailController,
      RelationshipDetail?,
      String
    >(
      RelationshipDetailController.new,
      name: 'relationshipDetailControllerProvider',
    );
