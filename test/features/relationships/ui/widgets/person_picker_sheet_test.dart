import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/state/relationships_providers.dart';
import 'package:lotti/features/relationships/ui/shared/persona_avatar.dart';
import 'package:lotti/features/relationships/ui/widgets/person_picker_sheet.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../test_helper.dart';
import '../../helpers/test_people.dart';

/// Serves a fixed People list, most recently contacted first — the order
/// the real list arrives in, which the picker re-sorts by name.
class _FixedPeople extends RelationshipsListController {
  _FixedPeople(this.items);

  final List<RelationshipListItem> items;

  @override
  Future<List<RelationshipListItem>> build() async => items;
}

void main() {
  final people = [
    makeTestPerson(id: 'rocko', title: 'Rocko'),
    makeTestPerson(id: 'pip', title: 'Pip Penguin', nickname: 'Pip'),
    makeTestPerson(id: 'oona', title: 'oona', nickname: 'oona'),
  ];
  List<Override> overrides() => [
    relationshipsListControllerProvider.overrideWith(
      () => _FixedPeople([
        for (final person in people) (relationship: person, lastCheckIn: null),
      ]),
    ),
  ];

  /// Opens the picker from a button and hands back what it closed with.
  Future<Set<String>? Function()> openPicker(
    WidgetTester tester, {
    Set<String> initialSelectedIds = const {},
  }) async {
    Set<String>? result;
    var closed = false;
    await tester.pumpWidget(
      WidgetTestBench(
        overrides: overrides(),
        child: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async {
                result = await showPersonPicker(
                  context: context,
                  title: 'Who was there?',
                  initialSelectedIds: initialSelectedIds,
                );
                closed = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return () {
      expect(closed, isTrue, reason: 'the picker should have closed');
      return result;
    };
  }

  testWidgets('lists everyone by name, each with their face', (tester) async {
    await openPicker(tester);

    final names = ['oona', 'Pip Penguin', 'Rocko'];
    final tops = [
      for (final name in names) tester.getTopLeft(find.text(name)).dy,
    ];
    expect(tops, orderedEquals([...tops]..sort()));
    expect(find.byType(PersonaAvatar), findsNWidgets(3));
    // A nickname that differs from the name is shown under it; one that
    // repeats the name is not.
    expect(find.text('Pip'), findsOneWidget);
    expect(find.text('oona'), findsOneWidget);
  });

  testWidgets('the search matches a name or a nickname', (tester) async {
    await openPicker(tester);

    await tester.enterText(find.byType(TextField), 'pip');
    await tester.pumpAndSettle();
    expect(find.text('Pip Penguin'), findsOneWidget);
    expect(find.text('Rocko'), findsNothing);

    await tester.enterText(find.byType(TextField), 'ROC');
    await tester.pumpAndSettle();
    expect(find.text('Rocko'), findsOneWidget);
    expect(find.text('Pip Penguin'), findsNothing);
  });

  testWidgets('Apply returns the staged people, seeded with who was there', (
    tester,
  ) async {
    final result = await openPicker(tester, initialSelectedIds: {'rocko'});

    await tester.tap(find.text('Pip Penguin'));
    await tester.pump();
    await tester.tap(find.text('Rocko'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('person-picker-apply')));
    await tester.pumpAndSettle();

    expect(result(), {'pip'});
  });

  testWidgets('dismissing returns nothing, so nothing is written', (
    tester,
  ) async {
    final result = await openPicker(tester, initialSelectedIds: {'rocko'});

    await tester.tap(find.text('Pip Penguin'));
    await tester.pump();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(result(), isNull);
  });
}
