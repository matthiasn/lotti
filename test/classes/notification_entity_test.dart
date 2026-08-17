import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/notification_entity.dart';
import 'package:lotti/features/sync/vector_clock.dart';

void main() {
  group('NotificationEntityFields', () {
    test('exposes meta-derived getters for taskSuggestion', () {
      final entity = _suggestion(
        id: 'sg-1',
        linkedTaskId: 'task-1',
        title: 'Suggestion title',
        body: 'Suggestion body',
      );

      expect(entity.id, 'sg-1');
      expect(entity.meta.id, 'sg-1');
      expect(entity.title, 'Suggestion title');
      expect(entity.body, 'Suggestion body');
      expect(entity.type, 'taskSuggestion');
      expect(entity.linkedEntityId, 'task-1');
    });

    test('exposes meta-derived getters for taskOverdue', () {
      final entity = _overdue(
        id: 'od-1',
        linkedTaskId: 'task-2',
        title: 'Overdue title',
        body: 'Overdue body',
      );

      expect(entity.id, 'od-1');
      expect(entity.title, 'Overdue title');
      expect(entity.body, 'Overdue body');
      expect(entity.type, 'taskOverdue');
      expect(entity.linkedEntityId, 'task-2');
    });

    test('copyWithMeta swaps meta while preserving variant content', () {
      final entity = _suggestion(
        id: 'sg-2',
        linkedTaskId: 'task-3',
        title: 'Original',
        body: 'Body',
      );
      final replacement = entity.meta.copyWith(
        seenAt: DateTime.utc(2026, 5, 17, 11),
        vectorClock: const VectorClock({'host-b': 5}),
      );

      final updated = entity.copyWithMeta(replacement);

      expect(updated, isA<TaskSuggestionNotification>());
      final updatedSuggestion = updated as TaskSuggestionNotification;
      expect(updatedSuggestion.linkedTaskId, 'task-3');
      expect(updatedSuggestion.title, 'Original');
      expect(updatedSuggestion.body, 'Body');
      expect(updatedSuggestion.suggestionCount, 2);
      expect(updated.meta.seenAt, DateTime.utc(2026, 5, 17, 11));
      expect(updated.meta.vectorClock, const VectorClock({'host-b': 5}));
    });

    test('exposes meta-derived getters for relationshipCheckIn', () {
      final entity = _checkIn(
        id: 'ci-1',
        linkedRelationshipId: 'rel-7',
        title: 'Check in with Anna?',
        body: 'A good moment to reach out.',
      );

      expect(entity.id, 'ci-1');
      expect(entity.title, 'Check in with Anna?');
      expect(entity.body, 'A good moment to reach out.');
      expect(entity.type, 'relationshipCheckIn');
      // The shared getter answers for this variant too — which is exactly why
      // consumers must switch on the union rather than read it and assume a
      // task (see NotificationScheduler._deepLinkFor).
      expect(entity.linkedEntityId, 'rel-7');
    });

    test('copyWithMeta preserves the relationshipCheckIn variant', () {
      final entity = _checkIn(
        id: 'ci-2',
        linkedRelationshipId: 'rel-8',
        title: 'Title',
        body: 'Body',
      );
      final replacement = entity.meta.copyWith(
        deletedAt: DateTime.utc(2026, 5, 17, 16),
      );

      final updated = entity.copyWithMeta(replacement);

      expect(updated, isA<RelationshipCheckInNotification>());
      final updatedCheckIn = updated as RelationshipCheckInNotification;
      expect(updatedCheckIn.linkedRelationshipId, 'rel-8');
      expect(updatedCheckIn.title, 'Title');
      expect(updatedCheckIn.body, 'Body');
      expect(updated.meta.deletedAt, DateTime.utc(2026, 5, 17, 16));
    });

    test('copyWithMeta preserves the overdue variant', () {
      final entity = _overdue(
        id: 'od-2',
        linkedTaskId: 'task-4',
        title: 'Hello',
        body: 'World',
      );
      final replacement = entity.meta.copyWith(
        deletedAt: DateTime.utc(2026, 5, 17, 12),
      );

      final updated = entity.copyWithMeta(replacement);

      expect(updated, isA<TaskOverdueNotification>());
      final updatedOverdue = updated as TaskOverdueNotification;
      expect(updatedOverdue.linkedTaskId, 'task-4');
      expect(updatedOverdue.title, 'Hello');
      expect(updatedOverdue.body, 'World');
      expect(updated.meta.deletedAt, DateTime.utc(2026, 5, 17, 12));
    });
  });

  group('NotificationMeta standalone round-trip', () {
    NotificationMeta roundTrip(NotificationMeta meta) =>
        NotificationMeta.fromJson(
          jsonDecode(jsonEncode(meta.toJson())) as Map<String, dynamic>,
        );

    test('serializes every field including the optional DateTimes', () {
      final meta = NotificationMeta(
        id: 'meta-1',
        createdAt: DateTime.utc(2026, 5, 17, 8),
        updatedAt: DateTime.utc(2026, 5, 17, 9),
        scheduledFor: DateTime.utc(2026, 5, 17, 12),
        vectorClock: const VectorClock({'host': 3, 'shared': 7}),
        originatingHostId: 'host-1',
        seenAt: DateTime.utc(2026, 5, 17, 13),
        actedOnAt: DateTime.utc(2026, 5, 17, 14),
        deletedAt: DateTime.utc(2026, 5, 17, 15),
        category: 'cat-9',
      );

      final decoded = roundTrip(meta);
      expect(decoded, meta);
      expect(decoded.scheduledFor, meta.scheduledFor);
      expect(decoded.vectorClock, meta.vectorClock);
    });

    test('optional fields survive as null', () {
      final meta = NotificationMeta(
        id: 'meta-2',
        createdAt: DateTime.utc(2026, 5, 17, 8),
        updatedAt: DateTime.utc(2026, 5, 17, 9),
        scheduledFor: DateTime.utc(2026, 5, 17, 12),
        vectorClock: const VectorClock({'host': 1}),
        originatingHostId: 'host-2',
      );

      final decoded = roundTrip(meta);
      expect(decoded, meta);
      expect(decoded.seenAt, isNull);
      expect(decoded.actedOnAt, isNull);
      expect(decoded.deletedAt, isNull);
      expect(decoded.category, isNull);
    });
  });

  group('NotificationEntity JSON round-trip', () {
    glados.Glados<_GeneratedEntity>(
      glados.any.notificationEntity,
      glados.ExploreConfig(numRuns: 80),
    ).test('round-trips through fromJson/toJson', (generated) {
      final entity = generated.entity;

      final decoded = NotificationEntity.fromJson(
        jsonDecode(jsonEncode(entity.toJson())) as Map<String, dynamic>,
      );

      expect(decoded, entity);
      expect(decoded.type, entity.type);
      expect(decoded.title, entity.title);
      expect(decoded.body, entity.body);
      expect(decoded.linkedEntityId, entity.linkedEntityId);
      expect(decoded.meta, entity.meta);
    }, tags: 'glados');
  });

  // The union discriminator is the sync wire format. Renaming a variant would
  // make every already-synced row of that kind undecodable on upgrade, so the
  // strings are pinned here rather than left to whatever freezed emits.
  group('NotificationEntity wire compatibility', () {
    test('discriminators match the persisted type column', () {
      final rows = <NotificationEntity, String>{
        _suggestion(
          id: 'a',
          linkedTaskId: 't',
          title: 'x',
          body: 'y',
        ): 'taskSuggestion',
        _overdue(
          id: 'b',
          linkedTaskId: 't',
          title: 'x',
          body: 'y',
        ): 'taskOverdue',
        _checkIn(
          id: 'c',
          linkedRelationshipId: 'r',
          title: 'x',
          body: 'y',
        ): 'relationshipCheckIn',
      };

      for (final row in rows.entries) {
        expect(row.key.toJson()['runtimeType'], row.value);
        expect(row.key.type, row.value);
      }
    });

    test('a variant this build does not know throws rather than guessing', () {
      // This is what an older peer does when a newer one syncs a
      // relationshipCheckIn row. The sync processor turns the throw into
      // `UnrecoverableSyncPayloadException` and skips the event, so the row is
      // dropped with a log rather than retried forever — the mixed-fleet
      // degradation path this variant relies on.
      final json =
          jsonDecode(
                jsonEncode(
                  _checkIn(
                    id: 'c',
                    linkedRelationshipId: 'r',
                    title: 'x',
                    body: 'y',
                  ).toJson(),
                ),
              )
              as Map<String, dynamic>;
      json['runtimeType'] = 'somethingFromTheFuture';

      expect(() => NotificationEntity.fromJson(json), throwsA(isA<Object>()));
    });
  });
}

