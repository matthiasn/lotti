import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/utils/cache_extension.dart';

/// The tokens that mean "the relationships list may have changed": any
/// relationship write and any check-in write (a check-in changes the list's
/// recency ordering and subtitle). Both are emitted by `affectedIds`, so
/// this covers local edits and synced ones alike.
bool _touchesRelationships(Set<String> affectedIds) =>
    affectedIds.contains(relationshipNotification) ||
    affectedIds.contains(checkInNotification);

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
      // delta from plan v2 D1) and every entity's affectedIds carry its own
      // id, so this single membership test covers relationship edits, check-in
      // writes and link writes alike — local or synced.
      if (affectedIds.contains(_relationshipId) ||
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
