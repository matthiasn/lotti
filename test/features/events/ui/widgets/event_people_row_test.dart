import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/chips/design_system_chip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/events/ui/model/event_view_data.dart';
import 'package:lotti/features/events/ui/widgets/event_people_row.dart';
import 'package:lotti/features/relationships/ui/shared/persona_avatar.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

void main() {
  const pip = EventPerson(id: 'pip', name: 'Pip Penguin', avatarImageId: 'a1');
  const rocko = EventPerson(id: 'rocko', name: 'Rocko');

  Future<void> pumpRow(
    WidgetTester tester, {
    required List<EventPerson> people,
    ValueChanged<String>? onOpenPerson,
    VoidCallback? onEditPeople,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        EventPeopleRow(
          people: people,
          onOpenPerson: onOpenPerson,
          onEditPeople: onEditPeople,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('one chip per person, with their face, then Edit people', (
    tester,
  ) async {
    await pumpRow(tester, people: [pip, rocko], onEditPeople: () {});

    expect(find.text('Pip Penguin'), findsOneWidget);
    expect(find.text('Rocko'), findsOneWidget);
    final avatars = tester
        .widgetList<PersonaAvatar>(find.byType(PersonaAvatar))
        .toList();
    expect(avatars.map((a) => a.id), ['pip', 'rocko']);
    expect(avatars.first.imageId, 'a1');
    expect(avatars.last.initial, 'R');
    // The change chip comes last, told apart by its glyph alone…
    final edit = tester.widget<DesignSystemChip>(
      find.byKey(const ValueKey('event-people-edit')),
    );
    expect(edit.label, 'Edit people');
    expect(edit.leadingIcon, LottiIcons.edit);
    // …and every chip stands the same height, so a shared line sits level.
    final heights = tester
        .widgetList<DesignSystemChip>(find.byType(DesignSystemChip))
        .map((chip) => tester.getSize(find.byWidget(chip)).height)
        .toSet();
    expect(heights, hasLength(1));
    expect(
      tester.getTopLeft(find.text('Edit people')).dx,
      greaterThan(tester.getTopLeft(find.text('Rocko')).dx),
    );
  });

  testWidgets('a person chip opens that person', (tester) async {
    final opened = <String>[];
    await pumpRow(tester, people: [pip, rocko], onOpenPerson: opened.add);

    await tester.tap(find.text('Rocko'));
    await tester.tap(find.text('Pip Penguin'));

    expect(opened, ['rocko', 'pip']);
  });

  testWidgets('the change chip opens the picker', (tester) async {
    var edits = 0;
    await pumpRow(tester, people: [pip], onEditPeople: () => edits++);

    await tester.tap(find.text('Edit people'));

    expect(edits, 1);
  });

  testWidgets('with no one yet it is only the Add people chip', (tester) async {
    var edits = 0;
    await pumpRow(tester, people: const [], onEditPeople: () => edits++);

    final add = tester.widget<DesignSystemChip>(
      find.byType(DesignSystemChip),
    );
    expect(add.label, 'Add people');
    expect(add.leadingIcon, LottiIcons.personAdd);
    await tester.tap(find.text('Add people'));
    expect(edits, 1);
  });

  testWidgets('read-only: the people stay, the change chip goes', (
    tester,
  ) async {
    await pumpRow(tester, people: [pip]);

    expect(find.text('Pip Penguin'), findsOneWidget);
    expect(find.byKey(const ValueKey('event-people-edit')), findsNothing);
  });

  testWidgets('read-only with no one renders nothing', (tester) async {
    await pumpRow(tester, people: const []);

    expect(find.byType(DesignSystemChip), findsNothing);
    expect(
      tester.getSize(find.byType(EventPeopleRow)),
      Size.zero,
    );
  });
}
