import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/habits/ui/widgets/habits_title_row.dart';

import '../../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders the Habits title and the ISO date for a fixed today', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidget(
        HabitsTitleRow(todayOverride: _fixedToday),
      ),
    );
    await tester.pump();

    expect(find.text('Habits'), findsOneWidget);
    expect(find.text('2026-05-22'), findsOneWidget);
  });

  testWidgets('renders a different date when todayOverride changes', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidget(
        HabitsTitleRow(todayOverride: DateTime(2024, 3, 15)),
      ),
    );
    await tester.pump();

    expect(find.text('Habits'), findsOneWidget);
    expect(find.text('2024-03-15'), findsOneWidget);
    expect(find.text('2026-05-22'), findsNothing);
  });
}

final _fixedToday = DateTime(2026, 5, 22);
