import 'dart:convert';

import 'package:lotti/classes/notification_entity.dart';
import 'package:lotti/features/sync/vector_clock.dart';

class NotificationMerge {
  const NotificationMerge._();

  static NotificationEntity mergeFull(
    NotificationEntity existing,
    NotificationEntity incoming,
  ) {
    final contentWinner = _chooseContentWinner(existing, incoming);
    final existingMeta = existing.meta;
    final incomingMeta = incoming.meta;
    final winnerMeta = contentWinner.meta;

    return contentWinner.copyWithMeta(
      winnerMeta.copyWith(
        seenAt: earliestNonNull(existingMeta.seenAt, incomingMeta.seenAt),
        actedOnAt: earliestNonNull(
          existingMeta.actedOnAt,
          incomingMeta.actedOnAt,
        ),
        deletedAt: earliestNonNull(
          existingMeta.deletedAt,
          incomingMeta.deletedAt,
        ),
        vectorClock: VectorClock.merge(
          existingMeta.vectorClock,
          incomingMeta.vectorClock,
        ),
      ),
    );
  }

  static NotificationEntity mergeState(
    NotificationEntity existing, {
    DateTime? seenAt,
    DateTime? actedOnAt,
    DateTime? deletedAt,
    VectorClock? vectorClock,
    String? originatingHostId,
  }) {
    final meta = existing.meta;
    final mergedMeta = meta.copyWith(
      seenAt: earliestNonNull(meta.seenAt, seenAt),
      actedOnAt: earliestNonNull(meta.actedOnAt, actedOnAt),
      deletedAt: earliestNonNull(meta.deletedAt, deletedAt),
      vectorClock: vectorClock == null
          ? meta.vectorClock
          : VectorClock.merge(meta.vectorClock, vectorClock),
      originatingHostId: originatingHostId?.isNotEmpty ?? false
          ? originatingHostId!
          : meta.originatingHostId,
    );
    return existing.copyWithMeta(mergedMeta);
  }

  static DateTime? earliestNonNull(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isBefore(b) ? a : b;
  }

  static bool same(NotificationEntity left, NotificationEntity right) {
    return left == right;
  }

  static NotificationEntity _chooseContentWinner(
    NotificationEntity existing,
    NotificationEntity incoming,
  ) {
    final updatedComparison = existing.meta.updatedAt.compareTo(
      incoming.meta.updatedAt,
    );
    if (updatedComparison < 0) return incoming;
    if (updatedComparison > 0) return existing;

    final existingJson = jsonEncode(_tieBreakJson(existing));
    final incomingJson = jsonEncode(_tieBreakJson(incoming));
    return incomingJson.compareTo(existingJson) > 0 ? incoming : existing;
  }

  static Map<String, dynamic> _tieBreakJson(NotificationEntity entity) {
    final json =
        jsonDecode(jsonEncode(entity.toJson())) as Map<String, dynamic>;
    final meta =
        Map<String, dynamic>.from(
            json['meta'] as Map<String, dynamic>,
          )
          ..remove('seenAt')
          ..remove('actedOnAt')
          ..remove('deletedAt')
          ..remove('vectorClock');
    json['meta'] = meta;
    return json;
  }
}
