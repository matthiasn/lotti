import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/relationships/ui/widgets/person_create_menu.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

void main() {
  Future<Future<PersonCreateChoice?>> pumpMenu(WidgetTester tester) async {
    late Future<PersonCreateChoice?> result;
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        Builder(
          builder: (context) => TextButton(
            key: const ValueKey('open'),
            onPressed: () => result = showPersonCreateMenu(
              context: context,
              personName: 'Pip',
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open')));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('names the person in its title and in every row that is about '
      'them', (tester) async {
    await pumpMenu(tester);

    expect(find.text("Add to Pip's timeline"), findsOneWidget);
    expect(find.text('Add a note about Pip'), findsOneWidget);
    expect(find.text('Add a task for Pip'), findsOneWidget);
    expect(find.text('Add photos'), findsOneWidget);
    expect(find.text('Log check-in'), findsOneWidget);
  });

  for (final choice in PersonCreateChoice.values) {
    testWidgets('choosing ${choice.name} closes the menu with that choice', (
      tester,
    ) async {
      final result = await pumpMenu(tester);

      await tester.tap(find.byKey(ValueKey('person-create-${choice.name}')));
      await tester.pumpAndSettle();

      expect(await result, choice);
      expect(find.text("Add to Pip's timeline"), findsNothing);
    });
  }

  testWidgets('dismissing it chooses nothing', (tester) async {
    final result = await pumpMenu(tester);

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(await result, isNull);
  });
}