class _GeneratedEntity {
  const _GeneratedEntity({
    required this.variantSlot,
    required this.idSlot,
    required this.suggestionCountSlot,
    required this.seenSlot,
    required this.actedSlot,
    required this.deletedSlot,
    required this.categorySlot,
  });

  final int variantSlot;
  final int idSlot;
  final int suggestionCountSlot;
  final int seenSlot;
  final int actedSlot;
  final int deletedSlot;
  final int categorySlot;

  NotificationEntity get entity {
    final created = DateTime.utc(2026, 5, 17, 8);
    final updated = DateTime.utc(2026, 5, 17, 9);
    final scheduled = DateTime.utc(2026, 5, 17, 12);
    final meta = NotificationMeta(
      id: 'gen-$idSlot',
      createdAt: created,
      updatedAt: updated,
      scheduledFor: scheduled,
      seenAt: _optional(seenSlot, 10),
      actedOnAt: _optional(actedSlot, 11),
      deletedAt: _optional(deletedSlot, 13),
      vectorClock: VectorClock({
        'host': idSlot + 1,
        'shared': suggestionCountSlot,
      }),
      originatingHostId: 'host-$idSlot',
      category: _category(categorySlot),
    );

    // Modulo three, so the generator reaches every variant of the union
    // rather than only the two it had when it was written.
    return switch (variantSlot % 3) {
      0 => NotificationEntity.taskSuggestion(
        meta: meta,
        linkedTaskId: 'task-$idSlot',
        suggestionCount: suggestionCountSlot + 1,
        title: 'Title $idSlot',
        body: 'Body $idSlot',
      ),
      1 => NotificationEntity.taskOverdue(
        meta: meta,
        linkedTaskId: 'task-$idSlot',
        title: 'Title $idSlot',
        body: 'Body $idSlot',
      ),
      _ => NotificationEntity.relationshipCheckIn(
        meta: meta,
        linkedRelationshipId: 'rel-$idSlot',
        title: 'Title $idSlot',
        body: 'Body $idSlot',
      ),
    };
  }
}

