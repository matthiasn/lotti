import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/features/sync/vector_clock.dart';

import 'project_test_generators.dart';

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
      final restored = EntryLink.fromJson(
        jsonDecode(json) as Map<String, dynamic>,
      );

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

    glados.Glados(
      glados.any.generatedEntryLink,
      glados.ExploreConfig(numRuns: 160),
    ).test('round-trips generated link variants through JSON', (scenario) {
      final link = scenario.link;

      final restored = EntryLink.fromJson(
        jsonDecode(jsonEncode(link.toJson())) as Map<String, dynamic>,
      );

      expect(restored, equals(link), reason: '$scenario');
      expect(restored.collapsed, link.collapsed, reason: '$scenario');
      expect(restored.hidden, link.hidden, reason: '$scenario');
      expect(restored.runtimeType, link.runtimeType, reason: '$scenario');
    }, tags: 'glados');
  });

  final projectTestDate = DateTime(2024, 3, 15, 10, 30);

  group('EntryLink.project', () {
    test('round-trip JSON serialization', () {
      final link = EntryLink.project(
        id: 'link-001',
        fromId: 'project-001',
        toId: 'task-001',
        createdAt: projectTestDate,
        updatedAt: projectTestDate,
        vectorClock: null,
      );

      final json = jsonDecode(jsonEncode(link)) as Map<String, dynamic>;
      final restored = EntryLink.fromJson(json);

      expect(restored, isA<ProjectLink>());
      final restoredLink = restored as ProjectLink;
      expect(restoredLink.id, 'link-001');
      expect(restoredLink.fromId, 'project-001');
      expect(restoredLink.toId, 'task-001');
    });

    test('linkedDbEntity produces correct type', () {
      final link = EntryLink.project(
        id: 'link-001',
        fromId: 'project-001',
        toId: 'task-001',
        createdAt: projectTestDate,
        updatedAt: projectTestDate,
        vectorClock: null,
      );

      final dbLink = linkedDbEntity(link);
      expect(dbLink.type, 'ProjectLink');
      expect(dbLink.fromId, 'project-001');
      expect(dbLink.toId, 'task-001');
    });

    test('entryLinkFromLinkedDbEntry round-trips ProjectLink', () {
      final link = EntryLink.project(
        id: 'link-001',
        fromId: 'project-001',
        toId: 'task-001',
        createdAt: projectTestDate,
        updatedAt: projectTestDate,
        vectorClock: null,
      );

      final dbLink = linkedDbEntity(link);
      final restored = entryLinkFromLinkedDbEntry(dbLink);

      expect(restored, isA<ProjectLink>());
      expect(restored.id, 'link-001');
    });

    test('fallbackUnion deserializes unknown link types as BasicLink', () {
      // Simulates an older app version encountering a ProjectLink
      // by testing that the fallback works for truly unknown types
      final json = <String, dynamic>{
        'runtimeType': 'totally_unknown',
        'id': 'link-999',
        'fromId': 'a',
        'toId': 'b',
        'createdAt': projectTestDate.toIso8601String(),
        'updatedAt': projectTestDate.toIso8601String(),
        'vectorClock': null,
      };

      // The @Freezed(fallbackUnion: 'basic') ensures unknown types
      // deserialize as BasicLink
      final restored = EntryLink.fromJson(json);
      expect(restored, isA<BasicLink>());
    });

    glados.Glados(
      glados.any.generatedProjectLink,
      glados.ExploreConfig(numRuns: 140),
    ).test('round-trips generated project links through DB rows', (scenario) {
      final link = scenario.link;

      final dbLink = linkedDbEntity(link);
      final restored = entryLinkFromLinkedDbEntry(dbLink);

      expect(restored, equals(link), reason: '$scenario');
      expect(restored, isA<ProjectLink>(), reason: '$scenario');
      expect(dbLink.type, 'ProjectLink', reason: '$scenario');
      expect(dbLink.fromId, link.fromId, reason: '$scenario');
      expect(dbLink.toId, link.toId, reason: '$scenario');
      expect(dbLink.hidden, link.hidden ?? false, reason: '$scenario');
    }, tags: 'glados');
  });
}

enum _GeneratedEntryLinkKind { basic, rating, project }

class _GeneratedEntryLink {
  const _GeneratedEntryLink({
    required this.kind,
    required this.idSlot,
    required this.fromSlot,
    required this.toSlot,
    required this.createdAtSlot,
    required this.updatedAtSlot,
    required this.vectorClockSlot,
    required this.hiddenSlot,
    required this.collapsedSlot,
    required this.deletedAtSlot,
  });

