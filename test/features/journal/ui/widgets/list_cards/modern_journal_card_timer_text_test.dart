// ignore_for_file: avoid_redundant_argument_values
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// (no entity imports needed)
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/themes/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Card header date style width is stable', (tester) async {
    Future<double> pumpAndMeasure(DateTime from) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text(
                dfShort.format(from),
                style: monoTabularStyle(
                  fontSize: fontSizeMedium,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final textFinder = find.text(dfShort.format(from));
      expect(textFinder, findsOneWidget);
      return tester.getSize(textFinder).width;
    }

    final w1 = await pumpAndMeasure(DateTime(2025, 1, 1));
    final w2 = await pumpAndMeasure(DateTime(2025, 1, 8));
    expect(w1, equals(w2));
  });
}
