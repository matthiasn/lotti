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

    final existingJson = jsonEncode(_canonicalTieBreakJson(existing));
    final incomingJson = jsonEncode(_canonicalTieBreakJson(incoming));
    return incomingJson.compareTo(existingJson) > 0 ? incoming : existing;
  }

  // Builds a canonical map for deterministic tie-breaking when two devices
  // produce edits with identical updatedAt. Sorting keys recursively makes
  // the comparison stable across app versions that may differ in JSON key
  // insertion order. Meta state fields that converge via earliest-non-null
  // merging are stripped so they never participate in the tie-break.
  static Map<String, dynamic> _canonicalTieBreakJson(NotificationEntity e) {
    final json = Map<String, dynamic>.from(e.toJson());
    final meta = Map<String, dynamic>.from(e.meta.toJson())
      ..remove('seenAt')
      ..remove('actedOnAt')
      ..remove('deletedAt')
      ..remove('vectorClock');
    json['meta'] = meta;
    return _canonicalize(json)! as Map<String, dynamic>;
  }

  static Object? _canonicalize(Object? value) {
    if (value is Map) {
      final entries = value.entries.toList()
        ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
      return {
        for (final entry in entries)
          entry.key.toString(): _canonicalize(entry.value),
      };
    }
    if (value is List) {
      return value.map(_canonicalize).toList(growable: false);
    }
    return value;
  }
}
