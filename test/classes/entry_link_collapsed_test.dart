import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/features/sync/vector_clock.dart';

void main() {
  group('EntryLink collapsed field', () {
    final dateTime = DateTime(2024);

    test('defaults to null when not specified', () {
      final link = EntryLink.basic(
        id: 'link-1',
        fromId: 'from-1',
        toId: 'to-1',
        createdAt: dateTime,
        updatedAt: dateTime,
        vectorClock: null,
      );

      expect(link.collapsed, isNull);
    });

    test('can be set to true', () {
      final link = EntryLink.basic(
        id: 'link-1',
        fromId: 'from-1',
        toId: 'to-1',
        createdAt: dateTime,
        updatedAt: dateTime,
        vectorClock: null,
        collapsed: true,
      );

      expect(link.collapsed, isTrue);
    });

    test('can be set to false', () {
      final link = EntryLink.basic(
        id: 'link-1',
        fromId: 'from-1',
        toId: 'to-1',
        createdAt: dateTime,
        updatedAt: dateTime,
        vectorClock: null,
        collapsed: false,
      );

      expect(link.collapsed, isFalse);
    });

    test('copyWith updates collapsed field', () {
      final link = EntryLink.basic(
        id: 'link-1',
        fromId: 'from-1',
        toId: 'to-1',
        createdAt: dateTime,
        updatedAt: dateTime,
        vectorClock: null,
      );

      final updated = link.copyWith(collapsed: true);
      expect(updated.collapsed, isTrue);
      expect(updated.id, equals(link.id));
      expect(updated.fromId, equals(link.fromId));
      expect(updated.toId, equals(link.toId));
    });

    test('copyWith toggles collapsed from true to false', () {
      final link = EntryLink.basic(
        id: 'link-1',
        fromId: 'from-1',
        toId: 'to-1',
        createdAt: dateTime,
        updatedAt: dateTime,
        vectorClock: null,
        collapsed: true,
      );

      final toggled = link.copyWith(collapsed: false);
      expect(toggled.collapsed, isFalse);
    });

    test('serializes collapsed=true to JSON', () {
      final link = EntryLink.basic(
        id: 'link-1',
        fromId: 'from-1',
        toId: 'to-1',
        createdAt: dateTime,
        updatedAt: dateTime,
        vectorClock: const VectorClock({'a': 1}),
        collapsed: true,
      );

      final json = link.toJson();
      expect(json['collapsed'], isTrue);
    });

    test('serializes collapsed=null by omitting or setting null', () {
      final link = EntryLink.basic(
        id: 'link-1',
        fromId: 'from-1',
        toId: 'to-1',
        createdAt: dateTime,
        updatedAt: dateTime,
        vectorClock: null,
      );

      final json = link.toJson();
      // collapsed should either be absent or null
      expect(json['collapsed'], isNull);
    });

    test('deserializes collapsed=true from JSON', () {
      final link = EntryLink.basic(
        id: 'link-1',
        fromId: 'from-1',
        toId: 'to-1',
        createdAt: dateTime,
        updatedAt: dateTime,
        vectorClock: null,
        collapsed: true,
      );

      final json = jsonDecode(jsonEncode(link)) as Map<String, dynamic>;
      final deserialized = EntryLink.fromJson(json);

      expect(deserialized.collapsed, isTrue);
    });

    test('deserializes missing collapsed field as null (backward compat)', () {
      // Simulate JSON from an older version without the collapsed field
      final json = <String, dynamic>{
        'runtimeType': 'basic',
        'id': 'link-1',
        'fromId': 'from-1',
        'toId': 'to-1',
        'createdAt': dateTime.toIso8601String(),
        'updatedAt': dateTime.toIso8601String(),
        'vectorClock': null,
        'hidden': null,
        'deletedAt': null,
      };

      final link = EntryLink.fromJson(json);
      expect(link.collapsed, isNull);
    });

    test('roundtrip serialization preserves collapsed field', () {
      final original = EntryLink.basic(
        id: 'link-1',
        fromId: 'from-1',
        toId: 'to-1',
        createdAt: dateTime,
        updatedAt: dateTime,
        vectorClock: const VectorClock({'host': 5}),
        hidden: false,
        collapsed: true,
      );

      final json = jsonEncode(original);
      final restored =
          EntryLink.fromJson(jsonDecode(json) as Map<String, dynamic>);

      expect(restored.collapsed, isTrue);
      expect(restored.hidden, isFalse);
      expect(restored.id, equals(original.id));
      expect(restored.fromId, equals(original.fromId));
      expect(restored.toId, equals(original.toId));
    });

    test('equality: two links differ only by collapsed', () {
      final link1 = EntryLink.basic(
        id: 'link-1',
        fromId: 'from-1',
        toId: 'to-1',
        createdAt: dateTime,
        updatedAt: dateTime,
        vectorClock: null,
        collapsed: false,
      );
      final link2 = link1.copyWith(collapsed: true);

      expect(link1, isNot(equals(link2)));
    });

    test('equality: two links with same collapsed value are equal', () {
      final link1 = EntryLink.basic(
        id: 'link-1',
        fromId: 'from-1',
        toId: 'to-1',
        createdAt: dateTime,
        updatedAt: dateTime,
        vectorClock: null,
        collapsed: true,
      );
      final link2 = EntryLink.basic(
        id: 'link-1',
        fromId: 'from-1',
        toId: 'to-1',
        createdAt: dateTime,
        updatedAt: dateTime,
        vectorClock: null,
        collapsed: true,
      );

      expect(link1, equals(link2));
    });
  });
}
