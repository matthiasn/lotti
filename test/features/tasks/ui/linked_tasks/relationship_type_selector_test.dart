import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/features/design_system/components/dropdowns/design_system_dropdown.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/relationship_type_selector.dart';

import '../../../../test_helper.dart';

void main() {
  Future<BuildContext> pumpContext(WidgetTester tester) async {
    late BuildContext captured;
    await tester.pumpWidget(
      WidgetTestBench(
        child: Builder(
          builder: (context) {
            captured = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return captured;
  }

  group('relationshipTypeOptionLabel', () {
    testWidgets('returns a label for every task-relationship option', (
      tester,
    ) async {
      final context = await pumpContext(tester);

      expect(relationshipTypeOptionLabel(context, EntryLinkType.basic), 'Link');
      expect(
        relationshipTypeOptionLabel(context, EntryLinkType.blocks),
        'Blocks',
      );
      expect(
        relationshipTypeOptionLabel(context, EntryLinkType.followsUp),
        'Follows up',
      );
      expect(
        relationshipTypeOptionLabel(context, EntryLinkType.duplicates),
        'Duplicates',
      );
      expect(
        relationshipTypeOptionLabel(context, EntryLinkType.fixes),
        'Fixes',
      );
      expect(
        relationshipTypeOptionLabel(context, EntryLinkType.supersedes),
        'Supersedes',
      );
    });

    testWidgets(
      'throws for rating/project — never offered as a task relationship',
      (tester) async {
        final context = await pumpContext(tester);

        expect(
          () => relationshipTypeOptionLabel(context, EntryLinkType.rating),
          throwsStateError,
        );
        expect(
          () => relationshipTypeOptionLabel(context, EntryLinkType.project),
          throwsStateError,
        );
      },
    );
  });

  group('relationshipPhrasePair', () {
    testWidgets('returns the (primary, inverse) pair for every directional '
        'type', (tester) async {
      final context = await pumpContext(tester);

      expect(
        relationshipPhrasePair(context, EntryLinkType.blocks),
        ('Blocks', 'Is blocked by'),
      );
      expect(
        relationshipPhrasePair(context, EntryLinkType.followsUp),
        ('Follows up on', 'Has follow-up'),
      );
      expect(
        relationshipPhrasePair(context, EntryLinkType.duplicates),
        ('Duplicates', 'Is duplicated by'),
      );
      expect(
        relationshipPhrasePair(context, EntryLinkType.fixes),
        ('Fixes', 'Is fixed by'),
      );
      expect(
        relationshipPhrasePair(context, EntryLinkType.supersedes),
        ('Supersedes', 'Is superseded by'),
      );
    });

    testWidgets(
      'returns null for basic/rating/project — no phrasing choice',
      (tester) async {
        final context = await pumpContext(tester);

        expect(relationshipPhrasePair(context, EntryLinkType.basic), isNull);
        expect(relationshipPhrasePair(context, EntryLinkType.rating), isNull);
        expect(relationshipPhrasePair(context, EntryLinkType.project), isNull);
      },
    );
  });

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

    testWidgets('labels each option with its own directed phrase', (
      tester,
    ) async {
      final context = await pumpContext(tester);

      String label(EntryLinkType type, {bool inverse = false}) =>
          directedRelationLabel(
            context,
            DirectedRelation(type, inverse: inverse),
          );

      // The symmetric link completes the same sentence stem as the rest.
      expect(label(EntryLinkType.basic), 'Relates to');
      expect(label(EntryLinkType.blocks), 'Blocks');
      expect(label(EntryLinkType.blocks, inverse: true), 'Is blocked by');
      expect(label(EntryLinkType.supersedes), 'Supersedes');
      expect(
        label(EntryLinkType.supersedes, inverse: true),
        'Is superseded by',
      );
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
  });

  group('RelationshipTypeSelector', () {
    Future<DirectedRelation?> pumpSelector(
      WidgetTester tester, {
      DirectedRelation selected = const DirectedRelation(EntryLinkType.basic),
    }) async {
      DirectedRelation? picked;
      await tester.pumpWidget(
        WidgetTestBench(
          child: RelationshipTypeSelector(
            selected: selected,
            onChanged: (relation) => picked = relation,
          ),
        ),
      );
      return picked;
    }

    testWidgets(
      'is a single control showing the current relation as its value',
      (tester) async {
        await pumpSelector(tester);

        final dropdown = tester.widget<DesignSystemDropdown>(
          find.byType(DesignSystemDropdown),
        );
        expect(dropdown.label, 'This task…');
        expect(dropdown.inputLabel, 'Relates to');
        // Type and direction are one list, not two controls.
        expect(dropdown.items, hasLength(11));
        expect(
          dropdown.items.where((i) => i.selected).map((i) => i.label),
          ['Relates to'],
        );
      },
    );

    testWidgets('marks the supplied inverse relation as the selected item', (
      tester,
    ) async {
      await pumpSelector(
        tester,
        selected: const DirectedRelation(
          EntryLinkType.blocks,
          inverse: true,
        ),
      );

      final dropdown = tester.widget<DesignSystemDropdown>(
        find.byType(DesignSystemDropdown),
      );
      expect(dropdown.inputLabel, 'Is blocked by');
      expect(
        dropdown.items.where((i) => i.selected).map((i) => i.label),
        ['Is blocked by'],
      );
    });

    testWidgets('reports the picked option as a type + direction pair', (
      tester,
    ) async {
      DirectedRelation? picked;
      await tester.pumpWidget(
        WidgetTestBench(
          child: RelationshipTypeSelector(
            selected: const DirectedRelation(EntryLinkType.basic),
            onChanged: (relation) => picked = relation,
          ),
        ),
      );

      final dropdown = tester.widget<DesignSystemDropdown>(
        find.byType(DesignSystemDropdown),
      );
      final inverseBlocks = dropdown.items.firstWhere(
        (i) => i.label == 'Is blocked by',
      );
      dropdown.onItemPressed!(inverseBlocks);

      expect(
        picked,
        const DirectedRelation(EntryLinkType.blocks, inverse: true),
      );
    });
  });
}
