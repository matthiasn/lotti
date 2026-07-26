import 'package:glados/glados.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/features/tasks/model/directed_relation.dart';

extension _AnyDirectedRelation on Any {
  Generator<DirectedRelation> get directedRelation =>
      AnyUtils(this).choose(relationshipDirectedOptions);
}

void main() {
  group('relationshipDirectedOptions', () {
    test('offers the symmetric link first, then every type both ways', () {
      expect(relationshipDirectedOptions, [
        const DirectedRelation(EntryLinkType.basic),
        const DirectedRelation(EntryLinkType.blocks),
        const DirectedRelation(EntryLinkType.blocks, inverse: true),
        const DirectedRelation(EntryLinkType.followsUp),
        const DirectedRelation(EntryLinkType.followsUp, inverse: true),
        const DirectedRelation(EntryLinkType.duplicates),
        const DirectedRelation(EntryLinkType.duplicates, inverse: true),
        const DirectedRelation(EntryLinkType.fixes),
        const DirectedRelation(EntryLinkType.fixes, inverse: true),
        const DirectedRelation(EntryLinkType.supersedes),
        const DirectedRelation(EntryLinkType.supersedes, inverse: true),
      ]);
      // Ids are unique, so a dropdown item always maps back to one relation.
      final ids = relationshipDirectedOptions.map((r) => r.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });
  });

  group('DirectedRelation', () {
    test('equality and hashCode cover both type and direction', () {
      const primary = DirectedRelation(EntryLinkType.blocks);
      const inverse = DirectedRelation(EntryLinkType.blocks, inverse: true);

      expect(primary, const DirectedRelation(EntryLinkType.blocks));
      expect(
        primary.hashCode,
        const DirectedRelation(EntryLinkType.blocks).hashCode,
      );
      expect(primary, isNot(inverse));
      expect(primary, isNot(const DirectedRelation(EntryLinkType.fixes)));
    });

    test('inverse does not take part in identity on the symmetric link', () {
      expect(
        const DirectedRelation(EntryLinkType.basic, inverse: true),
        const DirectedRelation(EntryLinkType.basic),
      );
    });
  });

  group('wireName', () {
    test('maps every directed option to its stable machine phrase', () {
      expect(DirectedRelation.wireNames, [
        'relates_to',
        'blocks',
        'is_blocked_by',
        'follows_up_on',
        'has_follow_up',
        'duplicates',
        'is_duplicated_by',
        'fixes',
        'is_fixed_by',
        'supersedes',
        'is_superseded_by',
      ]);
    });

    test('throws for the non-relationship link types', () {
      expect(
        () => const DirectedRelation(EntryLinkType.rating).wireName,
        throwsStateError,
      );
      expect(
        () => const DirectedRelation(EntryLinkType.project).wireName,
        throwsStateError,
      );
    });
  });

  group('englishPhrase', () {
    test('completes the "This task …" sentence for every option', () {
      String phrase(EntryLinkType type, {bool inverse = false}) =>
          DirectedRelation(type, inverse: inverse).englishPhrase;

      expect(phrase(EntryLinkType.basic), 'relates to');
      expect(phrase(EntryLinkType.blocks), 'blocks');
      expect(phrase(EntryLinkType.blocks, inverse: true), 'is blocked by');
      expect(phrase(EntryLinkType.followsUp), 'follows up on');
      expect(phrase(EntryLinkType.followsUp, inverse: true), 'has follow-up');
      expect(phrase(EntryLinkType.duplicates), 'duplicates');
      expect(
        phrase(EntryLinkType.duplicates, inverse: true),
        'is duplicated by',
      );
      expect(phrase(EntryLinkType.fixes), 'fixes');
      expect(phrase(EntryLinkType.fixes, inverse: true), 'is fixed by');
      expect(phrase(EntryLinkType.supersedes), 'supersedes');
      expect(
        phrase(EntryLinkType.supersedes, inverse: true),
        'is superseded by',
      );
    });

    test('throws for the non-relationship link types', () {
      expect(
        () => const DirectedRelation(EntryLinkType.rating).englishPhrase,
        throwsStateError,
      );
      expect(
        () => const DirectedRelation(EntryLinkType.project).englishPhrase,
        throwsStateError,
      );
    });
  });

  group('fromWireName', () {
    Glados(any.directedRelation, ExploreConfig(numRuns: 60)).test(
      'round-trips every option through its wire name',
      (relation) {
        expect(
          DirectedRelation.fromWireName(relation.wireName),
          relation,
          reason: 'round-trip for $relation',
        );
      },
      tags: 'glados',
    );

    test('tolerates surrounding whitespace and case', () {
      expect(
        DirectedRelation.fromWireName('  IS_BLOCKED_BY '),
        const DirectedRelation(EntryLinkType.blocks, inverse: true),
      );
    });

    test('rejects anything outside the vocabulary', () {
      expect(DirectedRelation.fromWireName('blocked_by'), isNull);
      expect(DirectedRelation.fromWireName('parent_of'), isNull);
      expect(DirectedRelation.fromWireName(''), isNull);
      expect(DirectedRelation.fromWireName('rating'), isNull);
    });
  });

  group('canonicalEndpoints', () {
    test('primary phrase keeps the anchor as fromId', () {
      expect(
        const DirectedRelation(
          EntryLinkType.blocks,
        ).canonicalEndpoints(anchorId: 'me', otherId: 'other'),
        (fromId: 'me', toId: 'other'),
      );
    });

    test('inverse phrase swaps, so the blocker is always fromId', () {
      expect(
        const DirectedRelation(
          EntryLinkType.blocks,
          inverse: true,
        ).canonicalEndpoints(anchorId: 'me', otherId: 'other'),
        (fromId: 'other', toId: 'me'),
      );
    });

    test('the symmetric link never swaps, even with a stray inverse flag', () {
      expect(
        const DirectedRelation(
          EntryLinkType.basic,
          inverse: true,
        ).canonicalEndpoints(anchorId: 'me', otherId: 'other'),
        (fromId: 'me', toId: 'other'),
      );
    });

    Glados(any.directedRelation, ExploreConfig(numRuns: 60)).test(
      'both phrasings of a directional type store the same canonical edge',
      (relation) {
        // The symmetric link has one phrasing; either ordering is canonical.
        if (relation.isSymmetric) return;
        final primary = DirectedRelation(relation.type);
        final inverse = DirectedRelation(relation.type, inverse: true);

        // "A <primary> B" and "B <inverse> A" describe the same relationship,
        // so they must persist the identical row.
        expect(
          primary.canonicalEndpoints(anchorId: 'a', otherId: 'b'),
          inverse.canonicalEndpoints(anchorId: 'b', otherId: 'a'),
          reason: 'canonical edge for ${relation.type}',
        );
      },
      tags: 'glados',
    );
  });

  group('ExistingRelation', () {
    test('identity spans both the task and the exact relation it holds', () {
      const plainLink = ExistingRelation(
        taskId: 'a',
        relation: DirectedRelation(EntryLinkType.basic),
      );

      expect(
        plainLink,
        const ExistingRelation(
          taskId: 'a',
          relation: DirectedRelation(EntryLinkType.basic),
        ),
      );
      expect(
        plainLink.hashCode,
        const ExistingRelation(
          taskId: 'a',
          relation: DirectedRelation(EntryLinkType.basic),
        ).hashCode,
      );
      // Same task, different relation — a pair may hold both.
      expect(
        plainLink,
        isNot(
          const ExistingRelation(
            taskId: 'a',
            relation: DirectedRelation(EntryLinkType.blocks),
          ),
        ),
      );
      // Different task, same relation.
      expect(
        plainLink,
        isNot(
          const ExistingRelation(
            taskId: 'b',
            relation: DirectedRelation(EntryLinkType.basic),
          ),
        ),
      );
    });
  });
}