extension _AnyNotificationEntity on glados.Any {
  glados.Generator<int> get _slot => glados.IntAnys(this).intInRange(0, 9);

  glados.Generator<_GeneratedEntity> get notificationEntity =>
      glados.CombinableAny(this).combine7(
        _slot,
        _slot,
        _slot,
        _slot,
        _slot,
        _slot,
        _slot,
        (
          int variantSlot,
          int idSlot,
          int suggestionCountSlot,
          int seenSlot,
          int actedSlot,
          int deletedSlot,
          int categorySlot,
        ) => _GeneratedEntity(
          variantSlot: variantSlot,
          idSlot: idSlot,
          suggestionCountSlot: suggestionCountSlot,
          seenSlot: seenSlot,
          actedSlot: actedSlot,
          deletedSlot: deletedSlot,
          categorySlot: categorySlot,
        ),
      );
}

DateTime? _optional(int slot, int hour) {
  if (slot == 0) return null;
  return DateTime.utc(2026, 5, 17, hour, slot);
}

String? _category(int slot) {
  if (slot == 0) return null;
  return 'cat-$slot';
}

NotificationEntity _suggestion({
  required String id,
  required String linkedTaskId,
  required String title,
  required String body,
}) {
  final timestamp = DateTime.utc(2026, 5, 17, 8);
  return NotificationEntity.taskSuggestion(
    meta: NotificationMeta(
      id: id,
      createdAt: timestamp,
      updatedAt: timestamp,
      scheduledFor: timestamp,
      vectorClock: const VectorClock({'host-a': 1}),
      originatingHostId: 'host-a',
    ),
    linkedTaskId: linkedTaskId,
    suggestionCount: 2,
    title: title,
    body: body,
  );
}

NotificationEntity _overdue({
  required String id,
  required String linkedTaskId,
  required String title,
  required String body,
}) {
  final timestamp = DateTime.utc(2026, 5, 17, 8);
  return NotificationEntity.taskOverdue(
    meta: NotificationMeta(
      id: id,
      createdAt: timestamp,
      updatedAt: timestamp,
      scheduledFor: timestamp,
      vectorClock: const VectorClock({'host-a': 1}),
      originatingHostId: 'host-a',
    ),
    linkedTaskId: linkedTaskId,
    title: title,
    body: body,
  );
}

NotificationEntity _checkIn({
  required String id,
  required String linkedRelationshipId,
  required String title,
  required String body,
}) {
  final timestamp = DateTime.utc(2026, 5, 17, 8);
  return NotificationEntity.relationshipCheckIn(
    meta: NotificationMeta(
      id: id,
      createdAt: timestamp,
      updatedAt: timestamp,
      scheduledFor: timestamp,
      vectorClock: const VectorClock({'host-a': 1}),
      originatingHostId: 'host-a',
    ),
    linkedRelationshipId: linkedRelationshipId,
    title: title,
    body: body,
  );
}