  final _GeneratedEntryLinkKind kind;
  final int idSlot;
  final int fromSlot;
  final int toSlot;
  final int createdAtSlot;
  final int updatedAtSlot;
  final int vectorClockSlot;
  final int hiddenSlot;
  final int collapsedSlot;
  final int deletedAtSlot;

  EntryLink get link {
    final common = (
      id: 'link-$idSlot',
      fromId: 'from-$fromSlot',
      toId: 'to-$toSlot',
      createdAt: _linkDate(createdAtSlot),
      updatedAt: _linkDate(updatedAtSlot),
      vectorClock: _vectorClock(vectorClockSlot),
      hidden: _optionalBool(hiddenSlot),
      collapsed: _optionalBool(collapsedSlot),
      deletedAt: deletedAtSlot.isEven ? null : _linkDate(deletedAtSlot),
    );

    return switch (kind) {
      _GeneratedEntryLinkKind.basic => EntryLink.basic(
        id: common.id,
        fromId: common.fromId,
        toId: common.toId,
        createdAt: common.createdAt,
        updatedAt: common.updatedAt,
        vectorClock: common.vectorClock,
        hidden: common.hidden,
        collapsed: common.collapsed,
        deletedAt: common.deletedAt,
      ),
      _GeneratedEntryLinkKind.rating => EntryLink.rating(
        id: common.id,
        fromId: common.fromId,
        toId: common.toId,
        createdAt: common.createdAt,
        updatedAt: common.updatedAt,
        vectorClock: common.vectorClock,
        hidden: common.hidden,
        collapsed: common.collapsed,
        deletedAt: common.deletedAt,
      ),
      _GeneratedEntryLinkKind.project => EntryLink.project(
        id: common.id,
        fromId: common.fromId,
        toId: common.toId,
        createdAt: common.createdAt,
        updatedAt: common.updatedAt,
        vectorClock: common.vectorClock,
        hidden: common.hidden,
        collapsed: common.collapsed,
        deletedAt: common.deletedAt,
      ),
    };
  }

  @override
  String toString() {
    return '_GeneratedEntryLink('
        'kind: $kind, '
        'idSlot: $idSlot, '
        'fromSlot: $fromSlot, '
        'toSlot: $toSlot, '
        'createdAtSlot: $createdAtSlot, '
        'updatedAtSlot: $updatedAtSlot, '
        'vectorClockSlot: $vectorClockSlot, '
        'hiddenSlot: $hiddenSlot, '
        'collapsedSlot: $collapsedSlot, '
        'deletedAtSlot: $deletedAtSlot)';
  }
}

extension _AnyEntryLink on glados.Any {
  glados.Generator<_GeneratedEntryLinkKind> get _entryLinkKind =>
      glados.AnyUtils(this).choose(_GeneratedEntryLinkKind.values);

  glados.Generator<_GeneratedEntryLink> get generatedEntryLink =>
      glados.CombinableAny(this).combine9(
        _entryLinkKind,
        glados.IntAnys(this).intInRange(0, 80),
        glados.IntAnys(this).intInRange(0, 80),
        glados.IntAnys(this).intInRange(0, 80),
        glados.IntAnys(this).intInRange(0, 240),
        glados.IntAnys(this).intInRange(0, 240),
        glados.IntAnys(this).intInRange(0, 20),
        glados.IntAnys(this).intInRange(0, 20),
        glados.IntAnys(this).intInRange(0, 20),
        (
          _GeneratedEntryLinkKind kind,
          int idSlot,
          int fromSlot,
          int toSlot,
          int createdAtSlot,
          int updatedAtSlot,
          int vectorClockSlot,
          int hiddenSlot,
          int collapsedSlot,
        ) => _GeneratedEntryLink(
          kind: kind,
          idSlot: idSlot,
          fromSlot: fromSlot,
          toSlot: toSlot,
          createdAtSlot: createdAtSlot,
          updatedAtSlot: updatedAtSlot,
          vectorClockSlot: vectorClockSlot,
          hiddenSlot: hiddenSlot,
          collapsedSlot: collapsedSlot,
          deletedAtSlot: hiddenSlot + collapsedSlot,
        ),
      );
}

DateTime _linkDate(int slot) {
  return DateTime.utc(
    2024 + (slot % 4),
    (slot % 12) + 1,
    (slot % 28) + 1,
    slot % 24,
    slot % 60,
  );
}

VectorClock? _vectorClock(int slot) {
  if (slot % 4 == 0) {
    return null;
  }

  return VectorClock({
    'host-${slot % 3}': slot + 1,
    'shared': slot % 7,
  });
}

bool? _optionalBool(int slot) {
  return switch (slot % 3) {
    0 => null,
    1 => true,
    _ => false,
  };
}
