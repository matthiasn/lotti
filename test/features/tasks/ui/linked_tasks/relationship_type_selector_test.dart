import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/features/design_system/components/buttons/ds_segmented_toggle.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
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

  group('RelationshipTypeSelector', () {
    // DsSegmentedToggle renders an invisible width-reserving ghost copy of
    // each segment's label (see its own doc comment) — plain find.text
    // matches two Texts; the visible one is the Stack's last child.
    Finder visibleText(String label) => find.text(label).last;

    testWidgets('defaults to Link selected with no phrasing toggle', (
      tester,
    ) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: RelationshipTypeSelector(
            selectedType: EntryLinkType.basic,
            inverse: false,
            onTypeChanged: (_) {},
            onInverseChanged: (_) {},
          ),
        ),
      );

      final linkPill = tester.widget<DsPill>(
        find.ancestor(of: find.text('Link'), matching: find.byType(DsPill)),
      );
      expect(linkPill.selected, isTrue);
      expect(find.byType(DsSegmentedToggle<bool>), findsNothing);
    });

    testWidgets(
      'selecting Duplicates reveals its own phrasing toggle',
      (tester) async {
        await tester.pumpWidget(
          WidgetTestBench(
            child: RelationshipTypeSelector(
              selectedType: EntryLinkType.duplicates,
              inverse: false,
              onTypeChanged: (_) {},
              onInverseChanged: (_) {},
            ),
          ),
        );

        expect(find.byType(DsSegmentedToggle<bool>), findsOneWidget);
        expect(visibleText('Duplicates'), findsOneWidget);
        expect(visibleText('Is duplicated by'), findsOneWidget);
      },
    );

    testWidgets('tapping a pill invokes onTypeChanged', (tester) async {
      EntryLinkType? selected;
      await tester.pumpWidget(
        WidgetTestBench(
          child: RelationshipTypeSelector(
            selectedType: EntryLinkType.basic,
            inverse: false,
            onTypeChanged: (type) => selected = type,
            onInverseChanged: (_) {},
          ),
        ),
      );

      await tester.tap(find.text('Blocks'));
      await tester.pump();

      expect(selected, EntryLinkType.blocks);
    });
  });
}
