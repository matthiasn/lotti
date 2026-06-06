import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/parsed_card.dart';

import '../../../../widget_test_utils.dart';

void main() {
  const category = DayAgentCategory(
    id: 'cat-1',
    name: 'Work',
    colorHex: '#4285F4',
  );

  ParsedItem item({
    ParsedItemKind kind = ParsedItemKind.newTask,
    ParsedItemConfidence confidence = ParsedItemConfidence.high,
    String? spokenPhrase,
    String? matchedTaskTitle,
  }) {
    return ParsedItem(
      id: 'item-1',
      kind: kind,
      title: 'Prepare slides',
      category: category,
      confidence: confidence,
      spokenPhrase: spokenPhrase,
      matchedTaskTitle: matchedTaskTitle,
    );
  }

  Future<void> pumpCard(
    WidgetTester tester,
    ParsedItem parsedItem, {
    VoidCallback? onBreakLink,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: ParsedCard(
            item: parsedItem,
            onBreakLink: onBreakLink ?? () {},
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('ParsedCard', () {
    testWidgets('renders the localized badge for every kind', (tester) async {
      // Exhaustive over the enum.
      const labels = {
        ParsedItemKind.newTask: 'NEW',
        ParsedItemKind.matched: 'MATCHED',
        ParsedItemKind.update: 'UPDATE',
      };
      for (final kind in ParsedItemKind.values) {
        await tester.pumpWidget(const SizedBox.shrink());
        await pumpCard(tester, item(kind: kind));

        expect(find.text(labels[kind]!), findsOneWidget, reason: '$kind');
        expect(find.text('Prepare slides'), findsOneWidget);
      }
    });

    testWidgets('break-link button fires only for matched cards', (
      tester,
    ) async {
      var broke = 0;
      await pumpCard(
        tester,
        item(kind: ParsedItemKind.matched, matchedTaskTitle: 'Old task'),
        onBreakLink: () => broke++,
      );

      expect(find.text('Old task'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      expect(broke, 1);
    });

    testWidgets('no matched-task pill (and no break button) without a match', (
      tester,
    ) async {
      await pumpCard(tester, item());

      expect(find.byIcon(Icons.close_rounded), findsNothing);
    });

    testWidgets('spoken phrase renders italicised when present', (
      tester,
    ) async {
      await pumpCard(
        tester,
        item(
          kind: ParsedItemKind.matched,
          spokenPhrase: 'the slides thing',
          matchedTaskTitle: 'Old task',
        ),
      );

      final phrase = tester.widget<Text>(
        find.textContaining('the slides thing'),
      );
      expect(phrase.style?.fontStyle, FontStyle.italic);

      // Absent phrase renders nothing.
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpCard(tester, item());
      expect(find.textContaining('the slides thing'), findsNothing);
    });
  });
}
