import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/duration_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('FormattedTime text width is stable', (tester) async {
    JournalEntity makeEntry(Duration duration) {
      final now = DateTime(2025, 1, 1, 12, 0, 0);
      final from = now.subtract(duration);
      return JournalEntity.journalEntry(
        meta: Metadata(
          id: 'e1',
          createdAt: from,
          updatedAt: now,
          dateFrom: from,
          dateTo: now,
        ),
      );
    }

    Future<double> pumpAndMeasure(Duration d) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: FormattedTime(
                labelColor: Colors.blueGrey,
                displayed: makeEntry(d),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final finder = find.byType(FormattedTime);
      expect(finder, findsOneWidget);
      final textFinder = find.descendant(
        of: finder,
        matching: find.byType(Text),
      );
      expect(textFinder, findsOneWidget);
      return tester.getSize(textFinder).width;
    }

    final w1 = await pumpAndMeasure(const Duration(minutes: 41));
    final w2 = await pumpAndMeasure(const Duration(minutes: 48));
    expect(w1, equals(w2));
  });
}
// ignore_for_file: avoid_redundant_argument_values
